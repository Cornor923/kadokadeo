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
        // the versions of the game bundles (hash of public/gamesdata/manifest.json) runs were played with
        Schema::create('game_builds', function (Blueprint $table) {
            $table->increments('id');
            $table->foreignId('game_id')->constrained()->cascadeOnDelete();
            $table->char('hash', 12);
            $table->timestamp('created_at')->nullable();
            $table->unique(['game_id', 'hash']);
        });

        // 4 bytes per run: the version of the game its replay has to be played with (null: before the archive)
        Schema::table('runs', function (Blueprint $table) {
            $table->unsignedInteger('game_build_id')->nullable();
            $table->foreign('game_build_id')->references('id')->on('game_builds')->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('runs', function (Blueprint $table) {
            $table->dropForeign(['game_build_id']);
            $table->dropColumn('game_build_id');
        });
        Schema::dropIfExists('game_builds');
    }
};
