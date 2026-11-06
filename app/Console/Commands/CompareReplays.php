<?php

namespace App\Console\Commands;

use App\Console\Commands\Concerns\SelectsRunsWithReplay;
use App\Models\Game;
use App\Models\Run;
use App\Services\ReplayVerifier;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Str;
use Symfony\Component\Process\Process;

// A game changed without changing its gameplay (stats for its achievements, a fix...) must play its old replays the
// same: they are played by the bundle of today (public/gamesdata) before the change (--baseline, kept in a file), then
// after the rebuild, and their scores and frames compared. The stats sent at the game over are in both files.
class CompareReplays extends Command
{
    use SelectsRunsWithReplay;

    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'kado:replays:compare {game : game_key of the game (xianxiang...)} {--baseline : record the reference, before changing the game} {--limit=1000 : number of runs of the reference (the latest)} {--parallel=4 : replays played at once} {--shard= : (internal) ids of the runs to play, one by line}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Compare the replays of a game played by its current bundle with a reference recorded before changing it (the database is not changed)';

    /**
     * Execute the console command.
     */
    public function handle(ReplayVerifier $verifier)
    {
        $key = (string) $this->argument('game');
        if ($this->option('shard')) {
            $this->playShard($verifier, $this->option('shard'));

            return self::SUCCESS;
        }
        $game = Game::all()->first(fn (Game $g) => $g->game_key === $key);
        if (!$game) {
            $this->error("No game {$key}.");

            return self::FAILURE;
        }

        return $this->option('baseline') ? $this->baseline($verifier, $game) : $this->compare($verifier, $game);
    }

    private function baseline(ReplayVerifier $verifier, Game $game): int
    {
        $ids = $this->latestRunsWithReplay($game, (int) $this->option('limit'), map: fn (Run $run) => $run->id)->all();
        if ($ids === []) {
            $this->info('Aucune partie avec un replay lisible.');

            return self::SUCCESS;
        }
        $results = $this->play($verifier, $game->game_key, $ids);
        File::put($this->baselineFile($game), json_encode(['bundle' => $this->bundleHash($game), 'runs' => $results], JSON_UNESCAPED_UNICODE));

        // what the replays give today against the database: not a change of this game, they are compared to themselves
        $runs = Run::query()->withoutReplay()->whereIn('id', $ids)->get()->keyBy('id');
        $failed = array_filter($results, fn (array $r) => !$r['ok']);
        $diverged = array_filter($results, fn (array $r, string $id) => $r['ok'] && (int) $r['score'] !== (int) $runs[$id]->score, ARRAY_FILTER_USE_BOTH);
        $otherStats = array_filter($results, fn (array $r, string $id) => $r['ok'] && ($r['stats'] ?? null) != $runs[$id]->score_details, ARRAY_FILTER_USE_BOTH);

        $this->info(count($ids).' partie(s) dans la référence : '.$this->baselineFile($game));
        $this->line(sprintf('Score de la base retrouvé : %d / %d. Stats de la base retrouvées : %d / %d.', count($ids) - count($failed) - count($diverged), count($ids), count($ids) - count($failed) - count($otherStats), count($ids)));
        foreach (array_slice($failed, 0, 5, true) as $id => $result) {
            $this->warn("{$id} : {$result['error']}");
        }
        foreach (array_slice($diverged, 0, 5, true) as $id => $result) {
            $this->warn("{$id} : score {$result['score']}, {$runs[$id]->score} en base");
        }

        return self::SUCCESS;
    }

