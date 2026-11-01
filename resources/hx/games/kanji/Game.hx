package kanji;

import common_haxe_avm1.KeyboardManager;
import haxe.io.UInt16Array;
import kado.TouchControlsConfig;
import kado.TouchControlsConfig.TouchControlsMode;
import kado.TouchControlsConfig.TouchButtonShape;

// Kanji (KadoKado, Motion-Twin): ported from the original sources (Manager, Const, Game, Hero, Jama, Bonus of the
// kanji folder) and the graphics of its SWF. Kanji the ninja jumps over the animals of the zoo (stork, bee, boar)
// and catches the zen symbols. The game runs in the Flash pixels of the original (300 x 300), drawn x2.
@:expose('GameKanji')
class Game implements kado.GameInterface {
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		buttons: [
			{
				id: "left",
				label: "◀",
				leftPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.LEFT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "right",
				label: "▶",
				leftPx: 90,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.RIGHT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "jump",
				label: "▲",
				rightPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.SPACE,
				shape: TouchButtonShape.SQUARE,
			},
		],
	};

	// ZQSD / WASD like the arrows, Enter like Space
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE.concat(KeyboardManager.ALIASES_ENTER_SPACE);

	public static inline var K = 2;

	// Manager.main: the game is played 5 times per frame, with tmod / 5
	public static inline var NSTEPS = 5;

	public static var me:Game;

	public var root:ASprite;
	public var hero:Hero;

	var death:Clip;

	public var game_over:Bool;

	public var dmanager:Plans;
	public var entities:Array<ASprite>;

	var bonuses:Array<Bonus>;

	public var jamas:Array<Jama>;

	var nb:Int;

	public var level:Int;

	var avg_tmod:Float;
	var death_y:Float;

	var bonusProbas:Array<Int>;

	// sent to the server at the end of the run (app/Achievements/Rules/Games/Kanji)
	public var stats:{
		t:Int,
		l:Int,
		n:Int,
		b:Array<Int>,
		m:Array<Int>,
		k:Int, // storks bounced on
		ks:Int, // best streak of storks bounced on without touching the ground
		wj:Int, // bounces on the walls while jumping
		bs:Int, // best number of symbols caught in one jump without bouncing on a stork
		ba:Int, // boars avoided
		bas:Int, // boars avoided with a small jump (the boar passing just under Kanji)
		lk:Int, // storks bounced on while being the last one alive
		fksc:Int, // score when the first stork is bounced on (-1: never, a stork can be bounced on at 0 points)
		fs:Int, // longest time in the air, in frames (32 per second)
	};

	public var mcs:Array<Mc>;
	public var anims:Array<FXFeather>;

	var scene:ASprite;
	var ended:Bool;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: UInt16Array.fromArray([
				KeyboardManager.LEFT,
				KeyboardManager.RIGHT,
				KeyboardManager.UP,
				KeyboardManager.DOWN,
				KeyboardManager.SPACE
			]),
			recordInputs: true,
			recordEvents: false,
		});
		me = this;
		mcs = [];
		anims = [];
		ended = false;
		Clip.flushRemoved();

		scene = root.createEmptyMovieClip("scene", 0);
		scene._xscale = scene._yscale = 100 * K;
		scene.updateState();
		this.root = scene.createEmptyMovieClip("world", 0);

		nb = 0;
		level = 0;
		avg_tmod = 0;
		game_over = false;

		bonusProbas = Const.BONUS_PROBAS_TBL.copy();
		if (Seed.random(1000) == 0)
			bonusProbas[2] = 3;

		stats = {
			t: 0,
			l: 0,
			n: 0,
			b: [0, 0, 0],
			m: [0, 0, 0],
			k: 0,
			ks: 0,
			wj: 0,
			bs: 0,
			ba: 0,
			bas: 0,
			lk: 0,
			fksc: -1,
			fs: 0,
		};
		dmanager = new Plans(this.root);
		dmanager.add(new Clip("bg"), 0);
		hero = new Hero(this);
		jamas = [];
		entities = [];
		bonuses = [];
		entities.push(hero.mc);
	}

	// Tools.randomProbas: an index drawn with the weights of the table
	public static function randomProbas(a:Array<Int>):Int {
		var sum = 0;
		for (x in a)
			sum += x;
		var n = Seed.random(sum);
		var i = 0;
		while (i < a.length - 1 && n >= a[i]) {
			n -= a[i];
			i++;
		}
		return i;
	}

	function genPlace(r:Int, bx:Null<Float>):{x:Float, y:Float} {
		var x:Float = bx != null ? bx : 0;
		var y:Float = 0;
		var ntrys = 50;
		var l = entities.length;
		var r2 = r * r;
		while (ntrys-- > 0) {
			if (bx == null)
				x = Seed.random(300 - r * 2) + r;
			y = Seed.random(Const.MAXY - r * 2) + r;
			var i = 0;
			while (i < l) {
				var b = entities[i];
				// (the removed clip of the hero has no position any more: NaN in Flash, never too close)
				if (b != hero.mc || !hero.dead) {
					var dx = b._x - x;
					var dy = b._y - y;
					if (dx * dx + dy * dy < r2)
						break;
				}
				i++;
			}
			if (i == l)
				return {x: x, y: y};
		}
		return null;
	}

	public function kill() {
		if (game_over)
			return;
		game_over = true;
		// the streaks of a jump ended by the death count too
		hero.saveStreaks();
		hero.dead = true;
		hero.mc.removeMovieClip();
		var d = dmanager.add(new Clip("death"), Const.PLAN_HERO);
		d._x = hero.x;
		d._y = hero.y - 15;
		d.updateState();

		death = dmanager.add(new Clip("fall"), Const.PLAN_HERO);
		death_y = -5;
		death._x = hero.x;
		death._y = hero.y;
		death.updateState();
		hero.jump_dx = (hero.x < 150) ? 1 : -1;
	}

	function genBonus() {
		var p = genPlace(5 + Std.int(Math.sqrt(Const.BONUS_RAY2)), null);
		if (p == null)
			return;
		var t = randomProbas(bonusProbas);
		var b = new Bonus(this, p, t);
		bonuses.push(b);
	}

	public function getBonus(b:Bonus) {
		KadoKadeoManager.kkm.addScore(Const.BONUS_POINTS[b.t]);
		nb++;
		stats.n++;
		stats.b[b.t]++;
		if (nb % Const.LEVEL_DELTA == 0)
			level++;
	}

	function genJama() {
		var w = (Seed.random(2) == 0);
		var p = genPlace(40, w ? 320 : -20);
		if (p == null)
			return;
		var t = randomProbas(Const.JAMA_PROBAS_TBL.slice(0, level + 1));
		var j = new Jama(this, p, t);
		stats.m[t]++;
		jamas.push(j);
	}

	// one frame of the Flash player: the timelines, then Manager.main (5 steps of the game)
	public function update(delta:Float) {
		Clip.flushRemoved();
		advanceClips();

		var tmod = Timer.tmod;
		var deltaT = Timer.deltaT;
		Timer.deltaT = deltaT / NSTEPS;
		Timer.tmod = tmod / NSTEPS;
		for (i in 0...NSTEPS)
			main();
		Timer.tmod = tmod;
		Timer.deltaT = deltaT;
	}

	function main() {
		avg_tmod = avg_tmod * 0.99 + Timer.calc_tmod * 0.01;

		if (game_over) {
			death._x += hero.jump_dx * Timer.tmod;
			death._y += death_y * Timer.tmod;
			death_y += Timer.tmod;
			if (death._y > 330 && !ended) {
				stats.l = level;
				stats.t = Std.int(avg_tmod * 100);
				KadoKadeoManager.kkm.gameOver(stats);
				// (the original sets game_over = false: the animals and the symbols go on behind the end screen,
				// the removed hero does nothing)
				ended = true;
			}
		} else
			hero.main();

		if (bonuses.length < 3 && Seed.random(Std.int(Const.BONUS_PROBAS * bonuses.length / Timer.tmod)) == 0)
			genBonus();

		var l = level;
		if (l >= Const.JAMA_PROBAS.length)
			l = Const.JAMA_PROBAS.length - 1;
		if (jamas.length < 10 && Seed.random(Std.int(Const.JAMA_PROBAS[l] * jamas.length / Timer.tmod)) == 0)
			genJama();

		var i = 0;
		while (i < bonuses.length) {
			if (!bonuses[i].update())
				bonuses.splice(i--, 1);
			i++;
		}

		var i = 0;
		while (i < jamas.length) {
			if (!jamas[i].update())
				jamas.splice(i--, 1);
			i++;
		}

		if (!hero.dead)
			hero.mc._xscale = hero.way * 100;
	}

	public function pollTouchControls():Void {
		var joystick = KadoKadeoManager.kkm.getTouchJoystickState();
		if (joystick == null)
			return;
		var axisX = joystick.active ? joystick.dirX : 0;
		var axisY = joystick.active ? joystick.dirY : 0;
		setKey(KeyboardManager.LEFT, axisX < 0);
		setKey(KeyboardManager.RIGHT, axisX > 0);
		setKey(KeyboardManager.UP, axisY < 0);
		setKey(KeyboardManager.DOWN, axisY > 0);
	}

	inline function setKey(keyCode:Int, down:Bool):Void {
		if (down)
			KeyboardManager.setKeyDown(keyCode);
		else
			KeyboardManager.setKeyUp(keyCode);
	}

	function advanceClips() {
		var i = 0;
		var n = mcs.length;
		while (i < n) {
			var m = mcs[i];
			if (m.dead || m.parent == null) {
				mcs[i] = mcs[n - 1];
				mcs.pop();
				n--;
				continue;
			}
			m.advance();
			i++;
		}
		var i = 0;
		while (i < anims.length) {
			if (!anims[i].advance()) {
				anims.splice(i, 1);
				continue;
			}
			i++;
		}
	}

	public function destroy():Void {
		Clip.flushRemoved();
		mcs = [];
		anims = [];
	}
}

