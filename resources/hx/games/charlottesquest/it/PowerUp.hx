package charlottesquest.it;

enum PowerUpKind {
	FrontBack;
	UpDown;
	Speed;
	Capture;
	Uber;
}

class PowerUp extends Item {
	var kind:PowerUpKind;
	var duration:Int;
	var mc:MovieClip;

	public function new(from:Entity, k:PowerUpKind) {
		super();

		kind = k;

		autoKillOutsider = true;
		radius = 25;
		copyPos(from);

		var a = 3.14 + getAngleTo(game.player);
		dx = Game.cos(a) * 0.1;
		dy = Game.sin(a) * 0.1;

		followScroll = true;
		duration = 30 * 10;
		frictX = frictY = 1;
		autoKill = KillCond.LeaveScreen;

		mc = new MovieClip("PowerIcon");
		var s = 0.7;
		switch (kind) {
			case FrontBack:
				mc.gotoAndStop(1);
				s = 0.8;
			case UpDown:
				mc.gotoAndStop(2);
				s = 0.8;
			case Speed:
				mc.gotoAndStop(3);
				s = 0.7;
			case Capture:
				mc.gotoAndStop(4);
				s = 0.7;
			case Uber:
				// (gotoAndStop(10) of a clip of 5 frames: its last frame)
				mc.gotoAndStop(10);
				s = 1;
		}
		mc.scaleX = mc.scaleY = s;
		mc.blendMode = BlendMode.ADD;
		spr.addChild(mc);
	}

	public static function randomKind(rs:Rand) {
		var rlist = new RandList();
		var b = Game.ME.player.build;
		if (b.front < 8)
			rlist.add(FrontBack, 10);
		if (b.up < 8)
			rlist.add(UpDown, 10);
		if (b.speed < 5)
			rlist.add(Speed, 5);
		if (b.capture < 8)
			rlist.add(Capture, 3);
		if (rlist.length() == 0)
			return null;
		else
			return rlist.draw(rs.random);
	}

	override function toString() {
		return super.toString() + "[" + kind + "]";
	}

	override public function unregister() {
		super.unregister();
		mc.dispose();
	}

	override public function pickUp() {
		super.pickUp();
		var txt = "???";
		var inc = 2;
		switch (kind) {
			case FrontBack:
				game.player.build.front += inc;
				game.player.build.back += inc;
				txt = Lang.get("Horizontal");
			case UpDown:
				game.player.build.up += inc;
				game.player.build.down += inc;
				txt = Lang.get("Vertical");
			case Speed:
				game.player.build.speed += inc;
				txt = Lang.get("Speed");
			case Capture:
				game.player.build.capture += inc;
				txt = Lang.get("Capture");
			case Uber:
				game.player.uber();
				txt = Lang.get("Uber");
		}
		game.player.applyBuild();
		var pt = getPoint();
		game.pop(pt.x, pt.y, txt);
	}

	override public function update() {
		if (duration <= 30 * 1)
			spr.alpha = game.time % 2 == 0 ? 0.5 : 1;
		else if (duration <= 30 * 3)
			spr.alpha = game.time % 4 == 0 ? 0.5 : 1;

		if (duration-- <= 0) {
			fx.explodeLight(this, color);
			game.addSkill(-0.2);
			destroy();
			return;
		}

		// Rebonds bords
		var pt = getScreenPoint();
		var m = 30;
		if (pt.x < m && dx < 0 || pt.x >= Game.WID - m && dx > 0)
			dx = -dx;
		if (pt.y < m && dy < 0 || pt.y >= Game.HEI - m && dy > 0)
			dy = -dy;

		super.update();
	}
}
