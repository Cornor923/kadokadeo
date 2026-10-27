package mt.bumdum;

import common_haxe_avm1.display.ASprite;
import mt.bumdum.Lib;

class Sprite {
	static public var spriteList:Array<Sprite> = [];
	static var updateSnapshot:Array<Sprite> = [];
	static var updateSnapshotLen:Int = 0;
	static var toAdd:Array<Sprite> = [];
	static var toRemove:Array<Sprite> = [];
	static var isIterating:Bool = false;

	public var root:ASprite;

	public var scale(get, set):Float;
	public var x(get, set):Float;
	public var y(get, set):Float;

	public function new(root:ASprite) {
		this.root = root;
		if (root != null) {
			root.obj = this;
			this.scale = 100;
		}
		register(this);

		if (this.root != null && this.root._x == 0 && this.root._y == 0) {
			this.root._x = -100;
			this.root._y = -100;
		}
	}

	public function get_x() {
		return this.root._x;
	}

	public function set_x(val:Float) {
		this.root._x = val;
		return val;
	}

	public function get_y() {
		return this.root._y;
	}

	public function set_y(val:Float) {
		this.root._y = val;
		return val;
	}

	public function get_scale() {
		return this.root._xscale;
	}

	public function set_scale(val:Float) {
		this.root._xscale = val;
		this.root._yscale = val;
		return val;
	}

	public function updatePos() {
		this.root._x = this.x;
		this.root._y = this.y;
	}

	public function update() {
		this.updatePos();
	}

	public function setScale(scale:Float) {
		this.scale = scale;
	}

	public function kill() {
		if (this.root != null) {
			this.root.removeMovieClip();
		}
		unregister(this);
	}

	static function register(sp:Sprite):Void {
		if (isIterating) {
			if (toRemove.remove(sp))
				return;
			if (toAdd.indexOf(sp) < 0)
				toAdd.push(sp);
			return;
		}
		spriteList.push(sp);
	}

	static function unregister(sp:Sprite):Void {
		if (isIterating) {
			if (toAdd.remove(sp))
				return;
			if (toRemove.indexOf(sp) < 0)
				toRemove.push(sp);
			return;
		}
		spriteList.remove(sp);
	}

	public static function updateAll():Void {
		isIterating = true;

		var src = spriteList;
		var count = src.length;
		for (i in 0...count) {
			updateSnapshot[i] = src[i];
		}
		for (i in count...updateSnapshotLen) {
			updateSnapshot[i] = null;
		}
		updateSnapshotLen = count;

		for (i in 0...count) {
			var sp = updateSnapshot[i];
			if (sp != null)
				sp.update();
		}

		isIterating = false;

		while (toRemove.length > 0) {
			var removed = toRemove.pop();
			if (removed != null)
				spriteList.remove(removed);
		}
		while (toAdd.length > 0) {
			var added = toAdd.pop();
			if (added != null)
				spriteList.push(added);
		}
	}

	public static function clearAll():Void {
		spriteList = [];
		updateSnapshot = [];
		updateSnapshotLen = 0;
		toAdd = [];
		toRemove = [];
		isIterating = false;
	}

	public function getDist(point:Point) {
		var x = point.x - this.x;
		var y = point.y - this.y;
		return Math.sqrt(x * x + y * y);
	}

	public function toward(arg0:Point, amount:Float, arg2:Int = 1) {
		var v5 = arg0.x - this.x;
		var v6 = arg0.y - this.y;
		this.x += Num.mm(-arg2, v5 * amount, arg2);
		this.y += Num.mm(-arg2, v6 * amount, arg2);
	};

	public function getAng(point:Point) {
		return Math.atan2(point.y - this.y, point.x - this.x);
	}

	public function isOut(m:Float, ?w:Float, ?h:Float) {
		if (Math.isNaN(x) || Math.isNaN(y)) {
			return true;
		}
		return (x < -m || x > w + m || y < -m || y > h + m);
	}
}
