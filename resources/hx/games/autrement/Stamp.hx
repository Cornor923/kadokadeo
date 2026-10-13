package autrement;

import pixi.core.textures.RenderTexture;
import pixi.core.math.Matrix;
import common_haxe_avm1.KeyboardManager;
import common_haxe_avm1.MouseManager;
import mt.DepthManager;
import mt.Timer;
import mt.bumdum.Phys;
import mt.bumdum.Lib;

enum Step {
	Play;
	Burst;
	Shaker;
	GameOver;
}

class Stamp {
	static var START_SIZE = 3;

	public var flRotate:Bool;
	public var rotDec:{x:Int, y:Int};

	public var x:Int;
	public var y:Int;

	var ct:Float;
	var flh:Float;

	public var step:Step;

	var dir:Array<Int>;
	var cols:Array<Bloc>;
	var burstList:Array<Bloc>;
	var optWait:Array<Array<Int>>;
	// options of a burst with a shaker: the next turn and the stars wait for the end of the shake
	var pendingOpts:Array<Array<Int>>;

	public var root:ASprite;

	var dm:DepthManager;

	public var bm:BlocManager;

	var pentacle:ASprite;
	var mcDisplay:ASprite;

	public function new() {
		x = Std.int(Game.MAX * 0.5);
		y = Std.int(Game.MAX * 0.5);

		root = Game.me.dm.empty(Game.DP_STAMP);
		dm = new DepthManager(root);

		bm = new BlocManager(dm.empty(0), Game.MAX * 2);
		bm.dx = bm.dy = Std.int(bm.max * 0.5);

		bm.root._x -= Game.SIZE * 0.5;
		bm.root._y -= Game.SIZE * 0.5;

		pentacle = dm.attach("mcStamp", Game.DP_BLOCS);
		mcDisplay = dm.attach("mcDisplay", Game.DP_BLOCS);
		pentacle._xscale = pentacle._yscale = Game.SIZE / KadoKadeoManager.I(1) / 20 * 100;
		mcDisplay._xscale = mcDisplay._yscale = Game.SIZE / KadoKadeoManager.I(1) / 20 * 100;

		for (x in 0...START_SIZE) {
			for (y in 0...START_SIZE) {
				var b = new Bloc(x - 1, y - 1, 10, bm);
			}
		}

		// STEP
		step = Play;
		cols = [];
		dir = [0, 0];

		// Col.setColor(bm.root,0xFF000000,80);
		// Col.setPercentColor(bm.root,30,0);
	}

	public function update() {
		//
		var odir = dir;
		var ocols = cols;
		cols = [];
		dir = [0, 0];
		//

		switch (step) {
			case Play:
				updatePlay();
				if (MouseManager.isButtonJustPressed(MouseManager.BUTTON_LEFT) || KeyboardManager.isJustDown(KeyboardManager.SPACE))
					action();
			case Burst:
				updateBurst();
			case Shaker:
				updateShaker();
			case GameOver:
		}

		// FLASH
		if (flh != null) {
			flh *= Math.pow(0.9, Timer.tmod);
			var prc = flh;
			if (flh < 5) {
				prc = 0;
				flh = null;
			}
			Col.setPercentColor(root, prc, 0xFFFFFF);
		}

		// REMET LES PIONS EN PLACE
		if (odir != null && (dir[0] != odir[0] || dir[1] != odir[1])) {
			for (b in ocols)
				b.setPos(b.x, b.y, true);
		}
		//

		// UPDATE DISPLAY
		if (cols.length == 0) {
			mcDisplay._rotation = 0;
			if (flRotate) {
				mcDisplay.gotoAndStop(2);
			} else {
				mcDisplay.gotoAndStop(3);
			}
		} else {
			if (dir[0] == 0)
				mcDisplay._rotation = dir[1] * 90;
			if (dir[1] == 0)
				mcDisplay._rotation = dir[0] * 90 - 90;
			mcDisplay.gotoAndStop(1);
		}

		move();
	}

	function move() {
		var tx = Game.getX(x);
		var ty = Game.getY(y);

		if (cols.length > 0) {
			var dec = Game.SIZE * 0.3;
			for (b in cols) {
				b.bm.dm.over(b.root);
				var tx = Game.getX(b.x) + dir[0] * dec;
				var ty = Game.getY(b.y) + dir[1] * dec;

				Bloc.goto(b, tx, ty);
			}
			tx += dir[0] * dec;
			ty += dir[1] * dec;
		}

		var dx = tx - root._x;
		var dy = ty - root._y;
		var cc = 0.6;
		root._x += dx * cc * Timer.tmod;
		root._y += dy * cc * Timer.tmod;
	}

	function updatePlay() {
		root._rotation *= 0.5;

		var dx:Int = Game.getGX(MouseManager.getX()) - x;
		var dy:Int = Game.getGY(MouseManager.getY()) - y;

		var adx = Math.abs(dx);
		var ady = Math.abs(dy);

		if (adx == 0 && ady == 0)
			return;

		if (adx >= ady) {
			dir = [Std.int(adx / dx), 0];
		} else {
			dir = [0, Std.int(ady / dy)];
		}

		var list = getObstacle(dir);
		if (list != null) {
			if (list.length > 0) {
				for (b in list)
					cols.push(b);
			} else {
				x += dir[0];
				y += dir[1];
				checkRotate();
			}
		}
	}

	function getObstacle(dir) {
		var list = [];
		var flOk = true;
		for (b in bm.list) {
			var nx = x + b.x + dir[0];
			var ny = y + b.y + dir[1];

			if (Game.me.bm.grid[nx] != null) {
				var b2 = Game.me.bm.grid[nx][ny];
				if (b2 != null)
					list.push(b2);
			}

			if (Game.me.bm.isOut(nx, ny)) {
				list = null;
				flOk = false;
				break;
			}
		}
		return list;
	}

