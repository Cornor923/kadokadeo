package mel;

// DefaultImport.hx of the original: the types shared by the game

enum NMY_TYPE {
	NT_HANDLE;
	NT_BAD_HANDLE;
	NT_SWARM;

	NT_TORCH;
	NT_BLADE;

	NT_MASSIVE;
}

enum CharPowers {
	CP_DOUBLE_JUMP;
	CP_WALL_STICK;
	CP_SUPER_JUMP;

	CP_KICK;
	CP_CANCEL;
}

typedef RectI = {x:Int, y:Int, width:Int, height:Int};

enum LD_PATTERN {
	LDPage(p:Int);
	LDGen(nb:Int);
}

enum Restager {
	RandPlatform(seed:Int);
	FixedPlatform(cx:Int, cy:Int);
	Fixed;
}

// flash.geom.Rectangle (getRect, intersects)
class Rect {
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

	// (Flash: false when one of them is empty)
	public function intersects(r:Rect):Bool {
		if (width <= 0 || height <= 0 || r.width <= 0 || r.height <= 0)
			return false;
		return x < r.x + r.width && r.x < x + width && y < r.y + r.height && r.y < y + height;
	}
}
