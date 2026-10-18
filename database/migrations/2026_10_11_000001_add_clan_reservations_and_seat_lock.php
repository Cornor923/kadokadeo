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
        // the period the seat ("Attaquant", "Défenseur" or none) was given: it can't change before the next one
        Schema::table('clan_members', function (Blueprint $table) {
            $table->foreignId('combat_role_period_id')->nullable()->constrained('periods')->nullOnDelete();
        });

        // "Je m'en occupe": a member of the clan says he will beat the score later (any other member can take his place)
        foreach (['clan_attacks', 'clan_mission_steps'] as $name) {
            Schema::table($name, function (Blueprint $table) {
                $table->foreignId('reserved_by_user_id')->nullable()->constrained('users')->nullOnDelete();
                $table->timestamp('reserved_at')->nullable();
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        foreach (['clan_attacks', 'clan_mission_steps'] as $name) {
            Schema::table($name, function (Blueprint $table) {
                $table->dropConstrainedForeignId('reserved_by_user_id');
                $table->dropColumn('reserved_at');
            });
        }
        Schema::table('clan_members', function (Blueprint $table) {
            $table->dropConstrainedForeignId('combat_role_period_id');
        });
    }
};
