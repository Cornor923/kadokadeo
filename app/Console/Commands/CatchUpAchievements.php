<?php

namespace App\Console\Commands;

use App\Achievements\Events\GameRunCompleted;
use App\Models\Run;
use App\Services\AchievementService;
use App\Settings\SiteSettings;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

// The runs finished since a date that gave nothing to the achievements (a rule failed: RunController::end reports it and
// goes on, a run can't be sent again). --since matters: the runs played before the achievements were turned on are
// not counted either, and they would pay their rewards.
class CatchUpAchievements extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'kado:achievements:catch-up {--since= : date of the first run to look at} {--dry-run : only count the runs}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Count for the achievements the finished runs that did not count';

    /**
     * Execute the console command.
     */
    public function handle(AchievementService $achievements, SiteSettings $settings)
    {
        if (!$this->option('since')) {
            $this->error('--since est obligatoire.');

            return self::FAILURE;
        }
        if (!$settings->achievements_enabled) {
            $this->error('Les succès sont désactivés.');

            return self::FAILURE;
        }

        $runs = Run::query()
            ->withoutReplay()
            ->with('user', 'game')
            ->whereNotNull('completed_at')
            ->where('is_cheat', false)
            ->where('completed_at', '>=', Carbon::parse($this->option('since')))
            ->whereNotExists(fn ($query) => $query->from('achievement_events')
                ->whereColumn('source_id', 'runs.id')
                ->where('source_type', Run::class)
                ->where('event_type', GameRunCompleted::class));

        if ($this->option('dry-run')) {
            $this->info($runs->count().' partie(s) à compter.');

            return self::SUCCESS;
        }

        $counted = 0;
        $failed = 0;
        // (their ids follow the time)
        $runs->lazyById(200, 'runs.id', 'id')->each(function (Run $run) use ($achievements, &$counted, &$failed) {
            try {
                $achievements->handleGameRunCompleted(new GameRunCompleted($run->user, $run->game, $run, $run->score_details ?? []));
                $counted++;
            } catch (\Throwable $e) {
                report($e);
                $failed++;
            }
        });
        $this->info("{$counted} partie(s) comptée(s), {$failed} en échec.");

        return $failed > 0 ? self::FAILURE : self::SUCCESS;
    }
}
