package pacifik;

import pacifik.Gfx;
import pacifik.MC.FilterDef;

class Laser {
	var game:Game;
	var mc:MC;
	var curtype:Int;
	var lastType:Int;
	// (undefined until the first move: NaN)
	var lastX:Float = Math.NaN;
	var glowCycles:Int;
	var inter:{x1:Float, x2:Float};
	var pressTimer:Float;

	// GradientGlowFilter(0, 45, [c, c], [0, 1], [0, 255], 8, 8, 2, 3, "outer"): its colour
	var glowColor:Int;

	public function new(g:Game) {
		game = g;
		mc = game.dm.attach("bar", Const.DP_BALL, Game.K);
		mc.x = Const.HEIGHT / 2;
		mc._x = mc.x;
		mc.gotoAndStop(1);
		curtype = 0;
		glowCycles = 0;
		pressTimer = 0.0;

		var color = 0x00FF99;
		glowColor = color;
	}

	public function updatePos(fx:Float) {
		pressTimer++;

		if (game.gameOver) {
			mc._visible = false;
			return;
		}

		if (curtype <= 0)
			mc.filters = [];
		else
			mc.filters = [Glow(8, 2, glowColor, 3)];

		if (fx - lastX < 0)
			inter = {x1: fx, x2: lastX};
		else
			inter = {x1: lastX, x2: fx};

		if (Math.abs(fx - lastX) > KKApi.val(Const.LASER_OFF)) {
			curtype = 0;
			mc.gotoAndStop(1);
		}

		if (fx < Const.CANON_WIDTH) {
			move(Const.CANON_WIDTH);
			return;
		}

		if (fx > Const.HEIGHT - Const.CANON_WIDTH) {
			move(Const.HEIGHT - Const.CANON_WIDTH);
			return;
		}

		move(fx);
	}

	function move(v:Float) {
		lastX = v;
		mc.x = v;
		mc._x = v;
	}

	// root.onPress
	public function switchType() {
		pressTimer = 0.0;

		if (curtype > 2) {
			curtype = 0;
			glowColor = 0x00FF99;
		} else {
			curtype++;
		}

		mc.gotoAndStop(curtype + 1);
		// (curtype 0: Const.COLORS[-1], undefined; the glow is not shown then)
		glowColor = Const.color(curtype - 1);
	}

	// root.onRelease: a long press puts the black laser back
	public function testPress() {
		if (pressTimer > 20) {
			curtype = 0;
			mc.gotoAndStop(1);
			pressTimer = 0.0;
		}
	}

	public function hit(b:Ball) {
		var r = b.mc != null ? b.mc.bounds() : null;
		var bx = b.mc != null ? b.mc.x : Math.NaN;
		var by = b.mc != null ? b.mc.y : Math.NaN;
		// (port fix) the original only tests the ball's new x against the laser's sweep (inter) and its new x: a ball
		// coming towards the laser by more than its width minus the laser's move (a fast ball: cyan, bonus, the speed
		// grows all game long) jumped over it, and the ball skipped by moveBalls after a removed one (its loop) was not
		// tested in that frame. The laser and the ball crossed since the ball's last test: their order changed
		var crossed = false;
		if (b.mc != null) {
			var d0 = b.lastX - b.lastLaserX;
			var d1 = bx - mc.x;
			crossed = (d0 < 0 && d1 > 0) || (d0 > 0 && d1 < 0);
			b.lastX = bx;
			b.lastLaserX = mc.x;
		}
		if (b.bonus) {
			if (curtype > 0) {
				return false;
			}
			if (crossed)
				return true;
			if (bx > inter.x1 && bx < inter.x2) {
				return true;
			}

			if (Const.contains(r, mc.x, by)) {
				return true;
			}
		}

		if (b.type + 1 != curtype) {
			return false;
		}

		if (crossed)
			return true;

		if (bx > inter.x1 && bx < inter.x2) {
			return true;
		}

		if (Const.contains(r, mc.x, by)) {
			return true;
		}
		return false;
	}

	public function hitCar(car:CarMC) {
		if (curtype > 0) {
			if (car._y < car.height() / 2)
				return false;

			var w = car.smcWidth();
			var r = [car._x - w / 2, car._x - w / 2 + w, car._y, car._y + car.smcHeight()];
			if (Const.contains(r, mc.x, car._y)) {
				return true;
			}
			return false;
		}
		return false;
	}

	// (the sparks are for the eye: the visual random)
	public function hitAnim(b:Ball) {
		for (i in 0...10) {
			var m = game.dm.add(new Part("mcLaserPart"), Const.DP_CANON);
			m._x = mc.x;
			m._y = b.mc.y;
			m._yscale = 100 * Seed.randomVfx(3);
			m._rotation = Seed.randomVfx(360);
			var p = new Phys(m);
			p.timer = 5;
			p.vx = Math.cos(m._rotation * Math.PI / 180);
			p.vy = Math.cos(m._rotation * Math.PI / 180);
			m.glow(Const.color(b.type), 8);
		}
	}
}
