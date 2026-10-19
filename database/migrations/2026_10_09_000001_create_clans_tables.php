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
        // a clan: a group of 1 to 50 players (App\Services\ClanService), kept from a period to the next
        Schema::create('clans', function (Blueprint $table) {
            $table->id();
            $table->string('name', 32)->unique();
            $table->text('description')->nullable();
            $table->foreignId('leader_id')->nullable()->constrained('users')->nullOnDelete();
            $table->boolean('is_recruiting')->default(true);
            $table->timestamps();
        });

        // a player belongs to a single clan at a time
        Schema::create('clan_members', function (Blueprint $table) {
            $table->id();
            $table->foreignId('clan_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            // App\Enums\ClanRole: "Bras droit" or member (the leader is clans.leader_id)
            $table->string('role', 16)->default('member');
            // App\Enums\ClanCombatRole: "Attaquant", "Défenseur" or none, seats by size of the clan
            $table->string('combat_role', 16)->nullable();
            $table->timestamps();
        });

        // the applications ("candidatures") sent to a clan, accepted or refused by its leader
        Schema::create('clan_applications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('clan_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('message', 500)->nullable();
            $table->string('status', 16)->default('pending');
            $table->timestamps();

            $table->index(['clan_id', 'status']);
        });

        // the tournament of a clan during a period: its scores, its ranks and the games chosen with the bonuses
        Schema::create('clan_period_scores', function (Blueprint $table) {
            $table->id();
            $table->foreignId('clan_id')->constrained()->cascadeOnDelete();
            $table->foreignId('period_id')->constrained()->cascadeOnDelete();
            $table->integer('war_score')->default(0);
            $table->integer('mission_score')->default(0);
            $table->unsignedInteger('attacks_won')->default(0);
            $table->unsignedInteger('attacks_lost')->default(0);
            $table->unsignedInteger('defenses_won')->default(0);
            $table->unsignedInteger('missions_completed')->default(0);
            $table->unsignedInteger('war_rank')->nullable();
            $table->unsignedInteger('mission_rank')->nullable();
            $table->unsignedInteger('reward')->default(0);
            $table->timestamp('closed_at')->nullable();
            // "Jeu caca" / "Jeu cool" bonuses: a game never / always in the next missions of the period
            $table->foreignId('banned_game_id')->nullable()->constrained('games')->nullOnDelete();
            $table->foreignId('forced_game_id')->nullable()->constrained('games')->nullOnDelete();
            $table->timestamps();

            $table->unique(['clan_id', 'period_id']);
            $table->index(['period_id', 'war_score']);
            $table->index(['period_id', 'mission_score']);
        });

        // what a player did for his clan during a period, and his share of the reward of the clan
        Schema::create('clan_member_stats', function (Blueprint $table) {
            $table->id();
            $table->foreignId('clan_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('period_id')->constrained()->cascadeOnDelete();
            $table->unsignedInteger('attacks')->default(0);
            $table->unsignedInteger('attacks_won')->default(0);
            $table->unsignedInteger('defenses')->default(0);
            $table->unsignedInteger('defenses_won')->default(0);
            $table->unsignedInteger('mission_steps')->default(0);
            // points won by his attacks + points saved by his defenses (+ mission_steps: his points in the clan)
            $table->integer('performance')->default(0);
            $table->unsignedInteger('reward')->default(0);
            $table->foreignId('user_point_id')->nullable()->constrained('user_points')->nullOnDelete();
            $table->timestamps();

            $table->unique(['clan_id', 'user_id', 'period_id']);
        });

        // an attack: the score of a run of a player against another clan, which has 12 hours to beat it
        Schema::create('clan_attacks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('period_id')->constrained()->cascadeOnDelete();
            $table->foreignId('game_id')->constrained()->cascadeOnDelete();
            $table->foreignId('attacker_clan_id')->constrained('clans')->cascadeOnDelete();
            $table->foreignId('attacker_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('defender_clan_id')->constrained('clans')->cascadeOnDelete();
            $table->foreignUlid('run_id')->nullable()->constrained()->nullOnDelete();
            $table->unsignedBigInteger('score')->default(0);
            $table->string('status', 16);
            $table->timestamp('expires_at')->nullable();
            $table->foreignId('defender_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignUlid('defense_run_id')->nullable()->constrained('runs')->nullOnDelete();
            $table->integer('points')->default(0);
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'expires_at']);
            $table->index(['attacker_clan_id', 'status']);
            $table->index(['defender_clan_id', 'status']);
        });

        // a mission: a series of scores to reach on several games, in 24 hours
        Schema::create('clan_missions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('clan_id')->constrained()->cascadeOnDelete();
            $table->foreignId('period_id')->constrained()->cascadeOnDelete();
            $table->unsignedInteger('number');
            $table->string('status', 16);
            // won when completed, lost (negative) when not finished in time
            $table->integer('points')->default(0);
            $table->timestamp('expires_at');
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->index(['clan_id', 'period_id', 'status']);
        });

        Schema::create('clan_mission_steps', function (Blueprint $table) {
            $table->id();
            $table->foreignId('clan_mission_id')->constrained()->cascadeOnDelete();
            $table->foreignId('game_id')->constrained()->cascadeOnDelete();
            $table->unsignedBigInteger('target_score');
            $table->foreignId('completed_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignUlid('run_id')->nullable()->constrained()->nullOnDelete();
            $table->unsignedBigInteger('score')->nullable();
            $table->boolean('skipped')->default(false);
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();
        });

        // the options of the missions (given at the start of the period, won by the missions), used by the leader or a
        // right hand until the end of the period
        Schema::create('clan_bonuses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('clan_id')->constrained()->cascadeOnDelete();
            $table->foreignId('period_id')->constrained()->cascadeOnDelete();
            $table->string('type', 24);
            $table->timestamp('used_at')->nullable();
            $table->timestamps();

            $table->index(['clan_id', 'period_id', 'used_at']);
        });

        // a clan run asked by a player (attack, improvement of his attack: clan_attack_id, defense, mission step): the next
        // run he begins on this game is bound to it
        Schema::create('clan_actions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('clan_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('game_id')->constrained()->cascadeOnDelete();
            $table->string('type', 16);
            $table->foreignId('defender_clan_id')->nullable()->constrained('clans')->cascadeOnDelete();
            $table->foreignId('clan_attack_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('clan_mission_step_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignUlid('run_id')->nullable()->unique()->constrained()->nullOnDelete();
            $table->string('result', 16)->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'game_id', 'run_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('clan_actions');
        Schema::dropIfExists('clan_bonuses');
        Schema::dropIfExists('clan_mission_steps');
        Schema::dropIfExists('clan_missions');
        Schema::dropIfExists('clan_attacks');
        Schema::dropIfExists('clan_member_stats');
        Schema::dropIfExists('clan_period_scores');
        Schema::dropIfExists('clan_applications');
        Schema::dropIfExists('clan_members');
        Schema::dropIfExists('clans');
    }
};
