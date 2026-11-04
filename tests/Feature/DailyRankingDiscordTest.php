<?php

namespace Tests\Feature;

use App\Models\DailyGame;
use App\Models\Game;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Services\DailyRankingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Schema;
use Spatie\DiscordAlerts\Jobs\SendToDiscordChannelJob;
use Tests\TestCase;

// the message of the daily ranking on Discord (one by period, when it closes), and the game of a day created once
class DailyRankingDiscordTest extends TestCase
{
    use RefreshDatabase;

    private Game $game;

    protected function setUp(): void
    {
        parent::setUp();
        Bus::fake([SendToDiscordChannelJob::class]);
        config(['discord-alerts.webhook_urls.scores' => 'https://discord.test/webhook']);
        $this->game = Game::factory()->create(['is_active' => true, 'stars' => [1000, 2000, 3000]]);
    }

    private function dailyGame(string $day): DailyGame
    {
        return DailyGame::query()->create([
            'day' => $day,
            'game_id' => $this->game->id,
            'seed' => 'seed',
            'contract_score' => 100,
            'contract_points' => 10,
        ]);
    }

    private function finishedPeriod(): Period
    {
        return Period::factory()->create(['start_at' => '2026-10-05 00:00:00', 'end_at' => '2026-10-18 23:59:59']);
    }

    private function dailyRun(DailyGame $dailyGame, User $user, int $score): Run
    {
        return Run::factory()->for($this->game)->for($user)->create(['period_id' => null, 'daily_game_id' => $dailyGame->id, 'score' => $score]);
    }

    private function message(): string
    {
        $text = null;
        Bus::assertDispatched(SendToDiscordChannelJob::class, function (SendToDiscordChannelJob $job) use (&$text) {
            $text = $job->text;

            return true;
        });

        return $text;
    }

    public function test_the_close_sends_one_message_with_the_final_top_10(): void
    {
        $period = $this->finishedPeriod();
        $players = User::factory()->count(11)->sequence(fn ($sequence) => ['display_name' => 'Joueur'.($sequence->index + 1)])->create()->values();
        $dailyGame = $this->dailyGame('2026-10-05');
        foreach ($players->take(10) as $index => $player) {
            $this->dailyRun($dailyGame, $player, 1000 - $index);
        }
        // (11th of the first day: no points)
        $this->dailyRun($dailyGame, $players[10], 10);

        $service = app(DailyRankingService::class);
        $service->closePeriod($period);
        $service->closePeriod($period);

        Bus::assertDispatchedTimes(SendToDiscordChannelJob::class, 1);
        $message = $this->message();
        $this->assertStringContainsString('classement final, période du 05/10 au 18/10', $message);
        $this->assertStringContainsString(':first_place: **Joueur1** : 10 pts', $message);
        $this->assertStringContainsString(':second_place: **Joueur2** : 9 pts', $message);
        $this->assertStringContainsString(':third_place: **Joueur3** : 8 pts', $message);
        $this->assertStringContainsString('10. **Joueur10** : 1 pts', $message);
        $this->assertStringNotContainsString('Joueur11', $message);
    }

    public function test_the_command_of_the_new_period_pays_and_sends_the_message(): void
    {
        $this->travelTo('2026-10-19 00:00:30');
        $period = $this->finishedPeriod();
        $player = User::factory()->create(['kado_points' => 0]);
        $this->dailyRun($this->dailyGame('2026-10-18'), $player, 900);

        $this->artisan('kado:prepare-new-period')->assertSuccessful();

        $this->assertSame(100, (int) $player->fresh()->kado_points);
        $this->assertSame(1, $period->dailyRankingResults()->count());
        Bus::assertDispatchedTimes(SendToDiscordChannelJob::class, 1);
    }

