<?php

namespace App\Services;

use App\Achievements\AchievementEventPayload;
use App\Achievements\AchievementRule;
use App\Achievements\Events\GameRunCompleted;
use App\Achievements\Events\LeagueChanged;
use App\Enums\AchievementCategory;
use App\Enums\AchievementProgressScope;
use App\Http\Resources\AchievementLevelResource;
use App\Models\Achievement;
use App\Models\AchievementEvent;
use App\Models\AchievementLevel;
use App\Models\Game;
use App\Models\User;
use App\Models\UserAchievementProgress;
use Illuminate\Support\Facades\DB;

class AchievementService
{
    /**
     * @param  iterable<AchievementRule>  $rules
     */
    public function __construct(private readonly iterable $rules) {}

    public function handleGameRunCompleted(GameRunCompleted $event): array
    {
        return $this->handle($event);
    }

    public function handleLeagueChanged(LeagueChanged $event): array
    {
        return $this->handle($event);
    }

    private function handle(AchievementEventPayload $event): array
    {
        if (!config('kado.achievements.enabled')) {
            return [];
        }

        return DB::transaction(function () use ($event) {
            if ($this->wasEventProcessed($event)) {
                return [];
            }

            $updates = [];

            foreach ($this->rules as $rule) {
                if (!$rule->supports($event)) {
                    continue;
                }

                $achievement = $this->findAchievement($rule, $event->game());
                if (!$achievement) {
                    continue;
                }

                $progress = $this->findOrCreateProgress($event->user(), $achievement, $event->periodId());
                if (!$progress) {
                    continue;
                }

                $beforeValue = $progress->current_value;
                $beforeLevel = $progress->completed_level;
                $result = $rule->evaluate($event, $progress);

                if (!$result->changed) {
                    continue;
                }

                $progress->current_value = $result->progress;
                if ($result->state !== null) {
                    $progress->state = $result->state;
                }
                $beforeLevel = $progress->completed_level;
                $this->updateCompletedLevel($progress, $achievement);
                if ($progress->completed_level > $beforeLevel) {
                    $this->grantLevelRewards($event->user(), $event->periodId(), $achievement, $beforeLevel, $progress->completed_level);
                }
                $progress->save();

                if ($progress->current_value !== $beforeValue || $progress->completed_level !== $beforeLevel) {
                    $updates[] = $this->makeUpdatePayload($achievement, $progress, $beforeValue, $beforeLevel);
                }
            }

            $this->markEventProcessed($event);

            return $updates;
        });
    }

    private function wasEventProcessed(AchievementEventPayload $event): bool
    {
        return AchievementEvent::query()
            ->where('event_type', $event::class)
            ->where('source_type', $event->sourceType())
            ->where('source_id', $event->sourceId())
            ->exists();
    }

    private function markEventProcessed(AchievementEventPayload $event): void
    {
        AchievementEvent::query()->create([
            'user_id' => $event->user()->id,
            'event_type' => $event::class,
            'source_type' => $event->sourceType(),
            'source_id' => $event->sourceId(),
            'processed_at' => now(),
        ]);
    }

    private function findAchievement(AchievementRule $rule, Game $game): ?Achievement
    {
        $query = Achievement::query()
            ->with('levels')
            ->where('key', $rule->achievementKey())
            ->where('category', $rule->category()->value)
            ->where('is_active', true);

        if ($rule->category() === AchievementCategory::GAME && $rule->gameKey() === null) {
            $query->where('game_id', $game->id);
        } elseif ($rule->gameKey() === null) {
            $query->whereNull('game_id');
        } else {
            $query->where('game_id', $game->id);
        }

        return $query->first();
    }

    private function findOrCreateProgress(User $user, Achievement $achievement, ?int $periodId): ?UserAchievementProgress
    {
        $periodId = $achievement->progress_scope === AchievementProgressScope::PER_PERIOD ? $periodId : null;

        if ($achievement->progress_scope === AchievementProgressScope::PER_PERIOD && $periodId === null) {
            return null;
        }

        $progress = UserAchievementProgress::query()->firstOrCreate([
            'user_id' => $user->id,
            'achievement_id' => $achievement->id,
            'scope_key' => $periodId === null ? 'lifetime' : 'period:'.$periodId,
        ], [
            'game_id' => $achievement->game_id,
            'period_id' => $periodId,
            'current_value' => 0,
            'completed_level' => 0,
            'state' => [],
        ]);

        // locked until the end of the transaction of handle(), read again: two runs of the player finished at once
        // progress one after the other (each from the value saved by the other, a level crossed and paid once)
        return UserAchievementProgress::query()->whereKey($progress->getKey())->lockForUpdate()->first();
    }

    private function updateCompletedLevel(UserAchievementProgress $progress, Achievement $achievement): void
    {
        $completedLevel = $achievement->levels
            ->where('target', '<=', $progress->current_value)
            ->max('level') ?? 0;

        $progress->completed_level = $completedLevel;

        if ($completedLevel > 0 && !$progress->completed_at) {
            $progress->completed_at = now();
        }
    }

    private function grantLevelRewards(User $user, ?int $periodId, Achievement $achievement, int $beforeLevel, int $afterLevel): void
    {
        $levels = $achievement->levels
            ->where('level', '>', $beforeLevel)
            ->where('level', '<=', $afterLevel);

        foreach ($levels as $level) {
            if ($level->reward > 0) {
                $user->increment('kado_points', $level->reward);
                $user->userPoints()->create([
                    'period_id' => $periodId,
                    'delta' => $level->reward,
                    'reason' => 'achievement',
                    'source_type' => AchievementLevel::class,
                    'source_id' => $level->id,
                ]);
            }
        }
    }

    private function makeUpdatePayload(Achievement $achievement, UserAchievementProgress $progress, int $beforeValue, int $beforeLevel): array
    {
        $currentLevel = $achievement->levels
            ->where('level', $progress->completed_level)
            ->first();
        $nextLevel = $achievement->levels
            ->where('level', '>', $progress->completed_level)
            ->sortBy('level')
            ->first();
        $unlockedLevels = $achievement->levels
            ->where('level', '>', $beforeLevel)
            ->where('level', '<=', $progress->completed_level)
            ->values();

        return [
            'id' => $achievement->id,
            'type' => $progress->completed_level > $beforeLevel ? 'unlocked' : 'progressed',
            'achievement_key' => $achievement->key,
            'category' => $achievement->category->value,
            'game_key' => $achievement->game?->game_key,
            'progress_before' => $beforeValue,
            'progress' => $progress->current_value,
            'completed_level_before' => $beforeLevel,
            'completed_level' => $progress->completed_level,
            'current_level' => $currentLevel ? AchievementLevelResource::make($currentLevel) : null,
            'next_level' => $nextLevel ? AchievementLevelResource::make($nextLevel) : null,
            'newly_unlocked_levels' => AchievementLevelResource::collection($unlockedLevels),
        ];
    }
}
