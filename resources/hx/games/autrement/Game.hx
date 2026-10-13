package autrement;

import common_haxe_avm1.KeyboardManager;
import pixi.filters.colormatrix.ColorMatrixFilter;
import common_haxe_avm1.KKApi;
import common_haxe_avm1.MouseManager;
import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchControlsMode;
import mt.DepthManager;
import mt.Timer;
import mt.bumdum.Sprite;
import mt.bumdum.Phys;
import mt.bumdum.Lib;

class RayListSprite extends ASprite {
	public var vr:Float;
}

class BgSprite extends ASprite {
	public var grid:ASprite;
}

private enum Step {
	Play;
	GameOver;
}

@:expose('GameAutrement')
class Game implements kado.GameInterface {
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.JOYSTICK,
		joystick: {
			x: 0.18,
			y: 0.8,
			radius: 54,
			deadZone: 0.15,
			dynamicCenter: true,
		},
		buttons: [
			{
				id: "action",
				label: "GO",
				rightPx: 14,
				bottomPx: 14,
				size: 84,
				keyCode: KeyboardManager.SPACE,
			}
		],
	};

	static inline var TOUCH_DIRECTION_THRESHOLD = 0.35;
	static inline var TOUCH_MOVE_REPEAT_FRAMES = 3;

	public static var DIR = [[0, 1], [1, 0], [0, -1], [-1, 0]];

	public static var DP_BG = 0;
	public static var DP_BLOCS = 2;
	public static var DP_STAMP = 3;
	public static var DP_PARTS = 4;
	public static var DP_FRONT = 6;

	public static var mcw = KadoKadeoManager.I(300);
	public static var mch = KadoKadeoManager.I(300);

	public static var me:Game;

	public static var CHRONO_MAX = 200;
	public static var FREQ_OPTIONS = 3000;
	public static var SIZE = KadoKadeoManager.I(25);
	public static var MAX = 2;

	public static var SCORE_SPAWN = KKApi.const(15);
	public static var SCORE_FALL = KKApi.const(80);
	public static var SCORE_BURST = KKApi.aconst([50, 50, 80, 120, 200, 300]);

	public var step:Step;

	public var colorMax:Int;
	public var invasion:Int;
	public var turn:Int;

	public var gstep:Int;

	public var dif:Float;
	public var timer:Float;
	public var chrono:Float;
	public var chronoMax:Float;

	public var holes:Array<{x:Int, y:Int}>;

	var rayList:Array<RayListSprite>;

	public var stamp:Stamp;
	public var bm:BlocManager;

	public var dm:DepthManager;
	public var root:ASprite;
	public var bg:BgSprite;

	public var stats:{_f:Int, _b:Array<Int>, _s:Int};

	var touchAxisX:Int = 0;
	var touchAxisY:Int = 0;
	var touchMoveDelay:Int = 0;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		var replayKeys = new UInt16Array(1);
		replayKeys[0] = KeyboardManager.SPACE;
		var replayMouseButtons = new UInt16Array(1);
		replayMouseButtons[0] = MouseManager.BUTTON_LEFT;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: replayKeys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: true,
			recordedMouseButtons: replayMouseButtons,
		});

		this.root = root;
		me = this;
		dm = new DepthManager(root);
		bg = cast dm.attach("mcBg", DP_BG);
		bg.grid = bg.attachMovie("grid");
		bg.grid._xscale = bg.grid._yscale = SIZE / KadoKadeoManager.I(1) / 12 * 100;
		MAX = Std.int(mcw / SIZE);

		//
		holes = [];
		stats = {_f: 0, _b: [0, 0, 0, 0, 0, 0], _s: 0}
		//
		chronoMax = CHRONO_MAX * 5;
		chrono = chronoMax;
		invasion = 1;
		colorMax = 2;
		turn = 0;

		initGrid();
		initStamp();

		step = Play;
	}

	function initGrid() {
		bm = new BlocManager(dm.empty(DP_BLOCS), MAX);

		for (x in 0...bm.grid.length) {
			for (y in 0...bm.grid[x].length) {
				if (x == 0 || x == MAX - 1 || y == 0 || y == MAX - 1) {
					var b = new Bloc(x, y, Seed.random(colorMax), bm);
				}
			}
		}
	}

	function initStamp() {
		stamp = new Stamp();
	}

	//
	public function update(delta:Float) {
		/*
			haxe.Log.clear();
			trace(Bloc.ANIMS.length);
		 */
		// traceStampGrid();

		// STAMP
		refill();
		switch (step) {
			case Play:
				updateGrid();
			case GameOver:
				updateGameOver();
		}

		stamp.update();

		// ANIMS BLOCS
		Bloc.updateAnims();
		// SPRITE
		Sprite.updateAll();
	}

	public function pollTouchControls():Void {
		var joystick = KadoKadeoManager.kkm.getTouchJoystickState();
		if (joystick == null || stamp == null) {
			return;
		}

		var axisX = 0;
		var axisY = 0;
		if (joystick.active) {
			if (Math.abs(joystick.nx) >= Math.abs(joystick.ny)) {
				if (joystick.nx <= -TOUCH_DIRECTION_THRESHOLD)
					axisX = -1;
				else if (joystick.nx >= TOUCH_DIRECTION_THRESHOLD)
					axisX = 1;
			} else {
				if (joystick.ny <= -TOUCH_DIRECTION_THRESHOLD)
					axisY = -1;
				else if (joystick.ny >= TOUCH_DIRECTION_THRESHOLD)
					axisY = 1;
			}
		}

		if (axisX == 0 && axisY == 0) {
			touchAxisX = 0;
			touchAxisY = 0;
			touchMoveDelay = 0;
			MouseManager.setPosition(Std.int(getX(stamp.x)), Std.int(getY(stamp.y)));
			return;
		}

		if (axisX != touchAxisX || axisY != touchAxisY) {
			touchAxisX = axisX;
			touchAxisY = axisY;
			touchMoveDelay = 0;
		}
		if (touchMoveDelay > 0) {
			touchMoveDelay--;
			return;
		}

		MouseManager.setPosition(Std.int(getX(stamp.x + axisX)), Std.int(getY(stamp.y + axisY)));
		touchMoveDelay = TOUCH_MOVE_REPEAT_FRAMES;
	}

	// BLOCS
	function updateGrid() {
		// DEFENSE

		// ATTAQUE
		// chronoMax *= Math.pow(0.999,mt.Timer.tmod);
		// (port fix) the next turn waits for the end of a shake (Stamp.updateBurst): the chrono too, the original
		// reset it (nextTurn) before the shake
		if (stamp.isShaking())
			return;
		chrono -= Timer.tmod;
		if (chrono < 0) {
			chronoMax *= 0.3;
			addBloc();
			checkDead();
		}
	}

	function refill() {
		for (p in holes) {
			if (stamp.isGridFree(p.x, p.y)) {
				if (bm.isFree(p.x, p.y)) {
					var b = new Bloc(p.x, p.y, Seed.random(colorMax), bm);
					holes.remove(p);

					var d = null;
					if (p.x == 0)
						d = [1, 0];
					if (p.x == MAX - 1)
						d = [-1, 0];
					if (p.y == 0)
						d = [0, 1];
					if (p.y == MAX - 1)
						d = [0, -1];
					b.root._x -= d[0] * SIZE;
					b.root._y -= d[1] * SIZE;
					b.setPos(b.x, b.y, true);

					checkDead();
					if (step == Play) {
						KadoKadeoManager.kkm.addScore(SCORE_SPAWN);
						stats._s++;
					}
					break;
				}
			}
		}
	}

	function addBloc() {
		chrono = chronoMax;

		var d = DIR[Seed.random(4)];
		var pos = d.copy();
		for (i in 0...pos.length) {
			if (pos[i] == 0) {
				pos[i] = Seed.random(MAX);
			} else {
				pos[i] = Math.floor((-pos[i] * 0.5 + 0.5) * (MAX - 1));
			}
		}

		var x = pos[0];
		var y = pos[1];
		var list = [];
		var to = 0;
		while (true) {
			if (to++ > 8 || !stamp.isGridFree(x, y))
				return;
			var b = bm.grid[x][y];

			if (b == null) {
				// trace("libre!");
				break;
			} else {
				list.push(b);
			}
			x += d[0];
			y += d[1];
		}

		for (b in list) {
			b.setPos(b.x + d[0], b.y + d[1], true);
		}

		var b = new Bloc(pos[0], pos[1], Seed.random(colorMax), bm);
		b.setPos(b.x, b.y, true);
		b.root._x -= d[0] * SIZE;
		b.root._y -= d[1] * SIZE;
	}

	public function nextTurn() {
		turn++;
		chronoMax = CHRONO_MAX;
		colorMax = Std.int(Num.mm(2, Math.pow(turn, 0.35), 6));
		invasion = Std.int(Num.mm(1, Math.pow(turn, 0.3) - 1, 10));
		for (i in 0...invasion)
			addBloc();
		checkDead();
	}

	function checkDead() {
		stamp.checkRotate();
		if (stamp.isDead())
			initGameOver();
	}

	// OPTIONS
	public function activeStar(id) {
		// var col = Seed.random(Game.me.colorMax-1);
		var list = Game.me.bm.list.copy();
		for (b in Game.me.stamp.bm.list)
			list.push(b);

		// COLOR LIST
		var cl = [];
		for (i in 0...Game.me.colorMax)
			cl.push([i, 0]);
		for (b in list) {
			if (cl[b.id] != null)
				cl[b.id][1]++;
		}

		cl.sort(function(a, b) {
			if (a[1] > b[1])
				return -1;
			return 1;
		});

		var col = id;
		var ncol = cl[0][0];
		if (ncol == col)
			ncol = cl[1][0];

		for (b in list) {
			if (b.id == col) {
				b.id = ncol;
				b.root.gotoAndStop(b.id + 1);
				var mc = b.dm.attach("mcReflet", 0);
				// mc.smc.gotoAndStop(col + 1);
				mc.gotoAndPlay(Seed.randomVfx(4) + 1);
				mc.removeOnFrame = 16;
			}
		}
	}

	public function activeShaker() {
		stamp.initShaker();
		/*
			var list = stamp.bm.list.copy();
			for( b in list ){
				if(b.id<10)b.fall();
			}
		 */
	}

	// GAMEOVER
	function initGameOver() {
		if (step == GameOver)
			return;
		step = GameOver;
		stamp.die();
		timer = 0;
		gstep = 0;
	}

	function updateGameOver() {
		switch (gstep) {
			case 0:
				timer += 0.1 * Timer.tmod;
				var c = timer;
				if (timer >= 1) {
					timer = 0;
					gstep++;
					var max = 12;
					rayList = [];
					for (i in 0...max) {
						var mc:RayListSprite = cast dm.attach("mcRay", DP_BLOCS);
						mc._x = stamp.root._x;
						mc._y = stamp.root._y;
						mc.vr = (Seed.randVfx() * 2 - 1) * 3;
						mc._xscale = 360;
						mc._yscale = 20 + Seed.randVfx() * 50;
						mc._rotation = Seed.randVfx() * 360;
						rayList.push(mc);
					}
				}

				// FILTER
				var im = [
					1, 0, 0, 0, 0,
					0, 1, 0, 0, 0,
					0, 0, 1, 0, 0,
					0, 0, 0, 1, 0
				];
				var r = 0.3;
				var g = 0.5;
				var b = 0.1;
				var a = 0.117;
				var gm = [
					r, g, b, 0, a,
					r, g, b, 0, a,
					r, g, b, 0, a,
					0, 0, 0, 1, 0
				];

				var fm = [];
				for (i in 0...im.length) {
					fm.push(im[i] * (1 - c) + gm[i] * c);
				}
				var fl = new ColorMatrixFilter();
				fl.matrix = fm;
				bm.root.filters = [fl];
				bg.filters = [fl];
			case 1:
				timer += Timer.tmod;
				stamp.shake(timer / 5);

				// RAY
				for (mc in rayList) {
					mc._rotation += mc.vr;
					var mult = 1.1;
					if (timer > 22)
						mult = 1.8;
					mc._yscale *= mult;
				}

				//

				Col.setPercentColor(stamp.root, timer / 20 * 100, 0xFFFFFF);
				if (timer > 30) {
					var max = 128;
					for (i in 0...max) {
						var ray = SIZE * 2;
						var speed = 1 + Seed.randVfx() * 8;
						var a = i / max * 6.28;
						var ca = Math.cos(a);
						var sa = Math.sin(a);
						var p = new Phys(dm.attach("partSquare", DP_PARTS));
						p.x = stamp.root._x + ca * speed * SIZE * 0.3;
						p.y = stamp.root._y + sa * speed * SIZE * 0.3;
						p.vx = KadoKadeoManager.S(ca * speed);
						p.vy = KadoKadeoManager.S(sa * speed);
						p.timer = 10 + Seed.randVfx() * 40;
						p.weight = KadoKadeoManager.S(0.1 + Seed.randVfx() * 0.1);
						p.fadeType = 0;
						// p.root.blendMode = "add";
					}
					//
					var max = 32;
					for (i in 0...max) {
						var ray = SIZE * 2;
						var speed = 0.5 + Seed.randVfx() * 12;
						var a = i / max * 6.28;
						var ca = Math.cos(a);
						var sa = Math.sin(a);
						var p = new Phys(dm.attach("partStamp", DP_PARTS));
						p.x = stamp.root._x + ca * speed * SIZE * 0.3;
						p.y = stamp.root._y + sa * speed * SIZE * 0.3;
						p.vx = KadoKadeoManager.S(ca * speed);
						p.vy = KadoKadeoManager.S(sa * speed - 1);
						p.vr = (Seed.randVfx() * 2 - 1) * 20;
						p.timer = 10 + Seed.randVfx() * 40;
						p.weight = KadoKadeoManager.S(0.2 + Seed.randVfx() * 0.2);
						p.root.gotoAndStop(Seed.randomVfx(p.root._totalframes) + 1);
						p.fadeType = 0;
						p.setScale(100 + Seed.randVfx() * 50);
						// p.root.blendMode = "add";
					}
					//
					// stamp.root.removeMovieClip();
					// stamp = null;
					stamp.root._visible = false;
					//
					gstep++;
					timer = 0;
				}

			//

			case 2:
				timer += Timer.tmod;

				// EXPLODE
				for (b in bm.list) {
					var dx = stamp.x - b.x;
					var dy = stamp.y - b.y;
					var dist = Math.sqrt(dx * dx + dy * dy);
					if (dist < 3 + timer * 0.2) {
						var mc = dm.attach("partWarp", DP_PARTS);
						mc.play();
						mc.removeOnFrame = 20;
						mc._x = Game.getX(b.x);
						mc._y = Game.getY(b.y);
						mc._rotation = Seed.randVfx() * 360;
						mc._xscale = mc._yscale = 50;
						b.kill();
					}
				}

				// RAY
				var list = rayList.copy();
				for (mc in list) {
					mc._rotation += mc.vr;
					mc._yscale *= 0.3;
					if (mc._yscale < 5) {
						mc.removeMovieClip();
						rayList.remove(mc);
					}
				}

				if (timer > 48) {
					KadoKadeoManager.kkm.gameOver(stats);
					gstep++;
				}
		}
	}

	// TOOLS
	static public function getX(x) {
		return (x + 0.5) * Game.SIZE;
	}

	static public function getY(y) {
		return (y + 0.5) * Game.SIZE;
	}

	static public function getGX(x:Float) { // >_<
		return Std.int((x / SIZE));
	}

	static public function getGY(y:Float) {
		return Std.int((y / SIZE));
	}

	// DEBUG
	public function traceStampGrid() {
		trace(stamp.bm.list.length);
		trace(stamp.x);
		trace(stamp.y);
		for (y in 0...MAX) {
			var str = "";
			for (x in 0...MAX) {
				if (stamp.isGridFree(x, y)) {
					str += "X-";
				} else {
					str += "O-";
				}
			}
			trace(str);
		}
	}

	public static function getAng(o1, o2) {
		var dx = o1.x - o2.x;
		var dy = o1.y - o2.y;
		return Math.atan2(dy, dx);
	}

	public function destroy() {
		Bloc.OPTIONS = [false, false];
		Bloc.ANIMS = [];
	}

	// NETTOYER STAMP GRID AVANT LE CHECKDEATH ( = BURST calcul len avance )
	// GERER LES RETRY SUR ADDBLOC
}
