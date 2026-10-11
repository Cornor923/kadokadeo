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
        Schema::table('control_games', function (Blueprint $table) {
            $table->dropForeign(['control_id']);
            $table->dropColumn('control_id');
            $table->string('key');
        });
        Schema::rename('control_games', 'game_controls');

        Schema::dropIfExists('controls');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::create('controls', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('key', 32);
        });

        Schema::rename('game_controls', 'control_games');
        Schema::table('control_games', function (Blueprint $table) {
            $table->dropColumn('key');
            $table->foreignId('control_id')->constrained();
        });
    }
};
