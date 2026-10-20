<?php

namespace App\Filament;

use App\Enums\AntiCheatBit;
use App\Settings\AntiCheatSettings;

// what the admins must know of the settings of the anti cheat (App\Settings\AntiCheatSettings)
class AntiCheatNotices
{
    // the checks of the replays turned off (banner on every page of the admin panel, AdminPanelProvider)
    /** @return list<string> */
    public static function disabledRequirements(): array
    {
        $settings = app(AntiCheatSettings::class);
        $notices = [];
        if (!$settings->require_rng_stir) {
            $notices[] = 'Le mélange des tirages n’est pas exigé : une partie dont le replay n’a pas les tirages mélangés par les frames (jeu modifié) n’est pas marquée comme triche.';
        }
        if (!$settings->require_input_phases) {
            $notices[] = 'Le moment des actions n’est pas exigé : une partie dont le replay n’a pas le moment des actions du joueur (replay version 4, jeu modifié) n’est pas marquée comme triche. À activer un ou deux jours après le déploiement des jeux.';
        }

        return $notices;
    }

    // which detections of the game mark a run as cheated, which ones put it in the queue (soft_bits) and which ones are
    // ignored (ignored_bits)
    public static function detectionRules(): string
    {
        $labels = fn (array $bits) => $bits ? implode(', ', array_map(fn (AntiCheatBit $bit) => $bit->getLabel(), $bits)) : 'aucune';

        return sprintf(
            'Marquées triche automatiquement : %s. Envoyées ici pour examen : %s. Ignorées : %s. Les autres règles (score, temps réel, analyse des coups) ne sanctionnent jamais. Réglages : Paramètres > Anti-triche.',
            $labels(AntiCheatBit::hardCases()),
            $labels(AntiCheatBit::softCases()),
            $labels(AntiCheatBit::ignoredCases()),
        );
    }
}
