package greenwitch.en.sh;


class Bullet extends greenwitch.en.Shoot {
	public var color		: Int;
	
	public function new(x,y, e:Entity, big:Bool) {
		super(x,y);
		
		color = 0x80FF00;
		fx.energyHit(xx, yy, color);
		
		var a = Game.atan2(e.yy-yy, e.xx-xx);
		dx = Game.cos(a)*speed;
		dy = Game.sin(a)*speed;
		sprite.rotation = Lib.deg(a);
		
		sprite.graphics.lineStyle(big ? 7 : 3, color, 0.3);
		sprite.graphics.beginFill(color,1);
		sprite.graphics.drawCircle(0, 0, big ? 3 : 2);
		sprite.graphics.drawCircle(-5, 0, big ? 2 : 1);
		sprite.blendMode = BlendMode.ADD;
		S.BANK.lazer02().play( Seed.rangeVfx(0.03, 0.07) );
	}
	
	public override function update() {
		super.update();
		
		for(e in getPropsInRange(15)) {
			e.hit(1);
			fx.hit(xx,yy, color);
			destroy();
			return;
		}
			
		for(e in getMobsInRange(15))
			if( e.canBeHit() ) {
				e.hit(1);
				fx.hit(xx,yy, color);
				destroy();
				return;
			}
	}
}