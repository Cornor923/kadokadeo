---
name: replay-analyzer
description: Créer (ou recalibrer) l'analyseur des coups d'un jeu pour le vérificateur de replays (anti-triche « partie jouée avec aide »), comme Binary et Kaskade 2.
---

Tu travailles sur KadoKadeo (Laravel + jeux Haxe). Entrée : le `game_key` d'un jeu (`binary`, `kaskade2`, `opalus2`...).

## Ce qu'un analyseur attrape (et ce qu'il n'attrape pas)

Le vérificateur rejoue le replay d'une partie sur le serveur et compare son score au score envoyé : un score trafiqué
est détecté. Mais une partie jouée **avec aide** (un script de la page qui calcule et montre le meilleur coup) a un
replay légitime et le bon score. L'analyseur regarde les coups pendant que le replay est rejoué et dit s'ils
ressemblent à ceux d'un joueur ou d'un solveur (meilleur coup quasiment à chaque fois, temps de décision inhumain...).

Bons candidats : jeux de réflexion à information visible, où « le meilleur coup » se calcule à partir de l'état à
l'écran (Binary, Kaskade 2, Logico, Hexile, Quadrikolor...). Jeux d'action/réflexes : pas de « meilleur coup », seulement
des métriques de temps/régularité des entrées (temps de réaction sous ~100 ms, intervalles trop réguliers) ; à
proposer à l'utilisateur avant de s'y lancer, le taux de faux positifs est plus dur à tenir.

## La chaîne (lire avant d'écrire)

1. Fin de partie : `App\Http\Controllers\Api\RunController::end` envoie `VerifyRunReplay` si
   `ReplayVerifier::shouldVerify` (meilleur score perso, contrat réussi, partie du jour) ou, pour les jeux qui ont un
   analyseur, `shouldSampleForAnalysis` (`kado.replay_analysis.sample_rate`, file `kado.replay_analysis.queue`).
   Tout est coupé si `KADO_REPLAY_VERIFIER` est faux.
2. `App\Jobs\VerifyRunReplay` → `App\Services\ReplayVerifier::verify` → `resources/js/replay-verifier/verify.mjs`
   (Node 22 + Chrome headless) avec `analysis` = `config('kado.replay_analysis.games.<key>')` quand
   `analyzers/<key>.mjs` existe (`ReplayVerifier::hasAnalyzer`).
3. `verify.mjs` importe `/__analyzers/<key>.mjs`, appelle `create({ kk, config })`, puis `beforeFrame(frame)` avant
   chaque `kk.updatePhysics`, puis `finish({ score, frames })` après l'écran de fin.
4. Le résultat va dans `replay_verifications.analysis` (admin « Paramètres > Vérificateur de replays », colonne
   « Analyse des coups »), et si `suspicious` et `KADO_REPLAY_ANALYSIS_FLAG` vrai, dans les runs suspectes
   (`SuspicionService::recordAnalysis`, règle `GAME_ANALYSIS`, détails = `reasons`).

Références à lire : `resources/js/replay-verifier/analyzers/README.md` (le contrat), `binary.mjs` (coups lus dans les
événements du replay) et `kaskade2.mjs` (coups lus dans un champ du jeu, plateau lu quand le jeu attend un clic).

## Méthode

### 1. Comprendre le jeu (Haxe)

Dans `resources/hx/games/<jeu>/` :
- **Quand le joueur décide** : l'étape/état où le jeu attend une entrée (`step` + `_hx_name` d'un enum dans Binary,
  `game.lock` dans Kaskade 2).
- **L'état vu par le joueur** à ce moment (grille, pièces, réserve...) et les champs qui le portent. Toute
  l'information aléatoire à venir est **inconnue** du joueur comme du solveur : ne compter que ce qui est certain à
  partir de l'écran (Kaskade 2 : les billes qui tombent sont `UNKNOWN`).
- **Le coup joué** : soit dans les événements du replay (`kk.replay.playFrames[i]` = frame,
  `kk.replay.playRecords[i].events` = événements du jeu, ex. Binary `{k: 1, x, y}` via `recordAndApplyReplayEvent`),
  soit dans un champ du jeu mis à jour par le coup (Kaskade 2 : `game.stats.d`, lu à la frame suivante).
- **Les règles** exactes du coup (points, gravité, combos), à porter fidèlement en citant les fonctions Haxe d'origine.

Les noms de champs survivent à la minification (esbuild ne renomme pas les propriétés), mais le DCE de Haxe peut
supprimer un champ jamais lu : vérifier par `grep` dans `public/gamesdata/<key>.js`.