    public function test_the_game_of_a_new_day_sends_nothing(): void
    {
        $yesterday = $this->dailyGame(now()->subDay()->toDateString());
        $this->dailyRun($yesterday, User::factory()->create(), 900);

        $this->artisan('kado:prepare-daily-game')->assertSuccessful();

        Bus::assertNotDispatched(SendToDiscordChannelJob::class);
    }

    public function test_nothing_is_sent_without_a_webhook_or_without_a_player(): void
    {
        app(DailyRankingService::class)->closePeriod($this->finishedPeriod());
        Bus::assertNotDispatched(SendToDiscordChannelJob::class);

        config(['discord-alerts.webhook_urls.scores' => null]);
        $period = Period::factory()->create(['start_at' => '2026-10-19 00:00:00', 'end_at' => '2026-11-01 23:59:59']);
        $this->dailyRun($this->dailyGame('2026-10-19'), User::factory()->create(), 900);
        app(DailyRankingService::class)->closePeriod($period);
        Bus::assertNotDispatched(SendToDiscordChannelJob::class);
    }

    public function test_a_name_can_neither_ping_nor_format_the_message(): void
    {
        $period = $this->finishedPeriod();
        $this->dailyRun($this->dailyGame('2026-10-05'), User::factory()->create(['display_name' => '@everyone *_x_* [a](https://b.c) <#1> :e:']), 900);

        app(DailyRankingService::class)->closePeriod($period);

        $this->assertStringContainsString("@\u{200B}everyone \\*\\_x\\_\\* \\[a\\]\\(https\\://b.c\\) \\<#1\\> \\:e\\:", $this->message());
    }

    public function test_the_message_stays_under_the_limit_of_discord(): void
    {
        $period = $this->finishedPeriod();
        // every player tied on the first place (one day each): more lines than the top 10, with long names
        foreach (range(5, 18) as $day) {
            $this->dailyRun($this->dailyGame(sprintf('2026-10-%02d', $day)), User::factory()->create(), 900);
        }
        User::query()->update(['display_name' => str_repeat('@', 20).str_repeat('x', 200)]);

        app(DailyRankingService::class)->closePeriod($period);

        $this->assertLessThanOrEqual(2000, mb_strlen($this->message()));
    }

    public function test_a_day_has_one_game(): void
    {
        $first = DailyGame::createOrFirst(['day' => today()], ['game_id' => $this->game->id, 'seed' => 'a', 'contract_score' => 1, 'contract_points' => 1]);
        $second = DailyGame::createOrFirst(['day' => today()], ['game_id' => Game::factory()->create()->id, 'seed' => 'b', 'contract_score' => 2, 'contract_points' => 2]);

        $this->assertTrue($first->wasRecentlyCreated);
        $this->assertFalse($second->wasRecentlyCreated);
        $this->assertSame($first->id, $second->id);
        $this->assertSame(1, DailyGame::query()->count());
    }

    public function test_the_migration_keeps_the_first_game_of_a_day(): void
    {
        $migration = require database_path('migrations/2026_11_04_000001_make_daily_games_day_unique.php');
        $migration->down();

        $kept = $this->dailyGame('2026-10-05');
        $sameGame = $this->dailyGame('2026-10-05');
        $otherGame = DailyGame::query()->create(['day' => '2026-10-05', 'game_id' => Game::factory()->create()->id, 'seed' => 's', 'contract_score' => 1, 'contract_points' => 1]);
        $other = $this->dailyGame('2026-10-06');
        $moved = $this->dailyRun($sameGame, User::factory()->create(), 1);
        $detached = Run::factory()->for($otherGame->game)->for(User::factory())->create(['period_id' => null, 'daily_game_id' => $otherGame->id]);

        $migration->up();

        $this->assertSame([$kept->id, $other->id], DailyGame::query()->orderBy('id')->pluck('id')->all());
        $this->assertSame($kept->id, $moved->fresh()->daily_game_id);
        $this->assertNull($detached->fresh()->daily_game_id);
        $this->assertTrue(Schema::hasIndex('daily_games', ['day'], 'unique'));
    }
}
