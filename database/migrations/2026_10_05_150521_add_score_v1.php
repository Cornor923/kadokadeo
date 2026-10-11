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
        Schema::table('games', function (Blueprint $table) {
            $table->unsignedBigInteger('score_rankv1')->nullable();
        });

        App\Models\Game::where('name', 'ABC Revolution')->update(['score_rankv1' => 78000]);
        App\Models\Game::where('name', 'Alchimie')->update(['score_rankv1' => 600000]);
        App\Models\Game::where('name', 'Alchimie2')->update(['score_rankv1' => 1000000]);
        App\Models\Game::where('name', 'Alphabounce')->update(['score_rankv1' => 110000]);
        App\Models\Game::where('name', 'Aqua Splash')->update(['score_rankv1' => 180000]);
        App\Models\Game::where('name', 'Atlanteine')->update(['score_rankv1' => 155000]);
        App\Models\Game::where('name', 'Autrement')->update(['score_rankv1' => 62000]);
        App\Models\Game::where('name', 'Bactery')->update(['score_rankv1' => 17500]);
        App\Models\Game::where('name', 'Binary')->update(['score_rankv1' => 130000]);
        App\Models\Game::where('name', 'Cereal Punk')->update(['score_rankv1' => 124000]);
        App\Models\Game::where('name', 'Chakré Bouddha')->update(['score_rankv1' => 330000]);
        App\Models\Game::where('name', 'Choco-Mouche')->update(['score_rankv1' => 675000]);
        App\Models\Game::where('name', 'Cooking Lili')->update(['score_rankv1' => 115000]);
        App\Models\Game::where('name', 'Cosmo Crash')->update(['score_rankv1' => 145000]);
        App\Models\Game::where('name', 'Crepuscud')->update(['score_rankv1' => 250000]);
        App\Models\Game::where('name', 'Cyclopean')->update(['score_rankv1' => 250000]);
        App\Models\Game::where('name', 'Digestomax')->update(['score_rankv1' => 160000]);
        App\Models\Game::where('name', 'Drakhan')->update(['score_rankv1' => 530000]);
        App\Models\Game::where('name', 'El Tortuga nemesis')->update(['score_rankv1' => 800000]);
        App\Models\Game::where('name', 'Electrolink')->update(['score_rankv1' => 340000]);
        App\Models\Game::where('name', 'Ellon In The Dark')->update(['score_rankv1' => 200000]);
        App\Models\Game::where('name', 'F1 Champion')->update(['score_rankv1' => 36500]);
        App\Models\Game::where('name', 'Flushee')->update(['score_rankv1' => 40000]);
        App\Models\Game::where('name', 'Happy Pti Tank')->update(['score_rankv1' => 103000]);
        App\Models\Game::where('name', 'Hexile')->update(['score_rankv1' => 24500]);
        App\Models\Game::where('name', 'Hypercube')->update(['score_rankv1' => 600000]);
        App\Models\Game::where('name', 'Interwheel')->update(['score_rankv1' => 58000]);
        App\Models\Game::where('name', 'Invasion')->update(['score_rankv1' => 13500]);
        App\Models\Game::where('name', 'Iron Chouquette')->update(['score_rankv1' => 270000]);
        App\Models\Game::where('name', 'Judo Commando')->update(['score_rankv1' => 280000]);
        App\Models\Game::where('name', 'Julianus')->update(['score_rankv1' => 23000]);
        App\Models\Game::where('name', 'K-Slash !')->update(['score_rankv1' => 118000]);
        App\Models\Game::where('name', 'K-Train')->update(['score_rankv1' => 185000]);
        App\Models\Game::where('name', 'Kanji')->update(['score_rankv1' => 59000]);
        App\Models\Game::where('name', 'Kanji Gaiden')->update(['score_rankv1' => 74000]);
        App\Models\Game::where('name', 'Kanji\'s Adventure')->update(['score_rankv1' => 350000]);
        App\Models\Game::where('name', 'Kanji\'s Nightmare')->update(['score_rankv1' => 100000]);
        App\Models\Game::where('name', 'Kaskade 2')->update(['score_rankv1' => 400000]);
        App\Models\Game::where('name', 'Kavern')->update(['score_rankv1' => 82500]);
        App\Models\Game::where('name', 'Kill Bulle')->update(['score_rankv1' => 95000]);
        App\Models\Game::where('name', 'Klinker Surprise')->update(['score_rankv1' => 300000]);
        App\Models\Game::where('name', 'Linea')->update(['score_rankv1' => 175000]);
        App\Models\Game::where('name', 'Logic\'O')->update(['score_rankv1' => 452000]);
        App\Models\Game::where('name', 'Magmax')->update(['score_rankv1' => 70000]);
        App\Models\Game::where('name', 'Manda')->update(['score_rankv1' => 505000]);
        App\Models\Game::where('name', 'Mini-Race')->update(['score_rankv1' => 117250]);
        App\Models\Game::where('name', 'Opalus 2')->update(['score_rankv1' => 170000]);
        App\Models\Game::where('name', 'Opalus Factory')->update(['score_rankv1' => 750000]);
        App\Models\Game::where('name', 'Oursouinvader')->update(['score_rankv1' => 160000]);
        App\Models\Game::where('name', 'PacifiK')->update(['score_rankv1' => 278000]);
        App\Models\Game::where('name', 'Paradice')->update(['score_rankv1' => 150000]);
        App\Models\Game::where('name', 'Phagocytoz')->update(['score_rankv1' => 48000]);
        App\Models\Game::where('name', 'Piou-Piou')->update(['score_rankv1' => 90000]);
        App\Models\Game::where('name', 'Pioutch')->update(['score_rankv1' => 53000]);
        App\Models\Game::where('name', 'Popcorn')->update(['score_rankv1' => 300000]);
        App\Models\Game::where('name', 'Punch-In !')->update(['score_rankv1' => 361000]);
        App\Models\Game::where('name', 'Puzzle-Manda')->update(['score_rankv1' => 96000]);
        App\Models\Game::where('name', 'QuadriKolor')->update(['score_rankv1' => 41500]);
        App\Models\Game::where('name', 'Razor')->update(['score_rankv1' => 70000]);
        App\Models\Game::where('name', 'Red Raid')->update(['score_rankv1' => 154000]);
        App\Models\Game::where('name', 'Safari')->update(['score_rankv1' => 156000]);
        App\Models\Game::where('name', 'Schizo Fuzz')->update(['score_rankv1' => 625000]);
        App\Models\Game::where('name', 'Spiroule')->update(['score_rankv1' => 200000]);
        App\Models\Game::where('name', 'Starfang')->update(['score_rankv1' => 230000]);
        App\Models\Game::where('name', 'Synapses')->update(['score_rankv1' => 105000]);
        App\Models\Game::where('name', 'Tianan Man')->update(['score_rankv1' => 1352000]);
        App\Models\Game::where('name', 'Tout-Caen')->update(['score_rankv1' => 129000]);
        App\Models\Game::where('name', 'Toy Maniak')->update(['score_rankv1' => 92000]);
        App\Models\Game::where('name', 'Travoltax')->update(['score_rankv1' => 495000]);
        App\Models\Game::where('name', 'Tubulo')->update(['score_rankv1' => 28000]);
        App\Models\Game::where('name', 'Twin Spirit')->update(['score_rankv1' => 204000]);
        App\Models\Game::where('name', 'Xian-Xiang')->update(['score_rankv1' => 15600]);
        App\Models\Game::where('name', 'ZipZap')->update(['score_rankv1' => 75000]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        //
    }
};
