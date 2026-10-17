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
        // a clan declares the war to another one (3 at most): the targets its members should attack first, shown in the
        // "Statut" of both clans. Declared or ended by the leader and the right hands, all ended with the period.
        Schema::create('clan_wars', function (Blueprint $table) {
            $table->id();
            $table->foreignId('clan_id')->constrained('clans')->cascadeOnDelete();
            $table->foreignId('target_clan_id')->constrained('clans')->cascadeOnDelete();
            $table->foreignId('declared_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['clan_id', 'target_clan_id']);
            $table->index('target_clan_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('clan_wars');
    }
};
