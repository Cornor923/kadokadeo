package mel;

import mel.Lib;

enum EntFlags {
	GRAVITY;
	CAN_GRIP;
	GRIPPED;
	FLY;
	NO_COLLIDE;
}

// Entity.hx of the original: a thing of the level in cells (cx, cy) + ratio in the cell (rx, ry), its speed (dx, dy)
// in cells per frame, the physics against the walls of the level
class Entity {
	public var cx:Int;
	public var cy:Int;

	public var rx:Float;
	public var ry:Float;

	public var dx:Float;
	public var dy:Float;

	public var fx:Float; // xfriction

	public var oppy:Float; // oppose to grav

	public var flags:haxe.EnumFlags<EntFlags>;
	public var mc:DO;

	public var page:Null<Int>;
	public var maxPv:Float = 1.0;
	public var pv:Float = 1.0;
	public var invincible = false;
	public var restager:Restager;
	public var name:String;

	public var game(get, null):Game;

	function get_game()
		return Game.me;

	public function new() {
		flags = haxe.EnumFlags.ofInt(0);
		fx = 0.9;
		dx = 0;
		dy = 0;
		oppy = 0;
		rx = 0;
		ry = 0;
		cx = 0;
		cy = 0;
	}

	public function isDead()
		return pv <= 0;

	public function hurt(v:Float):Bool {
		if (invincible)
			return false;
		pv -= v;
		if (pv <= 0) {
			onDestroy();
			return true;
		}
		return false;
	}

	// whence page is activated
	public function restage() {
		if (page != null)
			defaultRestage();
		mc.visible = true;
	}

	public function defaultRestage() {
		if (mc == null || restager == null)
			return;
		var l = game.level;
		if (Lambda.has(l.others, this))
			return;
		switch (restager) {
			case RandPlatform(seed):
				var wall = game.level.getRandomPlace(game.level.getWallCache(page), seed);
				cx = wall.px;
				cy = wall.py;
				wall.pl.addChild(mc);
				l.others.push(this);
			case FixedPlatform(fcx, fcy):
				var wc = l.getWallCache(page);
				var w = null;
				for (pl in wc)
					if (pl.px == fcx && pl.py == fcy) {
						w = pl;
						break;
					}
				if (w == null)
					throw "assert";
				w.addChild(mc);
				l.others.push(this);
			case Fixed:
				syncPos();
				if (!Lambda.has(l.others, this))
					l.others.push(this);
				l.dm.add(mc, Level.CHAR_DEPTH);
				mc.snap();
		}
		mc.visible = true;
	}

	public function unstage() {
		var l = game.level;
		l.others.remove(this);
		if (mc.parent != null) {
			mc.parent.removeChild(mc);
			mc.visible = false;
		}
	}

	// mc.getRect(level root)
	public function getRect():Rect {
		return mc.getRect();
	}

	public static inline var sy_cap = 0.775;
	public static inline var grav = 0.035;

	function onFall() {}

	function onLand(dy:Float) {}

	function onWallGrip(x:Int, y:Int) {}

	public function movePix(x:Int, y:Int) {
		cx = x >> Lib.cw_shift;
		cy = y >> Lib.ch_shift;
		rx = (x - (cx << Lib.cw_shift)) / Lib.cw;
		ry = (y - (cy << Lib.ch_shift)) / Lib.cw;
	}

	public function moveF(fcx:Float, fcy:Float) {
		this.cx = Std.int(fcx);
		this.cy = Std.int(fcy);
		rx = fcx - this.cx;
		ry = fcy - this.cy;
	}

	public function move(mcx:Int, mcy:Int) {
		this.cx = mcx;
		this.cy = mcy;
		rx = 0.5;
		ry = 1.0;
	}

	public function tpToF(fcx:Float, fcy:Float) {
		this.cx = Std.int(fcx);
		this.cy = Std.int(fcy);
		rx = ((fcx > 0) ? 1 : -1) * (fcx - this.cx);
		ry = ((fcy > 0) ? 1 : -1) * (fcy - this.cy);
	}

