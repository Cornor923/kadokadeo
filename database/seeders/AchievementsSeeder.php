<?php

namespace Database\Seeders;

use App\Enums\AchievementCategory;
use App\Enums\AchievementProgressScope;
use App\Models\Achievement;
use App\Models\Game;
use Illuminate\Database\Seeder;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;

class AchievementsSeeder extends Seeder
{
    private Collection $games;

    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        if (Achievement::query()->count() > 0) {
            Log::info('Achievements already seeded, skipping.');

            return;
        }

        $this->games = Game::all();

        $this->createAtlanteineAchievements();
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
        $this->createZipZapAchievements();
        $this->createCommonGameAchievements();
    }

    private function createAtlanteineAchievements()
    {
        $game = $this->games->where('game_key', 'atlanteine')->first();
        if (!$game) {
            return;
        }

        $ghostsKilled = $game->achievements()->create(['game_id' => $game->id, 'key' => 'ghosts_killed', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $ghostsKilled->levels()->create(['level' => 1, 'target' => 1, 'reward' => 100, 'title' => 'Bouh!', 'description' => 'Tuer 1 fantôme.']);
        $ghostsKilled->levels()->create(['level' => 2, 'target' => 50, 'reward' => 500, 'title' => 'Masacre ectoplasmique', 'description' => 'Tuer 50 fantômes.']);
        $ghostsKilled->levels()->create(['level' => 3, 'target' => 200, 'reward' => 1000, 'title' => 'Chasseur sans tête', 'description' => 'Tuer 200 fantômes.']);

        $boxesMoved = $game->achievements()->create(['game_id' => $game->id, 'key' => 'boxes_moved', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $boxesMoved->levels()->create(['level' => 1, 'target' => 10, 'reward' => 100, 'title' => 'Brocanteur', 'description' => 'Déplacer 10 caisses.']);
        $boxesMoved->levels()->create(['level' => 2, 'target' => 50, 'reward' => 500, 'title' => 'Déménageur', 'description' => 'Déplacer 50 caisses.']);
        $boxesMoved->levels()->create(['level' => 3, 'target' => 200, 'reward' => 1000, 'title' => 'Transporteur', 'description' => 'Déplacer 200 caisses.']);

        $waterDeaths = $game->achievements()->create(['game_id' => $game->id, 'key' => 'water_deaths', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $waterDeaths->levels()->create(['level' => 1, 'target' => 10, 'reward' => 100, 'title' => 'Parachutiste', 'description' => 'Tomber 10 fois dans l\'eau.']);
        $waterDeaths->levels()->create(['level' => 2, 'target' => 50, 'reward' => 500, 'title' => 'Base-jumper', 'description' => 'Tomber 50 fois dans l\'eau.']);
        $waterDeaths->levels()->create(['level' => 3, 'target' => 100, 'reward' => 1000, 'title' => 'Baumgartner', 'description' => 'Tomber 100 fois dans l\'eau.']);

        $levelReached = $game->achievements()->create(['game_id' => $game->id, 'key' => 'level_reached', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $levelReached->levels()->create(['level' => 1, 'target' => 10, 'reward' => 100, 'title' => 'Promeneur', 'description' => 'Atteindre le niveau 10.']);
        $levelReached->levels()->create(['level' => 2, 'target' => 20, 'reward' => 500, 'title' => 'Randonneur', 'description' => 'Atteindre le niveau 20.']);
        $levelReached->levels()->create(['level' => 3, 'target' => 30, 'reward' => 1000, 'title' => 'Explorateur', 'description' => 'Atteindre le niveau 30.']);

        $bonusBoxes = $game->achievements()->create(['game_id' => $game->id, 'key' => 'bonus_boxes', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $bonusBoxes->levels()->create(['level' => 1, 'target' => 3000, 'reward' => 250, 'title' => 'On encaisse', 'description' => 'Récupérer 3.000 points bonus de caisses en un seul niveau.']);

        $pushBoxOnGhost = $game->achievements()->create(['game_id' => $game->id, 'key' => 'push_box_on_ghost', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $pushBoxOnGhost->levels()->create(['level' => 1, 'target' => 1, 'reward' => 1000, 'title' => 'Prends ça !', 'description' => 'Pousser une caisse sur un fantôme.']);

        $ghostBuster = $game->achievements()->create(['game_id' => $game->id, 'key' => 'ghost_buster', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $ghostBuster->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'Ghost buster', 'description' => 'Foncer dans 3 fantômes dans un même niveau puis le réussir.']);
    }

    private function createChocoMoucheAchievements()
    {
        $game = $this->games->where('game_key', 'chocomouche')->first();
        if (!$game) {
            return;
        }

        $discoveredFives = $game->achievements()->create(['game_id' => $game->id, 'key' => 'discovered_fives', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $discoveredFives->levels()->create(['level' => 1, 'target' => 5, 'reward' => 100, 'title' => 'Terrain miné', 'description' => 'Découvrir 5 cases avec le chiffre 5.']);
        $discoveredFives->levels()->create(['level' => 2, 'target' => 25, 'reward' => 500, 'title' => 'Infestion de mouches', 'description' => 'Découvrir 25 cases avec le chiffre 5.']);
        $discoveredFives->levels()->create(['level' => 3, 'target' => 50, 'reward' => 1000, 'title' => 'Pentagramme drosophilien', 'description' => 'Découvrir 50 cases avec le chiffre 5.']);

        $totalDiscoveredCells = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_discovered_cells', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalDiscoveredCells->levels()->create(['level' => 1, 'target' => 500, 'reward' => 100, 'title' => 'Le chocolat, sans les mouches', 'description' => 'Découvrir 500 cases.']);
        $totalDiscoveredCells->levels()->create(['level' => 2, 'target' => 2000, 'reward' => 500, 'title' => 'Dévoreur cacaoté', 'description' => 'Découvrir 2.000 cases.']);
        $totalDiscoveredCells->levels()->create(['level' => 3, 'target' => 5000, 'reward' => 1000, 'title' => 'Indigestion de chocolat', 'description' => 'Découvrir 5.000 cases.']);

        $levelReached = $game->achievements()->create(['game_id' => $game->id, 'key' => 'level_reached', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $levelReached->levels()->create(['level' => 1, 'target' => 5, 'reward' => 100, 'title' => 'Pourquoi des mouches dans du chocolat ?', 'description' => 'Atteindre le niveau 5.']);
        $levelReached->levels()->create(['level' => 2, 'target' => 7, 'reward' => 500, 'title' => 'Vous avez dit des mouches ?', 'description' => 'Atteindre le niveau 7.']);
        $levelReached->levels()->create(['level' => 3, 'target' => 9, 'reward' => 1000, 'title' => 'Où ça des mouches ?', 'description' => 'Atteindre le niveau 9.']);

        $levelScore = $game->achievements()->create(['game_id' => $game->id, 'key' => 'level_score', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $levelScore->levels()->create(['level' => 1, 'target' => 45000, 'reward' => 100, 'title' => 'Démineur amateur', 'description' => 'Marquer 45.000 points sur un niveau.']);
        $levelScore->levels()->create(['level' => 2, 'target' => 50000, 'reward' => 500, 'title' => 'Démineur acharné', 'description' => 'Marquer 50.000 points sur un niveau.']);
        $levelScore->levels()->create(['level' => 3, 'target' => 55000, 'reward' => 1000, 'title' => 'Démineur professionnel', 'description' => 'Marquer 55.000 points sur un niveau.']);

        $fiveLevelsWithoutLifeLoss = $game->achievements()->create(['game_id' => $game->id, 'key' => 'five_levels_without_life_loss', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fiveLevelsWithoutLifeLoss->levels()->create(['level' => 1, 'target' => 5, 'reward' => 250, 'title' => 'Oh yeah!', 'description' => 'Finir 5 niveaux de suite sans perdre de vie.']);

        $sixAdjacentFlies = $game->achievements()->create(['game_id' => $game->id, 'key' => 'six_adjacent_flies', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sixAdjacentFlies->levels()->create(['level' => 1, 'target' => 1, 'reward' => 250, 'title' => 'Chanceux', 'description' => 'Découvrir une case avec 6 mouches à proximité.']);

        $threeFirstFlyLosses = $game->achievements()->create(['game_id' => $game->id, 'key' => 'three_first_fly_losses', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $threeFirstFlyLosses->levels()->create(['level' => 1, 'target' => 1, 'reward' => 1000, 'title' => 'Malchanceux', 'description' => 'Perdre 3 vies sur les 3 premières cases découvertes d\'une grille.']);

        $sevenClicksLevel = $game->achievements()->create(['game_id' => $game->id, 'key' => 'seven_clicks_level', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sevenClicksLevel->levels()->create(['level' => 1, 'target' => 1, 'reward' => 1000, 'title' => 'Vite fait bien fait', 'description' => 'Terminer un niveau avec maximum 7 cases cliquées.']);

        $fastLevelOne = $game->achievements()->create(['game_id' => $game->id, 'key' => 'fast_level_one', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fastLevelOne->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'J\'AI FAIM !', 'description' => 'Terminer le niveau 1 en moins de 15 secondes.']);
    }

    private function createCommonGameAchievements()
    {
        foreach ($this->games as $game) {

            $stars = $game->achievements()->create(['game_id' => $game->id, 'key' => 'stars', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
            $stars->levels()->create(['level' => 1, 'target' => 1, 'reward' => 0, 'title' => 'Étoile verte '.$game->name, 'description' => 'Obtenir l\'étoile verte sur '.$game->name.'.']);
            $stars->levels()->create(['level' => 2, 'target' => 2, 'reward' => 0, 'title' => 'Étoile orange '.$game->name, 'description' => 'Obtenir l\'étoile orange sur '.$game->name.'.']);
            $stars->levels()->create(['level' => 3, 'target' => 3, 'reward' => 0, 'title' => 'Étoile rouge '.$game->name, 'description' => 'Obtenir l\'étoile rouge sur '.$game->name.'.']);

            $paradiseLeague = $game->achievements()->create(['game_id' => $game->id, 'key' => 'paradise_league', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
            $paradiseLeague->levels()->create(['level' => 1, 'target' => 1, 'reward' => 0, 'title' => 'Ligue Paradis', 'description' => 'Atteindre la ligue Paradis à '.$game->name.'.']);
        }
    }

    private function createPopcornAchievements()
    {
        $game = $this->games->where('game_key', 'popcorn')->first();
        if (!$game) {
            return;
        }

        $totalBubleDestroyed = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_buble_destroyed', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalBubleDestroyed->levels()->create(['level' => 1, 'target' => 1500, 'reward' => 100, 'title' => 'Ventre vide', 'description' => 'Manger un total de 1.500 grains.']);
        $totalBubleDestroyed->levels()->create(['level' => 2, 'target' => 7500, 'reward' => 500, 'title' => 'Petit creux', 'description' => 'Manger un total de 7.500 grains.']);
        $totalBubleDestroyed->levels()->create(['level' => 3, 'target' => 20000, 'reward' => 1000, 'title' => 'Rassasié', 'description' => 'Manger un total de 20.000 grains.']);

        $totalDamageDealt = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_damage_dealt', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalDamageDealt->levels()->create(['level' => 1, 'target' => 50, 'reward' => 100, 'title' => 'Recrue', 'description' => 'Enlever 50 vies au boss Pokepi.']);
        $totalDamageDealt->levels()->create(['level' => 2, 'target' => 300, 'reward' => 500, 'title' => 'Combattant', 'description' => 'Enlever 300 vies au boss Pokepi.']);
        $totalDamageDealt->levels()->create(['level' => 3, 'target' => 700, 'reward' => 1000, 'title' => 'Assassin', 'description' => 'Enlever 700 vies au boss Pokepi.']);

        $totalKilledTimes = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_killed_times', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalKilledTimes->levels()->create(['level' => 1, 'target' => 1, 'reward' => 100, 'title' => 'Maman, j\'ai réussi', 'description' => 'Tuer Pokepi 1 fois.']);
        $totalKilledTimes->levels()->create(['level' => 2, 'target' => 25, 'reward' => 500, 'title' => 'Pokedead', 'description' => 'Tuer Pokepi 25 fois.']);
        $totalKilledTimes->levels()->create(['level' => 3, 'target' => 75, 'reward' => 1000, 'title' => 'Pioukepi', 'description' => 'Tuer Pokepi 75 fois.']);

        $bubleDestroyedInARow = $game->achievements()->create(['game_id' => $game->id, 'key' => 'buble_destroyed_in_a_row', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $bubleDestroyedInARow->levels()->create(['level' => 1, 'target' => 30, 'reward' => 100, 'title' => 'Gourmet', 'description' => 'Manger 30 grains à suivre sans toucher le sol.']);
        $bubleDestroyedInARow->levels()->create(['level' => 2, 'target' => 50, 'reward' => 500, 'title' => 'Gourmand', 'description' => 'Manger 50 grains à suivre sans toucher le sol.']);
        $bubleDestroyedInARow->levels()->create(['level' => 3, 'target' => 70, 'reward' => 1000, 'title' => 'Glouton', 'description' => 'Manger 70 grains à suivre sans toucher le sol.']);

        $combo500Pts = $game->achievements()->create(['game_id' => $game->id, 'key' => 'combo_500_pts', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $combo500Pts->levels()->create(['level' => 1, 'target' => 500, 'reward' => 250, 'title' => 'Sniper', 'description' => 'Atteindre un combo de 500 points.']);

        $threeTimesOutbounds = $game->achievements()->create(['game_id' => $game->id, 'key' => 'three_times_outbounds', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $threeTimesOutbounds->levels()->create(['level' => 1, 'target' => 3, 'reward' => 1000, 'title' => 'T\'es sûr qu\'il y a rien là haut ?', 'description' => 'Passer tout en haut du monde 3 fois dans une même partie.']);

        $fastkillPokepi = $game->achievements()->create(['game_id' => $game->id, 'key' => 'fastkill_pokepi', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fastkillPokepi->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'Ça, c\'est fait.', 'description' => 'Tuer Pokepi en moins de 1 minute.']);

        $perfectKill = $game->achievements()->create(['game_id' => $game->id, 'key' => 'perfect_kill', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $perfectKill->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'Vivacité', 'description' => 'Tuer Pokepi sans qu\'aucun grain n\'ait éclaté au sol.']);
    }

    private function createInterwheelAchievements()
    {
        $game = $this->games->where('game_key', 'interwheel')->first();
        if (!$game) {
            return;
        }

        $totalElevation = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_elevation', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalElevation->levels()->create(['level' => 1, 'target' => 25000, 'reward' => 100, 'title' => 'Apprenti grimpeur', 'description' => 'Monter d\'une hauteur cumulée de 25.000 mètres.']);
        $totalElevation->levels()->create(['level' => 2, 'target' => 150000, 'reward' => 500, 'title' => 'Grimpeur expérimenté', 'description' => 'Monter d\'une hauteur cumulée de 150.000 mètres.']);
        $totalElevation->levels()->create(['level' => 3, 'target' => 1000000, 'reward' => 1000, 'title' => 'Grimpeur légendaire', 'description' => 'Monter d\'une hauteur cumulée de 1.000.000 mètres.']);

        $totalJumps = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_jumps', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalJumps->levels()->create(['level' => 1, 'target' => 2500, 'reward' => 100, 'title' => 'Enjoué', 'description' => 'Effectuer un total cumulé de 2.500 sauts.']);
        $totalJumps->levels()->create(['level' => 2, 'target' => 10000, 'reward' => 500, 'title' => 'Hyperactif', 'description' => 'Effectuer un total cumulé de 10.000 sauts.']);
        $totalJumps->levels()->create(['level' => 3, 'target' => 25000, 'reward' => 1000, 'title' => 'Infatigable', 'description' => 'Effectuer un total cumulé de 25.000 sauts.']);

        $totalDives = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_dives', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalDives->levels()->create(['level' => 1, 'target' => 5, 'reward' => 100, 'title' => 'Baptème de plongée', 'description' => 'Plonger un total cumulé de 5 fois dans l\'eau.']);
        $totalDives->levels()->create(['level' => 2, 'target' => 100, 'reward' => 500, 'title' => 'N\'oublie pas les bouteilles', 'description' => 'Plonger un total cumulé de 100 fois dans l\'eau.']);
        $totalDives->levels()->create(['level' => 3, 'target' => 500, 'reward' => 1000, 'title' => 'Sous-marin', 'description' => 'Plonger un total cumulé de 500 fois dans l\'eau.']);

        $elevation = $game->achievements()->create(['game_id' => $game->id, 'key' => 'elevation', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $elevation->levels()->create(['level' => 1, 'target' => 2500, 'reward' => 100, 'title' => 'Mont-Blanc', 'description' => 'Monter d\'une hauteur de 2.500 mètres en une seule ascension.']);
        $elevation->levels()->create(['level' => 2, 'target' => 3500, 'reward' => 500, 'title' => 'Kilimanjaro', 'description' => 'Monter d\'une hauteur de 3.500 mètres en une seule ascension.']);
        $elevation->levels()->create(['level' => 3, 'target' => 4500, 'reward' => 1000, 'title' => 'Everest', 'description' => 'Monter d\'une hauteur de 4.500 mètres en une seule ascension.']);

        $totalPastilles = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_pastilles', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalPastilles->levels()->create(['level' => 1, 'target' => 750, 'reward' => 100, 'title' => 'Amateur', 'description' => 'Collecter un total cumulé de 750 pastilles.']);
        $totalPastilles->levels()->create(['level' => 2, 'target' => 5000, 'reward' => 500, 'title' => 'Collectionneur', 'description' => 'Collecter un total cumulé de 5.000 pastilles.']);
        $totalPastilles->levels()->create(['level' => 3, 'target' => 15000, 'reward' => 1000, 'title' => 'Aspirateur', 'description' => 'Collecter un total cumulé de 15.000 pastilles.']);

        $totalDodgedEnemies = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_dodged_enemies', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalDodgedEnemies->levels()->create(['level' => 1, 'target' => 100, 'reward' => 100, 'title' => 'Amis ?', 'description' => 'Esquiver un total cumulé de 100 mines.']);
        $totalDodgedEnemies->levels()->create(['level' => 2, 'target' => 1000, 'reward' => 500, 'title' => 'Ennemis...', 'description' => 'Esquiver un total cumulé de 1.000 mines.']);
        $totalDodgedEnemies->levels()->create(['level' => 3, 'target' => 5000, 'reward' => 1000, 'title' => 'Innofensifs !', 'description' => 'Esquiver un total cumulé de 5.000 mines.']);

        $waterScore = $game->achievements()->create(['game_id' => $game->id, 'key' => 'water_score', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $waterScore->levels()->create(['level' => 1, 'target' => 1000, 'reward' => 250, 'title' => 'Tout propre !', 'description' => 'Passer dans l\'eau puis récupérer au moins 1.000 points.']);

        $maxFallHeight = $game->achievements()->create(['game_id' => $game->id, 'key' => 'max_fall_height', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $maxFallHeight->levels()->create(['level' => 1, 'target' => 500, 'reward' => 1000, 'title' => 'Chute libre', 'description' => 'Faire une chute ininterrompue de 500 mètres.']);

        $fiveMineWheel = $game->achievements()->create(['game_id' => $game->id, 'key' => 'five_mine_wheel', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fiveMineWheel->levels()->create(['level' => 1, 'target' => 5, 'reward' => 1000, 'title' => 'Salut la compagnie !', 'description' => 'Atterrir sur une roue avec 5 mines et survivre.']);

        $bottomWheelElevation = $game->achievements()->create(['game_id' => $game->id, 'key' => 'bottom_wheel_elevation', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $bottomWheelElevation->levels()->create(['level' => 1, 'target' => 3500, 'reward' => 2000, 'title' => 'Challenge accepted', 'description' => 'Toucher la roue du bas puis monter à plus de 3.500 mètres.']);
    }

    private function createIronChouquetteAchievements()
    {
        $game = $this->games->where('game_key', 'ironchouquette')->first();
        if (!$game) {
            return;
        }

        $killShield = $game->achievements()->create(['game_id' => $game->id, 'key' => 'kill_shield', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killShield->levels()->create(['level' => 1, 'target' => 1, 'reward' => 250, 'title' => 'Tous tes bonus ne m\'atteignent pas', 'description' => 'Détruire un champ magnétique.']);

        $killBlocks = $game->achievements()->create(['game_id' => $game->id, 'key' => 'kill_total_blocks', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killBlocks->levels()->create(['level' => 1, 'target' => 10, 'reward' => 100, 'title' => 'Chatouilleur', 'description' => 'Détruire 10 Blocks cumulés.']);
        $killBlocks->levels()->create(['level' => 2, 'target' => 100, 'reward' => 500, 'title' => 'Killer', 'description' => 'Détruire 100 Blocks cumulés.']);
        $killBlocks->levels()->create(['level' => 3, 'target' => 500, 'reward' => 1000, 'title' => 'Destroyer', 'description' => 'Détruire 500 Blocks cumulés.']);

        $killStorms = $game->achievements()->create(['game_id' => $game->id, 'key' => 'kill_storms', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killStorms->levels()->create(['level' => 1, 'target' => 5, 'reward' => 100, 'title' => 'Rookie', 'description' => 'Détruire 5 Storms en une seule partie.']);
        $killStorms->levels()->create(['level' => 2, 'target' => 10, 'reward' => 500, 'title' => 'Pilote', 'description' => 'Détruire 10 Storms en une seule partie.']);
        $killStorms->levels()->create(['level' => 3, 'target' => 15, 'reward' => 1000, 'title' => 'Élite', 'description' => 'Détruire 15 Storms en une seule partie.']);

        $sacrifices = $game->achievements()->create(['game_id' => $game->id, 'key' => 'sacrifices', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sacrifices->levels()->create(['level' => 1, 'target' => 2, 'reward' => 100, 'title' => 'Question de survie', 'description' => 'Sacrifier 2 bonus en une seule partie.']);
        $sacrifices->levels()->create(['level' => 2, 'target' => 4, 'reward' => 500, 'title' => 'Question de maladresse', 'description' => 'Sacrifier 4 bonus en une seule partie.']);
        $sacrifices->levels()->create(['level' => 3, 'target' => 6, 'reward' => 1000, 'title' => 'Question de principes', 'description' => 'Sacrifier 6 bonus en une seule partie.']);

        $fiveEmptySlots = $game->achievements()->create(['game_id' => $game->id, 'key' => 'five_empty_slots', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fiveEmptySlots->levels()->create(['level' => 1, 'target' => 5, 'reward' => 1000, 'title' => 'Chargeurs vides', 'description' => 'Avoir 5 emplacements de bonus mais aucun bonus.']);

        $sameBonus = $game->achievements()->create(['game_id' => $game->id, 'key' => 'same_bonus', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sameBonus->levels()->create(['level' => 1, 'target' => 3, 'reward' => 2000, 'title' => 'Pourvu que ça soit pas du rose...', 'description' => 'Avoir 3 bonus de la même couleur en même temps.']);

        $sixBonuses = $game->achievements()->create(['game_id' => $game->id, 'key' => 'six_bonuses', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sixBonuses->levels()->create(['level' => 1, 'target' => 6, 'reward' => 2000, 'title' => 'Rainbow Color x15 !', 'description' => 'Avoir 6 bonus différents dans une partie.']);

        $surgromphsKilled = $game->achievements()->create(['game_id' => $game->id, 'key' => 'surgromphs_killed', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $surgromphsKilled->levels()->create(['level' => 1, 'target' => 1, 'reward' => 100, 'title' => 'Un Surgromph de moins', 'description' => 'Détruire 1 Surgromph en une seule partie.']);
        $surgromphsKilled->levels()->create(['level' => 2, 'target' => 3, 'reward' => 500, 'title' => 'Surgromph killer', 'description' => 'Détruire 3 Surgromphs en une seule partie.']);
        $surgromphsKilled->levels()->create(['level' => 3, 'target' => 5, 'reward' => 1000, 'title' => 'Les Surgromphs s\'écartent de mon chemin!', 'description' => 'Détruire 5 Surgromphs en une seule partie.']);

        $cuttyClosedKilled = $game->achievements()->create(['game_id' => $game->id, 'key' => 'cutty_closed_killed', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $cuttyClosedKilled->levels()->create(['level' => 1, 'target' => 1, 'reward' => 100, 'title' => 'Cutty vite parti', 'description' => 'Détruire 1 Cutty avant qu\'il ne s\'ouvre en une seule partie.']);
        $cuttyClosedKilled->levels()->create(['level' => 2, 'target' => 3, 'reward' => 500, 'title' => 'Cutty cutter', 'description' => 'Détruire 3 Cuttys avant qu\'ils ne s\'ouvrent en une seule partie.']);
        $cuttyClosedKilled->levels()->create(['level' => 3, 'target' => 10, 'reward' => 1000, 'title' => 'Un Cutty? Kézako?', 'description' => 'Détruire 10 Cuttys avant qu\'ils ne s\'ouvrent en une seule partie.']);

        $pinkBonusKills = $game->achievements()->create(['game_id' => $game->id, 'key' => 'pink_bonus_kills', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $pinkBonusKills->levels()->create(['level' => 1, 'target' => 20, 'reward' => 1000, 'title' => 'C\'est pas si mal finalement', 'description' => 'Détruire 20 ennemis avec le bonus rose dans une seule partie.']);

        $blackHoleProjectiles = $game->achievements()->create(['game_id' => $game->id, 'key' => 'black_hole_projectiles', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $blackHoleProjectiles->levels()->create(['level' => 1, 'target' => 100, 'reward' => 1000, 'title' => 'Ménage de printemps', 'description' => 'Aspirer 100 projectiles avec un seul trou noir.']);

        $lapinvinciblesWave = $game->achievements()->create(['game_id' => $game->id, 'key' => 'lapinvincibles_wave', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $lapinvinciblesWave->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'Ça existe ??', 'description' => 'Passer la vague des lapinvincibles.']);

        $maxEnemyShots = $game->achievements()->create(['game_id' => $game->id, 'key' => 'max_enemy_shots', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $maxEnemyShots->levels()->create(['level' => 1, 'target' => 100, 'reward' => 2000, 'title' => 'J\'y vois plus rien!', 'description' => 'Avoir au moins 100 projectiles ennemis à l\'écran.']);
    }

    private function createPiouPiouAchievements()
    {
        $game = $this->games->where('game_key', 'pioupiou')->first();
        if (!$game) {
            return;
        }

        $totalBubbles = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_bubbles', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalBubbles->levels()->create(['level' => 1, 'target' => 1000, 'reward' => 100, 'title' => 'Bulleur', 'description' => 'Récupérer un total cumulé de 1.000 bulles.']);
        $totalBubbles->levels()->create(['level' => 2, 'target' => 10000, 'reward' => 500, 'title' => 'Bulle popper', 'description' => 'Récupérer un total cumulé de 10.000 bulles.']);
        $totalBubbles->levels()->create(['level' => 3, 'target' => 25000, 'reward' => 1000, 'title' => 'Bulle doseur', 'description' => 'Récupérer un total cumulé de 25.000 bulles.']);

        $totalElevation = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_elevation', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalElevation->levels()->create(['level' => 1, 'target' => 500, 'reward' => 100, 'title' => 'Tropopiou', 'description' => 'Grimper un total cumulé de 500m.']);
        $totalElevation->levels()->create(['level' => 2, 'target' => 3000, 'reward' => 500, 'title' => 'Stratopiou', 'description' => 'Grimper un total cumulé de 3.000m.']);
        $totalElevation->levels()->create(['level' => 3, 'target' => 10000, 'reward' => 1000, 'title' => 'Exopiou', 'description' => 'Grimper un total cumulé de 10.000m.']);

        $elevation = $game->achievements()->create(['game_id' => $game->id, 'key' => 'elevation', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $elevation->levels()->create(['level' => 1, 'target' => 30, 'reward' => 100, 'title' => 'Combo ascendant', 'description' => 'Atteindre 30m en une partie.']);
        $elevation->levels()->create(['level' => 2, 'target' => 50, 'reward' => 500, 'title' => 'Sky Piouker', 'description' => 'Atteindre 50m en une partie.']);
        $elevation->levels()->create(['level' => 3, 'target' => 70, 'reward' => 1000, 'title' => 'Piou Infinity', 'description' => 'Atteindre 70m en une partie.']);

        $noBubble = $game->achievements()->create(['game_id' => $game->id, 'key' => 'no_bubble', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $noBubble->levels()->create(['level' => 1, 'target' => 15, 'reward' => 100, 'title' => 'Pas d\'bul', 'description' => 'Atteindre 15m sans récolter de points.']);
        $noBubble->levels()->create(['level' => 2, 'target' => 30, 'reward' => 500, 'title' => 'L\'esquiveur', 'description' => 'Atteindre 30m sans récolter de points.']);
        $noBubble->levels()->create(['level' => 3, 'target' => 40, 'reward' => 1000, 'title' => 'L\'invisible', 'description' => 'Atteindre 40m sans récolter de points.']);

        $fallingBubbles = $game->achievements()->create(['game_id' => $game->id, 'key' => 'falling_bubbles', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fallingBubbles->levels()->create(['level' => 1, 'target' => 30, 'reward' => 250, 'title' => 'Réceptionneur', 'description' => 'Récupérer 30 bonus avant qu\'ils ne touchent le sol dans une partie.']);

        $pinkBubblePopped = $game->achievements()->create(['game_id' => $game->id, 'key' => 'pink_bubble_popped', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $pinkBubblePopped->levels()->create(['level' => 1, 'target' => 1, 'reward' => 1000, 'title' => 'Je n\'ai rien pu faire', 'description' => 'Laisser une bulle rose se faire écraser.']);

        $climbHeight = $game->achievements()->create(['game_id' => $game->id, 'key' => 'climb_height', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $climbHeight->levels()->create(['level' => 1, 'target' => 5, 'reward' => 2000, 'title' => 'Déblocage vertical', 'description' => 'Monter de 5 cases d\'un coup.']);
    }

    private function createF1ChampionAchievements()
    {
        $game = $this->games->where('game_key', 'f1champion')->first();
        if (!$game) {
            return;
        }

        $totalKm = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_km', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalKm->levels()->create(['level' => 1, 'target' => 2000, 'reward' => 100, 'title' => 'Rodage', 'description' => 'Parcourir un total cumulé de 2.000 km.']);
        $totalKm->levels()->create(['level' => 2, 'target' => 5000, 'reward' => 500, 'title' => 'Vidange', 'description' => 'Parcourir un total cumulé de 5.000 km.']);
        $totalKm->levels()->create(['level' => 3, 'target' => 10000, 'reward' => 1000, 'title' => 'Visite technique', 'description' => 'Parcourir un total cumulé de 10.000 km.']);

        $rideOnOil = $game->achievements()->create(['game_id' => $game->id, 'key' => 'ride_on_oil', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $rideOnOil->levels()->create(['level' => 1, 'target' => 5, 'reward' => 100, 'title' => 'J\'ai glissé chef', 'description' => 'Rouler sur 5 flaques d\'huile en une partie.']);
        $rideOnOil->levels()->create(['level' => 2, 'target' => 8, 'reward' => 500, 'title' => 'Sport de glisse', 'description' => 'Rouler sur 8 flaques d\'huile en une partie.']);
        $rideOnOil->levels()->create(['level' => 3, 'target' => 15, 'reward' => 1000, 'title' => 'Passion pour le drift', 'description' => 'Rouler sur 15 flaques d\'huile en une partie.']);

        $rideOnHeal = $game->achievements()->create(['game_id' => $game->id, 'key' => 'ride_on_heal', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $rideOnHeal->levels()->create(['level' => 1, 'target' => 2, 'reward' => 100, 'title' => 'Assuré', 'description' => 'Récupérer 2 bonus de réparation en une partie.']);
        $rideOnHeal->levels()->create(['level' => 2, 'target' => 5, 'reward' => 500, 'title' => 'Indemnisé', 'description' => 'Récupérer 5 bonus de réparation en une partie.']);
        $rideOnHeal->levels()->create(['level' => 3, 'target' => 8, 'reward' => 1000, 'title' => 'Malussé', 'description' => 'Récupérer 8 bonus de réparation en une partie.']);

        $riskTaker = $game->achievements()->create(['game_id' => $game->id, 'key' => 'risk_taker', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $riskTaker->levels()->create(['level' => 1, 'target' => 5, 'reward' => 250, 'title' => 'Chauffard', 'description' => 'Sortir 5 fois de la piste sans mourir dans une partie.']);

        $pilot = $game->achievements()->create(['game_id' => $game->id, 'key' => 'pilot', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $pilot->levels()->create(['level' => 1, 'target' => 10, 'reward' => 1000, 'title' => 'Pilote', 'description' => 'Parcourir 10 km sans une égratignure.']);

        $autobhan = $game->achievements()->create(['game_id' => $game->id, 'key' => 'autobhan', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $autobhan->levels()->create(['level' => 1, 'target' => 20, 'reward' => 2000, 'title' => 'Autobahn', 'description' => 'Rouler à plus de 230 km/h pendant au moins 20 secondes d’affilée sans sortir de la piste.']);

        $secondLife = $game->achievements()->create(['game_id' => $game->id, 'key' => 'second_life', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $secondLife->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'Second life', 'description' => 'Descendre à moins de 5 % de vie puis remonter au maximum.']);
    }

    private function createZipZapAchievements()
    {
        $game = $this->games->where('game_key', 'zipzap')->first();
        if (!$game) {
            return;
        }

        $totalPops = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_pops', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalPops->levels()->create(['level' => 1, 'target' => 1000, 'reward' => 100, 'title' => 'Eclate ballons', 'description' => 'Eclater un total cumulé de 1.000 ballons.']);
        $totalPops->levels()->create(['level' => 2, 'target' => 7500, 'reward' => 500, 'title' => 'Anti-hélium', 'description' => 'Eclater un total cumulé de 7.500 ballons.']);
        $totalPops->levels()->create(['level' => 3, 'target' => 25000, 'reward' => 1000, 'title' => 'Terreur des baudruches', 'description' => 'Eclater un total cumulé de 25.000 ballons.']);

        $miniScore = $game->achievements()->create(['game_id' => $game->id, 'key' => 'mini_score', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $miniScore->levels()->create(['level' => 1, 'target' => 100, 'reward' => 1000, 'title' => '10.000 tout rond !', 'description' => 'Finir une partie avec 0 combos.']);

        $blackBalloonsPopped = $game->achievements()->create(['game_id' => $game->id, 'key' => 'black_balloons_popped', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $blackBalloonsPopped->levels()->create(['level' => 1, 'target' => 1, 'reward' => 100, 'title' => 'Adorateur de la mort', 'description' => 'Éclater 1 ballon noir.']);
        $blackBalloonsPopped->levels()->create(['level' => 2, 'target' => 10, 'reward' => 500, 'title' => 'Bonjour ténèbres', 'description' => 'Éclater 10 ballons noirs.']);
        $blackBalloonsPopped->levels()->create(['level' => 3, 'target' => 25, 'reward' => 1000, 'title' => 'Noir c\'est noir', 'description' => 'Éclater 25 ballons noirs.']);

        $fastFinish = $game->achievements()->create(['game_id' => $game->id, 'key' => 'fast_finish', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fastFinish->levels()->create(['level' => 1, 'target' => 1, 'reward' => 1000, 'title' => 'J\'ai pas compris le jeu', 'description' => 'Finir une partie en moins de 23 coups.']);

        $emptyShots = $game->achievements()->create(['game_id' => $game->id, 'key' => 'empty_shots', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $emptyShots->levels()->create(['level' => 1, 'target' => 10, 'reward' => 100, 'title' => 'Il faut viser les ballons ?', 'description' => 'Faire 10 coups dans le vide.']);
        $emptyShots->levels()->create(['level' => 2, 'target' => 100, 'reward' => 500, 'title' => 'Oups j\'ai glissé', 'description' => 'Faire 100 coups dans le vide.']);
        $emptyShots->levels()->create(['level' => 3, 'target' => 1000, 'reward' => 1000, 'title' => 'Rahhh, mais pourquoi ça bouge aussi !', 'description' => 'Faire 1.000 coups dans le vide.']);

        $fiveThousandCombo = $game->achievements()->create(['game_id' => $game->id, 'key' => 'five_thousand_combo', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fiveThousandCombo->levels()->create(['level' => 1, 'target' => 1, 'reward' => 100, 'title' => 'Combo !', 'description' => 'Obtenir 1 ballon à 5.000 points en un coup.']);
        $fiveThousandCombo->levels()->create(['level' => 2, 'target' => 2, 'reward' => 500, 'title' => 'Le doublet !', 'description' => 'Obtenir 2 ballons à 5.000 points en un coup.']);
        $fiveThousandCombo->levels()->create(['level' => 3, 'target' => 3, 'reward' => 1000, 'title' => 'Brochette de points', 'description' => 'Obtenir 3 ballons à 5.000 points en un coup.']);

        $riskLover = $game->achievements()->create(['game_id' => $game->id, 'key' => 'risk_lover', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $riskLover->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'J\'aime le risque', 'description' => 'Finir une partie sans mourir alors qu\'il y a au moins 3 ballons noirs lorsqu\'il reste au minimum 50 ballons à éclater.']);
    }

    private function createStarfangAchievements()
    {
        $game = $this->games->where('game_key', 'starfang')->first();
        if (!$game) {
            return;
        }

        $totalLevelsFinished = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_levels_finished', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalLevelsFinished->levels()->create(['level' => 1, 'target' => 50, 'reward' => 100, 'title' => 'Voyons ce qu\'il y a par là', 'description' => 'Terminer 50 niveaux.']);
        $totalLevelsFinished->levels()->create(['level' => 2, 'target' => 500, 'reward' => 500, 'title' => 'Explorateur spatial', 'description' => 'Terminer 500 niveaux.']);
        $totalLevelsFinished->levels()->create(['level' => 3, 'target' => 1500, 'reward' => 1000, 'title' => 'Vers l\'infini et au-delà', 'description' => 'Terminer 1.500 niveaux.']);

        $totalPurpleAsteroidsDestroyed = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_purple_asteroids_destroyed', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalPurpleAsteroidsDestroyed->levels()->create(['level' => 1, 'target' => 10, 'reward' => 100, 'title' => 'Apprenti du mauve', 'description' => 'Détruire 10 astéroïdes violets.']);
        $totalPurpleAsteroidsDestroyed->levels()->create(['level' => 2, 'target' => 75, 'reward' => 500, 'title' => 'Expert de l\'ultra violet', 'description' => 'Détruire 75 astéroïdes violets.']);
        $totalPurpleAsteroidsDestroyed->levels()->create(['level' => 3, 'target' => 250, 'reward' => 1000, 'title' => 'Maître de l\'octarine', 'description' => 'Détruire 250 astéroïdes violets.']);

        $noMainWeaponLevels = $game->achievements()->create(['game_id' => $game->id, 'key' => 'no_main_weapon_levels', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $noMainWeaponLevels->levels()->create(['level' => 1, 'target' => 1, 'reward' => 100, 'title' => 'À une main', 'description' => 'Terminer 1 niveau sans tirer avec l\'arme principale dans une seule partie.']);
        $noMainWeaponLevels->levels()->create(['level' => 2, 'target' => 3, 'reward' => 500, 'title' => 'À un doigt', 'description' => 'Terminer 3 niveaux sans tirer avec l\'arme principale dans une seule partie.']);
        $noMainWeaponLevels->levels()->create(['level' => 3, 'target' => 5, 'reward' => 1000, 'title' => 'Sans les mains', 'description' => 'Terminer 5 niveaux sans tirer avec l\'arme principale dans une seule partie.']);

        $fastLevel = $game->achievements()->create(['game_id' => $game->id, 'key' => 'fast_level', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fastLevel->levels()->create(['level' => 1, 'target' => 1, 'reward' => 100, 'title' => 'Rapide l\'ami', 'description' => 'Finir un niveau en moins de 35 secondes après le niveau 6.']);
        $fastLevel->levels()->create(['level' => 2, 'target' => 2, 'reward' => 500, 'title' => 'Vitesse supersonique', 'description' => 'Finir un niveau en moins de 25 secondes après le niveau 6.']);
        $fastLevel->levels()->create(['level' => 3, 'target' => 3, 'reward' => 1000, 'title' => 'Célérité supraluminique', 'description' => 'Finir un niveau en moins de 15 secondes après le niveau 6.']);

        $laserOverkill = $game->achievements()->create(['game_id' => $game->id, 'key' => 'laser_overkill', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $laserOverkill->levels()->create(['level' => 1, 'target' => 1, 'reward' => 250, 'title' => 'Overkill', 'description' => 'Détruire un astéroïde en terre avec un laser.']);

        $allWeaponUpgrades = $game->achievements()->create(['game_id' => $game->id, 'key' => 'all_weapon_upgrades', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $allWeaponUpgrades->levels()->create(['level' => 1, 'target' => 1, 'reward' => 1000, 'title' => 'Indécis', 'description' => 'Obtenir une amélioration d\'arme de chaque type dans une seule partie.']);

        $sameWeaponUpgrades = $game->achievements()->create(['game_id' => $game->id, 'key' => 'same_weapon_upgrades', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sameWeaponUpgrades->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'Puissant', 'description' => 'Obtenir 5 améliorations d\'armes identiques dans une seule partie.']);
    }

    private function createKaskade2Achievements()
    {
        $game = $this->games->where('game_key', 'kaskade2')->first();
        if (!$game) {
            return;
        }

        $totalBlocks = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_blocks', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalBlocks->levels()->create(['level' => 1, 'target' => 3000, 'reward' => 100, 'title' => 'Cliqueur', 'description' => 'Détruire un total cumulé de 3.000 blocs.']);
        $totalBlocks->levels()->create(['level' => 2, 'target' => 30000, 'reward' => 500, 'title' => 'Cogneur', 'description' => 'Détruire un total cumulé de 30.000 blocs.']);
        $totalBlocks->levels()->create(['level' => 3, 'target' => 250000, 'reward' => 1000, 'title' => 'Kasseur', 'description' => 'Détruire un total cumulé de 250.000 blocs.']);

        $miniScore = $game->achievements()->create(['game_id' => $game->id, 'key' => 'mini_score', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $miniScore->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'Premier ! De la fin...', 'description' => 'Faire un score de 2.000.']);

        $destroyFiftyBlocks = $game->achievements()->create(['game_id' => $game->id, 'key' => 'destroy_fifty_blocks', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $destroyFiftyBlocks->levels()->create(['level' => 1, 'target' => 50, 'reward' => 250, 'title' => 'Boom !', 'description' => 'Détruire 50 blocs en un seul coup.']);

        $sameColorClicks = $game->achievements()->create(['game_id' => $game->id, 'key' => 'same_color_clicks', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sameColorClicks->levels()->create(['level' => 1, 'target' => 8, 'reward' => 100, 'title' => 'C\'est une stratégie', 'description' => 'Cliquer 8 fois de suite sur la même couleur.']);
        $sameColorClicks->levels()->create(['level' => 2, 'target' => 10, 'reward' => 500, 'title' => 'C\'est une erreur', 'description' => 'Cliquer 10 fois de suite sur la même couleur.']);
        $sameColorClicks->levels()->create(['level' => 3, 'target' => 12, 'reward' => 1000, 'title' => 'C\'est un têtu', 'description' => 'Cliquer 12 fois de suite sur la même couleur.']);

        $sameCellClicks = $game->achievements()->create(['game_id' => $game->id, 'key' => 'same_cell_clicks', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sameCellClicks->levels()->create(['level' => 1, 'target' => 1, 'reward' => 250, 'title' => 'Il existe d\'autres cases', 'description' => 'Cliquer trois fois de suite sur la même case.']);

        $rgb = $game->achievements()->create(['game_id' => $game->id, 'key' => 'rgb', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $rgb->levels()->create(['level' => 1, 'target' => 1, 'reward' => 1000, 'title' => 'RGB', 'description' => 'Atteindre un score de 160.000 en alternant toujours Rouge, Vert, Bleu, Rouge, Vert, Bleu...']);

        $bicolor = $game->achievements()->create(['game_id' => $game->id, 'key' => 'bicolor', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $bicolor->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'Bicolor', 'description' => 'Atteindre un score de 200.000 en utilisant seulement 2 couleurs.']);
    }

    private function createOpalus2Achievements()
    {
        $game = $this->games->where('game_key', 'opalus2')->first();
        if (!$game) {
            return;
        }

        $miniScore = $game->achievements()->create(['game_id' => $game->id, 'key' => 'mini_score', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $miniScore->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'Minimaliste', 'description' => 'Faire un score de 6.750.']);

        $totalFallenBubbles = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_fallen_bubbles', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalFallenBubbles->levels()->create(['level' => 1, 'target' => 100, 'reward' => 100, 'title' => 'Dégringolade', 'description' => 'Faire tomber un total cumulé de 100 billes.']);
        $totalFallenBubbles->levels()->create(['level' => 2, 'target' => 1000, 'reward' => 500, 'title' => 'Effondrement', 'description' => 'Faire tomber un total cumulé de 1.000 billes.']);
        $totalFallenBubbles->levels()->create(['level' => 3, 'target' => 10000, 'reward' => 1000, 'title' => 'Avalanche', 'description' => 'Faire tomber un total cumulé de 10.000 billes.']);

        $destroyedBubbles = $game->achievements()->create(['game_id' => $game->id, 'key' => 'destroyed_bubbles', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $destroyedBubbles->levels()->create(['level' => 1, 'target' => 1000, 'reward' => 100, 'title' => 'Eclateur de billes', 'description' => 'Détruire un total cumulé de 1.000 billes.']);
        $destroyedBubbles->levels()->create(['level' => 2, 'target' => 10000, 'reward' => 500, 'title' => 'Destructeur de balles', 'description' => 'Détruire un total cumulé de 10.000 billes.']);
        $destroyedBubbles->levels()->create(['level' => 3, 'target' => 25000, 'reward' => 1000, 'title' => 'Anihilateur d\'exosphères', 'description' => 'Détruire un total cumulé de 25.000 billes.']);

        $sameColorDestroyedBubbles = $game->achievements()->create(['game_id' => $game->id, 'key' => 'same_color_destroyed_bubbles', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $sameColorDestroyedBubbles->levels()->create(['level' => 1, 'target' => 15, 'reward' => 100, 'title' => 'Éclatement', 'description' => 'Détruire 15 billes d\'une couleur en un seul coup.']);
        $sameColorDestroyedBubbles->levels()->create(['level' => 2, 'target' => 21, 'reward' => 500, 'title' => 'Massacre', 'description' => 'Détruire 21 billes d\'une couleur en un seul coup.']);
        $sameColorDestroyedBubbles->levels()->create(['level' => 3, 'target' => 27, 'reward' => 1000, 'title' => 'Strike monochrome', 'description' => 'Détruire 27 billes d\'une couleur en un seul coup.']);

        $noFallenBubbles = $game->achievements()->create(['game_id' => $game->id, 'key' => 'no_fallen_bubbles', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $noFallenBubbles->levels()->create(['level' => 1, 'target' => 1, 'reward' => 250, 'title' => 'Solide sur les appuis', 'description' => 'Finir une partie sans une seule bille tombée.']);

        $tenFallenBubbles = $game->achievements()->create(['game_id' => $game->id, 'key' => 'fallen_bubbles', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $tenFallenBubbles->levels()->create(['level' => 1, 'target' => 15, 'reward' => 1000, 'title' => 'Chute dans le peloton', 'description' => 'Faire tomber 15 billes d\'un coup.']);

        $magellan = $game->achievements()->create(['game_id' => $game->id, 'key' => 'magellan', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $magellan->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'Magellan', 'description' => 'Atteindre les 4 bords du plateau dans une seule partie.']);

        $colorBlindness = $game->achievements()->create(['game_id' => $game->id, 'key' => 'color_blindness', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $colorBlindness->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'Daltonisme', 'description' => 'Finir une partie en ne cliquant que sur des billes de 2 couleurs différentes.']);

        $rainbow = $game->achievements()->create(['game_id' => $game->id, 'key' => 'rainbow', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $rainbow->levels()->create(['level' => 1, 'target' => 7, 'reward' => 2000, 'title' => 'Arc-en-ciel', 'description' => 'Faire tomber une bille de chaque couleur en un seul coup.']);
    }

    private function createKSlashAchievements()
    {
        $game = $this->games->where('game_key', 'kslash')->first();
        if (!$game) {
            return;
        }

        $voodoo = $game->achievements()->create(['game_id' => $game->id, 'key' => 'voodoo', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $voodoo->levels()->create(['level' => 1, 'target' => 1, 'reward' => 1000, 'title' => 'Voyage initiatique', 'description' => 'Récolter une poupée vaudou.']);

        $killTankers = $game->achievements()->create(['game_id' => $game->id, 'key' => 'kill_tankers', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killTankers->levels()->create(['level' => 1, 'target' => 10, 'reward' => 100, 'title' => 'Guerrier', 'description' => 'Tuer un total cumulé de 10 Tankers.']);
        $killTankers->levels()->create(['level' => 2, 'target' => 50, 'reward' => 500, 'title' => 'Maître', 'description' => 'Tuer un total cumulé de 50 Tankers.']);
        $killTankers->levels()->create(['level' => 3, 'target' => 1000, 'reward' => 1000, 'title' => 'Ninja', 'description' => 'Tuer un total cumulé de 1.000 Tankers.']);

        $softKillTurtles = $game->achievements()->create(['game_id' => $game->id, 'key' => 'soft_kill_turtles', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $softKillTurtles->levels()->create(['level' => 1, 'target' => 50, 'reward' => 100, 'title' => 'Ça va pas la tête ?!', 'description' => 'Tuer un total cumulé de 50 Tortues en leur sautant dessus.']);
        $softKillTurtles->levels()->create(['level' => 2, 'target' => 250, 'reward' => 500, 'title' => 'Assomeur de tortues', 'description' => 'Tuer un total cumulé de 250 Tortues en leur sautant dessus.']);
        $softKillTurtles->levels()->create(['level' => 3, 'target' => 750, 'reward' => 1000, 'title' => 'Plombier moustachu', 'description' => 'Tuer un total cumulé de 750 Tortues en leur sautant dessus.']);

        $softKillBats = $game->achievements()->create(['game_id' => $game->id, 'key' => 'soft_kill_bats', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $softKillBats->levels()->create(['level' => 1, 'target' => 5, 'reward' => 100, 'title' => 'Bat-paf', 'description' => 'Tuer un total cumulé de 5 Chauve-souris en leur sautant dessus.']);
        $softKillBats->levels()->create(['level' => 2, 'target' => 20, 'reward' => 500, 'title' => 'Bat-crêpe', 'description' => 'Tuer un total cumulé de 20 Chauve-souris en leur sautant dessus.']);
        $softKillBats->levels()->create(['level' => 3, 'target' => 50, 'reward' => 1000, 'title' => 'Batman n\'a qu\'à bien se tenir', 'description' => 'Tuer un total cumulé de 50 Chauve-souris en leur sautant dessus.']);

        $softKillTankers = $game->achievements()->create(['game_id' => $game->id, 'key' => 'soft_kill_tankers', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $softKillTankers->levels()->create(['level' => 1, 'target' => 5, 'reward' => 100, 'title' => 'Pied de nez', 'description' => 'Tuer un total cumulé de 5 Tankers en leur sautant dessus.']);
        $softKillTankers->levels()->create(['level' => 2, 'target' => 25, 'reward' => 500, 'title' => 'Piétineur', 'description' => 'Tuer un total cumulé de 25 Tankers en leur sautant dessus.']);
        $softKillTankers->levels()->create(['level' => 3, 'target' => 150, 'reward' => 1000, 'title' => 'Coup de pied latéral en pleine face', 'description' => 'Tuer un total cumulé de 150 Tankers en leur sautant dessus.']);

        $superStarKills = $game->achievements()->create(['game_id' => $game->id, 'key' => 'super_star_kills', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $superStarKills->levels()->create(['level' => 1, 'target' => 50, 'reward' => 100, 'title' => 'Plus invincible que le slip de Superman', 'description' => 'Tuer un total cumulé de 50 monstres avec le bonus étoile.']);
        $superStarKills->levels()->create(['level' => 2, 'target' => 150, 'reward' => 500, 'title' => 'Plus invincible que Benoît Brisefer sous antihistaminiques', 'description' => 'Tuer un total cumulé de 150 monstres avec le bonus étoile.']);
        $superStarKills->levels()->create(['level' => 3, 'target' => 500, 'reward' => 1000, 'title' => 'Plus invincible qu\'Achille cul-de-jatte', 'description' => 'Tuer un total cumulé de 500 monstres avec le bonus étoile.']);

        $noShurikenScore = $game->achievements()->create(['game_id' => $game->id, 'key' => 'no_shuriken_score', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $noShurikenScore->levels()->create(['level' => 1, 'target' => 5000, 'reward' => 100, 'title' => 'Peace & Slash', 'description' => 'Atteindre un score de 5.000 sans utiliser de shurikens.']);
        $noShurikenScore->levels()->create(['level' => 2, 'target' => 12000, 'reward' => 500, 'title' => 'Maître d\'armes', 'description' => 'Atteindre un score de 12.000 sans utiliser de shurikens.']);
        $noShurikenScore->levels()->create(['level' => 3, 'target' => 20000, 'reward' => 1000, 'title' => 'La voie du sabre', 'description' => 'Atteindre un score de 20.000 sans utiliser de shurikens.']);

        $shurikenStock = $game->achievements()->create(['game_id' => $game->id, 'key' => 'shuriken_stock', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $shurikenStock->levels()->create(['level' => 1, 'target' => 200, 'reward' => 250, 'title' => 'Réserves', 'description' => 'Atteindre 200 shurikens en stock.']);

        $allBonuses = $game->achievements()->create(['game_id' => $game->id, 'key' => 'all_bonuses', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $allBonuses->levels()->create(['level' => 1, 'target' => 7, 'reward' => 1000, 'title' => 'Je suis increvab...', 'description' => 'Obtenir les 3 bonus en même temps.']);

        $diversity = $game->achievements()->create(['game_id' => $game->id, 'key' => 'diversity', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $diversity->levels()->create(['level' => 1, 'target' => 1, 'reward' => 1000, 'title' => 'Diversité', 'description' => 'Tuer un monstre de chaque type en une partie.']);

        $threeRespawns = $game->achievements()->create(['game_id' => $game->id, 'key' => 'three_respawns', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $threeRespawns->levels()->create(['level' => 1, 'target' => 3, 'reward' => 2000, 'title' => 'Plus fort que la mort', 'description' => 'Réapparaître 3 fois dans une partie.']);
    }

    private function createMagmaxAchievements()
    {
        $game = $this->games->where('game_key', 'magmax')->first();
        if (!$game) {
            return;
        }

        $turretsKilled = $game->achievements()->create(['game_id' => $game->id, 'key' => 'turrets_killed', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $turretsKilled->levels()->create(['level' => 1, 'target' => 10, 'reward' => 100, 'title' => 'Démontage de tourelle', 'description' => 'Tuer 10 tourelles.']);
        $turretsKilled->levels()->create(['level' => 2, 'target' => 100, 'reward' => 500, 'title' => 'Poussière de tourelle', 'description' => 'Tuer 100 tourelles.']);
        $turretsKilled->levels()->create(['level' => 3, 'target' => 1000, 'reward' => 1000, 'title' => 'Syndrome de la Tourelle', 'description' => 'Tuer 1.000 tourelles.']);

        $gemsCollected = $game->achievements()->create(['game_id' => $game->id, 'key' => 'gems_collected', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $gemsCollected->levels()->create(['level' => 1, 'target' => 100, 'reward' => 100, 'title' => 'Premier collier', 'description' => 'Obtenir 100 boules de couleur.']);
        $gemsCollected->levels()->create(['level' => 2, 'target' => 1000, 'reward' => 500, 'title' => 'Chasseur de perles', 'description' => 'Obtenir 1.000 boules de couleur.']);
        $gemsCollected->levels()->create(['level' => 3, 'target' => 10000, 'reward' => 1000, 'title' => 'Parure légendaire', 'description' => 'Obtenir 10.000 boules de couleur.']);

        $flowersOneGame = $game->achievements()->create(['game_id' => $game->id, 'key' => 'flowers_one_game', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $flowersOneGame->levels()->create(['level' => 1, 'target' => 5, 'reward' => 100, 'title' => 'Désherbage express', 'description' => 'Tuer 5 fleurs en une seule partie.']);
        $flowersOneGame->levels()->create(['level' => 2, 'target' => 10, 'reward' => 500, 'title' => 'Le beau bouquet', 'description' => 'Tuer 10 fleurs en une seule partie.']);
        $flowersOneGame->levels()->create(['level' => 3, 'target' => 15, 'reward' => 1000, 'title' => 'Fléau des Pétales', 'description' => 'Tuer 15 fleurs en une seule partie.']);

        $magmax = $game->achievements()->create(['game_id' => $game->id, 'key' => 'magmax', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $magmax->levels()->create(['level' => 1, 'target' => 1, 'reward' => 250, 'title' => 'Maximaxeur', 'description' => 'Faire un Magmax.']);

        $bothBonuses = $game->achievements()->create(['game_id' => $game->id, 'key' => 'both_bonuses', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $bothBonuses->levels()->create(['level' => 1, 'target' => 1, 'reward' => 1000, 'title' => 'Armé jusqu\'aux dents', 'description' => 'Obtenir les 2 bonus spéciaux en même temps.']);

        $killOrder = $game->achievements()->create(['game_id' => $game->id, 'key' => 'kill_order', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killOrder->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'Tri séquentiel', 'description' => 'Tuer dans l\'ordre goutte, fleur et tourelle dans un même combo.']);
    }

    private function createKanjiAchievements()
    {
        $game = $this->games->where('game_key', 'kanji')->first();
        if (!$game) {
            return;
        }

        $gatherBonus = $game->achievements()->create(['game_id' => $game->id, 'key' => 'gather_bonus', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $gatherBonus->levels()->create(['level' => 1, 'target' => 1000, 'reward' => 100, 'title' => 'Ceuilleur', 'description' => 'Récupérer un total cumulé de 1.000 bonus.']);
        $gatherBonus->levels()->create(['level' => 2, 'target' => 5000, 'reward' => 500, 'title' => 'Glaneur', 'description' => 'Récupérer un total cumulé de 5.000 bonus.']);
        $gatherBonus->levels()->create(['level' => 3, 'target' => 15000, 'reward' => 1000, 'title' => 'Collectionneur', 'description' => 'Récupérer un total cumulé de 15.000 bonus.']);

        $killStorks = $game->achievements()->create(['game_id' => $game->id, 'key' => 'kill_storks', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killStorks->levels()->create(['level' => 1, 'target' => 500, 'reward' => 100, 'title' => 'Je déteste la faune', 'description' => 'Rebondir un total cumulé de 500 fois sur des cigognes.']);
        $killStorks->levels()->create(['level' => 2, 'target' => 2500, 'reward' => 500, 'title' => 'À mort les zozios !', 'description' => 'Rebondir un total cumulé de 2.500 fois sur des cigognes.']);
        $killStorks->levels()->create(['level' => 3, 'target' => 5000, 'reward' => 1000, 'title' => 'Hécatombe aviaire', 'description' => 'Rebondir un total cumulé de 5.000 fois sur des cigognes.']);

        $wallJumps = $game->achievements()->create(['game_id' => $game->id, 'key' => 'wall_jumps', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $wallJumps->levels()->create(['level' => 1, 'target' => 50, 'reward' => 100, 'title' => 'Boing', 'description' => 'Rebondir un total cumulé de 50 fois sur les murs.']);
        $wallJumps->levels()->create(['level' => 2, 'target' => 250, 'reward' => 500, 'title' => 'Solides ces murs !', 'description' => 'Rebondir un total cumulé de 250 fois sur les murs.']);
        $wallJumps->levels()->create(['level' => 3, 'target' => 750, 'reward' => 1000, 'title' => 'Platrier de père en fils', 'description' => 'Rebondir un total cumulé de 750 fois sur les murs.']);

        $avoidBoars = $game->achievements()->create(['game_id' => $game->id, 'key' => 'avoid_boars', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $avoidBoars->levels()->create(['level' => 1, 'target' => 10, 'reward' => 100, 'title' => 'Ça sent le cochon non ?', 'description' => 'Éviter un total cumulé de 10 marcassins.']);
        $avoidBoars->levels()->create(['level' => 2, 'target' => 100, 'reward' => 500, 'title' => 'On n\'a pas gardé les cochons ensemble', 'description' => 'Éviter un total cumulé de 100 marcassins.']);
        $avoidBoars->levels()->create(['level' => 3, 'target' => 1000, 'reward' => 1000, 'title' => 'Maître de la harde', 'description' => 'Éviter un total cumulé de 1.000 marcassins.']);

        $avoidBoarsShort = $game->achievements()->create(['game_id' => $game->id, 'key' => 'avoid_boars_short', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $avoidBoarsShort->levels()->create(['level' => 1, 'target' => 1, 'reward' => 100, 'title' => 'Pas folle la guêpe', 'description' => 'Esquiver 1 marcassin avec des mini-sauts en une partie.']);
        $avoidBoarsShort->levels()->create(['level' => 2, 'target' => 4, 'reward' => 500, 'title' => 'Allez salto !', 'description' => 'Esquiver 4 marcassins avec des mini-sauts en une partie.']);
        $avoidBoarsShort->levels()->create(['level' => 3, 'target' => 8, 'reward' => 1000, 'title' => 'Ninja 8ème dan', 'description' => 'Esquiver 8 marcassins avec des mini-sauts en une partie.']);

        $killStreak = $game->achievements()->create(['game_id' => $game->id, 'key' => 'kill_streak', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killStreak->levels()->create(['level' => 1, 'target' => 5, 'reward' => 100, 'title' => 'Floor is lava', 'description' => 'Rebondir sur 5 cigognes sans toucher le sol.']);
        $killStreak->levels()->create(['level' => 2, 'target' => 15, 'reward' => 500, 'title' => 'Expert de la voltige', 'description' => 'Rebondir sur 15 cigognes sans toucher le sol.']);
        $killStreak->levels()->create(['level' => 3, 'target' => 25, 'reward' => 1000, 'title' => 'Pilote de la patrouille de France', 'description' => 'Rebondir sur 25 cigognes sans toucher le sol.']);

        $noStorkKillScore = $game->achievements()->create(['game_id' => $game->id, 'key' => 'no_stork_kill_score', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $noStorkKillScore->levels()->create(['level' => 1, 'target' => 15000, 'reward' => 100, 'title' => 'Amoureux de la faune', 'description' => 'Atteindre 15.000 points sans tuer de cigognes.']);
        $noStorkKillScore->levels()->create(['level' => 2, 'target' => 25000, 'reward' => 500, 'title' => 'peace and love', 'description' => 'Atteindre 25.000 points sans tuer de cigognes.']);
        $noStorkKillScore->levels()->create(['level' => 3, 'target' => 35000, 'reward' => 1000, 'title' => 'Vegan', 'description' => 'Atteindre 35.000 points sans tuer de cigognes.']);

        $bonusStreak = $game->achievements()->create(['game_id' => $game->id, 'key' => 'bonus_streak', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $bonusStreak->levels()->create(['level' => 1, 'target' => 5, 'reward' => 250, 'title' => 'Regarde comme je saute bien', 'description' => 'Récupérer 5 bonus en un saut sans rebondir sur des cigognes.']);

        $lastKillCount = $game->achievements()->create(['game_id' => $game->id, 'key' => 'last_kill_count', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $lastKillCount->levels()->create(['level' => 1, 'target' => 15, 'reward' => 1000, 'title' => 'Allez on arrête de spawn là', 'description' => 'Tuer la dernière cigogne en vie 15 fois dans la même partie.']);

        $flyStreak = $game->achievements()->create(['game_id' => $game->id, 'key' => 'fly_streak', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $flyStreak->levels()->create(['level' => 1, 'target' => 25, 'reward' => 2000, 'title' => 'I believe I can fly', 'description' => 'Rester 25 secondes en l\'air.']);
    }

    private function createTravoltaxAchievements()
    {
        $game = $this->games->where('game_key', 'travoltax')->first();
        if (!$game) {
            return;
        }

        $destroyLines = $game->achievements()->create(['game_id' => $game->id, 'key' => 'destroy_lines', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $destroyLines->levels()->create(['level' => 1, 'target' => 2000, 'reward' => 100, 'title' => 'Paragraphe 2000', 'description' => 'Détruire un total cumulé de 2.000 lignes.']);
        $destroyLines->levels()->create(['level' => 2, 'target' => 10000, 'reward' => 500, 'title' => 'Alinéa 10.000', 'description' => 'Détruire un total cumulé de 10.000 lignes.']);
        $destroyLines->levels()->create(['level' => 3, 'target' => 25000, 'reward' => 1000, 'title' => 'Ligne 25.000', 'description' => 'Détruire un total cumulé de 25.000 lignes.']);

        $useCalm = $game->achievements()->create(['game_id' => $game->id, 'key' => 'use_calm', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $useCalm->levels()->create(['level' => 1, 'target' => 1, 'reward' => 100, 'title' => 'Souffle un coup', 'description' => 'Utiliser 1 bonus "calme".']);
        $useCalm->levels()->create(['level' => 2, 'target' => 20, 'reward' => 500, 'title' => 'Calme raplapla', 'description' => 'Utiliser un total cumulé de 20 bonus "calme".']);
        $useCalm->levels()->create(['level' => 3, 'target' => 40, 'reward' => 1000, 'title' => 'Zénitude attitude', 'description' => 'Utiliser un total cumulé de 40 bonus "calme".']);

        $usePsycho = $game->achievements()->create(['game_id' => $game->id, 'key' => 'use_psycho', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $usePsycho->levels()->create(['level' => 1, 'target' => 1, 'reward' => 100, 'title' => 'Upside down', 'description' => 'Utiliser 1 bonus "psycho" en une seule partie.']);
        $usePsycho->levels()->create(['level' => 2, 'target' => 3, 'reward' => 500, 'title' => 'Fou furieux', 'description' => 'Utiliser 3 bonus "psycho" en une seule partie.']);
        $usePsycho->levels()->create(['level' => 3, 'target' => 5, 'reward' => 1000, 'title' => 'The Joker', 'description' => 'Utiliser 5 bonus "psycho" en une seule partie.']);

        $destroyTenLines = $game->achievements()->create(['game_id' => $game->id, 'key' => 'destroy_ten_lines', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $destroyTenLines->levels()->create(['level' => 1, 'target' => 10, 'reward' => 2000, 'title' => 'Décimation linéaire', 'description' => 'Détruire 10 lignes d\'un coup.']);

        $clearGrid = $game->achievements()->create(['game_id' => $game->id, 'key' => 'clear_grid', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $clearGrid->levels()->create(['level' => 1, 'target' => 1, 'reward' => 250, 'title' => 'Total reset', 'description' => 'Vider entièrement la grille.']);

        $coldSweats = $game->achievements()->create(['game_id' => $game->id, 'key' => 'cold_sweats', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $coldSweats->levels()->create(['level' => 1, 'target' => 30, 'reward' => 1000, 'title' => 'Sueurs froides', 'description' => 'Survivre 30 secondes alors qu\'il y a des pièces jusqu\'au plafond.']);

        $mafia = $game->achievements()->create(['game_id' => $game->id, 'key' => 'mafia', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $mafia->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'Mafieux', 'description' => 'Réussir un contrat à 8.000 points minimum.']);
    }

    private function createSynapsesAchievements()
    {
        $game = $this->games->where('game_key', 'synapses')->first();
        if (!$game) {
            return;
        }

        $totalNeuronsConnected = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_neurons_connected', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalNeuronsConnected->levels()->create(['level' => 1, 'target' => 2500, 'reward' => 100, 'title' => 'Psychologue', 'description' => 'Connecter un total de 2.500 neurones.']);
        $totalNeuronsConnected->levels()->create(['level' => 2, 'target' => 10000, 'reward' => 500, 'title' => 'Psychiatre', 'description' => 'Connecter un total de 10.000 neurones.']);
        $totalNeuronsConnected->levels()->create(['level' => 3, 'target' => 100000, 'reward' => 1000, 'title' => 'Neurochirurgien', 'description' => 'Connecter un total de 100.000 neurones.']);

        $levelOneScore = $game->achievements()->create(['game_id' => $game->id, 'key' => 'level_one_score', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $levelOneScore->levels()->create(['level' => 1, 'target' => 25000, 'reward' => 100, 'title' => 'Je valide', 'description' => 'Atteindre un score de 25.000 au niveau 1.']);
        $levelOneScore->levels()->create(['level' => 2, 'target' => 30000, 'reward' => 500, 'title' => 'C\'est OK', 'description' => 'Atteindre un score de 30.000 au niveau 1.']);
        $levelOneScore->levels()->create(['level' => 3, 'target' => 35000, 'reward' => 1000, 'title' => 'C\'est nickel', 'description' => 'Atteindre un score de 35.000 au niveau 1.']);

        $neuronScore = $game->achievements()->create(['game_id' => $game->id, 'key' => 'neuron_score', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $neuronScore->levels()->create(['level' => 1, 'target' => 500, 'reward' => 100, 'title' => 'Bon sens', 'description' => 'Atteindre un neurone à 500 points.']);
        $neuronScore->levels()->create(['level' => 2, 'target' => 600, 'reward' => 500, 'title' => 'Lucidité', 'description' => 'Atteindre un neurone à 600 points.']);
        $neuronScore->levels()->create(['level' => 3, 'target' => 700, 'reward' => 1000, 'title' => 'Clairvoyance', 'description' => 'Atteindre un neurone à 700 points.']);

        $afk = $game->achievements()->create(['game_id' => $game->id, 'key' => 'afk', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $afk->levels()->create(['level' => 1, 'target' => 1, 'reward' => 250, 'title' => 'AFK', 'description' => 'Gagner un niveau sans cliquer.']);

        $champion = $game->achievements()->create(['game_id' => $game->id, 'key' => 'champion', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $champion->levels()->create(['level' => 1, 'target' => 40, 'reward' => 1000, 'title' => 'Champion', 'description' => 'Gagner contre 4 adversaires en même temps avec au moins 40 neurones connectés.']);

        $tieWin = $game->achievements()->create(['game_id' => $game->id, 'key' => 'tie_win', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $tieWin->levels()->create(['level' => 1, 'target' => 1, 'reward' => 1000, 'title' => 'Arbitre partial', 'description' => 'Gagner sur une égalité.']);

        $crushingVictory = $game->achievements()->create(['game_id' => $game->id, 'key' => 'crushing_victory', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $crushingVictory->levels()->create(['level' => 1, 'target' => 75, 'reward' => 2000, 'title' => 'Victoire écrasante', 'description' => 'À partir du niveau 3, gagner avec au moins 75 neurones connectés.']);
    }

    private function createTiananManAchievements()
    {
        $game = $this->games->where('game_key', 'tiananman')->first();
        if (!$game) {
            return;
        }

        $followersCollected = $game->achievements()->create(['game_id' => $game->id, 'key' => 'followers_collected', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $followersCollected->levels()->create(['level' => 1, 'target' => 500, 'reward' => 100, 'title' => 'Viendez les zamis', 'description' => 'Récupérer 500 manifestants.']);
        $followersCollected->levels()->create(['level' => 2, 'target' => 5000, 'reward' => 500, 'title' => 'On est fâchés tout rouge', 'description' => 'Récupérer 5.000 manifestants.']);
        $followersCollected->levels()->create(['level' => 3, 'target' => 20000, 'reward' => 1000, 'title' => 'Plus on est de fous moins il y a de riz', 'description' => 'Récupérer 20.000 manifestants.']);

        $vehiclesDestroyed = $game->achievements()->create(['game_id' => $game->id, 'key' => 'vehicles_destroyed', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $vehiclesDestroyed->levels()->create(['level' => 1, 'target' => 50, 'reward' => 100, 'title' => 'Accident de la route', 'description' => 'Détruire 50 véhicules.']);
        $vehiclesDestroyed->levels()->create(['level' => 2, 'target' => 500, 'reward' => 500, 'title' => 'Cascadeur', 'description' => 'Détruire 500 véhicules.']);
        $vehiclesDestroyed->levels()->create(['level' => 3, 'target' => 2000, 'reward' => 1000, 'title' => 'Épaviste', 'description' => 'Détruire 2.000 véhicules.']);

        $fevers = $game->achievements()->create(['game_id' => $game->id, 'key' => 'fevers', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $fevers->levels()->create(['level' => 1, 'target' => 1, 'reward' => 100, 'title' => 'Dénonceur', 'description' => 'Passer en mode frénésie 1 fois en une seule partie.']);
        $fevers->levels()->create(['level' => 2, 'target' => 2, 'reward' => 500, 'title' => 'Proclameur', 'description' => 'Passer en mode frénésie 2 fois en une seule partie.']);
        $fevers->levels()->create(['level' => 3, 'target' => 3, 'reward' => 1000, 'title' => 'Contestataire', 'description' => 'Passer en mode frénésie 3 fois en une seule partie.']);

        $vehicleDiversity = $game->achievements()->create(['game_id' => $game->id, 'key' => 'vehicle_diversity', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $vehicleDiversity->levels()->create(['level' => 1, 'target' => 5, 'reward' => 250, 'title' => 'Collectionneur de carcasses', 'description' => 'Détruire 1 véhicule de chaque type en une partie avec la frénésie.']);

        $noFollowerLostFever = $game->achievements()->create(['game_id' => $game->id, 'key' => 'no_follower_lost_fever', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $noFollowerLostFever->levels()->create(['level' => 1, 'target' => 1, 'reward' => 1000, 'title' => 'Pro de la savonnette', 'description' => 'Passer en mode frénésie sans avoir perdu un seul manifestant.']);

        $lastFollowerScore = $game->achievements()->create(['game_id' => $game->id, 'key' => 'last_follower_score', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $lastFollowerScore->levels()->create(['level' => 1, 'target' => 100000, 'reward' => 2000, 'title' => 'Survivant', 'description' => 'Gagner 100.000 points en n\'ayant plus qu\'un seul point de vie.']);
    }

    private function createTubuloAchievements()
    {
        $game = $this->games->where('game_key', 'tubulo')->first();
        if (!$game) {
            return;
        }

        $levelResets = $game->achievements()->create(['game_id' => $game->id, 'key' => 'level_resets', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $levelResets->levels()->create(['level' => 1, 'target' => 25, 'reward' => 100, 'title' => 'On recommence', 'description' => 'Redémarrer 25 niveaux.']);
        $levelResets->levels()->create(['level' => 2, 'target' => 150, 'reward' => 500, 'title' => 'Mauvaise pioche', 'description' => 'Redémarrer 150 niveaux.']);
        $levelResets->levels()->create(['level' => 3, 'target' => 500, 'reward' => 1000, 'title' => 'Le réinitialiseur', 'description' => 'Redémarrer 500 niveaux.']);

        $greenPaint = $game->achievements()->create(['game_id' => $game->id, 'key' => 'green_paint', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $greenPaint->levels()->create(['level' => 1, 'target' => 1000, 'reward' => 100, 'title' => 'Peintre écolo', 'description' => 'Colorer 1.000 tubes en vert.']);
        $greenPaint->levels()->create(['level' => 2, 'target' => 10000, 'reward' => 500, 'title' => 'Greenwashing', 'description' => 'Colorer 10.000 tubes en vert.']);
        $greenPaint->levels()->create(['level' => 3, 'target' => 100000, 'reward' => 1000, 'title' => 'Vert l\'infini et l\'eau verdâtre', 'description' => 'Colorer 100.000 tubes en vert.']);

        $reachLevel = $game->achievements()->create(['game_id' => $game->id, 'key' => 'reach_level', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $reachLevel->levels()->create(['level' => 1, 'target' => 8, 'reward' => 100, 'title' => 'Octo-huitre', 'description' => 'Atteindre le niveau 8.']);
        $reachLevel->levels()->create(['level' => 2, 'target' => 10, 'reward' => 500, 'title' => 'Déca-bulot', 'description' => 'Atteindre le niveau 10.']);
        $reachLevel->levels()->create(['level' => 3, 'target' => 12, 'reward' => 1000, 'title' => 'Dodéca-moule', 'description' => 'Atteindre le niveau 12.']);

        $minScore = $game->achievements()->create(['game_id' => $game->id, 'key' => 'min_score', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $minScore->levels()->create(['level' => 1, 'target' => 1, 'reward' => 250, 'title' => 'T\'as bu l\'eau', 'description' => 'Finir la partie avec 200 points.']);

        $level9ChronoMax = $game->achievements()->create(['game_id' => $game->id, 'key' => 'level_9_chrono_max', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $level9ChronoMax->levels()->create(['level' => 1, 'target' => 1, 'reward' => 1000, 'title' => 'Neuf comme un sou', 'description' => 'Atteindre le niveau 9 en ayant le chronomètre rempli au max.']);

        $level10WithoutRetry = $game->achievements()->create(['game_id' => $game->id, 'key' => 'level_10_without_retry', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $level10WithoutRetry->levels()->create(['level' => 1, 'target' => 1, 'reward' => 2000, 'title' => 'Dix de der', 'description' => 'Atteindre le niveau 10 sans avoir redémarré de niveau.']);
    }

    private function createKillBulleAchievements()
    {
        $game = $this->games->where('game_key', 'killbulle')->first();
        if (!$game) {
            return;
        }

        $totalBubblesPopped = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_bubbles_popped', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalBubblesPopped->levels()->create(['level' => 1, 'target' => 1500, 'reward' => 100, 'title' => 'Fragmenteur', 'description' => 'Éclater 1.500 bulles.']);
        $totalBubblesPopped->levels()->create(['level' => 2, 'target' => 20000, 'reward' => 500, 'title' => 'Légende du Pop', 'description' => 'Éclater 20.000 bulles.']);
        $totalBubblesPopped->levels()->create(['level' => 3, 'target' => 100000, 'reward' => 1000, 'title' => 'Maitre de la division', 'description' => 'Éclater 100.000 bulles.']);

        $totalYingYangs = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_ying_yangs', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalYingYangs->levels()->create(['level' => 1, 'target' => 20, 'reward' => 100, 'title' => 'Calme', 'description' => 'Récupérer 20 bonus ying-yang.']);
        $totalYingYangs->levels()->create(['level' => 2, 'target' => 100, 'reward' => 500, 'title' => 'Tranquille', 'description' => 'Récupérer 100 bonus ying-yang.']);
        $totalYingYangs->levels()->create(['level' => 3, 'target' => 500, 'reward' => 1000, 'title' => 'Zen', 'description' => 'Récupérer 500 bonus ying-yang.']);

        $totalTimeBonuses = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_time_bonuses', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalTimeBonuses->levels()->create(['level' => 1, 'target' => 20, 'reward' => 100, 'title' => 'Fan de sieste', 'description' => 'Utiliser 20 bonus horloge.']);
        $totalTimeBonuses->levels()->create(['level' => 2, 'target' => 100, 'reward' => 500, 'title' => 'Maître du tempo', 'description' => 'Utiliser 100 bonus horloge.']);
        $totalTimeBonuses->levels()->create(['level' => 3, 'target' => 500, 'reward' => 1000, 'title' => 'Seigneur du temps', 'description' => 'Utiliser 500 bonus horloge.']);

        $bigBubbles = $game->achievements()->create(['game_id' => $game->id, 'key' => 'big_bubbles', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $bigBubbles->levels()->create(['level' => 1, 'target' => 1, 'reward' => 100, 'title' => 'Eclateur de baudruche', 'description' => 'Éclater 1 grosse bulle en une seule partie.']);
        $bigBubbles->levels()->create(['level' => 2, 'target' => 3, 'reward' => 500, 'title' => 'Dézingueur de montgolfières', 'description' => 'Éclater 3 grosses bulles en une seule partie.']);
        $bigBubbles->levels()->create(['level' => 3, 'target' => 5, 'reward' => 1000, 'title' => 'Massacreur de zeppelins', 'description' => 'Éclater 5 grosses bulles en une seule partie.']);

        $tenWithKunai = $game->achievements()->create(['game_id' => $game->id, 'key' => 'ten_with_kunai', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $tenWithKunai->levels()->create(['level' => 1, 'target' => 10, 'reward' => 250, 'title' => 'Boucher', 'description' => 'Éclater 10 bulles avec un seul bonus de kunais.']);

        $tenWithShuriken = $game->achievements()->create(['game_id' => $game->id, 'key' => 'ten_with_shuriken', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $tenWithShuriken->levels()->create(['level' => 1, 'target' => 10, 'reward' => 1000, 'title' => 'Ninja', 'description' => 'Éclater 10 bulles avec un seul bonus shuriken.']);

        $tenWithTimeBonus = $game->achievements()->create(['game_id' => $game->id, 'key' => 'ten_with_time_bonus', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $tenWithTimeBonus->levels()->create(['level' => 1, 'target' => 10, 'reward' => 2000, 'title' => 'Le temps est une bulle', 'description' => 'Éclater 10 bulles pendant un seul bonus de temps.']);
    }

    private function createKanjisNightmareAchievements()
    {
        $game = $this->games->where('game_key', 'kanjisnightmare')->first();
        if (!$game) {
            return;
        }

        $totalBlueTurtlesKilled = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_blue_turtles_killed', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalBlueTurtlesKilled->levels()->create(['level' => 1, 'target' => 25, 'reward' => 100, 'title' => 'Ninja vs Tortues', 'description' => 'Tuer un total cumulé de 25 tortues bleues.']);
        $totalBlueTurtlesKilled->levels()->create(['level' => 2, 'target' => 100, 'reward' => 500, 'title' => 'Extinction bleue', 'description' => 'Tuer un total cumulé de 100 tortues bleues.']);
        $totalBlueTurtlesKilled->levels()->create(['level' => 3, 'target' => 250, 'reward' => 1000, 'title' => 'Némésis bleue', 'description' => 'Tuer un total cumulé de 250 tortues bleues.']);

        $killTurtles = $game->achievements()->create(['game_id' => $game->id, 'key' => 'turtles_killed', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $killTurtles->levels()->create(['level' => 1, 'target' => 50, 'reward' => 100, 'title' => 'Tortue luth', 'description' => 'Tuer 50 tortues en une seule partie.']);
        $killTurtles->levels()->create(['level' => 2, 'target' => 100, 'reward' => 500, 'title' => 'Tortue ninja', 'description' => 'Tuer 100 tortues en une seule partie.']);
        $killTurtles->levels()->create(['level' => 3, 'target' => 150, 'reward' => 1000, 'title' => 'Tortueur', 'description' => 'Tuer 150 tortues en une seule partie.']);

        $getHooks = $game->achievements()->create(['game_id' => $game->id, 'key' => 'get_hooks', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $getHooks->levels()->create(['level' => 1, 'target' => 4, 'reward' => 100, 'title' => 'Bonus hepta-cool !', 'description' => 'Obtenir 7 grapins permanents en une seule partie.']);
        $getHooks->levels()->create(['level' => 2, 'target' => 5, 'reward' => 500, 'title' => 'Méthode octo-turbo', 'description' => 'Obtenir 8 grapins permanents en une seule partie.']);

        $repairBrokenArmor = $game->achievements()->create(['game_id' => $game->id, 'key' => 'repair_broken_armor', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $repairBrokenArmor->levels()->create(['level' => 1, 'target' => 1, 'reward' => 250, 'title' => 'Lessive terminée !', 'description' => 'Réparer une armure cassée.']);

        $getThreePermanentOpts = $game->achievements()->create(['game_id' => $game->id, 'key' => 'get_three_permanent_opts', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $getThreePermanentOpts->levels()->create(['level' => 1, 'target' => 3, 'reward' => 1000, 'title' => 'Opération triforce', 'description' => 'Obtenir 3 bonus permanents en même temps.']);

        $getAllPermanentOpts = $game->achievements()->create(['game_id' => $game->id, 'key' => 'get_all_permanent_opts', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $getAllPermanentOpts->levels()->create(['level' => 1, 'target' => 5, 'reward' => 2000, 'title' => 'Équipement militaire', 'description' => 'Obtenir tous les bonus permanents en même temps.']);

        $totalGraphinsUsed = $game->achievements()->create(['game_id' => $game->id, 'key' => 'total_graphins_used', 'category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        $totalGraphinsUsed->levels()->create(['level' => 1, 'target' => 500, 'reward' => 100, 'title' => 'Niveau ouistiti', 'description' => 'Utiliser le grapin 500 fois.']);
        $totalGraphinsUsed->levels()->create(['level' => 2, 'target' => 10000, 'reward' => 500, 'title' => 'Niveau gibbon', 'description' => 'Utiliser le grapin 10.000 fois.']);
        $totalGraphinsUsed->levels()->create(['level' => 3, 'target' => 25000, 'reward' => 1000, 'title' => 'Niveau orang-outan', 'description' => 'Utiliser le grapin 25.000 fois.']);
    }
}
