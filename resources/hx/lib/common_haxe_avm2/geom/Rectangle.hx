package common_haxe_avm2.geom;

// flash.geom.Rectangle (a value).
class Rectangle {
	public var x:Float;
	public var y:Float;
	public var width:Float;
	public var height:Float;

	public function new(?x:Float = 0, ?y:Float = 0, ?width:Float = 0, ?height:Float = 0) {
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
	}

	public var left(get, never):Float;
	inline function get_left() return x;
	public var top(get, never):Float;
	inline function get_top() return y;
	public var right(get, never):Float;
	inline function get_right() return x + width;
	public var bottom(get, never):Float;
	inline function get_bottom() return y + height;

	public var topLeft(get, never):Point;
	inline function get_topLeft() return new Point(x, y);
	public var bottomRight(get, never):Point;
	inline function get_bottomRight() return new Point(x + width, y + height);

	public function clone():Rectangle return new Rectangle(x, y, width, height);

	public function contains(px:Float, py:Float):Bool {
		return px >= x && px < x + width && py >= y && py < y + height;
	}

	public function toString():String return "[" + x + "," + y + " " + width + "x" + height + "]";
}
