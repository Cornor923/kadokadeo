<?php

namespace Database\Seeders;

use App\Enums\AchievementCategory;
use App\Enums\AchievementProgressScope;
use App\Models\Game;
use Illuminate\Database\Seeder;
use Illuminate\Support\Collection;

class AchievementsSeeder extends Seeder
{
    private Collection $games;

    /**
     * Run the database seeds. Can be run again at any time: an achievement (its key) or a level (its number) already
     * there is updated, so the progress of the players stays; what is removed from here stays in the database.
     */
    public function run(): void
    {
        $this->games = Game::all();

        $this->createAtlanteineAchievements();
        $this->createBacteryAchievements();
        $this->createChocoMoucheAchievements();
        $this->createF1ChampionAchievements();
        $this->createInterwheelAchievements();
        $this->createIronChouquetteAchievements();
        $this->createKanjiAchievements();
        $this->createKanjisNightmareAchievements();
        $this->createKaskade2Achievements();
        $this->createKillBulleAchievements();
        $this->createKSlashAchievements();
        $this->createMagmaxAchievements();
        $this->createOpalus2Achievements();
        $this->createPiouPiouAchievements();
        $this->createPopcornAchievements();
        $this->createStarfangAchievements();
        $this->createSynapsesAchievements();
        $this->createTiananManAchievements();
        $this->createTubuloAchievements();
        $this->createTravoltaxAchievements();
        $this->createXianXiangAchievements();
        $this->createZipZapAchievements();
        $this->createCommonGameAchievements();
    }

