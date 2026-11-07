<?php

namespace Database\Seeders;

use App\Enums\AchievementCategory;
use App\Enums\AchievementProgressScope;
use App\Models\Achievement;
use App\Models\Game;
use Illuminate\Database\Seeder;

class AchievementsSeeder extends Seeder
{
    /**
     * The achievements of each game (by game_key), with their levels: [target, reward, title, description]. Big numbers
     * are written with dots in the descriptions (1.000, 25.000).
     *
     * @var array<string, array<string, list<array{int, int, string, string}>>>
     */
    private const ACHIEVEMENTS = [
        'atlanteine' => [
            'ghosts_killed' => [
                [1, 100, 'Bouh!', 'Tuer 1 fantôme.'],
                [50, 500, 'Masacre ectoplasmique', 'Tuer 50 fantômes.'],
                [200, 1000, 'Chasseur sans tête', 'Tuer 200 fantômes.'],
            ],
            'boxes_moved' => [
                [10, 100, 'Brocanteur', 'Déplacer 10 caisses.'],
                [50, 500, 'Déménageur', 'Déplacer 50 caisses.'],
                [200, 1000, 'Transporteur', 'Déplacer 200 caisses.'],
            ],
            'water_deaths' => [
                [10, 100, 'Parachutiste', 'Tomber 10 fois dans l\'eau.'],
                [50, 500, 'Base-jumper', 'Tomber 50 fois dans l\'eau.'],
                [100, 1000, 'Baumgartner', 'Tomber 100 fois dans l\'eau.'],
            ],
            'level_reached' => [
                [10, 100, 'Promeneur', 'Atteindre le niveau 10.'],
                [20, 500, 'Randonneur', 'Atteindre le niveau 20.'],
                [30, 1000, 'Explorateur', 'Atteindre le niveau 30.'],
            ],
            'bonus_boxes' => [
                [3000, 250, 'On encaisse', 'Récupérer 3.000 points bonus de caisses en un seul niveau.'],
            ],
            'push_box_on_ghost' => [
                [1, 1000, 'Prends ça !', 'Pousser une caisse sur un fantôme.'],
            ],
            'ghost_buster' => [
                [3, 2000, 'Ghost buster', 'Foncer dans 3 fantômes dans un même niveau puis le réussir.'],
            ],
        ],
        'bactery' => [
            'few_bacteria' => [
                [1, 100, 'Antiseptique', 'Avoir 10 bactéries ou moins sur son plateau à la fin de partie.'],
                [2, 500, 'Désinfectant', 'Avoir 8 bactéries ou moins sur son plateau à la fin de partie.'],
                [3, 1000, 'Javel', 'Avoir 6 bactéries ou moins sur son plateau à la fin de partie.'],
            ],
            'total_stars' => [
                [10, 100, 'Admirateur d\'astres', 'Amasser un total de 10 étoiles.'],
                [100, 500, 'Collectionneur de constellations', 'Amasser un total de 100 étoiles.'],
                [1000, 1000, 'Adorateur de galaxies', 'Amasser un total de 1.000 étoiles.'],
            ],
            'high_scores' => [
                [1, 100, 'Les F5 ont enfin payé', 'Faire un score d\'au moins 17.000 une fois.'],
                [5, 500, 'Ça devient presque facile...', 'Faire un score d\'au moins 17.000 5 fois.'],
                [10, 1000, 'T\'as au moins pris le record du site ?', 'Faire un score d\'au moins 17.000 10 fois.'],
            ],
            'palace' => [
                [1, 250, 'La classe de palace', 'Réussir une partie avec 5 étoiles restantes et aucune bille colorée.'],
            ],
            'stones' => [
                [70, 1000, 'Bâtisseur de fondations', 'Obtenir 70 pierres en une partie.'],
            ],
            'tricolor' => [
                [1, 1000, 'Drapeau tricolore', 'Finir avec autant de bactéries, pierres et billes colorées.'],
            ],
            'colored_marbles' => [
                [85, 2000, 'F5 la prochaine fois...', 'Finir avec au moins 85 boules colorées.'],
            ],
        ],
        'chocomouche' => [
            'discovered_fives' => [
                [5, 100, 'Terrain miné', 'Découvrir 5 cases avec le chiffre 5.'],
                [25, 500, 'Infestion de mouches', 'Découvrir 25 cases avec le chiffre 5.'],
                [50, 1000, 'Pentagramme drosophilien', 'Découvrir 50 cases avec le chiffre 5.'],
            ],
            'total_discovered_cells' => [
                [500, 100, 'Le chocolat, sans les mouches', 'Découvrir 500 cases.'],
                [2000, 500, 'Dévoreur cacaoté', 'Découvrir 2.000 cases.'],
                [5000, 1000, 'Indigestion de chocolat', 'Découvrir 5.000 cases.'],
            ],
            'level_reached' => [
                [5, 100, 'Pourquoi des mouches dans du chocolat ?', 'Atteindre le niveau 5.'],
                [7, 500, 'Vous avez dit des mouches ?', 'Atteindre le niveau 7.'],
                [9, 1000, 'Où ça des mouches ?', 'Atteindre le niveau 9.'],
            ],
            'level_score' => [
                [45000, 100, 'Démineur amateur', 'Marquer 45.000 points sur un niveau.'],
                [50000, 500, 'Démineur acharné', 'Marquer 50.000 points sur un niveau.'],
                [55000, 1000, 'Démineur professionnel', 'Marquer 55.000 points sur un niveau.'],
            ],
            'five_levels_without_life_loss' => [
                [5, 250, 'Oh yeah!', 'Finir 5 niveaux de suite sans perdre de vie.'],
            ],
            'six_adjacent_flies' => [
                [1, 250, 'Chanceux', 'Découvrir une case avec 6 mouches à proximité.'],
            ],
            'three_first_fly_losses' => [
                [1, 1000, 'Malchanceux', 'Perdre 3 vies sur les 3 premières cases découvertes d\'une grille.'],
            ],
            'seven_clicks_level' => [
                [1, 1000, 'Vite fait bien fait', 'Terminer un niveau avec maximum 7 cases cliquées.'],
            ],
            'fast_level_one' => [
                [1, 2000, 'J\'AI FAIM !', 'Terminer le niveau 1 en moins de 15 secondes.'],
            ],
        ],
        'f1champion' => [
            'total_km' => [
                [2000, 100, 'Rodage', 'Parcourir un total cumulé de 2.000 km.'],
                [5000, 500, 'Vidange', 'Parcourir un total cumulé de 5.000 km.'],
                [10000, 1000, 'Visite technique', 'Parcourir un total cumulé de 10.000 km.'],
            ],
            'ride_on_oil' => [
                [5, 100, 'J\'ai glissé chef', 'Rouler sur 5 flaques d\'huile en une partie.'],
                [8, 500, 'Sport de glisse', 'Rouler sur 8 flaques d\'huile en une partie.'],
                [15, 1000, 'Passion pour le drift', 'Rouler sur 15 flaques d\'huile en une partie.'],
            ],
            'ride_on_heal' => [
                [2, 100, 'Assuré', 'Récupérer 2 bonus de réparation en une partie.'],
                [5, 500, 'Indemnisé', 'Récupérer 5 bonus de réparation en une partie.'],
                [8, 1000, 'Malussé', 'Récupérer 8 bonus de réparation en une partie.'],
            ],
            'risk_taker' => [
                [5, 250, 'Chauffard', 'Sortir 5 fois de la piste sans mourir dans une partie.'],
            ],
            'pilot' => [
                [10, 1000, 'Pilote', 'Parcourir 10 km sans une égratignure.'],
            ],
            'autobhan' => [
                [20, 2000, 'Autobahn', 'Rouler à plus de 230 km/h pendant au moins 20 secondes d’affilée sans sortir de la piste.'],
            ],
            'second_life' => [
                [1, 2000, 'Second life', 'Descendre à moins de 5 % de vie puis remonter au maximum.'],
            ],
        ],
        'interwheel' => [
            'total_elevation' => [
                [25000, 100, 'Apprenti grimpeur', 'Monter d\'une hauteur cumulée de 25.000 mètres.'],
                [150000, 500, 'Grimpeur expérimenté', 'Monter d\'une hauteur cumulée de 150.000 mètres.'],
                [1000000, 1000, 'Grimpeur légendaire', 'Monter d\'une hauteur cumulée de 1.000.000 mètres.'],
            ],
            'total_jumps' => [
                [2500, 100, 'Enjoué', 'Effectuer un total cumulé de 2.500 sauts.'],
                [10000, 500, 'Hyperactif', 'Effectuer un total cumulé de 10.000 sauts.'],
                [25000, 1000, 'Infatigable', 'Effectuer un total cumulé de 25.000 sauts.'],
            ],
            'total_dives' => [
                [5, 100, 'Baptème de plongée', 'Plonger un total cumulé de 5 fois dans l\'eau.'],
                [100, 500, 'N\'oublie pas les bouteilles', 'Plonger un total cumulé de 100 fois dans l\'eau.'],
                [500, 1000, 'Sous-marin', 'Plonger un total cumulé de 500 fois dans l\'eau.'],
            ],
            'elevation' => [
                [2500, 100, 'Mont-Blanc', 'Monter d\'une hauteur de 2.500 mètres en une seule ascension.'],
                [3500, 500, 'Kilimanjaro', 'Monter d\'une hauteur de 3.500 mètres en une seule ascension.'],
                [4500, 1000, 'Everest', 'Monter d\'une hauteur de 4.500 mètres en une seule ascension.'],
            ],
            'total_pastilles' => [
                [750, 100, 'Amateur', 'Collecter un total cumulé de 750 pastilles.'],
                [5000, 500, 'Collectionneur', 'Collecter un total cumulé de 5.000 pastilles.'],
                [15000, 1000, 'Aspirateur', 'Collecter un total cumulé de 15.000 pastilles.'],
            ],
            'total_dodged_enemies' => [
                [100, 100, 'Amis ?', 'Esquiver un total cumulé de 100 mines.'],
                [1000, 500, 'Ennemis...', 'Esquiver un total cumulé de 1.000 mines.'],
                [5000, 1000, 'Innofensifs !', 'Esquiver un total cumulé de 5.000 mines.'],
            ],
            'water_score' => [
                [1000, 250, 'Tout propre !', 'Passer dans l\'eau puis récupérer au moins 1.000 points.'],
            ],
            'max_fall_height' => [
                [500, 1000, 'Chute libre', 'Faire une chute ininterrompue de 500 mètres.'],
            ],
            'five_mine_wheel' => [
                [5, 1000, 'Salut la compagnie !', 'Atterrir sur une roue avec 5 mines et survivre.'],
            ],
            'bottom_wheel_elevation' => [
                [3500, 2000, 'Challenge accepted', 'Toucher la roue du bas puis monter à plus de 3.500 mètres.'],
            ],
        ],
        'ironchouquette' => [
            'kill_shield' => [
                [1, 250, 'Tous tes bonus ne m\'atteignent pas', 'Détruire un champ magnétique.'],
            ],
            'kill_total_blocks' => [
                [10, 100, 'Chatouilleur', 'Détruire 10 Blocks cumulés.'],
                [100, 500, 'Killer', 'Détruire 100 Blocks cumulés.'],
                [500, 1000, 'Destroyer', 'Détruire 500 Blocks cumulés.'],
            ],
            'kill_storms' => [
                [5, 100, 'Rookie', 'Détruire 5 Storms en une seule partie.'],
                [10, 500, 'Pilote', 'Détruire 10 Storms en une seule partie.'],
                [15, 1000, 'Élite', 'Détruire 15 Storms en une seule partie.'],
            ],
            'sacrifices' => [
                [2, 100, 'Question de survie', 'Sacrifier 2 bonus en une seule partie.'],
                [4, 500, 'Question de maladresse', 'Sacrifier 4 bonus en une seule partie.'],
                [6, 1000, 'Question de principes', 'Sacrifier 6 bonus en une seule partie.'],
            ],
            'five_empty_slots' => [
                [5, 1000, 'Chargeurs vides', 'Avoir 5 emplacements de bonus mais aucun bonus.'],
            ],
            'same_bonus' => [
                [3, 2000, 'Pourvu que ça soit pas du rose...', 'Avoir 3 bonus de la même couleur en même temps.'],
            ],
            'six_bonuses' => [
                [6, 2000, 'Rainbow Color x15 !', 'Avoir 6 bonus différents dans une partie.'],
            ],
            'surgromphs_killed' => [
                [1, 100, 'Un Surgromph de moins', 'Détruire 1 Surgromph en une seule partie.'],
                [3, 500, 'Surgromph killer', 'Détruire 3 Surgromphs en une seule partie.'],
                [5, 1000, 'Les Surgromphs s\'écartent de mon chemin!', 'Détruire 5 Surgromphs en une seule partie.'],
            ],
            'cutty_closed_killed' => [
                [1, 100, 'Cutty vite parti', 'Détruire 1 Cutty avant qu\'il ne s\'ouvre en une seule partie.'],
                [3, 500, 'Cutty cutter', 'Détruire 3 Cuttys avant qu\'ils ne s\'ouvrent en une seule partie.'],
                [10, 1000, 'Un Cutty? Kézako?', 'Détruire 10 Cuttys avant qu\'ils ne s\'ouvrent en une seule partie.'],
            ],
            'pink_bonus_kills' => [
                [20, 1000, 'C\'est pas si mal finalement', 'Détruire 20 ennemis avec le bonus rose dans une seule partie.'],
            ],
            'black_hole_projectiles' => [
                [100, 1000, 'Ménage de printemps', 'Aspirer 100 projectiles avec un seul trou noir.'],
            ],
            'lapinvincibles_wave' => [
                [1, 2000, 'Ça existe ??', 'Passer la vague des lapinvincibles.'],
            ],
            'max_enemy_shots' => [
                [100, 2000, 'J\'y vois plus rien!', 'Avoir au moins 100 projectiles ennemis à l\'écran.'],
            ],
        ],
        'kanji' => [
            'gather_bonus' => [
                [1000, 100, 'Ceuilleur', 'Récupérer un total cumulé de 1.000 bonus.'],
                [5000, 500, 'Glaneur', 'Récupérer un total cumulé de 5.000 bonus.'],
                [15000, 1000, 'Collectionneur', 'Récupérer un total cumulé de 15.000 bonus.'],
            ],
            'kill_storks' => [
                [500, 100, 'Je déteste la faune', 'Rebondir un total cumulé de 500 fois sur des cigognes.'],
                [2500, 500, 'À mort les zozios !', 'Rebondir un total cumulé de 2.500 fois sur des cigognes.'],
                [5000, 1000, 'Hécatombe aviaire', 'Rebondir un total cumulé de 5.000 fois sur des cigognes.'],
            ],
            'wall_jumps' => [
                [50, 100, 'Boing', 'Rebondir un total cumulé de 50 fois sur les murs.'],
                [250, 500, 'Solides ces murs !', 'Rebondir un total cumulé de 250 fois sur les murs.'],
                [750, 1000, 'Platrier de père en fils', 'Rebondir un total cumulé de 750 fois sur les murs.'],
            ],
            'avoid_boars' => [
                [10, 100, 'Ça sent le cochon non ?', 'Éviter un total cumulé de 10 marcassins.'],
                [100, 500, 'On n\'a pas gardé les cochons ensemble', 'Éviter un total cumulé de 100 marcassins.'],
                [1000, 1000, 'Maître de la harde', 'Éviter un total cumulé de 1.000 marcassins.'],
            ],
            'avoid_boars_short' => [
                [1, 100, 'Pas folle la guêpe', 'Esquiver 1 marcassin avec des mini-sauts en une partie.'],
                [4, 500, 'Allez salto !', 'Esquiver 4 marcassins avec des mini-sauts en une partie.'],
                [8, 1000, 'Ninja 8ème dan', 'Esquiver 8 marcassins avec des mini-sauts en une partie.'],
            ],
            'kill_streak' => [
                [5, 100, 'Floor is lava', 'Rebondir sur 5 cigognes sans toucher le sol.'],
                [15, 500, 'Expert de la voltige', 'Rebondir sur 15 cigognes sans toucher le sol.'],
                [25, 1000, 'Pilote de la patrouille de France', 'Rebondir sur 25 cigognes sans toucher le sol.'],
            ],
            'no_stork_kill_score' => [
                [15000, 100, 'Amoureux de la faune', 'Atteindre 15.000 points sans tuer de cigognes.'],
                [25000, 500, 'peace and love', 'Atteindre 25.000 points sans tuer de cigognes.'],
                [35000, 1000, 'Vegan', 'Atteindre 35.000 points sans tuer de cigognes.'],
            ],
            'bonus_streak' => [
                [5, 250, 'Regarde comme je saute bien', 'Récupérer 5 bonus en un saut sans rebondir sur des cigognes.'],
            ],
            'last_kill_count' => [
                [15, 1000, 'Allez on arrête de spawn là', 'Tuer la dernière cigogne en vie 15 fois dans la même partie.'],
            ],
            'fly_streak' => [
                [25, 2000, 'I believe I can fly', 'Rester 25 secondes en l\'air.'],
            ],
        ],
        'kanjisnightmare' => [
            'total_blue_turtles_killed' => [
                [25, 100, 'Ninja vs Tortues', 'Tuer un total cumulé de 25 tortues bleues.'],
                [100, 500, 'Extinction bleue', 'Tuer un total cumulé de 100 tortues bleues.'],
                [250, 1000, 'Némésis bleue', 'Tuer un total cumulé de 250 tortues bleues.'],
            ],
            'turtles_killed' => [
                [50, 100, 'Tortue luth', 'Tuer 50 tortues en une seule partie.'],
                [100, 500, 'Tortue ninja', 'Tuer 100 tortues en une seule partie.'],
                [150, 1000, 'Tortueur', 'Tuer 150 tortues en une seule partie.'],
            ],
            'get_hooks' => [
                [4, 100, 'Bonus hepta-cool !', 'Obtenir 7 grapins permanents en une seule partie.'],
                [5, 500, 'Méthode octo-turbo', 'Obtenir 8 grapins permanents en une seule partie.'],
            ],
            'repair_broken_armor' => [
                [1, 250, 'Lessive terminée !', 'Réparer une armure cassée.'],
            ],
            'get_three_permanent_opts' => [
                [3, 1000, 'Opération triforce', 'Obtenir 3 bonus permanents en même temps.'],
            ],
            'get_all_permanent_opts' => [
                [5, 2000, 'Équipement militaire', 'Obtenir tous les bonus permanents en même temps.'],
            ],
            'total_graphins_used' => [
                [500, 100, 'Niveau ouistiti', 'Utiliser le grapin 500 fois.'],
                [10000, 500, 'Niveau gibbon', 'Utiliser le grapin 10.000 fois.'],
                [25000, 1000, 'Niveau orang-outan', 'Utiliser le grapin 25.000 fois.'],
            ],
        ],
        'kaskade2' => [
            'total_blocks' => [
                [3000, 100, 'Cliqueur', 'Détruire un total cumulé de 3.000 blocs.'],
                [30000, 500, 'Cogneur', 'Détruire un total cumulé de 30.000 blocs.'],
                [250000, 1000, 'Kasseur', 'Détruire un total cumulé de 250.000 blocs.'],
            ],
            'mini_score' => [
                [1, 2000, 'Premier ! De la fin...', 'Faire un score de 2.000.'],
            ],
            'destroy_fifty_blocks' => [
                [50, 250, 'Boom !', 'Détruire 50 blocs en un seul coup.'],
            ],
            'same_color_clicks' => [
                [8, 100, 'C\'est une stratégie', 'Cliquer 8 fois de suite sur la même couleur.'],
                [10, 500, 'C\'est une erreur', 'Cliquer 10 fois de suite sur la même couleur.'],
                [12, 1000, 'C\'est un têtu', 'Cliquer 12 fois de suite sur la même couleur.'],
            ],
            'same_cell_clicks' => [
                [3, 250, 'Il existe d\'autres cases', 'Cliquer trois fois de suite sur la même case.'],
            ],
            'rgb' => [
                [1, 1000, 'RGB', 'Atteindre un score de 160.000 en alternant toujours Rouge, Vert, Bleu, Rouge, Vert, Bleu...'],
            ],
            'bicolor' => [
                [1, 2000, 'Bicolor', 'Atteindre un score de 200.000 en utilisant seulement 2 couleurs.'],
            ],
        ],
        'killbulle' => [
            'total_bubbles_popped' => [
                [1500, 100, 'Fragmenteur', 'Éclater 1.500 bulles.'],
                [20000, 500, 'Légende du Pop', 'Éclater 20.000 bulles.'],
                [100000, 1000, 'Maitre de la division', 'Éclater 100.000 bulles.'],
            ],
            'total_ying_yangs' => [
                [20, 100, 'Calme', 'Récupérer 20 bonus ying-yang.'],
                [100, 500, 'Tranquille', 'Récupérer 100 bonus ying-yang.'],
                [500, 1000, 'Zen', 'Récupérer 500 bonus ying-yang.'],
            ],
            'total_time_bonuses' => [
                [20, 100, 'Fan de sieste', 'Utiliser 20 bonus horloge.'],
                [100, 500, 'Maître du tempo', 'Utiliser 100 bonus horloge.'],
                [500, 1000, 'Seigneur du temps', 'Utiliser 500 bonus horloge.'],
            ],
            'big_bubbles' => [
                [1, 100, 'Eclateur de baudruche', 'Éclater 1 grosse bulle en une seule partie.'],
                [3, 500, 'Dézingueur de montgolfières', 'Éclater 3 grosses bulles en une seule partie.'],
                [5, 1000, 'Massacreur de zeppelins', 'Éclater 5 grosses bulles en une seule partie.'],
            ],
            'ten_with_kunai' => [
                [10, 250, 'Boucher', 'Éclater 10 bulles avec un seul bonus de kunais.'],
            ],
            'ten_with_shuriken' => [
                [10, 1000, 'Ninja', 'Éclater 10 bulles avec un seul bonus shuriken.'],
            ],
            'ten_with_time_bonus' => [
                [10, 2000, 'Le temps est une bulle', 'Éclater 10 bulles pendant un seul bonus de temps.'],
            ],
        ],
        'kslash' => [
            'voodoo' => [
                [1, 1000, 'Voyage initiatique', 'Récolter une poupée vaudou.'],
            ],
            'kill_tankers' => [
                [10, 100, 'Guerrier', 'Tuer un total cumulé de 10 Tankers.'],
                [50, 500, 'Maître', 'Tuer un total cumulé de 50 Tankers.'],
                [1000, 1000, 'Ninja', 'Tuer un total cumulé de 1.000 Tankers.'],
            ],
            'soft_kill_turtles' => [
                [50, 100, 'Ça va pas la tête ?!', 'Tuer un total cumulé de 50 Tortues en leur sautant dessus.'],
                [250, 500, 'Assomeur de tortues', 'Tuer un total cumulé de 250 Tortues en leur sautant dessus.'],
                [750, 1000, 'Plombier moustachu', 'Tuer un total cumulé de 750 Tortues en leur sautant dessus.'],
            ],
            'soft_kill_bats' => [
                [5, 100, 'Bat-paf', 'Tuer un total cumulé de 5 Chauve-souris en leur sautant dessus.'],
                [20, 500, 'Bat-crêpe', 'Tuer un total cumulé de 20 Chauve-souris en leur sautant dessus.'],
                [50, 1000, 'Batman n\'a qu\'à bien se tenir', 'Tuer un total cumulé de 50 Chauve-souris en leur sautant dessus.'],
            ],
            'soft_kill_tankers' => [
                [5, 100, 'Pied de nez', 'Tuer un total cumulé de 5 Tankers en leur sautant dessus.'],
                [25, 500, 'Piétineur', 'Tuer un total cumulé de 25 Tankers en leur sautant dessus.'],
                [150, 1000, 'Coup de pied latéral en pleine face', 'Tuer un total cumulé de 150 Tankers en leur sautant dessus.'],
            ],
            'super_star_kills' => [
                [50, 100, 'Plus invincible que le slip de Superman', 'Tuer un total cumulé de 50 monstres avec le bonus étoile.'],
                [150, 500, 'Plus invincible que Benoît Brisefer sous antihistaminiques', 'Tuer un total cumulé de 150 monstres avec le bonus étoile.'],
                [500, 1000, 'Plus invincible qu\'Achille cul-de-jatte', 'Tuer un total cumulé de 500 monstres avec le bonus étoile.'],
            ],
            'no_shuriken_score' => [
                [5000, 100, 'Peace & Slash', 'Atteindre un score de 5.000 sans utiliser de shurikens.'],
                [12000, 500, 'Maître d\'armes', 'Atteindre un score de 12.000 sans utiliser de shurikens.'],
                [20000, 1000, 'La voie du sabre', 'Atteindre un score de 20.000 sans utiliser de shurikens.'],
            ],
            'shuriken_stock' => [
                [200, 250, 'Réserves', 'Atteindre 200 shurikens en stock.'],
            ],
            'all_bonuses' => [
                [7, 1000, 'Je suis increvab...', 'Obtenir les 3 bonus en même temps.'],
            ],
            'diversity' => [
                [1, 1000, 'Diversité', 'Tuer un monstre de chaque type en une partie.'],
            ],
            'three_respawns' => [
                [3, 2000, 'Plus fort que la mort', 'Réapparaître 3 fois dans une partie.'],
            ],
        ],
        'magmax' => [
            'turrets_killed' => [
                [10, 100, 'Démontage de tourelle', 'Tuer 10 tourelles.'],
                [100, 500, 'Poussière de tourelle', 'Tuer 100 tourelles.'],
                [1000, 1000, 'Syndrome de la Tourelle', 'Tuer 1.000 tourelles.'],
            ],
            'gems_collected' => [
                [100, 100, 'Premier collier', 'Obtenir 100 boules de couleur.'],
                [1000, 500, 'Chasseur de perles', 'Obtenir 1.000 boules de couleur.'],
                [10000, 1000, 'Parure légendaire', 'Obtenir 10.000 boules de couleur.'],
            ],
            'flowers_one_game' => [
                [5, 100, 'Désherbage express', 'Tuer 5 fleurs en une seule partie.'],
                [10, 500, 'Le beau bouquet', 'Tuer 10 fleurs en une seule partie.'],
                [15, 1000, 'Fléau des Pétales', 'Tuer 15 fleurs en une seule partie.'],
            ],
            'magmax' => [
                [1, 250, 'Maximaxeur', 'Faire un Magmax.'],
            ],
            'both_bonuses' => [
                [1, 1000, 'Armé jusqu\'aux dents', 'Obtenir les 2 bonus spéciaux en même temps.'],
            ],
            'kill_order' => [
                [1, 2000, 'Tri séquentiel', 'Tuer dans l\'ordre goutte, fleur et tourelle dans un même combo.'],
            ],
        ],
        'opalus2' => [
            'mini_score' => [
                [1, 2000, 'Minimaliste', 'Faire un score de 6.750.'],
            ],
            'total_fallen_bubbles' => [
                [100, 100, 'Dégringolade', 'Faire tomber un total cumulé de 100 billes.'],
                [1000, 500, 'Effondrement', 'Faire tomber un total cumulé de 1.000 billes.'],
                [10000, 1000, 'Avalanche', 'Faire tomber un total cumulé de 10.000 billes.'],
            ],
            'destroyed_bubbles' => [
                [1000, 100, 'Eclateur de billes', 'Détruire un total cumulé de 1.000 billes.'],
                [10000, 500, 'Destructeur de balles', 'Détruire un total cumulé de 10.000 billes.'],
                [25000, 1000, 'Anihilateur d\'exosphères', 'Détruire un total cumulé de 25.000 billes.'],
            ],
            'same_color_destroyed_bubbles' => [
                [15, 100, 'Éclatement', 'Détruire 15 billes d\'une couleur en un seul coup.'],
                [21, 500, 'Massacre', 'Détruire 21 billes d\'une couleur en un seul coup.'],
                [27, 1000, 'Strike monochrome', 'Détruire 27 billes d\'une couleur en un seul coup.'],
            ],
            'no_fallen_bubbles' => [
                [1, 250, 'Solide sur les appuis', 'Finir une partie sans une seule bille tombée.'],
            ],
            'fallen_bubbles' => [
                [15, 1000, 'Chute dans le peloton', 'Faire tomber 15 billes d\'un coup.'],
            ],
            'magellan' => [
                [1, 2000, 'Magellan', 'Atteindre les 4 bords du plateau dans une seule partie.'],
            ],
            'color_blindness' => [
                [1, 2000, 'Daltonisme', 'Finir une partie en ne cliquant que sur des billes de 2 couleurs différentes.'],
            ],
            'rainbow' => [
                [7, 2000, 'Arc-en-ciel', 'Faire tomber une bille de chaque couleur en un seul coup.'],
            ],
        ],
        'pioupiou' => [
            'total_bubbles' => [
                [1000, 100, 'Bulleur', 'Récupérer un total cumulé de 1.000 bulles.'],
                [10000, 500, 'Bulle popper', 'Récupérer un total cumulé de 10.000 bulles.'],
                [25000, 1000, 'Bulle doseur', 'Récupérer un total cumulé de 25.000 bulles.'],
            ],
            'total_elevation' => [
                [500, 100, 'Tropopiou', 'Grimper un total cumulé de 500m.'],
                [3000, 500, 'Stratopiou', 'Grimper un total cumulé de 3.000m.'],
                [10000, 1000, 'Exopiou', 'Grimper un total cumulé de 10.000m.'],
            ],
            'elevation' => [
                [30, 100, 'Combo ascendant', 'Atteindre 30m en une partie.'],
                [50, 500, 'Sky Piouker', 'Atteindre 50m en une partie.'],
                [70, 1000, 'Piou Infinity', 'Atteindre 70m en une partie.'],
            ],
            'no_bubble' => [
                [15, 100, 'Pas d\'bul', 'Atteindre 15m sans récolter de points.'],
                [30, 500, 'L\'esquiveur', 'Atteindre 30m sans récolter de points.'],
                [40, 1000, 'L\'invisible', 'Atteindre 40m sans récolter de points.'],
            ],
            'falling_bubbles' => [
                [30, 250, 'Réceptionneur', 'Récupérer 30 bonus avant qu\'ils ne touchent le sol dans une partie.'],
            ],
            'pink_bubble_popped' => [
                [1, 1000, 'Je n\'ai rien pu faire', 'Laisser une bulle rose se faire écraser.'],
            ],
            'climb_height' => [
                [5, 2000, 'Déblocage vertical', 'Monter de 5 cases d\'un coup.'],
            ],
        ],
        'popcorn' => [
            'total_buble_destroyed' => [
                [1500, 100, 'Ventre vide', 'Manger un total de 1.500 grains.'],
                [7500, 500, 'Petit creux', 'Manger un total de 7.500 grains.'],
                [20000, 1000, 'Rassasié', 'Manger un total de 20.000 grains.'],
            ],
            'total_damage_dealt' => [
                [50, 100, 'Recrue', 'Enlever 50 vies au boss Pokepi.'],
                [300, 500, 'Combattant', 'Enlever 300 vies au boss Pokepi.'],
                [700, 1000, 'Assassin', 'Enlever 700 vies au boss Pokepi.'],
            ],
            'total_killed_times' => [
                [1, 100, 'Maman, j\'ai réussi', 'Tuer Pokepi 1 fois.'],
                [25, 500, 'Pokedead', 'Tuer Pokepi 25 fois.'],
                [75, 1000, 'Pioukepi', 'Tuer Pokepi 75 fois.'],
            ],
            'buble_destroyed_in_a_row' => [
                [30, 100, 'Gourmet', 'Manger 30 grains à suivre sans toucher le sol.'],
                [50, 500, 'Gourmand', 'Manger 50 grains à suivre sans toucher le sol.'],
                [70, 1000, 'Glouton', 'Manger 70 grains à suivre sans toucher le sol.'],
            ],
            'combo_500_pts' => [
                [500, 250, 'Sniper', 'Atteindre un combo de 500 points.'],
            ],
            'three_times_outbounds' => [
                [3, 1000, 'T\'es sûr qu\'il y a rien là haut ?', 'Passer tout en haut du monde 3 fois dans une même partie.'],
            ],
            'fastkill_pokepi' => [
                [1, 2000, 'Ça, c\'est fait.', 'Tuer Pokepi en moins de 1 minute.'],
            ],
            'perfect_kill' => [
                [1, 2000, 'Vivacité', 'Tuer Pokepi sans qu\'aucun grain n\'ait éclaté au sol.'],
            ],
        ],
        'starfang' => [
            'total_levels_finished' => [
                [50, 100, 'Voyons ce qu\'il y a par là', 'Terminer 50 niveaux.'],
                [500, 500, 'Explorateur spatial', 'Terminer 500 niveaux.'],
                [1500, 1000, 'Vers l\'infini et au-delà', 'Terminer 1.500 niveaux.'],
            ],
            'total_purple_asteroids_destroyed' => [
                [10, 100, 'Apprenti du mauve', 'Détruire 10 astéroïdes violets.'],
                [75, 500, 'Expert de l\'ultra violet', 'Détruire 75 astéroïdes violets.'],
                [250, 1000, 'Maître de l\'octarine', 'Détruire 250 astéroïdes violets.'],
            ],
            'no_main_weapon_levels' => [
                [1, 100, 'À une main', 'Terminer 1 niveau sans tirer avec l\'arme principale dans une seule partie.'],
                [3, 500, 'À un doigt', 'Terminer 3 niveaux sans tirer avec l\'arme principale dans une seule partie.'],
                [5, 1000, 'Sans les mains', 'Terminer 5 niveaux sans tirer avec l\'arme principale dans une seule partie.'],
            ],
            'fast_level' => [
                [1, 100, 'Rapide l\'ami', 'Finir un niveau en moins de 35 secondes après le niveau 6.'],
                [2, 500, 'Vitesse supersonique', 'Finir un niveau en moins de 25 secondes après le niveau 6.'],
                [3, 1000, 'Célérité supraluminique', 'Finir un niveau en moins de 15 secondes après le niveau 6.'],
            ],
            'laser_overkill' => [
                [1, 250, 'Overkill', 'Détruire un astéroïde en terre avec un laser.'],
            ],
            'all_weapon_upgrades' => [
                [1, 1000, 'Indécis', 'Obtenir une amélioration d\'arme de chaque type dans une seule partie.'],
            ],
            'same_weapon_upgrades' => [
                [5, 2000, 'Puissant', 'Obtenir 5 améliorations d\'armes identiques dans une seule partie.'],
            ],
        ],
        'synapses' => [
            'total_neurons_connected' => [
                [2500, 100, 'Psychologue', 'Connecter un total de 2.500 neurones.'],
                [10000, 500, 'Psychiatre', 'Connecter un total de 10.000 neurones.'],
                [100000, 1000, 'Neurochirurgien', 'Connecter un total de 100.000 neurones.'],
            ],
            'level_one_score' => [
                [25000, 100, 'Je valide', 'Atteindre un score de 25.000 au niveau 1.'],
                [30000, 500, 'C\'est OK', 'Atteindre un score de 30.000 au niveau 1.'],
                [35000, 1000, 'C\'est nickel', 'Atteindre un score de 35.000 au niveau 1.'],
            ],
            'neuron_score' => [
                [500, 100, 'Bon sens', 'Atteindre un neurone à 500 points.'],
                [600, 500, 'Lucidité', 'Atteindre un neurone à 600 points.'],
                [700, 1000, 'Clairvoyance', 'Atteindre un neurone à 700 points.'],
            ],
            'afk' => [
                [1, 250, 'AFK', 'Gagner un niveau sans cliquer.'],
            ],
            'champion' => [
                [40, 1000, 'Champion', 'Gagner contre 4 adversaires en même temps avec au moins 40 neurones connectés.'],
            ],
            'tie_win' => [
                [1, 1000, 'Arbitre partial', 'Gagner sur une égalité.'],
            ],
            'crushing_victory' => [
                [75, 2000, 'Victoire écrasante', 'À partir du niveau 3, gagner avec au moins 75 neurones connectés.'],
            ],
        ],
        'tiananman' => [
            'followers_collected' => [
                [500, 100, 'Viendez les zamis', 'Récupérer 500 manifestants.'],
                [5000, 500, 'On est fâchés tout rouge', 'Récupérer 5.000 manifestants.'],
                [20000, 1000, 'Plus on est de fous moins il y a de riz', 'Récupérer 20.000 manifestants.'],
            ],
            'vehicles_destroyed' => [
                [50, 100, 'Accident de la route', 'Détruire 50 véhicules.'],
                [500, 500, 'Cascadeur', 'Détruire 500 véhicules.'],
                [2000, 1000, 'Épaviste', 'Détruire 2.000 véhicules.'],
            ],
            'fevers' => [
                [1, 100, 'Dénonceur', 'Passer en mode frénésie 1 fois en une seule partie.'],
                [2, 500, 'Proclameur', 'Passer en mode frénésie 2 fois en une seule partie.'],
                [3, 1000, 'Contestataire', 'Passer en mode frénésie 3 fois en une seule partie.'],
            ],
            'vehicle_diversity' => [
                [5, 250, 'Collectionneur de carcasses', 'Détruire 1 véhicule de chaque type en une partie avec la frénésie.'],
            ],
            'no_follower_lost_fever' => [
                [1, 1000, 'Pro de la savonnette', 'Passer en mode frénésie sans avoir perdu un seul manifestant.'],
            ],
            'last_follower_score' => [
                [100000, 2000, 'Survivant', 'Gagner 100.000 points en n\'ayant plus qu\'un seul point de vie.'],
            ],
        ],
        'tubulo' => [
            'level_resets' => [
                [25, 100, 'On recommence', 'Redémarrer 25 niveaux.'],
                [150, 500, 'Mauvaise pioche', 'Redémarrer 150 niveaux.'],
                [500, 1000, 'Le réinitialiseur', 'Redémarrer 500 niveaux.'],
            ],
            'green_paint' => [
                [1000, 100, 'Peintre écolo', 'Colorer 1.000 tubes en vert.'],
                [10000, 500, 'Greenwashing', 'Colorer 10.000 tubes en vert.'],
                [100000, 1000, 'Vert l\'infini et l\'eau verdâtre', 'Colorer 100.000 tubes en vert.'],
            ],
            'reach_level' => [
                [8, 100, 'Octo-huitre', 'Atteindre le niveau 8.'],
                [10, 500, 'Déca-bulot', 'Atteindre le niveau 10.'],
                [12, 1000, 'Dodéca-moule', 'Atteindre le niveau 12.'],
            ],
            'min_score' => [
                [1, 250, 'T\'as bu l\'eau', 'Finir la partie avec 200 points.'],
            ],
            'level_9_chrono_max' => [
                [1, 1000, 'Neuf comme un sou', 'Atteindre le niveau 9 en ayant le chronomètre rempli au max.'],
            ],
            'level_10_without_retry' => [
                [1, 2000, 'Dix de der', 'Atteindre le niveau 10 sans avoir redémarré de niveau.'],
            ],
        ],
        'travoltax' => [
            'destroy_lines' => [
                [2000, 100, 'Paragraphe 2000', 'Détruire un total cumulé de 2.000 lignes.'],
                [10000, 500, 'Alinéa 10.000', 'Détruire un total cumulé de 10.000 lignes.'],
                [25000, 1000, 'Ligne 25.000', 'Détruire un total cumulé de 25.000 lignes.'],
            ],
            'use_calm' => [
                [1, 100, 'Souffle un coup', 'Utiliser 1 bonus "calme".'],
                [20, 500, 'Calme raplapla', 'Utiliser un total cumulé de 20 bonus "calme".'],
                [40, 1000, 'Zénitude attitude', 'Utiliser un total cumulé de 40 bonus "calme".'],
            ],
            'use_psycho' => [
                [1, 100, 'Upside down', 'Utiliser 1 bonus "psycho" en une seule partie.'],
                [3, 500, 'Fou furieux', 'Utiliser 3 bonus "psycho" en une seule partie.'],
                [5, 1000, 'The Joker', 'Utiliser 5 bonus "psycho" en une seule partie.'],
            ],
            'destroy_ten_lines' => [
                [10, 2000, 'Décimation linéaire', 'Détruire 10 lignes d\'un coup.'],
            ],
            'clear_grid' => [
                [1, 250, 'Total reset', 'Vider entièrement la grille.'],
            ],
            'cold_sweats' => [
                [30, 1000, 'Sueurs froides', 'Survivre 30 secondes alors qu\'il y a des pièces jusqu\'au plafond.'],
            ],
            'mafia' => [
                [1, 2000, 'Mafieux', 'Réussir un contrat à 8.000 points minimum.'],
            ],
        ],
        'xianxiang' => [
            'total_tiles' => [
                [500, 100, 'Premier nettoyage', 'Détruire 500 tuiles.'],
                [2000, 500, 'Nettoyeur de plateau', 'Détruire 2.000 tuiles.'],
                [10000, 1000, 'Apocalypse de tuiles', 'Détruire 10.000 tuiles.'],
            ],
            'perfect_neighbours' => [
                [20, 100, 'Voisins proches', 'Rassembler 20 paires parfaites côte à côte.'],
                [100, 500, 'Collé-serré', 'Rassembler 100 paires parfaites côte à côte.'],
                [400, 1000, 'Comité de jumelage', 'Rassembler 400 paires parfaites côte à côte.'],
            ],
            'perfect_pairs' => [
                [10, 100, 'Déca-jonction', 'Rassembler 10 paires parfaites en une seule partie.'],
                [12, 500, 'Dodéca-appairage', 'Rassembler 12 paires parfaites en une seule partie.'],
                [14, 1000, 'Tetrakaideca-paires', 'Rassembler 14 paires parfaites en une seule partie.'],
            ],
            'no_one_point_pair' => [
                [1, 250, 'Oh, un chiffre rond', 'Finir une partie sans paire à 1 point.'],
            ],
            'min_score' => [
                [1, 1000, 'Premier (en partant de la fin)', 'Faire un score de 21.'],
            ],
            'perfect_colors' => [
                [2, 2000, 'Il y en aura pour tout le monde', 'Effectuer au moins 2 paires parfaites de chaque couleur en 1 seule partie.'],
            ],
        ],
        'zipzap' => [
            'total_pops' => [
                [1000, 100, 'Eclate ballons', 'Eclater un total cumulé de 1.000 ballons.'],
                [7500, 500, 'Anti-hélium', 'Eclater un total cumulé de 7.500 ballons.'],
                [25000, 1000, 'Terreur des baudruches', 'Eclater un total cumulé de 25.000 ballons.'],
            ],
            'mini_score' => [
                [100, 1000, '10.000 tout rond !', 'Finir une partie avec 0 combos.'],
            ],
            'black_balloons_popped' => [
                [1, 100, 'Adorateur de la mort', 'Éclater 1 ballon noir.'],
                [10, 500, 'Bonjour ténèbres', 'Éclater 10 ballons noirs.'],
                [25, 1000, 'Noir c\'est noir', 'Éclater 25 ballons noirs.'],
            ],
            'fast_finish' => [
                [1, 1000, 'J\'ai pas compris le jeu', 'Finir une partie en moins de 23 coups.'],
            ],
            'empty_shots' => [
                [10, 100, 'Il faut viser les ballons ?', 'Faire 10 coups dans le vide.'],
                [100, 500, 'Oups j\'ai glissé', 'Faire 100 coups dans le vide.'],
                [1000, 1000, 'Rahhh, mais pourquoi ça bouge aussi !', 'Faire 1.000 coups dans le vide.'],
            ],
            'five_thousand_combo' => [
                [1, 100, 'Combo !', 'Obtenir 1 ballon à 5.000 points en un coup.'],
                [2, 500, 'Le doublet !', 'Obtenir 2 ballons à 5.000 points en un coup.'],
                [3, 1000, 'Brochette de points', 'Obtenir 3 ballons à 5.000 points en un coup.'],
            ],
            'risk_lover' => [
                [1, 2000, 'J\'aime le risque', 'Finir une partie sans mourir alors qu\'il y a au moins 3 ballons noirs lorsqu\'il reste au minimum 50 ballons à éclater.'],
            ],
        ],
    ];

