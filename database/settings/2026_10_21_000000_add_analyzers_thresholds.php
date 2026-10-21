<?php

use Illuminate\Support\Facades\Artisan;
use Spatie\LaravelSettings\Migrations\SettingsMigration;

// the thresholds of the analyzers of 12 more games (resources/js/replay-verifier/analyzers/<game>/), the same as the
// defaults of their create(). A game the admin already has a row for keeps it
return new class() extends SettingsMigration
{
    private const GAMES = [
        // the slides on a shortest way out (atlanteine/solver.mjs) without pushing a box (optimal_rate) or pushing it
        // (push_optimal_rate), over min_decisions real choices; instant_rate: slides started the frame the ball stops,
        // with the better of both rates >= instant_optimal_rate, over min_moves slides
        'atlanteine' => ['min_decisions' => 80, 'optimal_rate' => 0.98, 'push_optimal_rate' => 0.92, 'min_moves' => 50, 'instant_rate' => 0.6, 'instant_optimal_rate' => 0.85],
        // the stick (position, turn, side) with the most points certain from the board: bursts, falls, shaker
        // (autrement/solver.mjs); value_rate: points of the moves played / points of the best ones
        'autrement' => ['min_decisions' => 30, 'optimal_rate' => 0.65, 'value_rate' => 0.85],
        // the best swap (most points over all its rounds, among the swaps after which the game goes on), cascades
        // included (cookinglili/solver.mjs)
        'cookinglili' => ['min_decisions' => 20, 'optimal_rate' => 0.6, 'value_rate' => 0.7],
        // the best push of the 14, and the best looking 2 pushes ahead (lookahead_rate), certain points only
        // (flushee/solver.mjs)
        'flushee' => ['min_decisions' => 10, 'optimal_rate' => 0.95, 'lookahead_rate' => 0.95],
        // clicks in the solution of the board (lights out mod 3, tubulo/solver.mjs), over min_decisions clicks made on
        // boards still needing min_remaining clicks or more
        'tubulo' => ['min_decisions' => 60, 'optimal_rate' => 0.95, 'min_remaining' => 8],
        // the exact value of the mid/late game (max-weight matching bound + perfect line, xianxiang/solver.mjs): a perfect
        // run only on moves where a player errs min_expected_errors times on average (a safety net: a solver rarely
        // reaches it, an expert neither)
        'xianxiang' => ['min_decisions' => 15, 'optimal_rate' => 1.0, 'min_expected_errors' => 6, 'max_nodes' => 2000],

        // PROVISIONAL (no replay of real players to calibrate them on, 2026-10: harness bots only): check them with
        // kado:replays:analyze <game> in production before turning the flag on
        // the best click looking one or two moves ahead, chains of drops simulated frame by frame (aquasplash/solver.mjs),
        // on the clicks that discriminate. A perfect human may reach it
        'aquasplash' => ['min_decisions' => 25, 'optimal_rate' => 0.97],
        // the link of the sides made with the fewest clicks from the board shown (electrolink/solver.mjs)
        'electrolink' => ['min_decisions' => 20, 'optimal_rate' => 0.95, 'min_best' => 3, 'max_nodes' => 200],
        // impossible knowledge: second cards matching their pair while never seen (memopsy/memory.mjs), and the odds of
        // winning that many blind guesses (max_log10_p)
        'memopsy' => ['min_decisions' => 20, 'optimal_rate' => 0.6, 'max_guess_chance' => 0.34, 'min_level' => 1, 'bias_factor' => 3, 'max_log10_p' => -9],
        // the turn of the row scoring the most (chains, freed ice) when several turns score (paradice/solver.mjs)
        'paradice' => ['min_decisions' => 30, 'optimal_rate' => 0.98],
        // the longest path / the best looking two slices ahead (lookahead_rate), among close choices (razor/solver.mjs):
        // about 12 choices a game, a perfect game is asked. A patient expert may reach it
        'razor' => ['min_decisions' => 11, 'optimal_rate' => 1.0, 'lookahead_rate' => 0.9, 'close_ratio' => 0.6, 'max_depth' => 2],
        // an auto-player (no best move here): aimed presses on the same pixel of the toys / slots, share within
        // aim_tolerance px of the others of their kind >= optimal_rate, or pooled spread <= max_spread px
        // (toymaniak/presses.mjs)
        'toymaniak' => ['min_decisions' => 30, 'optimal_rate' => 0.7, 'max_spread' => 1.5, 'aim_tolerance' => 1, 'aim_min_distance' => 20, 'min_group' => 4],
    ];

    public function up(): void
    {
        $this->migrator->update('anticheat.analysis_games', function (array $rows) {
            $present = array_column($rows, 'game');
            foreach (self::GAMES as $game => $params) {
                if (!in_array($game, $present, true)) {
                    $rows[] = ['game' => $game, 'params' => $params];
                }
            }

            return $rows;
        });
        Artisan::call('settings:clear-cache');
    }

    public function down(): void
    {
        $this->migrator->update('anticheat.analysis_games',
            fn (array $rows) => array_values(array_filter($rows, fn ($row) => !array_key_exists($row['game'] ?? '', self::GAMES))));
        Artisan::call('settings:clear-cache');
    }
};
