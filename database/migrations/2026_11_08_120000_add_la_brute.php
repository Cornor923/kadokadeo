<?php

use Illuminate\Database\Migrations\Migration;

return new class() extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // (the seeder only runs on a fresh install: the game is created or updated here, on every database)
        $category = App\Models\Category::firstOrCreate(['name' => 'Action']);
        App\Models\Game::updateOrCreate(['name' => 'La Brute'], [
            'category_id' => $category->id,
            'image_path' => '/assets/img/games/La_Brute.png',
            'is_active' => true,
            'is_arkadeo' => true,
            'stars' => [4000, 6500, 12000],
            'score_rankv1' => 30000,
            'description' => 'Les brutes de LaBrute descendent dans KadoKadéo pour tout casser, il est temps de leur montrer où ils mettent les pieds ! Devenez la Légende Brutale que tout le monde redoute, ou bien ployez le genou... Ici, pas de place aux perdants !',
        ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        //
    }
};
