package charlottesquest.bullet;

class Drop extends Bullet {
	public var mc:MovieClip;

	var scale:Float;

	// the stretch of the _smc of lib.Blood (the drop falling): kept here and given to it at each update, the timeline
	// of the clip places it again at each of its frames (in Flash, the code took it over). The _smc is a picture of the
	// sheet (one frame), not a nested clip: clip.get, not getClip
	var smcScaleY = 0.1;

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
		stretch();
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
		if (smcScaleY < 3)
			smcScaleY += gravity * 27;
		stretch();
	}

	function stretch() {
		var smc = mc.clip.get("_smc");
		if (smc != null)
			smc._yscale = smcScaleY * 100;
	}
}
