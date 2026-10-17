package brutalteenagecrisis.en.it;

class Bomb extends brutalteenagecrisis.en.Item {
	public function new(x,y) {
		super(x,y);
		setDuration(30);

		sprite.a.playAndLoop("bomb");
		addGlow("glow_bomb");
	}

	override function onPick() {
		super.onPick();
		var r = 200;
		fx.bombExplosion(xx,yy, r);
		for(e in brutalteenagecrisis.en.Mob.ALL)
			if( atDistance(e, r) && e.canBeHit ) {
				e.hit(xx,yy, 5);
				e.ignoreFloors(1);
			}
	}
}
