package arkadeo;

// flash.display.Shape
class Shape extends DisplayObject {
	public var graphics(default, null):Graphics;

	public function new() {
		super(new Node());
		graphics = new Graphics();
		node.addChild(graphics);
	}

	override function maskShape():pixi.core.display.DisplayObject {
		return graphics;
	}

	override public function contentRect():Rectangle {
		return DisplayObjectContainer.unionGraphics(null, graphics);
	}
}
