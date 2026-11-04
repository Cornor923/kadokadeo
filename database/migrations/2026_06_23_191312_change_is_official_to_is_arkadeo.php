<?php

use App\Models\Game;
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
        Schema::table('games', function (Blueprint $table) {
            $table->renameColumn('is_official', 'is_arkadeo');
            $table->boolean('is_arkadeo')->default(false)->change();
        });

        Game::where('is_arkadeo', true)->update(['is_arkadeo' => false]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('games', function (Blueprint $table) {
            $table->renameColumn('is_arkadeo', 'is_official');
            $table->boolean('is_official')->default(true)->change();
        });
    }
};
