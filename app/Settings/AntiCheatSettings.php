<?php

namespace App\Settings;

use Spatie\LaravelSettings\Settings;

// the anti cheat: what marks a run as cheated, the queue of the suspicious runs (App\Services\SuspicionService), the
// replay verifier and its analyzers of the moves (App\Services\ReplayVerifier), changed from the admin panel
// (App\Filament\Pages\ManageAntiCheatSettings)
class AntiCheatSettings extends Settings
{
    // ---------------------------------------------------------------- replays

    // a replay of a run outside the daily game must have its draws stirred by the frames and the inputs
    // (App\Support\ReplayHeader::FLAG_RNG_STIR), otherwise the run is marked as cheated. To turn on once the pages opened
    // before the deployment of the games with the stir are gone (a day or two).
    public bool $require_rng_stir;

    // ... and the time of the inputs in their frame (replay version 4, App\Support\ReplayHeader::FLAG_INPUT_PHASES). Same:
    // to turn on a day or two after the deployment of the games that record it.
    public bool $require_input_phases;

    // ---------------------------------------------------------------- detections of the game

    // the bits of what the game detected during a run (App\Enums\AntiCheatBit) that don't mark it as cheated, but put it
    // in the queue of the suspicious runs. 0: any bit marks the run as cheated.
    public int $soft_bits;

    // the bits that neither mark the run as cheated nor put it in the queue (they win over soft_bits): kept on the run
    // only (by default the functions of the browser replaced and the inputs made by a script, raised by most of the
    // mobile browsers)
    public int $ignored_bits;

    // ---------------------------------------------------------------- queue of the suspicious runs

    public bool $suspicion_enabled;

    // a score above the record of the game (all the periods), once it has game_min_runs finished runs. A high score alone
    // is not looked at: too many legit runs in the queue
    public bool $suspicion_world_record;

    public int $suspicion_game_min_runs;

    // the frames of the replay (32 by second) can't be more than the time of the run on the server
    public float $suspicion_wall_clock_tolerance;

    public int $suspicion_wall_clock_margin_seconds;

    // far fewer frames than the time of the run (the time on the intro and contract screens counts too: off)
    public bool $suspicion_slow_motion;

    public float $suspicion_slow_ratio;

    public int $suspicion_slow_min_seconds;

    // ---------------------------------------------------------------- replay verifier

    // the replays of the runs that count (personal best, contract, daily game, clan) are played again on the server in a
    // headless Chrome to check their score (App\Jobs\VerifyRunReplay): needs Node 22+ and Chrome (config kado.replay_verifier)
    public bool $verifier_enabled;

    // seconds
    public int $verifier_timeout;

    // game keys whose replay sometimes ends differently from the live game (determinism bugs): a different score is
    // reported, not sanctioned
    public array $verifier_untrusted_games;

    // ---------------------------------------------------------------- analyzers of the moves

    // the analyzers of the moves of a game (resources/js/replay-verifier/analyzers/<game_key>.mjs), run by the verifier:
    // their result is kept with the verification, and puts the run in the queue of the suspicious runs once `flag` is on
    // (calibrate the thresholds first: php artisan kado:replays:analyze <game>)
    public bool $analysis_enabled;

    public bool $analysis_flag;

    // share of the runs not verified otherwise (not a best score, a contract, the daily game) verified anyway for their
    // analysis, for the games with an analyzer (0 to 1)
    public float $analysis_sample_rate;

    // the thresholds of the analyzers: [{game: game_key, params: {name: value}}] (a KeyValue of the admin: the values are
    // strings once edited, see analysisConfig)
    public array $analysis_games;

    public static function group(): string
    {
        return 'anticheat';
    }

    public function isUntrustedGame(string $key): bool
    {
        return in_array($key, $this->verifier_untrusted_games, true);
    }

    /**
     * The config of the analyzer of a game (`config` of its create()), numbers and booleans typed. A game without
     * thresholds gets none: the analyzer takes its defaults.
     *
     * @return array<string, mixed>
     */
    public function analysisConfig(string $key): array
    {
        $row = collect($this->analysis_games)->first(fn ($row) => is_array($row) && ($row['game'] ?? null) === $key);

        return collect($row['params'] ?? [])
            ->filter(fn ($value, $name) => is_string($name) && $name !== '')
            ->map(fn ($value) => self::typed($value))
            ->all();
    }

    private static function typed(mixed $value): mixed
    {
        if (!is_string($value)) {
            return $value;
        }
        $value = trim($value);

        return match (true) {
            $value === 'true' => true,
            $value === 'false' => false,
            preg_match('/^-?\d+$/', $value) === 1 => (int) $value,
            is_numeric($value) => (float) $value,
            default => $value,
        };
    }
}
