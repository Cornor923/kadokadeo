<?php

namespace App\Enums;

use Filament\Support\Contracts\HasLabel;

enum AchievementProgressScope: string implements HasLabel
{
    case LIFETIME = 'lifetime';
    case PER_PERIOD = 'per_period';

    public function getLabel(): string
    {
        return match ($this) {
            self::LIFETIME => 'Permanente',
            self::PER_PERIOD => 'Par période',
        };
    }
}