    private function createAtlanteineAchievements()
    {
        $game = $this->games->where('game_key', 'atlanteine')->first();
        if (!$game) {
            return;
        }

        $ghostsKilled = $game->achievements()->updateOrCreate(['key' => 'ghosts_killed'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $ghostsKilled->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 100, 'title' => 'Bouh!', 'description' => 'Tuer 1 fantôme.']);
        $ghostsKilled->levels()->updateOrCreate(['level' => 2], ['target' => 50, 'reward' => 500, 'title' => 'Masacre ectoplasmique', 'description' => 'Tuer 50 fantômes.']);
        $ghostsKilled->levels()->updateOrCreate(['level' => 3], ['target' => 200, 'reward' => 1000, 'title' => 'Chasseur sans tête', 'description' => 'Tuer 200 fantômes.']);

        $boxesMoved = $game->achievements()->updateOrCreate(['key' => 'boxes_moved'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $boxesMoved->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 100, 'title' => 'Brocanteur', 'description' => 'Déplacer 10 caisses.']);
        $boxesMoved->levels()->updateOrCreate(['level' => 2], ['target' => 50, 'reward' => 500, 'title' => 'Déménageur', 'description' => 'Déplacer 50 caisses.']);
        $boxesMoved->levels()->updateOrCreate(['level' => 3], ['target' => 200, 'reward' => 1000, 'title' => 'Transporteur', 'description' => 'Déplacer 200 caisses.']);

        $waterDeaths = $game->achievements()->updateOrCreate(['key' => 'water_deaths'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $waterDeaths->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 100, 'title' => 'Parachutiste', 'description' => 'Tomber 10 fois dans l\'eau.']);
        $waterDeaths->levels()->updateOrCreate(['level' => 2], ['target' => 50, 'reward' => 500, 'title' => 'Base-jumper', 'description' => 'Tomber 50 fois dans l\'eau.']);
        $waterDeaths->levels()->updateOrCreate(['level' => 3], ['target' => 100, 'reward' => 1000, 'title' => 'Baumgartner', 'description' => 'Tomber 100 fois dans l\'eau.']);

        $levelReached = $game->achievements()->updateOrCreate(['key' => 'level_reached'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $levelReached->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 100, 'title' => 'Promeneur', 'description' => 'Atteindre le niveau 10.']);
        $levelReached->levels()->updateOrCreate(['level' => 2], ['target' => 20, 'reward' => 500, 'title' => 'Randonneur', 'description' => 'Atteindre le niveau 20.']);
        $levelReached->levels()->updateOrCreate(['level' => 3], ['target' => 30, 'reward' => 1000, 'title' => 'Explorateur', 'description' => 'Atteindre le niveau 30.']);

        $bonusBoxes = $game->achievements()->updateOrCreate(['key' => 'bonus_boxes'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $bonusBoxes->levels()->updateOrCreate(['level' => 1], ['target' => 3000, 'reward' => 250, 'title' => 'On encaisse', 'description' => 'Récupérer 3.000 points bonus de caisses en un seul niveau.']);

        $pushBoxOnGhost = $game->achievements()->updateOrCreate(['key' => 'push_box_on_ghost'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $pushBoxOnGhost->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 1000, 'title' => 'Prends ça !', 'description' => 'Pousser une caisse sur un fantôme.']);

        $ghostBuster = $game->achievements()->updateOrCreate(['key' => 'ghost_buster'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $ghostBuster->levels()->updateOrCreate(['level' => 1], ['target' => 3, 'reward' => 2000, 'title' => 'Ghost buster', 'description' => 'Foncer dans 3 fantômes dans un même niveau puis le réussir.']);
    }

    private function createBacteryAchievements()
    {
        $game = $this->games->where('game_key', 'bactery')->first();
        if (!$game) {
            return;
        }

        $fewBacteria = $game->achievements()->updateOrCreate(['key' => 'few_bacteria'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fewBacteria->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 100, 'title' => 'Antiseptique', 'description' => 'Avoir 10 bactéries ou moins sur son plateau à la fin de partie.']);
        $fewBacteria->levels()->updateOrCreate(['level' => 2], ['target' => 2, 'reward' => 500, 'title' => 'Désinfectant', 'description' => 'Avoir 8 bactéries ou moins sur son plateau à la fin de partie.']);
        $fewBacteria->levels()->updateOrCreate(['level' => 3], ['target' => 3, 'reward' => 1000, 'title' => 'Javel', 'description' => 'Avoir 6 bactéries ou moins sur son plateau à la fin de partie.']);

        $totalStars = $game->achievements()->updateOrCreate(['key' => 'total_stars'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalStars->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 100, 'title' => 'Admirateur d\'astres', 'description' => 'Amasser un total de 10 étoiles.']);
        $totalStars->levels()->updateOrCreate(['level' => 2], ['target' => 100, 'reward' => 500, 'title' => 'Collectionneur de constellations', 'description' => 'Amasser un total de 100 étoiles.']);
        $totalStars->levels()->updateOrCreate(['level' => 3], ['target' => 1000, 'reward' => 1000, 'title' => 'Adorateur de galaxies', 'description' => 'Amasser un total de 1.000 étoiles.']);

        $highScores = $game->achievements()->updateOrCreate(['key' => 'high_scores'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $highScores->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 100, 'title' => 'Les F5 ont enfin payé', 'description' => 'Faire un score d\'au moins 17.000 une fois.']);
        $highScores->levels()->updateOrCreate(['level' => 2], ['target' => 5, 'reward' => 500, 'title' => 'Ça devient presque facile...', 'description' => 'Faire un score d\'au moins 17.000 5 fois.']);
        $highScores->levels()->updateOrCreate(['level' => 3], ['target' => 10, 'reward' => 1000, 'title' => 'T\'as au moins pris le record du site ?', 'description' => 'Faire un score d\'au moins 17.000 10 fois.']);

        $palace = $game->achievements()->updateOrCreate(['key' => 'palace'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $palace->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 250, 'title' => 'La classe de palace', 'description' => 'Réussir une partie avec 5 étoiles restantes et aucune bille colorée.']);

        $stones = $game->achievements()->updateOrCreate(['key' => 'stones'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $stones->levels()->updateOrCreate(['level' => 1], ['target' => 70, 'reward' => 1000, 'title' => 'Bâtisseur de fondations', 'description' => 'Obtenir 70 pierres en une partie.']);

        $tricolor = $game->achievements()->updateOrCreate(['key' => 'tricolor'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $tricolor->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 1000, 'title' => 'Drapeau tricolore', 'description' => 'Finir avec autant de bactéries, pierres et billes colorées.']);

        $coloredMarbles = $game->achievements()->updateOrCreate(['key' => 'colored_marbles'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $coloredMarbles->levels()->updateOrCreate(['level' => 1], ['target' => 85, 'reward' => 2000, 'title' => 'F5 la prochaine fois...', 'description' => 'Finir avec au moins 85 boules colorées.']);
    }

    private function createChocoMoucheAchievements()
    {
        $game = $this->games->where('game_key', 'chocomouche')->first();
        if (!$game) {
            return;
        }

        $discoveredFives = $game->achievements()->updateOrCreate(['key' => 'discovered_fives'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $discoveredFives->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 100, 'title' => 'Terrain miné', 'description' => 'Découvrir 5 cases avec le chiffre 5.']);
        $discoveredFives->levels()->updateOrCreate(['level' => 2], ['target' => 25, 'reward' => 500, 'title' => 'Infestion de mouches', 'description' => 'Découvrir 25 cases avec le chiffre 5.']);
        $discoveredFives->levels()->updateOrCreate(['level' => 3], ['target' => 50, 'reward' => 1000, 'title' => 'Pentagramme drosophilien', 'description' => 'Découvrir 50 cases avec le chiffre 5.']);

        $totalDiscoveredCells = $game->achievements()->updateOrCreate(['key' => 'total_discovered_cells'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalDiscoveredCells->levels()->updateOrCreate(['level' => 1], ['target' => 500, 'reward' => 100, 'title' => 'Le chocolat, sans les mouches', 'description' => 'Découvrir 500 cases.']);
        $totalDiscoveredCells->levels()->updateOrCreate(['level' => 2], ['target' => 2000, 'reward' => 500, 'title' => 'Dévoreur cacaoté', 'description' => 'Découvrir 2.000 cases.']);
        $totalDiscoveredCells->levels()->updateOrCreate(['level' => 3], ['target' => 5000, 'reward' => 1000, 'title' => 'Indigestion de chocolat', 'description' => 'Découvrir 5.000 cases.']);

        $levelReached = $game->achievements()->updateOrCreate(['key' => 'level_reached'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $levelReached->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 100, 'title' => 'Pourquoi des mouches dans du chocolat ?', 'description' => 'Atteindre le niveau 5.']);
        $levelReached->levels()->updateOrCreate(['level' => 2], ['target' => 7, 'reward' => 500, 'title' => 'Vous avez dit des mouches ?', 'description' => 'Atteindre le niveau 7.']);
        $levelReached->levels()->updateOrCreate(['level' => 3], ['target' => 9, 'reward' => 1000, 'title' => 'Où ça des mouches ?', 'description' => 'Atteindre le niveau 9.']);

        $levelScore = $game->achievements()->updateOrCreate(['key' => 'level_score'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $levelScore->levels()->updateOrCreate(['level' => 1], ['target' => 45000, 'reward' => 100, 'title' => 'Démineur amateur', 'description' => 'Marquer 45.000 points sur un niveau.']);
        $levelScore->levels()->updateOrCreate(['level' => 2], ['target' => 50000, 'reward' => 500, 'title' => 'Démineur acharné', 'description' => 'Marquer 50.000 points sur un niveau.']);
        $levelScore->levels()->updateOrCreate(['level' => 3], ['target' => 55000, 'reward' => 1000, 'title' => 'Démineur professionnel', 'description' => 'Marquer 55.000 points sur un niveau.']);

        $fiveLevelsWithoutLifeLoss = $game->achievements()->updateOrCreate(['key' => 'five_levels_without_life_loss'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fiveLevelsWithoutLifeLoss->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 250, 'title' => 'Oh yeah!', 'description' => 'Finir 5 niveaux de suite sans perdre de vie.']);

        $sixAdjacentFlies = $game->achievements()->updateOrCreate(['key' => 'six_adjacent_flies'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sixAdjacentFlies->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 250, 'title' => 'Chanceux', 'description' => 'Découvrir une case avec 6 mouches à proximité.']);

        $threeFirstFlyLosses = $game->achievements()->updateOrCreate(['key' => 'three_first_fly_losses'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $threeFirstFlyLosses->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 1000, 'title' => 'Malchanceux', 'description' => 'Perdre 3 vies sur les 3 premières cases découvertes d\'une grille.']);

        $sevenClicksLevel = $game->achievements()->updateOrCreate(['key' => 'seven_clicks_level'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sevenClicksLevel->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 1000, 'title' => 'Vite fait bien fait', 'description' => 'Terminer un niveau avec maximum 7 cases cliquées.']);

        $fastLevelOne = $game->achievements()->updateOrCreate(['key' => 'fast_level_one'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fastLevelOne->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 2000, 'title' => 'J\'AI FAIM !', 'description' => 'Terminer le niveau 1 en moins de 15 secondes.']);
    }

    private function createCommonGameAchievements()
    {
        foreach ($this->games as $game) {

            $stars = $game->achievements()->updateOrCreate(['key' => 'stars'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
            $stars->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 0, 'title' => 'Étoile verte '.$game->name, 'description' => 'Obtenir l\'étoile verte sur '.$game->name.'.']);
            $stars->levels()->updateOrCreate(['level' => 2], ['target' => 2, 'reward' => 0, 'title' => 'Étoile orange '.$game->name, 'description' => 'Obtenir l\'étoile orange sur '.$game->name.'.']);
            $stars->levels()->updateOrCreate(['level' => 3], ['target' => 3, 'reward' => 0, 'title' => 'Étoile rouge '.$game->name, 'description' => 'Obtenir l\'étoile rouge sur '.$game->name.'.']);

            $paradiseLeague = $game->achievements()->updateOrCreate(['key' => 'paradise_league'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
            $paradiseLeague->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 0, 'title' => 'Ligue Paradis', 'description' => 'Atteindre la ligue Paradis à '.$game->name.'.']);
        }
    }

    private function createPopcornAchievements()
    {
        $game = $this->games->where('game_key', 'popcorn')->first();
        if (!$game) {
            return;
        }

        $totalBubleDestroyed = $game->achievements()->updateOrCreate(['key' => 'total_buble_destroyed'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalBubleDestroyed->levels()->updateOrCreate(['level' => 1], ['target' => 1500, 'reward' => 100, 'title' => 'Ventre vide', 'description' => 'Manger un total de 1.500 grains.']);
        $totalBubleDestroyed->levels()->updateOrCreate(['level' => 2], ['target' => 7500, 'reward' => 500, 'title' => 'Petit creux', 'description' => 'Manger un total de 7.500 grains.']);
        $totalBubleDestroyed->levels()->updateOrCreate(['level' => 3], ['target' => 20000, 'reward' => 1000, 'title' => 'Rassasié', 'description' => 'Manger un total de 20.000 grains.']);

        $totalDamageDealt = $game->achievements()->updateOrCreate(['key' => 'total_damage_dealt'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalDamageDealt->levels()->updateOrCreate(['level' => 1], ['target' => 50, 'reward' => 100, 'title' => 'Recrue', 'description' => 'Enlever 50 vies au boss Pokepi.']);
        $totalDamageDealt->levels()->updateOrCreate(['level' => 2], ['target' => 300, 'reward' => 500, 'title' => 'Combattant', 'description' => 'Enlever 300 vies au boss Pokepi.']);
        $totalDamageDealt->levels()->updateOrCreate(['level' => 3], ['target' => 700, 'reward' => 1000, 'title' => 'Assassin', 'description' => 'Enlever 700 vies au boss Pokepi.']);

        $totalKilledTimes = $game->achievements()->updateOrCreate(['key' => 'total_killed_times'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalKilledTimes->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 100, 'title' => 'Maman, j\'ai réussi', 'description' => 'Tuer Pokepi 1 fois.']);
        $totalKilledTimes->levels()->updateOrCreate(['level' => 2], ['target' => 25, 'reward' => 500, 'title' => 'Pokedead', 'description' => 'Tuer Pokepi 25 fois.']);
        $totalKilledTimes->levels()->updateOrCreate(['level' => 3], ['target' => 75, 'reward' => 1000, 'title' => 'Pioukepi', 'description' => 'Tuer Pokepi 75 fois.']);

        $bubleDestroyedInARow = $game->achievements()->updateOrCreate(['key' => 'buble_destroyed_in_a_row'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $bubleDestroyedInARow->levels()->updateOrCreate(['level' => 1], ['target' => 30, 'reward' => 100, 'title' => 'Gourmet', 'description' => 'Manger 30 grains à suivre sans toucher le sol.']);
        $bubleDestroyedInARow->levels()->updateOrCreate(['level' => 2], ['target' => 50, 'reward' => 500, 'title' => 'Gourmand', 'description' => 'Manger 50 grains à suivre sans toucher le sol.']);
        $bubleDestroyedInARow->levels()->updateOrCreate(['level' => 3], ['target' => 70, 'reward' => 1000, 'title' => 'Glouton', 'description' => 'Manger 70 grains à suivre sans toucher le sol.']);

        $combo500Pts = $game->achievements()->updateOrCreate(['key' => 'combo_500_pts'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $combo500Pts->levels()->updateOrCreate(['level' => 1], ['target' => 500, 'reward' => 250, 'title' => 'Sniper', 'description' => 'Atteindre un combo de 500 points.']);

        $threeTimesOutbounds = $game->achievements()->updateOrCreate(['key' => 'three_times_outbounds'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $threeTimesOutbounds->levels()->updateOrCreate(['level' => 1], ['target' => 3, 'reward' => 1000, 'title' => 'T\'es sûr qu\'il y a rien là haut ?', 'description' => 'Passer tout en haut du monde 3 fois dans une même partie.']);

        $fastkillPokepi = $game->achievements()->updateOrCreate(['key' => 'fastkill_pokepi'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fastkillPokepi->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 2000, 'title' => 'Ça, c\'est fait.', 'description' => 'Tuer Pokepi en moins de 1 minute.']);

        $perfectKill = $game->achievements()->updateOrCreate(['key' => 'perfect_kill'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $perfectKill->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 2000, 'title' => 'Vivacité', 'description' => 'Tuer Pokepi sans qu\'aucun grain n\'ait éclaté au sol.']);
    }

    private function createInterwheelAchievements()
    {
        $game = $this->games->where('game_key', 'interwheel')->first();
        if (!$game) {
            return;
        }

        $totalElevation = $game->achievements()->updateOrCreate(['key' => 'total_elevation'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalElevation->levels()->updateOrCreate(['level' => 1], ['target' => 25000, 'reward' => 100, 'title' => 'Apprenti grimpeur', 'description' => 'Monter d\'une hauteur cumulée de 25.000 mètres.']);
        $totalElevation->levels()->updateOrCreate(['level' => 2], ['target' => 150000, 'reward' => 500, 'title' => 'Grimpeur expérimenté', 'description' => 'Monter d\'une hauteur cumulée de 150.000 mètres.']);
        $totalElevation->levels()->updateOrCreate(['level' => 3], ['target' => 1000000, 'reward' => 1000, 'title' => 'Grimpeur légendaire', 'description' => 'Monter d\'une hauteur cumulée de 1.000.000 mètres.']);

        $totalJumps = $game->achievements()->updateOrCreate(['key' => 'total_jumps'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalJumps->levels()->updateOrCreate(['level' => 1], ['target' => 2500, 'reward' => 100, 'title' => 'Enjoué', 'description' => 'Effectuer un total cumulé de 2.500 sauts.']);
        $totalJumps->levels()->updateOrCreate(['level' => 2], ['target' => 10000, 'reward' => 500, 'title' => 'Hyperactif', 'description' => 'Effectuer un total cumulé de 10.000 sauts.']);
        $totalJumps->levels()->updateOrCreate(['level' => 3], ['target' => 25000, 'reward' => 1000, 'title' => 'Infatigable', 'description' => 'Effectuer un total cumulé de 25.000 sauts.']);

        $totalDives = $game->achievements()->updateOrCreate(['key' => 'total_dives'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalDives->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 100, 'title' => 'Baptème de plongée', 'description' => 'Plonger un total cumulé de 5 fois dans l\'eau.']);
        $totalDives->levels()->updateOrCreate(['level' => 2], ['target' => 100, 'reward' => 500, 'title' => 'N\'oublie pas les bouteilles', 'description' => 'Plonger un total cumulé de 100 fois dans l\'eau.']);
        $totalDives->levels()->updateOrCreate(['level' => 3], ['target' => 500, 'reward' => 1000, 'title' => 'Sous-marin', 'description' => 'Plonger un total cumulé de 500 fois dans l\'eau.']);

        $elevation = $game->achievements()->updateOrCreate(['key' => 'elevation'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $elevation->levels()->updateOrCreate(['level' => 1], ['target' => 2500, 'reward' => 100, 'title' => 'Mont-Blanc', 'description' => 'Monter d\'une hauteur de 2.500 mètres en une seule ascension.']);
        $elevation->levels()->updateOrCreate(['level' => 2], ['target' => 3500, 'reward' => 500, 'title' => 'Kilimanjaro', 'description' => 'Monter d\'une hauteur de 3.500 mètres en une seule ascension.']);
        $elevation->levels()->updateOrCreate(['level' => 3], ['target' => 4500, 'reward' => 1000, 'title' => 'Everest', 'description' => 'Monter d\'une hauteur de 4.500 mètres en une seule ascension.']);

        $totalPastilles = $game->achievements()->updateOrCreate(['key' => 'total_pastilles'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalPastilles->levels()->updateOrCreate(['level' => 1], ['target' => 750, 'reward' => 100, 'title' => 'Amateur', 'description' => 'Collecter un total cumulé de 750 pastilles.']);
        $totalPastilles->levels()->updateOrCreate(['level' => 2], ['target' => 5000, 'reward' => 500, 'title' => 'Collectionneur', 'description' => 'Collecter un total cumulé de 5.000 pastilles.']);
        $totalPastilles->levels()->updateOrCreate(['level' => 3], ['target' => 15000, 'reward' => 1000, 'title' => 'Aspirateur', 'description' => 'Collecter un total cumulé de 15.000 pastilles.']);

        $totalDodgedEnemies = $game->achievements()->updateOrCreate(['key' => 'total_dodged_enemies'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalDodgedEnemies->levels()->updateOrCreate(['level' => 1], ['target' => 100, 'reward' => 100, 'title' => 'Amis ?', 'description' => 'Esquiver un total cumulé de 100 mines.']);
        $totalDodgedEnemies->levels()->updateOrCreate(['level' => 2], ['target' => 1000, 'reward' => 500, 'title' => 'Ennemis...', 'description' => 'Esquiver un total cumulé de 1.000 mines.']);
        $totalDodgedEnemies->levels()->updateOrCreate(['level' => 3], ['target' => 5000, 'reward' => 1000, 'title' => 'Innofensifs !', 'description' => 'Esquiver un total cumulé de 5.000 mines.']);

        $waterScore = $game->achievements()->updateOrCreate(['key' => 'water_score'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $waterScore->levels()->updateOrCreate(['level' => 1], ['target' => 1000, 'reward' => 250, 'title' => 'Tout propre !', 'description' => 'Passer dans l\'eau puis récupérer au moins 1.000 points.']);

        $maxFallHeight = $game->achievements()->updateOrCreate(['key' => 'max_fall_height'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $maxFallHeight->levels()->updateOrCreate(['level' => 1], ['target' => 500, 'reward' => 1000, 'title' => 'Chute libre', 'description' => 'Faire une chute ininterrompue de 500 mètres.']);

        $fiveMineWheel = $game->achievements()->updateOrCreate(['key' => 'five_mine_wheel'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fiveMineWheel->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 1000, 'title' => 'Salut la compagnie !', 'description' => 'Atterrir sur une roue avec 5 mines et survivre.']);

        $bottomWheelElevation = $game->achievements()->updateOrCreate(['key' => 'bottom_wheel_elevation'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $bottomWheelElevation->levels()->updateOrCreate(['level' => 1], ['target' => 3500, 'reward' => 2000, 'title' => 'Challenge accepted', 'description' => 'Toucher la roue du bas puis monter à plus de 3.500 mètres.']);
    }

    private function createIronChouquetteAchievements()
    {
        $game = $this->games->where('game_key', 'ironchouquette')->first();
        if (!$game) {
            return;
        }

        $killShield = $game->achievements()->updateOrCreate(['key' => 'kill_shield'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killShield->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 250, 'title' => 'Tous tes bonus ne m\'atteignent pas', 'description' => 'Détruire un champ magnétique.']);

        $killBlocks = $game->achievements()->updateOrCreate(['key' => 'kill_total_blocks'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killBlocks->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 100, 'title' => 'Chatouilleur', 'description' => 'Détruire 10 Blocks cumulés.']);
        $killBlocks->levels()->updateOrCreate(['level' => 2], ['target' => 100, 'reward' => 500, 'title' => 'Killer', 'description' => 'Détruire 100 Blocks cumulés.']);
        $killBlocks->levels()->updateOrCreate(['level' => 3], ['target' => 500, 'reward' => 1000, 'title' => 'Destroyer', 'description' => 'Détruire 500 Blocks cumulés.']);

        $killStorms = $game->achievements()->updateOrCreate(['key' => 'kill_storms'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killStorms->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 100, 'title' => 'Rookie', 'description' => 'Détruire 5 Storms en une seule partie.']);
        $killStorms->levels()->updateOrCreate(['level' => 2], ['target' => 10, 'reward' => 500, 'title' => 'Pilote', 'description' => 'Détruire 10 Storms en une seule partie.']);
        $killStorms->levels()->updateOrCreate(['level' => 3], ['target' => 15, 'reward' => 1000, 'title' => 'Élite', 'description' => 'Détruire 15 Storms en une seule partie.']);

        $sacrifices = $game->achievements()->updateOrCreate(['key' => 'sacrifices'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sacrifices->levels()->updateOrCreate(['level' => 1], ['target' => 2, 'reward' => 100, 'title' => 'Question de survie', 'description' => 'Sacrifier 2 bonus en une seule partie.']);
        $sacrifices->levels()->updateOrCreate(['level' => 2], ['target' => 4, 'reward' => 500, 'title' => 'Question de maladresse', 'description' => 'Sacrifier 4 bonus en une seule partie.']);
        $sacrifices->levels()->updateOrCreate(['level' => 3], ['target' => 6, 'reward' => 1000, 'title' => 'Question de principes', 'description' => 'Sacrifier 6 bonus en une seule partie.']);

        $fiveEmptySlots = $game->achievements()->updateOrCreate(['key' => 'five_empty_slots'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fiveEmptySlots->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 1000, 'title' => 'Chargeurs vides', 'description' => 'Avoir 5 emplacements de bonus mais aucun bonus.']);

        $sameBonus = $game->achievements()->updateOrCreate(['key' => 'same_bonus'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sameBonus->levels()->updateOrCreate(['level' => 1], ['target' => 3, 'reward' => 2000, 'title' => 'Pourvu que ça soit pas du rose...', 'description' => 'Avoir 3 bonus de la même couleur en même temps.']);

        $sixBonuses = $game->achievements()->updateOrCreate(['key' => 'six_bonuses'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sixBonuses->levels()->updateOrCreate(['level' => 1], ['target' => 6, 'reward' => 2000, 'title' => 'Rainbow Color x15 !', 'description' => 'Avoir 6 bonus différents dans une partie.']);

        $surgromphsKilled = $game->achievements()->updateOrCreate(['key' => 'surgromphs_killed'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $surgromphsKilled->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 100, 'title' => 'Un Surgromph de moins', 'description' => 'Détruire 1 Surgromph en une seule partie.']);
        $surgromphsKilled->levels()->updateOrCreate(['level' => 2], ['target' => 3, 'reward' => 500, 'title' => 'Surgromph killer', 'description' => 'Détruire 3 Surgromphs en une seule partie.']);
        $surgromphsKilled->levels()->updateOrCreate(['level' => 3], ['target' => 5, 'reward' => 1000, 'title' => 'Les Surgromphs s\'écartent de mon chemin!', 'description' => 'Détruire 5 Surgromphs en une seule partie.']);

        $cuttyClosedKilled = $game->achievements()->updateOrCreate(['key' => 'cutty_closed_killed'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $cuttyClosedKilled->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 100, 'title' => 'Cutty vite parti', 'description' => 'Détruire 1 Cutty avant qu\'il ne s\'ouvre en une seule partie.']);
        $cuttyClosedKilled->levels()->updateOrCreate(['level' => 2], ['target' => 3, 'reward' => 500, 'title' => 'Cutty cutter', 'description' => 'Détruire 3 Cuttys avant qu\'ils ne s\'ouvrent en une seule partie.']);
        $cuttyClosedKilled->levels()->updateOrCreate(['level' => 3], ['target' => 10, 'reward' => 1000, 'title' => 'Un Cutty? Kézako?', 'description' => 'Détruire 10 Cuttys avant qu\'ils ne s\'ouvrent en une seule partie.']);

        $pinkBonusKills = $game->achievements()->updateOrCreate(['key' => 'pink_bonus_kills'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $pinkBonusKills->levels()->updateOrCreate(['level' => 1], ['target' => 20, 'reward' => 1000, 'title' => 'C\'est pas si mal finalement', 'description' => 'Détruire 20 ennemis avec le bonus rose dans une seule partie.']);

        $blackHoleProjectiles = $game->achievements()->updateOrCreate(['key' => 'black_hole_projectiles'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $blackHoleProjectiles->levels()->updateOrCreate(['level' => 1], ['target' => 100, 'reward' => 1000, 'title' => 'Ménage de printemps', 'description' => 'Aspirer 100 projectiles avec un seul trou noir.']);

        $lapinvinciblesWave = $game->achievements()->updateOrCreate(['key' => 'lapinvincibles_wave'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $lapinvinciblesWave->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 2000, 'title' => 'Ça existe ??', 'description' => 'Passer la vague des lapinvincibles.']);

        $maxEnemyShots = $game->achievements()->updateOrCreate(['key' => 'max_enemy_shots'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $maxEnemyShots->levels()->updateOrCreate(['level' => 1], ['target' => 100, 'reward' => 2000, 'title' => 'J\'y vois plus rien!', 'description' => 'Avoir au moins 100 projectiles ennemis à l\'écran.']);
    }

    private function createPiouPiouAchievements()
    {
        $game = $this->games->where('game_key', 'pioupiou')->first();
        if (!$game) {
            return;
        }

        $totalBubbles = $game->achievements()->updateOrCreate(['key' => 'total_bubbles'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalBubbles->levels()->updateOrCreate(['level' => 1], ['target' => 1000, 'reward' => 100, 'title' => 'Bulleur', 'description' => 'Récupérer un total cumulé de 1.000 bulles.']);
        $totalBubbles->levels()->updateOrCreate(['level' => 2], ['target' => 10000, 'reward' => 500, 'title' => 'Bulle popper', 'description' => 'Récupérer un total cumulé de 10.000 bulles.']);
        $totalBubbles->levels()->updateOrCreate(['level' => 3], ['target' => 25000, 'reward' => 1000, 'title' => 'Bulle doseur', 'description' => 'Récupérer un total cumulé de 25.000 bulles.']);

        $totalElevation = $game->achievements()->updateOrCreate(['key' => 'total_elevation'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalElevation->levels()->updateOrCreate(['level' => 1], ['target' => 500, 'reward' => 100, 'title' => 'Tropopiou', 'description' => 'Grimper un total cumulé de 500m.']);
        $totalElevation->levels()->updateOrCreate(['level' => 2], ['target' => 3000, 'reward' => 500, 'title' => 'Stratopiou', 'description' => 'Grimper un total cumulé de 3.000m.']);
        $totalElevation->levels()->updateOrCreate(['level' => 3], ['target' => 10000, 'reward' => 1000, 'title' => 'Exopiou', 'description' => 'Grimper un total cumulé de 10.000m.']);

        $elevation = $game->achievements()->updateOrCreate(['key' => 'elevation'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $elevation->levels()->updateOrCreate(['level' => 1], ['target' => 30, 'reward' => 100, 'title' => 'Combo ascendant', 'description' => 'Atteindre 30m en une partie.']);
        $elevation->levels()->updateOrCreate(['level' => 2], ['target' => 50, 'reward' => 500, 'title' => 'Sky Piouker', 'description' => 'Atteindre 50m en une partie.']);
        $elevation->levels()->updateOrCreate(['level' => 3], ['target' => 70, 'reward' => 1000, 'title' => 'Piou Infinity', 'description' => 'Atteindre 70m en une partie.']);

        $noBubble = $game->achievements()->updateOrCreate(['key' => 'no_bubble'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $noBubble->levels()->updateOrCreate(['level' => 1], ['target' => 15, 'reward' => 100, 'title' => 'Pas d\'bul', 'description' => 'Atteindre 15m sans récolter de points.']);
        $noBubble->levels()->updateOrCreate(['level' => 2], ['target' => 30, 'reward' => 500, 'title' => 'L\'esquiveur', 'description' => 'Atteindre 30m sans récolter de points.']);
        $noBubble->levels()->updateOrCreate(['level' => 3], ['target' => 40, 'reward' => 1000, 'title' => 'L\'invisible', 'description' => 'Atteindre 40m sans récolter de points.']);

        $fallingBubbles = $game->achievements()->updateOrCreate(['key' => 'falling_bubbles'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fallingBubbles->levels()->updateOrCreate(['level' => 1], ['target' => 30, 'reward' => 250, 'title' => 'Réceptionneur', 'description' => 'Récupérer 30 bonus avant qu\'ils ne touchent le sol dans une partie.']);

        $pinkBubblePopped = $game->achievements()->updateOrCreate(['key' => 'pink_bubble_popped'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $pinkBubblePopped->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 1000, 'title' => 'Je n\'ai rien pu faire', 'description' => 'Laisser une bulle rose se faire écraser.']);

        $climbHeight = $game->achievements()->updateOrCreate(['key' => 'climb_height'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $climbHeight->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 2000, 'title' => 'Déblocage vertical', 'description' => 'Monter de 5 cases d\'un coup.']);
    }

    private function createF1ChampionAchievements()
    {
        $game = $this->games->where('game_key', 'f1champion')->first();
        if (!$game) {
            return;
        }

        $totalKm = $game->achievements()->updateOrCreate(['key' => 'total_km'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalKm->levels()->updateOrCreate(['level' => 1], ['target' => 2000, 'reward' => 100, 'title' => 'Rodage', 'description' => 'Parcourir un total cumulé de 2.000 km.']);
        $totalKm->levels()->updateOrCreate(['level' => 2], ['target' => 5000, 'reward' => 500, 'title' => 'Vidange', 'description' => 'Parcourir un total cumulé de 5.000 km.']);
        $totalKm->levels()->updateOrCreate(['level' => 3], ['target' => 10000, 'reward' => 1000, 'title' => 'Visite technique', 'description' => 'Parcourir un total cumulé de 10.000 km.']);

        $rideOnOil = $game->achievements()->updateOrCreate(['key' => 'ride_on_oil'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $rideOnOil->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 100, 'title' => 'J\'ai glissé chef', 'description' => 'Rouler sur 5 flaques d\'huile en une partie.']);
        $rideOnOil->levels()->updateOrCreate(['level' => 2], ['target' => 8, 'reward' => 500, 'title' => 'Sport de glisse', 'description' => 'Rouler sur 8 flaques d\'huile en une partie.']);
        $rideOnOil->levels()->updateOrCreate(['level' => 3], ['target' => 15, 'reward' => 1000, 'title' => 'Passion pour le drift', 'description' => 'Rouler sur 15 flaques d\'huile en une partie.']);

        $rideOnHeal = $game->achievements()->updateOrCreate(['key' => 'ride_on_heal'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $rideOnHeal->levels()->updateOrCreate(['level' => 1], ['target' => 2, 'reward' => 100, 'title' => 'Assuré', 'description' => 'Récupérer 2 bonus de réparation en une partie.']);
        $rideOnHeal->levels()->updateOrCreate(['level' => 2], ['target' => 5, 'reward' => 500, 'title' => 'Indemnisé', 'description' => 'Récupérer 5 bonus de réparation en une partie.']);
        $rideOnHeal->levels()->updateOrCreate(['level' => 3], ['target' => 8, 'reward' => 1000, 'title' => 'Malussé', 'description' => 'Récupérer 8 bonus de réparation en une partie.']);

        $riskTaker = $game->achievements()->updateOrCreate(['key' => 'risk_taker'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $riskTaker->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 250, 'title' => 'Chauffard', 'description' => 'Sortir 5 fois de la piste sans mourir dans une partie.']);

        $pilot = $game->achievements()->updateOrCreate(['key' => 'pilot'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $pilot->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 1000, 'title' => 'Pilote', 'description' => 'Parcourir 10 km sans une égratignure.']);

        $autobhan = $game->achievements()->updateOrCreate(['key' => 'autobhan'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $autobhan->levels()->updateOrCreate(['level' => 1], ['target' => 20, 'reward' => 2000, 'title' => 'Autobahn', 'description' => 'Rouler à plus de 230 km/h pendant au moins 20 secondes d’affilée sans sortir de la piste.']);

        $secondLife = $game->achievements()->updateOrCreate(['key' => 'second_life'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $secondLife->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 2000, 'title' => 'Second life', 'description' => 'Descendre à moins de 5 % de vie puis remonter au maximum.']);
    }

    private function createZipZapAchievements()
    {
        $game = $this->games->where('game_key', 'zipzap')->first();
        if (!$game) {
            return;
        }

        $totalPops = $game->achievements()->updateOrCreate(['key' => 'total_pops'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalPops->levels()->updateOrCreate(['level' => 1], ['target' => 1000, 'reward' => 100, 'title' => 'Eclate ballons', 'description' => 'Eclater un total cumulé de 1.000 ballons.']);
        $totalPops->levels()->updateOrCreate(['level' => 2], ['target' => 7500, 'reward' => 500, 'title' => 'Anti-hélium', 'description' => 'Eclater un total cumulé de 7.500 ballons.']);
        $totalPops->levels()->updateOrCreate(['level' => 3], ['target' => 25000, 'reward' => 1000, 'title' => 'Terreur des baudruches', 'description' => 'Eclater un total cumulé de 25.000 ballons.']);

        $miniScore = $game->achievements()->updateOrCreate(['key' => 'mini_score'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $miniScore->levels()->updateOrCreate(['level' => 1], ['target' => 100, 'reward' => 1000, 'title' => '10.000 tout rond !', 'description' => 'Finir une partie avec 0 combos.']);

        $blackBalloonsPopped = $game->achievements()->updateOrCreate(['key' => 'black_balloons_popped'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $blackBalloonsPopped->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 100, 'title' => 'Adorateur de la mort', 'description' => 'Éclater 1 ballon noir.']);
        $blackBalloonsPopped->levels()->updateOrCreate(['level' => 2], ['target' => 10, 'reward' => 500, 'title' => 'Bonjour ténèbres', 'description' => 'Éclater 10 ballons noirs.']);
        $blackBalloonsPopped->levels()->updateOrCreate(['level' => 3], ['target' => 25, 'reward' => 1000, 'title' => 'Noir c\'est noir', 'description' => 'Éclater 25 ballons noirs.']);

        $fastFinish = $game->achievements()->updateOrCreate(['key' => 'fast_finish'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fastFinish->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 1000, 'title' => 'J\'ai pas compris le jeu', 'description' => 'Finir une partie en moins de 23 coups.']);

        $emptyShots = $game->achievements()->updateOrCreate(['key' => 'empty_shots'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $emptyShots->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 100, 'title' => 'Il faut viser les ballons ?', 'description' => 'Faire 10 coups dans le vide.']);
        $emptyShots->levels()->updateOrCreate(['level' => 2], ['target' => 100, 'reward' => 500, 'title' => 'Oups j\'ai glissé', 'description' => 'Faire 100 coups dans le vide.']);
        $emptyShots->levels()->updateOrCreate(['level' => 3], ['target' => 1000, 'reward' => 1000, 'title' => 'Rahhh, mais pourquoi ça bouge aussi !', 'description' => 'Faire 1.000 coups dans le vide.']);

        $fiveThousandCombo = $game->achievements()->updateOrCreate(['key' => 'five_thousand_combo'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fiveThousandCombo->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 100, 'title' => 'Combo !', 'description' => 'Obtenir 1 ballon à 5.000 points en un coup.']);
        $fiveThousandCombo->levels()->updateOrCreate(['level' => 2], ['target' => 2, 'reward' => 500, 'title' => 'Le doublet !', 'description' => 'Obtenir 2 ballons à 5.000 points en un coup.']);
        $fiveThousandCombo->levels()->updateOrCreate(['level' => 3], ['target' => 3, 'reward' => 1000, 'title' => 'Brochette de points', 'description' => 'Obtenir 3 ballons à 5.000 points en un coup.']);

        $riskLover = $game->achievements()->updateOrCreate(['key' => 'risk_lover'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $riskLover->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 2000, 'title' => 'J\'aime le risque', 'description' => 'Finir une partie sans mourir alors qu\'il y a au moins 3 ballons noirs lorsqu\'il reste au minimum 50 ballons à éclater.']);
    }

    private function createStarfangAchievements()
    {
        $game = $this->games->where('game_key', 'starfang')->first();
        if (!$game) {
            return;
        }

        $totalLevelsFinished = $game->achievements()->updateOrCreate(['key' => 'total_levels_finished'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalLevelsFinished->levels()->updateOrCreate(['level' => 1], ['target' => 50, 'reward' => 100, 'title' => 'Voyons ce qu\'il y a par là', 'description' => 'Terminer 50 niveaux.']);
        $totalLevelsFinished->levels()->updateOrCreate(['level' => 2], ['target' => 500, 'reward' => 500, 'title' => 'Explorateur spatial', 'description' => 'Terminer 500 niveaux.']);
        $totalLevelsFinished->levels()->updateOrCreate(['level' => 3], ['target' => 1500, 'reward' => 1000, 'title' => 'Vers l\'infini et au-delà', 'description' => 'Terminer 1.500 niveaux.']);

        $totalPurpleAsteroidsDestroyed = $game->achievements()->updateOrCreate(['key' => 'total_purple_asteroids_destroyed'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalPurpleAsteroidsDestroyed->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 100, 'title' => 'Apprenti du mauve', 'description' => 'Détruire 10 astéroïdes violets.']);
        $totalPurpleAsteroidsDestroyed->levels()->updateOrCreate(['level' => 2], ['target' => 75, 'reward' => 500, 'title' => 'Expert de l\'ultra violet', 'description' => 'Détruire 75 astéroïdes violets.']);
        $totalPurpleAsteroidsDestroyed->levels()->updateOrCreate(['level' => 3], ['target' => 250, 'reward' => 1000, 'title' => 'Maître de l\'octarine', 'description' => 'Détruire 250 astéroïdes violets.']);

        $noMainWeaponLevels = $game->achievements()->updateOrCreate(['key' => 'no_main_weapon_levels'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $noMainWeaponLevels->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 100, 'title' => 'À une main', 'description' => 'Terminer 1 niveau sans tirer avec l\'arme principale dans une seule partie.']);
        $noMainWeaponLevels->levels()->updateOrCreate(['level' => 2], ['target' => 3, 'reward' => 500, 'title' => 'À un doigt', 'description' => 'Terminer 3 niveaux sans tirer avec l\'arme principale dans une seule partie.']);
        $noMainWeaponLevels->levels()->updateOrCreate(['level' => 3], ['target' => 5, 'reward' => 1000, 'title' => 'Sans les mains', 'description' => 'Terminer 5 niveaux sans tirer avec l\'arme principale dans une seule partie.']);

        $fastLevel = $game->achievements()->updateOrCreate(['key' => 'fast_level'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fastLevel->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 100, 'title' => 'Rapide l\'ami', 'description' => 'Finir un niveau en moins de 35 secondes après le niveau 6.']);
        $fastLevel->levels()->updateOrCreate(['level' => 2], ['target' => 2, 'reward' => 500, 'title' => 'Vitesse supersonique', 'description' => 'Finir un niveau en moins de 25 secondes après le niveau 6.']);
        $fastLevel->levels()->updateOrCreate(['level' => 3], ['target' => 3, 'reward' => 1000, 'title' => 'Célérité supraluminique', 'description' => 'Finir un niveau en moins de 15 secondes après le niveau 6.']);

        $laserOverkill = $game->achievements()->updateOrCreate(['key' => 'laser_overkill'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $laserOverkill->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 250, 'title' => 'Overkill', 'description' => 'Détruire un astéroïde en terre avec un laser.']);

        $allWeaponUpgrades = $game->achievements()->updateOrCreate(['key' => 'all_weapon_upgrades'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $allWeaponUpgrades->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 1000, 'title' => 'Indécis', 'description' => 'Obtenir une amélioration d\'arme de chaque type dans une seule partie.']);

        $sameWeaponUpgrades = $game->achievements()->updateOrCreate(['key' => 'same_weapon_upgrades'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sameWeaponUpgrades->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 2000, 'title' => 'Puissant', 'description' => 'Obtenir 5 améliorations d\'armes identiques dans une seule partie.']);
    }

    private function createKaskade2Achievements()
    {
        $game = $this->games->where('game_key', 'kaskade2')->first();
        if (!$game) {
            return;
        }

        $totalBlocks = $game->achievements()->updateOrCreate(['key' => 'total_blocks'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalBlocks->levels()->updateOrCreate(['level' => 1], ['target' => 3000, 'reward' => 100, 'title' => 'Cliqueur', 'description' => 'Détruire un total cumulé de 3.000 blocs.']);
        $totalBlocks->levels()->updateOrCreate(['level' => 2], ['target' => 30000, 'reward' => 500, 'title' => 'Cogneur', 'description' => 'Détruire un total cumulé de 30.000 blocs.']);
        $totalBlocks->levels()->updateOrCreate(['level' => 3], ['target' => 250000, 'reward' => 1000, 'title' => 'Kasseur', 'description' => 'Détruire un total cumulé de 250.000 blocs.']);

        $miniScore = $game->achievements()->updateOrCreate(['key' => 'mini_score'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $miniScore->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 2000, 'title' => 'Premier ! De la fin...', 'description' => 'Faire un score de 2.000.']);

        $destroyFiftyBlocks = $game->achievements()->updateOrCreate(['key' => 'destroy_fifty_blocks'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $destroyFiftyBlocks->levels()->updateOrCreate(['level' => 1], ['target' => 50, 'reward' => 250, 'title' => 'Boom !', 'description' => 'Détruire 50 blocs en un seul coup.']);

        $sameColorClicks = $game->achievements()->updateOrCreate(['key' => 'same_color_clicks'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sameColorClicks->levels()->updateOrCreate(['level' => 1], ['target' => 8, 'reward' => 100, 'title' => 'C\'est une stratégie', 'description' => 'Cliquer 8 fois de suite sur la même couleur.']);
        $sameColorClicks->levels()->updateOrCreate(['level' => 2], ['target' => 10, 'reward' => 500, 'title' => 'C\'est une erreur', 'description' => 'Cliquer 10 fois de suite sur la même couleur.']);
        $sameColorClicks->levels()->updateOrCreate(['level' => 3], ['target' => 12, 'reward' => 1000, 'title' => 'C\'est un têtu', 'description' => 'Cliquer 12 fois de suite sur la même couleur.']);

        $sameCellClicks = $game->achievements()->updateOrCreate(['key' => 'same_cell_clicks'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sameCellClicks->levels()->updateOrCreate(['level' => 1], ['target' => 3, 'reward' => 250, 'title' => 'Il existe d\'autres cases', 'description' => 'Cliquer trois fois de suite sur la même case.']);

        $rgb = $game->achievements()->updateOrCreate(['key' => 'rgb'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $rgb->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 1000, 'title' => 'RGB', 'description' => 'Atteindre un score de 160.000 en alternant toujours Rouge, Vert, Bleu, Rouge, Vert, Bleu...']);

        $bicolor = $game->achievements()->updateOrCreate(['key' => 'bicolor'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $bicolor->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 2000, 'title' => 'Bicolor', 'description' => 'Atteindre un score de 200.000 en utilisant seulement 2 couleurs.']);
    }

    private function createOpalus2Achievements()
    {
        $game = $this->games->where('game_key', 'opalus2')->first();
        if (!$game) {
            return;
        }

        $miniScore = $game->achievements()->updateOrCreate(['key' => 'mini_score'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $miniScore->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 2000, 'title' => 'Minimaliste', 'description' => 'Faire un score de 6.750.']);

        $totalFallenBubbles = $game->achievements()->updateOrCreate(['key' => 'total_fallen_bubbles'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalFallenBubbles->levels()->updateOrCreate(['level' => 1], ['target' => 100, 'reward' => 100, 'title' => 'Dégringolade', 'description' => 'Faire tomber un total cumulé de 100 billes.']);
        $totalFallenBubbles->levels()->updateOrCreate(['level' => 2], ['target' => 1000, 'reward' => 500, 'title' => 'Effondrement', 'description' => 'Faire tomber un total cumulé de 1.000 billes.']);
        $totalFallenBubbles->levels()->updateOrCreate(['level' => 3], ['target' => 10000, 'reward' => 1000, 'title' => 'Avalanche', 'description' => 'Faire tomber un total cumulé de 10.000 billes.']);

        $destroyedBubbles = $game->achievements()->updateOrCreate(['key' => 'destroyed_bubbles'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $destroyedBubbles->levels()->updateOrCreate(['level' => 1], ['target' => 1000, 'reward' => 100, 'title' => 'Eclateur de billes', 'description' => 'Détruire un total cumulé de 1.000 billes.']);
        $destroyedBubbles->levels()->updateOrCreate(['level' => 2], ['target' => 10000, 'reward' => 500, 'title' => 'Destructeur de balles', 'description' => 'Détruire un total cumulé de 10.000 billes.']);
        $destroyedBubbles->levels()->updateOrCreate(['level' => 3], ['target' => 25000, 'reward' => 1000, 'title' => 'Anihilateur d\'exosphères', 'description' => 'Détruire un total cumulé de 25.000 billes.']);

        $sameColorDestroyedBubbles = $game->achievements()->updateOrCreate(['key' => 'same_color_destroyed_bubbles'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sameColorDestroyedBubbles->levels()->updateOrCreate(['level' => 1], ['target' => 15, 'reward' => 100, 'title' => 'Éclatement', 'description' => 'Détruire 15 billes d\'une couleur en un seul coup.']);
        $sameColorDestroyedBubbles->levels()->updateOrCreate(['level' => 2], ['target' => 21, 'reward' => 500, 'title' => 'Massacre', 'description' => 'Détruire 21 billes d\'une couleur en un seul coup.']);
        $sameColorDestroyedBubbles->levels()->updateOrCreate(['level' => 3], ['target' => 27, 'reward' => 1000, 'title' => 'Strike monochrome', 'description' => 'Détruire 27 billes d\'une couleur en un seul coup.']);

        $noFallenBubbles = $game->achievements()->updateOrCreate(['key' => 'no_fallen_bubbles'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $noFallenBubbles->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 250, 'title' => 'Solide sur les appuis', 'description' => 'Finir une partie sans une seule bille tombée.']);

        $tenFallenBubbles = $game->achievements()->updateOrCreate(['key' => 'fallen_bubbles'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $tenFallenBubbles->levels()->updateOrCreate(['level' => 1], ['target' => 15, 'reward' => 1000, 'title' => 'Chute dans le peloton', 'description' => 'Faire tomber 15 billes d\'un coup.']);

        $magellan = $game->achievements()->updateOrCreate(['key' => 'magellan'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $magellan->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 2000, 'title' => 'Magellan', 'description' => 'Atteindre les 4 bords du plateau dans une seule partie.']);

        $colorBlindness = $game->achievements()->updateOrCreate(['key' => 'color_blindness'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $colorBlindness->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 2000, 'title' => 'Daltonisme', 'description' => 'Finir une partie en ne cliquant que sur des billes de 2 couleurs différentes.']);

        $rainbow = $game->achievements()->updateOrCreate(['key' => 'rainbow'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $rainbow->levels()->updateOrCreate(['level' => 1], ['target' => 7, 'reward' => 2000, 'title' => 'Arc-en-ciel', 'description' => 'Faire tomber une bille de chaque couleur en un seul coup.']);
    }

    private function createKSlashAchievements()
    {
        $game = $this->games->where('game_key', 'kslash')->first();
        if (!$game) {
            return;
        }

        $voodoo = $game->achievements()->updateOrCreate(['key' => 'voodoo'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $voodoo->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 1000, 'title' => 'Voyage initiatique', 'description' => 'Récolter une poupée vaudou.']);

        $killTankers = $game->achievements()->updateOrCreate(['key' => 'kill_tankers'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killTankers->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 100, 'title' => 'Guerrier', 'description' => 'Tuer un total cumulé de 10 Tankers.']);
        $killTankers->levels()->updateOrCreate(['level' => 2], ['target' => 50, 'reward' => 500, 'title' => 'Maître', 'description' => 'Tuer un total cumulé de 50 Tankers.']);
        $killTankers->levels()->updateOrCreate(['level' => 3], ['target' => 1000, 'reward' => 1000, 'title' => 'Ninja', 'description' => 'Tuer un total cumulé de 1.000 Tankers.']);

        $softKillTurtles = $game->achievements()->updateOrCreate(['key' => 'soft_kill_turtles'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $softKillTurtles->levels()->updateOrCreate(['level' => 1], ['target' => 50, 'reward' => 100, 'title' => 'Ça va pas la tête ?!', 'description' => 'Tuer un total cumulé de 50 Tortues en leur sautant dessus.']);
        $softKillTurtles->levels()->updateOrCreate(['level' => 2], ['target' => 250, 'reward' => 500, 'title' => 'Assomeur de tortues', 'description' => 'Tuer un total cumulé de 250 Tortues en leur sautant dessus.']);
        $softKillTurtles->levels()->updateOrCreate(['level' => 3], ['target' => 750, 'reward' => 1000, 'title' => 'Plombier moustachu', 'description' => 'Tuer un total cumulé de 750 Tortues en leur sautant dessus.']);

        $softKillBats = $game->achievements()->updateOrCreate(['key' => 'soft_kill_bats'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $softKillBats->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 100, 'title' => 'Bat-paf', 'description' => 'Tuer un total cumulé de 5 Chauve-souris en leur sautant dessus.']);
        $softKillBats->levels()->updateOrCreate(['level' => 2], ['target' => 20, 'reward' => 500, 'title' => 'Bat-crêpe', 'description' => 'Tuer un total cumulé de 20 Chauve-souris en leur sautant dessus.']);
        $softKillBats->levels()->updateOrCreate(['level' => 3], ['target' => 50, 'reward' => 1000, 'title' => 'Batman n\'a qu\'à bien se tenir', 'description' => 'Tuer un total cumulé de 50 Chauve-souris en leur sautant dessus.']);

        $softKillTankers = $game->achievements()->updateOrCreate(['key' => 'soft_kill_tankers'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $softKillTankers->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 100, 'title' => 'Pied de nez', 'description' => 'Tuer un total cumulé de 5 Tankers en leur sautant dessus.']);
        $softKillTankers->levels()->updateOrCreate(['level' => 2], ['target' => 25, 'reward' => 500, 'title' => 'Piétineur', 'description' => 'Tuer un total cumulé de 25 Tankers en leur sautant dessus.']);
        $softKillTankers->levels()->updateOrCreate(['level' => 3], ['target' => 150, 'reward' => 1000, 'title' => 'Coup de pied latéral en pleine face', 'description' => 'Tuer un total cumulé de 150 Tankers en leur sautant dessus.']);

        $superStarKills = $game->achievements()->updateOrCreate(['key' => 'super_star_kills'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $superStarKills->levels()->updateOrCreate(['level' => 1], ['target' => 50, 'reward' => 100, 'title' => 'Plus invincible que le slip de Superman', 'description' => 'Tuer un total cumulé de 50 monstres avec le bonus étoile.']);
        $superStarKills->levels()->updateOrCreate(['level' => 2], ['target' => 150, 'reward' => 500, 'title' => 'Plus invincible que Benoît Brisefer sous antihistaminiques', 'description' => 'Tuer un total cumulé de 150 monstres avec le bonus étoile.']);
        $superStarKills->levels()->updateOrCreate(['level' => 3], ['target' => 500, 'reward' => 1000, 'title' => 'Plus invincible qu\'Achille cul-de-jatte', 'description' => 'Tuer un total cumulé de 500 monstres avec le bonus étoile.']);

        $noShurikenScore = $game->achievements()->updateOrCreate(['key' => 'no_shuriken_score'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $noShurikenScore->levels()->updateOrCreate(['level' => 1], ['target' => 5000, 'reward' => 100, 'title' => 'Peace & Slash', 'description' => 'Atteindre un score de 5.000 sans utiliser de shurikens.']);
        $noShurikenScore->levels()->updateOrCreate(['level' => 2], ['target' => 12000, 'reward' => 500, 'title' => 'Maître d\'armes', 'description' => 'Atteindre un score de 12.000 sans utiliser de shurikens.']);
        $noShurikenScore->levels()->updateOrCreate(['level' => 3], ['target' => 20000, 'reward' => 1000, 'title' => 'La voie du sabre', 'description' => 'Atteindre un score de 20.000 sans utiliser de shurikens.']);

        $shurikenStock = $game->achievements()->updateOrCreate(['key' => 'shuriken_stock'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $shurikenStock->levels()->updateOrCreate(['level' => 1], ['target' => 200, 'reward' => 250, 'title' => 'Réserves', 'description' => 'Atteindre 200 shurikens en stock.']);

        $allBonuses = $game->achievements()->updateOrCreate(['key' => 'all_bonuses'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $allBonuses->levels()->updateOrCreate(['level' => 1], ['target' => 7, 'reward' => 1000, 'title' => 'Je suis increvab...', 'description' => 'Obtenir les 3 bonus en même temps.']);

        $diversity = $game->achievements()->updateOrCreate(['key' => 'diversity'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $diversity->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 1000, 'title' => 'Diversité', 'description' => 'Tuer un monstre de chaque type en une partie.']);

        $threeRespawns = $game->achievements()->updateOrCreate(['key' => 'three_respawns'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $threeRespawns->levels()->updateOrCreate(['level' => 1], ['target' => 3, 'reward' => 2000, 'title' => 'Plus fort que la mort', 'description' => 'Réapparaître 3 fois dans une partie.']);
    }

    private function createMagmaxAchievements()
    {
        $game = $this->games->where('game_key', 'magmax')->first();
        if (!$game) {
            return;
        }

        $turretsKilled = $game->achievements()->updateOrCreate(['key' => 'turrets_killed'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $turretsKilled->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 100, 'title' => 'Démontage de tourelle', 'description' => 'Tuer 10 tourelles.']);
        $turretsKilled->levels()->updateOrCreate(['level' => 2], ['target' => 100, 'reward' => 500, 'title' => 'Poussière de tourelle', 'description' => 'Tuer 100 tourelles.']);
        $turretsKilled->levels()->updateOrCreate(['level' => 3], ['target' => 1000, 'reward' => 1000, 'title' => 'Syndrome de la Tourelle', 'description' => 'Tuer 1.000 tourelles.']);

        $gemsCollected = $game->achievements()->updateOrCreate(['key' => 'gems_collected'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $gemsCollected->levels()->updateOrCreate(['level' => 1], ['target' => 100, 'reward' => 100, 'title' => 'Premier collier', 'description' => 'Obtenir 100 boules de couleur.']);
        $gemsCollected->levels()->updateOrCreate(['level' => 2], ['target' => 1000, 'reward' => 500, 'title' => 'Chasseur de perles', 'description' => 'Obtenir 1.000 boules de couleur.']);
        $gemsCollected->levels()->updateOrCreate(['level' => 3], ['target' => 10000, 'reward' => 1000, 'title' => 'Parure légendaire', 'description' => 'Obtenir 10.000 boules de couleur.']);

        $flowersOneGame = $game->achievements()->updateOrCreate(['key' => 'flowers_one_game'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $flowersOneGame->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 100, 'title' => 'Désherbage express', 'description' => 'Tuer 5 fleurs en une seule partie.']);
        $flowersOneGame->levels()->updateOrCreate(['level' => 2], ['target' => 10, 'reward' => 500, 'title' => 'Le beau bouquet', 'description' => 'Tuer 10 fleurs en une seule partie.']);
        $flowersOneGame->levels()->updateOrCreate(['level' => 3], ['target' => 15, 'reward' => 1000, 'title' => 'Fléau des Pétales', 'description' => 'Tuer 15 fleurs en une seule partie.']);

        $magmax = $game->achievements()->updateOrCreate(['key' => 'magmax'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $magmax->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 250, 'title' => 'Maximaxeur', 'description' => 'Faire un Magmax.']);

        $bothBonuses = $game->achievements()->updateOrCreate(['key' => 'both_bonuses'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $bothBonuses->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 1000, 'title' => 'Armé jusqu\'aux dents', 'description' => 'Obtenir les 2 bonus spéciaux en même temps.']);

        $killOrder = $game->achievements()->updateOrCreate(['key' => 'kill_order'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killOrder->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 2000, 'title' => 'Tri séquentiel', 'description' => 'Tuer dans l\'ordre goutte, fleur et tourelle dans un même combo.']);
    }

    private function createKanjiAchievements()
    {
        $game = $this->games->where('game_key', 'kanji')->first();
        if (!$game) {
            return;
        }

        $gatherBonus = $game->achievements()->updateOrCreate(['key' => 'gather_bonus'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $gatherBonus->levels()->updateOrCreate(['level' => 1], ['target' => 1000, 'reward' => 100, 'title' => 'Ceuilleur', 'description' => 'Récupérer un total cumulé de 1.000 bonus.']);
        $gatherBonus->levels()->updateOrCreate(['level' => 2], ['target' => 5000, 'reward' => 500, 'title' => 'Glaneur', 'description' => 'Récupérer un total cumulé de 5.000 bonus.']);
        $gatherBonus->levels()->updateOrCreate(['level' => 3], ['target' => 15000, 'reward' => 1000, 'title' => 'Collectionneur', 'description' => 'Récupérer un total cumulé de 15.000 bonus.']);

        $killStorks = $game->achievements()->updateOrCreate(['key' => 'kill_storks'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killStorks->levels()->updateOrCreate(['level' => 1], ['target' => 500, 'reward' => 100, 'title' => 'Je déteste la faune', 'description' => 'Rebondir un total cumulé de 500 fois sur des cigognes.']);
        $killStorks->levels()->updateOrCreate(['level' => 2], ['target' => 2500, 'reward' => 500, 'title' => 'À mort les zozios !', 'description' => 'Rebondir un total cumulé de 2.500 fois sur des cigognes.']);
        $killStorks->levels()->updateOrCreate(['level' => 3], ['target' => 5000, 'reward' => 1000, 'title' => 'Hécatombe aviaire', 'description' => 'Rebondir un total cumulé de 5.000 fois sur des cigognes.']);

        $wallJumps = $game->achievements()->updateOrCreate(['key' => 'wall_jumps'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $wallJumps->levels()->updateOrCreate(['level' => 1], ['target' => 50, 'reward' => 100, 'title' => 'Boing', 'description' => 'Rebondir un total cumulé de 50 fois sur les murs.']);
        $wallJumps->levels()->updateOrCreate(['level' => 2], ['target' => 250, 'reward' => 500, 'title' => 'Solides ces murs !', 'description' => 'Rebondir un total cumulé de 250 fois sur les murs.']);
        $wallJumps->levels()->updateOrCreate(['level' => 3], ['target' => 750, 'reward' => 1000, 'title' => 'Platrier de père en fils', 'description' => 'Rebondir un total cumulé de 750 fois sur les murs.']);

        $avoidBoars = $game->achievements()->updateOrCreate(['key' => 'avoid_boars'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $avoidBoars->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 100, 'title' => 'Ça sent le cochon non ?', 'description' => 'Éviter un total cumulé de 10 marcassins.']);
        $avoidBoars->levels()->updateOrCreate(['level' => 2], ['target' => 100, 'reward' => 500, 'title' => 'On n\'a pas gardé les cochons ensemble', 'description' => 'Éviter un total cumulé de 100 marcassins.']);
        $avoidBoars->levels()->updateOrCreate(['level' => 3], ['target' => 1000, 'reward' => 1000, 'title' => 'Maître de la harde', 'description' => 'Éviter un total cumulé de 1.000 marcassins.']);

        $avoidBoarsShort = $game->achievements()->updateOrCreate(['key' => 'avoid_boars_short'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $avoidBoarsShort->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 100, 'title' => 'Pas folle la guêpe', 'description' => 'Esquiver 1 marcassin avec des mini-sauts en une partie.']);
        $avoidBoarsShort->levels()->updateOrCreate(['level' => 2], ['target' => 4, 'reward' => 500, 'title' => 'Allez salto !', 'description' => 'Esquiver 4 marcassins avec des mini-sauts en une partie.']);
        $avoidBoarsShort->levels()->updateOrCreate(['level' => 3], ['target' => 8, 'reward' => 1000, 'title' => 'Ninja 8ème dan', 'description' => 'Esquiver 8 marcassins avec des mini-sauts en une partie.']);

        $killStreak = $game->achievements()->updateOrCreate(['key' => 'kill_streak'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killStreak->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 100, 'title' => 'Floor is lava', 'description' => 'Rebondir sur 5 cigognes sans toucher le sol.']);
        $killStreak->levels()->updateOrCreate(['level' => 2], ['target' => 15, 'reward' => 500, 'title' => 'Expert de la voltige', 'description' => 'Rebondir sur 15 cigognes sans toucher le sol.']);
        $killStreak->levels()->updateOrCreate(['level' => 3], ['target' => 25, 'reward' => 1000, 'title' => 'Pilote de la patrouille de France', 'description' => 'Rebondir sur 25 cigognes sans toucher le sol.']);

        $noStorkKillScore = $game->achievements()->updateOrCreate(['key' => 'no_stork_kill_score'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $noStorkKillScore->levels()->updateOrCreate(['level' => 1], ['target' => 15000, 'reward' => 100, 'title' => 'Amoureux de la faune', 'description' => 'Atteindre 15.000 points sans tuer de cigognes.']);
        $noStorkKillScore->levels()->updateOrCreate(['level' => 2], ['target' => 25000, 'reward' => 500, 'title' => 'peace and love', 'description' => 'Atteindre 25.000 points sans tuer de cigognes.']);
        $noStorkKillScore->levels()->updateOrCreate(['level' => 3], ['target' => 35000, 'reward' => 1000, 'title' => 'Vegan', 'description' => 'Atteindre 35.000 points sans tuer de cigognes.']);

        $bonusStreak = $game->achievements()->updateOrCreate(['key' => 'bonus_streak'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $bonusStreak->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 250, 'title' => 'Regarde comme je saute bien', 'description' => 'Récupérer 5 bonus en un saut sans rebondir sur des cigognes.']);

        $lastKillCount = $game->achievements()->updateOrCreate(['key' => 'last_kill_count'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $lastKillCount->levels()->updateOrCreate(['level' => 1], ['target' => 15, 'reward' => 1000, 'title' => 'Allez on arrête de spawn là', 'description' => 'Tuer la dernière cigogne en vie 15 fois dans la même partie.']);

        $flyStreak = $game->achievements()->updateOrCreate(['key' => 'fly_streak'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $flyStreak->levels()->updateOrCreate(['level' => 1], ['target' => 25, 'reward' => 2000, 'title' => 'I believe I can fly', 'description' => 'Rester 25 secondes en l\'air.']);
    }

    private function createTravoltaxAchievements()
    {
        $game = $this->games->where('game_key', 'travoltax')->first();
        if (!$game) {
            return;
        }

        $destroyLines = $game->achievements()->updateOrCreate(['key' => 'destroy_lines'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $destroyLines->levels()->updateOrCreate(['level' => 1], ['target' => 2000, 'reward' => 100, 'title' => 'Paragraphe 2000', 'description' => 'Détruire un total cumulé de 2.000 lignes.']);
        $destroyLines->levels()->updateOrCreate(['level' => 2], ['target' => 10000, 'reward' => 500, 'title' => 'Alinéa 10.000', 'description' => 'Détruire un total cumulé de 10.000 lignes.']);
        $destroyLines->levels()->updateOrCreate(['level' => 3], ['target' => 25000, 'reward' => 1000, 'title' => 'Ligne 25.000', 'description' => 'Détruire un total cumulé de 25.000 lignes.']);

        $useCalm = $game->achievements()->updateOrCreate(['key' => 'use_calm'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $useCalm->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 100, 'title' => 'Souffle un coup', 'description' => 'Utiliser 1 bonus "calme".']);
        $useCalm->levels()->updateOrCreate(['level' => 2], ['target' => 20, 'reward' => 500, 'title' => 'Calme raplapla', 'description' => 'Utiliser un total cumulé de 20 bonus "calme".']);
        $useCalm->levels()->updateOrCreate(['level' => 3], ['target' => 40, 'reward' => 1000, 'title' => 'Zénitude attitude', 'description' => 'Utiliser un total cumulé de 40 bonus "calme".']);

        $usePsycho = $game->achievements()->updateOrCreate(['key' => 'use_psycho'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $usePsycho->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 100, 'title' => 'Upside down', 'description' => 'Utiliser 1 bonus "psycho" en une seule partie.']);
        $usePsycho->levels()->updateOrCreate(['level' => 2], ['target' => 3, 'reward' => 500, 'title' => 'Fou furieux', 'description' => 'Utiliser 3 bonus "psycho" en une seule partie.']);
        $usePsycho->levels()->updateOrCreate(['level' => 3], ['target' => 5, 'reward' => 1000, 'title' => 'The Joker', 'description' => 'Utiliser 5 bonus "psycho" en une seule partie.']);

        $destroyTenLines = $game->achievements()->updateOrCreate(['key' => 'destroy_ten_lines'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $destroyTenLines->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 2000, 'title' => 'Décimation linéaire', 'description' => 'Détruire 10 lignes d\'un coup.']);

        $clearGrid = $game->achievements()->updateOrCreate(['key' => 'clear_grid'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $clearGrid->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 250, 'title' => 'Total reset', 'description' => 'Vider entièrement la grille.']);

        $coldSweats = $game->achievements()->updateOrCreate(['key' => 'cold_sweats'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $coldSweats->levels()->updateOrCreate(['level' => 1], ['target' => 30, 'reward' => 1000, 'title' => 'Sueurs froides', 'description' => 'Survivre 30 secondes alors qu\'il y a des pièces jusqu\'au plafond.']);

        $mafia = $game->achievements()->updateOrCreate(['key' => 'mafia'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $mafia->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 2000, 'title' => 'Mafieux', 'description' => 'Réussir un contrat à 8.000 points minimum.']);
    }

    private function createSynapsesAchievements()
    {
        $game = $this->games->where('game_key', 'synapses')->first();
        if (!$game) {
            return;
        }

        $totalNeuronsConnected = $game->achievements()->updateOrCreate(['key' => 'total_neurons_connected'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalNeuronsConnected->levels()->updateOrCreate(['level' => 1], ['target' => 2500, 'reward' => 100, 'title' => 'Psychologue', 'description' => 'Connecter un total de 2.500 neurones.']);
        $totalNeuronsConnected->levels()->updateOrCreate(['level' => 2], ['target' => 10000, 'reward' => 500, 'title' => 'Psychiatre', 'description' => 'Connecter un total de 10.000 neurones.']);
        $totalNeuronsConnected->levels()->updateOrCreate(['level' => 3], ['target' => 100000, 'reward' => 1000, 'title' => 'Neurochirurgien', 'description' => 'Connecter un total de 100.000 neurones.']);

        $levelOneScore = $game->achievements()->updateOrCreate(['key' => 'level_one_score'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $levelOneScore->levels()->updateOrCreate(['level' => 1], ['target' => 25000, 'reward' => 100, 'title' => 'Je valide', 'description' => 'Atteindre un score de 25.000 au niveau 1.']);
        $levelOneScore->levels()->updateOrCreate(['level' => 2], ['target' => 30000, 'reward' => 500, 'title' => 'C\'est OK', 'description' => 'Atteindre un score de 30.000 au niveau 1.']);
        $levelOneScore->levels()->updateOrCreate(['level' => 3], ['target' => 35000, 'reward' => 1000, 'title' => 'C\'est nickel', 'description' => 'Atteindre un score de 35.000 au niveau 1.']);

        $neuronScore = $game->achievements()->updateOrCreate(['key' => 'neuron_score'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $neuronScore->levels()->updateOrCreate(['level' => 1], ['target' => 500, 'reward' => 100, 'title' => 'Bon sens', 'description' => 'Atteindre un neurone à 500 points.']);
        $neuronScore->levels()->updateOrCreate(['level' => 2], ['target' => 600, 'reward' => 500, 'title' => 'Lucidité', 'description' => 'Atteindre un neurone à 600 points.']);
        $neuronScore->levels()->updateOrCreate(['level' => 3], ['target' => 700, 'reward' => 1000, 'title' => 'Clairvoyance', 'description' => 'Atteindre un neurone à 700 points.']);

        $afk = $game->achievements()->updateOrCreate(['key' => 'afk'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $afk->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 250, 'title' => 'AFK', 'description' => 'Gagner un niveau sans cliquer.']);

        $champion = $game->achievements()->updateOrCreate(['key' => 'champion'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $champion->levels()->updateOrCreate(['level' => 1], ['target' => 40, 'reward' => 1000, 'title' => 'Champion', 'description' => 'Gagner contre 4 adversaires en même temps avec au moins 40 neurones connectés.']);

        $tieWin = $game->achievements()->updateOrCreate(['key' => 'tie_win'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $tieWin->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 1000, 'title' => 'Arbitre partial', 'description' => 'Gagner sur une égalité.']);

        $crushingVictory = $game->achievements()->updateOrCreate(['key' => 'crushing_victory'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $crushingVictory->levels()->updateOrCreate(['level' => 1], ['target' => 75, 'reward' => 2000, 'title' => 'Victoire écrasante', 'description' => 'À partir du niveau 3, gagner avec au moins 75 neurones connectés.']);
    }

    private function createXianXiangAchievements()
    {
        $game = $this->games->where('game_key', 'xianxiang')->first();
        if (!$game) {
            return;
        }

        $totalTiles = $game->achievements()->updateOrCreate(['key' => 'total_tiles'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalTiles->levels()->updateOrCreate(['level' => 1], ['target' => 500, 'reward' => 100, 'title' => 'Premier nettoyage', 'description' => 'Détruire 500 tuiles.']);
        $totalTiles->levels()->updateOrCreate(['level' => 2], ['target' => 2000, 'reward' => 500, 'title' => 'Nettoyeur de plateau', 'description' => 'Détruire 2.000 tuiles.']);
        $totalTiles->levels()->updateOrCreate(['level' => 3], ['target' => 10000, 'reward' => 1000, 'title' => 'Apocalypse de tuiles', 'description' => 'Détruire 10.000 tuiles.']);

        $perfectNeighbours = $game->achievements()->updateOrCreate(['key' => 'perfect_neighbours'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $perfectNeighbours->levels()->updateOrCreate(['level' => 1], ['target' => 20, 'reward' => 100, 'title' => 'Voisins proches', 'description' => 'Rassembler 20 paires parfaites côte à côte.']);
        $perfectNeighbours->levels()->updateOrCreate(['level' => 2], ['target' => 100, 'reward' => 500, 'title' => 'Collé-serré', 'description' => 'Rassembler 100 paires parfaites côte à côte.']);
        $perfectNeighbours->levels()->updateOrCreate(['level' => 3], ['target' => 400, 'reward' => 1000, 'title' => 'Comité de jumelage', 'description' => 'Rassembler 400 paires parfaites côte à côte.']);

        $perfectPairs = $game->achievements()->updateOrCreate(['key' => 'perfect_pairs'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $perfectPairs->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 100, 'title' => 'Déca-jonction', 'description' => 'Rassembler 10 paires parfaites en une seule partie.']);
        $perfectPairs->levels()->updateOrCreate(['level' => 2], ['target' => 12, 'reward' => 500, 'title' => 'Dodéca-appairage', 'description' => 'Rassembler 12 paires parfaites en une seule partie.']);
        $perfectPairs->levels()->updateOrCreate(['level' => 3], ['target' => 14, 'reward' => 1000, 'title' => 'Tetrakaideca-paires', 'description' => 'Rassembler 14 paires parfaites en une seule partie.']);

        $noOnePointPair = $game->achievements()->updateOrCreate(['key' => 'no_one_point_pair'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $noOnePointPair->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 250, 'title' => 'Oh, un chiffre rond', 'description' => 'Finir une partie sans paire à 1 point.']);

        $minScore = $game->achievements()->updateOrCreate(['key' => 'min_score'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $minScore->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 1000, 'title' => 'Premier (en partant de la fin)', 'description' => 'Faire un score de 21.']);

        $perfectColors = $game->achievements()->updateOrCreate(['key' => 'perfect_colors'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $perfectColors->levels()->updateOrCreate(['level' => 1], ['target' => 2, 'reward' => 2000, 'title' => 'Il y en aura pour tout le monde', 'description' => 'Effectuer au moins 2 paires parfaites de chaque couleur en 1 seule partie.']);
    }

    private function createTiananManAchievements()
    {
        $game = $this->games->where('game_key', 'tiananman')->first();
        if (!$game) {
            return;
        }

        $followersCollected = $game->achievements()->updateOrCreate(['key' => 'followers_collected'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $followersCollected->levels()->updateOrCreate(['level' => 1], ['target' => 500, 'reward' => 100, 'title' => 'Viendez les zamis', 'description' => 'Récupérer 500 manifestants.']);
        $followersCollected->levels()->updateOrCreate(['level' => 2], ['target' => 5000, 'reward' => 500, 'title' => 'On est fâchés tout rouge', 'description' => 'Récupérer 5.000 manifestants.']);
        $followersCollected->levels()->updateOrCreate(['level' => 3], ['target' => 20000, 'reward' => 1000, 'title' => 'Plus on est de fous moins il y a de riz', 'description' => 'Récupérer 20.000 manifestants.']);

        $vehiclesDestroyed = $game->achievements()->updateOrCreate(['key' => 'vehicles_destroyed'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $vehiclesDestroyed->levels()->updateOrCreate(['level' => 1], ['target' => 50, 'reward' => 100, 'title' => 'Accident de la route', 'description' => 'Détruire 50 véhicules.']);
        $vehiclesDestroyed->levels()->updateOrCreate(['level' => 2], ['target' => 500, 'reward' => 500, 'title' => 'Cascadeur', 'description' => 'Détruire 500 véhicules.']);
        $vehiclesDestroyed->levels()->updateOrCreate(['level' => 3], ['target' => 2000, 'reward' => 1000, 'title' => 'Épaviste', 'description' => 'Détruire 2.000 véhicules.']);

        $fevers = $game->achievements()->updateOrCreate(['key' => 'fevers'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fevers->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 100, 'title' => 'Dénonceur', 'description' => 'Passer en mode frénésie 1 fois en une seule partie.']);
        $fevers->levels()->updateOrCreate(['level' => 2], ['target' => 2, 'reward' => 500, 'title' => 'Proclameur', 'description' => 'Passer en mode frénésie 2 fois en une seule partie.']);
        $fevers->levels()->updateOrCreate(['level' => 3], ['target' => 3, 'reward' => 1000, 'title' => 'Contestataire', 'description' => 'Passer en mode frénésie 3 fois en une seule partie.']);

        $vehicleDiversity = $game->achievements()->updateOrCreate(['key' => 'vehicle_diversity'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $vehicleDiversity->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 250, 'title' => 'Collectionneur de carcasses', 'description' => 'Détruire 1 véhicule de chaque type en une partie avec la frénésie.']);

        $noFollowerLostFever = $game->achievements()->updateOrCreate(['key' => 'no_follower_lost_fever'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $noFollowerLostFever->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 1000, 'title' => 'Pro de la savonnette', 'description' => 'Passer en mode frénésie sans avoir perdu un seul manifestant.']);

        $lastFollowerScore = $game->achievements()->updateOrCreate(['key' => 'last_follower_score'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $lastFollowerScore->levels()->updateOrCreate(['level' => 1], ['target' => 100000, 'reward' => 2000, 'title' => 'Survivant', 'description' => 'Gagner 100.000 points en n\'ayant plus qu\'un seul point de vie.']);
    }

    private function createTubuloAchievements()
    {
        $game = $this->games->where('game_key', 'tubulo')->first();
        if (!$game) {
            return;
        }

        $levelResets = $game->achievements()->updateOrCreate(['key' => 'level_resets'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $levelResets->levels()->updateOrCreate(['level' => 1], ['target' => 25, 'reward' => 100, 'title' => 'On recommence', 'description' => 'Redémarrer 25 niveaux.']);
        $levelResets->levels()->updateOrCreate(['level' => 2], ['target' => 150, 'reward' => 500, 'title' => 'Mauvaise pioche', 'description' => 'Redémarrer 150 niveaux.']);
        $levelResets->levels()->updateOrCreate(['level' => 3], ['target' => 500, 'reward' => 1000, 'title' => 'Le réinitialiseur', 'description' => 'Redémarrer 500 niveaux.']);

        $greenPaint = $game->achievements()->updateOrCreate(['key' => 'green_paint'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $greenPaint->levels()->updateOrCreate(['level' => 1], ['target' => 1000, 'reward' => 100, 'title' => 'Peintre écolo', 'description' => 'Colorer 1.000 tubes en vert.']);
        $greenPaint->levels()->updateOrCreate(['level' => 2], ['target' => 10000, 'reward' => 500, 'title' => 'Greenwashing', 'description' => 'Colorer 10.000 tubes en vert.']);
        $greenPaint->levels()->updateOrCreate(['level' => 3], ['target' => 100000, 'reward' => 1000, 'title' => 'Vert l\'infini et l\'eau verdâtre', 'description' => 'Colorer 100.000 tubes en vert.']);

        $reachLevel = $game->achievements()->updateOrCreate(['key' => 'reach_level'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $reachLevel->levels()->updateOrCreate(['level' => 1], ['target' => 8, 'reward' => 100, 'title' => 'Octo-huitre', 'description' => 'Atteindre le niveau 8.']);
        $reachLevel->levels()->updateOrCreate(['level' => 2], ['target' => 10, 'reward' => 500, 'title' => 'Déca-bulot', 'description' => 'Atteindre le niveau 10.']);
        $reachLevel->levels()->updateOrCreate(['level' => 3], ['target' => 12, 'reward' => 1000, 'title' => 'Dodéca-moule', 'description' => 'Atteindre le niveau 12.']);

        $minScore = $game->achievements()->updateOrCreate(['key' => 'min_score'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $minScore->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 250, 'title' => 'T\'as bu l\'eau', 'description' => 'Finir la partie avec 200 points.']);

        $level9ChronoMax = $game->achievements()->updateOrCreate(['key' => 'level_9_chrono_max'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $level9ChronoMax->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 1000, 'title' => 'Neuf comme un sou', 'description' => 'Atteindre le niveau 9 en ayant le chronomètre rempli au max.']);

        $level10WithoutRetry = $game->achievements()->updateOrCreate(['key' => 'level_10_without_retry'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $level10WithoutRetry->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 2000, 'title' => 'Dix de der', 'description' => 'Atteindre le niveau 10 sans avoir redémarré de niveau.']);
    }

    private function createKillBulleAchievements()
    {
        $game = $this->games->where('game_key', 'killbulle')->first();
        if (!$game) {
            return;
        }

        $totalBubblesPopped = $game->achievements()->updateOrCreate(['key' => 'total_bubbles_popped'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalBubblesPopped->levels()->updateOrCreate(['level' => 1], ['target' => 1500, 'reward' => 100, 'title' => 'Fragmenteur', 'description' => 'Éclater 1.500 bulles.']);
        $totalBubblesPopped->levels()->updateOrCreate(['level' => 2], ['target' => 20000, 'reward' => 500, 'title' => 'Légende du Pop', 'description' => 'Éclater 20.000 bulles.']);
        $totalBubblesPopped->levels()->updateOrCreate(['level' => 3], ['target' => 100000, 'reward' => 1000, 'title' => 'Maitre de la division', 'description' => 'Éclater 100.000 bulles.']);

        $totalYingYangs = $game->achievements()->updateOrCreate(['key' => 'total_ying_yangs'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalYingYangs->levels()->updateOrCreate(['level' => 1], ['target' => 20, 'reward' => 100, 'title' => 'Calme', 'description' => 'Récupérer 20 bonus ying-yang.']);
        $totalYingYangs->levels()->updateOrCreate(['level' => 2], ['target' => 100, 'reward' => 500, 'title' => 'Tranquille', 'description' => 'Récupérer 100 bonus ying-yang.']);
        $totalYingYangs->levels()->updateOrCreate(['level' => 3], ['target' => 500, 'reward' => 1000, 'title' => 'Zen', 'description' => 'Récupérer 500 bonus ying-yang.']);

        $totalTimeBonuses = $game->achievements()->updateOrCreate(['key' => 'total_time_bonuses'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalTimeBonuses->levels()->updateOrCreate(['level' => 1], ['target' => 20, 'reward' => 100, 'title' => 'Fan de sieste', 'description' => 'Utiliser 20 bonus horloge.']);
        $totalTimeBonuses->levels()->updateOrCreate(['level' => 2], ['target' => 100, 'reward' => 500, 'title' => 'Maître du tempo', 'description' => 'Utiliser 100 bonus horloge.']);
        $totalTimeBonuses->levels()->updateOrCreate(['level' => 3], ['target' => 500, 'reward' => 1000, 'title' => 'Seigneur du temps', 'description' => 'Utiliser 500 bonus horloge.']);

        $bigBubbles = $game->achievements()->updateOrCreate(['key' => 'big_bubbles'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $bigBubbles->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 100, 'title' => 'Eclateur de baudruche', 'description' => 'Éclater 1 grosse bulle en une seule partie.']);
        $bigBubbles->levels()->updateOrCreate(['level' => 2], ['target' => 3, 'reward' => 500, 'title' => 'Dézingueur de montgolfières', 'description' => 'Éclater 3 grosses bulles en une seule partie.']);
        $bigBubbles->levels()->updateOrCreate(['level' => 3], ['target' => 5, 'reward' => 1000, 'title' => 'Massacreur de zeppelins', 'description' => 'Éclater 5 grosses bulles en une seule partie.']);

        $tenWithKunai = $game->achievements()->updateOrCreate(['key' => 'ten_with_kunai'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $tenWithKunai->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 250, 'title' => 'Boucher', 'description' => 'Éclater 10 bulles avec un seul bonus de kunais.']);

        $tenWithShuriken = $game->achievements()->updateOrCreate(['key' => 'ten_with_shuriken'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $tenWithShuriken->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 1000, 'title' => 'Ninja', 'description' => 'Éclater 10 bulles avec un seul bonus shuriken.']);

        $tenWithTimeBonus = $game->achievements()->updateOrCreate(['key' => 'ten_with_time_bonus'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $tenWithTimeBonus->levels()->updateOrCreate(['level' => 1], ['target' => 10, 'reward' => 2000, 'title' => 'Le temps est une bulle', 'description' => 'Éclater 10 bulles pendant un seul bonus de temps.']);
    }

    private function createKanjisNightmareAchievements()
    {
        $game = $this->games->where('game_key', 'kanjisnightmare')->first();
        if (!$game) {
            return;
        }

        $totalBlueTurtlesKilled = $game->achievements()->updateOrCreate(['key' => 'total_blue_turtles_killed'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalBlueTurtlesKilled->levels()->updateOrCreate(['level' => 1], ['target' => 25, 'reward' => 100, 'title' => 'Ninja vs Tortues', 'description' => 'Tuer un total cumulé de 25 tortues bleues.']);
        $totalBlueTurtlesKilled->levels()->updateOrCreate(['level' => 2], ['target' => 100, 'reward' => 500, 'title' => 'Extinction bleue', 'description' => 'Tuer un total cumulé de 100 tortues bleues.']);
        $totalBlueTurtlesKilled->levels()->updateOrCreate(['level' => 3], ['target' => 250, 'reward' => 1000, 'title' => 'Némésis bleue', 'description' => 'Tuer un total cumulé de 250 tortues bleues.']);

        $killTurtles = $game->achievements()->updateOrCreate(['key' => 'turtles_killed'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killTurtles->levels()->updateOrCreate(['level' => 1], ['target' => 50, 'reward' => 100, 'title' => 'Tortue luth', 'description' => 'Tuer 50 tortues en une seule partie.']);
        $killTurtles->levels()->updateOrCreate(['level' => 2], ['target' => 100, 'reward' => 500, 'title' => 'Tortue ninja', 'description' => 'Tuer 100 tortues en une seule partie.']);
        $killTurtles->levels()->updateOrCreate(['level' => 3], ['target' => 150, 'reward' => 1000, 'title' => 'Tortueur', 'description' => 'Tuer 150 tortues en une seule partie.']);

        $getHooks = $game->achievements()->updateOrCreate(['key' => 'get_hooks'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $getHooks->levels()->updateOrCreate(['level' => 1], ['target' => 4, 'reward' => 100, 'title' => 'Bonus hepta-cool !', 'description' => 'Obtenir 7 grapins permanents en une seule partie.']);
        $getHooks->levels()->updateOrCreate(['level' => 2], ['target' => 5, 'reward' => 500, 'title' => 'Méthode octo-turbo', 'description' => 'Obtenir 8 grapins permanents en une seule partie.']);

        $repairBrokenArmor = $game->achievements()->updateOrCreate(['key' => 'repair_broken_armor'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $repairBrokenArmor->levels()->updateOrCreate(['level' => 1], ['target' => 1, 'reward' => 250, 'title' => 'Lessive terminée !', 'description' => 'Réparer une armure cassée.']);

        $getThreePermanentOpts = $game->achievements()->updateOrCreate(['key' => 'get_three_permanent_opts'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $getThreePermanentOpts->levels()->updateOrCreate(['level' => 1], ['target' => 3, 'reward' => 1000, 'title' => 'Opération triforce', 'description' => 'Obtenir 3 bonus permanents en même temps.']);

        $getAllPermanentOpts = $game->achievements()->updateOrCreate(['key' => 'get_all_permanent_opts'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $getAllPermanentOpts->levels()->updateOrCreate(['level' => 1], ['target' => 5, 'reward' => 2000, 'title' => 'Équipement militaire', 'description' => 'Obtenir tous les bonus permanents en même temps.']);

        $totalGraphinsUsed = $game->achievements()->updateOrCreate(['key' => 'total_graphins_used'], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalGraphinsUsed->levels()->updateOrCreate(['level' => 1], ['target' => 500, 'reward' => 100, 'title' => 'Niveau ouistiti', 'description' => 'Utiliser le grapin 500 fois.']);
        $totalGraphinsUsed->levels()->updateOrCreate(['level' => 2], ['target' => 10000, 'reward' => 500, 'title' => 'Niveau gibbon', 'description' => 'Utiliser le grapin 10.000 fois.']);
        $totalGraphinsUsed->levels()->updateOrCreate(['level' => 3], ['target' => 25000, 'reward' => 1000, 'title' => 'Niveau orang-outan', 'description' => 'Utiliser le grapin 25.000 fois.']);
    }
}
