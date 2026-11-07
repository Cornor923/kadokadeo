package minirace;

import minirace.Game.Step;

class Car extends Tracker {
	static public var PNEU_COEF = 1;

	public var colors:Array<Int>;

	public var flPlayer:Bool;
	public var flGrass:Bool;

	public var acc:Float;
	public var wd:Float;
	public var paintTimer:Null<Float>;

	public var life:Float;

	public var brakeFrict:Float;
	public var grassFrict:Float;
	public var redFlash:Null<Float>;

	public var box:Array<Array<Float>>;
	public var opp:Array<Array<Float>>;
	public var normals:Array<Array<Float>>;

	public var cps:Int;
	public var pid:Int;

	var clip:Clip;
	var accelSteps:Int;

	public function new(mc:Clip) {
		super(mc);
		clip = mc;
		Cs.game.cars.push(this);

		brakeFrict = 0.93;
		grassFrict = 0.7;

		cps = 0;
		accelSteps = 0;
		flPlayer = false;
		flGrass = false;
	}

	public function setPlayer(id:Int) {
		pid = id;
		flPlayer = pid == 0;
		root.gotoAndStop(pid + 1);
		switch (pid) {
			case 0:
				flControl = true;

				life = Cs.LIFE_MAX;
				groundFrict = 0.96;
				decalMax = 0;

				wd = 1;
				acc = 0.3;
				turnCoef = 0.1;
				turnLimit = 0.5;
				colors = [0xA74403, 0xFF9900];
			case 1:
				wd = 1;
				acc = 0.1;
				turnCoef = 0.06;
				turnLimit = 0.2;
				colors = [0x449210, 0x89DE07];
			case 2:
				wd = 5;
				acc = 0.15;
				turnCoef = 0.1;
				turnLimit = 0.5;
				colors = [0x0939AA, 0x457BF5];
			case 3:
				wd = 20;
				acc = 0.22;
				turnCoef = 0.14;
				turnLimit = 0.65;
				colors = [0xA00162, 0xFF0080];
		}

		goto(pid * 2);
	}

	// UPDATE
	override public function update() {
		flGrass = Cs.game.raceHitTest(x, y);
		if (flGrass) {
			if (paintTimer == null)
				paintTimer = 0;
			paintTimer = Math.min(paintTimer + 3 * Timer.tmod, 24);
		}

		if (flGrass) {
			if (flPlayer) {
				Cs.game.flPerfect = false;
				Cs.game.flOffTrack = true;
			}
			speed *= Math.pow(grassFrict, Timer.tmod);
		}
		updateFlash();

		updateBox();
		control();
		move();
		updateCols();
		updatePneuFx();
	}

	function control() {
		if (flPlayer) {
			if (Cs.game.flPress && Cs.game.step == Play) {
				speed += acc * Timer.tmod;
				if (!flGrass) {
					Cs.game.addScore(Cs.SCORE_ACCEL);
					// the original adds SCORE_ACCEL once per Flash frame, not scaled by tmod: the SWF runs at 40 frames/s
					// (tmod ~0.8), KadoKadeo at 32 steps/s, so every 4th step adds the 5th frame of the original
					accelSteps++;
					if (accelSteps % 4 == 0)
						Cs.game.addScore(Cs.SCORE_ACCEL);
				}
			} else {
				speed *= Math.pow(brakeFrict, Timer.tmod);
			}
		} else {
			var c = 1 - Math.min(Math.abs(da), 1);
			speed += acc * c * Timer.tmod;
		}
		speed = Math.max(1, speed);
	}

	//
	override function nextWayPoint() {
		super.nextWayPoint();
		cps++;
		if (cpi == 1 && pid == 0)
			Cs.game.incLap();
	}

	override public function goto(n:Int) {
		super.goto(n);
		cps = n;
	}

	//
	function updateFlash() {
		if (redFlash != null) {
			var prc = redFlash;
			redFlash *= 0.8;
			if (redFlash < 1) {
				redFlash = null;
				prc = 0;
			}
			Cs.setPercentColorClip(clip, prc, 0xFF0000);
		}
	}

