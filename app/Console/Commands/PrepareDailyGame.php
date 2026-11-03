<?php

namespace App\Console\Commands;

use App\Events\DailyGameStarted;
use App\Models\DailyGame;
use App\Models\Game;
use App\Services\GameService;
use App\Support\Realtime;
use Illuminate\Console\Command;
use Spatie\DiscordAlerts\Facades\DiscordAlert;

class PrepareDailyGame extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'kado:prepare-daily-game';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Add a new daily game for today';

    protected $noRunsMessages = [
        "Pas de participants pour le jeu du jour d'hier. Peut-être que le jeu était nul ?",
        "Aucun score enregistré pour le jeu du jour d'hier. Si tu joues aujourd'hui tu as peut-être une chance de faire top 1 !",
        "Personne n'a joué au jeu du jour d'hier. Sois le premier aujourd'hui !",
        "Bon bah, personne n'a joué au jeu du jour d'hier... À toi de jouer aujourd'hui !",
        "Aucun score pour le jeu du jour d'hier. Tu pourrais bien être le premier aujourd'hui ! ...non?",
        "Spoiler: ||personne n'a joué au jeu du jour d'hier||. Tu as une chance de briller aujourd'hui !",
    ];

    protected $firstPlaceMessages = [
        'Victoire écrasante !',
        'Impressionnant !',
        'Chapeau bas, champion !',
        "T'as cheat ??",
    ];

    protected $secondPlaceMessages = [
        'Bien joué !',
        'Pas mal du tout !',
        "Tu t'es battu jusqu'au bout !",
        'La prochaine fois sera la bonne !',
    ];

    protected $thirdPlaceMessages = [
        'Bravo !',
        'Tu feras mieux demain...',
        'Continue comme ça !',
        'Honnêtement pas mal !',
    ];

    /**
     * Execute the console command.
     */
    public function handle()
    {
        // Check if a daily game already exists for today
        $existing = DailyGame::where('day', now()->today())->first();
        if ($existing) {
            $this->info('Daily game already exists for today.');
            $this->info("Game ID: {$existing->game_id} ({$existing->game->name}), Contract: {$existing->contract_score} for {$existing->contract_points} points.");

            return 0;
        }

        // Pick a random active game
        $game = Game::where('is_active', true)
            ->inRandomOrder()
            ->first();

        if (!$game) {
            $this->error('No active game found');

            return 1;
        }
        $gameService = app(GameService::class);

        [$contract, $points] = $gameService->getContract($game);
        $game->dailyGames()->create([
            'day' => now()->today(),
            'seed' => $gameService->generateSeed(),
            'contract_score' => $contract,
            'contract_points' => $points,
        ]);

        $this->info("Daily game for '{$game->name}' created: score {$contract} to win {$points} kado points.");
        Realtime::send(new DailyGameStarted());
        $this->sendTopScoresToDiscord();
    }

    public function sendTopScoresToDiscord()
    {
        $dailyGame = DailyGame::where('day', now()->yesterday())->first();
        if (!$dailyGame) {
            $this->info('No daily game found for yesterday.');

            return;
        }
        $game = $dailyGame->game;
        $topScores = $dailyGame->runs()
            ->whereNotNull('score')
            ->orderByDesc('score')
            ->take(3)
            ->get();

        $message = "Résultats du {$dailyGame->day->format('d/m/Y')} sur {$game->name}:\n";
        if ($topScores->isEmpty()) {
            $message .= $this->noRunsMessages[array_rand($this->noRunsMessages)];
        } else {
            foreach ($topScores as $index => $run) {
                $place = match ($index) {
                    0 => ':first_place:',
                    1 => ':second_place:',
                    2 => ':third_place:',
                    default => '',
                };
                $score = formatScore($run->score);
                $customMsg = match ($index) {
                    0 => $this->firstPlaceMessages[array_rand($this->firstPlaceMessages)],
                    1 => $this->secondPlaceMessages[array_rand($this->secondPlaceMessages)],
                    2 => $this->thirdPlaceMessages[array_rand($this->thirdPlaceMessages)],
                    default => '',
                };
                $message .= "{$place} **{$run->user->display_name}**: {$score} points. {$customMsg}\n";
            }
        }
        if (config('discord-alerts.webhook_urls.scores')) {
            DiscordAlert::to('scores')->message($message);
        }
    }
}
