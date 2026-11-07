<?php

namespace App\Enums;

use Filament\Support\Contracts\HasLabel;

enum AchievementCategory: string implements HasLabel
{
    case GLOBAL = 'global';
    case GAME = 'game';
    case SEASONAL = 'seasonal';

    public function getLabel(): string
    {
        return match ($this) {
            self::GLOBAL => 'Tous les jeux',
            self::GAME => 'Jeu',
            self::SEASONAL => 'Période',
        };
    }
}
