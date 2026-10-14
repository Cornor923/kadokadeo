<?php

namespace App\Filament;

use App\Enums\AntiCheatBit;

// what the admins must know of the settings of the anti cheat (config/kado.php)
class AntiCheatNotices
{
    // the checks of the replays turned off (banner on every page of the admin panel, AdminPanelProvider)
    /** @return list<string> */
    public static function disabledRequirements(): array
    {
        $notices = [];
        if (!config('kado.require_rng_stir')) {
            $notices[] = 'KADO_REQUIRE_RNG_STIR est désactivé : une partie dont le replay n’a pas les tirages mélangés par les frames (jeu modifié) n’est pas marquée comme triche.';
        }
        if (!config('kado.require_input_phases')) {
            $notices[] = 'KADO_REQUIRE_INPUT_PHASES est désactivé : une partie dont le replay n’a pas le moment des actions du joueur (replay version 4, jeu modifié) n’est pas marquée comme triche. À activer un ou deux jours après le déploiement des jeux.';
        }

        return $notices;
    }

    // which detections of the game mark a run as cheated, which ones put it in the queue (KADO_ANTICHEAT_SOFT_BITS) and
    // which ones are ignored (KADO_ANTICHEAT_IGNORED_BITS)
    public static function detectionRules(): string
    {
        $labels = fn (array $bits) => $bits ? implode(', ', array_map(fn (AntiCheatBit $bit) => $bit->getLabel(), $bits)) : 'aucune';

        return sprintf(
            'Marquées triche automatiquement : %s. Envoyées ici pour examen (KADO_ANTICHEAT_SOFT_BITS = 0x%X) : %s. Ignorées (KADO_ANTICHEAT_IGNORED_BITS = 0x%X) : %s. Les autres règles (score, temps réel, analyse des coups) ne sanctionnent jamais.',
            $labels(AntiCheatBit::hardCases()),
            AntiCheatBit::softMask(),
            $labels(AntiCheatBit::softCases()),
            AntiCheatBit::ignoredMask(),
            $labels(AntiCheatBit::ignoredCases()),
        );
    }
}
