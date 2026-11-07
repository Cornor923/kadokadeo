package zipzap;

import common_haxe_avm1.KeyboardManager;
import kado.Seed;
import mt.Timer;
import mt.bumdum.Lib;

class Hero {
	public var y:Float;
	public var mc:ASprite;

	var x:Float;
	var game:Game;
	var a:Float;
	var lock:Bool;

	public var moving:Null<Int>;

	var gameOver:Bool;

	public var ty:Null<Float>;

	var r:Float;

	public function new(g:Game) {
		game = g;
		mc = game.dmanager.attach("hero", Cs.PLAN_HERO);
		mc.onFrame.set(26, function() {
			mc.gotoAndPlay(1);
		});
		mc.onFrame.set(46, function() {
			mc.gotoAndPlay(1);
		});
		mc.stopOnFrame = [33, 50];
		a = 0;
		x = KadoKadeoManager.I(25);
		y = KadoKadeoManager.I(150);
		mc._x = x;
		mc._y = y;
		r = Seed.random(4) + 3;
	}

	public function action():Void {
		if (!lock) {
			// a move, by the mouse or the keyboard (the achievement fast_finish)
			game.stats.m++;
			game.stats.pa.push([0, 0, 0, 0, 0, 0]);
			lock = true;
			moving = (x < KadoKadeoManager.I(150)) ? 1 : -1;
			mc.gotoAndPlay(30);
			game.last = null;
		}
	}

	public function doGameOver():Void {
		gameOver = true;
		a = -KadoKadeoManager.I(1);
		mc.gotoAndStop(50);
	}

	public function update(steps:Int):Void {
		var dx = KadoKadeoManager.I(20) / steps;
		var dy = KadoKadeoManager.S((moving != null) ? 5 : 10) / steps;

		if (gameOver) {
			a += KadoKadeoManager.S(0.03 * Timer.tmod);
			x += ((mc._xscale < 0) ? -1 : 1) * Timer.tmod / KadoKadeoManager.I(2);
			y += a * Timer.tmod;

			if (y > KadoKadeoManager.I(280)) {
				y = KadoKadeoManager.I(280) - (y - KadoKadeoManager.I(280));
				a = -Math.abs(a) * 0.8;
				r = Seed.random(10) - 4;
			}

			mc._rotation += r * Timer.tmod;
			mc._x = x;
			mc._y = y;
			return;
		}

		if (KeyboardManager.isDown(KeyboardManager.UP)) {
			y -= dy * Timer.tmod;
			if (y < KadoKadeoManager.I(20)) {
				y = KadoKadeoManager.I(20);
			}
		} else if (KeyboardManager.isDown(KeyboardManager.DOWN)) {
			y += dy * Timer.tmod;
			if (y > KadoKadeoManager.I(285)) {
				y = KadoKadeoManager.I(285);
			}
		}
		if (moving != null) {
			x += moving * dx * Timer.tmod;
			if (x > KadoKadeoManager.I(275) || x < KadoKadeoManager.I(25)) {
				if (x > KadoKadeoManager.I(275)) {
					x = KadoKadeoManager.I(275);
				} else {
					x = KadoKadeoManager.I(25);
				}
				mc._xscale = (x > KadoKadeoManager.I(150)) ? -100 : 100;
				mc.gotoAndPlay(40);
				moving = null;
			}
		} else {
			if (KeyboardManager.isDown(KeyboardManager.SPACE)
				|| (KeyboardManager.isDown(KeyboardManager.RIGHT) && x < KadoKadeoManager.I(150))
				|| (KeyboardManager.isDown(KeyboardManager.LEFT) && x > KadoKadeoManager.I(150))) {
				action();
			} else {
				lock = false;
			}
		}

		if (ty != null) {
			var p = Math.pow((moving == null) ? 0.7 : 0.99, Timer.tmod);
			y = Num.q(y * p + ty * (1 - p));
			if (Math.abs(ty - y) < KadoKadeoManager.I(5)) {
				y = ty;
				ty = null;
			}
			if (y < KadoKadeoManager.I(20)) {
				y = KadoKadeoManager.I(20);
			} else if (y > KadoKadeoManager.I(285)) {
				y = KadoKadeoManager.I(285);
			}
		}

		a += Timer.tmod / (10 * steps);
		var tx = Num.q(x + Math.cos(a) * KadoKadeoManager.I(5));
		var ty = Num.q(y + Math.sin(a) * KadoKadeoManager.I(5));
		var p = Math.pow(0.7, Timer.tmod);
		var gfxX = Num.q(mc._x * p + tx * (1 - p));
		var gfxY = Num.q(mc._y * p + ty * (1 - p));
		mc._x = gfxX;
		mc._y = gfxY;

		if (moving != null) {
			var r = Ballon.ray + KadoKadeoManager.I(5);
			r = r * r;
			var i = 0;
			while (i < game.getBalsLength()) {
				var b = game.bals[i];
				dx = Num.q(this.x - b.x + KadoKadeoManager.I(12));
				dy = Num.q(this.y - b.y + KadoKadeoManager.I(10));
				if (dx * dx + dy * dy < r) {
					var idx = game.getBallon(b);
					game.stats.pa[game.stats.pa.length - 1][idx]++;
				}
				i++;
			}
		}
	}
}
