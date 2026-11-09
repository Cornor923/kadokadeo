# La Brute

A KadoKadeo game (Arkadeo size, 600 x 460) made from LaBrute, the Eternaltwin remake of MyBrute:
a shop, the choice of an opponent among three, an accelerated fight of LaBrute, again until a defeat.

## Where it comes from

- `Data.hx` (weapons, skills, pets, their 3 tiers), `Brute.hx` (stats, starter brute, random bonuses, looks) and
  `fight/` (the fight generator) are ported from
  [labrute-react](https://gitlab.com/eternaltwin/labrute/labrute-react) (`core/src/brute`, `server/src/utils/fight`),
  function by function. labrute-react is distributed under the
  [PolyForm Noncommercial License 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0) (primary author:
  Zenoo): the ported code keeps that license and its notices, and is used here for a noncommercial purpose.
- The fighters are drawn at run time by [labrute-pixi-fighter](https://github.com/Zenoo/labrute-pixi-fighter)
  (MIT, npm), with PixiJS 8 in a canvas of its own (`view/Actors.hx`).
- The sprite sheets `public/assets/img/content/labrute/labrute-*`, the start screen and the thumbnail are made
  from the pictures of labrute-react by `.opencode/skills/flash-port/scripts/examples/labrute/build_assets.mjs`.
  labrute-react distributes its pictures under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/):
  so are these sheets (noncommercial, credited, same license).

## What differs from LaBrute

- No fight modifier of the day, no boss, no clan, no original achievement, no chaos.
- A fight has a clock (`fight/Timing.hx`: LaBrute's steps played `Balance.FIGHT_SPEED` (2.2) times faster, the
  throws of the weapons kept in hand `THROWN_SPEED` (3.5) times): after `TIMER_FRAMES` (21 seconds), the sudden
  death: every fighter loses HP at each frame (`Balance.drainTotal`, a `Drain` step at the end of each turn, counted
  by the generator: the fight is decided when it is generated). It grows every 5 seconds of sudden death and every
  `DRAIN_LEVEL_FIGHTS` (5) fights of the run. In the turn that decides the fight, the drain stops at the blow that
  decided it (its `Drain` step is put just after that blow). A pet or a backup killed by it gives no gold, no ear.
- The pets come less often (`Balance.PET_ODDS_FACTOR`), for the player and for the opponents.
- When only boosters are left (LaBrute makes them rarer and rarer), a purchase draws among the perks still possible
  (`Brute.candidates`): every skill can be bought.
- The level of the player's brute is the fights played + 2; the opponents (easy, medium, hard:
  `Balance.OPPONENT_OFFSETS`) are below or above a hidden level that gains one more every `EXTRA_LEVEL_WINS` (3)
  fights won (`Run.playerLevel`, `Run.hiddenLevel`). The leagues stop at the last one.
- The `sort` calls of LaBrute that drew a random number in their comparator (the order of the fighters, Déluge)
  are deterministic here: the replays must give the same fight in every browser.
- « Pansement » (regeneration) gives no fight more per day: it forgives the first defeat of the run (once).
- The shop and the opponents only draw perks not owned yet (LaBrute gives a tier more); tiers are bought with gold
  and ears (`Balance.TIER_EARS`: one ear by fight won, one more by backup of the opponent killed).

All the tunable values of the game (prices, rewards, levels of the opponents, speed, sudden death) are in
`Balance.hx`.

## KadoKadeo

- The texts in 8 languages (`Lang.hx`, `lang/`: the data of LaBrute in `<Lang>Data.hx` from the translations of
  labrute-react by `build_lang.mjs`, the texts of the screens in `<Lang>.hx` by hand), the key L for the next one
  (remembered by the browser): pictures and texts only, nothing of the game.
- The replay: the clicks on the buttons are its events; the moves of the mouse and the changes of the pointer
  (mouse, touch, out of the game) are recorded too (`Game.hx`), the replay shows the hovers, the tooltips, a cursor
  (the live game keeps the cursor of the system) and the taps of a touch screen. The game never reads them: the
  score cannot depend on them.
