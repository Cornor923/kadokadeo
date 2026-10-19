<?php

namespace App\Console\Commands;

use App\Services\ClanWarService;
use Illuminate\Console\Command;

class ResolveClanAttacks extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'kado:clans:resolve-attacks';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Gives their points to the clan attacks not repelled in time.';

    /**
     * Execute the console command.
     */
    public function handle(ClanWarService $warService)
    {
        $count = $warService->resolveExpired();
        $this->info($count.' clan attack(s) won.');

        return 0;
    }
}