	// COLLISIONS
	function updateCols() {
		for (car in Cs.game.cars) {
			if (car != this) {
				// OVERTAKING
				if (pid == 0) {
					if (cps >= car.cps) {
						var dist0 = getDist(wp);
						var dist1 = car.getDist(wp);

						if (dist0 < dist1)
							car.pass(this);
					}
				}
			}
		}
	}

	public function checkColPhys(car:Car) {
		// WEIGHT
		var coef = car.wd / (wd + car.wd);
		if (pid == 0 || car.pid == 0)
			coef = 0.5;

		// COLLISION
		var rec = checkCol(car, 1);
		if (rec == null)
			return;

		x -= rec[0] * coef;
		y -= rec[1] * coef;
		car.x += rec[0] * (1 - coef);
		car.y += rec[1] * (1 - coef);

		var a = getAng(car);
		var da = Cs.hMod(angle - a, 3.14);
		var c = Math.abs(da) / 3.14;

		var dx = vx - car.vx;
		var dy = vy - car.vy;
		var force = Math.sqrt(dx * dx + dy * dy);

		bang(c, force);
		car.bang(1 - c, force);
	}

	// separating axes of the two boxes: smallest push, null when they do not touch
	function checkCol(car:Car, sc:Float):Array<Float> {
		// INIT
		var bn:Array<Float> = null;
		var ndif = 9999999999.0;
		var sens = 1;

		// BUILD NORMAL LIST
		var nl = [];
		for (n in normals)
			nl.push(n);
		for (n in car.normals)
			nl.push(n);

		// SEEK
		for (n in nl) {
			var p0 = getProj(n, sc);
			var p1 = car.getProj(n, sc);

			var min = Math.max(p0[0], p1[0]);
			var max = Math.min(p0[1], p1[1]);
			if (max > min) {
				var dif = max - min;
				if (dif < ndif) {
					bn = n;
					ndif = dif;
					sens = if (min == p0[0]) -1 else 1;
				}
			} else {
				return null;
			}
		}

		return [bn[0] * ndif * sens, bn[1] * ndif * sens];
	}

	function getProj(n:Array<Float>, sc:Float):Array<Float> {
		var distMin:Float = 9999999;
		var distMax:Float = -9999999;
		for (p in box) {
			var px = x + p[0] * sc;
			var py = y + p[1] * sc;
			var ps = n[0] * px + n[1] * py;
			distMin = Math.min(distMin, ps);
			distMax = Math.max(distMax, ps);
		}
		return [distMin, distMax];
	}

	function updateBox() {
		// (no box before the first update: no tyre trace either)
		opp = [];
		if (box != null)
			for (p in box)
				opp.push([p[0] * PNEU_COEF + x, p[1] * PNEU_COEF + y]);

		//
		var a = rot * 0.0174;
		var ca = Cs.qt(Math.cos(a));
		var sa = Cs.qt(Math.sin(a));
		var rw = 6;
		var rh = 3;
		box = [
			rotate(-rw, -rh, ca, sa),
			rotate(rw, -rh, ca, sa),
			rotate(rw, rh, ca, sa),
			rotate(-rw, rh, ca, sa)
		];
		normals = [[-sa, ca], [-ca, -sa]];
	}

	function rotate(x:Float, y:Float, ca:Float, sa:Float):Array<Float> {
		return [x * ca - y * sa, x * sa + y * ca];
	}

	function pass(c:Car) {
		if (Cs.game.step != Play)
			return;

		Cs.game.stats._pa[pid - 1]++;
		// PANEL
		var sc = Cs.SCORE_OVERTAKE[pid - 1];
		Cs.game.addScore(sc);
		cps += Cs.game.checkpoints.length;
		var p = new Phys(Clip.attach(Cs.game.mdm, "mcScore", Game.DP_INTER));
		// the number of the field, with the glow of colors[0] (Filt.glow(p.root, 2, 4, colors[0]))
		p.root.gotoAndStop(pid);
		p.x = x;
		p.y = y;
		p.vy = -5;
		p.frict = 0.7;
		p.timer = 40;
		p.fadeType = 0;

		// PARTS
		for (i in 0...40) {
			var a = Seed.randVfx() * 6.28;
			var p = new Luciole(Cs.game.mdm.empty(Game.DP_CAR), pid);
			p.setWayPoint(cpi);
			var ray = Seed.randVfx() * 20;
			p.x = x + Math.cos(a) * ray;
			p.y = y + Math.sin(a) * ray;
			p.vx = c.vx * 2;
			p.vy = c.vy * 2;
			p.angle = angle;
			p.flLine = true;
		}
	}

