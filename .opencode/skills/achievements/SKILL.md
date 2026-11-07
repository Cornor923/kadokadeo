---
name: achievements
description: Expliquer et implementer les achievements d'un jeu KadoKadeo a partir des stats envoyees par le jeu et du Google Sheet du projet.
---

Tu travailles sur un projet Laravel + Haxe KadoKadeo.

## Objectif

Creer ou modifier les regles serveur d'achievements pour un jeu, puis ajouter les achievements correspondants dans le seeder.

Les sources Haxe des jeux sont dans `resources/hx/games/`.
Les rules serveur sont dans `app/Achievements/Rules/Games/`.
Les achievements seedes sont dans `database/seeders/AchievementsSeeder.php`.

## Entrees attendues

La liste des succes est dans le Google Sheet du projet, lisible sans connexion et en lecture seule: https://docs.google.com/spreadsheets/d/1L0VNwws3ZDsALiZrvNQ13Gc1rjZleYc9tUAGoPc5Avc/edit

- Premier onglet: legende et etat de chaque jeu.
- Un onglet par jeu, a son nom affiche: titres par niveau, description, seuils, recompenses, regles speciales.
- Lire un onglet en CSV (le nom encode dans l'URL, par exemple `Xian-Xiang`):

```sh
curl -sSL "https://docs.google.com/spreadsheets/d/1L0VNwws3ZDsALiZrvNQ13Gc1rjZleYc9tUAGoPc5Avc/gviz/tq?tqx=out:csv&sheet=<Nom%20du%20jeu>"
```

- Colonne `Developpe ?`: `to review` et `new` sont des idees pas encore validees, a confirmer avant de les creer.
- Les lignes `Etoile` et `Ligue Paradis` sont les succes communs, deja crees pour tous les jeux.

L'utilisateur peut aussi donner directement le jeu, les variables de stats et les validations attendues.

Si une information est ambigue, manquante ou contradictoire, demander confirmation avant d'implementer. Ne pas deviner une regle metier.

## Principes importants

- Chaque jeu envoie des stats en fin de partie; les achievements ne doivent faire confiance qu'aux stats validees cote serveur.
- La rule principale du jeu doit verifier uniquement les variables demandees par l'utilisateur.
- Ne pas recalculer le score ou la coherence complete de la partie sauf demande explicite: certains scores sont trop complexes a recalculer.
- Les rules specifiques d'achievement doivent suivre les conventions existantes du dossier du jeu.
- Dans les descriptions du seeder, formatter les grands nombres avec des points comme separateurs: `1.000`, `25.000`, `1.000.000`.
- Ne pas modifier les fichiers generes Haxe/JS pour les achievements serveur sauf si l'utilisateur demande explicitement d'ajouter de nouvelles stats cote jeu.

## Workflow recommande

1. Identifier le jeu

- Trouver le dossier Haxe: `resources/hx/games/<game>`.
- Trouver ou creer le dossier de rules: `app/Achievements/Rules/Games/<GameName>/`.
- Verifier le mapping `game_key` utilise dans `AchievementsSeeder.php` avec les exemples existants.

2. Analyser les rules existantes

- Lire la rule principale du jeu si elle existe, par exemple `KSlashRule.php`.
- Lire quelques rules specifiques du meme jeu pour respecter le style de validation et de calcul de progression.
- Lire une section proche dans `database/seeders/AchievementsSeeder.php` pour conserver le style du seeder.

3. Implementer ou modifier la rule principale

- La rule principale `<GameName>Rule` est abstraite, etend `App\Achievements\GameRule` et donne le jeu (`protected const GAME = '<game_key>';`): categorie, `supports` et garde viennent de `GameRule`.
- La fonction `validate` doit retourner `true` si les stats necessaires sont considerees valides, sinon `false`. `GameRule` l'appelle une fois par partie pour toutes les rules du jeu: une stat refusee ne fait progresser aucun succes du jeu.
- Recuperer les stats avec `data_get`, par exemple:

```php
$bads = data_get($event->stats, 'bads', []);
```

- Valider uniquement ce qui a ete specifie par l'utilisateur: types, bornes, valeurs autorisees, structure de tableaux, compteurs non negatifs, etc.
- Valider avec `App\Achievements\Stats` (`isCount`, `isCounts`, `isRows`, `isList`), pas avec `is_array` / `count`: un joueur peut envoyer n'importe quoi, et un objet de la bonne taille passe `count()` puis fait planter `$stats[0]`. `is_numeric` laisse passer des chaines et des flottants: les jeux envoient des entiers.
- Refuser les stats invalides ou inattendues quand elles concernent les variables utilisees par les achievements.
- Ne pas ajouter de validation speculative basee sur le score, la duree ou des mecanismes internes non demandes.

4. Creer les rules d'achievements

- Creer une classe par achievement dans `app/Achievements/Rules/Games/<GameName>/` si le repo suit deja ce modele pour le jeu.
- Nommer les classes selon les conventions existantes: `<GameName><AchievementName>Rule`.
- Chaque rule donne sa cle (`achievementKey()`) et sa progression (`protected function progress(GameRunCompleted $event, UserAchievementProgress $progress): AchievementRuleResult`), appelee seulement sur des stats validees: elle ne revalide pas.
- Utiliser les stats deja validees par la rule principale.
- Retourner la valeur/progression attendue selon les patterns existants du projet.
- Pour les achievements cumulatifs, suivre les exemples existants avec `AchievementProgressScope::LIFETIME` dans le seeder.
- Pour les achievements en une partie, suivre aussi les exemples existants: le scope reste souvent `LIFETIME`, mais la rule retourne une progression issue d'une seule run.
- Un nombre a atteindre en une partie (par exemple avoir 70 pierres) ne compte pas en oui/non: la progression suit la vraie valeur. Le `target` du seeder est le seuil (70, pas 1) et la rule garde le meilleur resultat: avec 59 pierres la progression passe a 59, et elle reste a 59 si la partie d'apres en donne 57.

```php
return $this->best($progress, data_get($event->stats, 'w'));
```

- Un seuil a ne pas depasser (10 bacteries ou moins) ne peut pas suivre sa valeur, puisque plus bas est mieux: il garde des paliers 1, 2, 3, comme `BacteryFewBacteriaRule`.

5. Ajouter les achievements au seeder

- Ajouter le jeu (son `game_key`) et ses succes dans la table `ACHIEVEMENTS` de `database/seeders/AchievementsSeeder.php`: un succes par cle, ses paliers dans l'ordre `[target, reward, title, description]`. Les succes communs (`stars`, `paradise_league`) sont crees pour tous les jeux par `run()`.

```php
'bactery' => [
    'total_stars' => [
        [10, 100, 'Admirateur d\'astres', 'Amasser un total de 10 étoiles.'],
        [100, 500, 'Collectionneur de constellations', 'Amasser un total de 100 étoiles.'],
    ],
],
```

- Le seeder se relance sur une base existante (bouton admin « Mettre à jour les succès », ou `php artisan db:seed --class=AchievementsSeeder --force`) : il ajoute ce qui manque et met à jour titres, descriptions, seuils et récompenses, sans toucher à la progression des joueurs. Il écrase donc ce qui a été modifié à la main dans l'admin : le seeder est la référence.
- Il ne supprime rien : un succès ou un palier retiré du seeder reste en base. Renommer une `key` crée un nouveau succès, la progression ne suit pas.
- Deux paliers d'un même succès ne peuvent pas avoir le même `target` (contrainte unique), même le temps d'un échange.

- Utiliser les titres, descriptions, targets et rewards du Sheet.
- Si une valeur du Sheet est illisible ou incertaine, demander confirmation.

## Ajouter des stats a un jeu

Quand un succes demande une stat que le jeu n'envoie pas encore, il faut modifier le jeu sans changer son comportement: un replay doit donner exactement le meme resultat.

- Regarder d'abord ce que le jeu envoie deja: l'argument de `KadoKadeoManager.kkm.gameOver(...)`, stocke dans `runs.score_details`. Il peut suffire.
- Prendre la reference des replays **avant** de toucher au jeu (voir ci-dessous).
- N'ajouter que des compteurs qui lisent l'etat du jeu: pas de `Seed.rand()` / `Seed.random()`, pas d'ecriture dans ce que la logique lit, aucun changement d'ordre des appels. Un champ de plus sur une classe reste sans effet sur les prototypes geles.
- Ne pas renommer ce que lit un analyseur de coups (`resources/js/replay-verifier/analyzers/<game_key>.mjs`).
- Envoyer un objet a cles courtes (`{c: ..., p: ..., n: ...}`). `validate` refuse l'ancien format: une partie lancee avec l'ancien bundle ne fait simplement pas progresser les succes.
- Valider dans la rule principale les invariants certains du jeu (nombre de paires, sommes coherentes), en les confirmant sur les vraies parties.
- Une stat « la premiere fois que » s'initialise a `-1` et se teste contre `-1`: `0` est une vraie valeur (un score de 0, le niveau 0). `no_bubble` et `no_shuriken_score` ont eu ce bug, et la rule traite `-1` comme « jamais ».

## Comparer les replays avant / apres

`php artisan kado:replays:compare` rejoue les parties d'un jeu avec le bundle de `public/gamesdata`, comme le verificateur de replays du serveur (Node 22 + Chrome, dans `kadokadeo_app`). Il ne modifie pas la base.

```sh
# compiler un seul jeu: `make compile-games` utilise compile-dev.hxml, qui n'a pas tous les jeux
docker exec -u dev kadokadeo_app haxe -L pixijs -L crypto -L jsImport -cp ./resources/hx/lib -cp ./resources/hx/games -js ./resources/js/games/<game>.js <game>.Game
docker exec -u node -e GAME_BUILDS=off -w /www kadokadeo_front yarn games:bundle

# 1. AVANT le changement: compiler le code actuel, puis enregistrer la reference
docker exec kadokadeo_app php artisan kado:replays:compare <game_key> --baseline

# 2. modifier le jeu, recompiler avec les deux commandes ci-dessus

# 3. APRES: rejouer les memes parties et comparer
docker exec kadokadeo_app php artisan kado:replays:compare <game_key>
```

- Options: `--limit=1000` (les parties les plus recentes, a l'etape 1), `--parallel=4`. Compter environ 3 s par replay et par processus pour un jeu court.
- `--baseline` dit combien de replays redonnent le score et les stats de la base. Un ecart a ce stade existe deja: une partie differente de la base reste comparee a elle-meme (les replays d'avant la v5 peuvent diverger sur une autre machine: faire les deux etapes sur la meme machine).
- Comparaison: un score, un nombre de frames ou une erreur differente fait echouer la commande (code de sortie 1, 20 parties montrees). Si des parties different, relancer sans rien changer pour distinguer un jeu qui ne rejoue pas de facon stable d'une vraie regression.
- Des stats differentes sont signalees sans echec: c'est le but quand on ajoute des stats. Regarder l'exemple affiche.
- « Le bundle est le meme »: le jeu n'a pas ete recompile, la comparaison ne prouve rien.
- Les resultats sont dans `storage/app/replay-compare/<game_key>.json` (reference) et `<game_key>.compare.json` (apres), avec les stats de chaque partie.

Le passage de cette commande ne prouve pas que les nouvelles stats sont justes. A faire en plus:

- Passer les stats de `<game_key>.compare.json` dans les rules du jeu (par exemple avec `tinker`): `validate` doit accepter 100 % des parties, sinon le succes ne progressera jamais et rien ne le signalera.
- Si une stat existait deja (`score_details`), la comparer a l'ancienne valeur.
- Recalculer une nouvelle stat d'une autre facon que le compteur, par exemple en observant le plateau a chaque frame sur l'ancien build.
- Tester au moins une vraie partie sur le site local jusqu'a la fin: stats recues par le serveur, progression des succes, `ac` a 0, `is_cheat` faux, et replay de cette partie.

## Parties qui ne comptent plus

Les parties comptees sont dans `achievement_events`. `AchievementService::takeBackRun` les rejoue avec et sans la partie retiree et ne reprend que la difference, paliers et recompenses compris: une rule doit donc pouvoir etre rejouee depuis zero, avec `evaluate` et ses seules stats (rien d'autre dans `$progress` que `current_value` et `state`).

- `RunService::flagAsCheat` et `ModerationService::deleteRun` reprennent, `restoreRun` recompte. `deleteScores` (ban) garde, comme les points de contrat.
- `VerifyRunReplay` compare ce que les rules tirent des stats envoyees et de celles du replay (pas les stats brutes: Tubulo envoie des temps reels que le replay ne redonne pas). Ecart: la partie est recomptee avec les stats du replay et va dans « Runs suspectes », sans sanction.
- Une partie qui n'a pas compte (une rule a plante): `php artisan kado:achievements:catch-up --since=<date> --dry-run`. `--since` est obligatoire: les parties d'avant l'activation des succes paieraient leurs recompenses.
- Reglage `verifier_achievements` (« Parametres > Anti-triche »): verifie aussi les parties qui debloquent un palier recompense. Eteint par defaut: une partie dont le replay finit sur un autre score est marquee comme triche, donc mettre d'abord les jeux dont les replays divergent dans `verifier_untrusted_games`.

## Points d'attention

- Les noms de dossiers rules utilisent le casing PHP existant (`KSlash`, `F1Champion`, `Opalus2`, etc.).
- Les dossiers Haxe utilisent un nom minuscule (`kslash`, `f1champion`, `opalus2`).
- Les classes PHP doivent avoir le bon namespace `App\Achievements\Rules\Games\<GameName>`.
- Ne pas creer de compatibilite retroactive inutile.
- Ne pas renommer des keys d'achievements existantes sans demande explicite.
- Ne pas modifier les achievements communs (`stars`, `paradise_league`) sauf demande explicite.

## Verification

Un nouveau jeu avec des succes ajoute une vraie partie dans `tests/Fixtures/achievement-stats.json`: `AchievementRulesRobustnessTest` echoue sans elle, puis casse ces stats de toutes les facons pour verifier qu'aucune rule ne plante.

```sh
docker exec -w /www kadokadeo_app php -d memory_limit=2G vendor/bin/phpunit --no-coverage --filter AchievementRulesRobustnessTest
```

La verification minimale attendue est de controler que les fichiers PHP modifies sont syntaxiquement valides:

```sh
php -l app/Achievements/Rules/Games/<GameName>/<Rule>.php
php -l database/seeders/AchievementsSeeder.php
```

Si `php` n'est pas disponible localement, indiquer que la verification syntaxique n'a pas pu etre lancee.

Si le jeu a ete modifie, la section « Comparer les replays avant / apres » est obligatoire.