// ---------------------------------------------------------------- Const
class Const {
	public static inline var PLAN_BONUS = 3;
	public static inline var PLAN_HERO = 4;
	public static inline var PLAN_JAMA = 5;

	public static inline var MINX = 15;
	public static inline var MAXX = 285;
	public static inline var MAXY = 280;

	public static inline var HERO_Y_DELTA = -20;

	public static inline var BONUS_PROBAS = 100;
	public static var BONUS_PROBAS_TBL = [50, 10, 1];
	public static var JAMA_PROBAS_TBL = [100, 40, 10];
	public static var BONUS_POINTS = [200, 500, 3000];

	public static inline var BONUS_RAY2 = 600;

	public static inline var LEVEL_DELTA = 15;
	public static var JAMA_PROBAS = [50, 35, 20, 10, 5, 4, 4, 3, 3, 2, 1];
}

// ---------------------------------------------------------------- Hero
class Hero {
	static inline var S_WAIT = 0;
	static inline var S_MOVE = 1;
	static inline var S_JUMP = 2;

	var game:Game;
	var arrow:Clip;

	public var mc:Clip;
	public var x:Float;
	public var y:Float;
	public var frame:Float;
	public var way:Int;

	var state:Int;

	public var jump_pow:Float;
	public var jump_time:Bool;
	public var jump_dx:Float;

