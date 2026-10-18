package brutalteenagecrisis;

import mt.deepnight.slb.BSprite;

// Hud: hearts (credits) + phase icon with its reload gauge. The lit icon (phaseOn) is
// revealed from the bottom up by a rectangular mask over the grey one (phaseOff).
// (Arkadeo HTML5 port)
// Pitfall: the mask is set once and never removed (mask = null would set
// renderable = true: a white square); only its rectangle is drawn again every frame.
class Hud {
	var mode:Mode;
	public var wrapper:Sprite;
	var credits:Array<BSprite>;
	var phaseOn:BSprite;
	var phaseOff:BSprite;
	var phaseGauge:Shape;

	public function new() {
		mode = Mode.ME;
		credits = [];
		wrapper = new Sprite();
		mode.dm.add(wrapper, Const.DP_INTERF);

		if (mode.tiles.exists("icon_phantom")) {
			phaseOff = mode.tiles.get("icon_phantom", 0); // grey ghost (base)
			wrapper.addChild(phaseOff);
			phaseOff.alpha = 0.6;
			phaseOn = mode.tiles.get("icon_phantom", 2); // lit ghost (filled)
			wrapper.addChild(phaseOn);
			phaseOff.x = phaseOn.x = Const.WID - 40;
			phaseOff.y = phaseOn.y = 6;

			phaseGauge = new Shape();
			wrapper.addChild(phaseGauge);
			phaseOn.mask = phaseGauge; // permanent mask (reveals phaseOn from the bottom up), never drawn
		}
	}

	public function refresh():Void {
		if (mode.hero == null) return;
		for (s in credits)
			s.dispose();
		credits = [];
		if (!mode.tiles.exists("heart")) return;
		for (i in 0...mode.hero.credits) {
			var s = mode.tiles.get("heart", 0);
			wrapper.addChild(s);
			s.setCenter(0, 0);
			s.x = 5 + i * (s.width + 1);
			s.y = 5;
			credits.push(s);
		}
	}

	public function loseCreditFx():Void {
		if (credits.length == 0) return;
		var s = credits[credits.length - 1];
		mode.fx.creditLoss(s.x + s.width * 0.5, s.y + s.height * 0.5);
	}

	public function update():Void {
		if (phaseOn == null || mode.hero == null) return;
		var t = mode.hero.cd.getFloat("phaseLock");

		// While reloading: the "charging" glyph (frame 1) revealed from the bottom up; the
		// filled glyph (frame 2) only shows at 100 %. The grey base (phaseOff) is only
		// visible while reloading. The icon is 40x40: the mask must cover all of it.
		phaseGauge.graphics.clear();
		phaseGauge.graphics.beginFill(0xFFFFFF, 1);
		if (t > 0) {
			phaseOff.visible = true;
			phaseOn.visible = true;
			phaseOn.setFrame(1); // the "charging" glyph, NOT the filled one
			phaseOn.alpha = 0.7;
			var f = 1 - t / Const.PHASE_CD;
			if (f < 0) f = 0;
			else if (f > 1) f = 1;
			var sweep = 28.0; // height of the glyph
			var inset = 6.0; // inset in the 40 px box
			var h = sweep * f;
			phaseGauge.graphics.drawRect(phaseOn.x, phaseOn.y + inset + (sweep - h), phaseOn.width, h);
		} else {
			// 100 % only: FILLED ghost (frame 2), whole icon, base hidden
			phaseOff.visible = false;
			phaseOn.visible = true;
			phaseOn.setFrame(2);
			phaseOn.alpha = 1;
			phaseGauge.graphics.drawRect(phaseOn.x, phaseOn.y, phaseOn.width, phaseOn.height);
		}
		phaseGauge.graphics.endFill();
	}
}