	// ACTION
	function action() {
		if (step != Play)
			return;
		if (cols.length > 0) {
			// ATTACH
			for (b in cols) {
				if (Game.me.bm.isOut(b.x, b.y, 1))
					Game.me.holes.push({x: b.x, y: b.y});
				b.discard();
				b.setManager(bm);
				b.display(b.x - x, b.y - y);
			}

			// BURST
			var gr = bm.getGroups(function(a, b) {
				return a != null && b != null && a.id == b.id;
			});
			burstList = [];
			optWait = [];
			for (a in gr) {
				if (a != null && a.length > 3 && a[0].id < 10) {
					for (b in a) {
						burstList.push(b);
						if (b.option != null)
							optWait.push([b.option, b.id]);
					}
				}
			}

			if (burstList.length > 0) {
				step = Burst;
				ct = 0;
			} else {
				Game.me.nextTurn();
			}

			// RECULE
			var cc = 1;
			root._x += dir[0] * Game.SIZE * cc;
			root._y += dir[1] * Game.SIZE * cc;

			// FLASH
			flh = 100;
			Col.setPercentColor(root, 100, 0xFFFFFF);
			cols = [];

			//
			// Game.me.nextTurn();
		} else {
			/*
				var ofl = flRotate;
				checkRotate();
				if(flRotate!=ofl)trace("ERRRRRROOOOOOOOOOOOOOOR!");
			 */
			if (flRotate) {
				if (rotDec != null) {
					x += rotDec.x;
					y += rotDec.y;
					rotDec = null;
				}

				bm.rotate();
				root._rotation -= 90;
				pentacle._rotation += 90;

				checkRotate();
			}
		}
	}

	public function checkRotate() {
		rotDec = null;
		flRotate = bm.checkRotate(Game.me.bm, x, y);
		if (!flRotate) {
			for (dx in 0...3) {
				for (dy in 0...3) {
					flRotate = bm.checkRotate(Game.me.bm, x + dx - 1, y + dy - 1);
					if (flRotate) {
						rotDec = {x: dx - 1, y: dy - 1};
						return;
					}
				}
			}
		}
	}

	// BURST
	function updateBurst() {
		ct = Math.min(ct + 0.1 * Timer.tmod, 1);

		for (b in burstList) {
			Col.setPercentColor(b.root, ct * 100, 0xFFFFFF);
			if (ct == 1)
				b.explode();
		}

		if (ct == 1) {
			// FALL
			var list = bm.getFalls();
			for (b in list)
				b.fall();
			//
			step = Play;
			cols = [];
			dir = [0, 0];
			//
			// (port fix) the original played the next turn (new blocs, death check) before the options: the shaker
			// emptied the stamp only after the blocs it would have dropped had blocked it, and the game could end.
			// With a shaker the next turn waits for the end of the shake (updateShaker), the stars still after it
			var flShaker = false;
			for (a in optWait)
				if (a[0] == 1)
					flShaker = true;
			if (flShaker) {
				pendingOpts = optWait;
				Game.me.activeShaker();
			} else {
				Game.me.nextTurn();
				applyStars(optWait);
			}
		}
	}

	function applyStars(opts:Array<Array<Int>>) {
		for (a in opts) {
			if (a[0] == 0)
				Game.me.activeStar(a[1]);
		}
	}

	// SHAKER
	public function initShaker() {
		step = Shaker;
	}

	public function isShaking() {
		return step == Shaker;
	}

	function updateShaker() {
		if (bm.list.length == 9) {
			step = Play;
			if (pendingOpts != null) {
				var opts = pendingOpts;
				pendingOpts = null;
				Game.me.nextTurn();
				applyStars(opts);
			}
			return;
		}

		// FALL BALL

		var b = null;
		do {
			b = bm.list[Seed.random(bm.list.length)];
		} while (b.id == 10);

		var a = Game.getAng(b, {x: 0, y: 0});
		var sp = KadoKadeoManager.S(2 + Seed.randVfx() * 4);
		var p = b.fall();
		p.vx = Math.cos(a) * sp;
		p.vy = Math.sin(a) * sp;

		// ROTATION
		root._rotation = (Seed.randVfx() * 2 - 1) * 9;
		var size = KadoKadeoManager.I(300);
		var bmp = RenderTexture.create(size, size);
		var m = new Matrix();
		m.translate(size * 0.5, size * 0.5);
		bmp.draw(root, m);
		var mc = Game.me.dm.empty(Game.DP_PARTS);
		var mcc = new DepthManager(mc).empty(0);
		mcc._x = -size * 0.5;
		mcc._y = -size * 0.5;
		mcc.attachBitmap(bmp, 0);
		mcc._alpha = 50;
		mc._rotation = -root._rotation;

		var p = new Phys(mc);
		p.x = Game.getX(x);
		p.y = Game.getY(y);
		p.timer = 3;
		p.fadeLimit = 1;
		p.updatePos();
		p.setAlpha(50);
	}

	public function die() {
		step = GameOver;
	}

	public function shake(n:Float) {
		root._x = Game.getX(x) + KadoKadeoManager.S((Seed.randVfx() * 2 - 1) * n);
		root._y = Game.getY(y) + KadoKadeoManager.S((Seed.randVfx() * 2 - 1) * n);
	}

	// CHECK
	public function isDead() {
		for (d in Game.DIR) {
			var list = getObstacle(d);
			if (list != null && list.length == 0)
				return false;
		}
		return true;
	}

	public function isGridFree(gx, gy) {
		return bm.isFree(gx - x, gy - y);
	}
}
/*
	27
	254	- 1
	2542	- 10
	15766	- 100
	310952	- 1000
 */
