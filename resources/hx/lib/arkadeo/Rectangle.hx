package arkadeo;

// flash.geom.Rectangle (getRect, intersects)
class Rectangle {
	public var x:Float;
	public var y:Float;
	public var width:Float;
	public var height:Float;

	public function new(x:Float = 0, y:Float = 0, w:Float = 0, h:Float = 0) {
		this.x = x;
		this.y = y;
		width = w;
		height = h;
	}

	public var left(get, never):Float;
	public var top(get, never):Float;
	public var right(get, never):Float;
	public var bottom(get, never):Float;

	inline function get_left()
		return x;

	inline function get_top()
		return y;

	inline function get_right()
		return x + width;

	inline function get_bottom()
		return y + height;

	public function clone():Rectangle {
		return new Rectangle(x, y, width, height);
	}

	public function contains(px:Float, py:Float):Bool {
		return px >= x && px < x + width && py >= y && py < y + height;
	}

	public function toString():String {
		return "[" + x + "," + y + " " + width + "x" + height + "]";
	}

	// (Flash: false when one of them is empty)
	public function intersects(r:Rectangle):Bool {
		if (width <= 0 || height <= 0 || r.width <= 0 || r.height <= 0)
			return false;
		return x < r.x + r.width && r.x < x + width && y < r.y + r.height && r.y < y + height;
	}
}