    private function compare(ReplayVerifier $verifier, Game $game): int
    {
        $file = $this->baselineFile($game);
        if (!File::exists($file)) {
            $this->error("Pas de référence pour {$game->game_key} : à lancer avec --baseline avant de changer le jeu.");

            return self::FAILURE;
        }
        $baseline = json_decode(File::get($file), true);
        if ($baseline['bundle'] !== null && $baseline['bundle'] === $this->bundleHash($game)) {
            $this->warn('Le bundle est le même que celui de la référence : le jeu a-t-il été recompilé ?');
        }

        $results = $this->play($verifier, $game->game_key, array_keys($baseline['runs']));
        File::put(storage_path("app/replay-compare/{$game->game_key}.compare.json"), json_encode(['bundle' => $this->bundleHash($game), 'runs' => $results], JSON_UNESCAPED_UNICODE));

        $rows = [];
        $otherStats = 0;
        $example = null;
        foreach ($baseline['runs'] as $id => $before) {
            $now = $results[$id] ?? ['ok' => false, 'error' => 'pas de résultat'];
            if ($this->outcome($before) !== $this->outcome($now)) {
                $rows[] = [$id, $this->outcome($before), $this->outcome($now)];
            } elseif ($now['ok'] && ($now['stats'] ?? null) != ($before['stats'] ?? null)) {
                $otherStats++;
                $example ??= json_encode($before['stats'] ?? null).' -> '.json_encode($now['stats'] ?? null);
            }
        }

        if ($otherStats > 0) {
            $this->line("Stats envoyées différentes : {$otherStats} partie(s), par exemple {$example}.");
        }
        if ($rows !== []) {
            $this->table(['Partie', 'Avant', 'Après'], array_slice($rows, 0, 20));
            $this->error(count($rows).' partie(s) sur '.count($baseline['runs']).' ne se rejouent plus pareil.');

            return self::FAILURE;
        }
        $this->info(count($baseline['runs']).' partie(s) rejouée(s) à l’identique (score et frames).');

        return self::SUCCESS;
    }

    // how a replay ends: what must not change
    private function outcome(array $result): string
    {
        return $result['ok'] ? "score {$result['score']}, {$result['frames']} frames" : 'erreur : '.$result['error'];
    }

    /**
     * @param  list<string>  $ids
     * @return array<string, array<string, mixed>>
     */
    private function play(ReplayVerifier $verifier, string $key, array $ids): array
    {
        $bar = $this->output->createProgressBar(count($ids));
        $parallel = min((int) $this->option('parallel'), count($ids));
        if ($parallel > 1) {
            $results = $this->playInProcesses($key, $ids, $parallel, $bar->setProgress(...));
        } else {
            $results = [];
            foreach ($ids as $id) {
                $results[$id] = $this->playRun($verifier, $id);
                $bar->advance();
            }
        }
        $bar->finish();
        $this->newLine(2);

        return $results;
    }

    /**
     * @param  list<string>  $ids
     * @param  callable(int): mixed  $progress
     * @return array<string, array<string, mixed>>
     */
    private function playInProcesses(string $key, array $ids, int $parallel, callable $progress): array
    {
        $dir = storage_path('app/replay-compare/'.Str::random(16));
        File::ensureDirectoryExists($dir);
        try {
            $processes = [];
            foreach (array_chunk($ids, (int) ceil(count($ids) / $parallel)) as $i => $shard) {
                File::put("{$dir}/{$i}", implode("\n", $shard));
                // no timeout: each replay has the timeout of the verifier
                $processes[] = $process = new Process([PHP_BINARY, base_path('artisan'), $this->getName(), $key, "--shard={$dir}/{$i}"], base_path(), null, null, null);
                $process->start();
            }
            $read = function () use ($dir) {
                $lines = collect(File::glob("{$dir}/*.out"))->flatMap(fn (string $file) => file($file, FILE_IGNORE_NEW_LINES));

                return $lines->map(fn (string $line) => json_decode($line, true))->pluck('result', 'id')->all();
            };
            do {
                usleep(500_000);
                $running = array_filter($processes, fn (Process $process) => $process->isRunning());
                $progress(count($read()));
            } while ($running !== []);

            return $read();
        } finally {
            File::deleteDirectory($dir);
        }
    }

    private function playShard(ReplayVerifier $verifier, string $file): void
    {
        foreach (file($file, FILE_IGNORE_NEW_LINES) as $id) {
            File::append("{$file}.out", json_encode(['id' => $id, 'result' => $this->playRun($verifier, $id)])."\n");
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function playRun(ReplayVerifier $verifier, string $id): array
    {
        $run = Run::query()->with('game')->find($id);
        if (!$run) {
            return ['ok' => false, 'error' => 'partie introuvable'];
        }

        return $verifier->verify($run, ['stats' => true, 'analysis' => null], currentBundle: true);
    }

    private function baselineFile(Game $game): string
    {
        File::ensureDirectoryExists(storage_path('app/replay-compare'));

        return storage_path("app/replay-compare/{$game->game_key}.json");
    }

    private function bundleHash(Game $game): ?string
    {
        $bundle = public_path("gamesdata/{$game->game_key}.js");

        return File::exists($bundle) ? sha1_file($bundle) : null;
    }
}
