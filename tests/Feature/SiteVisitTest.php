<?php

namespace Tests\Feature;

use App\Enums\DeviceType;
use App\Filament\Pages\AudienceDashboard;
use App\Filament\Widgets\LiveVisitors;
use App\Filament\Widgets\VisitsByBrowserChart;
use App\Filament\Widgets\VisitsByCountryChart;
use App\Filament\Widgets\VisitsByDeviceChart;
use App\Filament\Widgets\VisitsOverTimeChart;
use App\Models\Session;
use App\Models\SiteVisit;
use App\Models\User;
use App\Services\VisitService;
use App\Support\GeoIp;
use App\Support\UserAgent;
use Filament\Pages\Dashboard;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Middleware\TrustProxies;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Http;
use Livewire\Livewire;
use Mockery;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\TestCase;

class SiteVisitTest extends TestCase
{
    use RefreshDatabase;

    private const CHROME_WINDOWS = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

    private const SAFARI_MAC = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15';

    private const SAFARI_IPHONE = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1';

    private const CHROME_ANDROID_PHONE = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';

    private const CHROME_ANDROID_TABLET = 'Mozilla/5.0 (Linux; Android 14; SM-X710) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

    private const FIREFOX_ANDROID_TABLET = 'Mozilla/5.0 (Android 14; Tablet; rv:131.0) Gecko/131.0 Firefox/131.0';

    private const FIREFOX_ANDROID_PHONE = 'Mozilla/5.0 (Android 14; Mobile; rv:131.0) Gecko/131.0 Firefox/131.0';

    private const IPAD_MOBILE_MODE = 'Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1';

    protected function setUp(): void
    {
        parent::setUp();
        config(['kado.geoip.path' => storage_path('framework/testing/no-geoip.mmdb')]);
    }

    private function visit(User $user, array $headers = []): void
    {
        $this->actingAs($user, 'web')
            ->withHeaders(['Referer' => config('app.url'), 'User-Agent' => self::CHROME_WINDOWS, ...$headers])
            ->getJson('/api/user')
            ->assertOk();
    }

    private function makeVisit(User $user, string $date, string $device = 'desktop', string $browser = 'Chrome', string $country = 'FR'): void
    {
        SiteVisit::query()->insert(['date' => $date, 'user_id' => $user->id, 'device' => $device, 'browser' => $browser, 'country' => $country]);
    }

    public function test_a_player_is_noted_once_a_day(): void
    {
        $this->travelTo(Carbon::parse('2026-11-04 23:59:00'));
        $user = User::factory()->create();

        $this->visit($user);
        $this->visit($user);

        $visit = SiteVisit::sole();
        $this->assertSame('2026-11-04', Carbon::parse($visit->date)->toDateString());
        $this->assertSame($user->id, $visit->user_id);
        $this->assertSame(DeviceType::DESKTOP, $visit->device);
        $this->assertSame('Chrome', $visit->browser);
        $this->assertSame(SiteVisit::UNKNOWN_COUNTRY, $visit->country);

        // a tab left open: the next day counts
        $this->travelTo(Carbon::parse('2026-11-05 00:01:00'));
        $this->visit($user);
        $this->assertSame(2, SiteVisit::count());
    }

    // a new session the same day (phone, new login): the same browser is not a new row, null would have made one
    public function test_two_sessions_on_the_same_device_are_one_visit(): void
    {
        $user = User::factory()->create();

        $this->visit($user);
        $this->flushSession();
        $this->visit($user);
        $this->assertSame(1, SiteVisit::count());

        $this->flushSession();
        $this->visit($user, ['User-Agent' => self::SAFARI_IPHONE]);
        $this->assertSame(2, SiteVisit::count());
        $this->assertSame([DeviceType::DESKTOP, DeviceType::MOBILE], SiteVisit::orderBy('id')->get()->pluck('device')->all());
    }

