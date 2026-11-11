package greenwitch.en.sh;


class TurretBullet extends greenwitch.en.Shoot {
	public var color		: Int;
	
	public function new(x,y, e:Entity) {
		super(x,y);
		
		speed *= 1.2;
		
		color = 0xFFC600;
		fx.energyHit(xx, yy, color);
		
		var a = Game.atan2(e.yy-yy, e.xx-xx);
		dx = Game.cos(a)*speed;
		dy = Game.sin(a)*speed;
		sprite.rotation = Lib.deg(a);
		
		sprite.graphics.lineStyle(7, color, 0.3);
		sprite.graphics.beginFill(color,1);
		sprite.graphics.drawCircle(0, 0, 3);
		sprite.graphics.drawCircle(-5, 0, 2);
		sprite.blendMode = BlendMode.ADD;
		S.BANK.lazer02().play( Seed.rangeVfx(0.03, 0.07) );
	}
	
	public override function update() {
		super.update();
		
		for(e in getPropsInRange(18))
			if( e.canBeHit() ) {
				e.hit(1);
				fx.hit(xx,yy, color);
				destroy();
				break;
			}
			
		for(e in getMobsInRange(18))
			if( e.canBeHit() ) {
				e.hit(1);
				fx.hit(xx,yy, color);
				destroy();
				break;
			}
	}
}