package atlanteine;

import kado.TouchControlsConfig.TouchControlsMode;
import haxe.io.UInt16Array;
import common_haxe_avm1.pixi.DropShadowFilter;
import pixi.core.Pixi.BlendModes;
import pixi.core.math.Matrix;
import pixi.core.graphics.Graphics;
import mt.bumdum.Sprite;
import mt.bumdum.Phys;
import mt.bumdum.Lib;
import common_haxe_avm1.KKApi;
import common_haxe_avm1.KeyboardManager;

class AnonSprite13294744 extends ASprite {
	public var shadow:ASprite;
	public var ball:ASprite;
}

class AnonSprite14226607 extends ASprite {
	public var field:Text;
	public var ring:Graphics;
}

private enum Step {
	Spawn;
	Play;
	Move;
	MoveBlock;
	Next;
	Wait;
	WaitTimer;
	GameOver;
}

private enum DelayedAction {
	SpawnBallAction;
	NextLevelAction;
}

class FieldMC extends ASprite {
	public var field:Text;
}

class Map extends ASprite {
	public var mcGround:McBmp;
	public var mcPlasma:McBmp;
}

class McBmp extends ASprite {
	public var bmp:RenderTexture;
}

class Ppath extends ASprite {
	public var n:Int;
	public var c:Float;
	public var speed:Float;
	public var cs:Float;
	public var dx:Float;
	public var dy:Float;
}

typedef DPoint = {x:Int, y:Int, d:Int};

enum abstract PathType(Int) from Int to Int {
	var EMPTY = 0;
	var PATH = 1;
	var ROCK = 2;
	var MROCK = 22;
	var BLOCK = 3;
	var TELEPORT = 4;
	var OUT = 5;
	var SEA = 6;
}

