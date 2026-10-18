package rockfaller;

import haxe.io.UInt16Array;
import pixi.core.Pixi.BlendModes;

// group of connected gems of the same colour (getGroups: flood fill)
typedef CGroup = {
	var id:Int;
	var l:Array<Slot>;
}

// the steps of the loop (enum Step of the original)
enum Step {
	S_Play;
	S_Rot;
	S_Grab;
	S_Fall(grabAgain:Bool);
	S_Game_Over;
}

/**
 * Rock Faller (Arkadeo, Motion Twin), the league mode: turn 2 x 2 squares of gems to make groups of 4 or more of the
 * same colour, drop the black rocks into the tubes for plays or points, 10 plays at the start.
 *
 * The game of the Arkadeo HTML5 port (one update per KadoKadeo step, 32 per second), on the rules of the original
 * (src/Game.hx of the archive: same steps, weights, combos and tubes). The game area of Arkadeo: 600 x 460 pixels, drawn
 * at 1 canvas pixel per Flash pixel, the bar of KadoKadeo under it (the canvas of an Arkadeo game is 600 x 500).
 *
 * The mouse (or a finger) points a 2 x 2 square, a click turns it clockwise (released on the canvas, like the onClick
 * of the original): the position and the left button are recorded in the replay.
 */
@:expose('GameRockFaller')
class Game implements kado.GameInterface {
	public static inline var WIDTH = 600;
	public static inline var HEIGHT = 460;

	// geometry of the original. The decor is framed like the Arkadeo HTML5 port (a scene of 600 x 480, the grid at 50),
	// shown from its row 15 (the 460 rows of the game area): the grid at 35 again, the STAGE_Y of the original
	// (rockfaller_assets.py, VIEW_Y)
	public static inline var STAGE_SIZE = 6;
	public static inline var STAGE_X = 120;
	public static inline var STAGE_Y = 35;
	public static inline var COMBO_COUNT = 4;
	public static inline var COMBO_MULT = 0.8;
	public static inline var EXIT_DIST = 60;
	public static inline var SHINE_WAIT = 10.0;

	public static var DIRS = [[1, 0], [0, 1], [-1, 0], [0, -1]];
	public static var SEL_DIRS = [[0, 0], [1, 0], [1, 1], [0, 1]];
	public static var EXIT_STARTS = [[0, 1, 4, 5], [0, 2, 3, 5]];
	// the league: 10 plays at the start (PLAY_COUNT[0][0])
	public static inline var PLAY_COUNT = 10;

	// the sounds of the original (public/assets/sound/rockfaller)
	static var SOUNDS = [
		"Blackrock_life2", "Blackrock_life3", "Blackrock_life4", "Blackrock_points1", "Blackrock_points2", "Blocks_X4L1",
		"Blocks_X4L2", "Blocks_X4L3", "Blocks_XXL1", "Blocks_XXL2", "Blocks_XXL3", "Pipe", "Rock_fall1", "Rock_fall2",
		"Rock_fall3", "Rock_fall4", "Rock_fall5", "Rock_fall6", "Rock_fall7", "Rock_fall8", "Rock_fall9", "Rocks_mouseover1",
		"Rocks_mouseover2", "Rocks_mouseover3", "Rocks_mouseover4", "Rocks_mouseover5", "Rocks_mouseover6", "Rocks_rotate"
	];
	static inline var MUSIC_VOLUME = 0.6;

	public static var me:Game;

	var root:ASprite;

	// planes, from the back to the front
	public var layerBg:ASprite;
	// the glows of the selection: under every stone (the glow of a stone would cover its neighbour of the square)
	public var layerGlow:ASprite;
	public var layerStones:ASprite;
	public var layerExits:ASprite;
	public var layerInter:ASprite;
	public var layerScore:ASprite;
	public var layerFx:ASprite;
	// the gems of the Foreground, under its rocky lips
	public var layerFgGems:ASprite;
	public var layerFg:ASprite;

	public var grid:Array<Array<Slot>>;
	public var allSlots:Array<Slot>;
	public var exits:Array<Exit>;

