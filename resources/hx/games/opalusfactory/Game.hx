package opalusfactory;

import haxe.io.UInt16Array;
import opalusfactory.MC.Plans;
import pixi.core.Pixi.BlendModes;
import pixi.core.display.Container;
import pixi.filters.alpha.AlphaFilter;

enum Step {
	Door;
	Play;
	Move(start:{x:Float, y:Float}, end:{x:Float, y:Float}, c:InCase);
	Roll(size:Int);
	GameOver;
}

// a hole: blockHole (id 0, the nuts) or an order clip (id 1..7, the opals of colour id). port: `field` is the text
// field the code writes (order.smc._field, blockHole._count._field)
typedef Hole = {
	var mc:MC;
	var mcLock:MC;
	var locks:Array<MC>;
	var count:Int;
	var id:Int;
	var field:Digits;
}

// a case of the roll. port: its button (hit test), the focus glow and the silhouettes of the line's drop shadow
typedef InCase = {
	var mc:MC;
	var coin:Coin;
	var index:Int;
	var l:RollLine;
	var links:Array<InCase>;
	var parsed:Bool;
	var focus:Bool;
	var rim:ASprite;
	var sil:Array<ASprite>;
}

typedef RollLine = {
	var index:Int;
	var tokened:Null<Bool>;
	var mc:MC;
	var recal:Float;
	var line:Array<InCase>;
	var sy:Null<Float>;
	var sc:Null<Float>;
	var fLimit:Float;
	// port: setLineShadow (DropShadowFilter of the line: its distance, 0 = none) and the silhouettes under its cases
	var shadowD:Int;
	var shade:ASprite;
	var shadeFilter:AlphaFilter;
}

typedef Goal = {
	var id:Null<Int>;
	var goal:Int;
	var count:Int;
}

// port: `mc._x = ...` of the clip the move drives (an MC or a named child)
typedef Move = {
	var setX:Float->Void;
	var func:Float->Float;
	var speed:Float;
	var start:{x:Float, y:Float};
	var end:{x:Float, y:Float};
	var timer:Float;
}

typedef Glow = {
	var mc:MC;
	var func:Float->Float;
	var speed:Float;
	var start:Float;
	var end:Float;
	var timer:Float;
}

typedef DropInfos = {
	var timer:Null<Float>;
	var hole:Hole;
	var coins:Array<{h:Float, c:Coin, spos:{x:Float, y:Float}, tpos:{x:Float, y:Float}}>;
}

// port: a coin that falls off the roll (coinFalls): its clip, the coin inside and the silhouette of its drop shadow
typedef Fall = {mc:MC, cmc:MC, sil:ASprite};

// port: an order clip (its hole of colour `color` comes in blurred: picture `intro` instead of smc on its first frames)
typedef Order = {mc:MC, color:Int, intro:ASprite};

// port: the points that rise (the drop shadow of _p moves down with the frames)
typedef Points = {mc:MC, p:ASprite, t:Digits};

// Game.hx of the original (Haxe for Flash 8), line by line; the port's own parts are at the end
@:expose('GameOpalusFactory')
class Game implements kado.GameInterface {
	// Flash played Opalus Factory at 40 frames/s (the rate of the KadoKado loader that plays the game SWF; the SWF says
	// 44) with Timer.wantedFPS = 32
	public static inline var FLASH_FPS = 40;

	public static var gMove:Array<Move> = new Array();
	public static var gGlow:Array<Glow> = new Array();

	public static var DP_BG = 0;
	public static var DP_SUB_PARTS = 1;
	public static var DP_HOLE = 2;
	public static var DP_ROLL = 3;
	public static var DP_CASE = 4;
	public static var DP_COIN = 5;
	public static var DP_HERO = 6;
	public static var DP_INTER = 8;

	public static var DP_PARTS = 10;
	public static var DP_POINTS = 11;
	public static var DP_DOOR = 12;

	// replay: the plays, one Int each (x | y << 10 | case << 20 | line << 23, x / y: the mouse in canvas pixels
	// 0..1023, the case played: its index in its line and the line's index in the roll), not the mouse itself
	// replay: the pointer goes from a play to the next one in MOVE_BASE steps + 1 per MOVE_SPEED Flash pixels (eased),
	// then waits there
	static inline var MOVE_BASE = 4;
	static inline var MOVE_SPEED = 16;

	public var step:Step;

	var timer:Null<Float>;

	var goal:Goal;
	var goalCount:Int;
	var dropInfos:DropInfos;

	public var flGameOver:Bool;
	public var mdm:Plans;
	public var root:ASprite;

	public static var me:Game;

	var mcWall:MC;
	var mcDoor:MC;

	public var rolldm:Plans;
	public var mcRoll:MC;

	public var holes:Array<Hole>;

	public var roll:Array<RollLine>;
	public var level:Int;
	public var lastWasGoal:Bool;
	public var lastLockPlay:Null<Int>;

	var oldDeltaRoll:Float;
	var flagBlockPart:Null<Int>;

	public var currentBlockMove:{m:Move, onEnd:Void->Void};

	public var mcHero:MC;
	public var hsy:Float;
	public var heroX:Null<Int>;
	public var heroY:Null<Int>;

	var lastParse:Array<InCase>;