@:expose('GameAtlanteine')
class Game implements kado.GameInterface {
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		swipe: {
			leftAction: "swipe_left",
			rightAction: "swipe_right",
			upAction: "swipe_up",
			downAction: "swipe_down",
			minDistance: 48,
			maxDurationMs: 300,
		},
	};

	static inline var SWIPE_PRESS_FRAMES = 2;

	public static var FL_DEBUG = false;
	public static var FL_BONUS = false;
	public static var FL_SIZER = false;
	public static var FL_GHOST = true;
	public static var FL_PUSH = true;
	public static var FL_BONUS_BLOCK = true;
	public static var FL_TELEPORT = true;
	public static var BACKGROUND_COLOR = 0x4E8A8F;

	public static var DIR = [[1, 0], [0, 1], [-1, 0], [0, -1]];

	public static var DP_BG = 0;
	public static var DP_LEVEL = 1;
	public static var DP_INTER = 2;
	public static var DP_FRONT = 3;

	public static var DP_GROUND = 1;
	public static var DP_ROCK = 2;
	public static var DP_GHOST = 3;
	public static var DP_PARTS = 4;

	static var SCORE_TIME = KKApi.const(5);
	static var SCORE_BLOCK = KKApi.const(200);

	static var SCORE_GREEN = KKApi.const(200);
	static var SCORE_BLUE = KKApi.const(1000);
	static var SCORE_PINK = KKApi.const(12000);

	public static var mcw = KadoKadeoManager.I(300);
	public static var mch = KadoKadeoManager.I(300);
	public static var SIZE = KadoKadeoManager.I(20);

	static var SPEED = 0.7; // 0.4;
	static var ZOOM_SPEED = 0.1; // 0.05;
	static var HOLE_FADE = 30;
	static var TIME = 800;
	static var TIME_LEVEL_MALUS = 12;
	static var PROBA_PUSH = 5;
	static var SHOW_PATH_LEVEL_LIMIT = 3;

	var flFill:Bool;
	var flPush:Bool;
	var flControl:Bool;

	public var xmax:Int;
	public var ymax:Int;
	public var level:Int;
	public var clevel:Int;
	public var skin:Int;

	var levelTimer:Float;
	var levelTimerMax:Float;
	var delayedActions:Array<{timer:Float, action:DelayedAction}>;

	public var dif:Float;

	public var step:Step;

	// BALL
	var ball:Sprite;
	var mcBall:AnonSprite13294744;
	var x:Int;
	var y:Int;
	var lastDir:Int;
	var move:{d:Int, coef:Float};
	var bvy:Float;
	var disDec:Float;

	var tc:Float;
	var prc:Float;
	var ballFlash:Float;
	// a swipe is a short press of an arrow key (recorded by the replay like the keyboard): the key held, the frames
	// before it is released
	var swipeKey:Null<Int>;
	var swipeFramesLeft:Int;

	var pushInfo:{base:Array<Int>, free:Array<Int>, flDone:Bool};

	public var grid:Array<Array<Int>>;
	public var cache:Array<Array<Int>>;
	public var elements:Array<Array<ASprite>>;
	public var bonus:Array<Array<ASprite>>;
	public var nList:Array<DPoint>;
	public var ppList:Array<Ppath>;
	public var ghostList:Array<Ghost>;
	public var tel:Array<Array<Int>>;
	public var stones:Array<Array<Int>>;

	public var mcPushIcon:ASprite;

	public var mdm:mt.DepthManager;
	public var dm:mt.DepthManager;
	public var bg:ASprite;
	public var mcOut:ASprite;
	public var map:Map;
	public var mcDisplay:McBmp;
	public var prec:Map;
	public var mcTimer:AnonSprite14226607;
	public var stats:{
		s:Array<Array<Int>>, // [per level: [boxesInLevel, ghostsInLevel, boxesMoved, ghostsKilledBySelf, ghostsKilledByBlock, timesKilledByWater, movesCount, hasPushedInLevel]]
	};

	// var dbg:Graphics;

	public function new(root:ASprite) {
		mdm = new mt.DepthManager(root);
		bg = cast mdm.empty(DP_BG);
		bg.getGraphics().beginFill(BACKGROUND_COLOR);
		bg.getGraphics().drawRect(0, 0, mcw, mch);
		// dbg = cast mdm.empty(DP_PARTS).getGraphics();

		xmax = Std.int(mcw / SIZE);
		ymax = Std.int(mch / SIZE);

		stats = {
			s: [],
		};

		dif = 0;
		level = 1;
		clevel = 1;
		skin = 0;
		delayedActions = [];
		flControl = true;
		swipeKey = null;
		swipeFramesLeft = 0;
		step = Step.WaitTimer;
		initTimer();
		initMap();
		spawnBall();

		displayPushIcon();

		var replayKeys = new UInt16Array(10);
		replayKeys[0] = common_haxe_avm1.KeyboardManager.ARROW_RIGHT;
		replayKeys[1] = common_haxe_avm1.KeyboardManager.ARROW_DOWN;
		replayKeys[2] = common_haxe_avm1.KeyboardManager.ARROW_LEFT;
		replayKeys[3] = common_haxe_avm1.KeyboardManager.ARROW_UP;
		replayKeys[4] = common_haxe_avm1.KeyboardManager.D;
		replayKeys[5] = common_haxe_avm1.KeyboardManager.S;
		replayKeys[6] = common_haxe_avm1.KeyboardManager.Q;
		replayKeys[7] = common_haxe_avm1.KeyboardManager.Z;
		replayKeys[8] = common_haxe_avm1.KeyboardManager.A;
		replayKeys[9] = common_haxe_avm1.KeyboardManager.W;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: replayKeys,
			recordInputs: true,
			recordEvents: false,
		});
	}

	function initMap() {
		map = cast mdm.empty(DP_LEVEL);
		dm = new mt.DepthManager(map);

		ppList = null;
		var minimum = Math.min(level * 0.6, 14);

		cache = null;
		while (true) {
			genLevel();
			cache = [];
			for (x in 0...xmax)
				cache.push([]);
			var short = getShortPath(x, y, true, cache);
			if (short > minimum-- && short < 999)
				break;
		}
		drawLevel();
		var boxesInLevel = 0;
		for (a in grid) {
			for (mc in a.filter(n -> n != null)) {
				if (mc == BLOCK) {
					boxesInLevel++;
				}
			}
		}
		#if debug
		if (stats.s.length > 0) {
			trace(stats.s[stats.s.length - 1]);
		}
		#end
		stats.s.push([boxesInLevel, ghostList.length, 0, 0, 0, 0, 0, 0]);
	}

	public function update(ts:Float) {
		// mt.Timer.tmod *= 0.5;
		// SPRITE
		Sprite.updateAll();
		// if (ppList != null) {
		// 	for (mc in ppList) {
		// 		mc.update();
		// 	}
		// }

		prec?.update();

		// #if debug
		// dbg.clear();
		// dbg.beginFill(0x00FF00, 0.5);
		// dbg.drawCircle(ball.x, ball.y, 30);
		// #end

		control();

		// STEP
		switch (step) {
			case Spawn:
				updateSpawn();
			case Play:
				updateAnims();
			case Move:
				updateMove();
			case Next:
				updateNextLevel();
			case WaitTimer:
				updateTimer();
			case GameOver:
			case Wait:
			case MoveBlock:
		}

		if (prc != null) {
			prc--;
			prc *= 0.5;
			if (prc < 1)
				prc = 0;
			Col.setPercentColor(map, prc.int(), 0);
			if (prc <= 0)
				prc = null;
		}
		if (ballFlash != null) {
			ballFlash *= 0.6;
			if (ballFlash < 2)
				ballFlash = 0;
			Col.setColor(ball.root, 0, Std.int(ballFlash));
			if (ballFlash <= 0)
				ballFlash = null;
		}

		updateDisplay();
		updateScheduledActions();
		releaseSwipeKey(false);
	}

	function scheduleAction(action:DelayedAction, delayMs:Int) {
		delayedActions.push({
			timer: delayMs * mt.Timer.wantedFPS / 1000,
			action: action,
		});
	}

	function updateScheduledActions() {
		var i = 0;
		while (i < delayedActions.length) {
			var pending = delayedActions[i];
			pending.timer -= mt.Timer.tmod;
			if (pending.timer <= 0) {
				delayedActions.splice(i, 1);
				switch (pending.action) {
					case SpawnBallAction:
						spawnBall();
					case NextLevelAction:
						nextLevel();
				}
			} else {
				i++;
			}
		}
	}

	// ANIMS
	function updateAnims() {
		// PATH ANIM
		if (ppList != null) {
			if (Seed.randomVfx(5) == 0) {
				var mc:Ppath = cast dm.attach("mcPoint", DP_GROUND);
				mc.n = nList.length - 1;
				mc.c = 0;
				mc.speed = 0.1 + Seed.randVfx() * 0.2;
				mc.dx = (Seed.randVfx() * 2 - 1) * SIZE * 0.5;
				mc.dy = (Seed.randVfx() * 2 - 1) * SIZE * 0.5;
				mc._xscale = mc._yscale = 50 + Seed.randVfx() * 50;
				// mc.blendMode = BlendModes.ADD;
				ppList.push(mc);
				mc.loop = true;
				mc.play();
			}

			var i = ppList.length - 1;
			while (i >= 0) {
				var mc = ppList[i];
				var p0 = nList[mc.n];
				var p1 = nList[mc.n - 1];

				if (p1 == null) {
					mc.removeMovieClip();
					ppList.splice(i--, 1);
					continue;
				}

				if (mc.cs == null)
					mc.cs = 1 / mt.bumdum.Geom.getDist(cast p0, cast p1);
				mc.c += mc.speed * mc.cs * mt.Timer.tmod;

				while (mc.c > 1) {
					mc.c--;
					mc.n--;
					mc.cs = null;
					p0 = nList[mc.n];
					p1 = nList[mc.n - 1];
				}

				if (p1 == null) {
					mc.removeMovieClip();
					ppList.splice(i--, 1);
					continue;
				}

				var px = p0.x * (1 - mc.c) + p1.x * mc.c;
				var py = p0.y * (1 - mc.c) + p1.y * mc.c;
				mc._x = (px + 0.5) * SIZE + mc.dx;
				mc._y = (py + 0.5) * SIZE + mc.dy;

				mc._rotation += mc.speed * 30;

				if (mc.n == 0) {
					mc.removeMovieClip();
					ppList.splice(i--, 1);
					continue;
				}
				i--;
			}
		}
	}

	// CONTROL
	function control() {
		var d = null;
		if (KeyboardManager.isDown(KeyboardManager.RIGHT) || KeyboardManager.isDown(KeyboardManager.D))
			d = 0;
		if (KeyboardManager.isDown(KeyboardManager.DOWN) || KeyboardManager.isDown(KeyboardManager.S))
			d = 1;
		if (KeyboardManager.isDown(KeyboardManager.LEFT)
			|| KeyboardManager.isDown(KeyboardManager.Q)
			|| KeyboardManager.isDown(KeyboardManager.A))
			d = 2;
		if (KeyboardManager.isDown(KeyboardManager.UP)
			|| KeyboardManager.isDown(KeyboardManager.Z)
			|| KeyboardManager.isDown(KeyboardManager.W))
			d = 3;

		if (!flControl && d == null)
			flControl = true;

		if (step != Play)
			return;

		if (d != null && (flControl || lastDir != d)) {
			stats.s[stats.s.length - 1][6]++;
			flControl = false;
			lastDir = d;
			var dir = DIR[d];
			var next = grid[x + dir[0]][y + dir[1]];
			if (!isBlock(x + dir[0], y + dir[1])) {
				step = Move;
				move = {d: d, coef: 0.0}
			} else {
				if (FL_PUSH && next == BLOCK && pushInfo == null && isFree(x + dir[0] * 2, y + dir[1] * 2)) {
					pushInfo = {
						base: [x + dir[0], y + dir[1]],
						free: [x + dir[0] * 2, y + dir[1] * 2],
						flDone: false
					}
					grid[x + dir[0] * 2][y + dir[1] * 2] = BLOCK;
					grid[x + dir[0]][y + dir[1]] = EMPTY;
					stats.s[stats.s.length - 1][2]++;

					step = Move;
					move = {d: d, coef: 0.0};

					hidePushIcon();
				}
			}
		}

		updateTimer();
		checkGhostCol();
	}

	public function onTouchAction(action:String):Void {
		var key:Null<Int> = switch (action) {
			case "swipe_right": KeyboardManager.ARROW_RIGHT;
			case "swipe_down": KeyboardManager.ARROW_DOWN;
			case "swipe_left": KeyboardManager.ARROW_LEFT;
			case "swipe_up": KeyboardManager.ARROW_UP;
			default: null;
		}
		if (key == null)
			return;
		releaseSwipeKey(true);
		KeyboardManager.queueVirtualKeyDown(key);
		swipeKey = key;
		swipeFramesLeft = SWIPE_PRESS_FRAMES;
	}

	// at the end of each frame (now: a new swipe)
	function releaseSwipeKey(now:Bool):Void {
		if (swipeKey == null || (!now && --swipeFramesLeft > 0))
			return;
		KeyboardManager.queueVirtualKeyUp(swipeKey);
		swipeKey = null;
	}

	// BALL
	function initBall() {
		var a = dm.empty(DP_ROCK);
		ball = new Sprite(a);
		// ball.root.anchor.set(0.5, 38 / 71);
		(cast ball.root).ball = ball.root.createEmptyMovieClip();
		(cast ball.root).shadow = ball.root.attachMovie("mcBallShadow", "smc", -1);
		(cast ball.root).shadow.loop = true;
		(cast ball.root).shadow.play();
		(cast ball.root).ball.smc = (cast ball.root).ball.attachMovie("mcBall");
		(cast ball.root).ball.smc.stopOnFrame = [37, 48];
		var last = nList[nList.length - 1];
		x = last.x;
		y = last.y;

		// Filt.glow(ball.root, KadoKadeoManager.I(2), 2, 0xFFFFFF);
		// Filt.glow(ball.root, KadoKadeoManager.I(20), 1, 0xFFFF00);

		ball.x = (x + 0.5) * SIZE;
		ball.y = (y + 0.5) * SIZE;
		updateBallDepths();
	}

	function updateBallDepths() {
		dm.over(ball.root);
		for (py in y + 1...ymax) {
			for (px in 0...xmax) {
				var mc = elements[px][py];
				if (mc != null) {
					dm.over(mc);
				}
			}
		}
	}

	function updateMove() {
		// var mc:{>ASprite,ball:ASprite} = cast ball.root;

		// mc.ball.gotoAndPlay(((mc.ball._currentframe+3)%mc.ball._totalframes)+1);

		var d = DIR[move.d];
		move.coef = move.coef + SPEED * mt.Timer.tmod;
		while (move.coef >= 1) {
			x += d[0];
			y += d[1];

			if (d[1] != 0)
				updateBallDepths();

			// CHECK ACTUAL
			var actual = grid[x][y];
			switch (actual) {
				case SEA:
					mcBall.ball.smc.gotoAndPlay(10);
					mcBall.shadow._alpha = 0;
					move.coef = 0;
					if (isFree(x, y + 1)) {
						move.coef += 0.2;
						ball.y -= 17;
						ball.root._y -= 17;
					}
					mcBall.filters = [];
					killBall();
					stats.s[stats.s.length - 1][5]++;
					break;
				case OUT:
					finishLevel();
					break;
				case TELEPORT:
					move.coef = 0;
					var p = getTeleportPos(x, y);
					x = p[0];
					y = p[1];
					var max = 16;
					var rc = 3;
					var press = 3;
					for (i in 0...max) {
						var a = i / max * 6.28;
						var ca = Math.cos(a);
						var sa = Math.sin(a);
						var speed = 1 + Seed.randVfx() * 4;
						var sp = new Phys(dm.attach("partTiret", DP_PARTS));
						sp.x = p[0] * SIZE + ca * speed * rc;
						sp.y = p[1] * SIZE + sa * speed * rc;
						sp.vx = ca * speed + d[0] * press;
						sp.vy = sa * speed + d[1] * press;
						sp.vr = (Seed.randVfx() * 2 - 1) * 20;
						sp.root._rotation = Seed.randVfx() * 360;
						// sp.weight = -(0.1 + Seed.randVfx() * 0.2);
						sp.setScale(50 + Seed.randVfx() * 100);
						sp.timer = 10 + Seed.randVfx() * 10;
						sp.fadeType = 0;
						sp.root.blendMode = BlendModes.ADD;
						sp.frict = 0.95;
						sp.root.updateState();
					}
					ballFlash = 5000;
					Col.setColor(ball.root, 0, Std.int(ballFlash));

					break;
			}
			var mc = if (bonus != null && bonus[x] != null) bonus[x][y] else null;
			if (mc != null) {
				pickBonus(mc);
				mc.removeMovieClip();
				bonus[x][y] = null;
			}

			// CHECK NEXT
			if (isBlock(x + d[0], y + d[1])) {
				move.coef = 0;
				step = Play;
				break;
			} else {
				move.coef -= 1;
			}
		}
		ball.x = (x + 0.5 + move.coef * d[0]) * SIZE;
		ball.y = (y + 0.5 + move.coef * d[1]) * SIZE;

		//
		if (pushInfo != null && pushInfo.flDone == false) {
			var c = move.coef;
			if (c == 0)
				c = 1;

			pushBlocks(c);
			if (c == 1) {
				pushInfo.flDone = true;
				updateBallDepths();
			}
		}

		//
		updateTimer();
		checkGhostCol();
		updateAnims();
	}

	// ACTION
	function checkGhostCol() {
		for (g in ghostList) {
			var dist = ball.getDist({x: g.x, y: g.y});
			if (dist < KadoKadeoManager.I(10)) {
				g.explode();
				stats.s[stats.s.length - 1][3]++;
				killBall();
				ball.kill();
				levelTimer = Math.max(levelTimer - 100, 0);
				break;
			}
		}
	}

	function getTeleportPos(px, py) {
		for (p in tel) {
			if (p[0] != px || p[1] != py) {
				return p;
			}
		}
		trace("getTeleport ERROR");
		return null;
	}

	function killBall() {
		step = WaitTimer;
		scheduleAction(SpawnBallAction, 500);
	}

	// ROCK
	function pushBlocks(c:Float) {
		var mc = elements[pushInfo.base[0]][pushInfo.base[1]];
		var x = pushInfo.base[0] * (1 - c) + pushInfo.free[0] * c;
		var y = pushInfo.base[1] * (1 - c) + pushInfo.free[1] * c;
		mc._x = x * SIZE;
		mc._y = y * SIZE;
	}

	function displayPushIcon() {
		if (!FL_PUSH)
			return;

		for (a in elements)
			for (mc in a.filter(n -> n != null)) {
				if (mc._name.indexOf('box@') > -1) {
					mc.gotoAndStop(1);
				}
			}
	}

	function hidePushIcon() {
		if (!FL_PUSH)
			return;
		// mcPushIcon.removeMovieClip();
		for (a in elements)
			for (mc in a.filter(n -> n != null)) {
				if (mc._name.indexOf('box@') > -1) {
					mc.gotoAndStop(2);
				}
			}
	}

	// SPAWN
	function spawnBall() {
		initBall();
		step = Spawn;
		bvy = 0;
		mcBall = cast ball.root;
		mcBall.ball.smc._y = KadoKadeoManager.I(-80);
		mcBall.shadow._alpha = 0;
		tc = 0;

		flFill = levelTimer == null;

		if (flFill) {
			levelTimerMax = TIME - level * TIME_LEVEL_MALUS;
			levelTimer = 1;
			flFill = true;
		}
	}

	function updateSpawn() {
		var flNext = false;

		// BALL FALL
		bvy += 2 * mt.Timer.tmod;
		mcBall.ball.smc._y += bvy * mt.Timer.tmod;
		var lim = 0;
		if (mcBall.ball.smc._y > lim) {
			mcBall.ball.smc._y = lim;
			if (bvy > 4 * mt.Timer.tmod) {
				bvy *= -0.4;
			} else {
				if (pushInfo == null) {
					flNext = true;
				}
			}
		}
		mcBall.shadow._alpha = 100 + mcBall.ball.smc._y * KadoKadeoManager.I(2);

		// SPAWN COEF
		tc = Math.min(tc + 0.1 * mt.Timer.tmod, 1);
		if (pushInfo != null) {
			pushBlocks(1 - tc);
			if (tc == 1) {
				grid[pushInfo.base[0]][pushInfo.base[1]] = BLOCK;
				grid[pushInfo.free[0]][pushInfo.free[1]] = EMPTY;
				pushInfo = null;
				displayPushIcon();
			}
		}

		//
		if (flFill && levelTimer < levelTimerMax) {
			var timerMod = (mt.Timer.wantedFPS * mt.Timer.deltaT); // use real time
			levelTimer = Math.min(levelTimer + 40 * timerMod, levelTimerMax);
			updateTimerGfx();
			if (levelTimer == levelTimerMax) {
				var max = 12;
				for (i in 0...max) {
					var p = new Phys(mdm.attach("partCloud", DP_INTER));
					p.root.play();
					p.root.stopOnFrame = [8];
					var a = i / max * 6.28;
					var ray = KadoKadeoManager.I(18);
					var ca = Math.cos(a);
					var sa = Math.sin(a);
					var sp = 0.5 + Seed.randVfx() * 1.5;
					p.x = mcw - KadoKadeoManager.I(20) + ca * ray;
					p.y = mch - KadoKadeoManager.I(20) + sa * ray;
					// p.weight = -(0.1 + Seed.randVfx() * 0.3);
					p.vx = ca * sp;
					p.vy = sa * sp;
					p.timer = 10 + Seed.randVfx() * 10;
					p.fadeType = 0;
					p.frict = 0.9;
					p.root.blendMode = BlendModes.ADD;
					p.setScale(KadoKadeoManager.I(200));
					p.updatePos();
					p.vr = (Seed.randVfx() * 2 - 1) * 30;
					p.root._rotation = Seed.randVfx() * 360;
				}
				flFill = false;
			}
		}

		if (!flFill && flNext)
			step = Play;
	}

	// NEXTLEVEL
	function finishLevel() {
		if (ppList != null) {
			while (ppList.length > 0) {
				var mc:ASprite = ppList.pop();
				var p = new Phys(mc);
				p.timer = 10 + Seed.randVfx() * 5;
				p.updatePos();
			}
		}

		mcBall.ball.smc.gotoAndPlay(40);
		mcBall.shadow._alpha = 0;
		move.coef = 0;
		step = Wait;
		scheduleAction(NextLevelAction, 700);

		mcOut.gotoAndPlay(2);

		if (pushInfo != null) {
			stats.s[stats.s.length - 1][7] = 1;
		}
		// BONUS CAISSE
		if (FL_BONUS_BLOCK && pushInfo == null) {
			for (a in elements)
				for (mc in a.filter(n -> n != null)) {
					if (mc._name.startsWith("box@")) {
						var max = 6;

						// SCORE
						KadoKadeoManager.kkm.addScore(SCORE_BLOCK);
						var p = new Phys(dm.empty(DP_PARTS));
						p.x = mc._x + SIZE * 0.5;
						p.y = mc._y + SIZE * 0.5;
						p.vy = KadoKadeoManager.I(-5);
						p.frict = 0.7;
						p.timer = 20;
						// p.root.gotoAndStop(Seed.randomVfx(p.root._totalframes) + 1);
						var mcf:FieldMC = cast p.root;
						mcf.field = mcf.initTextField("field", {
							color: 0xFFFFFF,
							align: "center",
							font: "Impact",
							size: 30,
							x: 0,
							y: KadoKadeoManager.I(-11)
						});
						mcf.field.text = Std.string(KKApi.val(SCORE_BLOCK));
						Filt.glow(p.root, KadoKadeoManager.I(2), 2, 0);
						var mcScore = p.root;
						mcScore.initTextField('field', {
							color: 0xFFFFFF,
							align: "center",
							font: "Impact",
							size: 16,
							bold: false,
							x: 0,
							y: -11
						});

						// PARTS
						for (i in 0...max) {
							var p = new Phys(dm.attach("partBlock", DP_PARTS));
							p.x = mc._x + SIZE * 0.5;
							p.y = mc._y + SIZE * 0.5;
							p.vx = (Seed.randVfx() * 2 - 1) * KadoKadeoManager.I(2);
							p.vy = KadoKadeoManager.S(-(1 + Seed.randVfx() * 2));
							p.weight = 0.1 + Seed.randVfx() * KadoKadeoManager.S(0.1);
							p.fadeType = 0;
							p.timer = 10 + Seed.randVfx() * 10;
							p.vr = (Seed.randVfx() * 2 - 1) * KadoKadeoManager.I(20);
							p.root._rotation = Seed.randVfx() * 360;
							Filt.glow(p.root, KadoKadeoManager.I(3), 2, 0);
							if (i == max * 0.5)
								dm.over(mcScore);
						}

						mc.removeMovieClip();
					}
				}
		}
	}

	function nextLevel() {
		level++;
		clevel++;
		dif = Math.min(100, dif + 10);

		if (FL_SIZER && level > 16) {
			SIZE = Std.int(Math.max(SIZE - 1, 12));
			xmax = Std.int(mcw / SIZE);
			ymax = Std.int(mch / SIZE);
		}

		for (a in elements) {
			for (mc in a.filter(n -> n != null)) {
				var m = new Matrix();
				// m.scale(mc._xscale / 100, mc._yscale / 100);
				// m.translate(mc._x, mc._y);
				map.mcGround.bmp.draw(mc, m);
				mc.removeMovieClip();
			}
		}

		prec = map;
		tc = 0;

		// ZOOM
		map.mcGround._x = -ball.x;
		map.mcGround._y = -ball.y;
		map._x = ball.x;
		map._y = ball.y;

		while (ghostList.length > 0) {
			ghostList.pop().kill();
		}

		initMap();
		Col.setPercentColor(map, HOLE_FADE, 0);
		mdm.over(prec);
		step = Next;
	}

	function updateNextLevel() {
		tc = Math.min(tc + ZOOM_SPEED * mt.Timer.tmod, 1);

		// ZOOM
		prec._xscale = 100 + Math.pow(tc, 3) * 3500;
		prec._yscale = prec._xscale;

		var zc = Math.pow(tc, 0.5);
		map._xscale = zc * 100;
		map._yscale = zc * 100;
		map._x = (mcw * (1 - zc)) * 0.5;
		map._y = (mcw * (1 - zc)) * 0.5;

		// TIMER
		if (levelTimer != null) {
			var timerMod = (mt.Timer.wantedFPS * mt.Timer.deltaT);
			var n = Math.min(levelTimer, 34 * timerMod);
			levelTimer -= n;
			if (n > 0) {
				KadoKadeoManager.kkm.addScore(Std.int(n) * SCORE_TIME);
			}
			updateTimerGfx();

			// PARTS
			var p = new Phys(mdm.attach("partCloud", DP_INTER));
			p.root.play();
			var c = levelTimer / levelTimerMax;
			var a = c * 6.28 - 1.57;
			var ray = KadoKadeoManager.I(16);
			p.x = mcw - KadoKadeoManager.I(20) + Math.cos(a) * ray;
			p.y = mch - KadoKadeoManager.I(20) + Math.sin(a) * ray;
			p.weight = -(0.1 + Seed.randVfx() * 0.3);
			p.vx = (Seed.randVfx() * 2 - 1) * 0.5;
			p.timer = 10 + Seed.randVfx() * 10;
			p.fadeType = 0;
			p.root.blendMode = BlendModes.ADD;
			p.setScale(KadoKadeoManager.I(150));
			p.updatePos();

			//
			if (levelTimer <= 0) {
				levelTimer = null;
				mcTimer.field.text = Std.string(level);
			}
		}

		//
		if (tc == 1) {
			if (prec._visible) {
				prc = HOLE_FADE;
				prec.removeMovieClip();

				if (pushInfo != null) {
					pushInfo = null;
					displayPushIcon();
				}
			}
			if (levelTimer == null) {
				spawnBall();
			}
		}
	}

	// GEN LEVEL
	function genLevel() {
		// GRILLE
		grid = new Array();
		stones = new Array();
		for (x in 0...xmax) {
			grid[x] = new Array();
			for (y in 0...ymax) {
				grid[x][y] = if (x == 0 || x == xmax - 1 || y == 0 || y == ymax - 1) SEA; else EMPTY;
			}
		}

		// TELEPORT

		if (FL_TELEPORT && level >= 10) {
			tel = [];
			for (i in 0...2) {
				var p = null;
				do {
					p = getRandomPos([EMPTY], 3);
				} while (i == 1 && (p.x == tel[0][0] || p.y == tel[0][1]));

				grid[p.x][p.y] = TELEPORT;
				tel.push([p.x, p.y]);
				for (d in DIR) {
					grid[p.x + d[0]][p.y + d[1]] = PATH;
				}
			}
		}

		{ // SORTIE + GENERATION
			var p = getRandomPos([EMPTY, PATH], 4);
			grid[p.x][p.y] = OUT;

			nList = [{x: p.x, y: p.y, d: Seed.random(4)}];
			flPush = FL_PUSH && level > 2;
			getRange();

			var last = nList[nList.length - 1];
			x = last.x;
			y = last.y;
		}
		// CREATE THE BLOCK
		// createTheBlock();

		for (x in 0...xmax) {
			for (y in 0...ymax) {
				if (grid[x][y] == MROCK)
					grid[x][y] = ROCK;
			}
		}

		// PARASITES

		var bList = new Array();
		var max = null;
		// FALSE PATH

		for (i in 0...6) {
			var m = 4;
			var x = m + Seed.random(xmax - 2 * m);
			var y = m + Seed.random(ymax - 2 * m);
			var d = DIR[Seed.random(4)];
			while (true) {
				x += d[0];
				y += d[1];
				var sq = grid[x][y];
				if (sq == EMPTY) {
					grid[x][y] = PATH;
				}
				if (sq == SEA)
					break;
			}
		}

		// LINE
		var max = Std.int(Math.min(dif * 0.2, 8));
		for (i in 0...max) {
			var m = 4;
			var x = m + Seed.random(xmax - 2 * m);
			var y = m + Seed.random(ymax - 2 * m);
			var d = DIR[Seed.random(4)];
			while (true) {
				x += d[0];
				y += d[1];
				var sq = grid[x][y];
				if (sq == EMPTY) {
					grid[x][y] = ROCK;
					bList.push({x: x, y: y});
				}
				if (sq == SEA)
					break;
			}
		}

		// HOLE
		bList = shuffle(bList);
		for (i in 0...max) {
			var p = bList.pop();
			if (p == null)
				continue;
			grid[p.x][p.y] = EMPTY;
		}

		// ALONE
		var max = Math.floor(dif * 0.1);
		for (i in 0...max) {
			var m = 1;
			var x = m + Seed.random(xmax - 2 * m);
			var y = m + Seed.random(ymax - 2 * m);
			if (grid[x][y] == EMPTY)
				grid[x][y] = ROCK;
		}

		// WATER
		var px = 1;
		var py = 1;
		var flSwitch = true;
		for (d in DIR) {
			for (x in 0...xmax - 3) {
				if (Seed.random(6) == 0)
					flSwitch = !flSwitch;
				if (flSwitch) {
					if (grid[px][py] == EMPTY) {
						grid[px][py] = SEA;
					} else {
						flSwitch = false;
					}
				}
				px += d[0];
				py += d[1];
			}
		}

		// TRANSMUTE ROCK -> BLOCK
		var falseBlockCoef = Math.min((level / 20), 0.9);
		for (x in 0...xmax) {
			for (y in 0...xmax) {
				if (grid[x][y] == ROCK && Seed.rand() < falseBlockCoef) {
					if ((isFree(x - 1, y) && isFree(x + 1, y)) || (isFree(x, y - 1) && isFree(x, y + 1))) {
						grid[x][y] = BLOCK;
					}
				}
			}
		}

		// HOLE ROCKERS
		var sx = nList[0].x;
		var sy = nList[0].y;

		for (d in DIR) {
			var dist = 0;
			while (true) {
				dist++;
				var nx = sx + d[0] * dist;
				var ny = sy + d[1] * dist;
				var c = grid[nx][ny];
				if (c == EMPTY && Seed.random(3) == 0) {
					grid[nx][ny] = ROCK;
					break;
				}
				if (c == SEA)
					break;
			}
		}
	}

	function getRange():Bool {
		var limit = 4 + Std.int(dif * 0.12);
		if (nList.length >= limit) {
			return true;
		}
		var last = nList[nList.length - 1];
		var d = DIR[last.d];

		// Fait la liste des distances accessibles
		var dList = new Array();

		var n = 0;
		var nx = last.x;
		var ny = last.y;

		while (true) {
			n++;
			nx += d[0];
			ny += d[1];
			var sq = grid[nx][ny];
			if (sq == TELEPORT) {
				var p = getTeleportPos(nx, ny);
				nx = p[0];
				ny = p[1];
			}

			if (sq == EMPTY) {
				dList.push(n);
			} else {
				if (sq != PATH && sq != TELEPORT)
					break;
			}
		}

		// Melange de la liste des distances accessibles
		dList = shuffle(dList);

		// Parcours les distances accessibles
		while (dList.length > 0) {
			// R�cup�re une distance
			var dist = dList.pop();

			// Calcule le x et le y de la case d'arriv�e
			// var nx = last.x + dist*d[0];
			// var ny = last.y + dist*d[1];
			var nx = null;
			var ny = null;

			// Peint le chemin
			var px = last.x;
			var py = last.y;
			var cleanList = [];
			for (i in 0...dist) {
				px += d[0];
				py += d[1];

				if (grid[px][py] == TELEPORT) {
					var p = getTeleportPos(px, py);
					px = p[0];
					py = p[1];
				} else {
					if (grid[px][py] == EMPTY)
						cleanList.push([px, py]);
					grid[px][py] = PATH;
				}

				nx = px;
				ny = py;
			}

			// Choisis une direction au hasard parmis les deux disponibles
			var dir = new Array();
			dir.push((last.d + 1) % 4);
			dir.push((last.d + 3) % 4);
			dir = shuffle(dir);
			var cacheStones = stones.copy();

			while (dir.length > 0) {
				// index de la direction a verifier;
				var nd = dir.pop();
				// essaie de placer un block dans la direction oppos�
				var od = (nd + 2) % 4;
				var bx = nx + DIR[od][0];
				var by = ny + DIR[od][1];
				var sq = grid[bx][by];
				if (sq == EMPTY || sq == ROCK || sq == MROCK) { // CORRECTION 1

					// Pose le block
					if (grid[bx][by] == MROCK) {
						grid[bx][by] = ROCK;
					} else {
						grid[bx][by] = MROCK;
					}

					// addStone(bx,by,nx,ny);

					// Ajoute a la liste
					var o = {x: nx, y: ny, d: nd}
					nList.push(o);

					// verifie le prochain path
					if (getRange()) {
						// cr�� un block si l'action est dispo

						if (flPush && grid[bx][by] == MROCK) {
							var flAdd = true;
							for (i in 0...3) {
								if (nList[nList.length - (1 + i)] == o) {
									flAdd = false;
									break;
								}
							}

							if (flAdd && Seed.random(PROBA_PUSH) == 0) {
								flPush = false;
								var d = DIR[nd];
								grid[bx + d[0]][by + d[1]] = BLOCK;
								grid[bx][by] = PATH;
							}
						}

						return true;
					}

					// nettoie la liste
					nList.pop();

					// Enleve le block
					grid[bx][by] = sq;
				}
			}

			// ECHEC !!
			stones = cacheStones;

			// Nettoie le chemin
			/*
				var px = last.x;
				var py = last.y;
				for( i in 0...dist ){
					px += d[0];
					py += d[1];

					if( grid[px][py] == TELEPORT ){
						var p = getTeleportPos(px,py);
						px = p[0];
						py = p[1];
					}else{
						grid[px][py] = EMPTY;
					}


				}
			 */

			for (p in cleanList)
				grid[p[0]][p[1]] = EMPTY;
		}

		// ECHEC
		return false;
	}

	function drawLevel() {
		// ELEMENTS
		elements = [];
		for (i in 0...xmax)
			elements[i] = [];

		// GROUND
		map.mcGround = cast dm.empty(DP_GROUND);
		map.mcGround.bmp = RenderTexture.create(mcw, mcw);
		Col.setPercentColor(map.mcGround, Seed.random(20), 0xff9900);

		for (y in 0...ymax) {
			for (x in 0...xmax) {
				var type:PathType = grid[x][y];

				switch (type) {
					case ROCK:
						var mc = dm.attach("baseRoche", DP_ROCK);
						mc.gotoAndStop(Seed.random(7) + 1);
						mc._x = x * SIZE - 4;
						mc._y = y * SIZE;

						Col.setPercentColor(mc, Seed.random(20), 0xff9900);
						elements[x][y] = mc;

					case BLOCK:
						var mc = dm.attach("box", DP_ROCK);
						mc._x = x * SIZE;
						mc._y = y * SIZE;
						mc.gotoAndStop(1);

						Col.setPercentColor(mc, Seed.random(20), 0xff9900);
						elements[x][y] = mc;
					case TELEPORT:
						var mc = dm.attach("mcTeleport", DP_ROCK);
						mc._x = x * SIZE + SIZE / 2;
						mc._y = y * SIZE + SIZE / 2 - KadoKadeoManager.I(2);
						mc._xscale = mc._yscale = SIZE / 30 * 100;
						mc.play();
						mc.loop = true;

						elements[x][y] = mc;
					case OUT:
						var mc = map.mcGround.attachMovie("mcOut");

						// Empty circle hole from nearby ground textures
						var mask = new Graphics();
						mask.beginFill(0xffffff);
						mask.drawCircle(x * SIZE + KadoKadeoManager.I(12), y * SIZE + KadoKadeoManager.I(11), KadoKadeoManager.I(12));
						mask.endFill();
						mask.blendMode = untyped BlendModes.ERASE;
						map.mcGround.bmp.draw(mask, new Matrix());

						mc._x = x * SIZE + SIZE / 2;
						mc._y = y * SIZE + SIZE / 2 - KadoKadeoManager.I(2);

						mcOut = mc;
						dm.over(map.mcGround);
					default:
				}

				var groundFrame = 1;
				for (i in 0...DIR.length) {
					var d = DIR[i];
					if (grid[x + d[0]] != null && grid[x + d[0]][y + d[1]] != SEA)
						groundFrame += Std.int(Math.pow(2, i));
				}

				switch (type) {
					case EMPTY, PATH, ROCK, BLOCK, TELEPORT:
						var c = new ASprite();
						var mcg = new ASprite("mcDalle");
						mcg.gotoAndStop(groundFrame);
						c.addChild(mcg);
						var tacheFrame = Seed.random(28) + 1;
						if (tacheFrame < 12) {
							var tache = new ASprite("tache");
							tache.gotoAndStop(Math.floor(tacheFrame / 3) + 1);
							tache.position.set(KadoKadeoManager.I(11), KadoKadeoManager.S(8.5));
							c.addChild(tache);
						} else if (tacheFrame < 16) {
							var zarbi = new ASprite("formeZarbi");
							zarbi.gotoAndStop(Seed.random(zarbi._totalframes) + 1);
							zarbi.position.set(KadoKadeoManager.I(5), KadoKadeoManager.S(1.5));
							zarbi.filters = [
								new DropShadowFilter({
									blur: 0,
									rotation: 45,
									distance: 2,
									color: 0xD4E2C5
								}),
								new DropShadowFilter({
									blur: 0,
									rotation: 225,
									distance: 2,
									color: 0x99B66B
								})
							];
							c.addChild(zarbi);
						}

						var m = new Matrix();
						// Fixes pixel interpolation. Math is (SIZE - 1) = 59 (but hardcoded because it depends on the image)
						m.translate(x * SIZE, y * SIZE);

						map.mcGround.bmp.draw(c, m);
						c.removeMovieClip();
					default:
				}
			}
		}

		map.mcGround.attachBitmap(map.mcGround.bmp, 1);
		map.mcGround.setChildIndex(mcOut, map.mcGround.children.length - 1);
		// var dbg = map.mcGround.createEmptyMovieClip();
		// dbg.getGraphics().lineStyle(1, 0xffffff, 0.5);
		// for (x in 0...xmax) {
		// 	dbg.getGraphics().moveTo(x * SIZE, 0);
		// 	dbg.getGraphics().lineTo(x * SIZE, ymax * SIZE);
		// }
		// for (y in 0...ymax) {
		// 	dbg.getGraphics().moveTo(0, y * SIZE);
		// 	dbg.getGraphics().lineTo(xmax * SIZE, y * SIZE);
		// }

		// BONUS
		if (FL_BONUS) {
			var max = Std.int(Math.min(3 + level * 0.5, 16));
			bonus = [];
			for (x in 0...xmax)
				bonus.push([]);
			for (i in 0...max) {
				var x = null;
				var y = null;
				var m = 1;

				do {
					x = m + Seed.random(xmax - m * 2);
					y = m + Seed.random(ymax - m * 2);
				} while (!isFree(x, y) || bonus[x][y] != null);
				var mc = dm.attach("mcBonus", DP_ROCK);

				mc._x = x * SIZE + 15;
				mc._y = y * SIZE + 10;
				mc._xscale = mc._yscale = SIZE / 30 * 100;
				mc.gotoAndStop(getBonusId());
				mc.updateState();
				bonus[x][y] = mc;
			}
		}
		// GHOST
		if (FL_GHOST) {
			var max = Std.int(Math.min(Math.pow((level - 10), 0.5), 5));
			ghostList = [];
			for (i in 0...max) {
				var g = new Ghost(this, dm.empty(DP_GHOST));
				Filt.glow(g.root, 15, 2, 0xFFFFFF);
			}
		}
		// START DALLE
		var p = nList[nList.length - 1];
		var mc = dm.attach("mcStartDalle", DP_GROUND);
		mc._x = p.x * SIZE + SIZE / 2;
		mc._y = p.y * SIZE + SIZE / 2;
		elements[p.x][p.y] = mc;
	}

	function getShortPath(x, y, flPush, ?cache, ?ng) {
		if (cache == null) {
			cache = [];
			for (x in 0...xmax)
				cache.push([]);
		}
		var ch = cache[x][y];
		if (ch != null)
			return ch;

		// TRAITEMENT DE LA CASE EN COURT;
		cache[x][y] = 999;

		var result = 999;
		for (d in DIR) {
			var nx = x;
			var ny = y;
			while (true) {
				nx += d[0];
				ny += d[1];
				var next:PathType = grid[nx][ny];
				if (next == TELEPORT) {
					var p = getTeleportPos(nx, ny);
					nx = p[0];
					ny = p[1];
				}

				if (ng != null && ng[nx] != null && ng[nx][ny] != null)
					next = ng[nx][ny];

				switch (next) {
					case OUT:
						result = 1;
						break;
					case ROCK:
						result = Std.int(Math.min(1 + getShortPath(nx - d[0], ny - d[1], flPush, cache), result));
						break;
					case BLOCK:
						result = Std.int(Math.min(1 + getShortPath(nx - d[0], ny - d[1], flPush, cache), result));
						if (flPush) {
							var beyond = grid[nx + d[0]][ny + d[1]];
							if (beyond == EMPTY || beyond == PATH) {
								var ng = [];
								for (x in 0...xmax)
									ng.push([]);
								ng[nx][ny] = EMPTY;
								ng[nx + d[0]][ny + d[1]] = BLOCK;

								result = Std.int(Math.min(1 + getShortPath(nx, ny, false, cache, ng), result));
							}
						}
					case SEA:
						result = Std.int(Math.min(999, result));
						break;
					default:
				}
			}
		}

		cache[x][y] = result;
		return result;
	}

	// BONUS
	function getBonusId() {
		var proba = [
			100, // bonus vert
			10, // bonus bleu
			1 // bonus rose
		];
		var sum = 0;
		for (n in proba)
			sum += n;
		var rnd = Seed.random(sum);
		sum = 0;
		for (i in 0...proba.length) {
			sum += proba[i];
			if (sum >= rnd) {
				return (i + 1);
			}
		}
		return null;
	}

	function pickBonus(mc:ASprite) {
		switch (mc._currentframe) {
			case 1:
				KadoKadeoManager.kkm.addScore(SCORE_GREEN);
			case 2:
				KadoKadeoManager.kkm.addScore(SCORE_BLUE);
			case 3:
				KadoKadeoManager.kkm.addScore(SCORE_PINK);
		}
		ballFlash = 255;
		Col.setColor(ball.root, 0, Std.int(ballFlash));

		for (i in 0...3) {
			var p = dm.attach("partWarp", DP_PARTS);
			p._x = mc._x + SIZE * 0.5 + (Seed.randVfx() * 2 - 1) * 6;
			p._y = mc._y + SIZE * 0.5 + (Seed.randVfx() * 2 - 1) * 6;
			p._xscale = p._yscale = 20;
			p._rotation = Seed.randVfx() * 360;
			p.gotoAndPlay(Seed.randomVfx(6) + 1);
		}
	}

	// TIMER
	function initTimer() {
		mcTimer = cast mdm.empty(DP_INTER);
		mcTimer.initTextField("field", {
			color: 0xFFFFFF,
			align: "center",
			font: "Impact",
			size: 26,
			bold: false,
			x: -KadoKadeoManager.I(20),
			y: -KadoKadeoManager.I(28)
		});
		mcTimer._x = mcw;
		mcTimer._y = mch;
		mcTimer.field.text = Std.string(level);
		mcTimer.ring = new Graphics();
		mcTimer.addChild(mcTimer.ring);

		Filt.glow(mcTimer, KadoKadeoManager.I(10), 1, 0xFFFFFF);
	}

	function drawRing(p:Float) {
		mcTimer.ring.clear();

		var cx = -KadoKadeoManager.I(20), cy = -KadoKadeoManager.I(20);
		var r = KadoKadeoManager.I(12); // rayon au milieu du trait
		var thickness = KadoKadeoManager.I(6);

		var start = -Math.PI / 2;
		var end = start + Math.PI * 2 * p;

		mcTimer.ring.lineStyle(thickness, 0xFFFFFF, 1);
		mcTimer.ring.arc(cx, cy, r, start, end);
	}

	function updateTimer() {
		if (mcTimer == null)
			return;
		if (mcTimer._x > mcw) {
			var dx = mcw - mcTimer._x;
			if (Math.abs(dx) < 1)
				dx = 0;
			mcTimer._x += dx * 0.5;
		}

		levelTimer -= mt.Timer.deltaT * mt.Timer.wantedFPS;
		updateTimerGfx();

		if (levelTimer <= 0) {
			if (level > SHOW_PATH_LEVEL_LIMIT) {
				KadoKadeoManager.kkm.gameOver(stats);
				step = GameOver;
			} else {
				if (ppList == null)
					ppList = [];
			}
		}
	}

	function updateTimerGfx() {
		drawRing(levelTimer / levelTimerMax);
		// mcTimer.smc.gotoAndStop(1 + Std.int((levelTimer / levelTimerMax) * 160));
	}

	// DISPLAY
	function updateDisplay() {
		return;
		if (disDec == null)
			disDec = 0;
		disDec = (disDec + 20) % 628;
		var c = Math.cos(disDec * 0.01);

		if (mcDisplay == null) {
			mcDisplay = cast mdm.empty(DP_FRONT);
			mcDisplay.bmp = RenderTexture.create(mcw * 2, mch);
			mcDisplay.bmp.fill(0xFF0000);
			mcDisplay.attachBitmap(mcDisplay.bmp, 0);
			mcDisplay._x = 0;
		}

		// CLEAN
		mcDisplay.bmp.fill(0xFF0000);

		// COPY MAPv
		var m = new Matrix();
		m.translate(mcw, 0);
		mcDisplay.bmp.draw(map, m);

		// DISPLACEMENT
		var mc = mdm.attach("mcDisplacement", 0);
		var dbmp = RenderTexture.create(mcw, mch);
		dbmp.fill(0x000000);
		dbmp.draw(mc, new Matrix());
		mc.removeMovieClip();

		trace('FIXME: DisplacementMapFilter');
		/*var fl = new flash.filters.DisplacementMapFilter();
				fl.componentX = 2;
				fl.componentY = 1;
				var sc = 160;
				fl.scaleX = mcw * 2 + 4;
				fl.scaleY = sc + c * sc;
				fl.mapPoint = new flash.geom.Point(0.0, 0.0);
				fl.mapBitmap = dbmp;
				fl.mode = "clamp";

			mcDisplay.bmp.applyFilter(mcDisplay.bmp, new flash.geom.Rectangle(0, 0, mcw, mch), new flash.geom.Point(0, 0), fl);
		 */

		// mcDisplay.bmp.draw(dbmp);

		/*
			var fl = new flash.filters.BlurFilter();
			fl.blurX = 8;
			fl.blurY = 8;
			mcDisplay.bmp.applyFilter(mcDisplay.bmp,mcDisplay.bmp.rectangle,new flash.geom.Point(0,0),fl);
		 */
	}

	//
	public function isFree(x, y) {
		var next = grid[x][y];
		return next == PATH || next == EMPTY;
	}

	public function isBlock(x, y) {
		var next = grid[x][y];
		return next == BLOCK || next == ROCK;
	}

	public function getRandomPos(a:Array<Int>, ?m) {
		if (m == null)
			m = 2;
		var to = 0;
		while (true) {
			var x = m + Seed.random(xmax - 2 * m);
			var y = m + Seed.random(ymax - 2 * m);
			for (type in a) {
				if (grid[x][y] == type)
					return {x: x, y: y};
			}
			if (to++ > 200) {
				trace("PIOOOOOOOOOOU ! getRandomPos ERROR");
				return null;
			}
		}
		return null;
	}

	function shuffle<T>(list:Array<T>):Array<T> {
		var pos = [];
		for (n in 0...list.length)
			pos.push(n);
		var a = [];
		while (pos.length > 0) {
			var index = Seed.random(pos.length);
			var n = pos[index];
			pos.splice(index, 1);
			a.push(list[n]);
		}
		return a;
	}

	// DEBUG

	function displayCache(cache) {
		mdm.clear(DP_FRONT);
		for (x in 0...xmax) {
			for (y in 0...ymax) {
				var type = cache[x][y];
				if (type == 999)
					type = 0;
				if (type != null) {
					var mc:FieldMC = cast mdm.attach("mcDebugField", DP_FRONT);
					mc._x = x * SIZE;
					mc._y = y * SIZE;
					mc.field.text = Std.string(type);
					mc._xscale = mc._yscale = SIZE / 30 * 100;
				}
			}
		}
	}

	function displayNList() {
		mdm.clear(DP_FRONT);
		var n = 0;
		for (p in nList) {
			n++;
			var x = p.x;
			var y = p.y;
			var mc:FieldMC = cast mdm.attach("mcDebugField", DP_FRONT);
			mc._x = x * SIZE;
			mc._y = y * SIZE;
			mc.field.text = Std.string(n);
			mc._xscale = mc._yscale = SIZE / 30 * 100;
		}
	}

	function displayPath() {
		mdm.clear(DP_FRONT);
		for (x in 0...xmax) {
			for (y in 0...ymax) {
				var type = grid[x][y];
				if (type == PATH) {
					var mc:FieldMC = cast mdm.attach("mcDebugField", DP_FRONT);
					mc._x = x * SIZE;
					mc._y = y * SIZE;
					mc.field.text = "0";
					mc._xscale = mc._yscale = SIZE / 30 * 100;
				}
			}
		}
	}

	public function destroy():Void {}
}
