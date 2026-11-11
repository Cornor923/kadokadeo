package greenwitch.en;


class Bomb extends Entity {
	static inline var DELAY = 40;
	
	var warning		: Sprite;
	var bomb		: BSprite;
	
	public function new(from:Entity, x,y) {
		super();
		
		collides = false;
		weight = 0;
		
		xx = x;
		yy = y;
		updateFromScreenCoords();
		
		var b = game.char.get("bomb", 0);
		game.sdm.add(b, Const.DP_BOMB);
		b.x = from.xx;
		b.y = from.yy-30;
		b.setCenter(0.5,0.5);
		game.tw.create(b, "y", b.y-200, TLinear, 300);
		game.tw.create(b, "alpha", 0, TLinear, 300).onEnd = function() {
			b.destroy();
		}
		
		
		bomb = game.char.get("bomb", 1);
		bomb.setCenter(0.5, 1);
		bomb.visible = false;
		bomb.x = xx;
		bomb.y = yy-150;
		game.sdm.add(bomb, Const.DP_BOMB);
		
		// (Arkadeo HTML5 port) the aiming sight drawn around (0, 0), not flattened (a RenderTexture by bomb) and without its
		// GlowFilter (a filter pass by bomb): its orange glow is a wider translucent stroke under it
		warning = new Sprite();
		var g = warning.graphics;
		g.lineStyle(7, 0xFF7B1A, 0.30);
		g.drawCircle(0,0,20);
		g.lineStyle(4, 0xFFFF00, 0.9);
		g.drawCircle(0,0,20);
		g.moveTo(-25,0); g.lineTo(-15,0);
		g.moveTo(25,0); g.lineTo(15,0);
		g.moveTo(0,-25); g.lineTo(0,-15);
		g.moveTo(0,25); g.lineTo(0,15);
		
		warning.blendMode = BlendMode.ADD;
		warning.x = xx;
		warning.y = yy;
		game.sdm.add(warning, Const.DP_BG_FX);
		
		cd.set("arrive", DELAY);
		cd.onComplete("arrive", function() {
			play3dSound( S.BANK.fall01(), Seed.rangeVfx(0.1, 0.2) );
		});
	}
	
	override public function destroy() {
		super.destroy();
		bomb.destroy();
		warning.detach();
		warning.releaseGpu();
		play3dSound( S.BANK.explode05(), 0.3 );
	}
	
	override public function update() {
		super.update();
		
		//warning.scaleX -= 0.03;
		//if( warning.scaleX<0.8 )
			//warning.scaleX = 1;
		//warning.scaleY = warning.scaleX;
		warning.scaleX = 0.5 + 0.5*cd.get("arrive")/DELAY;
		warning.scaleY = warning.scaleX * 0.7;
		warning.x = xx;
		warning.y = yy;
		
		if( !cd.has("arrive") ) {
			warning.alpha = game.time%3==0 ? 1 : 0.5;
			bomb.visible = true;
			bomb.y+=8;
			fx.bombSmoke(bomb.x, bomb.y-5, 0xA3AAC2);
			if( bomb.y>=yy ) {
				fx.explode(xx,yy);
				game.explosion(true, xx,yy, 30, 3, 2);
				fx.burn(xx,yy);
				destroy();
			}
		}
	}
}

