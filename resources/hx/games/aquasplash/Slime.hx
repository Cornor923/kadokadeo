package aquasplash;

import aquasplash.Data.HitMask;
import aquasplash.Game.Pos;

class Slime {
	public static var MAX_GROW = 4;

	public var grow:Int;
	public var pos:Pos;
	public var bonus:Bool;
	public var wait:Null<Float>;

	public var mc:SlimeMC;
	public var mcBonus:MC;

	public function new(p:Pos) {
		grow = 1;
		pos = p;
		bonus = false;

		mc = Game.me.sdm.add(new SlimeMC(this), 3);
		setSkin();
		var p = Cs.getPos(pos, true);
		mc._x = p.x;
		mc._y = p.y;
		mc._alpha = Cs.ALPHA_SLIME;
		mc._xscale = 100;

		// mc.onRollOver / onRollOut / onRelease: Flash buttons, polled by Game.updateMouse (rollOver, rollOut, touch)
	}

	// onRollOver: the slime under the mouse grows (and faces right: its flip is lost)
	public function rollOver() {
		mc._xscale = 110;
		mc._yscale = mc._xscale;
	}

	public function rollOut() {
		mc._xscale = 100;
		mc._yscale = mc._xscale;
	}

	public function addBonus() {
		if (bonus)
			return;

		bonus = true;
		growTo(0);

		mcBonus = Game.me.sdm.attach("playBonus", 3);
		var p = Cs.getPos(pos, true);
		mcBonus._x = p.x;
		mcBonus._y = p.y;
	}

	public function toExplode():Bool {
		return grow > 4;
	}

	public function growTo(l) { // for level init
		grow = l;
		setSkin();
	}

	public function growing() {
		if (bonus) {
			explode();
			return;
		}

		grow++;
		setSkin();

		if (bigEnough())
			explode();
	}

	public function ungrowing():Bool {
		if (wait != null && wait > 0) {
			wait--;
			return false;
		}

		var oldG = grow;
		grow = 0;

		pSmoke();

		if (grow <= 0) {
			grow = 0;

			var mcExplode = Game.me.dm.attach("burn", Game.DP_ANIM);
			mcExplode.removeAt = 16;
			// the slime picture goes at once: the burn shows in the same step
			mcExplode.showNow = true;
			mcExplode._x = mc._x;
			mcExplode._y = mc._y;
			// (SCALE_SLIME[-2] of a bonus that forceReduce brought to -1: undefined, a scale Flash ignores)
			var sc:Null<Int> = Cs.SCALE_SLIME[oldG - 1];
			if (sc != null) {
				mcExplode._xscale = sc;
				mcExplode._yscale = mcExplode._xscale;
			}

			setSkin();

			// Game.me.incExplode(pos) ;

			Game.me.slimes.remove(this);

			Game.me.addScore(Cs.SPOUT_POINTS);
		}
		return true;
	}

	public function setSkin() {
		if (grow > 0)
			mc.gotoAndStop(grow);
		else
			mc.gotoAndStop(5);
	}

	public function bigEnough():Bool {
		return grow > MAX_GROW;
	}

	public function touch() {
		if (Game.me.isLocked() || Game.me.checkEnd() || bonus)
			return;
		Game.me.lock();

		Game.me.downPlay();

		if (grow > 0) { // growing
			grow++;

			if (bigEnough()) {
				Game.me.initSploutch(this);
				return;
			}
			mc.gotoAndStop(grow);
		} else { // flame
			Game.me.toReduce = [];
			for (s in Game.me.slimes) {
				if (s.grow == 0)
					continue;
				if (isAdjacent(s.pos)) {
					s.wait = Seed.random(7);
					Game.me.toReduce.push(s);
				}

				if (Game.me.toReduce.length == 8)
					break;
			}

			Game.me.initBombing(pos);
			return;
		}

		Game.me.setPlay();
	}

