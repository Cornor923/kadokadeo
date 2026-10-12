package invasion;

import pixi.filters.colormatrix.ColorMatrixFilter;

class McSprite extends ASprite {
	public var sub:ASprite;
}

class FxSprite extends ASprite {
	public var remove:Bool;
	// public var visible:Bool;
}

class Perso {
	public var x:Int;
	public var y:Int;

	public var anim_delta:Float;
	public var adx:Int;
	public var ady:Int;

	public var mc:McSprite;
	public var hero:Bool;
	public var game:Game;
	public var kind:Int;
	public var cursig:Int;
	public var dir:Int;

	public var fx:FxSprite;
	public var goutte:ASprite;

	public function new(g, h, x, y) {
		game = g;
		hero = h;
		anim_delta = 0;
		adx = 0;
		ady = 0;
		this.x = x;
		this.y = y;
		dir = game.dir(0, 1);
		if (hero)
			kind = 0;
		else
			kind = randomProbas(Cs.PROBAS_MONSTERS);

		fx = cast game.dmanager.attach(hero ? "hero-apparition" : "monster-apparition", Cs.PLAN_PERSO);
		fx.loop = false;
		fx.onFrame.set(19, function() {
			fx.remove = true;
		});
		fx.removeOnFrame = 23;

		fx.play();

		if (!hero && game.state != Game.PLACE) {
			this.goutte = cast game.dmanager.attach("goutte", Cs.PLAN_FX);
		}

		colorize(fx);
		Cs.pos(fx, x, y);
		game.dmanager.compact(Cs.PLAN_PERSO);
		game.dmanager.ysort(Cs.PLAN_PERSO);
		game.wait.push(this);
	}

	public function colorize(mc:ASprite) {
		var color:pixi.core.renderers.webgl.filters.Filter = null;
		switch (kind) {
			case 1:
				var c = new ColorMatrixFilter();
				c.matrix = [
					0, 1, 0, 0, 0,
					0, 1, 0, 0, 0,
					1, 0, 0, 0, 0,
					0, 0, 0, 1, 0,
					0, 0, 0, 0, 1,
				];
				color = c;
			case 2:
				var c = new ColorMatrixFilter();
				c.matrix = [
					0, 1, 0, 0, 0,
					1, 0, 0, 0, 0,
					0, 0, 1, 0, 0,
					0, 0, 0, 1, 0,
					0, 0, 0, 0, 1,
				];
				color = c;
		}
		if (color != null) {
			mc.filters = [color];
		}
	}

	public function attach() {
		mc = cast game.dmanager.attach(hero ? "hero" : "monster", Cs.PLAN_PERSO);
		mc.gotoAndStop(3);
		colorize(mc);
		game.dmanager.compact(Cs.PLAN_PERSO);
		game.dmanager.ysort(Cs.PLAN_PERSO);
		update();
	}

	public function color(col) {
		var k = 75;
		var val = (100 - k) / 100;
		var rb = Std.int((col >> 16) * k / 100);
		var gb = Std.int(((col >> 8) & 0xFF) * k / 100);
		var bb = Std.int((col & 0xFF) * k / 100);
		var filter = new ColorMatrixFilter();

		filter.matrix = [
			val,   0,   0, 0, rb / 255,
			  0, val,   0, 0, gb / 255,
			  0,   0, val, 0, bb / 255,
			  0,   0,   0, 1,        0
		];

		mc.filters = [filter];
	}

	public function update() {
		if (mc == null) {
			return;
		}
		Cs.pos(mc, x, y);
		mc._x += adx * anim_delta;
		mc._y += ady * anim_delta;
		if (anim_delta == 0)
			mc.gotoAndStop(dir + 1);
	}

	public function destroy() {
		fx = cast game.dmanager.attach(hero ? "disparition-hero" : "disparition-monster", Cs.PLAN_FX);
		Cs.pos(fx, x, y);
		fx._x += Cs.SIZE / 2;
		fx._y += Cs.SIZE / 2;
		fx.play();
		fx.removeOnFrame = 15;
		fx.remove = true;
		game.wait.push(this);
	}

	public function move(dx, dy, att) {
		dir = game.dir(dx, dy); // Should be bool
		x += dx;
		y += dy;
		adx = -dx;
		ady = -dy;
		anim_delta = Cs.SIZE;
		if (mc != null) {
			if (hero)
				mc.gotoAndStop(dir + (att ? 10 : 6));
			else
				mc.gotoAndStop(dir + 7);
		}
		update();
	}

	public function anim() {
		anim_delta -= mt.Timer.tmod * Cs.S(3);
		if (anim_delta < 0)
			anim_delta = 0;
		update();
		return (anim_delta != 0);
	}

	public function signal(s) {
		cursig = s;
		switch (s) {
			case null:
				if (!hero) {
					if (goutte != null) {
						goutte.removeMovieClip();
					}
				}
			case Cs.SDEF_FIRST: // 5
				if (!hero) {
					if (goutte != null) {
						goutte.removeMovieClip();
					}
					goutte = game.dmanager.attach("goutte", Cs.PLAN_FX);
					Cs.pos(goutte, x, y);
					var tmp = [[6, -10], [22, -9], [6, -12], [9, -10]];
					goutte.play();
					goutte._x += Cs.S(tmp[dir][0]);
					goutte._y += Cs.S(tmp[dir][1]);
					goutte.removeOnFrame = 29;
				}
		}
	}

	public function randomProbas(probas:Array<Int>):Int {
		var total = 0;
		for (v in probas) {
			total += v;
		}
		if (total <= 0) {
			return 0;
		}
		var rnd = Seed.random(total);
		for (i in 0...probas.length) {
			rnd -= probas[i];
			if (rnd < 0) {
				return i;
			}
		}
		return 0;
	}
}
