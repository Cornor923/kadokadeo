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
        // the look of the site chosen by the player (kado.themes), the themes other than "base" being bought with Kado points
        Schema::table('users', function (Blueprint $table) {
            $table->string('theme', 16)->default('base');
            $table->json('unlocked_themes')->nullable();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['theme', 'unlocked_themes']);
        });
    }
};