	// hero.mc._name == null of the original (its clip removed)
	public var dead:Bool;

	// streaks of the current jump, for the stats
	public var killStreak:Int;
	public var bonusStreak:Int;

	var flySteps:Int;

	public function new(g:Game) {
		game = g;
		x = 150;
		state = S_WAIT;
		y = Const.MAXY;
		way = 1;
		jump_dx = 0;
		jump_pow = 0;
		frame = 0;
		dead = false;
		jump_time = false;
		killStreak = 0;
		bonusStreak = 0;
		flySteps = 0;
		arrow = game.dmanager.add(new Clip("arrow"), 5);
		mc = game.dmanager.add(new Clip("hero"), Const.PLAN_HERO);
		mc.stop();
		mc._x = x;
		mc._y = y;
		mc.updateState();
	}

	static inline function isDown(k:Int):Bool {
		return KeyboardManager.isDown(k);
	}

	public inline function isJumping():Bool {
		return state == S_JUMP;
	}

	public function main() {
		var speed = 5;
		var jspeed = 0.7;
		var maxpow = 25;

		jump_dx *= Math.pow(0.9, Timer.tmod);

		switch (state) {
			case S_WAIT | S_MOVE:
				if (isDown(KeyboardManager.LEFT)) {
					if (state == S_WAIT)
						frame = 29;
					state = S_MOVE;
					way = -1;
					x -= Timer.tmod * speed;
				} else if (isDown(KeyboardManager.RIGHT)) {
					if (state == S_WAIT)
						frame = 29;
					state = S_MOVE;
					way = 1;
					x += Timer.tmod * speed;
				} else {
					if (state == S_MOVE)
						frame = 40;
					state = S_WAIT;
				}

				if (isDown(KeyboardManager.UP) || isDown(KeyboardManager.SPACE)) {
					jump_time = true;
					jump_pow = 4;
					jump_dx = (state == S_MOVE) ? (way * speed) : 0;
					state = S_JUMP;
					frame = 58;

					var p = game.dmanager.add(new Clip("smoke"), Const.PLAN_HERO);
					p._x = x;
					p._y = y;
					p.updateState();
				}
			case S_JUMP:
				flySteps++;
				if (isDown(KeyboardManager.LEFT)) {
					way = -1;
					jump_dx -= Timer.tmod;
				} else if (isDown(KeyboardManager.RIGHT)) {
					way = 1;
					jump_dx += Timer.tmod;
				}

				if (isDown(KeyboardManager.UP) || isDown(KeyboardManager.SPACE)) {
					if (jump_time && jump_pow < maxpow) {
						jump_pow *= Cs.pow(1.4, Timer.tmod);
						if (jump_pow >= maxpow) {
							jump_pow = maxpow;
							jump_time = false;
						}
					}
				} else
					jump_time = false;

				x += jump_dx * Timer.tmod / 1.5;
				if (!jump_time)
					jump_pow -= 1.2 * Timer.tmod;
		}

		y -= Timer.tmod * jspeed * jump_pow;

		if (y > Const.MAXY) {
			jump_pow = 0;
			state = S_WAIT;
			frame = 94;
			y = Const.MAXY;
			saveStreaks();
		}

		if (x < Const.MINX) {
			x = Const.MINX;
			jump_dx *= -2;
			if (state == S_JUMP)
				game.stats.wj++;
		}

		if (x > Const.MAXX) {
			x = Const.MAXX;
			jump_dx *= -2;
			if (state == S_JUMP)
				game.stats.wj++;
		}

		mc._x = x;
		mc._y = y;
		mc._xscale = 100;

		switch (state) {
			case S_WAIT:
				frame += Timer.tmod;
				if (frame >= 94) {
					if (frame >= 106)
						frame = 1;
				} else if (frame >= 40) {
					if (frame >= 46)
						frame = isDown(KeyboardManager.DOWN) ? 59 : 1;
				} else if (isDown(KeyboardManager.DOWN))
					frame = 59;
				else if (frame >= 25)
					frame -= 24;
			case S_MOVE:
				frame += Timer.tmod;
				while (frame >= 36)
					frame -= 3;
			case S_JUMP:
				frame += Timer.tmod;
				if (frame >= 73 && jump_pow > 0)
					frame = 70;
				if (frame >= 93)
					frame = 80;
		}

		mc.gotoAndStop(Std.int(frame));
		arrow._visible = (y < 0);
		arrow._x = x;
	}

