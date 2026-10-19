<?php

namespace App\Enums;

use Filament\Support\Contracts\HasColor;
use Filament\Support\Contracts\HasLabel;

// a report (App\Models\Report): open until an admin ignores it or acts on the content (deleted)
enum ReportStatus: string implements HasColor, HasLabel
{
    case OPEN = 'open';
    case DISMISSED = 'dismissed';
    case ACTIONED = 'actioned';

    public function getLabel(): string
    {
        return match ($this) {
            self::OPEN => 'À examiner',
            self::DISMISSED => 'Ignoré',
            self::ACTIONED => 'Contenu supprimé',
        };
    }

    public function getColor(): string
    {
        return match ($this) {
            self::OPEN => 'warning',
            self::DISMISSED => 'gray',
            self::ACTIONED => 'danger',
        };
    }
}
