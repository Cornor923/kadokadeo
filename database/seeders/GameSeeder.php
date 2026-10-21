<?php

namespace Database\Seeders;

use App\Models\Game;
use Illuminate\Database\Seeder;

/**
 * Celestin
 * Aidez Celestin le Nuage à pousser sa petite bulle en évitant les méchants pics et les vilains ventilateurs, tout en ramassant les gentils bonus.
 */
class GameSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $catAction = \App\Models\Category::firstOrCreate(['name' => 'Action']);
        $catPuzzle = \App\Models\Category::firstOrCreate(['name' => 'Réflexion']);

        Game::truncate();

        $catAction->games()->createMany([
            ['name' => 'ABC Revolution', 'image_path' => '/assets/img/games/ABC_Revolution.png', 'is_active' => false, 'stars' => [32424, 44433, 50438]],
            ['name' => 'Alphabounce', 'image_path' => '/assets/img/games/Alphabounce.png', 'is_active' => false, 'stars' => [5977, 25901, 35862]],
            ['name' => 'Iron Chouquette', 'image_path' => '/assets/img/games/Iron_Chouquette.png', 'is_active' => true, 'stars' => [19076, 50870, 66766]],
            ['name' => 'K-Slash !', 'image_path' => '/assets/img/games/K-Slash_!.png', 'is_active' => true, 'stars' => [6957, 18552, 24350]],
            ['name' => 'Kanji', 'image_path' => '/assets/img/games/Kanji.png', 'is_active' => true, 'stars' => [12150, 24300, 30375], 'description' => "Kanji le Ninja saura-t'il se défaire des pièges que renferme ce Zoo infernal ? Dans l'antique Japon, les animaux n'étaient pas toujours l'ami de l'homme : évitez-les en sautant et ramassez les symboles Zen."],
            ['name' => 'Ellon In The Dark', 'image_path' => '/assets/img/games/Ellon_In_The_Dark.png', 'is_active' => true, 'stars' => [15996, 38848, 50273]],
            ['name' => 'Interwheel', 'image_path' => '/assets/img/games/Interwheel.png', 'is_active' => true, 'stars' => [16847, 28881, 34898], 'description' => 'Au secours, c\'est l\'inondation ! Aidez Krakra, la petite tâche de crasse, à s\'évader de la salle de bain du temple aztèque Tenochtitlan. Attention aux mines ancestrales du grand Quetzal !'],
            ['name' => 'Piou-Piou', 'image_path' => '/assets/img/games/Piou-Piou.png', 'is_active' => true, 'stars' => [14801, 31247, 39470]],
            ['name' => 'Manda', 'image_path' => '/assets/img/games/Manda.png', 'is_active' => false, 'stars' => [23987, 263877, 383822], 'description' => "Tortillez-vous pour ramasser les fruits et les bonus, tentez d'obtenir le Jackpot et surtout evitez les murs ! Un grand classique."],
            ['name' => 'Schizo Fuzz', 'image_path' => '/assets/img/games/Schizo_Fuzz.png', 'is_active' => true, 'stars' => [76482, 172084, 219885]],
            ['name' => 'Mini-Race', 'image_path' => '/assets/img/games/Mini-Race.png', 'is_active' => true, 'stars' => [23567, 57234, 74068]],
            ['name' => 'Kavern', 'image_path' => '/assets/img/games/Kavern.png', 'is_active' => true, 'stars' => [27421, 48514, 59061], 'description' => "Aidez PiouPiou à explorer de sombres cavernes ! Ramassez des légumes pour gagner des points et des capsules d'énergie pour survivre plus longtemps."],
            ['name' => 'Twin Spirit', 'image_path' => '/assets/img/games/Twin_Spirit.png', 'is_active' => false, 'stars' => [29884, 63089, 79691]],
            ['name' => 'Judo Commando', 'image_path' => '/assets/img/games/Judo_Commando.png', 'is_active' => true, 'stars' => [24212, 72636, 96848]],
            ['name' => 'Tianan Man', 'image_path' => '/assets/img/games/Tianan_Man.png', 'is_active' => true, 'stars' => [40809, 142834, 193847]],
            ['name' => 'ZipZap', 'image_path' => '/assets/img/games/ZipZap.png', 'is_active' => true, 'stars' => [15258, 24795, 29563]],
            ['name' => 'Kill Bulle', 'image_path' => '/assets/img/games/Kill_Bulle.png', 'is_active' => true, 'stars' => [12609, 37827, 50436], 'description' => 'Retrouvrez Kanji le Ninja dans une nouvelle aventure ! Utilisez le grapin de façon à détruire les bulles bondissantes et gagnez ainsi un max de points.'],
            ['name' => 'Starfang', 'image_path' => '/assets/img/games/Starfang.png', 'is_active' => true, 'stars' => [5228, 15684, 20912]],
            ['name' => 'Oursouinvader', 'image_path' => '/assets/img/games/Oursouinvader.png', 'is_active' => true, 'stars' => [22932, 45864, 57330]],
            ['name' => 'Cyclopean', 'image_path' => '/assets/img/games/Cyclopean.png', 'is_active' => true, 'stars' => [34145, 91053, 119507]],
            ['name' => 'Punch-In !', 'image_path' => '/assets/img/games/Punch-In_!.png', 'is_active' => true, 'stars' => [22334, 78169, 106086]],
            ['name' => 'Crepuscud', 'image_path' => '/assets/img/games/Crepuscud.png', 'is_active' => true, 'stars' => [62057, 113771, 139628]],
            ['name' => "Kanji's Nightmare", 'image_path' => "/assets/img/games/Kanji's_Nightmare.png", 'is_active' => true, 'stars' => [10305, 30915, 41220]],
            ['name' => 'Chakré Bouddha', 'image_path' => '/assets/img/games/Chakré_Bouddha.png', 'is_active' => true, 'stars' => [26941, 53882, 67353]],
            ['name' => 'F1 Champion', 'image_path' => '/assets/img/games/F1_Champion.png', 'is_active' => true, 'stars' => [13695, 20543, 23967]],
            ['name' => 'Tout-Caen', 'image_path' => '/assets/img/games/Tout-Caen.png', 'is_active' => true, 'stars' => [35753, 63256, 77007]],
            ['name' => 'El Tortuga nemesis', 'image_path' => '/assets/img/games/El_Tortuga_nemesis.png', 'is_active' => false, 'stars' => [10938, 65628, 92973]],
            ['name' => 'K-Train', 'image_path' => '/assets/img/games/K-Train.png', 'is_active' => true, 'stars' => [38671, 87010, 111179]],
            ['name' => 'Cosmo Crash', 'image_path' => '/assets/img/games/Cosmo_Crash.png', 'is_active' => true, 'stars' => [7738, 33532, 46428]],
            ['name' => 'Magmax', 'image_path' => '/assets/img/games/Magmax.png', 'is_active' => false, 'stars' => [6183, 21641, 29370], 'description' => 'De nombreux ennemis vous assaillent de tous les cotés, survivez le maximum de temps en enfer en les refroidissant !'],
            ['name' => 'Red Raid', 'image_path' => '/assets/img/games/Red_Raid.png', 'is_active' => false, 'stars' => [26835, 47478, 57799]],
            ['name' => 'Pioutch', 'image_path' => '/assets/img/games/Pioutch.png', 'is_active' => true, 'stars' => [10473, 22110, 27928]],
            ['name' => 'Safari', 'image_path' => '/assets/img/games/Safari.png', 'is_active' => false, 'stars' => [14073, 28146, 35183]],
            ['name' => 'Pacifik', 'image_path' => '/assets/img/games/Pacifik.png', 'is_active' => true, 'stars' => [7887, 34177, 47322]],
            ['name' => 'Phagocytoz', 'image_path' => '/assets/img/games/Phagocytoz.png', 'is_active' => true, 'stars' => [12000, 24000, 30000]],
            ['name' => 'Linea', 'image_path' => '/assets/img/games/Linea.png', 'is_active' => true, 'stars' => [12188, 42658, 57893]],
            ['name' => 'Kanji Gaiden', 'image_path' => '/assets/img/games/Kanji_Gaiden.png', 'is_active' => true, 'stars' => [9024, 27072, 36096]],
            ['name' => 'Julianus', 'image_path' => '/assets/img/games/Julianus.png', 'is_active' => true, 'stars' => [4433, 9975, 12745]],
            ['name' => 'Popcorn', 'image_path' => '/assets/img/games/Popcorn.png', 'is_active' => true, 'stars' => [18443, 79920, 110658]],
            ['name' => 'Happy Pti Tank', 'image_path' => '/assets/img/games/Happy_Pti_Tank.png', 'is_active' => true, 'stars' => [5869, 35214, 49887]],
            ['name' => 'Brutal Teenage Crisis', 'image_path' => '/assets/img/games/Brutal_Teenage_Crisis.png', 'is_active' => true, 'is_arkadeo' => true, 'stars' => [20000, 60000, 100000]],
            ['name' => 'Fafi 360', 'image_path' => '/assets/img/games/Fafi_360.png', 'is_active' => false],
            ['name' => "Charlotte's Quest", 'image_path' => "/assets/img/games/Charlotte's_Quest.png", 'is_active' => false],
            ['name' => 'Capman', 'image_path' => '/assets/img/games/Capman.png', 'is_active' => false],
            ['name' => 'Pulsar', 'image_path' => '/assets/img/games/Pulsar.png', 'is_active' => false],
            ['name' => 'Mel', 'image_path' => '/assets/img/games/Mel.png', 'is_active' => true, 'is_arkadeo' => true, 'stars' => [4000, 12000, 20000], 'description' => 'Mel, coursière de la résistance, doit grimper la ville de Black$ter le plus haut possible : sauts, doubles sauts, accroches et sauts chargés. Mais attention, les Pulpz montent derrière elle !'],
            ['name' => 'Overdrive', 'image_path' => '/assets/img/games/Overdrive.png', 'is_active' => false],
            ['name' => 'Green Witch', 'image_path' => '/assets/img/games/Green_Witch.png', 'is_active' => false],
        ]);

        $catPuzzle->games()->createMany([
            ['name' => 'Opalus Factory', 'image_path' => '/assets/img/games/Opalus_Factory.png', 'is_active' => true, 'stars' => [53167, 106334, 132917]],
            ['name' => 'Flushee', 'image_path' => '/assets/img/games/Flushee.png', 'is_active' => true, 'stars' => [10007, 17705, 21554], 'description' => 'Ces petits animaux sont très fragiles : à peine on les effleure et ils explosent en grappes ! Gagnez le maximum de points en un nombre limité de coups.'],
            ['name' => 'Opalus 2', 'image_path' => '/assets/img/games/Opalus.png', 'is_active' => true, 'stars' => [77855, 105661, 119563]],
            ['name' => 'Kaskade 2', 'image_path' => '/assets/img/games/Kaskade_2.png', 'is_active' => true, 'stars' => [158229, 230151, 266112]],
            ['name' => 'Cooking Lili', 'image_path' => '/assets/img/games/Cooking_Lili.png', 'is_active' => true, 'stars' => [26230, 41660, 49374]],
            ['name' => 'Xian-Xiang', 'image_path' => '/assets/img/games/Xian-Xiang.png', 'is_active' => true, 'stars' => [10240, 12288, 13312]],
            ['name' => 'Aqua Splash', 'image_path' => '/assets/img/games/Aqua_Splash.png', 'is_active' => true, 'stars' => [60722, 107431, 130786]],
            ['name' => 'Atlanteine', 'image_path' => '/assets/img/games/Atlanteine.png', 'is_active' => true, 'stars' => [34641, 61288, 74612]],
            ['name' => "Logic'O", 'image_path' => "/assets/img/games/Logic'O.png", 'is_active' => true, 'stars' => [124705, 198061, 234739]],
            ['name' => 'Choco-Mouche', 'image_path' => '/assets/img/games/Choco-Mouche.png', 'is_active' => true, 'stars' => [84041, 204101, 264131]],
            ['name' => 'Alchimie', 'image_path' => '/assets/img/games/Alchimie1.png', 'is_active' => true, 'stars' => [8000, 17000, 39000], 'description' => "Devenez Alchimiste ! Assemblez les différents éléments nécessaires à la réalisation d'une véritable pépite d'or. Mais attention à ne pas dépasser la limite !"],
            ['name' => 'Alchimie 2', 'image_path' => '/assets/img/games/Alchimie.png', 'is_active' => true, 'stars' => [25999, 166540, 236810], 'description' => "Devenez Alchimiste ! Assemblez les différents éléments nécessaires à la réalisation d'une véritable pépite d'or. Mais attention à ne pas dépasser la limite !"],
            ['name' => 'Bactery', 'image_path' => '/assets/img/games/Bactery.png', 'is_active' => true, 'stars' => [10612, 13734, 15294]],
            ['name' => 'Binary', 'image_path' => '/assets/img/games/Binary.png', 'is_active' => true, 'stars' => [19388, 40931, 51702]],
            ['name' => 'QuadriKolor', 'image_path' => '/assets/img/games/QuadriKolor.png', 'is_active' => true, 'stars' => [17427, 26600, 31186]],
            ['name' => 'Hexile', 'image_path' => '/assets/img/games/Hexile.png', 'is_active' => true, 'stars' => [17413, 19866, 21092]],
            ['name' => "Kanji's Adventure", 'image_path' => "/assets/img/games/Kanji's_Adventure.png", 'is_active' => true, 'stars' => [18700, 56100, 74800]],
            ['name' => 'Razor', 'image_path' => '/assets/img/games/Razor.png', 'is_active' => true, 'stars' => [33459, 44997, 50766]],
            ['name' => 'Spiroule', 'image_path' => '/assets/img/games/Spiroule.png', 'is_active' => true, 'stars' => [46817, 82830, 100837]],
            ['name' => 'Cereal Punk', 'image_path' => '/assets/img/games/Cereal_Punk.png', 'is_active' => true, 'stars' => [42189, 57815, 65628]],
            ['name' => 'Travoltax', 'image_path' => '/assets/img/games/Travoltax.png', 'is_active' => true, 'stars' => [32622, 114177, 154954]],
            ['name' => 'Synapses', 'image_path' => '/assets/img/games/Synapses.png', 'is_active' => true, 'stars' => [39844, 59766, 69727]],
            ['name' => 'Paradice', 'image_path' => '/assets/img/games/Paradice.png', 'is_active' => true, 'stars' => [48291, 68413, 78473]],
            ['name' => 'Invasion', 'image_path' => '/assets/img/games/Invasion.png', 'is_active' => true, 'stars' => [5761, 9150, 10845]],
            ['name' => 'Electrolink', 'image_path' => '/assets/img/games/Electrolink.png', 'is_active' => true, 'stars' => [26388, 79164, 105552]],
            ['name' => 'Toy Maniak', 'image_path' => '/assets/img/games/Toy_Maniak.png', 'is_active' => true, 'stars' => [11131, 33393, 44524]],
            ['name' => 'Drakhan', 'image_path' => '/assets/img/games/Drakhan.png', 'is_active' => false, 'stars' => [35208, 123228, 167238]],
            ['name' => 'Digestomax', 'image_path' => '/assets/img/games/Digestomax.png', 'is_active' => true, 'stars' => [27941, 83823, 111764]],
            ['name' => 'Puzzle-Manda', 'image_path' => '/assets/img/games/Puzzle-Manda.png', 'is_active' => true, 'stars' => [20297, 40594, 50743]],
            ['name' => 'Autrement', 'image_path' => '/assets/img/games/Autrement.png', 'is_active' => true, 'stars' => [6286, 18858, 25144]],
            ['name' => 'Hypercube', 'image_path' => '/assets/img/games/Hypercube.png', 'is_active' => true, 'stars' => [10213, 44256, 61278]],
            ['name' => 'Klinker Surprise', 'image_path' => '/assets/img/games/Klinker_Surprise.png', 'is_active' => true, 'stars' => [16111, 48333, 64444]],
            ['name' => 'Tubulo', 'image_path' => '/assets/img/games/Tubulo.png', 'is_active' => true, 'stars' => [7000, 12000, 17000]],
            ['name' => 'Memopsy', 'image_path' => '/assets/img/games/Memopsy.png', 'is_active' => true, 'stars' => [12000, 24000, 30000]],
            ['name' => 'Rock Faller', 'image_path' => '/assets/img/games/Rock_Faller.png', 'is_active' => true, 'is_arkadeo' => true, 'stars' => [6000, 15000, 25000], 'description' => "Fais pivoter les pierres par carrés de quatre pour réunir au moins quatre gemmes de la même couleur, et fais tomber les rochers noirs dans les tubes pour gagner des coups ou des points. Tu n'as que 10 coups au départ : à toi de faire durer la partie !"],
            ['name' => 'Animoz', 'image_path' => '/assets/img/games/Animoz.png', 'is_active' => false],
            ['name' => 'Nosushi', 'image_path' => '/assets/img/games/Nosushi.png', 'is_active' => false],
            ['name' => 'BattleSheep', 'image_path' => '/assets/img/games/BattleSheep.png', 'is_active' => false],
            ['name' => 'Trigo', 'image_path' => '/assets/img/games/Trigo.png', 'is_active' => false],
            ['name' => 'IceWay', 'image_path' => '/assets/img/games/IceWay.png', 'is_active' => false],
            ['name' => 'BadaBloom', 'image_path' => '/assets/img/games/BadaBloom.png', 'is_active' => false],
            ['name' => 'Cataclismo', 'image_path' => '/assets/img/games/Cataclismo.png', 'is_active' => false],
        ]);
    }
}
