package charlottesquest.en;

class Worm extends Enemy {
	public static var MIN_DIFFS = [19, 23, 28];

	var type:Int;
	var ang:Float;
	var angRecal:Float;
	var target:{x:Float, y:Float};
	var leader:Null<Worm>;
	var bodyPos:Float;
	var history:Array<{ang:Float, x:Float, y:Float}>;
	var delay:Int;
	var duration:Int;
	var leaving:Bool;
	var cadency:Int;

	public function new(t:Int) {
		super();

		type = t;
		radius = 10;
		followScroll = true;
		autoKill = null;
		color = 0xDAAE6D;
		pullable = false;
		history = [];
		ang = 3.14;
		angRecal = 0.01;
		autoKillOutsider = true;
		cadency = 0;
		setCD("shoot", rseed.range(150, 300));
		followScroll = false;

		duration = 40 * 20;
		leaving = false;

		var wave = getWave().list;
		var side = getRandomPopSide(MIN_DIFFS[type]);
		var rpos = wrand.range(0.2, 0.8);
		var margin = 100;
		if (type == 2)
			margin += rseed.random(200);
		switch (side) {
			case 0:
				setPosScreen(Game.WID * rpos, -margin);
			case 1:
				setPosScreen(Game.WID + margin, Game.HEI * rpos);
			case 2:
				setPosScreen(Game.WID * rpos, Game.HEI + margin);
			case 3:
				setPosScreen(-margin, Game.HEI * rpos);
		}

		if (wave.length >= 2)
			leader = cast wave[wave.length - 2];

		// (lib.Scuti, drawn by cacheAnims with the filters of the clip: the glow and the colour of the types 1 and 2)
		switch (type) {
			case 0:
				initLife(2);
				cadency = 0;
				spr.scaleX = 1.5;
				spr.scaleY = 0.8;
				delay = 6 * wave.length;
				color = 0xDAAE6D;
			case 1:
				cadency = 40 * 3;
				initLife(5);
				spr.scaleX = 1;
				spr.scaleY = 2;
				delay = 6 * wave.length;
				color = 0xE03A1D;

			case 2:
				color = 0xF50707;
				cadency = 0;
				initLife(5);
				spr.scaleX = 1;
				spr.scaleY = 1;
				delay = 6 * wave.length;
		}
		cacheAnims("worm_" + type, type == 0 || type == 2 ? 0.5 : 0.8);

		if (isHead()) {
			augmentLife(3);
			newTarget();
		}

		updateBodies(getWave());
	}

	override public function toString() {
		return super.toString() + "[Worm]";
	}

	override public function onDie() {
		super.onDie();

		var f = getFollower();
		if (f != null) {
			f.leader = null;
			f.setCD("shoot", rseed.range(100, 200));
			f.newTarget(true);
			f.augmentLife(3);
		}

		Worm.updateBodies(getWave());
		dropReward(if (type == 2) waveKilled() ? 1 : 0 else waveKilled() ? 2 : 1);
	}

	static function updateBodies(wave:{total:Int, list:Array<Enemy>}) {
		var bodies:Array<Array<Worm>> = [];
		for (e in wave.list) {
			var e:Worm = cast e;
			if (e.isHead())
				bodies.push([]);
			bodies[bodies.length - 1].push(e);
		}

		for (b in bodies) {
			var n = 0;
			for (e in b) {
				e.speed = e.wormSpeed(b.length / wave.total);
				if (b.length == 1)
					e.bodyPos = 0;
				else
					e.bodyPos = n / (b.length - 1);

				if (e.bodyPos == 0) {
					e.spr.scaleY = 1;
					e.setAnim("head");
				} else if (e.bodyPos < 1) {
					e.spr.scaleY = 0.5 + Math.sin(e.bodyPos * 3.14) * 0.5;
					e.setAnim("middle");
				} else {
					e.spr.scaleY = 1;
					e.setAnim("back");
				}
				n++;
			}
		}
	}

	public function getFollower() {
		for (e in getWave().list) {
			var e:Worm = cast e;
			if (e.leader == this)
				return e;
		}
		return null;
	}

	override public function hit(v:Float, ?from:Entity) {
		super.hit(v, from);
	}

	inline function isHead() {
		return leader == null;
	}

	public inline function angDist(a:Float, b:Float) {
		var d = b - a;
		if (d > 3.14)
			d -= 6.28;
		if (d < -3.14)
			d += 6.28;
		return d;
	}

	function wormSpeed(bodySize:Float) {
		return if (type == 0) 0.12 + Game.q(Math.pow(1 - bodySize, 2)) * 0.10; else if (type == 1) 0.16 + Game.q(Math.pow(1 - bodySize, 2)) * 0.13; else
			0.12 + Game.q(Math.pow(1 - bodySize, 2)) * 0.10;
	}

	public function newTarget(forceOpposite = false) {
		if (duration > 0) {
			if (target == null)
				target = {
					x: Game.WID * 0.2 + rseed.rand() * Game.WID * 0.6,
					y: Game.HEI * 0.2 + rseed.rand() * Game.HEI * 0.6,
				}
			else {
				var old = target;
				var pt = getScreenPoint();
				do {
					target = {
						x: Game.WID * 0.1 + rseed.rand() * Game.WID * 0.8,
						y: Game.HEI * 0.1 + rseed.rand() * Game.HEI * 0.8,
					}
				} while (Math.abs(target.x - old.x) <= 230 && Math.abs(target.y - old.y) <= 150);
			}
		} else
			target = {
				x: Game.cos(ang) * 1000,
				y: Game.sin(ang) * 1000,
			}
		angRecal = 0.001;
	}

	override public function update() {
		if (--delay > 0) {
			spr.visible = false;
			return;
		}

		if (--duration <= 0 && !leaving) {
			leaving = true;
			autoKill = LeaveScreen;
			newTarget();
		}

		if (leader != null) {
			var maxDist = 30;
			var lpt = leader.getPoint();
			var h = leader.history.shift();
			if (leader.history.length > 0) {
				while (leader.history.length > 0 && Lib.distance(h.x, h.y, lpt.x, lpt.y) > maxDist)
					h = leader.history.shift();
				setPosInScroll(h.x, h.y);
				var pt = getScreenPoint();
				var lpt = leader.getScreenPoint();
				ang = Game.atan2(lpt.y - pt.y, lpt.x - pt.x);
				dx = dy = 0;
			} else {
				dx = Game.cos(ang) * speed;
				dy = Game.sin(ang) * speed;
			}
		} else {
			var pt = getScreenPoint();
			var ta = Game.atan2(target.y - pt.y, target.x - pt.x);
			var da = angDist(ang, ta);
			ang += da * angRecal;
			if (angRecal < 0.4)
				angRecal += 0.001 + speed * 0.01;
			if (Math.abs(target.x - pt.x) < 50 && Math.abs(target.y - pt.y) < 50)
				newTarget();
			dx = Game.cos(ang) * speed;
			dy = Game.sin(ang) * speed;
		}

		spr.rotation = 180 + Lib.deg(ang);

		super.update();

		if (onScreen && isHead() && cadency > 0 && !hasCD("shoot")) {
			setCD("shoot", cadency);
			var b = new charlottesquest.bullet.Bad(this, color);
			b.speed = speed;
			b.toPlayer();
		}

		var pt = getPoint();
		history.push({ang: ang, x: pt.x, y: pt.y});
	}
}
