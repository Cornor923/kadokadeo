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
        Schema::create('runs', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->foreignId('period_id')->nullable()->constrained()->onDelete('set null');
            $table->foreignId('game_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->integer('contract_score');
            $table->integer('contract_points');
            $table->string('seed')->nullable();
            $table->integer('score')->nullable();
            $table->jsonb('score_details')->nullable();
            $table->integer('play_time_seconds')->nullable();
            $table->jsonb('replay')->nullable();
            $table->timestamps();
            $table->timestamp('completed_at')->nullable();
            $table->softDeletes();

            $table->index(['game_id', 'score', 'completed_at']);
            $table->index(['game_id', 'user_id', 'completed_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('runs');
    }
};
