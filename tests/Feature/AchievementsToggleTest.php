<?php

namespace Tests\Feature;

use App\Achievements\Events\GameRunCompleted;
use App\Enums\AchievementCategory;
use App\Enums\AchievementProgressScope;
use App\Models\AchievementEvent;
use App\Models\Game;
use App\Models\Run;
use App\Models\User;
use App\Models\UserAchievementProgress;
use App\Services\AchievementService;
use App\Settings\SiteSettings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AchievementsToggleTest extends TestCase
{
    use RefreshDatabase;

    public function test_nothing_is_evaluated_when_achievements_are_disabled(): void
    {
        $this->setSettings(SiteSettings::class, ['achievements_enabled' => false]);
        [$user, $game, $run] = $this->runWithStarsAchievement();

        $updates = app(AchievementService::class)->handleGameRunCompleted(new GameRunCompleted($user, $game, $run, []));

        $this->assertSame([], $updates);
        $this->assertSame(0, AchievementEvent::count());
        $this->assertSame(0, UserAchievementProgress::count());
        $this->assertSame(0, $user->fresh()->kado_points);
    }

    public function test_achievements_progress_when_enabled(): void
    {
        $this->setSettings(SiteSettings::class, ['achievements_enabled' => true]);
        [$user, $game, $run] = $this->runWithStarsAchievement();

        $updates = app(AchievementService::class)->handleGameRunCompleted(new GameRunCompleted($user, $game, $run, []));

        $this->assertCount(1, $updates);
        $this->assertSame(1, AchievementEvent::count());
        $this->assertSame(1, UserAchievementProgress::sole()->completed_level);
        $this->assertSame(100, $user->fresh()->kado_points);
    }

    public function test_the_api_lists_no_achievement_when_disabled(): void
    {
        $this->setSettings(SiteSettings::class, ['achievements_enabled' => false]);
        $this->runWithStarsAchievement();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/achievements')->assertOk()->assertExactJson(['data' => []]);
    }

    /**
     * A run reaching the first star of a game that has a one level "stars" achievement.
     */
    private function runWithStarsAchievement(): array
    {
        $user = User::factory()->create(['kado_points' => 0]);
        $game = Game::factory()->create(['stars' => [10, 20, 30, 40]]);
        $run = Run::factory()->for($game)->for($user)->create(['score' => 15]);

        $achievement = $game->achievements()->create([
            'key' => 'stars',
            'category' => AchievementCategory::GAME,
            'progress_scope' => AchievementProgressScope::LIFETIME,
        ]);
        $achievement->levels()->create(['level' => 1, 'target' => 1, 'reward' => 100, 'title' => 'Étoile', 'description' => 'Obtenir une étoile.']);

        return [$user, $game, $run];
    }
}
