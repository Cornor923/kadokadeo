<?php

namespace Tests\Feature;

use App\Enums\AntiCheatBit;
use App\Filament\Pages\ManageAntiCheatSettings;
use App\Filament\Pages\ManageReplaySettings;
use App\Filament\Pages\ManageSiteSettings;
use App\Models\Game;
use App\Models\User;
use App\Services\ReplayVerifier;
use App\Settings\AntiCheatSettings;
use App\Settings\ReplaySettings;
use App\Settings\SiteSettings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

// the settings that were in the env until 2026-10 (config/kado.php), now in the admin panel
class SettingsPagesTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_thresholds_of_an_analyzer_are_typed(): void
    {
        $this->setSettings(AntiCheatSettings::class, ['analysis_games' => [
            ['game' => 'binary', 'params' => ['min_decisions' => '30', 'optimal_rate' => '0.8', 'strict' => 'true', 'off' => 'false', 'mode' => 'fast', '' => '1']],
        ]]);
        $settings = app(AntiCheatSettings::class);

        $this->assertSame(['min_decisions' => 30, 'optimal_rate' => 0.8, 'strict' => true, 'off' => false, 'mode' => 'fast'], $settings->analysisConfig('binary'));
        // no thresholds: the defaults of the analyzer
        $this->assertSame([], $settings->analysisConfig('kaskade2'));
    }

    public function test_the_analyzers_are_the_files_of_the_games(): void
    {
        $keys = ReplayVerifier::analyzerKeys();

        $this->assertContains('binary', $keys);
        $this->assertContains('kaskade2', $keys);
        $this->assertNotContains('binary.test', $keys);
    }

    public function test_the_admin_sets_the_anti_cheat(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));
        Game::factory()->create(['name' => 'Binary']);

        Livewire::test(ManageAntiCheatSettings::class)
            // the masks as their checked boxes
            ->assertSet('data.ignored_bits', ['64', '128'])
            ->set('data.soft_bits', [(string) AntiCheatBit::FOREIGN_DISPLAY_OBJECT->value, (string) AntiCheatBit::CODE_PATCHED->value])
            ->set('data.require_rng_stir', true)
            ->set('data.verifier_untrusted_games', ['binary'])
            ->set('data.analysis_games', [
                ['game' => 'binary', 'params' => ['min_decisions' => '40']],
            ])
            ->call('save')
            ->assertHasNoErrors();

        $settings = app(AntiCheatSettings::class)->refresh();
        $this->assertSame(0x12, $settings->soft_bits);
        $this->assertSame(0xC0, $settings->ignored_bits);
        $this->assertTrue($settings->require_rng_stir);
        $this->assertTrue($settings->isUntrustedGame('binary'));
        $this->assertSame(['min_decisions' => 40], $settings->analysisConfig('binary'));
        $this->assertSame([], $settings->analysisConfig('kaskade2'));
    }

    public function test_the_thresholds_are_kept_when_the_page_is_saved(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));

        Livewire::test(ManageAntiCheatSettings::class)->call('save')->assertHasNoErrors();

        $settings = app(AntiCheatSettings::class)->refresh();
        $this->assertSame(['min_decisions' => 25, 'optimal_rate' => 0.85, 'max_depth' => 3], $settings->analysisConfig('binary'));
        $this->assertSame(['min_decisions' => 15, 'optimal_rate' => 0.9, 'max_depth' => 3], $settings->analysisConfig('kaskade2'));
        $this->assertSame(0x3F0, $settings->soft_bits);
    }

    public function test_an_analyzer_has_one_row_only(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));

        Livewire::test(ManageAntiCheatSettings::class)
            ->set('data.analysis_games', [
                ['game' => 'binary', 'params' => []],
                ['game' => 'binary', 'params' => []],
            ])
            ->call('save')
            ->assertHasErrors();
    }

    public function test_the_admin_sets_the_games_of_the_site(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));

        Livewire::test(ManageSiteSettings::class)
            ->set('data.games_per_day', 25)
            ->set('data.achievements_enabled', true)
            ->set('data.theme_prices.karbon', 500)
            ->call('save')
            ->assertHasNoErrors();

        $settings = app(SiteSettings::class)->refresh();
        $this->assertSame(25, $settings->games_per_day);
        $this->assertTrue($settings->achievements_enabled);
        $this->assertSame(500, $settings->themePrice('karbon'));
        $this->assertSame(0, $settings->themePrice('base'));
        $this->assertSame(-1, $settings->themePrice('nope'));
    }

    public function test_a_replay_stays_under_the_limit_of_php(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]));

        Livewire::test(ManageReplaySettings::class)
            ->set('data.max_length', 20_000_000)
            ->call('save')
            ->assertHasErrors(['data.max_length']);

        Livewire::test(ManageReplaySettings::class)
            ->set('data.max_length', 5_000_000)
            ->call('save')
            ->assertHasNoErrors();
        $this->assertSame(5_000_000, app(ReplaySettings::class)->refresh()->max_length);
    }
}