	// ---------------------------------------------------------------- port
	var isReplay:Bool;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	// the score of KKApi, nothing after the game over
	var over:Bool = false;
	// the mouse in canvas pixels (0..1023: what the replay events hold), and in Flash pixels (root._xmouse / _ymouse)
	var mousePx:Int = 0;
	var mousePy:Int = 0;
	var mouseX:Float = 0;
	var mouseY:Float = 0;
	// replay: the plays of the replay (frame, position in Flash pixels), the one at or before the frame played
	var path:Array<{f:Int, x:Float, y:Float}>;
	var pathIdx:Int = 0;
	// Flash buttons (the cases): the case under the pointer, the case pressed, whether the pointer is still over it
	var hovered:InCase;
	var pressTarget:InCase;
	var pressed:Bool = false;
	var onPointerDown:Dynamic;
	// coins falling off the roll (their drop shadow)
	var falls:Array<Fall> = [];
	var orders:Array<Order> = [];
	var pointsList:Array<Points> = [];
	// the planes under DP_INTER, drawn together under wallUp's tapi (overlay)
	var low:ASprite;
	var overlay:OverlayFilter;
	#if debug
	// test harness: what the game went through (window.__over)
	public var stats = {plays: 0, goals: 0, golden: 0, nuts: 0, upward: 0, falls: 0, maxLevel: 5};
	#end

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: new UInt16Array(0),
			recordInputs: false,
			recordEvents: true,
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0),
		});
		if (isReplay)
			initPath();
		// statics of the original (the SWF was loaded again for every game)
		gMove = new Array();
		gGlow = new Array();
		MC.clearAll();
		Clip.reset();
		Sprite.spriteList = [];
		Cs.init();
		// mt.Timer before its first update (Manager.init creates the game before the first Manager.main)
		Timer.tmod = 1;
		Clip.deferring = true;
		// like the Flash player, a case pressed keeps the mouse while the button is held (its release outside the game
		// is still seen)
		if (!isReplay) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			onPointerDown = function(e:Dynamic) {
				try {
					canvas.setPointerCapture(e.pointerId);
				} catch (_:Dynamic) {}
			};
			canvas.addEventListener("pointerdown", onPointerDown);
		}

		// the original's 300x300 pixels, drawn x2
		root = mc.createEmptyMovieClip("scene", 0);
		root._xscale = root._yscale = 100 * Clip.K;
		root.updateState();
		me = this;
		low = new ASprite();
		root.addChild(low);
		overlay = new OverlayFilter();
		low.filters = [overlay];
		mdm = new Plans(root, null, low, DP_INTER);

		flGameOver = false;

		initBg();
		initGame();

		Clip.deferring = false;
		Clip.runLater();
		MC.displayAll(1);
		displayShadows();
		// Flash shows the first picture after the first frame (Manager.init, then Manager.main)
		root.visible = false;
		warmShaders();
	}

	function initBg() {
		var bg = mdm.attach("mcBg", DP_BG);
		bg._x = 0;
		bg._y = 0;
	}

	function initGame() {
		// (mdm = new mt.DepthManager(root): a second manager of the same clip, nothing of it is attached again)
		level = Cs.INIT_LEVEL;

		initMcs();
		initRoll();
		initHero();
		goalCount = 0;
		setGoal();
		initPlays();
		step = Door;
		timer = 0.0;

		mcDoor = mdm.attach("door", DP_DOOR);
	}

	function initMcs() {
		var y = 23;
		var x = Cs.HOLE_X;

		holes = new Array();

		var submc = mdm.attach("subRoll", DP_SUB_PARTS);
		submc._x = 1;
		submc._y = 6;

		var mc = mdm.attach("blockHole", DP_HOLE);
		mc._x = 262.5;
		mc._y = 244;

		// (cast mc)._empty.createEmptyMovieClip("mcLock2", 1): _empty is a picture of blockHole
		var empty = mc.clip.get("_empty");
		var mcLock = mc.attachIn(empty, Clip.EMPTY, Clip.K * mc.clip.def.r);
		var count = mc.sub("_count");
		var cf = new Digits(Data.COUNT_FIELD, Data.ADV14, Clip.K * count.def.r);
		count.addChild(cf);

		var h:Hole = {
			id: 0,
			mc: mc,
			mcLock: mcLock,
			locks: new Array(),
			count: 0,
			field: cf
		};

		mc.sub("_wheel").gotoAndStop(1);
		holes.push(h);
		h.count = 0;
		addLocks(Cs.INIT_COUNT);
		for (m in holes[0].locks)
			m.gotoAndStop(m._currentframe);

		for (i in 1...level) {
			mc = mdm.attach("order", DP_HOLE);
			mc._x = x;
			mc._y = y;
			mc.sub("smc").gotoAndStop(i);

			y += 25;

			h = {
				id: i,
				mc: mc,
				mcLock: null,
				locks: new Array(),
				count: 0,
				field: holeField(mc, i)
			};
			h.count = 0;
			h.field.visible = false;
			holes.push(h);
		}

		mcWall = mdm.attach("wallUp", DP_INTER);
	}

	function initRoll() {
		mcRoll = mdm.empty(DP_ROLL);
		mcRoll._x = 20;
		rolldm = new Plans(mcRoll.clip, mcRoll);

		roll = new Array();

		createLine(Cs.ROLL_LENGTH);
	}

	function initHero() {
		heroX = Seed.random(3) + 1;
		heroY = 8;

		var ch = roll[heroY].line[heroX];
		ch.coin.kill();

		var pos = getHeroPos();
		mcHero = mdm.attach("hero", DP_HERO);
		mcHero._x = pos.x;
		mcHero._y = pos.y;
	}

	function setGoal() {
		var oldId:Null<Int> = null;
		if (goal != null) {
			goalCount += 1;

			if (goalCount == Cs.GOAL_UP_LEVEL)
				upLevel();

			holes[goal.id].field.visible = false;
			oldId = goal.id;

			var hm = holes[goal.id].mc;
			var gm:Move = {
				setX: function(v) hm._x = v,
				timer: 0.0,
				speed: 0.05,
				func: function(x:Float) {
					return 1 - AnimFunc.bounce(1 - x);
				},
				start: {x: hm._x, y: 0.0},
				end: {x: Cs.HOLE_X, y: 0.0}
			};

			gMove.push(gm);
			#if debug
			stats.goals++;
			#end
		}

		goal = {id: null, goal: 0, count: 0};
		while (goal.id == null) {
			goal.id = Seed.random(level - 2) + 1;

			if (oldId != null && goal.id == oldId)
				goal.id = null;
		}
		goal.goal = Std.int(level / 2 + Seed.random(level));
		goal.count = 0;

		holes[goal.id].field.setText(Std.string(goal.goal));
		holes[goal.id].field.visible = true;

		var hm = holes[goal.id].mc;
		var gm:Move = {
			setX: function(v) hm._x = v,
			timer: 0.0,
			speed: 0.05,
			func: function(x:Float) {
				return 1 - AnimFunc.bounce(1 - x);
			},
			start: {x: hm._x, y: 0.0},
			end: {x: Cs.GOAL_X, y: 0.0}
		};

		gMove.push(gm);
	}

	function upLevel() {
		if (level == 8)
			return;

		level = Std.int(Math.min(8, level + 1));
		goalCount = 0;

		var mc = mdm.attach("order", DP_HOLE);
		mc._x = Cs.HOLE_X;
		mc._y = holes[holes.length - 1].mc._y + 25;
		mc.sub("smc").gotoAndStop(level - 1);

		var h:Hole = {
			id: level - 1,
			mc: mc,
			mcLock: null,
			locks: new Array(),
			count: 0,
			field: holeField(mc, level - 1)
		};
		h.count = 0;
		h.field.visible = false;
		holes.push(h);
		#if debug
		stats.maxLevel = level;
		#end
	}

	public function getHeroPos():{x:Float, y:Float} {
		return {
			x: mcRoll._x + roll[heroY].mc._x + roll[heroY].line[heroX].mc._x,
			y: mcRoll._y + roll[heroY].mc._y + roll[heroY].line[heroX].mc._y
		};
	}

	public function getCasePos(c:InCase):{x:Float, y:Float} {
		return {
			x: mcRoll._x + roll[c.l.index].mc._x + roll[c.l.index].line[c.index].mc._x,
			y: mcRoll._y + roll[c.l.index].mc._y + roll[c.l.index].line[c.index].mc._y
		};
	}

	// (undefined once the hero has fallen: heroX / heroY null)
	public function getHeroCase():InCase {
		if (heroX == null || heroY == null)
			return null;
		return roll[heroY].line[heroX];
	}

	public function setHeroCase(c:InCase) {
		heroX = c.index;
		heroY = c.l.index;
	}

	public function isGoalComplete():Bool {
		return goal != null && goal.count == 0 && lastWasGoal;
	}

	function getLevel():Int {
		if (Seed.random(1300) == 0)
			return Cs.GOLDEN_COIN;

		return Seed.random(level);
	}

	// (cheatDetected / KKApi.flagCheater: the PArray protection of the original, nothing to port)
	function origUpdate() {
		updateSprites();
		updateGoalMoves();
		updateGlow();

		if (step != GameOver) {
			// (a fallen hero: getCasePos(undefined) gives NaN, the rotation is not changed)
			var hc = getHeroCase();
			if (hc != null) {
				var hp = getCasePos(hc);
				Cs.rotateMc(mcHero, mouseX, mouseY, hp.x, hp.y);
			}
		}

		switch (step) {
			case Door:
				timer = Math.min(timer + 0.03 * Timer.tmod, 1.0);

				var f = AnimFunc.quint;
				var d = if (timer <= 0.5) f(2 * timer) / 2 else ((2 - f(2 * (1 - timer))) / 2);

				mcDoor.setSub("_top", null, (1 - d) - Data.DOOR_TOP_HEIGHT * d);
				mcDoor.setSub("_bottom", null, Cs.mch * (1 - d) + (Cs.mch + Data.DOOR_BOTTOM_HEIGHT) * d);

				if (timer == 1) {
					step = Play;
					timer = 0.0;
				}

			case Play:
				if (flGameOver) {
					gameOver();
					timer = 0.0;
					step = GameOver;
				}

			case Move(s, e, c):
				if (timer < 1.0) {
					timer = Math.min(timer + 0.1 * Timer.tmod, 1.0);
					var d = 1 - AnimFunc.quint(1 - timer);
					mcHero._x = s.x * (1 - d) + e.x * d;
					mcHero._y = s.y * (1 - d) + e.y * d;
				}

				if (dropInfos == null && timer > 0.25) {
					resetParse();
					dropInfos = initCoinDrop(c);
				}

				if (dropInfos != null && dropInfos.timer != null) {
					dropInfos.timer = Math.min(dropInfos.timer + 0.14 * Timer.tmod, 1.0);
					var d = dropInfos.timer;
					for (cc in dropInfos.coins) {
						cc.c.mc._x = cc.spos.x * (1 - d) + cc.tpos.x * d;
						cc.c.mc._y = cc.spos.y * (1 - d) + cc.tpos.y * d;
					}

					if (dropInfos.timer != null && dropInfos.timer == 1.0) {
						addToHole(dropInfos.hole, dropInfos.coins.length);
						for (cc in dropInfos.coins)
							cc.c.kill();
						dropInfos.timer = null;
					}
				}

				if (flagBlockPart != null)
					launchBlockParticles();

				// (dropInfos is null for a frame after the golden coin: undefined.coins.length tests false)
				if (timer == 1
					&& dropInfos != null
					&& ((dropInfos.coins.length > 0 && dropInfos.timer == null) || dropInfos.coins.length == 0)) {
					resetLinks();
					setHeroCase(c);
					startRoll(dropInfos.coins.length == 0, lastWasGoal);
				}

			case Roll(size):
				var s = if (size < 0) -1 else 1;
				var oldTimer = timer;
				timer = Math.min(timer + 0.06 * Timer.tmod / Math.abs(size / 2), 1.0);
				var d = 1 - AnimFunc.bounce(1 - timer);

				for (i in 0...roll.length) {
					var l = roll[i];

					if (l.sy == null) {
						l.sy = l.mc._y;
						l.sc = l.mc._yscale;
					}

					if (l.index - size < 5) {
						var nextPos = l.index - size;
						var startInfos:Array<Float> = if (l.index < 0) [0, 275 + l.index * Cs.ROLL_LINE_Y / 6] else if (l.index < 5)
							Cs.ROLL_VOID_INFOS[l.index] else [100.0, 0];
						var endInfos:Array<Float> = null;
						if (nextPos < 0)
							endInfos = [0, 275 + nextPos * Cs.ROLL_LINE_Y / 6];
						else if (nextPos < 5)
							endInfos = Cs.ROLL_VOID_INFOS[nextPos]
						else
							endInfos = [100.0, 0];

						l.mc._y = (l.sy) * (1 - d) + (endInfos[1]) * d;
						var oldScale = l.mc._yscale;
						l.mc._yscale = startInfos[0] * (1 - d) + (endInfos[0]) * d;

						if (s > 0 && endInfos[0] == 0)
							l.mc._alpha = Math.max(0, 150 - timer * 200);

						if (s < 0 && startInfos[0] == 0)
							l.mc._alpha = Math.min(timer * 400, 100);

						if (s > 0 && nextPos < 3) {
							if (l.mc._yscale < l.fLimit && oldScale >= l.fLimit)
								coinFalls(l);
						}

						var lim = 0.3;
						if (oldTimer <= lim && timer > lim) {
							setLineShadow(l, l.index - size);
						}
					} else {
						if (s > 0)
							l.mc._y = l.sy * (1 - d) + (l.sy + size * Cs.ROLL_LINE_Y) * d;
						else {
							l.mc._y = l.sy * (1 - d) + (Cs.ROLL_BOTTOM - (l.index - size) * Cs.ROLL_LINE_Y) * d;
							if (l.sc != 100)
								l.mc._yscale = l.sc * (1 - d) + (100) * d;
						}
					}

					if (timer == 1)
						l.sy = null;
				}

				if (heroX != null)
					mcHero._y = hsy * (1 - d) + (hsy + size * Cs.ROLL_LINE_Y) * d;

				if (timer == 1) {
					timer = 0.0;
					recalRoll(size);
					step = Play;
				}

			case GameOver:
				if (timer != null) {
					timer = Math.min(timer + 0.03 * Timer.tmod, 1.0);

					var f = AnimFunc.quint;
					var d = if (timer <= 0.5) f(2 * timer) / 2 else ((2 - f(2 * (1 - timer))) / 2);

					mcDoor.setSub("_top", null, -Data.DOOR_TOP_HEIGHT * (1 - d));
					mcDoor.setSub("_bottom", null, (Cs.mch + Data.DOOR_BOTTOM_HEIGHT) * (1 - d) + Cs.mch * (d));

					if (timer == 1)
						timer = null;
				}
		}
	}

	function addToHole(h:Hole, nb:Int) {
		if (nb <= 0)
			return;

		var gg:Glow = {
			mc: h.mc,
			func: function(x:Float) {
				return 1 - AnimFunc.quint(1 - x);
			},
			start: 2.0,
			end: 0.0,
			speed: 0.05,
			timer: 0.0
		};
		Game.gGlow.push(gg);

		if (goal != null && h.id == goal.id) {
			lastWasGoal = true;

			var d = Std.int(Math.max(0, goal.goal - goal.count));

			h.field.setText(Std.string(d));

			if (d == 0) // goal complete
				setGoal();
		} else if (h.id == 0) {
			// (h.mc._field.text = ...: blockHole has no _field)
		}
	}

	function coinFalls(l:RollLine) {
		for (c in l.line) {
			var hasHero = c == getHeroCase();
			if (c.coin == null && !hasHero)
				continue;

			if (c.coin != null) {
				var mc = mdm.empty(DP_PARTS);
				// (it replaces the coin of the case, killed below)
				mc.showAtOnce();
				// (cmc.filters = [new DropShadowFilter(2, -90, 0x171B24, 5, 1, 1, 0.6)]: its silhouette under it)
				var sil = newSilhouette("coinW", mc.clip);
				var cmc = mc.attach("coin");
				cmc.showAtOnce();

				cmc.gotoAndStop(c.coin.id + 1);

				var p = getCasePos(c);
				mc._x = p.x + c.coin.mc._x;
				mc._y = p.y + c.coin.mc._y;

				cmc._yscale = l.mc._yscale;
				// (the alpha of its fade applies to the coin drawn with its shadow)
				mc.groupAlpha = true;
				sil.texture = Tex.get("coinW")[c.coin.id];
				falls.push({mc: mc, cmc: cmc, sil: sil});

				var sp = new FPhys(mc);

				sp.x = mc._x;
				sp.y = mc._y;
				sp.vsc = 0.97;
				sp.timer = 25 + Seed.randomVfx(15);
				sp.fadeType = 6;

				sp.weight = -0.055;

				var vx = (c.index - 2) * -0.35;

				sp.vx = vx;
				sp.vy = 2.75;
				sp.frict = 0.95;

				sp.onEnd = vanish.bind(sp);

				c.coin.kill();
				#if debug
				stats.falls++;
				#end
			}

			if (hasHero)
				heroFall();
		}
	}

	public function heroFall() {
		var sp = new FPhys(mcHero);

		sp.x = mcHero._x;
		sp.y = mcHero._y;
		sp.vsc = 0.97;
		sp.timer = 25 + Seed.randomVfx(15);
		sp.fadeType = 6;

		sp.weight = -0.055;
		sp.vx = (Seed.randomVfx(2) * 2 - 1) * Seed.randomVfx(6) / 20;
		sp.vy = 2.75;
		sp.frict = 0.95;

		sp.onEnd = vanish.bind(sp);

		heroX = null;
		heroY = null;
		setGameOver();
	}

	function startRoll(?noDrop = false, ?isGoal = false) {
		var size = if (noDrop) 4 else 3;

		if (isGoalComplete())
			size = Std.int(Math.min(Cs.GOAL_ROLL_UPWARD, Cs.UP_LIMIT - 2 - heroY)) * -1;

		if (size > 0 && (holes[0].count > 0 || lastLockPlay != null))
			size -= 2;

		holes[0].field.setText(Std.string(holes[0].count));

		oldDeltaRoll = 0.0;
		timer = 0.0;
		hsy = mcHero._y;

		if (size > 0) {
			for (i in (roll.length - 3)...roll.length) {
				var l = roll[i];
				if (l.tokened)
					continue;
				l.tokened = true;
				for (c in l.line) {
					if (c.coin != null)
						c.coin.mc._visible = true;
				}
			}
		}
		#if debug
		if (size < 0)
			stats.upward++;
		#end

		var ls = if (size < 0) size else Std.int(Math.max(0, size - (roll.length - Cs.ROLL_LENGTH)));
		createLine(ls);

		if (size != 0)
			step = Roll(size);
		else {
			recalRoll(0);
			step = Play;
		}
	}

	function recalRoll(size:Int) {
		for (i in 0...size) {
			var l = roll.shift();
			l.mc.removeMovieClip();
		}

		flagBlockPart = null;

		var w = holes[0].mc.sub("_wheel");
		w.gotoAndStop(w.frame);
		for (m in holes[0].locks) {
			m.gotoAndStop(m._currentframe);
		}

		for (i in 0...roll.length) {
			roll[i].index = i;
		}

		if (heroY != null)
			heroY = heroY - size;
		initPlays();
	}

	function setLineShadow(l:RollLine, index:Int) {
		var d = Std.int(Math.max(1, (6 - index) / 2));
		l.shadowD = d;

		for (c in l.line) {
			if (c.coin == null)
				continue;
			c.coin.shadowD = d;
		}
	}

	function addLocks(n:Int) {
		var h = holes[0];
		var old = h.count;
		h.count += n;
		h.field.setText(Std.string(h.count));

		var w = 0;

		for (i in 0...n) {
			var mc = h.mcLock.attach("ecrou_2");
			mc._x = 10 - 8 * (old + i + 1);

			mc.gotoAndPlay(Seed.randomVfx(5) + 1);
			mc._y = 0;
			w += 8;
			h.locks.push(mc);
		}

		var f = function(x:Float) {
			return 1 - AnimFunc.quint(1 - x);
		};
		var lock = h.mcLock;
		var m1:Move = {
			setX: function(v) lock._x = v,
			timer: 0.0,
			speed: 0.05,
			func: f,
			start: {x: h.mcLock._x, y: 0.0},
			end: {x: h.mcLock._x + w, y: 0.0}
		};

		var hm = h.mc;
		var bx = h.mc.subX("_bounce");
		var m2:Move = {
			setX: function(v) hm.setSub("_bounce", v),
			timer: 0.0,
			speed: 0.05,
			func: f,
			start: {x: bx, y: 0.0},
			end: {x: bx + w, y: 0.0}
		};

		chainBlockMove(m1, m2);

		h.field.setText(Std.string(holes[0].count));
		#if debug
		stats.nuts += n;
		#end
	}

	function removeLock(n:Int) {
		var h = holes[0];
		if (h.count - n < 0)
			n = h.count;

		var old = h.count;
		h.count -= n;
		h.field.setText(Std.string(h.count));

		var w = 0;
		for (i in 0...n) {
			var mc = h.locks.pop();
			mc.removeMovieClip();

			w += 8;
		}

		var f = function(x:Float) {
			return 1 - AnimFunc.elastic(1, 1 - x);
		};
		var lock = h.mcLock;
		var m1:Move = {
			setX: function(v) lock._x = v,
			timer: 0.0,
			speed: 0.05,
			func: f,
			start: {x: h.mcLock._x, y: 0.0},
			end: {x: h.mcLock._x - w, y: 0.0}
		};

		var hm = h.mc;
		var bx = h.mc.subX("_bounce");
		var m2:Move = {
			setX: function(v) hm.setSub("_bounce", v),
			timer: 0.0,
			speed: 0.05,
			func: f,
			start: {x: bx, y: 0.0},
			end: {x: bx - w, y: 0.0}
		};

		chainBlockMove(m1, m2);

		h.field.setText(Std.string(holes[0].count));
	}

	// the end of addLocks / removeLock: the moves start now, or when the current one is over
	function chainBlockMove(m1:Move, m2:Move) {
		if (currentBlockMove == null) {
			gMove.push(m1);
			gMove.push(m2);
			currentBlockMove = {
				m: m1,
				onEnd: function() {
					Game.me.currentBlockMove = null;
				}
			};
		} else {
			currentBlockMove.onEnd = function() {
				Game.me.currentBlockMove = {
					m: m1,
					onEnd: function() {
						Game.me.currentBlockMove = null;
					}
				};
				Game.gMove.push(m1);
				Game.gMove.push(m2);
			};
		}
	}

	function createLine(nb:Int) {
		if (nb == 0)
			return;

		var s = if (nb > 0) 1 else -1;
		var from = if (s > 0) roll.length - 1 else 0;
		nb = Std.int(Math.abs(nb));

		var ly:Float = if (roll.length == 0) Cs.ROLL_BOTTOM; else roll[from].mc._y - Cs.ROLL_LINE_Y;
		var r = if (roll.length == 0 || roll[from].recal == 0) Cs.ROLL_LINE_RECAL else 0.0;

		var begin = roll.length;
		var end = roll.length + nb;
		if (s < 0) {
			begin = 1;
			end = nb + 1;
		}

		for (ii in begin...end) {
			var i = ii * s;
			var l:RollLine = {
				index: null,
				mc: rolldm.empty(i),
				recal: r,
				line: new Array(),
				sy: null,
				sc: null,
				fLimit: 50.0 + Seed.random(10),
				tokened: null,
				shadowD: 0,
				shade: null,
				shadeFilter: null
			};
			l.index = i;
			l.mc._y = ly;
			l.mc._x = r;
			// port: the line has a drop shadow (cached as a bitmap): its alpha is the one of the whole picture
			l.mc.groupAlpha = true;
			l.shade = new ASprite();
			l.mc.clip.addChild(l.shade);
			ly -= Cs.ROLL_LINE_Y;
			for (j in 0...Cs.CASE_PER_LINE) {
				var c:InCase = {
					mc: l.mc.attach("case"),
					coin: null,
					l: l,
					index: null,
					links: null,
					parsed: false,
					focus: false,
					rim: null,
					sil: null
				};

				c.index = j;
				c.mc._x = j * Cs.ROLL_LINE_X;
				c.mc._y = 0;

				if (i >= 3) {
					c.coin = new Coin(getLevel(), c.mc);
					c.coin.myCase = c;
				}
				// port: the focus glow over the case, the silhouettes of the line's shadow (case, coin, coin's shadow)
				c.rim = newSilhouette("caseRim", c.mc.clip);
				c.sil = [
					newSilhouette("caseW", l.shade),
					newSilhouette("coinW", l.shade),
					newSilhouette("coinW", l.shade)
				];

				// (onRollOver / onRollOut / onReleaseOutside / onRelease: see updateMouse)
				l.line.push(c);
			}

			if (i < 0) {
				l.mc._yscale = 0;
				l.mc._alpha = 0;
				l.mc._y = 275 + i * Cs.ROLL_LINE_Y / 6;
			} else if (i < 4) {
				l.mc._yscale = Cs.ROLL_VOID_INFOS[i][0];
				l.mc._y = Cs.ROLL_VOID_INFOS[i][1];
			}

			if (s > 0)
				roll.push(l);
			else
				roll.unshift(l);

			if (r > 0)
				r = 0.0;
			else
				r = Cs.ROLL_LINE_RECAL;
		}

		for (i in 0...roll.length) {
			var l = roll[i];

			setLineShadow(l, i);

			rolldm.swap(l.mc, l.index);
			if (l.tokened == null) {
				if (s > 0 && i >= roll.length - 1) {
					l.tokened = false;
					for (c in l.line) {
						if (c.coin != null)
							c.coin.mc._visible = false;
					}
				} else
					l.tokened = true;
			}
		}
	}

	function initCoinDrop(c:InCase):DropInfos {
		var th:Hole = null;

		lastLockPlay = null;

		if (c.coin == null) {
			if (holes[0].count > 0) {
				removeLock(1);
				makeBlockParticles(c);
				lastLockPlay = 1;
			}
			return {hole: null, timer: null, coins: []};
		}

		if (c.coin.id == Cs.GOLDEN_COIN) { // BONUS
			c.coin.kill();
			setScore(c, Cs.GOLDEN_BONUS);
			#if debug
			stats.golden++;
			#end
		} else {
			for (h in holes) {
				if (h.id == c.coin.id) {
					th = h;
					break;
				}
			}
		}

		if (th == null) {
			return null;
		}

		var res:DropInfos = {
			hole: th,
			coins: new Array(),
			timer: 0.0
		}

		var dp = 8.0;

		if (th.id == 0) {
			lastLockPlay = c.links.length;
			makeBlockParticles(c);
			addLocks(c.links.length - 1);
		} else {
			if (holes[0].count > 0) {
				removeLock(1);
				makeBlockParticles(c);
				lastLockPlay = 1;
			}
			th.count += c.links.length;
			if (th.id == goal.id)
				goal.count += c.links.length;
		}

		for (cc in c.links) {
			var nc = cc.coin.copy(mdm, DP_COIN);
			var p = getCasePos(cc);
			nc.mc._x = p.x + cc.coin.mc._x;
			nc.mc._y = p.y + cc.coin.mc._y;

			res.coins.push({
				h: 10.0 + Seed.randomVfx(60),
				c: nc,
				spos: {x: nc.mc._x, y: nc.mc._y},
				tpos: {
					x: th.mc._x + dp / 2 + Seed.randomVfx(Std.int(dp / 2)),
					y: th.mc._y + dp / 2 + Seed.randomVfx(Std.int(dp / 2))
				}
			});

			if (th.id > 0) {
				if (th.id == goal.id) {
					setScore(cc, KKApi.cadd(Cs.GOAL_POINTS, KKApi.cmult(KKApi.const(c.links.length), Cs.MULTI_BONUS)));
				} else
					setScore(cc, KKApi.cadd(Cs.POINTS, KKApi.cmult(KKApi.const(c.links.length), Cs.MULTI_BONUS)));
			}

			cc.coin.kill();
		}

		return res;
	}

	function parseLinks(c:InCase) {
		resetParse();
		if (c.coin == null || c.coin.id == Cs.GOLDEN_COIN) {
			c.links = [c];
		} else {
			c.links = parseL(c);
			for (cc in c.links) {
				cc.links = c.links;
			}
		}
	}

	function resetLinks() {
		for (r in roll) {
			for (c in r.line) {
				c.links = null;
			}
		}
	}

	function resetParse(?v = false) {
		lastParse = null;
		for (r in roll) {
			for (c in r.line) {
				c.parsed = v;
				c.focus = false;
			}
		}
		var hc = getHeroCase();
		if (hc != null)
			hc.parsed = true;
	}

	function parseL(c:InCase):Array<InCase> {
		var res = [c];
		c.parsed = true;

		for (pos in Cs.getAround(c)) {
			var nc = getCase(c.index + pos[0], c.l.index + pos[1]);
			if (nc == null || nc.parsed || nc.l.index > Cs.UP_LIMIT)
				continue;

			nc.parsed = true;
			if (nc.coin == null || nc.coin.id != c.coin.id || nc.coin.mc._visible == false || c.l.index >= Cs.UP_LIMIT)
				continue;
			res = res.concat(parseL(nc));
		}

		return res;
	}

	public function getCase(x:Int, y:Int):InCase {
		if (x < 0 || x >= Cs.CASE_PER_LINE || y < 0 || y >= Cs.ROLL_LENGTH)
			return null;

		return roll[y].line[x];
	}

	public function canBePlayed(c:InCase):Bool {
		if (c.l.index < Cs.DOWN_LIMIT || c.l.index > Cs.UP_LIMIT - 1 || heroX == null)
			return false;
		var diff = [c.index - heroX, c.l.index - heroY];

		for (p in Cs.getAround(getHeroCase())) {
			if (p[0] == diff[0] && p[1] == diff[1])
				return true;
		}
		return false;
	}

	public function caseOver(c:InCase) {
		if (step != Play)
			return;

		if (c.links == null) {
			setFocus(null);
		} else {
			var p = canBePlayed(c);
			if (!p)
				setFocus(null);
			else {
				if (lastParse != c.links)
					setFocus(c.links);
			}
		}
	}

	function setFocus(t:Array<InCase>) {
		if (lastParse != null) {
			for (c in lastParse) {
				c.focus = false;
			}
		}

		lastParse = t;
		if (t != null) {
			for (c in t) {
				// Filt.glow(c.mc, 2, 10, 0xFFFFFF, true)
				c.focus = true;
			}
		}
	}

	public function caseOut(c:InCase) {
		// nothing to do
	}

	function initPlays() {
		var hc = getHeroCase();
		var focus = null;

		for (pos in Cs.getAround(hc)) {
			// (out of the roll, or no hero: c is undefined, its tests are false and parseLinks only resets the parse)
			var c = hc == null ? null : getCase(hc.index + pos[0], hc.l.index + pos[1]);
			if (c == null) {
				resetParse();
				continue;
			}

			if (c.l.index < Cs.DOWN_LIMIT || c.l.index > Cs.UP_LIMIT)
				continue;

			parseLinks(c);

			if (caseBoundsHit(c, mouseX, mouseY)) {
				focus = c.links;
			}
		}

		if (focus != null)
			setFocus(focus);
	}

	function isCompletingGoal(c:InCase):Bool {
		return goal != null && c.coin != null && c.coin.id == goal.id && goal.goal <= goal.count + c.links.length;
	}

	public function play(c:InCase) {
		if (step != Play || !canBePlayed(c))
			return;
		recordPlay(c);

		timer = 0.0;
		dropInfos = null;
		lastWasGoal = false;
		#if debug
		stats.plays++;
		#end

		var d = 0;
		if (isCompletingGoal(c)) // goal complete
			d += 6;

		var w = holes[0].mc.sub("_wheel");
		w.gotoAndPlay(w.frame + (if (w.frame > 6) -6 else 0) + d);
		for (m in holes[0].locks) {
			m.gotoAndPlay(m._currentframe + (if (m._currentframe > 6) -6 else 0) + d);
		}

		if (d == 0) {
			if (roll[0].recal > 0) {
				if (!roll[19].tokened) {
					mcWall.sub("_p1").gotoAndPlay(4);
				}
			} else {
				if (!roll[19].tokened)
					mcWall.sub("_p2").gotoAndPlay(4);
			}
		}

		step = Move(getCasePos(getHeroCase()), getCasePos(c), c);
	}

	function updateSprites() {
		var list = Sprite.spriteList.copy();
		for (sp in list)
			sp.update();
	}

	public function setGameOver() {
		flGameOver = true;
	}

	function updateGlow() {
		var list = Game.gGlow.copy();
		for (m in list) {
			m.timer = Math.min(m.timer + m.speed * Timer.tmod, 1.0);
			var d = m.func(m.timer);

			// m.mc.filters = []; Filt.glow(m.mc, 40, ..., 0xFFFFFF, true)
			setGlow(m.mc, m.start * (1 - d) + m.end * d);

			if (m.timer == 1) {
				Game.gGlow.remove(m);
			}
		}
	}

	function updateGoalMoves() {
		var list = Game.gMove.copy();
		for (m in list) {
			m.timer = Math.min(m.timer + m.speed * Timer.tmod, 1.0);
			var d = m.func(m.timer);
			m.setX(m.start.x * (1 - d) + m.end.x * d);

			if (m.timer == 1) {
				if (currentBlockMove != null && currentBlockMove.m == m)
					currentBlockMove.onEnd();

				Game.gMove.remove(m);
			}
		}
	}

	function setScore(c:InCase, sc:KKConst) {
		var mc = mdm.attach("points", DP_PARTS);
		var pp = mc.clip.get("_p");
		var t = new Digits(Data.P_FIELD, Data.ADV12, Clip.K * mc.clip.def.r);
		pp.addChild(t);
		t.setText(Std.string(KKApi.val(sc)));
		pointsList.push({mc: mc, p: pp, t: t});
		var p = getCasePos(c);
		mc._x = p.x;
		mc._y = p.y;

		addScore(sc);
	}

	public function addScore(sc:KKConst) {
		if (over)
			return;
		KadoKadeoManager.kkm.addScore(KKApi.val(sc));
	}

	function makeBlockParticles(c:InCase) {
		if (!isCompletingGoal(c))
			flagBlockPart = 50;
	}

	function launchBlockParticles() {
		var nb = Std.int(flagBlockPart / 6);
		var s = 1;

		for (i in 0...nb) {
			var mc = mdm.attach("parts", DP_PARTS);
			mc.blendAdd();

			var sc = 80 + Seed.randomVfx(40);
			mc._xscale = sc;
			mc._yscale = sc;

			var p = new Phys(mc);
			p.x = holes[0].mc._x + Seed.randomVfx(2) + 3;
			p.y = holes[0].mc._y - 4 + i * (25 / nb) + Seed.randomVfx(1);

			p.frict = 0.97;
			p.timer = 5 + Seed.randomVfx(15);
			p.fadeType = 6;
			p.weight = Seed.randVfx() / 5;

			p.vx = Seed.randVfx() * 3.5;
			p.vy = s * Seed.randVfx() * 20 * (if (Seed.randomVfx(25) == 0) -1 else 1);
		}

		flagBlockPart -= 5;
		if (flagBlockPart < 0)
			flagBlockPart = null;
	}

	public static function vanish(s:FPhys) {
		var mc = Game.me.mdm.attach("vanish", Game.DP_SUB_PARTS);
		mc.blendAdd();
		mc.gotoAndPlay(10 + Seed.randomVfx(15));
		mc._rotation = Seed.randomVfx(360);
		var sp = new FPhys(mc);
		sp.x = s.x;
		sp.y = s.y;
		sp.fadeType = 6;
		sp.timer = 40;
	}

	// ================================================================ port
	// order.smc._field: the text field of the hole of colour i (frame i of smc)
	function holeField(mc:MC, i:Int):Digits {
		var smc = mc.sub("smc");
		var f = new Digits(Data.HOLE_FIELDS[i - 1], Data.ADV14, Clip.K * smc.def.r);
		smc.addChild(f);
		f.setText("99");
		// the hole coming in, blurred (frames 1..ORDER_INTRO)
		var intro = newSilhouette("orderIn" + i, mc.clip);
		orders.push({mc: mc, color: i, intro: intro});
		return f;
	}

	// a white silhouette (drop shadows, focus glow), hidden until displayShadows shows it
	public function newSilhouette(anim:String, parent:Container):ASprite {
		var s = new ASprite();
		var t = Tex.get(anim);
		s.texture = t[0];
		s.anchor.copyFrom(t[0].defaultAnchor);
		s.visible = false;
		parent.addChild(s);
		return s;
	}

	// the glow of a hole (one inner GlowFilter, replaced each frame by updateGlow)
	var glows:Map<MC, FlashGlow> = new Map();

	function setGlow(mc:MC, strength:Float) {
		var g = glows.get(mc);
		if (strength <= 0 || mc.removed) {
			if (g != null) {
				mc.clip.filters = null;
				glows.remove(mc);
			}
			return;
		}
		if (g == null) {
			g = new FlashGlow(40, strength, 0xFFFFFF);
			glows.set(mc, g);
			mc.clip.filters = [g];
		}
		g.setStrength(strength);
	}

	public function stageRoot():ASprite {
		return root;
	}

	// ---------------------------------------------------------------- KadoKadeo step: 5 Flash frames every 4 steps
	public function update(delta:Float) {
		updateMouse();
		frameAcc += 5;
		while (frameAcc >= 4) {
			frameAcc -= 4;
			flashFrame();
		}
		MC.displayAll(frameAcc / 4);
		displayShadows();
	}

	// one Flash frame: the timelines advance, then Manager.main (tmod ~0.8: Timer settles on 32 / 40), then the frame
	// scripts the code triggered
	function flashFrame() {
		Timer.tmod = 32 / FLASH_FPS;
		MC.frameStart();
		var i = 0;
		while (i < falls.length) {
			if (falls[i].mc.removed)
				falls.splice(i, 1);
			else
				i++;
		}
		Clip.deferring = true;
		origUpdate();
		Clip.deferring = false;
		Clip.runLater();
		frameCount++;
		root.visible = true;
	}

	function gameOver() {
		if (over)
			return;
		#if debug
		untyped js.Browser.window.__over = debugState();
		#end
		KadoKadeoManager.kkm.gameOver({});
		over = true;
	}

	#if debug
	public function debugState():Dynamic {
		var coins = [];
		for (l in roll)
			for (c in l.line)
				coins.push(c.coin == null ? -1 : c.coin.id);
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			level: level,
			goal: goal.id,
			goalLeft: goal.goal - goal.count,
			nuts: holes[0].count,
			rollLength: roll.length,
			coins: coins.join(""),
			stats: haxe.Json.stringify(stats)
		};
	}
	#end

	// ---------------------------------------------------------------- port: the filters of the code (drop shadows, focus)
	// DropShadowFilter(d, -90, colour, 5, 1, 1, 0.6) of setLineShadow and coinFalls: the silhouette of the clip moved d
	// stage pixels up (Flash filters are not scaled with the clip), at 60 %, under it. A line's shadow is the silhouette
	// of everything it holds: the cases (their coins inside them at 100 %); squeezed at the bottom of the roll, its
	// coins and their own shadows stick out of the cases: their silhouettes are drawn together and then at 60 %.
	static inline var LINE_SHADOW = 0x808CBF;
	static inline var COIN_SHADOW = 0x171B24;

	function displayShadows() {
		// order clips: the blurred hole on the first frames
		var i = 0;
		while (i < orders.length) {
			var o = orders[i];
			if (o.mc.removed) {
				orders.splice(i, 1);
				continue;
			}
			var f = o.mc.clip.frame;
			var inIntro = f >= 1 && f <= Data.ORDER_INTRO;
			o.mc.clip.setVisible("smc", !inIntro);
			o.intro.visible = inIntro;
			if (inIntro)
				o.intro.texture = Tex.get("orderIn" + o.color)[f - 1];
			i++;
		}
		// points: DropShadowFilter of _p, its distance on each frame (stage pixels: _p is squeezed at the end)
		i = 0;
		while (i < pointsList.length) {
			var pt = pointsList[i];
			if (pt.mc.removed || pt.mc.clip.selfRemoved) {
				pointsList.splice(i, 1);
				continue;
			}
			var f = pt.mc.clip.frame;
			var sy = pt.p._yscale / 100;
			if (f >= 1 && f <= Data.P_SHADOW.length)
				pt.t.setShadow(Data.P_SHADOW[f - 1], sy);
			i++;
		}
		for (l in roll) {
			if (l.mc.removed)
				continue;
			var ys = l.mc.shownYScale;
			var on = l.shadowD > 0 && ys > 0.01;
			l.shade.visible = on;
			var k = ys / 100;
			var squeezed = ys < 99.99;
			if (on) {
				if (squeezed) {
					if (l.shadeFilter == null)
						l.shadeFilter = new AlphaFilter(0.6);
					if (l.shade.filters == null)
						l.shade.filters = [l.shadeFilter];
				} else if (l.shade.filters != null) {
					l.shade.filters = null;
				}
			}
			var off = on ? -l.shadowD / k : 0.0;
			for (c in l.line) {
				var coinOn = c.coin != null && c.coin.mc != null && !c.coin.mc.removed && c.coin.mc._visible;
				var cs = coinOn ? c.coin.shadowD : 0;
				// (line units: Flash pixels, the pictures at K px per Flash pixel)
				var cx = c.mc._x;
				var cy = c.mc._y;
				var s0 = c.sil[0];
				showSil(s0, on, LINE_SHADOW, squeezed ? 100 : 60, cx, cy + off, 1 / Clip.K);
				var s1 = c.sil[1];
				var s2 = c.sil[2];
				if (on && squeezed && coinOn) {
					var t = Tex.get("coinW")[c.coin.id];
					s1.texture = t;
					s2.texture = t;
					showSil(s1, true, LINE_SHADOW, 100, cx + c.coin.mc._x, cy + c.coin.mc._y + off, 1 / Clip.K);
					showSil(s2, cs > 0, LINE_SHADOW, 100, cx + c.coin.mc._x, cy + c.coin.mc._y + off - cs / k, 1 / Clip.K);
				} else {
					s1.visible = false;
					s2.visible = false;
				}
				// the coin's own shadow, in the case (its pixels: K per Flash pixel)
				if (c.coin != null && c.coin.shadow != null) {
					var sh = c.coin.shadow;
					if (coinOn && cs > 0 && ys > 0.01) {
						sh.texture = Tex.get("coinW")[c.coin.id];
						showSil(sh, true, COIN_SHADOW, 60, c.coin.mc._x * Clip.K, (c.coin.mc._y - cs / k) * Clip.K, 1);
					} else
						sh.visible = false;
				}
				// the focus glow (Filt.glow(c.mc, 2, 10, 0xFFFFFF, true)): the overlay drawn for the scale of the line
				var rim = c.rim;
				if (c.focus && ys > 0.01) {
					var fi = Math.abs(ys - Data.RIM_SCALES[0]) <= Math.abs(ys - Data.RIM_SCALES[1]) ? 0 : 1;
					rim.texture = Tex.get("caseRim")[fi];
					rim.visible = true;
					rim._x = 0;
					rim._y = 0;
					rim._xscale = 100;
					rim._yscale = 100 * 100 / Data.RIM_SCALES[fi];
					rim._alpha = 100;
				} else
					rim.visible = false;
			}
		}
		// the coins falling off the roll: DropShadowFilter(2, ...) on the coin in its clip
		for (f in falls) {
			if (f.mc.removed)
				continue;
			var k = f.mc.shownYScale / 100 * f.cmc._yscale / 100;
			if (k > 0.001) {
				showSil(f.sil, true, COIN_SHADOW, 60, 0, -2 / (f.mc.shownYScale / 100), 1 / Clip.K);
				f.sil._yscale = f.cmc._yscale / Clip.K;
			} else
				f.sil.visible = false;
		}
	}

	inline function showSil(s:ASprite, on:Bool, color:Int, alpha:Float, x:Float, y:Float, sc:Float) {
		s.visible = on;
		if (on) {
			s.tint = color;
			s._alpha = alpha;
			s._x = x;
			s._y = y;
			s._xscale = s._yscale = sc * 100;
		}
	}

	// ---------------------------------------------------------------- port: mouse
	// The cases are Flash buttons (createLine: onRollOver = caseOver, onRelease = play; onRollOut / onReleaseOutside do
	// nothing). The pointer is polled once per step (the replay only records the plays, see recordPlay): the case under
	// it is the topmost case whose shape covers it (the last line on top). A press on a case and its release on the same
	// case is a click; a press elsewhere and a release on a case is not.
	function updateMouse() {
		Clip.deferring = true;
		if (isReplay)
			replayMouse();
		else
			liveMouse();
		Clip.deferring = false;
		Clip.runLater();
	}

	function liveMouse() {
		setMouse(MouseManager.getX(), MouseManager.getY());
		var under = caseAt(mouseX, mouseY);
		if (!pressed)
			hover(under);
		if (MouseManager.isButtonJustPressed(MouseManager.BUTTON_LEFT)) {
			pressed = true;
			pressTarget = hovered;
		}
		if (MouseManager.isButtonJustReleased(MouseManager.BUTTON_LEFT)) {
			var target = pressTarget;
			pressed = false;
			pressTarget = null;
			if (target != null && under == target) {
				// onRelease (the button stays under the pointer: no new rollOver)
				hovered = target;
				play(target);
			} else {
				// onReleaseOutside: the case under the pointer is rolled over at the next poll
				hovered = null;
			}
		}
	}

	// onRollOver of the case now under the pointer
	function hover(c:InCase) {
		if (c != hovered) {
			hovered = c;
			if (c != null)
				caseOver(c);
		}
	}

	function setMouse(x:Int, y:Int) {
		mousePx = x < 0 ? 0 : x > 1023 ? 1023 : x;
		mousePy = y < 0 ? 0 : y > 1023 ? 1023 : y;
		mouseX = (mousePx + 0.5) / Clip.K;
		mouseY = (mousePy + 0.5) / Clip.K;
	}

	// ---------------------------------------------------------------- port: replay
	// a play is recorded for the step being played: the replay gives it back on the same step, before the Flash frames
	// (updateMouse)
	function recordPlay(c:InCase) {
		if (!isReplay) {
			var replay = KadoKadeoManager.kkm.replay;
			replay.recordEvent(mousePx | (mousePy << 10) | (c.index << 20) | (c.l.index << 23), replay.getCurrentFrame());
		}
	}

	function initPath() {
		path = [];
		for (e in KadoKadeoManager.kkm.replay.getReplayEvents()) {
			var v = Std.int(e.event);
			path.push({f: e.frame, x: ((v & 1023) + 0.5) / Clip.K, y: (((v >> 10) & 1023) + 0.5) / Clip.K});
		}
	}

	// the mouse of a replay: the plays on the step where the player did them; in between, the pointer goes from a play
	// to the next one (only the position of the plays counts), hovering the cases on its way like the player's
	function replayMouse() {
		var replay = KadoKadeoManager.kkm.replay;
		var t = replay.getCurrentFrame();
		while (pathIdx + 1 < path.length && path[pathIdx + 1].f <= t)
			pathIdx++;
		while (pathIdx > 0 && path[pathIdx].f > t)
			pathIdx--;
		if (path.length > 0) {
			var a = path[pathIdx];
			if (t <= a.f || pathIdx + 1 >= path.length) {
				mouseX = a.x;
				mouseY = a.y;
			} else {
				var b = path[pathIdx + 1];
				var dx = b.x - a.x;
				var dy = b.y - a.y;
				var u = Math.min(1, (t - a.f) / Math.min(b.f - a.f, MOVE_BASE + Math.sqrt(dx * dx + dy * dy) / MOVE_SPEED));
				u = u * u * (3 - 2 * u);
				mouseX = a.x + dx * u;
				mouseY = a.y + dy * u;
			}
		}
		hover(caseAt(mouseX, mouseY));
		for (e in replay.consumeEvents()) {
			var v = Std.int(e);
			setMouse(v & 1023, (v >> 10) & 1023);
			var c = getCase((v >> 20) & 7, (v >> 23) & 31);
			if (c != null) {
				// onRelease (see liveMouse)
				hovered = c;
				play(c);
			}
		}
	}

	// the case whose button shape is under the point (Flash pixels)
	function caseAt(fx:Float, fy:Float):InCase {
		var i = roll.length - 1;
		while (i >= 0) {
			var l = roll[i];
			i--;
			var ys = l.mc._yscale;
			if (!(ys > 0) || !l.mc._visible)
				continue;
			var ly = (fy - mcRoll._y - l.mc._y) / (ys / 100);
			var lx = fx - mcRoll._x - l.mc._x;
			for (c in l.line)
				if (hitShape(lx - c.mc._x, ly - c.mc._y))
					return c;
		}
		return null;
	}

	static function hitShape(x:Float, y:Float):Bool {
		var row = Math.floor((y - Data.HIT_Y) * Data.HIT_Z);
		if (row < 0 || row >= Data.HIT_ROWS.length)
			return false;
		var col = (x - Data.HIT_X) * Data.HIT_Z;
		for (r in Data.HIT_ROWS[row])
			if (col >= r[0] && col < r[1])
				return true;
		return false;
	}

	// MovieClip.hitTest(x, y) without shapeFlag (initPlays): the bounds of the case clip on the stage
	function caseBoundsHit(c:InCase, fx:Float, fy:Float):Bool {
		var l = c.l;
		var k = l.mc._yscale / 100;
		var x0 = mcRoll._x + l.mc._x + c.mc._x;
		var y0 = mcRoll._y + l.mc._y + c.mc._y * k;
		var b = Data.CASE_BOUNDS;
		var ya = y0 + b[2] * k;
		var yb = y0 + b[3] * k;
		return fx >= x0 + b[0] && fx <= x0 + b[1] && fy >= Math.min(ya, yb) && fy <= Math.max(ya, yb);
	}

	// ---------------------------------------------------------------- port: shaders
	// The first use of a filter compiles its shader (tens of ms of freeze): the inner glow of the holes and the
	// AlphaFilter of the lines' shadows are drawn once now, off screen
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		if (renderer == null)
			return;
		var holder = new Container();
		var s = new pixi.core.sprites.Sprite(pixi.core.textures.Texture.WHITE);
		s.filters = [new FlashGlow(40, 1, 0xFFFFFF), new AlphaFilter(0.6), new OverlayFilter()];
		holder.addChild(s);
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	public function destroy():Void {
		if (onPointerDown != null) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			if (canvas != null)
				canvas.removeEventListener("pointerdown", onPointerDown);
			onPointerDown = null;
		}
		me = null;
		MC.clearAll();
		Clip.reset();
		Sprite.spriteList = [];
		gMove = new Array();
		gGlow = new Array();
	}
}
