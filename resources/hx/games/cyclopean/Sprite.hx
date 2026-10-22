package cyclopean;

class Sprite {
	public var x:Float;
	public var y:Float;
	public var root:MC;

	public function new(mc:MC) {
		root = mc;
		root.obj = this;
		Cs.game.sList.push(this);
		x = 0;
		y = 0;
		root._x = -1000;
		root._y = -1000;
	}

	public function update():Void {
		root._x = x;
		root._y = y;
		placed();
	}

	public function kill():Void {
		root.removeMovieClip();
		Cs.game.sList.remove(this);
	}

	public function updatePos():Void {
		root._x = x;
		root._y = y;
		placed();
	}

	// the first position given to the clip (it waits at -1000 until then): a sprite created during the loop of
	// Game.main (sList copied before it: a bille born from an egg, the particles) gets it on the next Flash frame only,
	// and the display would slide it from -1000 across the screen. Shown there at once (display only)
	var flPlaced:Bool = false;

	inline function placed():Void {
		if (!flPlaced) {
			flPlaced = true;
			root.teleport();
		}
	}

	public function getDist(o:{x:Float, y:Float}):Float {
		var dx = o.x - x;
		var dy = o.y - y;
		return Math.sqrt(dx * dx + dy * dy);
	}

	public function getAng(o:{x:Float, y:Float}):Float {
		var dx = o.x - x;
		var dy = o.y - y;
		return Cs.atan2(dy, dx);
	}
}
