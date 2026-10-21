---
name: replay-system
description: Integrer le systeme de replay dans un jeu Haxe (clavier + souris polled + evenements gameplay) a partir d'un dossier cible.
---

Tu travailles sur un projet Haxe KadoKadeo.

## Objectif

A partir d'un dossier de jeu fourni en parametre (ex: `resources/hx/games/monjeu`), integrer le systeme de replay pour rendre une partie rejouable de maniere deterministe.

Le moteur replay est dans `resources/hx/lib/kado/ReplayManager.hx`.
L'orchestration globale (start/stop/frame + envoi replay) est deja geree par `resources/hx/lib/kado/KadoKadeoManager.hx`.

## Entree attendue

- Le point d'entrée du jeu est souvent la classe `Game.hx`

## Principes importants (a respecter absolument)

- Ne pas gerer manuellement le cycle de vie replay dans le jeu:
    - pas de `replay.start()`, `replay.stop()`, `replay.beginFrame()`, `replay.endFrame()` cote jeu
    - c'est `KadoKadeoManager` qui le fait deja
- Initialiser le replay dans le constructeur du jeu avec `KadoKadeoManager.kkm.replay.init(...)`
- Preferer le polling clavier/souris (`KeyboardManager` + `MouseManager`) pour les inputs joueur
- Ne garder `recordEvents` que pour des evenements gameplay non derivables d'un input polled (spawn scriptes, triggers metier, etc.)
- Quand `recordEvents = true`, consommer les evenements replay au debut de `update()`
- Respecter la temporalite des events: `recordEvent(...)` (sans `frameIndex`) est applique a la frame suivante; ne pas appliquer immediatement en live une action qui, en replay, passera par `consumeEvents()`
- Eviter les doubles enregistrements en mode replay (`isReplay == true`) pour les evenements metier
- Conserver la logique gameplay identique entre session live et session replay (memes chemins de code)
- Pour les controles clavier, utiliser `common_haxe_avm1.KeyboardManager` (et pas la classe `Key` legacy)
- Pour les controles souris, utiliser `common_haxe_avm1.MouseManager` (`getX/getY`, `isButtonDown`, `isButtonJustPressed`, `isButtonJustReleased`)
- Si le jeu est base sur une grille, calculer la cellule depuis `MouseManager.getX/getY` dans `update()` (hover derive de la position)

## Strategie d'integration

Choisir le mode en fonction des controles du jeu:

1. Inputs clavier uniquement
    - `recordInputs: true`, `recordEvents: false`
    - fournir `recordedKeys` (`UInt16Array`)
    - exemple: `resources/hx/games/atlanteine/Game.hx`

2. Inputs souris polls (sans position)
    - `recordInputs: false`, `recordEvents: false`
    - `recordMousePosition: false`
    - `recordedMouseButtons: UInt16Array([...])`
    - lecture en jeu via `MouseManager.isButtonDown/isButtonJustPressed/...`
    - exemple: `resources/hx/games/interwheel/Game.hx`

3. Inputs souris polls (avec position)
    - `recordInputs: false` (ou `true` si clavier aussi), `recordEvents: false`
    - `recordMousePosition: true`
    - `recordedMouseButtons: UInt16Array([...])`
    - lecture en jeu via `MouseManager.getX/getY` + boutons
    - exemples: `resources/hx/games/kaskade2/Game.hx`, `resources/hx/games/zipzap/Game.hx`

4. Evenements gameplay metier uniquement (hors inputs polled)
    - `recordInputs: false`, `recordEvents: true`
    - enregistrer des evenements metier via `recordEvent(...)`
    - rejouer via `consumeEvents()` + `applyReplayEvent(...)`
    - exemple: `resources/hx/games/synapses/Game.hx`

5. Mix clavier + evenements metier
    - `recordInputs: true`, `recordEvents: true`
    - ajouter `recordMousePosition` / `recordedMouseButtons` seulement si la souris influence le gameplay
    - exemples: `resources/hx/games/opalus2/Game.hx`, `resources/hx/games/kslash/Game.hx` (le code secret NIGHT
      tape au clavier : ses lettres ne sont pas des touches enregistrees, un evenement le rejoue)

