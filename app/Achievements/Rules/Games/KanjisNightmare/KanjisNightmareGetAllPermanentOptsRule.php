<?php

namespace App\Achievements\Rules\Games\KanjisNightmare;

// the same count of permanent bonuses as get_three_permanent_opts, another target
class KanjisNightmareGetAllPermanentOptsRule extends KanjisNightmareGetThreePermanentOptsRule
{
    public function achievementKey(): string
    {
        return 'get_all_permanent_opts';
    }
}
