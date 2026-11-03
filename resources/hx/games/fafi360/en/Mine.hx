package fafi360.en;

class Mine extends Entity {
	var mc			: MovieClip;
	var timer		: Int;
	public function new() {
		super();

		timer = -1;

		game.miscEntities.push(this);

		mc = new MovieClip("Mine");
		spr.addChild(mc);
		mc.stop();

		cx = Game.FPADDING + rseed.irange(8, Game.FWID-8);
		cy = Game.FPADDING + rseed.irange(3, Game.FHEI-3);
	}

	override public function unregister() {
		super.unregister();
		game.miscEntities.remove(this);
		mc.dispose();
	}

	public override function update() {
		super.update();

		var b = game.ball;

		if( timer>0 ) {
			timer--;
			var blink = timer%3==0;
			mc.gotoAndStop(blink ? 2 : 1);
			if( blink )
				mc.filters = [ new GlowFilter(0xFFC600,0.8, 2,2,10) ];
			else
				mc.filters = [];

			if( timer<=0 )
				explode(100);
		}

		if( game.isPlaying() && timer<0 )
			if( b.z<=3 && distance(b)<=30 )
				timer = 15;
	}
}
