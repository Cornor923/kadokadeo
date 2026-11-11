package greenwitch.en.mob;

class FireCannon extends greenwitch.en.Mob {
	public function new(x,y) {
		super(x,y);
		
		maxPathLen = 0;
		setSpeed(0);
		radius = 12;
		initLife(20);
		weight = 999;
		strength = 0;
		
		sprite.swap("turret", 4);
		sprite.setCenter(0.5, 0.8);
		defaultAnim = null;
		setShadow(false);
	}
	
	override function getLoot():Null<Int> { return 2; }
	override function getXp():Null<Int> { return 4; }


	override function onDie() {
		super.onDie();
		fx.explode(xx,yy);
	}
	
	override function moveAI() {}
	
	override function update() {
		super.update();
		if( !cd.has("shoot") )
			for( e in game.getAllies(rseed.random(6)==0) )
				if( sightCheck(e) ) {
					cd.set("shoot", 50);
					var pt = e.getAnticipatedCoord();
					new greenwitch.en.sh.FireBall(xx,yy-25, pt.x, pt.y);
					break;
				}
				
		sprite.scaleX = 1;
	}
}