    public function test_guests_and_tokens_are_not_noted(): void
    {
        $this->withHeaders(['Referer' => config('app.url')])->getJson('/api/user')->assertUnauthorized();
        $this->assertSame(0, SiteVisit::count());

        $token = User::factory()->create()->createToken('test')->plainTextToken;
        $this->flushHeaders();
        $this->withToken($token)->getJson('/api/user')->assertOk();
        $this->assertSame(0, SiteVisit::count());
    }

    // the visit is only a stat: the request of the player goes on when it fails
    public function test_a_failure_does_not_fail_the_request(): void
    {
        $this->mock(GeoIp::class)->shouldReceive('country')->andThrow(new RuntimeException('broken database'));

        $this->visit(User::factory()->create());

        $this->assertSame(0, SiteVisit::count());
    }

    public function test_the_country_comes_from_the_ip(): void
    {
        $this->mock(GeoIp::class)->shouldReceive('country')->with('203.0.113.7')->andReturn('BE');

        $this->visit(User::factory()->create(), ['REMOTE_ADDR' => '203.0.113.7']);

        $this->assertSame('BE', SiteVisit::sole()->country);
    }

    public function test_the_ip_of_a_trusted_proxy_is_replaced_by_the_one_of_the_player(): void
    {
        $this->mock(GeoIp::class)->shouldReceive('country')->with('198.51.100.9')->andReturn('CA');
        TrustProxies::at('10.0.0.1');
        TrustProxies::withHeaders(Request::HEADER_X_FORWARDED_FOR);
        $this->beforeApplicationDestroyed(fn () => TrustProxies::flushState());

        $this->withServerVariables(['REMOTE_ADDR' => '10.0.0.1']);
        $this->visit(User::factory()->create(), ['X-Forwarded-For' => '198.51.100.9']);

        $this->assertSame('CA', SiteVisit::sole()->country);
    }

    public function test_a_forged_forwarded_header_is_ignored_without_a_trusted_proxy(): void
    {
        $this->mock(GeoIp::class)->shouldReceive('country')->with('203.0.113.7')->andReturn('BE');

        $this->withServerVariables(['REMOTE_ADDR' => '203.0.113.7']);
        $this->visit(User::factory()->create(), ['X-Forwarded-For' => '198.51.100.9']);

        $this->assertSame('BE', SiteVisit::sole()->country);
    }

    public static function devices(): array
    {
        return [
            'pc' => [self::CHROME_WINDOWS, 0, DeviceType::DESKTOP],
            'mac' => [self::SAFARI_MAC, 0, DeviceType::DESKTOP],
            'iphone' => [self::SAFARI_IPHONE, 5, DeviceType::MOBILE],
            'android phone' => [self::CHROME_ANDROID_PHONE, 5, DeviceType::MOBILE],
            'android tablet' => [self::CHROME_ANDROID_TABLET, 5, DeviceType::TABLET],
            'firefox android phone' => [self::FIREFOX_ANDROID_PHONE, 5, DeviceType::MOBILE],
            'firefox android tablet' => [self::FIREFOX_ANDROID_TABLET, 5, DeviceType::TABLET],
            'ipad saying it is a mac' => [self::SAFARI_MAC, 5, DeviceType::TABLET],
            'ipad in mobile mode' => [self::IPAD_MOBILE_MODE, 5, DeviceType::TABLET],
            'nothing' => ['', 0, DeviceType::DESKTOP],
        ];
    }

    #[DataProvider('devices')]
    public function test_the_device(string $agent, int $touchPoints, DeviceType $device): void
    {
        $this->assertSame($device, (new UserAgent($agent))->deviceType($touchPoints));
    }

    public function test_the_ipad_header_of_the_spa(): void
    {
        $this->visit(User::factory()->create(), ['User-Agent' => self::SAFARI_MAC, 'X-Kado-Touch' => '5']);

        $this->assertSame(DeviceType::TABLET, SiteVisit::sole()->device);
    }

    public function test_the_session_device_did_not_change(): void
    {
        $this->assertSame('Chrome · Windows', (new Session())->forceFill(['user_agent' => self::CHROME_WINDOWS])->device());
        $this->assertSame('Safari · iOS', (new Session())->forceFill(['user_agent' => self::SAFARI_IPHONE])->device());
        $this->assertSame('Inconnu', (new Session())->forceFill(['user_agent' => null])->device());
    }

