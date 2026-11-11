package charlottesquest.en;

class Mosquito extends Enemy {
	public static var MIN_DIFF = 7;

	var zigzag:Float;
	var turnBacks:Int;
	var cadency:Int;
	var dir:Int;

	public function new() {
		super();

		radius = 25;
		zigzag = rnd(2, 3);
		followScroll = true;
		autoKill = KillCond.LeaveScreen;
		color = 0xAEB627;
		initLife(3);
		turnBacks = 2;
		cadency = 80;
		pullable = false;

		var margin = 60 + waveCount() * 150;
		var spawn = rnd(0, 300);
		switch ((wrand.random(2) + waveCount()) % 2) {
			case 0: // droite
				dir = -1;
				setPosScreen(Game.WID + margin, 50);
			case 1: // gauche
				dir = 1;
				setPosScreen(-margin, 50);
			default:
		}
		speed = rnd(0.05, 0.07);
		speed = rnd(0.09, 0.12);

		var scale = 0.75;
		radius *= scale;
		// (lib.Moustik, drawn by cacheAnims)
		cacheAnims("mosquito", scale);
		setAnim("right");

		setCD("shoot", 100);
	}

	override public function toString() {
		return super.toString() + "[Mosquito]";
	}

	override public function hit(v:Float, ?from:Entity) {
		super.hit(v, from);
		setAnim("right");
		setAnim("hit", false);
	}

	override public function onDie() {
		super.onDie();
		dropReward(2);
	}

	override public function update() {
		dx = dir * speed;
		dy = Game.sin(uid + game.time * 0.2 * 3.14) * 0.03 * zigzag;
		spr.rotation = Math.sin(uid + game.time * 0.2 * 3.14) * 5;
		if (animDone())
			setAnim("right");

		super.update();

		if (onScreen && !hasCD("shoot")) {
			var b = new charlottesquest.bullet.Drop();
			b.setPosInScroll(rx + (-dir * 8), ry + 16);
			b.dx = dx;
			fx.tinyDrops(b.rx, b.ry, b.color);
			setAnim("shoot", false);
			setCD("shoot", cadency);
			b.mc.rotation = dir * 15;
		}

		var pt = getScreenPoint();
		if (turnBacks > 0) {
			if (dx > 0 && pt.x > Game.WID - radius * 2) {
				turnBacks--;
				setAnim("turn", false);
				dir = -1;
			}
			if (dx < 0 && pt.x < radius * 2) {
				turnBacks--;
				setAnim("turn", false);
				dir = 1;
			}
		}

		spr.scaleX = dir;
	}
}
