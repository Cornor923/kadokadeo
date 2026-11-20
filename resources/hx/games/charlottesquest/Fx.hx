package charlottesquest;

// The effects: their random draws on the random of the effects of KadoKadeo (Seed.*Vfx, the original: Math.random / Std.random)
class Fx {
	var game:Game;
	var anims:Array<MovieClip>;

	public function new() {
		game = Game.ME;
		anims = new Array();
	}

	inline function register(p:Particle, ?b:BlendMode, ?inScrolling = true) {
		if (inScrolling)
			game.sdm.add(p, Game.DP_FX);
		else
			game.dm.add(p, game.shopping ? Game.DP_INTERF : Game.DP_FX);
		p.blendMode = b == null ? BlendMode.ADD : b;
	}

	inline function rnd(min:Float, max:Float, ?sign = false) {
		return Seed.rangeVfx(min, max, sign);
	}

	inline function irnd(min:Int, max:Int, ?sign = false) {
		return Seed.irangeVfx(min, max, sign);
	}

	inline function deg(a) {
		return Lib.deg(a);
	}

	inline function rad(a) {
		return Lib.rad(a);
	}

	public function tinyDrops(x:Float, y:Float, col:Int) { // moustique
		if (game.perf <= 0.7)
			return;
		for (i in 0...8) {
			var p = new Particle(x + rnd(0, 2, true), y + rnd(0, 4, true));
			p.reset();
			p.drawBox(1, 1, col);

			p.gy = rnd(0.1, 0.7);
			var s = rnd(1, 2);
			p.life = rnd(8, 16);
			p.frictX = p.frictY = 0.93;

			p.pixel = true;
			register(p, BlendMode.NORMAL);
		}
	}

	public function popDots(cx:Float, cy:Float, col:Int) {
		if (game.perf <= 0.7)
			return;
		var n = game.perf >= 0.85 ? 9 : 5;
		var base = rnd(0, 6.28);
		for (i in 0...n) {
			var a = base + 6.28 * i / n;
			var d = rnd(5, 6);
			var x = cx + Math.cos(a) * d;
			var y = cy + Math.sin(a) * d;
			var p = new Particle(x, y);
			p.reset();
			p.drawBox(2, 1, col);

			p.rotation = deg(a);
			p.dx = Math.cos(a) * 4;
			p.dy = Math.sin(a) * 4;
			p.life = 24 + i * 2;
			p.frictX = p.frictY = 0.85;

			p.filters = [new GlowFilter(col, 0.7, 8, 8, 6)];
			p.pixel = true;
			register(p);
		}
	}

	public function popCircle(e:Entity) {
		var pt = e.getPoint();
		var p = new Particle(pt);
		p.reset();
		p.graphics.lineStyle(1, e.color, 0.5);
		p.graphics.drawCircle(0, 0, e.radius + 3);
		p.life = rnd(0, 3);
		p.ds = 0.03;
		register(p);
	}

	public function uber() {
		var e = game.player;
		var pt = e.getPoint();
		var n = game.perf >= 0.7 ? 5 : 1;
		for (i in 0...n) {
			var color = Color.randomColor(rnd(0, 1), 0.4, 1);
			var p = new Particle(pt.x + rnd(0, 20, true), pt.y + rnd(0, 35, true));
			p.drawBox(2, 2, color, rnd(0.5, 1));
			p.reset();
			p.dx = -e.dx * 4;
			p.dy = -e.dy * 4;
			p.frictX = 0.92;
			p.frictY = 0.97;
			p.alpha = 0;
			p.da = 0.1;
			p.gx = rnd(0, 0.2, true);
			p.gy = rnd(0, 0.1, true);
			p.life = rnd(0, 32);
			p.filters = [new GlowFilter(color, 0.7, 8, 8, 5),];
			register(p);
		}
	}

	public function hit(x:Float, y:Float, col:Int) {
		for (i in 0...3) {
			var p = new Particle(x + rnd(0, 3, true), y + rnd(0, 3, true));
			p.reset();
			p.graphics.lineStyle(1, col, 1);
			p.graphics.drawCircle(0, 0, rnd(3, 8));
			p.life = rnd(2, 6);
			p.ds = 0.02;
			p.filters = [new GlowFilter(col, 0.5, 16, 16, 2)];
			register(p);
		}
	}

	public function anim(mc:MovieClip, x:Float, y:Float) {
		mc.x = x;
		mc.y = y;
		mc.rotation = rnd(0, 360);
		game.sdm.add(mc, Game.DP_FX);
		mc.gotoAndStop(1);
		anims.push(mc);
		return mc;
	}

	public function cadaver() {
		var mc = new MovieClip("Dead");
		var pt = game.player.getPoint();
		var p = new Particle(pt.x, pt.y);
		p.addChild(mc);
		p.dr = rnd(2, 5, true);
		p.dx = rnd(1, 2, true);
		p.dr = (p.dx < 0 ? -1 : 1) * 5;
		p.dy = -rnd(6, 7);
		p.frictX = 1;
		p.gy = 0.4;
		p.scaleX = p.scaleY = 0.8;
		p.life = 100;
		p.flatten();
		mc.dispose();
		register(p, BlendMode.NORMAL);
	}

