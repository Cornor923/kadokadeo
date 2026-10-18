package brutalteenagecrisis.en.mob;

// (Arkadeo HTML5 port) The explosion starts at once but AFTER super.onDie() (killed = true): a chain of explosions does
// not hit the first bomber again (!e.killed), no double loot nor endless re-entry.
class Bomber extends Walker {
	var exploded:Bool;

	public function new(x, y) {
		super(x, y);

		type = MT_Bomber;
		animBaseKey = "mob_d";
		initLife(1);
		speed *= 0.6 + 0.2 * Math.min(1, mode.diff / 200);
		radius = 14;
		exploded = false;
		barY -= 5;
	}

	function explode() {
		if (exploded)
			return;
		exploded = true;

		var r = 200;
		fx.bombExplosion(xx, yy, r);
		for (e in brutalteenagecrisis.en.Mob.ALL)
			if (e != this && !e.killed && atDistance(e, r)) {
				e.hit(xx, yy, 5);
				e.ignoreFloors(1);
			}
	}

	override function onDie() {
		super.onDie(); // killed = true before the explosion
		explode(); // whatever killed it
	}

	override function loot() {
		dropGold(4);
	}

	override function update() {
		super.update();

		if (!cd.hasSet("spark", Seed.rangeVfx(4, 8)))
			fx.sparks(xx + dir * 5, yy - 50, dir);
	}
}
