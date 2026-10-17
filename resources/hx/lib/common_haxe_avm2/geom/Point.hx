package common_haxe_avm2.geom;

// flash.geom.Point (a value).
class Point {
	public var x:Float;
	public var y:Float;

	public function new(?x:Float = 0, ?y:Float = 0) {
		this.x = x;
		this.y = y;
	}

	public var length(get, never):Float;
	inline function get_length():Float return Math.sqrt(x * x + y * y);

	public function clone():Point return new Point(x, y);

	public function setTo(x:Float, y:Float):Void {
		this.x = x;
		this.y = y;
	}

	public function add(p:Point):Point return new Point(x + p.x, y + p.y);
	public function subtract(p:Point):Point return new Point(x - p.x, y - p.y);
	public function offset(dx:Float, dy:Float):Void {
		x += dx;
		y += dy;
	}

	public static function distance(a:Point, b:Point):Float {
		var dx = a.x - b.x;
		var dy = a.y - b.y;
		return Math.sqrt(dx * dx + dy * dy);
	}

	public function toString():String return "(" + x + "," + y + ")";
}