    /**
     * Run the database seeds. Can be run again at any time: an achievement (its key) or a level (its number) already
     * there is updated, so the progress of the players stays; what is removed from here stays in the database.
     */
    public function run(): void
    {
        $games = Game::all()->keyBy('game_key');

        foreach (self::ACHIEVEMENTS as $gameKey => $achievements) {
            $game = $games->get($gameKey);
            if (!$game) {
                continue;
            }

            foreach ($achievements as $key => $levels) {
                $this->achievement($game, $key, array_map(fn (array $level) => array_combine(['target', 'reward', 'title', 'description'], $level), $levels));
            }
        }

        // the ones of every game: its stars, and its Paradise league
        foreach ($games as $game) {
            $this->achievement($game, 'stars', [
                ['target' => 1, 'reward' => 0, 'title' => 'Étoile verte '.$game->name, 'description' => 'Obtenir l\'étoile verte sur '.$game->name.'.'],
                ['target' => 2, 'reward' => 0, 'title' => 'Étoile orange '.$game->name, 'description' => 'Obtenir l\'étoile orange sur '.$game->name.'.'],
                ['target' => 3, 'reward' => 0, 'title' => 'Étoile rouge '.$game->name, 'description' => 'Obtenir l\'étoile rouge sur '.$game->name.'.'],
            ]);
            $this->achievement($game, 'paradise_league', [
                ['target' => 1, 'reward' => 0, 'title' => 'Ligue Paradis', 'description' => 'Atteindre la ligue Paradis à '.$game->name.'.'],
            ]);
        }
    }

    /**
     * @param  list<array{target: int, reward: int, title: string, description: string}>  $levels
     */
    private function achievement(Game $game, string $key, array $levels): void
    {
        /** @var Achievement $achievement */
        $achievement = $game->achievements()->updateOrCreate(['key' => $key], ['category' => AchievementCategory::GAME, 'progress_scope' => AchievementProgressScope::LIFETIME]);
        foreach ($levels as $index => $level) {
            $achievement->levels()->updateOrCreate(['level' => $index + 1], $level);
        }
    }
}
