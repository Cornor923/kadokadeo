<?php

namespace Tests\Feature;

use App\Enums\AchievementCategory;
use App\Enums\AchievementProgressScope;
use App\Filament\Widgets\MaintenanceActions;
use App\Models\Achievement;
use App\Models\AchievementLevel;
use App\Models\Game;
use App\Models\User;
use App\Models\UserAchievementProgress;
use Database\Seeders\AchievementsSeeder;
use Filament\Facades\Filament;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class AchievementsSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_running_it_again_keeps_the_achievements_and_the_progress(): void
    {
        $game = Game::factory()->create(['name' => 'Xian-Xiang']);
        $this->seed(AchievementsSeeder::class);
        $achievementIds = Achievement::orderBy('id')->pluck('id')->all();
        $levelIds = AchievementLevel::orderBy('id')->pluck('id')->all();
        $progress = UserAchievementProgress::create([
            'user_id' => User::factory()->create()->id,
            'achievement_id' => $game->achievements()->where('key', 'total_tiles')->sole()->id,
            'game_id' => $game->id,
            'scope_key' => 'lifetime',
            'current_value' => 1234,
            'completed_level' => 1,
        ]);

        $this->seed(AchievementsSeeder::class);

        $this->assertSame($achievementIds, Achievement::orderBy('id')->pluck('id')->all());
        $this->assertSame($levelIds, AchievementLevel::orderBy('id')->pluck('id')->all());
        $this->assertSame(1234, $progress->fresh()->current_value);
        $this->assertSame(1, $progress->fresh()->completed_level);
    }

    public function test_it_updates_what_changed_and_adds_what_is_missing(): void
    {
        $game = Game::factory()->create(['name' => 'Xian-Xiang']);
        $this->seed(AchievementsSeeder::class);
        $level = $game->achievements()->where('key', 'total_tiles')->sole()->levels()->where('level', 2)->sole();
        $seeded = $level->only('reward', 'description', 'title');
        $level->update(['reward' => 1, 'description' => 'Ancien texte.', 'title' => 'Ancien titre']);
        $game->achievements()->where('key', 'min_score')->delete();

        $this->seed(AchievementsSeeder::class);

        $this->assertSame($seeded, $level->fresh()->only('reward', 'description', 'title'));
        $this->assertSame(1, $game->achievements()->where('key', 'min_score')->count());
    }

    public function test_it_creates_the_achievements_of_xian_xiang_from_a_table_with_others_already_there(): void
    {
        $game = Game::factory()->create(['name' => 'Xian-Xiang']);
        $game->achievements()->create(['key' => 'stars', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);

        $this->seed(AchievementsSeeder::class);

        $this->assertEqualsCanonicalizing(
            ['stars', 'paradise_league', 'total_tiles', 'perfect_neighbours', 'perfect_pairs', 'no_one_point_pair', 'min_score', 'perfect_colors'],
            $game->achievements()->pluck('key')->all(),
        );
    }

    public function test_the_admin_updates_the_achievements_without_deleting_them(): void
    {
        $game = Game::factory()->create(['name' => 'Xian-Xiang']);
        $this->seed(AchievementsSeeder::class);
        $achievement = $game->achievements()->where('key', 'total_tiles')->sole();
        $reward = $achievement->levels()->where('level', 1)->sole()->reward;
        $achievement->levels()->where('level', 1)->update(['reward' => $reward + 1]);
        Filament::setCurrentPanel(Filament::getPanel('admin'));

        Livewire::actingAs(User::factory()->create(['is_admin' => true]))
            ->test(MaintenanceActions::class)
            ->call('syncAchievements')
            ->assertNotified('Succès mis à jour.');

        $this->assertSame($reward, $achievement->levels()->where('level', 1)->sole()->reward);
        $this->assertNotNull($achievement->fresh());
    }
}
