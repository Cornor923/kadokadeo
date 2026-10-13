package opalusfactory;

import opalusfactory.Game.InCase;

// Coin.hx of the original: an opal (id 1..7: its hole), a nut-coin (0: blockHole) or the golden coin (8)
class Coin {
	public var id:Int;
	public var mc:MC;
	public var myCase:InCase;

	// port: DropShadowFilter of the coin (Game.setLineShadow): its distance (0: none) and the silhouette drawn under it
	public var shadowD:Int = 0;
	public var shadow:ASprite;

	public function new(i:Int, ?pm:MC) {
		id = i;
		if (pm == null)
			return;
		// (the silhouette of its drop shadow first: drawn under it, over the case)
		shadow = Game.me.newSilhouette("coinW", pm.clip);
		mc = pm.attach("coin");
		// (mc.cacheAsBitmap = true)
		mc.gotoAndStop(id + 1);
	}

	public function copy(dm:MC.Plans, ?d = 1):Coin {
		var c = new Coin(id);
		c.mc = dm.attach("coin", d);
		c.mc.gotoAndStop(id + 1);
		// (it replaces this coin, killed by the code)
		c.mc.showAtOnce();
		return c;
	}

	public function kill() {
		mc.removeMovieClip();
		if (shadow != null) {
			shadow.visible = false;
			shadowD = 0;
		}
		if (myCase != null) {
			myCase.coin = null;
		}
	}
}