	// on landing (and on death): the streaks of the jump are over
	public function saveStreaks() {
		var stats = game.stats;
		if (killStreak > stats.ks)
			stats.ks = killStreak;
		killStreak = 0;

		if (bonusStreak > stats.bs)
			stats.bs = bonusStreak;
		bonusStreak = 0;

		// main is played NSTEPS times per frame
		var flyFrames = Std.int(flySteps / Game.NSTEPS);
		if (flyFrames > stats.fs)
			stats.fs = flyFrames;
		flySteps = 0;
	}
}

// ---------------------------------------------------------------- Jama
class Jama {
	static inline var CIGOGNE = 0;
	static inline var BEE = 1;
	static inline var SANGLIER = 2;

	var game:Game;
	var col:ASprite;
	var tmp:Clip;
	var mc:Clip;
	var x:Float;
	var y:Float;
	var t:Int;
	var way:Bool;
	var speed:Float;
	var time:Float;
	var sx:Float;
	var sy:Float;
	var hitUnder:Bool;
	var slightlyAvoided:Bool;

	public function new(g:Game, p:{x:Float, y:Float}, t:Int) {
		game = g;
		this.t = t;
		mc = game.dmanager.add(new Clip("jama"), Const.PLAN_JAMA);
		mc.gotoAndStop(t + 1);
		x = p.x;
		y = p.y;
		time = 0;
		sx = x;
		sy = y;
		way = (x > 0);
		hitUnder = false;
		slightlyAvoided = false;
		init();
		mc._x = x;
		mc._y = y;
		mc.updateState();
		game.entities.push(mc);
	}

