package charlottesquest.en;

class Turret extends Enemy {
	public static var MIN_DIFF = 0;

	var cadency:Int;
	var mc:MovieClip;
	var baseAng:Float;
	var basePtX:Float;
	var basePtY:Float;
	var level:Int;
	// (the leaves keep the rotation their frame script gave them: Flash does not move again what a script turned)
	var leavesRot:Float;

	public function new(r:Room, l:Int) {
		super();

		level = l;
		radius = 22;
		initLife(level == 0 ? 1 : 2);
		fixed = true;

		cadency = 40 * 4;
		setCD("shoot", cadency + rseed.random(cadency));
		alertOutside = false;

		baseAng = 0;

		mc = new MovieClip("Tourelle");
		mc.scaleX = mc.scaleY = level == 0 ? 0.8 : 1;
		mc.stop();
		mc.getClip("_smc").stop();
		spr.addChild(mc);
		basePtX = Data.TOURELLE_SMC[0];
		basePtY = Data.TOURELLE_SMC[1];
		// (the frame script of the leaves, gfx_fla.feuillebaseglobal_47: gotoAndStop(int(Math.random() * 10 - 5)), a
		// rotation of Math.random() * 273, on the random of the effects; a frame under 1 is the frame 1)
		var leaves = mc.getClip("leaves_");
		var f = Std.int(Seed.randVfx() * 10 - 5);
		leaves.gotoAndStop(f < 1 ? 1 : f);
		leavesRot = Seed.randVfx() * 273;
		leaves._rotation = leavesRot;
		animMC = mc;
		hasToBeKilled = false;
		if (level == 0)
			mc.filters = [Color.getColorizeMatrixFilter(0xC8522B, 0.5, 0.5)];

		// Placement
		var spots = r.getEmptySpotsCopy();
		var ok = false;
		while (spots.length > 0) {
			var pt = spots.splice(rseed.random(spots.length), 1)[0];
			var x = pt.x;
			var y = pt.y;
			if (!r.hasMark(x, y))
				if (r.getCol(x - 1, y) || r.getCol(x + 1, y) || r.getCol(x, y - 1) || r.getCol(x, y + 1)) {
					setPos(r.cx * Room.CWID + x, r.cy * Room.CHEI + y);
					r.mark(x, y);
					r.mark(x, y + 1);
					r.mark(x, y - 1);
					r.mark(x + 1, y);
					r.mark(x - 1, y);
					ok = true;
					break;
				}
		}

		if (!ok) {
			destroy();
		}
	}

	override public function toString() {
		return super.toString() + "[Turret]";
	}

	override public function onDie() {
		super.onDie();
		dropReward(level == 0 ? 0 : 1);
	}

	override public function unregister() {
		super.unregister();
		mc.dispose();
	}

	override public function setPos(x, y, ?xrr:Float, ?yrr:Float) {
		super.setPos(x, y, xrr, yrr);
		if (getCol(cx, cy - 1)) {
			yr = 0.1;
			baseAng = 1.57;
		} else if (getCol(cx, cy + 1)) {
			yr = 0.9;
			baseAng = -1.57;
		} else if (getCol(cx - 1, cy)) {
			xr = 0.1;
			baseAng = 0;
		} else {
			xr = 0.9;
			baseAng = 3.14;
		}
		mc.getClip("_smc")._rotation = Lib.deg(baseAng);
	}

	override public function hit(d:Float, ?from:Entity) {
		super.hit(d, from);
		setAnim();
		setAnim("hit", false);
	}

	override function setAnim(?a, ?loop = true) {
		super.setAnim(a, loop);
		updateAng();
	}

	function updateAng() {
		var a = getAngleTo(game.player);
		var d = a - baseAng;
		if (d > 3.14)
			d -= 6.28;
		if (d < -3.14)
			d += 6.28;

		var max = 1.8;
		if (d < -max)
			a = baseAng - max;
		if (d > max)
			a = baseAng + max;

		mc.getClip("_smc")._rotation = Flash.normRot(Lib.deg(a) + 180);
		return a;
	}

	override public function update() {
		super.update();

		if (animDone()) {
			if (anim == "shoot")
				setAnim("wait");
			if (anim == "hit")
				setAnim("wait");
		}

		var a = updateAng();

		// Tir
		var cd = getCD("shoot");
		if (cd > 0 && cd < 32 && mc.currentFrameLabel == "wait")
			setAnim("charge");

		if (cd <= 0) {
			setAnim("shoot", false);
			setCD("shoot", cadency);
			if (onScreen) {
				var b = new charlottesquest.bullet.Bad(this);
				b.followScroll = false;
				b.xr += Game.cos(a) * 1;
				b.yr += Game.sin(a) * 1 - 0.2;
				b.dx = Game.cos(a) * b.speed;
				b.dy = Game.sin(a) * b.speed;
			}
		}

		var smc = mc.getClip("_smc");
		smc._x = basePtX + Math.sin(uid + game.time * 0.02 * 3.14) * 5;
		smc._y = basePtY + Math.sin(uid + game.time * 0.03 * 3.14) * 5;
		mc.getClip("leaves_")._rotation = leavesRot;
	}
}
