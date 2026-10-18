package mt.deepnight;

import kado.Seed;

// On the AS3 display list of arkadeo: a Sprite (children allowed), the random draws on KadoKadeo's visual random (the
// effects of a replay are the ones of the game), a scale changed by ds / dsx / dsy that stops at 0, destroy() frees the
// particle at once.
class Particle extends arkadeo.Sprite {
	public static var ALL:Array<Particle> = [];
	public static var DEFAULT_BOUNDS:arkadeo.Rectangle = null;
	public static var AUTO_RESET_SETTINGS = true;
	public static var GX = 0;
	public static var GY = 0.4;
	public static var WINDX = 0.0;
	public static var WINDY = 0.0;
	public static var DEFAULT_SNAP_PIXELS = true;
	public static var LIMIT:Int = 1000;

	var rx:Float; // real x,y
	var ry:Float;

	public var dx:Float;
	public var dy:Float;
	public var da:Float; // alpha
	public var ds:Float; // scale
	public var dsx:Float; // scaleX
	public var dsy:Float; // scaleY
	public var frictX:Float;
	public var frictY:Float;
	public var frict(never, set):Float;
	public var gx:Float;
	public var gy:Float;
	public var dr:Float;
	public var bounce:Float;
	@:isVar public var life(default, set):Float;

	var rlife:Float;
	var maxLife:Float;

	public var bounds:Null<arkadeo.Rectangle>;
	public var fl_wind:Bool;
	public var groundY:Null<Float>;
	public var groupId:Null<String>;

	@:isVar public var delay(default, set):Float;

	public var onStart:Null<Void->Void>;
	public var onBounce:Null<Void->Void>;
	public var onUpdate:Null<Void->Void>;
	public var onKill:Null<Void->Void>;

	public var pixel:Bool;
	public var killOnLifeOut:Bool;
	public var ignoreLimit:Bool; // if TRUE, cannot be killed by the performance LIMIT

	public function new(?x:Float, ?y:Float, ?pt:{x:Float, y:Float}) {
		super();
		if (pt != null) {
			x = pt.x;
			y = pt.y;
		}
		setPos(x, y);
		dx = dy = da = ds = dsx = dsy = 0;
		ignoreLimit = false;
		bounce = 0.85;
		dr = 0;
		if (AUTO_RESET_SETTINGS)
			reset();
		else {
			gx = GX;
			gy = GY + Seed.randomVfx(Std.int(GY * 10)) / 10;
			frictX = 0.95 + Seed.randomVfx(40) / 1000;
			frictY = 0.97;
		}
		delay = 0;
		life = 32 + Seed.randomVfx(32);
		pixel = DEFAULT_SNAP_PIXELS;
		bounds = DEFAULT_BOUNDS;
		killOnLifeOut = false;
		fl_wind = true;
		ALL.push(this);
		this.mouseChildren = this.mouseEnabled = false;
	}

	function set_delay(d:Float):Float {
		visible = d <= 0;
		return delay = d;
	}

	function set_life(l:Float):Float {
		if (l < 0)
			l = 0;
		life = l;
		rlife = l;
		maxLife = l;
		return l;
	}

	inline function set_frict(f:Float):Float {
		return frictX = frictY = f;
	}

	public inline function time() {
		return 1 - (rlife + alpha) / (maxLife + 1);
	}

	public inline function drawBox(w:Float, h:Float, col:Int, ?a = 1.0) {
		graphics.clear();
		graphics.beginFill(col, a);
		graphics.drawRect(-Std.int(w / 2), -Std.int(h / 2), w, h);
		graphics.endFill();
	}

	// a disc, or a circle line (`fill` false, `thickness`)
	public inline function drawCircle(r:Float, col:Int, ?a = 1.0, ?fill = true, ?thickness = 0.0) {
		graphics.clear();
		if (fill && thickness <= 0) {
			graphics.beginFill(col, a);
			graphics.drawCircle(0, 0, r);
			graphics.endFill();
		} else {
			graphics.lineStyle(thickness > 0 ? thickness : 1, col, a);
			graphics.drawCircle(0, 0, r);
		}
	}

	public inline function drawDot(w:Int, col:Int, ?a = 1.0) {
		drawBox(w, w, col, a);
	}

	public inline function reset() {
		gx = gy = dx = dy = dr = 0;
		frictX = frictY = 1;
	}