    public function test_no_database_or_a_private_ip_has_no_country(): void
    {
        $geoIp = new GeoIp();

        $this->assertNull($geoIp->country('8.8.8.8'));
        // (never read: refused before the file)
        config(['kado.geoip.path' => __FILE__]);
        $this->assertNull($geoIp->country('192.168.1.10'));
        $this->assertNull($geoIp->country('127.0.0.1'));
        $this->assertNull($geoIp->country(null));
    }

    public function test_no_realtime_no_count_of_the_connected_players(): void
    {
        config(['broadcasting.default' => 'log']);

        $this->assertNull(app(VisitService::class)->connectedNow());
    }

    public function test_the_connected_players_are_read_from_the_channels_of_reverb(): void
    {
        config(['broadcasting.default' => 'reverb']);
        $pusher = Mockery::mock();
        $pusher->shouldReceive('getChannels')->with(['filter_by_prefix' => 'private-App.Models.User.'])
            ->andReturn((object) ['channels' => ['private-App.Models.User.1' => (object) [], 'private-App.Models.User.2' => (object) []]]);
        $broadcaster = Mockery::mock();
        $broadcaster->shouldReceive('getPusher')->andReturn($pusher);
        Broadcast::shouldReceive('connection')->with('reverb')->andReturn($broadcaster);

        $this->assertSame(2, app(VisitService::class)->connectedNow());
    }

    public function test_a_reverb_down_is_no_error(): void
    {
        config(['broadcasting.default' => 'reverb']);
        Broadcast::shouldReceive('connection')->andThrow(new RuntimeException('down'));

        $this->assertNull(app(VisitService::class)->connectedNow());
    }

    public function test_the_active_players(): void
    {
        $user = User::factory()->create();
        $sessions = [
            ['id' => 'a', 'user_id' => $user->id, 'last_activity' => now()->subMinutes(2)->getTimestamp()],
            ['id' => 'b', 'user_id' => $user->id, 'last_activity' => now()->subMinutes(3)->getTimestamp()],
            ['id' => 'c', 'user_id' => User::factory()->create()->id, 'last_activity' => now()->subMinutes(60)->getTimestamp()],
            ['id' => 'd', 'user_id' => null, 'last_activity' => now()->getTimestamp()],
        ];
        foreach ($sessions as $session) {
            Session::query()->insert([...$session, 'payload' => '']);
        }

        $this->assertSame(1, app(VisitService::class)->activeSince(15));
    }

    public function test_the_visitors_count_each_player_once(): void
    {
        $this->travelTo(Carbon::parse('2026-11-04 12:00:00'));
        $user = User::factory()->create();
        $this->makeVisit($user, '2026-11-04');
        $this->makeVisit($user, '2026-11-04', 'mobile', 'Safari');
        $this->makeVisit($user, '2026-11-03');
        $this->makeVisit(User::factory()->create(), '2026-11-03');
        $this->makeVisit(User::factory()->create(), '2026-10-20');

        $visits = app(VisitService::class);
        $this->assertSame(1, $visits->visitorsBetween(today()));
        $this->assertSame(2, $visits->visitorsBetween(today()->subDay(), today()->subDay()));
        $this->assertSame(2, $visits->visitorsBetween(today()->subDays(6)));
        $this->assertEqualsCanonicalizing(['desktop' => 2, 'mobile' => 1], $visits->visitorsBy('device', 7));
        $this->assertSame(1, $visits->visitorsBy('device', 90)['mobile']);
        $this->assertSame(3, $visits->visitorsBy('device', 90)['desktop']);
    }

