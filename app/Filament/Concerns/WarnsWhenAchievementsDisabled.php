<?php

namespace App\Filament\Concerns;

use App\Settings\SiteSettings;

trait WarnsWhenAchievementsDisabled
{
    protected static function achievementsDisabledNotice(): ?string
    {
        if (app(SiteSettings::class)->achievements_enabled) {
            return null;
        }

        return '⚠️ Les succès sont désactivés globalement (Paramètres > Site) : aucune progression n\'est calculée et rien n\'est affiché aux joueurs.';
    }
}
