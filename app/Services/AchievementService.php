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
use App\Models\Run;
use App\Models\User;
use App\Models\UserAchievementProgress;
use App\Settings\SiteSettings;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
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
        if (!app(SiteSettings::class)->achievements_enabled) {
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

    /**
     * A run that should not have counted (cheated, deleted): what it gave to the achievements of its player is taken back,
     * levels and their rewards included. The runs counted (achievement_events) are played again with and without it, and
     * only the difference is taken: a level the run did not cross stays, even if its target was raised since. A run that
     * did not count takes nothing: called again, nothing more goes.
     */
    public function takeBackRun(Run $run): void
    {
        DB::transaction(function () use ($run) {
            $event = $this->runEvents($run->user_id)->where('source_id', (string) $run->id)->first();
            if (!$event) {
                return;
            }

            $user = User::query()->findOrFail($run->user_id);
            $game = Game::query()->findOrFail($run->game_id);
            $achievements = $this->replayableAchievements($game);
            // locked first: a run finishing now waits, or is in the runs read below
            $progresses = UserAchievementProgress::query()
                ->where('user_id', $user->id)
                ->whereIn('achievement_id', $achievements->pluck('id'))
                ->orderBy('id')
                ->lockForUpdate()
                ->get()
                ->keyBy('achievement_id');

            $runs = Run::query()->withTrashed()->withoutReplay()
                ->where('user_id', $user->id)
                ->where('game_id', $game->id)
                ->whereIn('id', $this->runEvents($user->id)->select('source_id'))
                ->orderBy('completed_at')
                ->orderBy('id')
                ->get();
            $with = $this->replayRuns($user, $game, $achievements, $runs);
            $without = $this->replayRuns($user, $game, $achievements, $runs->reject(fn (Run $other) => $other->is($run)));

            foreach ($achievements as $achievement) {
                $progress = $progresses->get($achievement->id);
                $counted = $with[$achievement->id] ?? null;
                if ($progress && $counted) {
                    $this->takeBackFrom($user, $run, $achievement, $progress, $counted, $without[$achievement->id] ?? null);
                }
            }

            $event->delete();
        }, 3);
    }

    // what the rules read in these stats is what they read in the stats of the run (the stats they don't read may differ:
    // Tubulo sends real times, a replay can't give them back)
    public function givesTheSame(Run $run, array $stats): bool
    {
        $user = new User();
        $game = Game::query()->findOrFail($run->game_id);
        $achievements = $this->replayableAchievements($game);
        $given = fn (array $runStats) => array_map(
            fn (UserAchievementProgress $progress) => [$progress->current_value, $progress->state],
            $this->replayRuns($user, $game, $achievements, new Collection([$run->replicate()->forceFill(['score_details' => $runStats])])),
        );

        return $given($run->score_details ?? []) == $given($stats);
    }

    // the stats of a run that counted, read from its replay: it counts with them instead of the ones the game sent
    public function correctRunStats(Run $run, array $stats): void
    {
        DB::transaction(function () use ($run, $stats) {
            $this->takeBackRun($run);
            $run->update(['score_details' => $stats]);
            $this->handleGameRunCompleted(new GameRunCompleted($run->user, $run->game, $run, $stats));
        });
    }

    // (off: it could not count again)
    public function canCorrect(Run $run): bool
    {
        return app(SiteSettings::class)->achievements_enabled
            && $this->runEvents($run->user_id)->where('source_id', (string) $run->id)->exists();
    }

    // the part of the progress of the player that comes from the run: what $counted (all its runs) has more than $left
    private function takeBackFrom(User $user, Run $run, Achievement $achievement, UserAchievementProgress $progress, UserAchievementProgress $counted, ?UserAchievementProgress $left): void
    {
        $levelsLost = $this->levelOf($achievement, $counted->current_value) - $this->levelOf($achievement, $left->current_value ?? 0);
        $beforeLevel = $progress->completed_level;

        $progress->current_value = max(0, $progress->current_value - ($counted->current_value - ($left->current_value ?? 0)));
        $progress->completed_level = max(0, $beforeLevel - max(0, $levelsLost));
        $progress->state = $left->state ?? [];
        if ($progress->completed_level === 0) {
            $progress->completed_at = null;
        }
        $progress->save();

        $rewards = $achievement->levels
            ->where('level', '>', $progress->completed_level)
            ->where('level', '<=', $beforeLevel)
            ->where('reward', '>', 0);
        foreach ($rewards as $level) {
            $user->decrement('kado_points', $level->reward);
            $user->userPoints()->create([
                'period_id' => $run->period_id,
                'delta' => -$level->reward,
                'reason' => 'achievement taken back',
                'source_type' => AchievementLevel::class,
                'source_id' => $level->id,
            ]);
        }
    }

    /**
     * The progress the runs give from nothing, by achievement.
     *
     * @param  Collection<int, Achievement>  $achievements
     * @param  Collection<int, Run>  $runs
     * @return array<int, UserAchievementProgress>
     */
    private function replayRuns(User $user, Game $game, Collection $achievements, Collection $runs): array
    {
        $byKey = $achievements->keyBy('key');
        $progresses = [];
        foreach ($runs as $run) {
            $event = new GameRunCompleted($user, $game, $run, $run->score_details ?? []);
            foreach ($this->rules as $rule) {
                $achievement = $byKey->get($rule->achievementKey());
                if (!$achievement || $rule->category() !== $achievement->category || !$rule->supports($event)) {
                    continue;
                }

                $progress = $progresses[$achievement->id] ??= new UserAchievementProgress(['current_value' => 0, 'completed_level' => 0, 'state' => []]);
                $result = $rule->evaluate($event, $progress);
                if ($result->changed) {
                    $progress->current_value = $result->progress;
                    if ($result->state !== null) {
                        $progress->state = $result->state;
                    }
                }
            }
        }

        return $progresses;
    }

    /**
     * The achievements a run of this game gives alone: not the ones counted on all the games, or by period.
     *
     * @return Collection<int, Achievement>
     */
    private function replayableAchievements(Game $game): Collection
    {
        return Achievement::query()
            ->with('levels')
            ->where('game_id', $game->id)
            ->where('category', AchievementCategory::GAME->value)
            ->where('progress_scope', AchievementProgressScope::LIFETIME->value)
            ->where('is_active', true)
            ->get();
    }

    /**
     * @return Builder<AchievementEvent>
     */
    private function runEvents(int $userId): Builder
    {
        return AchievementEvent::query()
            ->where('user_id', $userId)
            ->where('event_type', GameRunCompleted::class)
            ->where('source_type', Run::class);
    }

    private function levelOf(Achievement $achievement, int $value): int
    {
        return $achievement->levels->where('target', '<=', $value)->max('level') ?? 0;
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
        $completedLevel = $this->levelOf($achievement, $progress->current_value);

        // a level reached stays reached (a target raised later, a progress going down): its reward was paid
        $progress->completed_level = max($progress->completed_level, $completedLevel);

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
            'rewarded_points' => $unlockedLevels->sum('reward'),
        ];
    }
}
