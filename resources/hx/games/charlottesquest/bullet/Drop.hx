package charlottesquest.bullet;

class Drop extends Bullet {
	public var mc:MovieClip;

	var scale:Float;

	public function new() {
		super();

		hitPlayer = true;
		autoKill = KillCond.LeaveScreen;
		color = 0xC40000;
		radius = 6;
		range = 600;
		gravity = 0.008;
		scale = 0.7;
		frictX = 0.95;
		frictY = 0.98;
		trailWid = 0;

		followScroll = false;
		mc = new MovieClip("Blood");
		spr.addChild(mc);
		mc.scaleX = mc.scaleY = 0;
		mc.getClip("_smc")._yscale = 0.1 * 100;
		mc.y = -7;
	}

	override public function unregister() {
		super.unregister();
		mc.dispose();
	}

	override public function update() {
		super.update();
		if (mc.scaleX < scale) {
			mc.scaleX += 0.06;
			if (mc.scaleX > scale)
				mc.scaleX = scale;
			mc.scaleY = mc.scaleX;
		}
		mc.rotation *= 0.95;
		var smc = mc.getClip("_smc");
		if (smc._yscale / 100 < 3)
			smc._yscale += gravity * 27 * 100;
	}
}
