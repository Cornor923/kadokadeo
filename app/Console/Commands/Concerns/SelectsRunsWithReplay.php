<?php

namespace App\Console\Commands\Concerns;

use App\Models\Game;
use App\Models\Run;
use App\Support\ReplayHeader;
use Illuminate\Support\Collection;

trait SelectsRunsWithReplay
{
    /**
     * The latest runs of a game with a replay the game can read (not the replays emptied by an export of the database,
     * "936 bytes"...).
     *
     * @param  callable(mixed): mixed|null  $scope  more conditions on the query
     * @param  callable(Run): mixed|null  $map  what is kept of a run (the replays of thousands of runs are heavy)
     */
    private function latestRunsWithReplay(Game $game, int $limit, ?callable $scope = null, ?callable $map = null): Collection
    {
        $runs = collect();
        $skipped = 0;
        Run::query()
            ->where('game_id', $game->id)
            ->whereNotNull('completed_at')
            ->whereNotNull('replay')
            ->when($scope, fn ($q) => $scope($q))
            ->with('user', 'game', 'gameBuild')
            ->orderByDesc('completed_at')
            ->orderByDesc('id')
            ->chunk(200, function ($chunk) use ($limit, $runs, $map, &$skipped) {
                foreach ($chunk as $run) {
                    if (ReplayHeader::parse($run->replay) === null) {
                        $skipped++;

                        continue;
                    }
                    $runs->push($map ? $map($run) : $run);
                    if ($runs->count() >= $limit) {
                        return false;
                    }
                }
            });
        if ($skipped > 0) {
            $this->warn("{$skipped} partie(s) sans replay lisible ignorée(s).");
        }

        return $runs;
    }
}
