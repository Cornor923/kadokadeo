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
        Schema::create('game_period_stars', function (Blueprint $table) {
            $table->id();
            $table->foreignId('game_id')->constrained();
            $table->foreignId('period_id')->constrained();
            $table->foreignId('user_id')->constrained();
            $table->integer('star');
            $table->timestamps();
        });

        Schema::create('user_stars', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained();
            $table->foreignId('period_id')->constrained();
            $table->integer('green_stars')->default(0);
            $table->integer('orange_stars')->default(0);
            $table->integer('red_stars')->default(0);
            $table->integer('purple_stars')->default(0);

            $table->unique(['user_id', 'period_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('game_period_stars');
        Schema::dropIfExists('user_stars');
    }
};
