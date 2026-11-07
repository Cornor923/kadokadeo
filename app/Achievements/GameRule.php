<?php

namespace App\Achievements;

use App\Achievements\Events\GameRunCompleted;
use App\Enums\AchievementCategory;
use App\Models\UserAchievementProgress;
use WeakMap;

// A rule of the achievements of a game, read from the stats of its runs. Each game has its base rule
// (App\Achievements\Rules\Games\<Game>\<Game>Rule): its validate() says whether the stats of a run can be read (once by
// run, for all the rules of the game), then each rule gives its progress().
abstract class GameRule implements AchievementRule
{
    // the game_key of the game (App\Models\Game::getGameKeyAttribute)
    protected const GAME = '';

    /** @var array<string, WeakMap<GameRunCompleted, bool>> by game */
    private static array $validated = [];

    abstract public function validate(GameRunCompleted $event): bool;

    abstract protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult;

    public function category(): AchievementCategory
    {
        return AchievementCategory::GAME;
    }

    public function gameKey(): ?string
    {
        return static::GAME;
    }

    public function supports(object $event): bool
    {
        return $event instanceof GameRunCompleted && $event->gameKey() === static::GAME;
    }

    final public function evaluate(object $event, UserAchievementProgress $progress): AchievementRuleResult
    {
        if (!$event instanceof GameRunCompleted || !$this->isValid($event)) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return $this->progress($event, $progress);
    }

    // a value reached in one run: the best one is kept
    protected function best(UserAchievementProgress $progress, int $value): AchievementRuleResult
    {
        if ($value <= $progress->current_value) {
            return AchievementRuleResult::unchanged($progress->current_value);
        }

        return AchievementRuleResult::setProgress($value);
    }

    private function isValid(GameRunCompleted $event): bool
    {
        self::$validated[static::GAME] ??= new WeakMap();

        return self::$validated[static::GAME][$event] ??= $this->validate($event);
    }
}
