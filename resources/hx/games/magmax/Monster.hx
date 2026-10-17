package magmax;

// heliPart of Monster.touched: a piece of the heliflower, moved by Game.main
class Part extends MC {
	public var vx:Float;
	public var vy:Float;
	public var x:Float;
	public var y:Float;
	public var by:Float;
}

// the bonus dropped by a monster
class Bonus extends MC {
	public var t:Int;
	public var time:Float;

	// bounds of the clip in the stage: they follow the nested timelines (the gem, or the option and its particles)
	// and the _xscale of the bonus vanishing
	public function bounds():Array<Float> {
		var r:Array<Float>;
		if (t < 3) {
			r = Data.BONUS_GEM[clip.frameOf("gem") - 1];
		} else {
			r = Bounds.union(Data.BONUS_16[clip.frameOf("o16") - 1], Data.BONUS_19[clip.frameOf("o19") - 1]);
			var o = clip.getClip("o24");
			if (o != null) {
				var a = o.getClip("a");
				if (a != null)
					r = Bounds.union(r, Data.BONUS_PART[0][a.frame - 1]);
				for (i in 0...o.dups.length)
					r = Bounds.union(r, Data.BONUS_PART[i][o.dups[i].frame - 1]);
			}
		}
		return Bounds.place(r, _x, _y, _xscale, _yscale);
	}
}

typedef Pos = {x:Float, y:Float};

// Monster.mt of the original: type 0 the firebomb, 1 the heliflower, 2 the cyblock
class Monster {
	var game:Game;
	var type:Int;

	public var mc:MC;

	var x:Float;
	var y:Float;
	// null until set, like the undefined of Flash (nextStep tests dx != null)
	var dx:Null<Float> = null;
	var dy:Null<Float> = null;
	var speed:Float;
	var nsteps:Int;
	var ang:Float;
	var ray:Float;
	// fields the original reads before setting them: undefined in Flash, NaN in a calculation (every comparison
	// false). The heliflower's `time += deltaT` while it is out of the screen stays NaN until it has come in once:
	// it cannot leave for good before.
	var time:Float = Math.NaN;
	var wait:Float = Math.NaN;
	var flag:Bool = false;
	var next:Pos;
	var pv:Int;
	var flash_time:Float = Math.NaN;

	public function new(g:Game, t:Int) {
		game = g;
		type = t;
		mc = game.dmanager.attach(new MC("monster"), Const.PLAN_MONSTER);
		mc.gotoAndStop(t + 1);
		init();
		mc._x = x;
		mc._y = y;
	}

	// bounds of mc.sub.col in the stage
	public function colBounds():Array<Float> {
		return Bounds.place(Data.MONSTER_COL[type][mc.clip.frameOf("sub") - 1], mc._x, mc._y);
	}

	function subGoto(f:Int) {
		var s = mc.clip.getClip("sub");
		if (s != null)
			s.gotoAndStop(f);
	}

	function genRandPos(out:Bool):Pos {
		var x:Float = Seed.random(260) + 20;
		var y:Float = Seed.random(260) + 20;
		if (out) {
			switch (Seed.random(4)) {
				case 0:
					x = -20;
				case 1:
					x = 320;
				case 2:
					y = -20;
				case 3:
					y = 320;
			}
		}
		return {x: x, y: y};
	}

	function init() {
		var p = genRandPos(true);
		x = p.x;
		y = p.y;

		var ddx = x - game.hero.x;
		var ddy = y - game.hero.y;
		var d = Math.sqrt(ddx * ddx + ddy * ddy);
		if (d < 70) {
			init();
			return;
		}

		switch (type) {
			case 0:
				pv = 5;
				nsteps = 10;
				nextStep();
				dx = next.x - x;
				dy = next.y - y;
				speed = 2 + game.level / 40;
			case 1:
				pv = 3;
				nsteps = 20;
				nextStep();
				dx = Const.q(Math.cos(ang));
				dy = Const.q(Math.sin(ang));
				speed = 4 + game.level / 100;
			case 2:
				pv = 10;
				next = genRandPos(false);
				speed = 2 + game.level / 100;
				time = 0;
		}
	}

	function fire3() {
		var a = Math.atan2(dy, dx);
		var s = 4;
		game.tirs.push(new Tir(game, 1, x, y, Const.q(s * Math.cos(a)), Const.q(s * Math.sin(a))));
		game.tirs.push(new Tir(game, 1, x, y, Const.q(s * Math.cos(a + 0.2)), Const.q(s * Math.sin(a + 0.2))));
		game.tirs.push(new Tir(game, 1, x, y, Const.q(s * Math.cos(a - 0.2)), Const.q(s * Math.sin(a - 0.2))));
	}

	function fire4() {
		var s = 3;
		game.tirs.push(new Tir(game, 2, x, y, -s, -s));
		game.tirs.push(new Tir(game, 2, x, y, -s, s));
		game.tirs.push(new Tir(game, 2, x, y, s, -s));
		game.tirs.push(new Tir(game, 2, x, y, s, s));
	}

	function nextStep() {
		switch (type) {
			case 0:
				next = genRandPos((--nsteps) <= 0);
				if (dx != null && Seed.random(5) == 0) {
					fire3();
					wait = 2;
				}
			case 1:
				next = genRandPos((--nsteps) <= 0);
				ang = Const.q(Math.atan2(y - next.y, x - next.x));
				ray = Math.sqrt((x - next.x) * (x - next.x) + (y - next.y) * (y - next.y));
			case 2:
				next = genRandPos(false);
		}
	}

