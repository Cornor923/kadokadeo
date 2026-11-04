<?php

namespace App\Enums;

use Filament\Support\Contracts\HasLabel;

// what a player visits the site with (App\Support\UserAgent)
enum DeviceType: string implements HasLabel
{
    case DESKTOP = 'desktop';
    case MOBILE = 'mobile';
    case TABLET = 'tablet';

    public function getLabel(): string
    {
        return match ($this) {
            self::DESKTOP => 'PC',
            self::MOBILE => 'Mobile',
            self::TABLET => 'Tablette',
        };
    }
}
