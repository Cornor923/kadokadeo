package charlottesquest.en;

class Mine extends Enemy {
	public static var MIN_DIFF = 15;

	var dr:Float;

	public function new(r:Room, type:Int) {
		super();

		var size = rnd(0.55, 0.75);

		radius = 35 * size;
		color = 0x9CA0BC;
		hasToBeKilled = false;
		pullable = true;
		pullPower = 0.2;
		alertOutside = false;

		dr = rseed.range(0.5, 2, true);

		// (lib.MineBalls, drawn by cacheAnims with the filters of the clip: a blur, its glows, the colour of the type 1)

		switch (type) {
			case 0:
				initLife(4);
			case 1:
				initLife(2);
			default:
				throw "err" + type;
		}

		cacheAnims("mine" + type, 0.7);

		setAnim("wait");
		// (a random frame of the animation: on the random of the effects)
		setAnimFrame(Seed.randomVfx(animCache.get("wait").n));

		spr.scaleX = spr.scaleY = size;
		spr.rotation = rnd(0, 360);
		if (game.perf >= 0.8) {
			spr.filters = [
				new DropShadowFilter(12, -120, 0x0, 0.2, 2, 2, 1, 1, true),
				new DropShadowFilter(16, 90, 0x0, 0.4, 16, 16, 1),
			];
			cachedAnimMC.blendMode = BlendMode.ADD;
		}

		var spots = r.getEmptySpotsCopy();
		var ok = false;
		while (spots.length > 0 && !ok) {
			var pt = spots.splice(rseed.random(spots.length), 1)[0];
			var x = pt.x;
			var y = pt.y;
			if (!r.hasMark(x, y)) {
				setPos(r.cx * Room.CWID + x, r.cy * Room.CHEI + y);
				r.mark(x, y);
				ok = true;
				break;
			}
		}
		if (!ok)
			destroy();
	}

	override public function toString() {
		return super.toString() + "[Mine]";
	}

	override public function hit(pow:Float, ?from:Entity) {
		pow = 1;
		super.hit(pow, from);
		setCD("shield", 5);
	}

	override public function onDie() {
		super.onDie();
		var n = 10;
		var base = 0;
		for (i in 0...n) {
			var b = new charlottesquest.bullet.Bad(this);
			var a = base + 6.28 * i / n;
			b.speed *= 1.5;
			b.dx = Game.cos(a) * b.speed;
			b.dy = Game.sin(a) * b.speed;
			b.range = 160;
		}
	}

	override public function update() {
		if (life > 1) {
			dx = Game.sin(timeOffset(0.05)) * 0.01;
			dy = Game.sin(timeOffset(0.03)) * 0.02;
		} else {
			dx = Game.sin(timeOffset(0.50)) * 0.04;
			dy = Game.sin(timeOffset(0.42)) * 0.03;
		}
		spr.rotation += dr;
		spr.rotation += pullDx * 50;

		super.update();

		if (life <= 1 && !hasCD("danger"))
			setCD("danger", 15);
		var b = getCD("danger");
		if (b > 0) {
			var r = b / 20;
			spr.transform.colorTransform = Color.getColorizeCT(Color.interpolateInt(0xFF0000, 0xFFFF00, r), 0.6);
		} else if (blinkCpt <= 0)
			spr.transform.colorTransform = new ColorTransform();
	}
}
