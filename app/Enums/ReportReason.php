<?php

namespace App\Enums;

use Filament\Support\Contracts\HasColor;
use Filament\Support\Contracts\HasLabel;

// why a player reports a content (App\Services\ReportService): the labels are shown to the players too
enum ReportReason: string implements HasColor, HasLabel
{
    case SPAM = 'spam';
    case ABUSE = 'abuse';
    case INAPPROPRIATE = 'inappropriate';
    case OTHER = 'other';

    public function getLabel(): string
    {
        return match ($this) {
            self::SPAM => 'Spam ou publicité',
            self::ABUSE => 'Insulte ou harcèlement',
            self::INAPPROPRIATE => 'Contenu inapproprié',
            self::OTHER => 'Autre',
        };
    }

    public function getColor(): string
    {
        return match ($this) {
            self::SPAM => 'gray',
            self::ABUSE => 'danger',
            self::INAPPROPRIATE => 'warning',
            self::OTHER => 'info',
        };
    }

    // for the form of the replay page: [{value, label}]
    public static function options(): array
    {
        return array_map(fn (self $reason) => ['value' => $reason->value, 'label' => $reason->getLabel()], self::cases());
    }
}
