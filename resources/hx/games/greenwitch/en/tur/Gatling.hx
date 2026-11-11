package greenwitch.en.tur;

class Gatling extends greenwitch.en.Turret {
	static var AUTOHIT_FREQ = 3*30;
	
	public function new(tcx,tcy) {
		super(tcx,tcy);
		initLife(5);
		sprite.setFrame(3);
		showBar = true;
		barOffsetY = 4;
		cd.set("autoHit", AUTOHIT_FREQ);
	}
	
	public override function update() {
		super.update();
		
		if( !cd.hasSet("autoHit", AUTOHIT_FREQ) )
			hit(1);
		
		if( !cd.has("shoot") ) {
			cd.set("shoot", 13);
			var e = getSingleTarget(170);
			if( e!=null )
				new greenwitch.en.sh.TurretBullet(xx+2,yy-20, e);
		}
	}
}