	public function splash(from:Entity, to:Entity) {
		if (game.perf < 0.7)
			return;
		var pt = to.getPoint();
		var x = pt.x + 5;
		var y = pt.y + 5;
		var col = 0xC66FD2;
		var col = 0x8A2F97;
		var r = game.getRoomAt(x, y);
		if (r == null || !r.ready)
			return;

		var wrapper = new Sprite();
		wrapper.filters = [
			new BlurFilter(2, 2),
			new DropShadowFilter(6, 90, 0xffffff, 0.2, 2, 2, 1, 1, true),
			new DropShadowFilter(3, 90, col, 1, 0, 0, 1, 1, true),
			new DropShadowFilter(2, 90, 0x0, 0.3, 4, 4, 1),
		];

		// (ct.color = col: a solid colour; the pictures of lib.Splash1 are white, tinted)
		var ct = new ColorTransform(((col >> 16) & 0xFF) / 255, ((col >> 8) & 0xFF) / 255, (col & 0xFF) / 255, 1);

		var clips = [];
		for (i in 0...irnd(1, 2)) {
			var mc = new MovieClip("Splash1");
			wrapper.addChild(mc);
			mc.gotoAndStop(Seed.randomVfx(mc.totalFrames) + 1);
			mc.rotation = rnd(0, 360);
			mc.scaleX = mc.scaleY = rnd(4, 5);
			mc.transform.colorTransform = ct;
			clips.push(mc);
		}

		wrapper.alpha = 0.5;
		// (getBounds(wrapper): the box of its pictures)
		var b = wrapper.contentRect();
		var cox = (b.left + b.width * 0.5);
		var coy = (b.top + b.height * 0.5);
		var bmp = Lib.flatten(wrapper);
		for (mc in clips)
			mc.dispose();
		var pt = new Point(x - bmp.width * 0.5 - r.cx * Room.CWID * Room.GRID, y - bmp.height * 0.5 - r.cy * Room.CHEI * Room.GRID);
		pt.x += cox;
		pt.y += coy;
		r.splashes.bitmapData.copyPixels(bmp.bitmapData, bmp.bitmapData.rect, pt, r.bg.bitmapData, pt, true);

		bmp.bitmapData.dispose();
	}

	public function playerDeath() {
		var e = game.player;
		e.mc.visible = false;
		var pt = e.getScreenPoint();
		pt.x += 10;
		if (pt.x < 0)
			pt.x = -10;
		if (pt.x >= Game.WID)
			pt.x = Game.WID + 10;
		if (pt.y < 0)
			pt.y = -10;
		if (pt.y >= Game.HEI)
			pt.y = Game.HEI + 10;

		var p = new Particle(pt.x, pt.y);
		p.reset();
		p.graphics.beginFill(0xD27AE9, 0.5);
		p.graphics.drawCircle(0, 0, 50);
		p.graphics.endFill();
		p.scaleX = p.scaleY = 2;
		p.ds -= 0.2;
		p.life = 1;
		register(p, false);

		for (i in 0...50) {
			var p = new Particle(pt.x + rnd(0, 10, true), pt.y + rnd(0, 10, true));
			p.drawBox(rnd(3, 6), rnd(3, 6), Seed.randomVfx(100) < 30 ? 0xFF8040 : 0xD55BFD);
			p.reset();
			var a = rnd(0, 6.28);
			var s = rnd(5, 10);
			p.rotation = deg(a);
			p.frictX = 0.96;
			p.frictY = 0.94;
			p.dx = Math.cos(a) * s;
			p.dy = Math.sin(a) * s;
			p.dr = rnd(10, 30);
			p.gy = 0.1;
			p.delay = rnd(0, 8);
			p.life = rnd(15, 70);
			p.filters = [
				new DropShadowFilter(2, -90, 0x0, 0.4, 2, 2, 1, 1, true),
				new GlowFilter(0x0, 0.3, 2, 2, 3),
			];
			p.flatten(2);
			register(p, BlendMode.NORMAL, false);
		}

		cadaver();
	}

	public function explodeLight(e:Entity, col:Int) {
		if (game.perf <= 0.7)
			return;
		var pt = e.getPoint();
		for (i in 0...15) {
			var p = new Particle(pt.x + rnd(0, 10, true), pt.y + rnd(0, 10, true));
			p.reset();
			p.drawBox(rnd(2, 8), 2, col);
			var a = rnd(0, 6.28);
			var s = rnd(9, 15);
			p.rotation = deg(a);
			p.frictX = p.frictY = 0.90;
			p.dx = Math.cos(a) * s;
			p.dy = Math.sin(a) * s;
			p.life = rnd(5, 20);
			p.filters = [new GlowFilter(col, 0.7, 8, 8, 2)];
			register(p);
		}
	}

	public function update() {
		Particle.update();

		var i = 0;
		while (i < anims.length) {
			if (anims[i].currentFrame == anims[i].totalFrames) {
				anims[i].parent.removeChild(anims[i]);
				anims[i].dispose();
				anims.splice(i, 1);
			} else {
				anims[i].nextFrame();
				i++;
			}
		}
	}
}
