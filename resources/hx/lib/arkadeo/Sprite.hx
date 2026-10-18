package arkadeo;

// flash.display.Sprite (its graphics are drawn under its children)
class Sprite extends DisplayObjectContainer {
	public var graphics(get, never):Graphics;

	var gfx:Graphics = null;

	// (node: a node made elsewhere, a plane of DepthManager)
	public function new(?node:common_haxe_avm1.display.ASprite) {
		super(node != null ? node : new Node());
	}

	function get_graphics():Graphics {
		if (gfx == null) {
			gfx = new Graphics();
			untyped gfx.blendMode = pixiBlend();
			node.addChildAt(gfx, 0);
			base = 1;
		}
		return gfx;
	}

	override public function contentRect():Rectangle {
		return DisplayObjectContainer.unionGraphics(super.contentRect(), gfx);
	}
}
