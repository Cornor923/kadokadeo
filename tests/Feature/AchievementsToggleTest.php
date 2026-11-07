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
use Database\Seeders\AchievementsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
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

    // read at each page: not a query by level
    public function test_the_api_lists_the_achievements_with_a_few_queries(): void
    {
        $this->setSettings(SiteSettings::class, ['achievements_enabled' => true]);
        $game = Game::factory()->create(['name' => 'Bactery']);
        $this->seed(AchievementsSeeder::class);
        Sanctum::actingAs(User::factory()->create());

        DB::enableQueryLog();
        $response = $this->getJson('/api/achievements')->assertOk();

        $this->assertLessThan(10, count(DB::getQueryLog()));
        $response->assertJsonPath('data.0.game', ['id' => $game->id, 'name' => 'Bactery']);
        $this->assertStringContainsString('/gfx/achievements/levels/bactery/', $response->json('data.0.levels.0.icon'));
    }

    public function test_the_end_of_a_run_reads_its_achievements_once(): void
    {
        $this->setSettings(SiteSettings::class, ['achievements_enabled' => true]);
        $game = Game::factory()->create(['name' => 'Bactery']);
        $this->seed(AchievementsSeeder::class);
        $user = User::factory()->create();
        $service = app(AchievementService::class);
        $event = fn () => new GameRunCompleted($user, $game, Run::factory()->for($game)->for($user)->create(), ['k' => 50, 'm' => 25, 'w' => 20, 'b' => 5]);
        $first = $event();
        $second = $event();
        $service->handleGameRunCompleted($first);

        DB::enableQueryLog();
        $service->handleGameRunCompleted($second);

        // (the event, the achievements with their levels and game, the locked progress, the 3 progresses that changed...)
        $this->assertLessThan(15, count(DB::getQueryLog()));
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
