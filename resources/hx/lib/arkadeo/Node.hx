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

	// PIXI's render of an object with filters: none when the object and the reach of its filters are out of the frame it is
	// drawn into (the screen, or a texture). Its filter passes cost even when nothing is seen: the sparks of the bottles
	// all over the field of Fafi 360, half of its passes
	@:keep function renderAdvanced(renderer:Dynamic):Void {
		var filters:Array<Dynamic> = untyped this.filters;
		if (filters != null && filters.length > 0) {
			var frame:Dynamic = renderer.renderTexture.sourceFrame;
			var b:Dynamic = untyped this.getBounds(true);
			var pad = 0.0;
			for (f in filters)
				pad += f.padding;
			if (b.width > 0 && (b.x + b.width + pad < frame.x || b.y + b.height + pad < frame.y || b.x - pad > frame.x + frame.width
				|| b.y - pad > frame.y + frame.height))
				return;
		}
		js.Syntax.code("{0}.prototype.renderAdvanced.call({1}, {2})", ASprite, this, renderer);
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