	function bang(c:Float, force:Float) {
		if (c < 0.5)
			speed *= c;

		force *= (1 - c);

		var max = Std.int(force);
		for (n in 0...max) {
			var p = getPart(0.6);
			var a = n / max * 6.28 + Seed.randVfx() * 0.2;
			var ca = Math.cos(a);
			var sa = Math.sin(a);
			var sp = 0.2 + Seed.randVfx() * 2;
			p.x = x + (Seed.randVfx() * 2 - 1) * 3;
			p.y = y + (Seed.randVfx() * 2 - 1) * 3;
			p.vx = ca * sp + vx * (0.1 + Seed.randVfx() * 0.4);
			p.vy = sa * sp + vy * (0.1 + Seed.randVfx() * 0.4);
		}

		if (pid != 0)
			return;

		if (flPlayer)
			Cs.game.flPerfect = false;
		if (force > 1.5) {
			redFlash = 100;
			updateFlash();
			life = Math.max(life - force * 10, 0);
			Cs.game.updateLife(life);
			if (life == 0)
				explode();
		}
	}

	// FX
	public function updatePneuFx() {
		if (paintTimer == null)
			return;

		var dda = Math.abs(da);

		for (i in 0...box.length) {
			if (opp[i] == null)
				continue;
			var wpx = box[i][0] * PNEU_COEF + x;
			var wpy = box[i][1] * PNEU_COEF + y;
			var x = opp[i][0];
			var y = opp[i][1];
			var dx = wpx - x;
			var dy = wpy - y;
			var dist = Math.sqrt(dx * dx + dy * dy);
			var a = Math.atan2(dy, dx);

			var prc = Math.min(paintTimer * 4 + dda * 20, 100);
			Cs.game.paintMark(x, y, dist, a, prc);
		}

		paintTimer -= Timer.tmod;
		if (paintTimer <= 0)
			paintTimer = null;
	}

	//
	function explode() {
		Cs.game.stats._x = 1;
		Cs.game.initGameOver(20);

		//
		var p = new Part(Clip.attach(Cs.game.mdm, "partCarcasse", Game.DP_PARTS));
		p.x = x;
		p.y = y;
		p.vx = vx * 0.2;
		p.vy = vy * 0.2;
		p.root._rotation = rot;
		p.vr = da * 10;
		p.frict = 0.93;
		p.fr = 0.95;
		p.bhl = [0];

		//
		var max = 36;
		var cr = 1;
		for (n in 0...max) {
			var p = getPart();

			var a = n / max * 6.28 + Seed.randVfx() * 0.2;
			var ca = Math.cos(a);
			var sa = Math.sin(a);
			var sp = 0.5 + Seed.randVfx() * 3;
			p.x = x + ca * cr * sp;
			p.y = y + sa * cr * sp;
			p.vx = ca * sp + vx * (0.3 + Seed.randVfx() * 0.3);
			p.vy = sa * sp + vy * (0.3 + Seed.randVfx() * 0.3);
		}

		kill();
	}

	function getPart(?sc:Float):Part {
		if (sc == null)
			sc = 1;
		var p = new Part();
		p.vr = (Seed.randVfx() * 2 - 1) * 24;
		p.root._rotation = Seed.randVfx() * 360;
		p.zw = 0.1 + Seed.randVfx() * 0.1;
		p.frict = 0.95;
		p.timer = 10 + Seed.randVfx() * 70;
		p.setScale((50 + Seed.randVfx() * 100) * sc);
		p.fadeType = 2;
		p.vz = -1 + Seed.randVfx() * 10;
		p.initShade();
		p.setColour(colors[Seed.randomVfx(colors.length)]);
		return p;
	}

	// the car leaves the race and the screen, but stays in the list of the sprites like in the original (Car.kill does
	// not call Sprite.kill): it goes on along the track, invisible, until the end of the game
	override public function kill() {
		Cs.game.cars.remove(this);
		root.removeMovieClip();
	}
}
