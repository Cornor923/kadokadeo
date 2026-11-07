<?php

namespace App\Achievements\Rules\Games\ZipZap;

use App\Achievements\AchievementRuleResult;
use App\Achievements\Events\GameRunCompleted;
use App\Models\UserAchievementProgress;

class ZipZapFiveThousandComboRule extends ZipZapRule
{
    public function achievementKey(): string
    {
        return 'five_thousand_combo';
    }

    protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        $max = 0;
        foreach (data_get($event->stats, 'pa', []) as $action) {
            $max = max($max, $action[4]);
        }

        return $this->best($progress, $max);
    }
}
