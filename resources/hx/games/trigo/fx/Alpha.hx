package trigo.fx;

import arkadeo.Clip;

// fades the alpha of a clip to `to` (the original's on a Sprite: in the League it only fades named children of the
// timelines, the _hili of a block and the _txt of the combo meter, nested clips)
class Alpha extends mt.fx.Fx {
	var mc:Clip;
	var start:Float;
	var end:Float;
	var sp:Float;

	public function new(mc:Clip, to:Float, sp = 0.1) {
		super();
		this.mc = mc;
		this.start = mc._alpha / 100;
		this.end = to;
		this.sp = sp;
	}

	override function update() {
		super.update();
		coef = Math.min(coef + sp, 1);
		var c = curve(coef);

		mc._alpha = (start + (end - start) * c) * 100;

		if (coef == 1)
			kill();
	}
}
