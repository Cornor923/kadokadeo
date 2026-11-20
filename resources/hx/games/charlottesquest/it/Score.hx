package charlottesquest.it;

class Score extends Item {
	static var VALUES = [10, 50, 250];

	var value:Int;

	public function new(e:Entity, type:Int) {
		super();

		radius = 25;
		copyPos(e);
		autoKillOutsider = true;
		color = 0xBCF807;

		frictX = 0.98;
		frictY = 0.90;
		gravity = 0.004 + rnd(0, 0.003);
		autoKill = KillCond.LeaveScreen;

		spr.rotation = rnd(5, 40, true);

		// (lib.Billet, drawn by cacheAnims)
		value = VALUES[type];
		spr.scaleX = rseed.random(2) == 0 ? -1 : 1;
		cacheAnims("score_" + type, type == 2 ? 1 : 0.7);

		switch (type) {
			case 0:
				setAnim("bronze");
			case 1:
				setAnim("silver");
			case 2:
				setAnim("gold");
			default:
				throw "err" + type;
		}

		dy = -rnd(0.20, 0.30);
	}

	override function onAutoKill() {
		super.onAutoKill();
	}

	override public function setPos(x, y, ?xrr:Float, ?yrr:Float) {
		super.setPos(x, y, xrr, yrr);
		var pt = getScreenPoint();
		dx = 0.05 * (pt.x < Game.WID * 0.5 ? 1 : -1) + game.lastScroll.x;
	}

	override public function pickUp() {
		super.pickUp();
		game.addScore(this, value);
	}

	override public function update() {
		super.update();

		if (game.perf < 0.65) {
			if (!animPaused)
				setAnimFrame(0);
			animPaused = true;
		}

		spr.rotation *= 0.95;
	}
}