	public static function makeExplosion(n:Int, x, y, powX:Int, ?powY:Int) {
		if (powY == null)
			powY = Math.round(powX * 2);
		var list = new List();
		for (i in 0...n) {
			var p = new Particle(x + Seed.randomVfx(700) / 1000 * sign(), y + Seed.randomVfx(700) / 1000 * sign());
			p.dx = Seed.randomVfx(powX * 1000) / 1000 * sign();
			p.dy = -Seed.randomVfx(powY * 1000) / 1000;
			if (i < n * 0.3)
				p.dy *= 1 + randFloat(2);
			if (i >= n * 0.3 && i < n * 0.6)
				p.dx *= 1 + randFloat(2);
			list.add(p);
		}
		return list;
	}

	public static function makeDust(n:Int, x, y) {
		var list = new List();
		for (i in 0...n) {
			var p = new Particle(x + randFloat(7) * sign(), y + randFloat(7) * sign());
			p.dx = randFloat(0.8) * sign();
			p.dy = -randFloat(0.8);
			p.gx = randFloat(0.02) * sign();
			p.gy = randFloat(0.02) * sign();
			list.add(p);
		}
		return list;
	}

	// out of ALL and of the display list, its node freed
	public function destroy() {
		ALL.remove(this);
		detach();
		node.destroy({children: true});
	}

	public inline function getSpeed() {
		return Math.sqrt(dx * dx + dy * dy);
	}

	public static inline function sign() {
		return Seed.randomVfx(2) * 2 - 1;
	}

	public static inline function randFloat(f:Float) {
		return Seed.randomVfx(Std.int(f * 10000)) / 10000;
	}

	public inline function moveAng(a:Float, spd:Float) {
		dx = Math.cos(a) * spd;
		dy = Math.sin(a) * spd;
	}

	public inline function setPos(x, y) {
		rx = this.x = x;
		ry = this.y = y;
	}

	public static function clearAll() {
		for (p in ALL.copy())
			p.destroy();
		ALL = [];
	}

	public static function update(?tmod = 1.0) {
		var i = 0;
		var all = ALL;
		var wx = WINDX;
		var wy = WINDY;
		var limit = LIMIT;

		var count = all.length;
		while (i < count) {
			var p = ALL[i];
			var wind = (p.fl_wind ? 1 : 0);
			// p.visible = p.delay<=0;
			p.delay -= tmod;
			if (p.delay > 0)
				i++;
			else {
				if (p.onStart != null) {
					var cb = p.onStart;
					p.onStart = null;
					cb();
				}

				// gravité
				p.dx += tmod * (p.gx + wind * wx);
				p.dy += tmod * (p.gy + wind * wy);

				// friction
				p.dx *= Math.pow(p.frictX, tmod);
				p.dy *= Math.pow(p.frictY, tmod);

				// mouvement
				p.rx += tmod * p.dx;
				p.ry += tmod * p.dy;

				if (p.groundY != null && p.dy > 0 && p.ry >= p.groundY) {
					p.dy = -p.dy * p.bounce;
					p.ry = p.groundY - 1;
					if (p.onBounce != null)
						p.onBounce();
				}

				if (p.pixel) {
					p.x = Std.int(p.rx);
					p.y = Std.int(p.ry);
				} else {
					p.x = p.rx;
					p.y = p.ry;
				}

				p.rotation += p.dr * tmod;
				// (a shrinking scale stops at 0 instead of growing back mirrored)
				if (p.ds + p.dsx != 0)
					p.scaleX = Math.max(0, p.scaleX + (p.ds + p.dsx) * tmod);
				if (p.ds + p.dsy != 0)
					p.scaleY = Math.max(0, p.scaleY + (p.ds + p.dsy) * tmod);

				if (p.rlife > 0 && p.da != 0) {
					p.alpha += p.da * tmod;
					if (p.alpha > 1) {
						p.da = 0;
						p.alpha = 1;
					}
				}

				p.rlife -= tmod;

				if (p.rlife <= 0 || !p.ignoreLimit && i < all.length - limit)
					p.alpha -= 0.1 * tmod;

				if (p.rlife <= 0 && (p.alpha <= 0 || p.killOnLifeOut) || p.bounds != null && !p.bounds.contains(p.rx, p.ry)) {
					// Destruction
					all.splice(i, 1);
					count--;
					if (p.onKill != null)
						p.onKill();
					p.detach();
				} else {
					if (p.onUpdate != null)
						p.onUpdate();
					i++;
				}
			}
		}
	}
}
