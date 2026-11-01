package f1champion;

import common_haxe_avm1.kac.ProtectedInt;
import mt.bumdum.Sprite;
import mt.bumdum.Phys;
import pixi.core.graphics.Graphics;
import pixi.core.text.Text;
import kado.TouchControlsConfig.TouchControlsMode;
import kado.TouchControlsConfig.TouchButtonShape;

class F1Sprite extends ASprite {
	public var dr:ASprite;
	public var dl:ASprite;
	public var ur:ASprite;
	public var ul:ASprite;
}

@:expose('GameF1Champion')
class Game implements kado.GameInterface {
	// mobile: steer left / right, the up arrow accelerates
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
				id: "up",
				label: "▲",
				rightPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.UP,
				shape: TouchButtonShape.SQUARE,
			},
		],
	};

	static var BONUS = KKApi.aconst([200, 500, 1000]);

	public var mc:ASprite;
	public var dmanager:DepthManager;

	var level:Level;
	var f1:F1Sprite;
	var shadow:ASprite;
	var life_container:ASprite;
	var life:ASprite;
	var life_mask:Graphics;
	var speed:Text;
	var trail_mc:ASprite;
	var expl_mc:ASprite;
	var options:Array<{id:Int, mc:ASprite}>;
	var trails:Array<Array<{x:Float, y:Float, c:Int}>>;
	var parts:Array<{
		mc:ASprite,
		sx:Float,
		sy:Float,
		sr:Float,
		ay:Float,
		ss:Float
	}>;

	public var chkdata:{
		n:Int,
		b:Array<Int>,
		o:Int, // out (times vehicle went out of bounds)
		m:Int, // max kilometers without going out of bounds
		so:Int, // speed over 230 km/h (frames)
		l:Array<Int>, // life percentage after returning in bounds or collecting life
	};

	var pos:Float;
	var delta:Float;
	var lifepts:Float;
	var lock:Bool;
	var score:Float;
	var oil_time:Float;
	var speed_over_230_kmh:Int = 0;
	var is_inbounds:Bool = true;

	public var km_without_out_of_bounds:ProtectedInt;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		var replayKeys = new UInt16Array(8);
		replayKeys[0] = KeyboardManager.ARROW_RIGHT;
		replayKeys[1] = KeyboardManager.ARROW_LEFT;
		replayKeys[2] = KeyboardManager.ARROW_UP;
		replayKeys[3] = KeyboardManager.D;
		replayKeys[4] = KeyboardManager.Q;
		replayKeys[5] = KeyboardManager.Z;
		replayKeys[6] = KeyboardManager.A;
		replayKeys[7] = KeyboardManager.W;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: replayKeys,
			recordInputs: true,
			recordEvents: false,
		});

		this.mc = root;
		km_without_out_of_bounds = new ProtectedInt(0);
		dmanager = new DepthManager(root);
		shadow = dmanager.attach("shadow", Cs.PLAN_F1);
		shadow._xscale = Cs.CAR_SCALE;
		shadow._yscale = Cs.CAR_SCALE;
		shadow._alpha = 10;
		f1 = cast dmanager.empty(Cs.PLAN_F1);
		f1.attachMovie("f1", "f1", 1);
		f1._xscale = Cs.CAR_SCALE;
		f1._yscale = Cs.CAR_SCALE;
		f1.dr = cast f1.attachMovie("wheel", 0);
		f1.dr.loop = true;
		f1.dr.play();
		f1.dr._xscale = -100;
		f1.dr._x = KadoKadeoManager.I(7);
		f1.dr._y = KadoKadeoManager.I(6);
		f1.dl = cast f1.attachMovie("wheel", 0);
		f1.dl.loop = true;
		f1.dl.play();
		f1.dl._x = KadoKadeoManager.I(-7);
		f1.dl._y = KadoKadeoManager.I(6);
		f1.ur = cast f1.attachMovie("wheel", 0);
		f1.ur.loop = true;
		f1.ur.play();
		f1.ur._xscale = -100;
		f1.ur._x = KadoKadeoManager.I(6);
		f1.ur._y = KadoKadeoManager.I(-9);
		f1.ul = cast f1.attachMovie("wheel", 0);
		f1.ul.loop = true;
		f1.ul.play();
		f1.ul._x = KadoKadeoManager.I(-6);
		f1.ul._y = KadoKadeoManager.I(-9);
		trail_mc = dmanager.empty(Cs.PLAN_TRAIL);
		life_container = dmanager.attach("life_empty", Cs.PLAN_INTERFACE);
		life = life_container.attachMovie("life_full", 2);
		var mask = life.createEmptyMovieClip("life_mask", 3);
		life_mask = mask.getGraphics();
		life.mask = life_mask;
		life_container._x = Cs.WIDTH - KadoKadeoManager.I(128);
		life_container._y = Cs.HEIGHT - KadoKadeoManager.I(31);
		lifepts = Cs.MAXLIFE;
		oil_time = 0;
		var speedSprite = dmanager.empty(Cs.PLAN_INTERFACE);
		speed = speedSprite.initTextField("field", {
			font: "LCD",
			size: 30,
			color: 0xFFFFFF,
			align: "right",
		});
		speed.x = Cs.WIDTH - KadoKadeoManager.I(10);
		speed.y = Cs.HEIGHT - KadoKadeoManager.I(40);
		pos = KadoKadeoManager.I(150);
		delta = 0;
		score = 0;
		trails = [[], [], [], []];
		chkdata = {
			n: 0,
			b: [0, 0, 0, 0, 0],
			o: 0,
			m: 0,
			so: 0,
			l: [],
		};
		parts = new Array();
		options = new Array();
		level = new Level(this);
		updateInterf();
	}

	function updateInterf() {
		life_mask.clear()
			.beginFill(0xFFFFFF)
			.drawRect(0, 0, life._width * lifepts / Cs.MAXLIFE, life._height)
			.endFill();
		var speedValue = Std.int(Math.pow(level.cur_speed / KadoKadeoManager.I(1), 0.75) * 30);
		speed.text = speedValue + " KM/H";
		if (speedValue >= 230 && is_inbounds) {
			speed_over_230_kmh += 1;
		} else {
			if (speed_over_230_kmh > chkdata.so) {
				chkdata.so = speed_over_230_kmh;
			}
			speed_over_230_kmh = 0;
		}
	}

	function slowDown() {
		if (level.cur_speed > level.speed / 2)
			level.cur_speed *= Math.pow(0.98, Timer.tmod);
	}

	function updateF1() {
		var max = Cs.STEER_DELTA_MAX;
		var logicSpeed = level.speed / KadoKadeoManager.I(1);
		var logicCurSpeed = level.cur_speed / KadoKadeoManager.I(1);
		var time = Timer.tmod * logicSpeed / 5;
		var dd = (oil_time > 0) ? Cs.STEER_INPUT_OIL : Cs.STEER_INPUT_DRY;

		if (!lock) {
			if (KeyboardManager.isDown(KeyboardManager.LEFT)
				|| KeyboardManager.isDown(KeyboardManager.Q)
				|| KeyboardManager.isDown(KeyboardManager.A)) {
				delta -= dd * time;
				if (delta < -max)
					delta = -max;
				else
					slowDown();
			} else if (KeyboardManager.isDown(KeyboardManager.RIGHT) || KeyboardManager.isDown(KeyboardManager.D)) {
				delta += dd * time;
				if (delta > max)
					delta = max;
				else
					slowDown();
			} else if (KeyboardManager.isDown(KeyboardManager.UP)
				|| KeyboardManager.isDown(KeyboardManager.Z)
				|| KeyboardManager.isDown(KeyboardManager.W))
				level.cur_speed += KadoKadeoManager.I(1);
		}
		delta += 0.05 * time * (Cs.MAXLIFE - lifepts) / Cs.MAXLIFE * ((Seed.random(2) == 0) ? -1 : 1);
		delta *= Math.pow((oil_time <= 0) ? Cs.STEER_FRICTION_DRY : Cs.STEER_FRICTION_OIL, time);
		if (delta > max)
			delta = max;
		else if (delta < -max)
			delta = -max;
		pos += delta * time * KadoKadeoManager.I(1);
		if (pos < KadoKadeoManager.I(5))
			pos = KadoKadeoManager.I(5);
		else if (pos > KadoKadeoManager.I(295))
			pos = KadoKadeoManager.I(295);
		f1._rotation = delta * 15;
		f1._x = pos;
		f1._y = KadoKadeoManager.S(250 + (logicSpeed - logicCurSpeed) * 2);
		shadow._x = f1._x + Cs.SHADOW_X;
		shadow._y = f1._y + Cs.SHADOW_Y;
		shadow._rotation = f1._rotation;
	}

	inline function wheelWorldPos(wheel:ASprite):{x:Float, y:Float} {
		var r = f1._rotation * Math.PI / 180;
		var cr = Math.cos(r);
		var sr = Math.sin(r);
		var sx = f1._xscale / 100;
		var sy = f1._yscale / 100;
		var lx = wheel._x * sx;
		var ly = wheel._y * sy;
		return {
			x: f1._x + lx * cr - ly * sr,
			y: f1._y + lx * sr + ly * cr
		};
	}

	function updateTrails(dp:Float) {
		var c = (oil_time > 0) ? 30 : ((Math.abs(f1._rotation) > 30) ? 10 : 0);
		if (f1._name != null) {
			var p1 = wheelWorldPos(f1.dr);
			var p2 = wheelWorldPos(f1.dl);
			var p3 = wheelWorldPos(f1.ur);
			var p4 = wheelWorldPos(f1.ul);
			trails[0].unshift({
				x: p1.x,
				y: p1.y,
				c: c
			});
			trails[1].unshift({
				x: p2.x,
				y: p2.y,
				c: c
			});
			trails[2].unshift({
				x: p3.x,
				y: p3.y,
				c: c
			});
			trails[3].unshift({
				x: p4.x,
				y: p4.y,
				c: c
			});
		}
		trail_mc.clear();
		c = null;
		for (tr in trails) {
			var p = tr[0];
			trail_mc.moveTo(p.x, p.y);
			var i = 1;
			while (i < tr.length) {
				p = tr[i];
				p.y += dp;
				if (c != p.c) {
					c = p.c;
					trail_mc.lineStyle(KadoKadeoManager.I(3), 4, p.c);
				}
				trail_mc.lineTo(p.x, p.y);
				if (p.y > KadoKadeoManager.I(300))
					break;
				i++;
			}
			tr.splice(i, tr.length - i);
		}
	}

	function getOption(id:Int) {
		chkdata.b[id]++;
		switch (id) {
			case 0:
				lifepts += 20;
				if (lifepts > Cs.MAXLIFE)
					lifepts = Cs.MAXLIFE;
				chkdata.l.push(Std.int(lifepts * 100 / Cs.MAXLIFE));
			case 1 | 2 | 3:
				var mc = new Phys(dmanager.empty(Cs.PLAN_INTERFACE));
				mc.root._x = f1._x;
				mc.root._y = f1._y;
				mc.timer = 32;
				var txt = mc.root.initTextField("field", {
					font: "Junegull-Regular",
					size: 25,
					color: 0xFFFFFF,
					align: "center",
				});
				txt.text = Std.string(KKApi.val(BONUS[id - 1]));
				KadoKadeoManager.kkm.addScore(BONUS[id - 1]);
			case 4:
				oil_time += 2 + Seed.random(200) / 100;
		}
	}

	inline function optionHitsCar(optionMc:ASprite):Bool {
		var radius = KadoKadeoManager.I(12);
		var carScaleX = f1._xscale / 100;
		var carScaleY = f1._yscale / 100;
		var halfW = KadoKadeoManager.I(18) * carScaleX;
		var halfH = KadoKadeoManager.I(26) * carScaleY;

		var dx = optionMc._x - f1._x;
		var dy = optionMc._y - f1._y;

		var a = -f1._rotation * Math.PI / 180;
		var ca = Math.cos(a);
		var sa = Math.sin(a);
		var localX = dx * ca - dy * sa;
		var localY = dx * sa + dy * ca;

		var closestX = Math.max(-halfW, Math.min(localX, halfW));
		var closestY = Math.max(-halfH, Math.min(localY, halfH));
		var distX = localX - closestX;
		var distY = localY - closestY;
		return distX * distX + distY * distY <= radius * radius;
	}

	function updateOptions(dp:Float) {
		var i = 0;
		while (i < options.length) {
			var o = options[i];
			o.mc._y += dp;
			if (optionHitsCar(o.mc)) {
				getOption(o.id);
				o.mc._y = KadoKadeoManager.I(600);
			}
			if (o.mc._y > KadoKadeoManager.I(320)) {
				o.mc.removeMovieClip();
				options.splice(i--, 1);
			}
			i++;
		}
		if (level.pos < Level.DELTA - KadoKadeoManager.I(25)
			&& Seed.random(Std.int(Cs.OPTIONS_PROBA * (options.length / 5 + 1) / Timer.tmod)) == 0) {
			var ntries = 20;
			var y = -KadoKadeoManager.I(10);
			var x;
			do {
				x = KadoKadeoManager.I(30 + Seed.random(240));
				if (!level.middleContains(x - KadoKadeoManager.I(15), y)
					&& !level.middleContains(x + KadoKadeoManager.I(15), y)
					&& !level.middleContains(x, y - KadoKadeoManager.I(15))
					&& !level.middleContains(x, y + KadoKadeoManager.I(15)))
					break;
			} while (--ntries > 0);
			if (ntries == 0)
				return;
			var mc = dmanager.attach("option", Cs.PLAN_OPTION);
			var sum = 0;
			var id;

			for (opt in Cs.OPTIONS)
				sum += opt;

			sum = Seed.random(sum);

			id = 0;
			while (sum >= Cs.OPTIONS[id])
				sum -= Cs.OPTIONS[id++];

			if (id == 0 && lifepts == Cs.MAXLIFE) {
				mc.removeMovieClip();
				return;
			}

			mc._x = x;
			mc._y = y;
			if (id == 4)
				mc.gotoAndStop(Seed.random(3) + 5);
			else
				mc.gotoAndStop(id + 1);
			options.push({id: id, mc: mc});
		}
	}

	function genParticules() {
		var mc = dmanager.attach("part", Cs.PLAN_PART);
		mc._x = f1._x;
		mc._y = f1._y + KadoKadeoManager.I(10);
		mc._xscale = KadoKadeoManager.I(25 + Seed.randomVfx(40));
		mc._yscale = mc._xscale;
		mc._rotation = Seed.randomVfx(360);
		mc.tint = 0x224400;
		mc._alpha = 30;
		mc.gotoAndStop(3);
		parts.push({
			mc: mc,
			sx: KadoKadeoManager.S(Seed.randomVfx(8) - 4),
			sy: -KadoKadeoManager.S(3 + Seed.randomVfx(30) / 10),
			ay: 0.95,
			ss: 0,
			sr: 10
		});
	}

	function genSmoke() {
		var sx = (Seed.randomVfx(8) - 4) / KadoKadeoManager.I(5);
		for (i in 0...3) {
			var mc = dmanager.attach("part", Cs.PLAN_PART);
			mc.gotoAndStop(1);
			mc._x = f1._x + KadoKadeoManager.I(Seed.randomVfx(10) - 5);
			mc._y = f1._y + KadoKadeoManager.I(Seed.randomVfx(10) - 5);
			mc._xscale = 60 + Seed.randomVfx(40);
			mc._yscale = mc._xscale;
			mc._rotation = Seed.randomVfx(360);
			mc._alpha = 30;
			parts.push({
				mc: mc,
				sx: sx,
				sy: KadoKadeoManager.I(-5) * level.speed / Cs.MINSPEED,
				ay: 1,
				ss: 3,
				sr: 30
			});
		}
	}

	function updateParticules(dp:Float) {
		var i = 0;
		while (i < parts.length) {
			var p = parts[i];
			p.sy *= Math.pow(p.ay, Timer.tmod);
			p.mc._xscale += p.ss * Timer.tmod;
			p.mc._yscale += p.ss * Timer.tmod;
			p.mc._x += p.sx * Timer.tmod;
			p.mc._y += p.sy * Timer.tmod + dp;
			p.mc._rotation += p.sr * Timer.tmod;
			if (p.mc._y > KadoKadeoManager.I(310)) {
				p.mc.removeMovieClip();
				parts.splice(i--, 1);
			}
			i++;
		}
	}

	public function update(delta:Float):Void {
		updateF1();
		var dp = level.main();
		updateTrails(dp);
		updateOptions(dp);
		if (oil_time >= 0)
			oil_time -= Timer.deltaT;
		var isOutOfBounds = level.wallContains(f1._x, f1._y);
		if (isOutOfBounds && is_inbounds) {
			is_inbounds = false;
			chkdata.o++;
			chkdata.m = Std.int(Math.max(chkdata.m, km_without_out_of_bounds.get()));
			km_without_out_of_bounds = 0;
		} else if (!isOutOfBounds && !is_inbounds) {
			is_inbounds = true;
			chkdata.l.push(Std.int(lifepts * 100 / Cs.MAXLIFE));
		}
		if (!lock && isOutOfBounds) {
			lifepts -= Timer.tmod * level.cur_speed / 2 / KadoKadeoManager.I(1);
			for (_ in 0...3)
				slowDown();
			genParticules();
			if (lifepts < 0) {
				lifepts = 0;
				lock = true;
				oil_time = 0;
				expl_mc = dmanager.attach("explosion", Cs.PLAN_PART);
				expl_mc.play();
				expl_mc._alpha = 70;
				expl_mc._xscale = Cs.CAR_SCALE;
				expl_mc._yscale = Cs.CAR_SCALE;
				expl_mc._x = f1._x;
				expl_mc._y = f1._y;
				expl_mc.removeOnFrame = 18;
				f1.removeMovieClip();
				shadow.removeMovieClip();
				KadoKadeoManager.kkm.gameOver(chkdata);
			}
		}

		if (!lock && lifepts < Cs.MAXLIFE / 2 && Seed.randomVfx(Std.int(30 * (lifepts / Cs.MAXLIFE) / Timer.tmod)) == 0)
			genSmoke();

		if (expl_mc != null) {
			expl_mc._y += dp / KadoKadeoManager.I(1);
		}
		updateParticules(dp);
		updateInterf();
		if (!lock) {
			score += Timer.tmod * level.cur_speed / KadoKadeoManager.I(1);
			var ratio = 5;
			var s = Std.int(score / ratio);
			score -= s * ratio;
			KadoKadeoManager.kkm.addScore(KKApi.const(s));
		}
		Sprite.updateAll();

		// Debug
		// lifepts = 100;
		// if (KeyboardManager.isDown(KeyboardManager.A)) {
		// 	level.cur_speed = 1;
		// }

		// if (KeyboardManager.isJustDown(KeyboardManager.D)) {
		// 	if (level.walls.mask != null) {
		// 		level.walls.mask = null;
		// 		for (i in 0...5) {
		// 			f1.children[i].visible = false;
		// 		}
		// 		f1.getGraphics().clear().beginFill(0xFF00FF).drawCircle(0, 0, 5).endFill();
		// 		life_container._alpha = 10;
		// 	} else {
		// 		level.walls.mask = level.walls_mask;
		// 		f1.getGraphics().clear();
		// 		for (i in 0...5) {
		// 			f1.children[i].visible = true;
		// 		}
		// 		life_container._alpha = 100;
		// 	}
		// }
	}

	public function destroy():Void {}
}
