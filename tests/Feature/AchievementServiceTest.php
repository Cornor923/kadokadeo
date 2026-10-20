<?php

namespace Tests\Feature;

use App\Achievements\Events\GameRunCompleted;
use App\Enums\AchievementCategory;
use App\Enums\AchievementProgressScope;
use App\Models\Achievement;
use App\Models\Game;
use App\Models\Run;
use App\Models\User;
use App\Models\UserAchievementProgress;
use App\Services\AchievementService;
use App\Settings\SiteSettings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AchievementServiceTest extends TestCase
{
    use RefreshDatabase;

    // another run of the player saved its progress after it was read: the progress is read again under its lock,
    // the next level reached once and paid once (not the level of the other run a second time)
    public function test_the_progress_is_computed_from_the_locked_row(): void
    {
        $this->setSettings(SiteSettings::class, ['achievements_enabled' => true]);
        $user = User::factory()->create(['kado_points' => 0]);
        $game = Game::factory()->create();
        $run = Run::factory()->for($game)->for($user)->create();
        $achievement = Achievement::query()->create([
            'key' => 'games_played',
            'category' => AchievementCategory::GLOBAL,
            'progress_scope' => AchievementProgressScope::LIFETIME,
        ]);
        $achievement->levels()->create(['level' => 1, 'target' => 1, 'reward' => 100, 'title' => 'Une partie', 'description' => 'Jouer une partie.']);
        $achievement->levels()->create(['level' => 2, 'target' => 2, 'reward' => 200, 'title' => 'Deux parties', 'description' => 'Jouer deux parties.']);
        $progress = UserAchievementProgress::query()->create([
            'user_id' => $user->id,
            'achievement_id' => $achievement->id,
            'scope_key' => 'lifetime',
            'current_value' => 0,
            'completed_level' => 0,
            'state' => [],
        ]);

        // the other run commits right after the first read
        $concurrent = false;
        UserAchievementProgress::retrieved(function () use (&$concurrent, $progress) {
            if (!$concurrent) {
                $concurrent = true;
                UserAchievementProgress::query()->whereKey($progress->id)->toBase()->update(['current_value' => 1, 'completed_level' => 1]);
            }
        });

        app(AchievementService::class)->handleGameRunCompleted(new GameRunCompleted($user, $game, $run, []));

        $this->assertTrue($concurrent);
        $progress->refresh();
        $this->assertSame(2, $progress->current_value);
        $this->assertSame(2, $progress->completed_level);
        $this->assertSame(200, $user->fresh()->kado_points);
        $this->assertSame([200], $user->userPoints()->where('reason', 'achievement')->pluck('delta')->all());
    }
}