## Etapes d'implementation (ordre recommande)

1. Analyser les entrees gameplay

- Lister ce qui influence l'etat de partie:
    - touches clavier
    - boutons souris press/release
    - position souris si elle influence la selection/target
    - hover si le hover modifie la selection/target effective
- Ignorer le purement visuel.
- Pour les touches, recenser les usages `Key.isDown(...)`/`Key` et les migrer vers `KeyboardManager.isDown(...)` avant l'integration replay.
- Si des keycodes sont utilisés en dur, les remplacer par des constantes `KeyboardManager.<KEY>` en modifiant le KeyboardManager pour les definir si necessaire.
- Pour la souris, migrer les handlers ad-hoc (`onPress`, `onRelease`, `recordEvent({k:...})`) vers la lecture polled dans `update()`.
- Pour les grilles, definir une conversion souris -> cellule (`getMouseCell`, `screenToGrid`, etc.) et centraliser l'action metier via cette cellule.

2. Initialiser replay dans `new(...)`

- Ajouter (ou completer) `replay.init`:

```hx
var replayKeys = new UInt16Array(N);
// replayKeys[i] = common_haxe_avm1.KeyboardManager.<KEY>;
var replayMouseButtons = new UInt16Array(M);
// replayMouseButtons[i] = common_haxe_avm1.MouseManager.BUTTON_LEFT; // etc.

KadoKadeoManager.kkm.replay.init({
	recordedKeys: replayKeys, // ou new UInt16Array(0) si pas de clavier
	recordInputs: true,       // ou false
	recordEvents: false,      // true seulement pour evenements metier
	recordMousePosition: true, // ou false
	recordedMouseButtons: replayMouseButtons,
});
```

3. Migrer le jeu vers les inputs polled

- Clavier: `KeyboardManager.isDown/isJustDown`
- Souris: `MouseManager.getX/getY`, `MouseManager.isButtonDown/isButtonJustPressed/isButtonJustReleased`
- Ne pas brancher la logique gameplay principale sur des callbacks UI souris; la lire dans `update()` pour avoir exactement la meme valeur live/replay.

4. Brancher la consommation d'evenements metier (si `recordEvents = true`)
   **deprecated** : utilisation des événements de souris/clavier directement (inputs polled).

- En tete de `update(delta)`:

```hx
for (event in KadoKadeoManager.kkm.replay.consumeEvents()) {
	applyReplayEvent(event);
}
```

- Implementer `applyReplayEvent(event:Dynamic)`:
    - valider `event != null`
    - lire `k`, eventuellement `x`, `y`
    - rejouer l'action metier exacte (hover, select, press/release...)
- Important: ne pas utiliser `recordEvents` pour des inputs souris standard si `MouseManager` suffit.

5. Enregistrer les evenements metier (optionnel)

- Au moment ou l'action utilisateur est validee:

```hx
KadoKadeoManager.kkm.replay.recordEvent({k: 2, x: cell.x, y: cell.y});
```

- A reserver aux evenements metier non derivables des etats clavier/souris polled.

6. Eviter les doublons en replay

- Si `recordEvents = true`, dans les handlers live (`onPress`, `updateHover`, etc.), ne pas `recordEvent` si `isReplayMode`.
- Conserver un code unique de gameplay autant que possible.

7. Validation

- Pour compiler, utiliser la commande `make compile-games`
- Lancer une partie live et verifier l'absence de regression.
- Verifier qu'un replay rejoue:
    - memes actions
    - meme score final
    - meme fin de partie
- En debug, `KadoKadeoManager` trace `Replay data` a la fin.

## Details techniques utiles sur ReplayManager

