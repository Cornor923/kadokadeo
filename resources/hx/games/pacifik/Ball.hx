package pacifik;

import pacifik.Gfx;
import pacifik.MC.FilterDef;

class Ball {
	var game:Game;
	var targetX:Float;
	var targetY:Float;
	var yf:Float;
	var xf:Float;
	var speed:Float;

	public var bonus:Bool = false;
	public var moveLeft:Bool;
	// null once cleaned: the ball stays in Game.balls and every test on it fails, like Flash's undefined
	public var mc:BallMC;
	public var type:Int;
	// (port fix) the ball's x and the laser's at its last laser test (Laser.hit): NaN before the first one
	public var lastX:Float = Math.NaN;
	public var lastLaserX:Float = Math.NaN;

	public function new(g:Game, x:Float, y:Float, target:Canon) {
		game = g;
		mc = game.dm.add(new BallMC(), Const.DP_BALL);
		mc.x = x;
		mc._x = x;
		mc.y = y;
		mc._y = y;

		var s = KKApi.val(Const.LEARN_STEP);

		if (s > 1 && Seed.random(100) < KKApi.val(Const.BONUS_BALL_PROBA)) {
			mc.gotoAndPlay(1);
			type = 4;
			bonus = true;
		} else {
			var rand = Seed.random(100);
			var type = 0;
			if (rand < KKApi.val(Const.BALL3_PROBA)) {
				type = 2;
			} else if (rand < KKApi.val(Const.BALL2_PROBA)) {
				type = 1;
			}

			if (s < 3 && s < type) {
				this.type = s;
			} else {
				this.type = type;
			}

			mc.gotoAndStop(this.type + 1);
		}
		targetX = target.mc != null ? target.mc._x : Math.NaN;
		targetY = target.mc != null ? target.mc._y : Math.NaN;
		// (type: the field, 4 for a bonus ball)
		speed = (type + 1) * 0.5 * KKApi.val(Const.BALL_SPEED) / 100;

		var r = Math.atan2(targetY - y, targetX - x);
		yf = Const.q(Math.sin(r) * speed);
		xf = Const.q(Math.cos(r) * speed);
		moveLeft = xf < 0;
		// (a GradientGlowFilter in the colour of the type, never given to the clip: mc.filters = [glow] is commented out)
	}

	public function move(tmod:Float) {
		if (mc == null)
			return;
		mc.x += xf * tmod;
		mc._x = mc.x;
		mc.y += yf * tmod;
		mc._y = mc.y;

		if (mc.x <= -mc.width() / 2)
			clean();
		if (mc != null && mc.x >= Const.HEIGHT + mc.width() / 2)
			clean();
	}

	public function destroy(score:Int) {
		if (score > 0) {
			var s = game.dm.add(new ScoreMC(score, Const.color(type)), Const.DP_CANON);
			s._x = mc.x;
			s._y = mc.y - 5;
			var p = new Phys(s);
			p.timer = 12;
			p.fadeLimit = 10;
			p.fadeType = 0;
			// Filt.glow(p.root, 4, 2, 0x000000)
			s.filters = [Glow(4, 2, 0x000000, 1)];
		}

		// (the sparks are for the eye: the visual random)
		if (bonus) {
			for (i in 0...14) {
				var m = game.dm.add(new Part("mcBallPart"), Const.DP_BALL);
				m.gotoAndStop(Seed.randomVfx(Const.COLORS.length) + 1);
				m._x = mc.x;
				m._y = mc.y;
				m._rotation = Seed.randomVfx(360);
				var p = new Phys(m);
				p.timer = 20;
				var s = KKApi.val(Const.BALL_SPEED);
				var rad = m._rotation * Math.PI / 180;
				p.vx = (0.5) * Math.cos(rad) * s / 100 * (if (Seed.randomVfx(2) == 0) 2 else -2);
				p.vy = (0.5) * Math.sin(rad) * s / 100 * (if (Seed.randomVfx(2) == 0) 2 else -2);
				p.sleep = if (i > 0) i * 3.0 else null;
				p.frict = 1.1;
				p.vsc = 1.15;
				m.glow(Const.COLORS[Seed.randomVfx(Const.COLORS.length)], 8);
			}
			clean();
			return;
		}

		for (i in 0...3) {
			for (j in 0...9) {
				var m = game.dm.add(new Part("mcBallPart"), Const.DP_BALL);
				m.gotoAndStop(type + 1);
				m._x = mc.x;
				m._y = mc.y;
				m._rotation = Seed.randomVfx(360);
				var p = new Phys(m);
				p.timer = 20;
				var s = KKApi.val(Const.BALL_SPEED);
				var rad = m._rotation * Math.PI / 180;
				p.vx = (0.5) * Math.cos(rad) * s / 100 * (if (Seed.randomVfx(2) == 0) 3 else -3);
				p.vy = (0.5) * Math.sin(rad) * s / 100 * (if (Seed.randomVfx(2) == 0) 3 else -3);
				// (asleep, then playing: the sparks of the 2nd and 3rd rows cycle through the 3 colours of mcBallPart)
				p.sleep = if (i > 0) i * 2.0 else null;
				p.frict = 1.05;
				p.vsc = 1.05;
				m.glow(Const.color(type), 8);
			}
		}

		clean();
	}

	public function clean() {
		if (mc != null)
			mc.removeMovieClip();
		mc = null;
	}

	static var learnCycle:Float = KKApi.val(Const.LEARN_CYCLE);

	public static function reset() {
		learnCycle = KKApi.val(Const.LEARN_CYCLE);
	}

	public static function update(tmod:Float) {
		if (KKApi.val(Const.LEARN_STEP) > 2)
			return;
		learnCycle -= tmod;

		if (learnCycle <= 0) {
			Const.LEARN_STEP = KKApi.const(KKApi.val(Const.LEARN_STEP) + 1);
			learnCycle = KKApi.val(Const.LEARN_CYCLE);
		}
	}
}