	function init() {
		switch (t) {
			case CIGOGNE:
				var sub = mc.getClip("sub");
				col = sub != null ? sub.get("col") : null;
				if (sub != null)
					sub.hideLayer("col");
				if (way) {
					mc._xscale = -100;
					x += 20;
				} else
					x -= 20;
				speed = 1 + 0.3 * game.level;
			case BEE:
				sx = (50 + Math.min(game.level, 5) * 10);
				if (sy + sx > Const.MAXX)
					sy = Const.MAXX - sx;
				if (sy - sx < 0)
					sy = sx;
				speed = 0.4 + 0.2 * game.level;
				if (way)
					mc._xscale = -100;
			case SANGLIER:
				y = Const.MAXY;
				sx = 0;
				speed = 8;
				// (mc.sub.stop(): the boar is not named sub in the SWF, it keeps running)
				time = -2.7 + game.level * 0.15;

				tmp = game.dmanager.add(new Clip("prev"), 6);
				tmp._x = x + (way ? -20 : 20);
				tmp._y = y - 10;

				if (way)
					mc._xscale = -100;
				else
					tmp._xscale = -100;
				tmp.updateState();
		}
	}

	// frame of the animal (the clip in the jama clip) to read its bounds
	function animalFrame():Int {
		for (c in mc.children)
			if (Std.isOfType(c, Clip))
				return (cast c : Clip).frame;
		return 1;
	}

	// (col or mc).getBounds(hero.mc) of the original, from the vector bounds of the SWF
	function hit(hray:Float):Bool {
		if (game.hero.dead)
			return false;

		mc._x = x;
		mc._y = y;

		var key = switch (t) {
			case CIGOGNE: "stork";
			case BEE: "bee";
			default: "boar";
		};
		var r = Art.BOUNDS.get(key + animalFrame());
		if (r == null)
			return false;
		var flip = mc._xscale < 0;
		var hx = game.hero.mc._x;
		var hy = game.hero.mc._y;
		var b = {
			xMin: (flip ? -r[2] : r[0]) + x - hx,
			xMax: (flip ? -r[0] : r[2]) + x - hx,
			yMin: r[1] + y - hy,
			yMax: r[3] + y - hy
		};

		b.yMin += 20;
		b.yMax += 20;

		if (b.xMin * b.xMax > 0) {
			if (b.xMin < 0) {
				if (b.xMax < hray)
					return false;
			} else if (b.xMin > hray)
				return false;
		}

		if (b.yMin * b.yMax > 0) {
			if (b.yMin < 0) {
				if (b.yMax < hray)
					return false;
			} else if (b.yMin > hray)
				return false;
		}

		hitUnder = ((b.yMin + b.yMax) / 2 > 5);
		return true;
	}

	function isLastStork():Bool {
		for (j in game.jamas)
			if (j != this && j.t == CIGOGNE)
				return false;
		return true;
	}

	function remove():Bool {
		game.entities.remove(mc);
		mc.removeMovieClip();
		return false;
	}

	public function update():Bool {
		var ret = true;
		time += Timer.deltaT;
		switch (t) {
			case CIGOGNE:
				x += speed * Timer.tmod * (way ? -1 : 1);
				if (hit(10)) {
					if (hitUnder) {
						var hero = game.hero;
						var p = Math.abs(hero.jump_pow);
						p *= 0.7;
						p = Math.max(p, 5);
						hero.jump_pow = p;
						hero.jump_time = true;
						hero.frame = 59;
						hero.killStreak++;
						hero.bonusStreak = 0;
						game.stats.k++;
						if (game.stats.fksc < 0)
							game.stats.fksc = KadoKadeoManager.kkm.score;
						// (the stork is still in game.jamas: removed from it when update returns false)
						if (isLastStork())
							game.stats.lk++;

						var d = new FXFeather();
						game.dmanager.add(d, Const.PLAN_JAMA + 1);
						d._x = x;
						d._y = y;
						d.updateState();
						game.anims.push(d);

						var s = game.dmanager.add(new Clip("smoke"), Const.PLAN_HERO);
						s._x = x;
						s._y = y;
						s.updateState();

						ret = remove();
					} else {
						game.kill();
					}
				}
				if (x > 340 || x < -40)
					ret = remove();
			case BEE:
				x += speed * Timer.tmod * (way ? -1 : 1);
				y = Cs.sin(time) * sx + sy;
				if (hit(5))
					game.kill();
				if (x > 320 || x < -20)
					ret = remove();
			case SANGLIER:
				if (time < 0)
					return ret;
				if (tmp != null) {
					tmp.removeMovieClip();
					tmp = null;
				}
				sx += Timer.tmod;
				x += speed * Timer.tmod * (way ? -1 : 1);
				if (hit(10))
					game.kill();
				if (!game.hero.dead && Math.abs(x - game.hero.x) < 5 && Math.abs(y - game.hero.y) < 30)
					slightlyAvoided = true;
				if (x > 340 || x < -40) {
					ret = remove();
					if (!game.game_over) {
						game.stats.ba++;
						if (slightlyAvoided)
							game.stats.bas++;
					}
				}
		}
		mc._x = x;
		mc._y = y;
		return ret;
	}
}