- `recordInput` enregistre des transitions de touche (down/up), pas un etat complet a chaque frame.
- `recordMousePosition` enregistre la position souris (int) seulement quand elle change.
- `recordedMouseButtons` enregistre les transitions down/up des boutons souris suivis.
- Les boutons souris utilises suivent `MouseEvent.button` DOM (`0` gauche, `1` milieu, `2` droit).
- `recordEvent` sans `frameIndex` met en file d'attente pour la frame suivante (comportement normal du manager).
- Consequence pratique: si une action est enregistree en event, eviter de l'appliquer "tout de suite" en live dans un chemin de code different, sinon live et replay peuvent diverger (timing, trajectoires, score).
- Le format d'evenement `{k, x, y}` est un exemple et est a adapter suivant le jeu / le contexte.
- Format binaire (version 3, ecrite depuis 2026-10) : chaque section est ecrite colonne par colonne (tous les ecarts
  de frames, puis toutes les valeurs), les touches / boutons comme leur indice dans `recordedKeys` /
  `recordedMouseButtons`, la position de la souris comme son deplacement (moins celui de la frame d'avant) : environ
  2 fois plus petit pour les jeux a la souris. Les versions 1 et 2 restent lues (anciens replays). Rien a faire dans
  les jeux.
- Version 4 (anti-triche, flag `INPUT_PHASES`, jeux avec le stir) : une section PHASES, un octet par changement de
  touche, par event et par changement de bouton souris : le moment de l'input dans sa frame (quart de ms, lu sur
  `Event.timeStamp` par `kac.Natives`, 125 = sans temps, 127 = event exclu). Le stir de la frame en depend (avec la
  position souris pour `recordMousePosition`, et les events de la frame d'avant) : les prochaines pieces ne se
  predisent plus avant le clic. Rien a faire dans les jeux : `recordEvent(e, frame)` prend la phase du dernier input de
  la frame (`recordEvent(e, frame, phase)` pour en donner une, `ReplayManager.phaseOf(t)`); un event enregistre pour
  une frame deja jouee est exclu (phase 127). Le jeu du jour n'a ni stir ni phases.
- L'interface du replay (`ReplayHud`, creee par `KadoKadeoManager`) est commune a tous les jeux : rien a faire non plus.

## Patterns de reference (repo actuel)

- Inputs clavier seuls:
    - `resources/hx/games/atlanteine/Game.hx`
- Souris polled:
    - `resources/hx/games/interwheel/Game.hx`
    - `resources/hx/games/kaskade2/Game.hx`
    - `resources/hx/games/zipzap/Game.hx`
- Clics en evenements, appliques avant le stir (`applyInputEvents`, voir plus bas):
    - `resources/hx/games/chocomouche/Game.hx`, `resources/hx/games/opalus2/Game.hx`
- Inputs + evenements metier:
    - `resources/hx/games/opalus2/Game.hx`
    - `resources/hx/games/kslash/Game.hx`
- Souris en evenements (parties longues, la position de la souris ne compte qu'au clic):
    - `resources/hx/games/hypercube/Game.hx` : `recordMousePosition: false`, un evenement Int par clic utile
      (`EV_PRESS` prise d'une piece / bouton de fin, rejoue par un hit test a la position enregistree; `EV_DROP` pose),
      enregistre pour la frame en cours (`recordEvent(e, replay.getCurrentFrame())`) et consomme sur la meme frame; les
      touches restent des inputs. En replay, la piece en main va d'un evenement au suivant (lisse) grace a
      `replay.getReplayEvents()` (tous les evenements du replay avec leur frame, pour anticiper).
    - `resources/hx/games/phagocytoz/Game.hx` (`readControls`) : la souris ne compte que par la poussee (bouton + direction
      depuis le heros). Un octet par changement, en `{k, x, y}` packe : 0 = relache, v >= 1 = pousse, la direction (255)
      change de unzig(v - 1) (ecarts : deflate les compresse bien). Enregistre pour la frame en cours et applique sur la
      meme frame, en live comme en replay (le live pousse aussi dans la direction enregistree). Les changements de
      direction prennent la phase `ReplayManager.PHASE_NONE` (une visee continue n'a pas de moment, sinon un octet de phase
      aleatoire par event) ; l'appui garde la phase de l'input.

## Points d'attention importants

- Jamais de callback d'input sur un sprite (`ASprite.onPress` / `onRelease` / `onRollOver` / `onMouseMove`...): ils
  partent des evenements PIXI, dans `MouseManager.beginFrame`, donc avant le `Seed.stir` de la frame, alors que le
  replay applique ses evenements dans `update()` (apres le stir): un clic qui tire le RNG de gameplay (Chocomouche:
  les bombes) diverge. Lire la souris en polling. Un jeu dont le clic doit rester avant le stir (anciens replays
  enregistres avec les callbacks) definit `applyInputEvents()`: appele par `KadoKadeoManager` entre
  `replay.beginFrame()` et le stir, il y lit la souris en live (evenement enregistre avec
  `recordEvent(e, replay.getCurrentFrame())`) et y applique les evenements du replay. Les `onPress` champs d'une classe
  `MC` du jeu, appeles par son `Buttons.hx` depuis la souris pollee (Electrolink, Hypercube, Logic'O...), sont du
  polling: pas concernes.
- Ne pas lire la souris / le clavier dans le constructeur du jeu: rien n'est encore enregistre (en replay, la position
  donnee est celle de la frame 0, `MouseManager.presetPosition`).
- La position de la souris n'est jamais negative (`MouseManager.getX/getY`, comme l'enregistrement): pointeur sorti a
  gauche / en haut = 0.
- Le gameplay ne lit pas les pixels d'une texture (`PixelHelper.extract`, `renderer.extract`): le GPU donne d'autres
  bords d'une machine a l'autre, et le verificateur du serveur n'a pas de GPU. Garder un modele CPU (Crepuscud:
  `ground`).

- Lorsque le jeu est en recordEvent et possède une grille où x et y sont inférieurs à 8 (entre 0 et 7), on peut utiliser recordEvent({k: 0-3, x: 0-7, y: 0-7}) pour encoder un event en un seul octet (k<<6 | x<<3 | y). Cela permet de réduire la taille du replay.
- Si le jeu est en recordEvent mais n'est pas dans une grille, utiliser un autre valeur que "k" dans l'objet recordé.

## Versions des jeux (replays apres une mise a jour)

Un replay ne contient que les inputs: il doit etre rejoue par la version du jeu avec laquelle il a ete enregistre.
**Desactive pour l'instant** (`SiteSettings::$game_builds_enabled`, admin « Paramètres > Site »): la prod ecrase `storage/` a chaque deploiement, l'archive
est perdue; les runs ne retiennent aucune version et les replays sont joues par le bundle courant.
C'est automatique, rien a faire dans le code d'un jeu:

- `resources/js/games/build-games.mjs` archive a chaque build l'ancienne version de chaque bundle qui change
  (`resources/js/games/builds/archive.mjs`, dans `storage/app/game-builds/`): un delta binaire de quelques centaines
  d'octets par version (`delta.mjs`), et pour la planche de sprites seulement les images que la nouvelle planche n'a
  plus ou dessine avec une autre taille / ancre (`atlas.mjs`, mini-planche de quelques Ko).
- La page envoie `build` (hash du manifest) au debut d'une partie: `runs.game_build_id` (table `game_builds`).
- La page replay (`runs/show.vue`) charge `run.gamedata`: le bundle de cette version, reconstruit par Laravel
  (`/gamesdata/builds/<jeu>/<hash>.js`, `app/Support/GameBuilds`), et sa planche (`params.assetBase`).
- `php artisan kado:game-builds:keep` (planifie chaque jour) liste les versions encore utilisees par des replays: le build
  suivant supprime les autres.

A respecter dans un jeu: charger sa planche par le chemin du manager (`<jeu>-0.json` et ses `related_multi_packs`),
pas de chemin `/assets/img/content/...` ecrit en dur pour la planche; ne pas supprimer `storage/app/game-builds`.
Tests: `node --test resources/js/games/builds/archive.test.mjs` et `php artisan test --filter GameBuildsTest`.

## Checklist finale

- [ ] `replay.init(...)` present dans le constructeur
- [ ] `recordedKeys` defini correctement (ou vide)
- [ ] `recordMousePosition` active si la position souris impacte le gameplay
- [ ] `recordedMouseButtons` defini si des boutons souris sont utilises
- [ ] logique input lue en polling dans `update()` (clavier/souris)
- [ ] `consumeEvents()` / `applyReplayEvent(...)` uniquement si `recordEvents = true`
- [ ] `recordEvent(...)` reserve aux evenements metier non derivables
- [ ] garde-fou anti double-enregistrement en replay (si events metier)
- [ ] score/fin de partie identiques entre live et replay
