<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

// the name of a clan is unique whatever the case (App\Rules\ClanName): clans_name_unique only refused the exact same name,
// two clans "Foo" and "foo" created at the same time both passed the rule. Built CONCURRENTLY on PostgreSQL (it can't run
// in a transaction). If it fails, PostgreSQL leaves an INVALID index of this name: drop it before migrating again
return new class() extends Migration
{
    public $withinTransaction = false;

    public function up(): void
    {
        // the clans already named the same way are not renamed here: the admin renames them first
        $duplicates = DB::table('clans')
            ->selectRaw('lower(name) as lower_name')
            ->groupByRaw('lower(name)')
            ->havingRaw('count(*) > 1')
            ->pluck('lower_name');
        if ($duplicates->isNotEmpty()) {
            $names = DB::table('clans')->whereIn(DB::raw('lower(name)'), $duplicates)->orderBy('name')
                ->get(['id', 'name'])->map(fn ($clan) => "#{$clan->id} {$clan->name}")->implode(', ');

            throw new RuntimeException("Clans with the same name whatever the case, rename them before migrating: {$names}");
        }

        DB::statement(sprintf('CREATE UNIQUE INDEX %s IF NOT EXISTS clans_name_lower_unique ON clans (lower(name))', $this->concurrently()));
    }

    public function down(): void
    {
        DB::statement(sprintf('DROP INDEX %s IF EXISTS clans_name_lower_unique', $this->concurrently()));
    }

    // CONCURRENTLY on PostgreSQL, outside a transaction only (a test calls this migration inside its own)
    private function concurrently(): string
    {
        return DB::getDriverName() === 'pgsql' && DB::transactionLevel() === 0 ? 'CONCURRENTLY' : '';
    }
};
