<?php

namespace Tests\Feature;

use App\Enums\LocalePreference;
use App\Filament\Pages\ManageSiteSettings;
use App\Models\User;
use App\Settings\SiteSettings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class LocalePreferenceTest extends TestCase
{
    use RefreshDatabase;

    private function player(LocalePreference $locale = LocalePreference::AUTO): User
    {
        return User::factory()->create(['locale' => $locale]);
    }

    private function saveLocale(mixed $locale)
    {
        return $this->withHeader('Referer', config('app.url'))->putJson('/api/user/locale', ['locale' => $locale]);
    }

    public function test_a_new_player_follows_his_browser(): void
    {
        $this->assertSame(LocalePreference::AUTO, User::factory()->create()->fresh()->locale);
        $this->assertSame(LocalePreference::AUTO, (new User())->locale);
    }

    public function test_the_languages_are_off_by_default(): void
    {
        $this->assertFalse(app(SiteSettings::class)->i18n_enabled);
    }

    public function test_the_admin_turns_the_languages_on(): void
    {
        $admin = User::factory()->create(['is_admin' => true]);
        $this->actingAs($admin);

        Livewire::test(ManageSiteSettings::class)
            ->assertFormFieldExists('i18n_enabled', fn ($field) => $field->getLabel() === 'Choix de la langue')
            ->fillForm(['i18n_enabled' => true])
            ->call('save')
            ->assertHasNoErrors();

        $this->assertTrue(app(SiteSettings::class)->i18n_enabled);
    }

    public function test_with_the_flag_off_a_page_is_french_and_says_so(): void
    {
        $this->actingAs($this->player(LocalePreference::EN), 'web');

        $this->withHeader('Accept-Language', 'en')->get('/games')
            ->assertOk()
            ->assertSee('<html lang="fr">', false)
            ->assertSee('locale: "fr"', false)
            ->assertSee('i18n_enabled: false', false);
    }

    public function test_with_the_flag_on_a_page_follows_the_language(): void
    {
        $this->setSettings(SiteSettings::class, ['i18n_enabled' => true]);

        $this->withHeader('Accept-Language', 'en')->get('/games')
            ->assertOk()
            ->assertSee('<html lang="en">', false)
            ->assertSee('locale: "en"', false)
            ->assertSee('i18n_enabled: true', false);
    }

    public function test_a_page_gives_the_languages_of_the_site(): void
    {
        $this->get('/games')
            ->assertOk()
            ->assertSee('locales: ["fr","en"]', false);
    }

    public function test_the_account_of_the_player_wins_in_the_page(): void
    {
        $this->setSettings(SiteSettings::class, ['i18n_enabled' => true]);
        $this->actingAs($this->player(LocalePreference::FR), 'web');

        $this->withHeader('Accept-Language', 'en')->get('/games')
            ->assertSee('<html lang="fr">', false);
    }

    public function test_a_page_is_not_shared_between_players(): void
    {
        $cacheControl = $this->get('/games')->headers->get('Cache-Control');

        $this->assertStringNotContainsString('public', (string) $cacheControl);
    }

    public function test_a_player_saves_a_language(): void
    {
        $player = $this->player();
        $this->actingAs($player, 'web');

        $this->saveLocale('en')->assertOk()->assertJsonPath('data.locale', 'en');

        $this->assertSame(LocalePreference::EN, $player->fresh()->locale);
    }

    public function test_a_language_can_be_saved_with_the_flag_off_without_any_effect(): void
    {
        $player = $this->player();
        $this->actingAs($player, 'web');

        $this->saveLocale('en')->assertOk();

        $this->withHeader('Accept-Language', 'en')->get('/games')->assertSee('<html lang="fr">', false);
    }

    /** @return array<string, array{mixed}> */
    public static function refusedLanguages(): array
    {
        return ['unknown' => ['klingon'], 'empty' => [''], 'absent' => [null], 'a list' => [['en']]];
    }

    #[DataProvider('refusedLanguages')]
    public function test_a_language_that_does_not_exist_is_refused(mixed $locale): void
    {
        $player = $this->player(LocalePreference::FR);
        $this->actingAs($player, 'web');

        $this->saveLocale($locale)->assertStatus(422);

        $this->assertSame(LocalePreference::FR, $player->fresh()->locale);
    }

    public function test_a_visitor_cannot_save_a_language(): void
    {
        $this->saveLocale('en')->assertUnauthorized();
    }

    public function test_only_the_player_sees_his_language(): void
    {
        $player = $this->player(LocalePreference::EN);
        $other = $this->player();
        $this->actingAs($other, 'web');

        $this->withHeader('Referer', config('app.url'))->getJson("/api/users/{$player->etwin_id}")
            ->assertJsonMissingPath('data.locale');
    }
}