	public function getFx()
		return cx + rx;

	public function getFy()
		return cy + ry;

	public function getCx(pix:Float):Int
		return Std.int(pix / Lib.cw);

	public function getCy(pix:Float):Int
		return Std.int(pix / Lib.ch);

	public function syncPos() {
		mc.x = Std.int(Lib.cw * (rx + cx));
		mc.y = Std.int(Lib.ch * (ry + cy));
	}

	// called whenever should be disposed, trigger object removal here
	public function onDispose() {}

	// called whenever should dies, trigger fx here !
	public function onDestroy() {}

	public function updatePhy() {
		var lev = game.level;
		ry += dy;

		if (flags.has(GRAVITY))
			dy += (grav - oppy);
		if (dy > sy_cap)
			dy = sy_cap;

		rx += dx;
		dx = dx * fx;

		function testColY() {
			if (!flags.has(GRAVITY) && !flags.has(FLY))
				if (!lev.testColl(cx, cy + 1)) {
					flags.set(GRAVITY);
					onFall();
				}

			if (flags.has(GRAVITY) && !flags.has(FLY)) {
				var t = lev.testColl(cx, cy + 1);
				if (dy > 0 && t && ry >= 0.95) {
					var ody = dy;
					dy = 0;
					ry = 1;
					onLand(ody);
				}
			}
		}

		function testColX() {
			if (!flags.has(CAN_GRIP)) {
				if (lev.testBorder(cx - 1, cy)) {
					if (dx < 0)
						dx = 0; // stuck on wall an running
					else if (!flags.has(GRIPPED) && (cx - 1 == 0))
						rx += 0.05; // stuck an wall bounce
					if (rx < 0.4)
						rx = 0.4;
				}
				if (lev.testBorder(cx + 1, cy)) {
					if (dx > 0)
						dx = 0;
					else if (!flags.has(GRIPPED) && (cx + 1 == Lib.nbcw() - 1))
						rx -= 0.05;
					if (rx > 0.6)
						rx = 0.6;
				}
			} else {
				if (lev.testColl(cx - 1, cy)) {
					var ccyp = lev.testColl(cx, cy - 1);
					var ccx = lev.testColl(cx, cy);
					var shallGrip = flags.has(CAN_GRIP) && !ccyp && !ccx && Math.abs(dy) > 0.005;
					var tb = lev.testBorder(cx - 1, cy);
					if (dx < 0) {
						if ((shallGrip || tb))
							dx = 0; // stuck on wall an running
					} else if (!flags.has(GRIPPED) && (cx - 1 <= 0))
						rx += 0.05; // stuck an wall bounce
					if ((shallGrip || tb) && rx < 0.4)
						rx = 0.4;
					if (shallGrip)
						onWallGrip(cx - 1, cy);
				}

				if (lev.testColl(cx + 1, cy)) {
					var ccx = lev.testColl(cx, cy);
					var ccyp = lev.testColl(cx, cy - 1);
					var shallGrip = flags.has(CAN_GRIP) && !ccyp && !ccx && Math.abs(dy) > 0.005;
					var tb = lev.testBorder(cx + 1, cy);
					if (dx > 0) {
						if ((shallGrip || tb))
							dx = 0;
					} else if (!flags.has(GRIPPED) && (cx + 1 == Lib.nbcw() - 1))
						rx -= 0.05;
					if ((shallGrip || tb) && rx > 0.6)
						rx = 0.6;
					if (shallGrip)
						onWallGrip(cx + 1, cy);
				}
			}
		}

		testColY();

		while (ry < 0) {
			cy--;
			ry++;
			if (!flags.has(NO_COLLIDE))
				testColY();
		}
		while (ry > 1) {
			cy++;
			ry--;
			if (!flags.has(NO_COLLIDE))
				testColY();
		}

		if (!flags.has(NO_COLLIDE))
			testColX();

		// process x
		while (rx < 0) {
			cx--;
			rx++;
		}
		while (rx > 1) {
			cx++;
			rx--;
		}
	}

	public function onProc() {}
}
