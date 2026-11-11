package charlottesquest;

class Item extends Entity {
	var realGravity:Float;
	var bubble:Null<MovieClip>;
	var hasBeenCaptured:Bool;

	public function new() {
		super();
		radius = 25;
		realGravity = gravity;
		hasBeenCaptured = false;

		game.items.add(this);
		game.sdm.add(spr, Game.DP_ITEM);

		autoKill = KillCond.LeaveScreen;
	}

	override public function toString() {
		return "Item#" + uid;
	}

	override public function unregister() {
		super.unregister();
		game.items.remove(this);
		if (bubble != null)
			bubble.dispose();
	}

	public function pickUp() {
		var pt = getPoint();
		fx.popDots(pt.x, pt.y, color);
	}

	override public function update() {
		// Apparition bulle de capture
		var capture = game.player.build.capture;
		if (capture > 0 && !hasBeenCaptured) {
			hasBeenCaptured = true;
			realGravity = gravity;
			bubble = new MovieClip("Bubble");
			spr.addChild(bubble);
			bubble.alpha = 0.5;
			bubble.blendMode = BlendMode.ADD;
			setCD("capture", 15 + capture * 12 + rseed.range(0, 5));
			gravity = 0.01 * realGravity;
			if (capture < 2)
				dy *= 0.5;
			else
				dy *= 0.2;
		}

		// Aimant
		if (capture > 0 && hasCD("capture") && game.time % 3 == 0 && !game.player.dead()) {
			var d = Lib.distance(rx, ry, game.player.rx, game.player.ry);
			var a = Game.atan2(game.player.ry - ry, game.player.rx - rx);
			var pow = (1 - Math.min(1, d / 180)) * (capture / 6);
			dx += Game.cos(a) * 0.1 * pow;
			dy += Game.sin(a) * 0.1 * pow;
		}

		// (the bubble flattened when the machine is slow (perf <= 0.85): never here)
		if (bubble != null) {
			if (!hasCD("capture")) {
				gravity = realGravity;
				bubble.parent.removeChild(bubble);
				bubble.dispose();
				bubble = null;
				var pt = getPoint();
				fx.anim(new MovieClip("Pop"), pt.x, pt.y);
			}
		}

		var pt = getScreenPoint();
		if (pt.y <= 5)
			dy = 0.1;

		super.update();

		if (checkHit(game.player, true)) {
			destroy();
			pickUp();
		}
	}
}
