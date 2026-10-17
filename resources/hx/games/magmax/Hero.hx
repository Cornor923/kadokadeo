package magmax;

// Hero.mt of the original
class Hero {
	var game:Game;
	var ploc:MC;

	public var mc:MC;
	public var x:Float;
	public var y:Float;

	var speed:Float;
	var wait_tir:Float;
	var tang:Float;
	var ang:Float;
	var tspeed:Float;
	var pow:Int;
	var bonus_time:Float;

	public function new(g:Game) {
		game = g;
		wait_tir = 0;
		mc = game.dmanager.attach(new MC("hero"), Const.PLAN_HERO);
		// (Flash showed the hero one frame at the origin before its first update placed it)
		mc._x = 150;
		mc._y = 150;
		x = 150;
		y = 150;
		ang = 0;
		pow = 1;
		tang = 0;
		speed = 3.5;
		tspeed = 8;
		bonus_time = 0;
	}

	// bounds of mc.col in the stage (where mc was placed at the end of the last update)
	public function colBounds():Array<Float> {
		return Bounds.place(Data.HERO_COL, mc._x, mc._y);
	}

	function genTir() {
		var t = new Tir(game, 0, x, y, Const.q(Math.cos(tang) * tspeed), Const.q(Math.sin(tang) * tspeed));
		game.tirs.push(t);
		ploc = game.dmanager.attach(new MC("plop"), Const.PLAN_HERO);
		ploc._x = x;
		ploc._y = y;
		if (pow == 2) {
			t.mc.gotoAndStop(4);
			t.pow = 2;
		} else if (bonus_time > 0) {
			// setColor(t.mc, 0xFF0000), setColor(ploc, 0xFF0000): the red variants of the SWF pictures
			t.setRed();
			ploc.setClip("plopRed");
		}
		if (tang <= 0)
			ploc.gotoAndStop(Std.int(-tang * 4 / Math.PI) + 1);
		else
			ploc.gotoAndStop(5 + Std.int((-tang + Math.PI) * 4 / Math.PI));
	}

	function moyAng(a:Float, b:Float):Float {
		if (Math.abs(a - b) > Math.PI) {
			if (b < a)
				b += Math.PI * 2;
			else
				b -= Math.PI * 2;
		}
		var p = Const.q(Math.pow(0.7, Timer.tmod));
		a = a * p + b * (1 - p);
		while (a <= Math.PI)
			a += Math.PI * 2;
		while (a > Math.PI)
			a -= Math.PI * 2;
		return a;
	}

	// setColor(mc, col): colour offsets of col (0: none)
	function setColor(m:MC, col:Int) {
		m.setColorOffset(col >> 16, (col >> 8) & 0xFF, col & 0xFF);
	}

	public function update():Bool {
		var dx = 0, dy = 0;

		if (KeyboardManager.isDown(KeyboardManager.LEFT))
			dx--;
		if (KeyboardManager.isDown(KeyboardManager.RIGHT))
			dx++;
		if (KeyboardManager.isDown(KeyboardManager.UP))
			dy--;
		if (KeyboardManager.isDown(KeyboardManager.DOWN))
			dy++;
		var fire = KeyboardManager.isDown(KeyboardManager.SPACE) || KeyboardManager.isDown(KeyboardManager.CONTROL);

		if (bonus_time > 0) {
			bonus_time -= Timer.deltaT;
			if (bonus_time <= 0) {
				// (3, not the 3.5 of the start: the original's)
				speed = 3;
				pow = 1;
				setColor(mc, 0);
			}
		}

		if (dx != 0 || dy != 0) {
			var d = Timer.tmod * speed / Math.sqrt(dx * dx + dy * dy);
			// atan2 of -1 / 0 / 1: the 8 multiples of PI / 4, the same in every browser (not rounded: the frames of
			// the shot sparks are computed from them)
			if (!fire)
				tang = Math.atan2(dy, dx);
			x += dx * d;
			y += dy * d;
			// (the last spark follows the hero; null before the first shot: undefined in Flash, nothing happens)
			if (ploc != null) {
				ploc._x += dx * d;
				ploc._y += dy * d;
			}
		}

		if (x < 15)
			x = 15;
		if (y < 20)
			y = 20;
		if (x > 285)
			x = 285;
		if (y > 290)
			y = 290;

		ang = moyAng(ang, tang);
		if (ang < 0)
			mc.gotoAndStop(Std.int(-ang * 30 / Math.PI) + 1);
		else
			mc.gotoAndStop(31 + Std.int((-ang + Math.PI) * 30 / Math.PI));

		if (wait_tir > 0)
			wait_tir -= Timer.deltaT;
		else if (fire) {
			wait_tir = 0.2 / pow;
			genTir();
		}

		var i = 0;
		while (i < game.monsters.length) {
			var m = game.monsters[i];
			if (Bounds.hit(colBounds(), m.colBounds()))
				return false;
			i++;
		}
		i = 0;
		while (i < game.bonus.length) {
			var b = game.bonus[i];
			b.time -= Timer.deltaT;
			if (Bounds.hit(colBounds(), b.bounds())) {
				game.stats.b[b.t]++;
				switch (b.t) {
					case 3:
						if (pow == 2)
							game.stats.dual++;
						setColor(mc, 0xFF0000);
						speed = 7;
						bonus_time += 8;
					case 4:
						if (speed == 7)
							game.stats.dual++;
						pow = 2;
						bonus_time += 5;
					case 0, 1, 2:
						game.addScore(KKApi.val(Const.BONUS_POINTS[b.t]));
				}
				b.removeMovieClip();
				game.bonus.splice(i--, 1);
			} else if (b.time < 0) {
				b._xscale -= 10 * Timer.tmod;
				b._yscale = b._xscale;
				if (b._xscale < 0) {
					b.removeMovieClip();
					game.bonus.splice(i--, 1);
				}
			}
			i++;
		}

		mc._x = x;
		mc._y = y;
		return true;
	}
}
