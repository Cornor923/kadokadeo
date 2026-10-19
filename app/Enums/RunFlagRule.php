<?php

namespace App\Enums;

use Filament\Support\Contracts\HasLabel;
use Illuminate\Support\Number;

// why a run is in the queue of the suspicious runs (App\Services\SuspicionService)
enum RunFlagRule: string implements HasLabel
{
    // a score above the record of the game
    case WORLD_RECORD = 'world_record';
    // (no longer evaluated, 2026-10: kept for the flags already in the queue) a score far above the other runs of the
    // player on this game / a new best score of the player among the best scores of the game
    case SCORE_ABOVE_HISTORY = 'score_above_history';
    case SCORE_TOP_PERCENTILE = 'score_top_percentile';
    // more frames in the replay than the time between the beginning and the end of the run: a clock sped up
    case FASTER_THAN_REAL_TIME = 'faster_than_real_time';
    // far fewer frames than the time of the run: the game slowed down (off by default, see kado.suspicion)
    case SLOW_MOTION = 'slow_motion';
    // the game detected a script of the page (soft bits of App\Enums\AntiCheatBit)
    case CLIENT_DETECTION = 'client_detection';
    // the analyzer of the game found the moves suspicious (resources/js/replay-verifier/analyzers)
    case GAME_ANALYSIS = 'game_analysis';
    // the verifier could not play the replay to its end (the game crashed, the replay never ends, timeout...): its score
    // is not proven (a forged replay can make the game crash), an admin decides (App\Jobs\VerifyRunReplay)
    case REPLAY_UNVERIFIABLE = 'replay_unverifiable';

    public function getLabel(): string
    {
        return match ($this) {
            self::WORLD_RECORD => 'Record du jeu battu',
            self::SCORE_ABOVE_HISTORY => 'Score très au-dessus de ses parties',
            self::SCORE_TOP_PERCENTILE => 'Record dans le haut du classement',
            self::FASTER_THAN_REAL_TIME => 'Partie plus longue que le temps réel',
            self::SLOW_MOTION => 'Partie ralentie',
            self::CLIENT_DETECTION => 'Détection du client',
            self::GAME_ANALYSIS => 'Analyse des coups',
            self::REPLAY_UNVERIFIABLE => 'Replay impossible à vérifier',
        };
    }

    // the details of a flag of this rule, for the admin
    public function describe(?array $details): string
    {
        $details ??= [];
        $n = fn ($v) => Number::format((float) ($v ?? 0), maxPrecision: 1, locale: 'fr');

        return match ($this) {
            self::WORLD_RECORD => sprintf('Ancien record : %s', $n($details['previous_record'] ?? null)),
            self::SCORE_ABOVE_HISTORY => sprintf('Médiane de ses %s dernières parties : %s', $details['runs'] ?? '?', $n($details['median'] ?? null)),
            self::SCORE_TOP_PERCENTILE => sprintf('Seuil du top %s %% : %s (meilleur score précédent : %s)', $n((1 - ($details['percentile'] ?? 1)) * 100), $n($details['threshold'] ?? null), $n($details['previous_best'] ?? null)),
            self::FASTER_THAN_REAL_TIME, self::SLOW_MOTION => sprintf('Durée du replay : %s s, temps réel : %s s', $n($details['game_seconds'] ?? null), $n($details['real_seconds'] ?? null)),
            self::CLIENT_DETECTION => AntiCheatBit::describe((int) ($details['bits'] ?? 0)),
            self::GAME_ANALYSIS => implode(' ; ', $details['reasons'] ?? []) ?: 'Coups suspects',
            self::REPLAY_UNVERIFIABLE => sprintf('Erreur du vérificateur : %s', $details['error'] ?? '?'),
        };
    }
}
