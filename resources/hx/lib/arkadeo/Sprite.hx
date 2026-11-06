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

	// a Sprite without children as a mask: its graphics (NosuShi: the plates shown through a rectangle drawn in a Sprite,
	// the mask set before the drawing)
	override function maskShape():pixi.core.display.DisplayObject {
		return children.length == 0 ? graphics : node;
	}

	override public function contentRect():Rectangle {
		return DisplayObjectContainer.unionGraphics(super.contentRect(), gfx);
	}
}
