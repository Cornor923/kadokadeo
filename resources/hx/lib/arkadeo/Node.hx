package arkadeo;

import common_haxe_avm1.display.ASprite;

// the ASprite of a DisplayObject: interpolated between two steps of KadoKadeo like every sprite of the site, a flip
// excepted (Clip.noFlipLerp), at whole pixels when it moves in a game drawn so (Flash.roundMoving)
class Node extends ASprite {
	// shown at the last position of the game (DisplayObject.show): not rounded when it stays there
	public var exact:Bool = true;

	public function new() {
		super();
	}

	override public function updateGraphics(a:Float) {
		Clip.noFlipLerp(this);
		super.updateGraphics(a);
		if (Flash.roundMoving) {
			var p = _prevState, c = _curState;
			if (!(exact && p.x == c.x && p.y == c.y)) {
				position.x = Math.round(position.x);
				position.y = Math.round(position.y);
			}
		}
	}
}
