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
        Schema::table('game_controls', function (Blueprint $table) {
            $table->jsonb('keys')->default('[]');
            $table->dropColumn('key');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('game_controls', function (Blueprint $table) {
            $table->string('key');
            $table->dropColumn('keys');
        });
    }
};
