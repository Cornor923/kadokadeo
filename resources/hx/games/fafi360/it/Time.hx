package fafi360.it;

class Time extends GenericItem {
	var mc : MovieClip;

	public function new() {
		super();

		color = 0xB4BFCD;
		fl_repop = false;

		mc = new MovieClip("Chrono");
		spr.addChild(mc);
	}

	public override function unregister() {
		super.unregister();
		mc.dispose();
	}

	public override function pickUp() {
		super.pickUp();
		fx.popTime(xx,yy, 20);
		game.addTime(20);
	}
}
