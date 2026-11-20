package charlottesquest.en;

class Eye extends Enemy {
	public static var MIN_DIFFS = [4, 14]; // TODO akconst ?

	var mc:MovieClip;
	var ang:Float;
	var spd:Float;
	var spdBoost:Float;
	var zigzag:Float;
	var scale:Float;
	var blob:Float;
	var type:Int;

	public function new(t:Int) {
		super();

		type = t;
		radius = 45;
		zigzag = rnd(0.5, 1);
		followScroll = true;
		blob = 0;
		color = 0xFCA84B;
		alertOutside = true;
		autoKillOutsider = true;

		var margin = 60;
		var spawn = rnd(0, 300);
		spd = 0.02;
		autoKill = LeaveScreen;
		var side = getRandomPopSide(MIN_DIFFS[type]);
		switch (side) {
			case 0: // haut
				ang = 1.1 + rnd(0, 0.2, true);
				setPosScreen(rnd(50, Game.WID - 200), -margin - spawn);
				spd += rnd(0.02, 0.04);
				autoKill = ReachDown;
			case 1: // droite
				ang = 3.14 + rnd(0, 0.1, true);
				setPosScreen(Game.WID + margin + spawn, rnd(100, Game.HEI - 100));
				spd += rnd(0.04, 0.08);
				autoKill = ReachLeft;
			case 2: // bas
				ang = -1.1 + rnd(0, 0.2, true);
				setPosScreen(rnd(50, Game.WID - 200), Game.HEI + margin + spawn);
				spd += rnd(0.02, 0.04);
				autoKill = ReachUp;
			case 3: // gauche
				ang = rnd(0, 0.1, true);
				setPosScreen(-margin - spawn, rnd(100, Game.HEI - 100));
				spd += rnd(0.03, 0.05);
				autoKill = ReachRight;
		}

		spdBoost = spd * 0.7;

		mc = if (type == 0) new MovieClip("Eye") else new MovieClip("Eye2");
		spr.addChild(mc);
		mc.stop();

		switch (type) {
			case 0:
				initLife(2);
				scale = rnd(0.35, 0.40);
			case 1:
				initLife(8);
				scale = rnd(0.55, 0.60);
		}

		mc.scaleX = mc.scaleY = scale;
		radius *= scale;
	}

	override public function toString() {
		return super.toString() + "[Eye]";
	}

	override public function hit(v:Float, ?from:Entity) {
		super.hit(v, from);
		blob = 1;
	}

	override public function onDie() {
		super.onDie();
		dropReward(type == 0 ? (waveKilled() ? 2 : 1) : 2);
	}

	override public function unregister() {
		super.unregister();
		mc.dispose();
	}

	override public function update() {
		if (blob > 0) {
			blob -= 0.05;
			if (blob < 0)
				blob = 0;
		}

		var a = ang + Game.sin(uid + game.time * 0.02 * 3.14) * zigzag;
		var s = spd + Game.sin(uid + game.time * 0.04 * 3.14) * spdBoost;
		dx = Game.cos(a) * s;
		dy = Game.sin(a) * s;

		mc.scaleX = scale + Math.cos(uid + game.time * 0.2 * 3.14) * (0.01 + 0.14 * blob);
		mc.scaleY = scale + Math.sin(uid + game.time * 0.2 * 3.14) * (0.01 + 0.14 * blob);

		super.update();

		// the iris looks at Charlotte (a picture: Math.atan2 not rounded)
		var pt = getScreenPoint();
		var player = game.player.getScreenPoint();
		var a = Math.atan2(player.y - pt.y, player.x - pt.x);
		var smc = mc.getClip("_smc");
		if (mc != null && smc != null) {
			var f = Math.ceil(smc.totalFrames * (1 - (3.14 + a) / 6.28));
			smc.gotoAndStop(f < 1 ? 1 : f > smc.totalFrames ? smc.totalFrames : f);
		}
	}
}