    public function test_the_visitors_of_each_day(): void
    {
        $this->travelTo(Carbon::parse('2026-11-04 12:00:00'));
        $user = User::factory()->create();
        $this->makeVisit($user, '2026-11-01');
        $this->makeVisit($user, '2026-11-01', 'mobile', 'Safari');
        $this->makeVisit(User::factory()->create(), '2026-11-01');
        $this->makeVisit($user, '2026-11-03');
        $this->makeVisit($user, '2026-10-31');
        $this->makeVisit($user, '2026-11-04');

        $this->assertSame(
            ['2026-11-01' => 2, '2026-11-02' => 0, '2026-11-03' => 1],
            app(VisitService::class)->visitorsPerDay(Carbon::parse('2026-11-01'), Carbon::parse('2026-11-03')),
        );
    }

    public function test_the_chart_of_a_period(): void
    {
        Cache::flush();
        $this->travelTo(Carbon::parse('2026-11-04 12:00:00'));
        $this->actingAs(User::factory()->create(['is_admin' => true]));
        $this->makeVisit(User::factory()->create(), '2026-11-02');

        $widget = Livewire::test(VisitsOverTimeChart::class)
            ->set('filters', ['startDate' => '2026-11-01', 'endDate' => '2026-11-03'])
            ->instance();
        $data = (fn () => $this->getData())->call($widget);

        $this->assertSame(['01/11', '02/11', '03/11'], $data['labels']);
        $this->assertSame([0, 1, 0], $data['datasets'][0]['data']);
    }

    // the visits are kept 90 days: an older start shows nothing more, and the days after today neither
    public function test_the_chart_stops_at_what_is_kept(): void
    {
        Cache::flush();
        $this->travelTo(Carbon::parse('2026-11-04 12:00:00'));
        $this->actingAs(User::factory()->create(['is_admin' => true]));

        $widget = Livewire::test(VisitsOverTimeChart::class)
            ->set('filters', ['startDate' => '2020-01-01', 'endDate' => '2030-01-01'])
            ->instance();
        $data = (fn () => $this->getData())->call($widget);

        $this->assertCount(SiteVisit::KEEP_DAYS + 1, $data['labels']);
        $this->assertSame('04/11', end($data['labels']));
    }

    public function test_the_old_visits_are_pruned(): void
    {
        $this->travelTo(Carbon::parse('2026-11-04 12:00:00'));
        $user = User::factory()->create();
        $this->makeVisit($user, today()->subDays(SiteVisit::KEEP_DAYS)->toDateString());
        $this->makeVisit($user, today()->subDays(SiteVisit::KEEP_DAYS + 1)->toDateString());

        Artisan::call('model:prune', ['--model' => [SiteVisit::class]]);

        $this->assertSame(1, SiteVisit::count());
    }

