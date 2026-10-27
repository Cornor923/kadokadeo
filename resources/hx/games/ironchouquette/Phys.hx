package ironchouquette;

import mt.bumdum.Lib;

class Phys extends mt.bumdum.Phys {
	public var ray:Float;

	public var flash:Float;
	public var plasmaId:Int;

	public function new(mc) {
		super(mc);
		// frict = 1
		vx = 0;
		vy = 0;
	}

	public override function update() {
		// Original Phys.mt stamps with root at its pre-move position (logical x/y moved, root synced next frame)
		// and before the fade of the frame (Part.mt fades after). Here x/y write root directly and
		// mt.bumdum.Phys.update fades before returning: stamp first, from the end-of-last-frame state.
		// (Known residual: the original applied this frame's vr rotation before stamping - one frame of lag
		// on the spinning flame shots, the only plasmaId objects with vr.)
		if (plasmaId != null) {
			Cs.game.plasmaDraw(root, plasmaId);
		}

		super.update();
	}

	public override function isOut(m:Float, ?w:Float, ?h:Float) {
		return super.isOut(m, Cs.mcw, Cs.mch);
	}

	public function updateFlash() {
		if (flash != null) {
			var prc = Math.min(flash, 100);
			flash *= 0.6;
			if (flash < 2) {
				flash = null;
				prc = 0;
			}
			Col.setPercentColor(root, prc, 0xFFFFFF);
		}
	}

	public function collide(sp:Phys) {
		var d = getDist({x: sp.x, y: sp.y});
		return d < ray + sp.ray;
	}

	//
	public function fxOnde(sc) {
		var p = Cs.game.dm.attach("mcOnde", Game.DP_UNDERPARTS);
		p._x = x;
		p._y = y;
		p._xscale = sc;
		p._yscale = sc;
	}

	public function fxExplode(sc) {
		var p = Cs.game.dm.attach("mcMiniExplo", Game.DP_UNDERPARTS);
		p._x = x;
		p._y = y;
		p._xscale = sc;
		p._yscale = sc;
	}
}
