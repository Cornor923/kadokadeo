package nosushi.fx;

import arkadeo.Clip;
import arkadeo.ColorTransform;

// The blinking of a bomb / dynamite about to blow up: the `_bonus` icon of the block (a nested clip) tinted towards a
// colour and back (Col.setPercentColor(root, c * max, color) of the original)
class Radiate extends mt.fx.Fx {
	var color:Null<Int>;
	var speed:Float;
	var timer:Int;
	var max:Float;

	public var root:Clip;

	public function new(mc:Clip, sp = 0.1, color:Null<Int>, max:Float, timer:Int) {
		this.color = color;
		super();
		root = mc;
		speed = sp;
		this.max = max;
		this.timer = timer;
	}

	override function update() {
		if (!root.visible || timer-- == 0) {
			kill();
			return;
		}
		maj();
	}

	public function maj() {
		coef = (coef + speed) % 1;
		var c = 0.5 + Math.cos(curve(coef) * 6.28) * 0.5;
		setPercentColor(root, c * max, color);
	}

	override function kill() {
		// Col.setColor(root, 0, 0): no colour
		root.setColour(0xFFFFFF, 0);
		super.kill();
	}

	// mt.bumdum9.Lib.Col.setPercentColor on a nested clip
	static function setPercentColor(mc:Clip, c:Float, col:Int) {
		var cp = 1 - c;
		var ct = new ColorTransform(cp, cp, cp, 1, Std.int(c * ((col >> 16) & 0xFF)), Std.int(c * ((col >> 8) & 0xFF)),
			Std.int(c * (col & 0xFF)), 0);
		mc.setColour(ct.tint(), ct.add());
	}
}