	public function touched(t:Tir) {
		pv -= t.pow;

		if (pv > 0) {
			if (!game.game_over)
				game.addScore(KKApi.val(Const.MONSTER_POINTS[type]));
			flash_time = 1;
			var vx = x - game.hero.x;
			var vy = y - game.hero.y;
			var v = Math.sqrt(vx * vx + vy * vy);
			// the cyblock never sets dx / dy: NaN in Flash (unused by its moves); stays null here
			if (dx != null) {
				var d = Math.sqrt(dx * dx + dy * dy);
				dx += vx * d / v;
				dy += vy * d / v;
			}
			return;
		}

		game.doCombo(type);

		game.stats.k[type]++;
		mc.removeMovieClip();
		game.monsters.remove(this);

		{
			var b = game.dmanager.attach(new Bonus("bonus"), Const.PLAN_BONUS);
			b._x = x;
			b._y = y;
			if (b._x < 10)
				b._x = 10;
			if (b._y < 10)
				b._y = 10;
			if (b._x > 290)
				b._x = 290;
			if (b._y > 290)
				b._y = 290;
			b.t = Const.randomProbas(Const.BONUS);
			b.time = 15;
			b.gotoAndStop(b.t + 1);
			game.bonus.push(b);
		}

		switch (type) {
			case 0:
				var b = game.dmanager.attach(new MC("boum"), Const.PLAN_PART);
				b._x = x;
				b._y = y;
			case 1:
				for (i in 1...6) {
					var b = game.dmanager.attach(new Part("heliPart"), Const.PLAN_PART);
					b._x = x;
					b._y = y;
					b.gotoAndStop(i);
					b.x = x;
					b.y = 0;
					b.vx = (Seed.random(15) - 7) / 3;
					b.vy = -(5 + Seed.random(4));
					b.by = y;
					game.addPart(b);
				}
			case 2:
				var b = game.dmanager.attach(new MC("blam"), Const.PLAN_PART);
				b._x = x;
				b._y = y;
		}
	}

	// the sub clip faces the move (60 directions)
	function face() {
		var ang = Const.q(Math.atan2(dy, dx));
		if (ang < 0)
			subGoto(Std.int(-ang * 30 / Math.PI) + 1);
		else
			subGoto(31 + Std.int((-ang + Math.PI) * 30 / Math.PI));
		return ang;
	}

	public function update():Bool {
		if (flash_time > 0) {
			flash_time -= Timer.tmod * 0.15;
			if (flash_time < 0)
				mc.setColorOffset(0, 0, 0);
			else {
				var k = Std.int(flash_time * 250);
				mc.setColorOffset(k, k, k);
			}
		}

		if (wait > 0) {
			wait -= Timer.deltaT;
			if (type == 2) {
				time += Timer.tmod;
				if (flag) {
					if (time > 30)
						time = 30;
				} else {
					if (time > 43)
						time = 0;
					else if (time < 30)
						time = time % 14;
				}
				subGoto(Std.int(time + 1));
			}
		} else
			switch (type) {
				case 0:
					var tdx = next.x - x;
					var tdy = next.y - y;
					var p = Const.q(Math.pow(0.95, Timer.tmod));
					dx = dx * p + tdx * (1 - p);
					dy = dy * p + tdy * (1 - p);

					face();

					var s = Timer.tmod * speed / Math.sqrt(dx * dx + dy * dy);
					x += s * dx;
					y += s * dy;
					if (Math.abs(x - next.x) + Math.abs(y - next.y) < Timer.tmod * speed * 2) {
						if (nsteps <= 0) {
							mc.removeMovieClip();
							return false;
						}
						nextStep();
					}
				case 1:
					ray -= Timer.tmod;
					ang += (100 / ray) * 0.05 * Timer.tmod;
					var px = next.x + Const.q(Math.cos(ang) * ray);
					var py = next.y + Const.q(Math.sin(ang) * ray);
					var tdx = px - x;
					var tdy = py - y;

					var p = Const.q(Math.pow(0.95, Timer.tmod));

					dx = dx * p + tdx * (1 - p);
					dy = dy * p + tdy * (1 - p);
					var s = speed * Timer.tmod / Math.sqrt(dx * dx + dy * dy);

					x += dx * s;
					y += dy * s;

					// (the original tests `ang > Math.PI * 2` on the local angle of the move, from atan2: never true)
					var moveAng = face();

					if (ray < 20 || moveAng > Math.PI * 2)
						nextStep();

					if (x < -10 || y < -10 || x > 310 || y > 310) {
						time += Timer.deltaT;
						if (time > 3) {
							mc.removeMovieClip();
							return false;
						}
					} else
						time = 0;
				case 2:
					if (flag) {
						flag = false;
						fire4();
						wait = 1;
						nextStep();
						return true;
					}

					time += Timer.tmod;
					subGoto(Std.int(time % 14 + 1));

					// move
					var p = Const.q(Math.pow(0.97, Timer.tmod));
					x = x * p + next.x * (1 - p);
					y = y * p + next.y * (1 - p);

					var ddx = next.x - x;
					var ddy = next.y - y;
					var d = Math.sqrt(ddx * ddx + ddy * ddy);

					if (d < 20) {
						flag = true;
						wait = 2;
						time = time % 14;
					}
			}

		mc._x = x;
		mc._y = y;
		return true;
	}
}
