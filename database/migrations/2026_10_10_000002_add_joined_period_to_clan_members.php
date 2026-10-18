<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class() extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // the period an accepted member joined the clan: he can't leave it nor be excluded before the next one
        // (App\Services\ClanService::assertNotNewMember)
        Schema::table('clan_members', function (Blueprint $table) {
            $table->foreignId('joined_period_id')->nullable()->constrained('periods')->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('clan_members', function (Blueprint $table) {
            $table->dropConstrainedForeignId('joined_period_id');
        });
    }
};
