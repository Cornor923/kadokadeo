<?php

namespace App\Console\Commands;

use App\Models\Game;
use App\Models\Run;
use App\Services\ReplayVerifier;
use App\Support\ReplayHeader;
use Illuminate\Console\Command;

// ANTI CHEAT: the analyzer of a game (resources/js/replay-verifier/analyzers) on the replays of its past runs, to set
// its thresholds (admin « Paramètres > Anti-triche ») before its results put runs in the queue of the suspicious runs
class AnalyzeReplays extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'kado:replays:analyze {game : game_key of the game (binary...)} {--since= : runs finished since this date} {--limit=50 : number of runs (the latest)} {--user= : runs of this user id only}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Run the analyzer of a game on the replays of its runs and show its metrics (nothing is stored)';

    /**
     * Execute the console command.
     */
    public function handle(ReplayVerifier $verifier)
    {
        $key = (string) $this->argument('game');
        if (!$verifier->hasAnalyzer($key)) {
            $this->error("No analyzer for {$key} (resources/js/replay-verifier/analyzers/{$key}.mjs), or the analysis is off (admin « Paramètres > Anti-triche »).");

            return self::FAILURE;
        }
        $game = Game::all()->first(fn (Game $g) => $g->game_key === $key);
        if (!$game) {
            $this->error("No game {$key}.");

            return self::FAILURE;
        }

        // the latest runs with a replay the game can read (not the replays emptied by an export of the database,
        // "936 bytes"...)
        $limit = (int) $this->option('limit');
        $runs = collect();
        $skipped = 0;
        Run::query()
            ->where('game_id', $game->id)
            ->whereNotNull('completed_at')
            ->whereNotNull('replay')
            ->when($this->option('since'), fn ($q, $since) => $q->where('completed_at', '>=', $since))
            ->when($this->option('user'), fn ($q, $user) => $q->where('user_id', $user))
            ->with('user', 'game', 'gameBuild')
            ->orderByDesc('completed_at')
            ->orderByDesc('id')
            ->chunk(200, function ($chunk) use ($limit, $runs, &$skipped) {
                foreach ($chunk as $run) {
                    if (ReplayHeader::parse($run->replay) === null) {
                        $skipped++;

                        continue;
                    }
                    $runs->push($run);
                    if ($runs->count() >= $limit) {
                        return false;
                    }
                }
            });
        if ($skipped > 0) {
            $this->warn("{$skipped} partie(s) sans replay lisible ignorée(s).");
        }
        if ($runs->isEmpty()) {
            $this->info('Aucune partie avec un replay lisible.');

            return self::SUCCESS;
        }

        $rows = [];
        $rates = [];
        $this->withProgressBar($runs, function (Run $run) use ($verifier, &$rows, &$rates) {
            $result = $verifier->verify($run);
            $analysis = $result['analysis'] ?? null;
            $metrics = $analysis['metrics'] ?? [];
            $rate = $metrics['optimalRate'] ?? null;
            if ($rate !== null) {
                $rates[] = $rate;
            }
            $rows[] = [
                $run->id,
                $run->user?->display_name,
                $run->score,
                $run->is_cheat ? 'oui' : '',
                $metrics['decisions'] ?? '—',
                $rate ?? '—',
                $metrics['valueRate'] ?? '—',
                $metrics['medianDecisionFrames'] ?? '—',
                !$result['ok'] ? 'erreur : '.$result['error'] : ($analysis['error'] ?? (($analysis['suspicious'] ?? false) ? 'SUSPECT' : '')),
            ];
        });
        $this->newLine(2);

        $this->table(['Partie', 'Joueur', 'Score', 'Triche', 'Coups', 'Meilleur coup', 'Points / max', 'Temps médian (frames)', ''], $rows);

        if ($rates) {
            sort($rates);
            $at = fn (float $p) => $rates[(int) min(count($rates) - 1, floor($p * count($rates)))];
            $this->info(sprintf('Taux de meilleur coup sur %d parties : p50 %s, p90 %s, p99 %s, max %s', count($rates), $at(0.5), $at(0.9), $at(0.99), end($rates)));
        }

        return self::SUCCESS;
    }
}
