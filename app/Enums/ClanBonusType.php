<?php

namespace App\Enums;

use App\Settings\ClanSettings;
use Filament\Support\Contracts\HasLabel;

// the options of the missions (App\Services\ClanMissionService::useBonus): given to every clan at the start of the period
// (App\Settings\ClanSettings::$starting_bonuses), won by chance with the missions (bonus_chance / bonus_weights)
enum ClanBonusType: string implements HasLabel
{
    case MORE_TIME = 'more_time';
    case BAN_GAME = 'ban_game';
    case FORCE_GAME = 'force_game';
    case NEXT_MISSION = 'next_mission';
    case SKIP_STEP = 'skip_step';
    case DOUBLE_POINTS = 'double_points';

    public function getLabel(): string
    {
        return match ($this) {
            self::MORE_TIME => 'Plus de temps',
            self::BAN_GAME => 'Jeu caca',
            self::FORCE_GAME => 'Jeu cool',
            self::NEXT_MISSION => 'Mission suivante',
            self::SKIP_STEP => 'Passe étape',
            self::DOUBLE_POINTS => 'Double points',
        };
    }

    public function description(): string
    {
        return match ($this) {
            self::MORE_TIME => 'Repousse la fin de la mission de '.app(ClanSettings::class)->mission_more_time_hours.' heures pour avoir plus de temps pour la terminer.',
            self::BAN_GAME => 'Ajoute un jeu aux jeux caca du clan : ils ne seront jamais présents dans les futures missions de la période.',
            self::FORCE_GAME => 'Ajoute un jeu aux jeux cool du clan : ils seront présents dans les futures missions de la période (une partie d\'entre eux au hasard s\'il y en a plus que d\'étapes).',
            self::NEXT_MISSION => 'Annule la mission en cours, sans perdre de points, et génère une nouvelle mission.',
            self::SKIP_STEP => 'Supprime une étape au choix de votre mission.',
            self::DOUBLE_POINTS => 'La prochaine mission rapportera deux fois plus de points à votre clan si vous la réussissez.',
        };
    }

    public function icon(): string
    {
        return match ($this) {
            self::MORE_TIME => '/gfx/clan/opt/optMoreTime.gif',
            self::BAN_GAME => '/gfx/clan/opt/optBlacklistGame.gif',
            self::FORCE_GAME => '/gfx/clan/opt/optSelectGame.gif',
            self::NEXT_MISSION => '/gfx/clan/opt/optSkipMission.gif',
            self::SKIP_STEP => '/gfx/clan/opt/optSkipStep.gif',
            self::DOUBLE_POINTS => '/gfx/clan/opt/optDoublePoints.gif',
        };
    }
}
