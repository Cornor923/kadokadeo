package greenwitch.en.mob;

class Horde extends greenwitch.en.Mob {
	public function new(x,y) {
		super(x,y);
		
		maxPathLen = 15;
		setSpeed(0.6);
		radius = 8;
		initLife(2);
		
		sprite.swap("horde"+irnd(1,2));
		sprite.setCenter(0.5, 0.7);
		setShadow(false);
	}
	
	override function getLoot():Null<Int> { return 0; }
	override function getXp():Null<Int> { return 1; }


	override public function onDie() {
		super.onDie();
		if( !hero.dead )
			if( Seed.randomVfx(3)==0 )
				play3dSound( S.BANK.mobHit01(), Seed.rangeVfx(0.3, 0.5) );
			else
				play3dSound( S.BANK.mobHit02(), Seed.rangeVfx(0.3, 0.5) );
	}
}