// ---------------------------------------------------------------- Bonus
class Bonus {
	var game:Game;
	var mc:ASprite;

	public var t:Int;

	var s:Float;

	public function new(g:Game, p:{x:Float, y:Float}, t:Int) {
		s = 5;
		game = g;
		this.t = t;
		// "bonus" frame t+1: the turning symbol of its colour and the shape on top
		mc = game.dmanager.empty(Const.PLAN_BONUS);
		mc.addChild(new Clip("bonusSym" + (t + 1)));
		var top = new Mc("bonusTop", false);
		top.updateState();
		mc.addChild(top);
		mc._x = p.x;
		mc._y = p.y;
		mc._xscale = s;
		mc._yscale = s;
		mc.updateState();
		game.entities.push(mc);
	}

	public function update():Bool {
		if (s < 100) {
			s += Timer.tmod * 10;
			if (s >= 100)
				s = 100;
			mc._xscale = s;
			mc._yscale = s;
		}

		// (the removed clip of the hero has no position: NaN, never caught)
		if (game.hero.dead)
			return true;
		var dx = game.hero.mc._x - mc._x;
		var dy = (game.hero.mc._y - 20) - mc._y;
		if (dx * dx + dy * dy < Const.BONUS_RAY2) {
			var p = game.dmanager.add(new Clip("FXVanish"), Const.PLAN_HERO + 1);
			p._x = mc._x;
			p._y = mc._y;
			p.updateState();
			game.entities.remove(mc);
			mc.removeMovieClip();
			if (game.hero.isJumping())
				game.hero.bonusStreak++;
			game.getBonus(this);
			return false;
		}

		return true;
	}
}

// ---------------------------------------------------------------- FXFeather
// the script of FXFeather: 10 feathers of random size and frame, placed by their bounds, falling and fading
class FXFeather extends ASprite {
	var list:Array<{mc:Clip, t:Int}>;
	var timer:Int;

	public function new() {
		super();
		list = [];
		for (i in 0...10) {
			var mc = new Clip("feather");
			addChild(mc);
			mc.gotoAndPlay(1 + Seed.randomVfx(Art.N_FEATHER));
			var sc = 50 + Seed.randomVfx(100);
			mc._xscale = mc._yscale = sc;
			var b = Art.BOUNDS.get("feather" + mc.frame);
			mc._x = -b[0] * sc / 100;
			mc._y = -b[1] * sc / 100;
			mc.updateState();
			list.push({mc: mc, t: 10 + Seed.randomVfx(40)});
		}
		timer = 50;
	}

	// frame 2 of FXFeather (frame 3: gotoAndPlay(2))
	public function advance():Bool {
		if (parent == null)
			return false;
		var i = 0;
		while (i < list.length) {
			var f = list[i];
			var mc = f.mc;
			f.t--;
			if (f.t < 10)
				mc._alpha = 10 * f.t;
			var c = (mc.frame * 2 - Art.N_FEATHER) / Art.N_FEATHER;
			mc._y += 0.5 + Math.abs(c) * 1;
			if (f.t == 0) {
				mc.removeMovieClip();
				list.splice(i, 1);
				continue;
			}
			i++;
		}
		if (timer-- < 0) {
			removeMovieClip();
			return false;
		}
		return true;
	}
}