### 2. Le solveur : `analyzers/<key>/solver.mjs` + `analyzers/<key>.test.mjs`

- Fonctions pures, sans rien du navigateur ni du jeu : `rateMove(state, depth, coup)` →
  `{ best, value, optimal, ... }` (points du meilleur coup, points du coup joué, coup joué parmi les meilleurs).
- Profondeur bornée (`max_depth` de la config) : le vérificateur a un timeout (`KADO_REPLAY_VERIFIER_TIMEOUT`) et
  rejoue toute la partie ; mémoïser (voir `kaskade2/solver.mjs`).
- Tests `node --test resources/js/replay-verifier/analyzers/<key>.test.mjs` : règles (un coup, une cascade), un cas
  où le meilleur coup n'est pas le coup glouton, la profondeur. Grilles écrites en chaînes lisibles comme dans les
  tests existants.

### 3. L'analyseur : `analyzers/<key>.mjs`

Partir de `binary.mjs` ou `kaskade2.mjs` selon d'où vient le coup. Règles impératives :
- `export const meta = { game: '<key>', version: 1 }` ; incrémenter `version` quand les métriques changent de sens.
- **Lecture seule** : lire les champs de `kk.game` / `kk.replay`, ne jamais appeler une méthode du jeu ni `Seed` (le
  replay doit se dérouler exactement comme sans analyseur). Copier les tableaux avant de travailler dessus.
- Champ attendu absent → `throw new Error('unsupported build')` (bundles archivés) : l'erreur termine l'analyse, jamais
  la vérification.
- Métriques : garder les noms communs, lus par `php artisan kado:replays:analyze` et par la colonne de l'admin :
  `decisions`, `optimal`, `optimalRate`, `valueRate`, `meanDecisionFrames`, `medianDecisionFrames`,
  `p10DecisionFrames` (frames entre l'état affiché et le coup, 32 par seconde). Une métrique nouvelle et utile pour
  calibrer : l'ajouter aussi au tableau de `app/Console/Commands/AnalyzeReplays.php`.
- `suspicious` seulement au-delà d'un minimum de coups (`min_decisions`) : une partie courte n'a rien de significatif.
- `reasons` **en français** (affichées telles quelles dans l'admin), ex. ``meilleur coup 93 % du temps (42 coups, limite 85 %)``.

### 4. La config

Dans `config/kado.php`, `replay_analysis.games.<key>` : `min_decisions`, `optimal_rate`, `max_depth` (+ ce que
l'analyseur lit), avec un commentaire qui renvoie au solveur. `KADO_REPLAY_ANALYSIS_FLAG` est **global** : s'il est
déjà allumé en production, un analyseur pas encore calibré enverrait ses parties dans la file dès son déploiement.
Dans ce cas, livrer avec un seuil impossible (`optimal_rate` > 1) jusqu'à la calibration, et le dire à l'utilisateur.

### 5. Essayer de bout en bout (local)

Le conteneur `kadokadeo_app` a Node 22 et Chromium :

```sh
node --test resources/js/replay-verifier/analyzers/<key>.test.mjs
docker exec kadokadeo_app php artisan kado:replays:analyze <key> --limit=20
```

Il faut des parties avec replay dans la base locale (jouer quelques parties en local, en jouant bien et mal). Pour
une partie : `--user=<id>`. Une colonne vide ou « erreur : ... » = l'analyseur ne lit pas le jeu (champ, frame du coup).
Vérifier à la main 2 ou 3 coups notés « meilleur » / « pas meilleur » contre le replay (admin, bouton replay) avant de
faire confiance aux taux.

### 6. Calibrer (production)

Sur le serveur de production (ou une copie de sa base, avec les replays) :

```sh
php artisan kado:replays:analyze <key> --limit=500
php artisan kado:replays:analyze <key> --user=<id d'un tricheur connu>
```

La commande affiche p50 / p90 / p99 / max du taux de meilleur coup. Placer `optimal_rate` au-dessus du p99 des
joueurs honnêtes (et des meilleurs joueurs du classement : ils jouent bien sans aide), sous les tricheurs connus s'il
y en a. Rapporter les chiffres à l'utilisateur et le laisser décider d'allumer `KADO_REPLAY_ANALYSIS_FLAG` (et
éventuellement `KADO_REPLAY_ANALYSIS_SAMPLE_RATE` pour analyser aussi des parties qui ne sont pas des records).

### 7. Finir

- `AGENTS.md` (ligne « Per-game move analyzers ») : ajouter le jeu à la liste.
- Tests PHP si du PHP a changé : `docker exec kadokadeo_app php artisan test`.
- Pas de rebuild des jeux : l'analyseur ne touche pas au bundle.