	public function explode() {
		if (!bigEnough() && !bonus)
			return;

		if (bonus) {
			Game.me.getBonus(pos);

			// dm.attach("bExplod", DP_ANIM): gfx.swf exports no "bExplod", Flash attaches nothing (only the particles show)
			/*if (bonus)
				Col.setPercentColor(mcExplode, 100, Cs.BONUS_COLOR) ; */
			pBonus();
		} else {
			Game.me.incExplode(pos);
			var points = KKApi.cadd(Cs.SPOUT_POINTS, KKApi.cmult(KKApi.const(Game.me.explosion), Cs.SPOUT_CHAIN));
			Game.me.addScore(points);

			var mcExplode = Game.me.dm.attach("explode", Game.DP_ANIM);
			mcExplode.removeAt = 7;
			// the slime picture goes at once: the explosion shows in the same step
			mcExplode.showNow = true;
			mcExplode._x = mc._x;
			mcExplode._y = mc._y;
		}

		grow = 0;
		mc.gotoAndStop(5);
		Game.me.slimes.remove(this);

		if (!bonus) {
			Drop.launch(pos);
		} else {
			mcBonus.removeMovieClip();
			bonus = false;
		}
	}

	public function kill() {
		mc.removeMovieClip();

		Game.me.allSlimes.remove(this);
		Game.me.slimes.remove(this);
	}

	public function isAdjacent(p:Pos):Bool {
		if (p == null)
			return false;
		return Math.abs(p.x - pos.x) <= 1 && Math.abs(p.y - pos.y) <= 1;
	}

	public static function getRandomGrow(l:Int):Int {
		var r = Seed.random(100);

		var mod = Math.floor(l * 2);
		var g = 0;

		var caps = [23, 38, 55, 81];

		if (r < caps[0] - Std.int(mod / 2))
			g = 0;
		else if (r < caps[1] - Std.int(mod / 2))
			g = if (l == 0) 2 else (if (l > 10) Seed.random(2) + 1 else 1);
		else if (r < caps[2] + mod)
			g = if (l > 10) Seed.random(2) + 1 else 2;
		else if (r < caps[3] + mod)
			g = 3;
		else
			g = 4;
		return g;
	}

	// ### PARTS (pictures only: visual random)
	public function pBonus() {
		var nb = 10 + Seed.randomVfx(5);
		var p = Cs.getPos(pos, true);
		var px = p.x;
		var py = p.y;

		for (i in 0...nb) {
			var mc = Game.me.dm.attach("partLight", Game.DP_PARTS);

			var a = (i + Seed.randVfx()) / nb * 6.28;
			var ca = Math.cos(a);
			var sa = Math.sin(a);
			var sp = 0.5 + Seed.randVfx() * 10;

			var dx = ca * sp + 0.4;
			var dy = sa * sp + 0.4;

			var s = new Phys(mc);
			s.root.setAdd();
			var sc = 40 + Seed.randomVfx(60);
			s.root._xscale = sc;
			s.root._yscale = sc;

			s.x = px;
			s.y = py;
			s.frict = 0.9;
			s.vx = dx;
			s.vy = dy;
			s.fadeType = 5;
			s.timer = 10 + Seed.randomVfx(10);

			if (Sprite.spriteList.length - 81 > 40 && i > 3)
				break;
		}
	}

	public function pSmoke() {
		var nb = 10 + Seed.randomVfx(5);
		var p = Cs.getPos(pos, true);
		var px = p.x;
		var py = p.y;

		for (i in 0...nb) {
			var mc = Game.me.dm.attach("partSmoke", Game.DP_PARTS);

			var dx = (Seed.randVfx() * 2 - 1) * (Seed.randVfx() * 1);
			var dy = -1;

			var s = new Phys(mc);
			s.root.gotoAndStop(1);
			s.root._alpha = 20 + Seed.randomVfx(40);
			s.x = px;
			s.y = py;
			s.weight = -0.2;
			// s.frict = 0.90 ;
			s.vx = dx;
			s.vy = dy;
			s.vr = (Seed.randomVfx(2) * 2 - 1) * Seed.randVfx() * 50;
			s.fadeType = 5;
			s.timer = 10 + Seed.randomVfx(10);
			s.sleep = Seed.randomVfx(10);

			if (Sprite.spriteList.length - 81 > 40 && i > 3)
				break;
		}
	}
}

