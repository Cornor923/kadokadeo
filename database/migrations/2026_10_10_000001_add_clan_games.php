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
        // the paid clan games (App\Services\ClanGameService): bought with Kado points, used for the attacks and the defenses
        // once the games of the day are used, given to the clan by their owner
        Schema::table('users', function (Blueprint $table) {
            $table->unsignedInteger('clan_games')->default(0);
        });

        // the games given by the members, distributed by the leader and the right hands
        Schema::table('clans', function (Blueprint $table) {
            $table->unsignedInteger('clan_games')->default(0);
        });

        // who gave games to the clan, and who received them
        Schema::create('clan_game_transfers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('clan_id')->constrained()->cascadeOnDelete();
            $table->string('type', 16);
            $table->foreignId('from_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('to_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->unsignedInteger('count');
            $table->timestamps();

            $table->index(['clan_id', 'id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('clan_game_transfers');
        Schema::table('clans', function (Blueprint $table) {
            $table->dropColumn('clan_games');
        });
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('clan_games');
        });
    }
};