    public function test_the_stats_have_their_own_page(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));
        $widgets = (new AudienceDashboard())->getWidgets();

        $this->assertSame(
            [LiveVisitors::class, VisitsOverTimeChart::class, VisitsByDeviceChart::class, VisitsByBrowserChart::class, VisitsByCountryChart::class],
            $widgets,
        );
        $this->get(AudienceDashboard::getUrl())->assertOk()->assertSee('Fréquentation');

        $this->get('/admin')->assertOk();
        $this->assertSame([], array_values(array_intersect($widgets, (new Dashboard())->getWidgets())));
    }

    public function test_the_page_is_for_the_admins(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => false]));

        $this->get(AudienceDashboard::getUrl())->assertForbidden();
    }

    public function test_the_widgets(): void
    {
        config(['broadcasting.default' => 'log']);
        Cache::flush();
        $this->actingAs(User::factory()->create(['is_admin' => true]));
        $users = User::factory()->count(13)->create();
        foreach ($users as $i => $user) {
            $this->makeVisit($user, today()->toDateString(), $i ? 'desktop' : 'mobile', $i ? 'Chrome' : 'Safari', $i < 2 ? 'FR' : ($i === 12 ? 'ZZ' : 'B'.chr(64 + $i)));
        }

        Livewire::test(LiveVisitors::class)->assertSee('Connectés maintenant')->assertSee('—')->assertSee('13');

        $device = (fn () => $this->getData())->call(Livewire::test(VisitsByDeviceChart::class)->instance());
        $this->assertSame(['PC (92 %)', 'Mobile (8 %)', 'Tablette (0 %)'], $device['labels']);
        $this->assertSame([12, 1, 0], $device['datasets'][0]['data']);

        $browser = (fn () => $this->getData())->call(Livewire::test(VisitsByBrowserChart::class)->instance());
        $this->assertSame([12, 0, 1, 0, 0, 0], $browser['datasets'][0]['data']);

        $country = Livewire::test(VisitsByCountryChart::class);
        $country->assertSee('IP Geolocation by DB-IP');
        $data = (fn () => $this->getData())->call($country->instance());
        $this->assertSame('France', $data['labels'][0]);
        $this->assertSame(2, $data['datasets'][0]['data'][0]);
        // the 10 first countries, then what is left: BB and on make 11 countries, so one in « Autres »
        $this->assertSame(['Autres', 'Inconnu'], array_slice($data['labels'], -2));
        $this->assertCount(12, $data['labels']);
    }

    public function test_the_period_of_a_chart_cannot_be_forged(): void
    {
        Cache::flush();
        $this->actingAs(User::factory()->create(['is_admin' => true]));

        Livewire::test(VisitsByDeviceChart::class)->set('filter', '1; drop table users')->assertOk();

        $this->assertTrue(Cache::has('admin.widgets.visits.device.30'));
    }

    public function test_the_ip_database_is_kept_when_the_download_is_not_one(): void
    {
        $path = storage_path('framework/testing/geoip-test/country.mmdb');
        File::ensureDirectoryExists(dirname($path));
        File::put($path, 'old');
        touch($path, Carbon::parse('2026-10-01')->getTimestamp());
        $this->beforeApplicationDestroyed(fn () => File::deleteDirectory(dirname($path)));
        config(['kado.geoip.path' => $path]);
        $this->travelTo(Carbon::parse('2026-11-04 12:00:00'));
        Http::fake(['*' => Http::response(gzencode('not a database'))]);

        $this->artisan('kado:geoip:update')->assertFailed();

        $this->assertSame('old', File::get($path));
        $this->assertFileDoesNotExist("{$path}.tmp");
        Http::assertSent(fn ($request) => str_ends_with($request->url(), 'dbip-country-lite-2026-11.mmdb.gz'));
        Http::assertSent(fn ($request) => str_ends_with($request->url(), 'dbip-country-lite-2026-10.mmdb.gz'));
    }

    public function test_the_ip_database_of_the_month_is_not_downloaded_again(): void
    {
        $path = storage_path('framework/testing/geoip-test/country.mmdb');
        File::ensureDirectoryExists(dirname($path));
        File::put($path, 'current');
        touch($path, Carbon::parse('2026-11-01')->getTimestamp());
        $this->beforeApplicationDestroyed(fn () => File::deleteDirectory(dirname($path)));
        config(['kado.geoip.path' => $path]);
        $this->travelTo(Carbon::parse('2026-11-04 12:00:00'));
        Http::fake();

        $this->artisan('kado:geoip:update')->assertSuccessful();

        Http::assertNothingSent();
    }

    // the month not released yet: asked again a few hours later, not every 5 minutes
    public function test_an_older_ip_database_is_not_replaced_at_every_run(): void
    {
        Cache::flush();
        $path = storage_path('framework/testing/geoip-test/country.mmdb');
        File::ensureDirectoryExists(dirname($path));
        File::put($path, 'old');
        touch($path, Carbon::parse('2026-10-01')->getTimestamp());
        $this->beforeApplicationDestroyed(fn () => File::deleteDirectory(dirname($path)));
        config(['kado.geoip.path' => $path]);
        $this->travelTo(Carbon::parse('2026-11-01 12:00:00'));
        Http::fake(['*' => Http::response('', 404)]);

        $this->artisan('kado:geoip:update')->assertFailed();
        $this->artisan('kado:geoip:update')->assertSuccessful();

        Http::assertSentCount(2);
    }
}
