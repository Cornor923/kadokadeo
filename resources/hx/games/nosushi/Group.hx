package nosushi;

import nosushi.Game;

// Foods of the same kind next to each other (Group of the original): lit up under the mouse, taken away by a click.
class Group {
	public var arr:Array<Block>;
	public var id:Int;

	public function new(id:Int) {
		arr = [];
		this.id = id;
	}

	function clickable() {
		return arr.length > 1;
	}

	public function onOver() {
		if (!clickable())
			return;

		var i:Int = id;

		var m = null;
		switch (i) {
			case 0:
				m = new mt.flash.ColorMatrix();
				m.adjustBrightness(0.05);
				m.adjustContrast(0.2);
				m.adjustSaturation(0);
			case 1:
				m = new mt.flash.ColorMatrix();
				m.adjustBrightness(0.05);
				m.adjustContrast(0.2);
				m.adjustSaturation(0.1);
			case 2:
				m = new mt.flash.ColorMatrix();
				m.adjustBrightness(0.2);
				m.adjustContrast(0);
				m.adjustSaturation(0.05);
		}

		for (b in arr) {
			var sp:DisplayObject = b.bmp.visible ? b.bmp : b.mc;
			sp.y -= 2;
			sp.filters = [new ColorMatrixFilter(m.matrix)];
		}

		// (isContractId: the gauge of the order of the LvUP)
	}

	public function onOut() {
		if (!clickable())
			return;

		for (b in arr) {
			var sp:DisplayObject = (b.bmp != null && b.bmp.visible) ? b.bmp : b.mc;
			if (sp != null) {
				sp.y += 2;
				sp.filters = [];
			}
		}
	}

	// the orders of the LvUP: none in the League (contractSteps = 0)
	function isContractId() {
		return false;
	}

	// (GM_LEAGUE: every group counts)
	function isValid() {
		return true;
	}

	function calcPts() {
		var m = 1;
		for (b in arr) {
			switch (b.bonus) {
				case B_X2:
					m *= 2;
				default:
			}
		}
		return Math.round(arr.length * (arr.length - 1) / 2 * Game.PTS * m);
	}

	public function onClick() {
		if (!clickable())
			return;

		if (Game.me.leftPlay <= 0 || Game.me.step != S_Play)
			return;

		Game.me.leftPlay--;
		Game.me.updateMoves();

		var s = calcPts();

		// (isContractId: never in the League; !isValid: the plate broken in pieces, never in the League either)
		var isValid = isValid();
		Game.me.addScore(s);

		var cp = Game.me.curPlate;
		cp.gotoAndStop(id + 2);
		var x = new nosushi.fx.Play(cp.getClip("_order"));
		x.onFinish = function() {
			if (isValid) {
				var f = new mt.fx.Tween(cp, 620, cp.y);
				f.onFinish = function() {
					cp.parent.removeChild(cp);
				};
				new mt.fx.Sleep(f, null, 13);
			}
		};
		new mt.fx.Sleep(x, null, 20);
		Game.me.addFx(new nosushi.fx.Sleep(33));

		var count = arr.length;
		var pts = Math.round(s / count);
		for (b in arr)
			b.exec(true, isValid, arr.length, pts);

		Game.me.setStep(S_Break);
	}
}
