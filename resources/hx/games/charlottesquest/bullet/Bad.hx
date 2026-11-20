package charlottesquest.bullet;

class Bad extends Bullet {
	// (the original flattened the same shapes for every bullet: the picture of each colour drawn once, shared)
	static var CACHE:Map<Int, {bd:BitmapData, x:Float, y:Float}> = new Map();

	public static function clearCache() {
		for (c in CACHE)
			c.bd.dispose();
		CACHE = new Map();
	}

	var cache:Bitmap;

	public function new(e:Enemy, ?col = 0xFFBF00) {
		super();

		range = 300;
		radius = 5;
		setPos(e.cx, e.cy, e.xr, e.yr);
		color = col;
		speed = 0.15;

		var c = CACHE.get(color);
		if (c == null) {
			var s = new Sprite();
			// Halo
			s.graphics.beginFill(color, 0.2);
			s.graphics.drawCircle(0, 0, radius * 2);
			s.graphics.endFill();

			// Coeur
			s.graphics.beginFill(Color.lighten(color, 0.5), 1);
			s.graphics.lineStyle(1, color, 1);
			s.graphics.drawCircle(0, 0, radius);
			s.graphics.endFill();
			s.filters = [new GlowFilter(color, 0.3, 4, 4, 8, 2), new GlowFilter(color, 0.6, 16, 16, 1, 2),];

			var b = Lib.flatten(s, 16);
			c = {bd: b.bitmapData, x: b.x, y: b.y};
			CACHE.set(color, c);
		}
		cache = new Bitmap(c.bd);
		cache.x = c.x;
		cache.y = c.y;
		spr.addChild(cache);
	}

	public function toPlayer(?spd:Float) {
		if (spd != null)
			speed = spd;
		var a = getAngleTo(game.player);
		dx = Game.cos(a) * speed;
		dy = Game.sin(a) * speed;
	}

	override public function update() {
		if (game.perf >= 0.8) {
			spr.scaleX = spr.scaleY = rnd(0.9, 1.1);
			spr.alpha = rnd(0.5, 1);
		}
		super.update();
	}
}
