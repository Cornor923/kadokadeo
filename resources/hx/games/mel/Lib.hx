package mel;

// Lib.hx of the original: the size of the Arkadeo game area (600 x 480, of which the game has 600 x 460 below the bar
// of Arkadeo) in cells of 16 x 16 pixels
class Lib {
	public static inline var sw = 600;
	public static inline var sh = 480;

	public static inline function ph():Int
		return nbch() << ch_shift;

	public static inline function h():Int
		return sh - 20;

	public static inline function w():Int
		return sw;

	public static inline function nbch():Int
		return (sh - 20) >> ch_shift;

	public static inline function nbcw():Int
		return sw >> cw_shift;

	public static inline var cw:Int = 16;
	public static inline var cw_shift:Int = 4;

	public static inline var ch:Int = 16;
	public static inline var ch_shift:Int = 4;

	// Lib.getTf: a text in the galaxy font (orange, inner orange glow, black outline); here the white one of the bonus
	// texts (the only use: Bonus.onProc sets textColor to white)
	public static function getTf(txt:String, sz:Int = 10):TextField {
		var t = new TextField("score");
		t.text = txt;
		return t;
	}

	// returns the next position going to (x, y) at speed (unused by the game)
	public static function goto(mx:Float, my:Float, x:Float, y:Float, speed:Float, eps = 0.1):Null<{nx:Float, ny:Float}> {
		var diffX = x - mx;
		var diffY = y - my;
		var len = diffX * diffX + diffY * diffY;
		if (len <= eps * eps)
			return {nx: x, ny: y};
		if (len < speed) {
			mx = x;
			my = y;
		} else {
			var il = 1.0 / len;
			mx += diffX * il * speed;
			my += diffY * il * speed;
		}
		return {nx: mx, ny: my};
	}

	public static inline var WALL_ID = 0xAA;
}
