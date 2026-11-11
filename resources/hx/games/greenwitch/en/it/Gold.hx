package greenwitch.en.it;

class Gold extends greenwitch.en.Item {
	static var VALUES = [50, 200, 500, 5000];
	
	var v			: Int;
	
	public function new(x,y, lvl:Int) {
		super(x,y);
		
		v = VALUES[lvl];
		// (AKApi.isLowQuality: never)
		zsortable = true;
		
		var f = switch( lvl ) {
			case 0 : irnd(0,2);
			case 1 : 3;
			case 2 : 4;
			case 3 : 5; // coffre
			default : 0;
		}
		sprite.swap("gold", f);
		sprite.setCenter(0.5, 0.8);
		
		if( lvl>=3 )
			duration = -1;
		else
			duration = 30*20;
		if( lvl>=2 )
			zsortable = true;
		//switch( lvl ) {
			//case 0 : sprite.setCenter(0.5, 0.8);
			//case 1 : sprite.setCenter(0.5, 0.7);
			//case 2 : sprite.setCenter(0.5, 0.6);
			//default : sprite.setCenter(0.5, 0.5);
		//}
	}
	
	override private function onPickUp() {
		super.onPickUp();
		game.addScorePop(xx,yy, v);
		S.BANK.item01().play( Seed.rangeVfx(0.4, 0.8) );
		mt.deepnight.Sfx.playOne([
			S.BANK.gold01, S.BANK.gold02, S.BANK.gold03,
		], Seed.rangeVfx(0.2, 0.3));
	}
}