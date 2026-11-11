package charlottesquest.bullet;

class Heart extends Bullet {
	// (Lib.flatten of lib.Shoot per level: its picture of the sheet, nothing to cache)
	public static inline function clearCache() {}

	var bmp:Bitmap;

	public function new(ang:Float, r:Float, level:Int) {
		super();

		var powerScale = level / 8;

		power = 1 + powerScale * 5;
		trailWid = if (level == 0) 0 else 1;

		hitPlayer = false;
		radius = 15;
		color = 0xFF80FF;
		copyPos(game.player);
		xr += Game.cos(ang) * 0.8;
		yr += Game.sin(ang) * 0.4;
		var spd = 0.50;
		dx = Game.cos(ang) * spd;
		dy = Game.sin(ang) * spd;

		range = r;

		// (the frame 1 + level of lib.Shoot, flattened: drawn at its registration point)
		bmp = new Bitmap("Shoot", 1 + level);

		spr.addChild(bmp);
		spr.blendMode = BlendMode.ADD;
	}
}
