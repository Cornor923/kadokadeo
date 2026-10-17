<?php

namespace App\Enums;

use Filament\Support\Contracts\HasLabel;

// the rank of a member in his clan: the leader (a single one, clans.leader_id) can do everything, a right hand everything
// but disband the clan (App\Services\ClanService::assertManager)
enum ClanRole: string implements HasLabel
{
    case LEADER = 'leader';
    case RIGHT_HAND = 'right_hand';
    case MEMBER = 'member';

    public function getLabel(): string
    {
        return match ($this) {
            self::LEADER => 'Chef de clan',
            self::RIGHT_HAND => 'Bras droit',
            self::MEMBER => 'Membre',
        };
    }

    public function canManage(): bool
    {
        return $this !== self::MEMBER;
    }
}
