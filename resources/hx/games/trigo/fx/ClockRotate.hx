package trigo.fx;

import arkadeo.Clip;

// turns the hand of the clock (the `_time` clip of gfx.Clock) to `to` degrees, its frame following its angle
class ClockRotate extends mt.fx.Fx {
	var to:Float;
	var from:Float;
	var root:Clip;
	var sp:Float;

	public function new(root:Clip, to:Float, sp) {
		super();
		this.root = root;
		this.to = normalize(to);
		this.from = normalize(root._rotation);
		this.sp = sp;

		this.curve = function(c) {
			return 4 * (c * c * c) - 9 * (c * c) + 6 * c;
		}
	}

	function normalize(r:Float):Float {
		while (r < 0)
			r += 360;
		while (r >= 360)
			r -= 360;
		return r;
	}

	override public function update() {
		coef += sp;

		if (coef >= 1) {
			coef = 1;
			kill();
		}

		var v = from + (to - from) * curve(coef);
		root._rotation = v;
		root.gotoAndStop(Math.round(v / 2) + 1);
	}
}
