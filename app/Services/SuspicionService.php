<?php

namespace App\Services;

use App\Enums\AntiCheatBit;
use App\Enums\RunFlagRule;
use App\Models\Run;
use App\Models\RunFlag;
use App\Settings\AntiCheatSettings;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;

/**
 * ANTI CHEAT: a run whose inputs come from the player (its replay gives its score) can still be played with help (a
 * script showing the best move...). The runs that look like it go in the queue of the suspicious runs of the admin
 * (Runs suspectes): nothing is sanctioned here, an admin decides.
 */
class SuspicionService
{
    // frames of the game by second (kado.FixedFramerate)
    private const FRAMES_PER_SECOND = 32;

    public function __construct(private readonly AntiCheatSettings $settings) {}

    // a run just finished (App\Jobs\EvaluateRunSuspicion)
    public function evaluateFinishedRun(Run $run): void
    {
        if (!$this->settings->suspicion_enabled || $run->is_cheat || $run->completed_at === null) {
            return;
        }

        $this->checkClientDetections($run);
        $this->checkRealTime($run);
        $this->checkWorldRecord($run);
    }

    // the result of the analyzer of the game (App\Jobs\VerifyRunReplay)
    public function recordAnalysis(Run $run, ?array $analysis): void
    {
        if (!$analysis || !($analysis['suspicious'] ?? false) || !$this->settings->analysis_flag) {
            return;
        }
        $this->flag($run, RunFlagRule::GAME_ANALYSIS, 2, [
            'analyzer' => $analysis['analyzer'] ?? null,
            'metrics' => $analysis['metrics'] ?? [],
            'reasons' => $analysis['reasons'] ?? [],
        ]);
    }

    // the verifier could not play the replay of the run (App\Jobs\VerifyRunReplay): its score stays, an admin decides
    public function recordUnverifiable(Run $run, string $error): void
    {
        $this->flag($run, RunFlagRule::REPLAY_UNVERIFIABLE, 2, ['error' => Str::limit($error, 500)]);
    }

    private function checkClientDetections(Run $run): void
    {
        $bits = AntiCheatBit::softBits((int) $run->anticheat_flags);
        if ($bits !== 0) {
            $this->flag($run, RunFlagRule::CLIENT_DETECTION, 2, ['bits' => $bits]);
        }
    }

    // the time of the game (frames of its replay) against the time between its beginning and its end on the server: a
    // game can only be late (lag, tab hidden then caught up), not ahead
    private function checkRealTime(Run $run): void
    {
        if ($run->replay_frames === null || $run->play_time_seconds === null) {
            return;
        }
        $gameSeconds = $run->replay_frames / self::FRAMES_PER_SECOND;
        $realSeconds = (int) $run->play_time_seconds;
        $details = ['game_seconds' => round($gameSeconds, 1), 'real_seconds' => $realSeconds, 'frames' => $run->replay_frames];

        $allowed = $realSeconds * (1 + $this->settings->suspicion_wall_clock_tolerance) + $this->settings->suspicion_wall_clock_margin_seconds;
        if ($gameSeconds > $allowed) {
            $this->flag($run, RunFlagRule::FASTER_THAN_REAL_TIME, 3, $details);

            return;
        }

        if ($this->settings->suspicion_slow_motion
            && $gameSeconds < $realSeconds * $this->settings->suspicion_slow_ratio
            && $realSeconds - $gameSeconds > $this->settings->suspicion_slow_min_seconds) {
            $this->flag($run, RunFlagRule::SLOW_MOTION, 1, $details);
        }
    }

    // a high score alone is legit most of the time: only a new record of the game is looked at
    private function checkWorldRecord(Run $run): void
    {
        if (!$this->settings->suspicion_world_record || !$this->hasEnoughRuns($run->game_id)) {
            return;
        }
        $record = Run::query()
            ->where('game_id', $run->game_id)
            ->whereKeyNot($run->getKey())
            ->whereNotNull('completed_at')
            ->where('is_cheat', false)
            ->max('score');
        if ($record !== null && $run->score > $record) {
            $this->flag($run, RunFlagRule::WORLD_RECORD, 2, ['previous_record' => (int) $record, 'score' => $run->score]);
        }
    }

    // the game has game_min_runs finished runs (its first records mean nothing), kept an hour
    private function hasEnoughRuns(int $gameId): bool
    {
        return Cache::remember("suspicion:game-enough-runs:{$gameId}", 3600, fn () => Run::query()
            ->where('game_id', $gameId)
            ->whereNotNull('completed_at')
            ->where('is_cheat', false)
            ->count() >= $this->settings->suspicion_game_min_runs);
    }

    // one flag by run and rule: evaluated again, it is updated (its review is kept)
    private function flag(Run $run, RunFlagRule $rule, int $severity, array $details): RunFlag
    {
        return RunFlag::updateOrCreate(
            ['run_id' => $run->id, 'rule' => $rule],
            ['user_id' => $run->user_id, 'game_id' => $run->game_id, 'severity' => $severity, 'details' => $details],
        );
    }
}