	public var leftPlay:Int;

	var mcPlays:Array<ASprite>;
	var playWithoutGrab:Int = 0;

	public var step:Step;
	public var selected:Array<Slot>;
	public var falls:Array<Slot>;
	public var waitingFx:Int = 0;

	var comboCount:Int = 0;
	var toRefill:Array<Int>;
	var curSelX:Int = -1;
	var curSelY:Int = -1;
	var nextMudPart:Int = 0;
	// (the fall sound once every 3 steps at most: a whole column lands at once)
	var fallSndCd:Int = 0;
	// one entry per colour: the colour at the head shines when its wait is over, then goes to the tail
	var shines:Array<{id:Int, wait:Float}>;

	// running animations: closures returning true when they are finished
	var fxList:Array<Void->Bool>;

	// KadoKadeo
	var isReplay:Bool;
	var over:Bool = false;
	var frameCount:Int = 0;
	var score:Int = 0;
	var onPointerDown:Dynamic = null;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		var buttons = new UInt16Array(1);
		buttons[0] = MouseManager.BUTTON_LEFT;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: new UInt16Array(0),
			recordInputs: false,
			recordEvents: false,
			recordMousePosition: true,
			recordedMouseButtons: buttons,
		});
		// like the Flash player, a pressed button keeps the mouse until it is released (KadoKadeo releases the buttons
		// when the pointer leaves the canvas): a click started on a square and released out of the grid turns nothing
		if (!isReplay) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			onPointerDown = function(e:Dynamic) {
				try {
					canvas.setPointerCapture(e.pointerId);
				} catch (_:Dynamic) {}
			};
			canvas.addEventListener("pointerdown", onPointerDown);
		}

		me = this;
		this.root = root;
		allSlots = [];
		exits = [];
		selected = [];
		falls = [];
		toRefill = [];
		fxList = [];

		layerBg = new ASprite();
		layerGlow = new ASprite();
		layerStones = new ASprite();
		layerExits = new ASprite();
		layerInter = new ASprite();
		layerScore = new ASprite();
		layerFx = new ASprite();
		layerFgGems = new ASprite();
		layerFg = new ASprite();
		for (l in [layerBg, layerGlow, layerStones, layerExits, layerInter, layerScore, layerFx, layerFgGems, layerFg])
			root.addChild(l);

		// gfx.Background, cut to the game area
		layerBg.addChild(new ASprite("bg"));

		initStage();
		initInter();

		// gfx.Foreground: its gems _g0.._g4 in a random colour (gotoAndStop(rand(4) + 1) of the original), baked with the
		// mask of the Foreground (only their top shows between the rocks), under its rocky lips
		for (i in 0...Data.FG_GEMS.length) {
			var gem = new ASprite("fgGem" + i);
			gem.gotoAndStop(Seed.randomVfx(Stone.getMaxId()) + 1);
			gem._x = Data.FG_GEMS[i][0];
			gem._y = Data.FG_GEMS[i][1];
			layerFgGems.addChild(gem);
		}
		layerFg.addChild(new ASprite("fg"));

		step = S_Play;
		nextMudPart = 80 + Seed.randomVfx(80);

		GameSounds.init("rockfaller", SOUNDS);
		GameSounds.playMusic("Music", MUSIC_VOLUME);
	}

	public function rand(n:Int):Int {
		return Seed.random(n);
	}

	// ------------------------------------------------------------------ the board
	function initStage():Void {
		allSlots = [];
		exits = [];
		grid = [];
		var toCheck:Array<Slot> = [];
		for (x in 0...STAGE_SIZE) {
			grid[x] = [];
			for (y in 0...STAGE_SIZE) {
				grid[x][y] = new Slot(x, y);
				toCheck.push(grid[x][y]);
			}
		}

		// the tubes, on the bottom row
		for (i in EXIT_STARTS[rand(EXIT_STARTS.length)]) {
			var e = new Exit();
			grid[i][STAGE_SIZE - 1].setExit(e);
			exits.push(e);
		}

		// black rocks, then no group already made
		insertStones(toCheck, 3);
		killAutoCombo(toCheck);

		// the shines: one entry per colour, a random first wait
		shines = [];
		for (i in 0...Stone.getMaxId())
			shines.push({id: i, wait: SHINE_WAIT + (Seed.randomVfx(2) * 2 - 1) * SHINE_WAIT / 2});
	}

	function initInter():Void {
		leftPlay = PLAY_COUNT;
		mcPlays = [];
		for (i in 0...leftPlay) {
			var p = new ASprite("Play");
			layerInter.addChild(p);
			p.gotoAndStop(1);
			p._x = 25;
			p._y = 20 + i * 30;
			mcPlays.push(p);
		}
	}

	// ------------------------------------------------------------------ the loop
	public function update(delta:Float) {
		frameCount++;
		GameSounds.step();
		updateFx();

		// a click (the left button released) turns the square under the pointer: a finger does not hover, so the
		// selection is put under it first
		if (!over && MouseManager.isButtonJustReleased(MouseManager.BUTTON_LEFT)) {
			if (Type.enumEq(step, S_Play))
				updateSelection(false);
			emitRotation();
		}

		// the scale of the selection, the falls (a copy: fall() removes from `falls`)
		for (s in allSlots)
			s.update();
		for (s in falls.copy())
			s.fall();

		// mud falling in the background (gfx.MudPart, addMudParts of the original)
		nextMudPart--;
		if (nextMudPart < 0)
			addMudParts();

		if (fallSndCd > 0)
			fallSndCd--;

		updateStep();
		#if debug
		untyped js.Browser.window.__rockfaller = endState();
		#end
	}

	function updateStep():Void {
		switch (step) {
			case S_Play:
				updateShine();
				updateSelection(false);

			case S_Rot:
				updateShine();
				if (waitingFx > 0)
					return;
				waitingFx = 0;
				rotationDone();
				var combos = getCombos();
				if (combos.toGrab.length > 0)
					playWithoutGrab = 0;
				else
					playWithoutGrab++;
				if (!combos.has)
					setStep(S_Play);
				else {
					startGrab(combos.toDestroy, combos.toGrab);
					setStep(S_Grab);
				}

			case S_Grab:
				if (waitingFx > 0)
					return;
				waitingFx = 0;
				startFall();
				var combos = getCombos();
				if (!combos.has) {
					startRefill();
					setStep(S_Fall(false));
				} else
					setStep(S_Fall(true));

			case S_Fall(grabAgain):
				if (falls.length > 0)
					return;
				if (grabAgain) {
					var combos = getCombos();
					comboCount++;
					startGrab(combos.toDestroy, combos.toGrab);
					setStep(S_Grab);
				} else
					setStep(S_Play);

			case S_Game_Over:
		}
	}

	public function setStep(s:Step):Void {
		switch (s) {
			case S_Play:
				// the league: no play left, the game ends (a win: the score is the result)
				if (leftPlay <= 0) {
					gameOver();
					s = S_Game_Over;
				}
			default:
		}
		step = s;
	}

	// the 2 x 2 square under the pointer (getCurSelection of the original: Std.int truncates towards 0, the left /
	// top half of the first column / row points the first square too)
	function updateSelection(force:Bool):Void {
		var px = Std.int((MouseManager.getMouseX() - (STAGE_X + Slot.SIZE / 2)) / Slot.SIZE);
		var py = Std.int((MouseManager.getMouseY() - (STAGE_Y + Slot.SIZE / 2)) / Slot.SIZE);
		if (px < 0 || px > STAGE_SIZE - 2 || py < 0 || py > STAGE_SIZE - 2) {
			px = -1;
			py = -1;
		}
		if (px == curSelX && py == curSelY && !force)
			return;

		unselect();
		curSelX = px;
		curSelY = py;
		if (px < 0)
			return;
		for (i in 0...4) {
			var sl = grid[px + SEL_DIRS[i][0]][py + SEL_DIRS[i][1]];
			sl.select();
			selected.push(sl);
		}
		// sparkles around the square
		var p = Slot.getStonePos(px, py);
		var cx = p.x + Slot.SIZE / 2;
		var cy = p.y + Slot.SIZE / 2;
		var pnb = 3 + Seed.randomVfx(3);
		for (i in 0...pnb)
			spawnSparkle(cx + Seed.signVfx() * (12 + Seed.randomVfx(20)), cy + Seed.signVfx() * (12 + Seed.randomVfx(20)));
		GameSounds.play("Rocks_mouseover" + (1 + Seed.randomVfx(6)));
	}

	function unselect():Void {
		for (s in selected.copy())
			s.unselect();
		selected = [];
		curSelX = -1;
		curSelY = -1;
	}

	// one colour shines at a time, in turn: the head of the list waits, then all its gems shine (a diagonal wave,
	// Slot.setShine) and it goes to the tail (the List of the original)
	function updateShine():Void {
		var sh = shines[0];
		sh.wait -= 0.1;
		if (sh.wait > 0.0)
			return;
		for (sl in allSlots)
			if (sl.stone != null && !sl.stone.isStone() && sl.stone.id == sh.id)
				sl.setShine();
		sh.wait = SHINE_WAIT + (Seed.randomVfx(2) * 2 - 1) * SHINE_WAIT / 2;
		shines.shift();
		shines.push(sh);
	}

	function emitRotation():Void {
		if (!Type.enumEq(step, S_Play) || selected.length < 4)
			return;
		startRotation();
	}

	function startRotation():Void {
		spendPlay();
		for (i in 0...selected.length)
			selected[i].rotate(i);
		GameSounds.play("Rocks_rotate");
		setStep(S_Rot);
	}

	function rotationDone():Void {
		var newOrder = [for (s in selected) s.stone];
		newOrder.unshift(newOrder.pop());
		for (i in 0...selected.length)
			selected[i].setStone(newOrder[i]);
		comboCount = 0;
		updateSelection(true);
	}

	// ------------------------------------------------------------------ combos
	function getCombos():{has:Bool, toDestroy:Array<CGroup>, toGrab:Array<Exit>} {
		var toDestroy = [];
		for (g in getGroups())
			if (g.l.length >= COMBO_COUNT)
				toDestroy.push(g);
		var toGrab = [];
		for (e in exits)
			if (e.slot != null && e.slot.stone != null && e.slot.stone.isStone())
				toGrab.push(e);
		return {toDestroy: toDestroy, toGrab: toGrab, has: toDestroy.length > 0 || toGrab.length > 0};
	}

	function startGrab(toDestroy:Array<CGroup>, toGrab:Array<Exit>):Void {
		unselect();
		resetRefill();

		// the sound of the blocks: level of the combo (0, 1, 2+) x one group (X4) / several (XX)
		if (toDestroy.length > 0) {
			var lvl = comboCount > 2 ? 3 : comboCount + 1;
			GameSounds.play("Blocks_" + (toDestroy.length == 1 ? "X4L" : "XXL") + lvl);
		}

		for (g in toDestroy) {
			var scorePerStone = Std.int(g.l[0].stone.getPoints() * (1.0 + COMBO_MULT * comboCount) * toDestroy.length);
			addScore(g.l.length * scorePerStone);
			for (s in g.l) {
				var sc = prepareScore(s.x, s.y, scorePerStone);
				var pos = Slot.getStonePos(s.x, s.y);
				spawnOnce("Vanish", pos.x, pos.y);
				waitingFx++;
				vanishFx(s.stone.mc, 12, function() {
					s.vanishStone();
					fadeScore(sc);
					waitDone();
				});
				toRefill[s.x]++;
			}
		}

		for (e in toGrab) {
			var s = e.slot;
			var mc = s.stone.mc;
			waitingFx++;
			toRefill[s.x]++;
			// waitDone() is called by proc() once the tube has moved: the next getCombos sees the tube on its new slot
			// and takes a rock already lying there
			tweenTo(mc, mc._x + e.dir[0] * EXIT_DIST, mc._y + e.dir[1] * EXIT_DIST, 8, function() {
				s.removeStone();
				e.proc();
			});
		}
	}

	// ------------------------------------------------------------------ fall, refill
	function resetRefill():Void {
		toRefill = [];
		for (x in 0...STAGE_SIZE) {
			toRefill[x] = 0;
			for (y in 0...STAGE_SIZE)
				if (grid[x][y].stone == null)
					toRefill[x]++;
		}
	}

	function startFall():Void {
		for (x in 0...toRefill.length) {
			if (toRefill[x] == 0)
				continue;
			var y = STAGE_SIZE - 1;
			var count = 0;
			while (y > 0) {
				if (grid[x][y].stone == null) {
					var sy = y;
					var dy = y - 1;
					while (dy >= 0) {
						if (grid[x][dy].stone != null) {
							grid[x][sy].setStone(grid[x][dy].stone, false);
							grid[x][dy].stone = null;
							grid[x][sy].setFall(count * 2);
							count++;
							sy--;
						}
						dy--;
					}
				}
				y--;
			}
		}
	}

	function startRefill():Void {
		var toCheck:Array<Slot> = [];
		for (x in 0...toRefill.length) {
			if (toRefill[x] == 0)
				continue;
			var delta = rand(20);
			for (i in 0...toRefill[x]) {
				var st = new Stone();
				grid[x][i].setStone(st, false);
				toCheck.push(grid[x][i]);
				st.mc._x = Slot.getStonePos(x, i).x;
				st.mc._y = -5 - delta - (toRefill[x] - i) * (Slot.SIZE + 50);
				grid[x][i].setFall();
				grid[x][i].stone.isNew = true;
			}
		}
		insertStones(toCheck);
		killAutoCombo(toCheck);
		// (no prize tokens in KadoKadeo: setPK of the original never happens)
	}

	// ------------------------------------------------------------------ score, plays
	public function addScore(s:Int):Void {
		if (over)
			return;
		score += s;
		KadoKadeoManager.kkm.addScore(s);
	}

	function spendPlay():Void {
		if (leftPlay <= 0)
			return;
		leftPlay--;
		if (mcPlays[leftPlay] != null)
			mcPlays[leftPlay].gotoAndStop(2);
	}

	public function addPlay(n:Int):Void {
		for (i in leftPlay...(leftPlay + n)) {
			if (mcPlays[i] == null) {
				var p = new ASprite("Play");
				layerInter.addChild(p);
				p._x = 25;
				p._y = 20 + i * 30;
				mcPlays[i] = p;
			}
			mcPlays[i].gotoAndStop(1);
			mcPlays[i]._visible = true;
		}
		leftPlay += n;
	}

	// gfx.Score over a destroyed gem (Slot.prepareScore of the original): shown while the gem vanishes
	function prepareScore(gx:Int, gy:Int, value:Int):Score {
		var p = Slot.getStonePos(gx, gy);
		var t = new Score(value);
		t._x = p.x;
		t._y = p.y;
		layerScore.addChild(t);
		var pnb = 2 + Seed.randomVfx(3);
		for (i in 0...pnb)
			spawnSparkle(p.x + Seed.signVfx() * (5 + Seed.randomVfx(8)), p.y + Seed.signVfx() * (5 + Seed.randomVfx(8)));
		return t;
	}

	// then fades out before the stones fall into its cell (Slot.vanishStone: a Part of 7 + rand(7) frames, the last 6
	// fading)
	function fadeScore(t:Score):Void {
		var timer = 7 + Seed.randomVfx(7);
		fxList.push(function() {
			timer--;
			if (timer < 6)
				t._alpha = 100 * timer / 6;
			if (timer <= 0) {
				t.removeMovieClip();
				return true;
			}
			return false;
		});
	}

	// a stone lands: one of the 9 fall sounds
	public function onStoneLanded():Void {
		if (fallSndCd > 0)
			return;
		fallSndCd = 3;
		GameSounds.play("Rock_fall" + (1 + Seed.randomVfx(9)));
	}

	// ------------------------------------------------------------------ effects (gfx.Sparkle*, gfx.Vanish, gfx.MudPart)
	// a clip of the sheet played once, then removed (gfx.Vanish)
	function spawnOnce(name:String, x:Float, y:Float):Void {
		var sp = new ASprite(name);
		sp._x = x;
		sp._y = y;
		sp.loop = false;
		sp.removeOnFrame = sp._totalframes;
		sp.play();
		layerFx.addChild(sp);
	}

	// gfx.Sparkle / 2 / 3: drifts up and fades out
	function spawnSparkle(x:Float, y:Float):Void {
		var names = ["Sparkle", "Sparkle2", "Sparkle3"];
		spawnParticle(names[Seed.randomVfx(3)], x, y, (Seed.randVfx() - 0.5) * 1.2, -0.3 - Seed.randVfx(), -0.04, 10 + Seed.randomVfx(10));
	}

	function spawnParticle(name:String, x:Float, y:Float, vx:Float, vy:Float, weight:Float, timer:Int):Void {
		var sp = new ASprite(name);
		sp._x = x;
		sp._y = y;
		sp.blendMode = BlendModes.ADD;
		if (sp._totalframes > 1) {
			sp.loop = true;
			sp.play();
		}
		layerFx.addChild(sp);
		var t = 0;
		var dvx = vx;
		var dvy = vy;
		fxList.push(function() {
			t++;
			dvy += weight;
			dvx *= 0.96;
			sp._x = sp._x + dvx;
			sp._y = sp._y + dvy;
			sp._alpha = 100 * Math.max(0, 1 - t / timer);
			if (t >= timer) {
				sp.removeMovieClip();
				return true;
			}
			return false;
		});
	}

	function addMudParts():Void {
		nextMudPart = 70 + Seed.randomVfx(70);
		var n = 1;
		var nb = Seed.randomVfx(10);
		if (nb < 2)
			n += 2;
		else if (nb < 5)
			n += 1;
		for (i in 0...n) {
			var sp = new ASprite("MudPart");
			sp.gotoAndStop(Seed.randomVfx(5) + 1);
			sp._x = 40 + Seed.randomVfx(WIDTH - 80);
			sp._y = -50 - Seed.randomVfx(250);
			sp._rotation = Seed.randomVfx(360);
			if (Seed.randomVfx(2) == 0)
				sp._xscale = -100;
			layerFx.addChild(sp);
			var vy = 1.0 + Seed.randVfx() * 2;
			var t = 0;
			fxList.push(function() {
				t++;
				vy += 0.3;
				sp._y = sp._y + vy;
				sp._rotation = sp._rotation + 3;
				if (sp._y > HEIGHT + 60 || t > 400) {
					sp.removeMovieClip();
					return true;
				}
				return false;
			});
		}
	}

	// ------------------------------------------------------------------ tweens
	function updateFx():Void {
		var i = fxList.length - 1;
		while (i >= 0) {
			if (fxList[i]())
				fxList.splice(i, 1);
			i--;
		}
	}

	// smoothstep from the current position to (tx, ty) in `dur` steps
	public function tweenTo(mc:ASprite, tx:Float, ty:Float, dur:Int, ?onFinish:Void->Void):Void {
		var t = 0;
		var sx = mc._x;
		var sy = mc._y;
		fxList.push(function() {
			t++;
			var k = t / dur;
			if (k > 1)
				k = 1;
			var e = k * k * (3 - 2 * k);
			mc._x = sx + (tx - sx) * e;
			mc._y = sy + (ty - sy) * e;
			if (t >= dur) {
				if (onFinish != null)
					onFinish();
				return true;
			}
			return false;
		});
	}

	// fades and shrinks a destroyed gem
	public function vanishFx(mc:ASprite, dur:Int, ?onFinish:Void->Void):Void {
		var t = 0;
		var a0 = mc._alpha;
		var s0 = mc._xscale;
		fxList.push(function() {
			t++;
			var k = t / dur;
			if (k > 1)
				k = 1;
			mc._alpha = a0 * (1 - k);
			mc._xscale = mc._yscale = s0 * (1 - k);
			if (t >= dur) {
				if (onFinish != null)
					onFinish();
				return true;
			}
			return false;
		});
	}

	public function waitDone():Void {
		waitingFx--;
	}

	public function getFreeExitSlots():Array<Slot> {
		var res = [];
		for (i in 0...STAGE_SIZE) {
			var s = grid[i][STAGE_SIZE - 1];
			if (s.exit == null)
				res.push(s);
		}
		return res;
	}

	// ------------------------------------------------------------------ stones: rocks, groups
	function countStones():Int {
		var c = 0;
		for (s in allSlots)
			if (s.stone != null && s.stone.isStone())
				c++;
		return c;
	}

	function insertStones(changeable:Array<Slot>, force:Int = 0):Void {
		var weights = [20, 48, 30, 2];
		var nStones = force;
		if (nStones == 0) {
			var canHave = randomProbs(weights);
			nStones = canHave - countStones();
		}
		nStones += Std.int(Math.round(playWithoutGrab / 10.0));
		nStones = Std.int(Math.min(nStones, changeable.length));

		// (a guard the original did not have: the bottom row cannot take a rock)
		var guard = 0;
		while (nStones > 0 && guard++ < 2000) {
			var slot = changeable[rand(changeable.length)];
			if (slot.stone.isStone() || slot.y == STAGE_SIZE - 1)
				continue;
			slot.stone.setId(10);
			nStones--;
		}
	}

	function killAutoCombo(changeable:Array<Slot>):Void {
		var guard = 0;
		while (guard++ < 1000) {
			var autoCombo = false;
			for (g in getGroups()) {
				if (g.l.length < COMBO_COUNT)
					continue;
				autoCombo = true;
				break;
			}
			if (!autoCombo)
				break;
			for (s in changeable)
				if (!s.stone.isStone())
					s.stone.draw();
		}
	}

	function parse(from:Slot, into:Array<Slot>):Void {
		from.group.l.push(from);
		for (d in DIRS) {
			var nx = from.x + d[0];
			var ny = from.y + d[1];
			if (nx < 0 || nx >= STAGE_SIZE || ny < 0 || ny >= STAGE_SIZE)
				continue;
			var s = grid[nx][ny];
			if (s.group != null || s.stone == null || s.stone.isStone() || from.stone.id != s.stone.id)
				continue;
			into.remove(s);
			s.group = from.group;
			parse(s, into);
		}
	}

	public function getGroups():Array<CGroup> {
		for (g in grid)
			for (s in g)
				s.killGroup();
		var s:Array<Slot> = [];
		for (sl in allSlots)
			if (sl.stone != null && !sl.stone.isStone())
				s.push(sl);
		var groups:Array<CGroup> = [];
		while (s.length > 0) {
			var a = s.pop();
			a.group = {id: groups.length, l: []};
			groups.push(a.group);
			parse(a, s);
		}
		return groups;
	}

	public static function randomProbs(t:Array<Int>):Int {
		var n = 0;
		for (e in t)
			n += e;
		n = Game.me.rand(n);
		var i = 0;
		while (n >= t[i]) {
			n -= t[i];
			i++;
		}
		return i;
	}

	// ------------------------------------------------------------------ KadoKadeo
	// AKApi.gameOver
	function gameOver():Void {
		if (over)
			return;
		over = true;
		#if debug
		untyped js.Browser.window.__over = endState();
		#end
		KadoKadeoManager.kkm.gameOver({});
	}

	#if debug
	// the state compared between a game and its replay (test bots)
	function endState():Dynamic {
		return {
			frame: frameCount,
			score: score,
			plays: leftPlay,
			step: Std.string(step),
			over: over,
			grid: [for (x in 0...STAGE_SIZE) [for (y in 0...STAGE_SIZE) grid[x][y].stone == null ? -1 : grid[x][y].stone.id]],
			exits: [for (e in exits) [e.slot.x, Type.enumIndex(e.fx)]],
		};
	}
	#end

	public function destroy():Void {
		over = true;
		GameSounds.stopMusic();
		if (onPointerDown != null) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			if (canvas != null)
				canvas.removeEventListener("pointerdown", onPointerDown);
			onPointerDown = null;
		}
		me = null;
	}
}