/**
 * The slime clip (sprite 126), stopped by the code on frames 1-5. Frames 1-4 hold a goute that plays once from its
 * first frame each time the slime changes frame, and stops on its last one; goutes 3 and 4 then show eyes (sprite
 * 110) that roll random(120) on every frame (gotoAndPlay(2) on its frame 3) and play eyeClose on a 1 in 120 chance:
 * a blink (frames 2-4, stop() on 5) when eyeClose is on frame 1, nothing to see when it is on 5 (it goes back to 1).
 * Frame 5 only holds an invisible square: no picture, still a button.
 */
class SlimeMC extends MC {
	public var slime(default, null):Slime;
	public var frame(default, null):Int = 0;

	var goute:Int = 1;
	var eyeAge:Int = 0;
	var eye:Int = 1;
	var eyePlaying:Bool = false;

	public function new(slime:Slime) {
		super(null, Game.K);
		this.slime = slime;
	}

	override public function gotoAndStop(f:Int):Void {
		if (removed)
			return;
		if (f < 1)
			f = 1;
		if (f > 5)
			f = 5;
		if (f == frame)
			return;
		frame = f;
		goute = 1;
		eyeAge = 0;
		eye = 1;
		eyePlaying = false;
		if (f < 5)
			setFrames("slime" + f);
		else
			setEmpty();
		_currentframe = picture();
	}

	override function advance():Void {
		if (removed || frame >= 5)
			return;
		var n = Data.GOUTE_FRAMES[frame - 1];
		if (goute < n) {
			goute++;
		} else if (Data.GOUTE_BLINK[frame - 1]) {
			if (eyePlaying) {
				eye = eye % 5 + 1;
				if (eye == 1 || eye == 5)
					eyePlaying = false;
			}
			// the eyes clip is placed on the goute's last frame, its blink roll starts on the next one
			eyeAge++;
			if (eyeAge > 1 && Seed.randomVfx(120) == 1)
				eyePlaying = true;
		}
		_currentframe = picture();
	}

	function picture():Int {
		if (frame >= 5)
			return 1;
		var n = Data.GOUTE_FRAMES[frame - 1];
		if (goute < n)
			return goute;
		if (Data.GOUTE_BLINK[frame - 1] && eye >= 2 && eye <= 4)
			return n + eye - 1;
		return n;
	}

	// bounds of the picture shown, on the stage (the slime plane is at the origin of the root) [xmin, xmax, ymin, ymax]
	public function stageBounds():Array<Float> {
		var b = frame >= 5 ? Data.SLIME5_BOUNDS : Data.SLIME_BOUNDS[frame - 1][picture() - 1];
		var sx = _xscale / 100, sy = _yscale / 100;
		var ax = _x + b[0] * sx, bx = _x + b[1] * sx;
		var ay = _y + b[2] * sy, by = _y + b[3] * sy;
		return [Math.min(ax, bx), Math.max(ax, bx), Math.min(ay, by), Math.max(ay, by)];
	}

	// the shapes of the clip under the stage point (fx, fy): the hit area of the button
	public function hitTest(fx:Float, fy:Float):Bool {
		if (_xscale == 0 || _yscale == 0)
			return false;
		var m:HitMask = frame >= 5 ? Data.SLIME5_MASK : Data.SLIME_MASKS[frame - 1][picture() - 1];
		var ix = Math.floor((fx - _x) / (_xscale / 100) * Game.K);
		var iy = Math.floor((fy - _y) / (_yscale / 100) * Game.K) - m.y;
		var rows = maskRows(m);
		if (iy < 0 || iy >= rows.length)
			return false;
		var r = rows[iy];
		var i = 0;
		while (i < r.length) {
			if (ix >= r[i] && ix < r[i + 1])
				return true;
			i += 2;
		}
		return false;
	}

	static var masks:Map<String, Array<Array<Int>>> = new Map();

	static function maskRows(m:HitMask):Array<Array<Int>> {
		var r = masks.get(m.rows);
		if (r == null) {
			r = [];
			for (row in m.rows.split(";")) {
				var runs = [];
				if (row != "")
					for (run in row.split(",")) {
						// (runs may start left of the origin: "-12-30" is -12 to 30)
						var dash = run.indexOf("-", 1);
						runs.push(Std.parseInt(run.substr(0, dash)));
						runs.push(Std.parseInt(run.substr(dash + 1)));
					}
				r.push(runs);
			}
			masks.set(m.rows, r);
		}
		return r;
	}
}
