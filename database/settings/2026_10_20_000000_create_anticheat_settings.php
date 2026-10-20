<?php

use Illuminate\Support\Facades\Artisan;
use Spatie\LaravelSettings\Migrations\SettingsMigration;

// the anti cheat settings, read from the env until now: it gives their first values (config kado.legacy)
return new class() extends SettingsMigration
{
    public function up(): void
    {
        $this->migrator->add('anticheat.require_rng_stir', (bool) (config('kado.legacy.require_rng_stir') ?? false));
        $this->migrator->add('anticheat.require_input_phases', (bool) (config('kado.legacy.require_input_phases') ?? false));

        $this->migrator->add('anticheat.soft_bits', intval((string) (config('kado.legacy.soft_bits') ?? 0x3F0), 0));
        $this->migrator->add('anticheat.ignored_bits', intval((string) (config('kado.legacy.ignored_bits') ?? 0xC0), 0));

        $this->migrator->add('anticheat.suspicion_enabled', (bool) (config('kado.legacy.suspicion_enabled') ?? true));
        $this->migrator->add('anticheat.suspicion_world_record', (bool) (config('kado.legacy.suspicion_world_record') ?? true));
        $this->migrator->add('anticheat.suspicion_game_min_runs', 200);
        $this->migrator->add('anticheat.suspicion_wall_clock_tolerance', 0.02);
        $this->migrator->add('anticheat.suspicion_wall_clock_margin_seconds', 5);
        $this->migrator->add('anticheat.suspicion_slow_motion', false);
        $this->migrator->add('anticheat.suspicion_slow_ratio', 0.4);
        $this->migrator->add('anticheat.suspicion_slow_min_seconds', 120);

        $this->migrator->add('anticheat.verifier_enabled', (bool) (config('kado.legacy.verifier_enabled') ?? false));
        $this->migrator->add('anticheat.verifier_timeout', (int) (config('kado.legacy.verifier_timeout') ?? 300));
        $this->migrator->add('anticheat.verifier_untrusted_games',
            array_values(array_filter(array_map('trim', explode(',', (string) (config('kado.legacy.verifier_untrusted_games') ?? ''))))));

        $this->migrator->add('anticheat.analysis_enabled', (bool) (config('kado.legacy.analysis_enabled') ?? true));
        $this->migrator->add('anticheat.analysis_flag', (bool) (config('kado.legacy.analysis_flag') ?? false));
        $this->migrator->add('anticheat.analysis_sample_rate', (float) (config('kado.legacy.analysis_sample_rate') ?? 0));
        $this->migrator->add('anticheat.analysis_games', [
            // suspicious: the best move (resources/js/replay-verifier/analyzers/binary/solver.mjs) at least optimal_rate of
            // the time, over min_decisions moves; max_depth: turns of a sequence looked at (the "misses" of the game)
            ['game' => 'binary', 'params' => ['min_decisions' => 25, 'optimal_rate' => 0.85, 'max_depth' => 3]],
            // the best move looking max_depth groups ahead (points certain from the board: the new balls are random), over
            // the 20 moves of a game (resources/js/replay-verifier/analyzers/kaskade2/solver.mjs)
            ['game' => 'kaskade2', 'params' => ['min_decisions' => 15, 'optimal_rate' => 0.9, 'max_depth' => 3]],
        ]);

        Artisan::call('settings:clear-cache');
    }

    public function down(): void
    {
        foreach ([
            'require_rng_stir', 'require_input_phases', 'soft_bits', 'ignored_bits',
            'suspicion_enabled', 'suspicion_world_record', 'suspicion_game_min_runs', 'suspicion_wall_clock_tolerance',
            'suspicion_wall_clock_margin_seconds', 'suspicion_slow_motion', 'suspicion_slow_ratio', 'suspicion_slow_min_seconds',
            'verifier_enabled', 'verifier_timeout', 'verifier_untrusted_games',
            'analysis_enabled', 'analysis_flag', 'analysis_sample_rate', 'analysis_games',
        ] as $name) {
            $this->migrator->delete("anticheat.{$name}");
        }
    }
};
