<?php

namespace App\Enums;

// a clan run asked by a player, bound to the next run he begins on the game (App\Services\ClanService::bindRun)
enum ClanActionType: string
{
    case ATTACK = 'attack';
    case DEFENSE = 'defense';
    case MISSION = 'mission';

    public function label(): string
    {
        return match ($this) {
            self::ATTACK => 'Attaque',
            self::DEFENSE => 'Défense',
            self::MISSION => 'Étape de mission',
        };
    }
}
