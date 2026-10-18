package arkadeo;

// flash.display.BlendMode: the strings of Flash (`blendMode = "add"`, or `blendMode = ADD`), drawn with PIXI.BLEND_MODES
enum abstract BlendMode(String) from String to String {
	var NORMAL = "normal";
	var LAYER = "layer";
	var MULTIPLY = "multiply";
	var SCREEN = "screen";
	var LIGHTEN = "lighten";
	var DARKEN = "darken";
	var DIFFERENCE = "difference";
	var ADD = "add";
	var SUBTRACT = "subtract";
	var INVERT = "invert";
	var ALPHA = "alpha";
	var ERASE = "erase";
	var OVERLAY = "overlay";
	var HARDLIGHT = "hardlight";
	var SHADER = "shader";

	public static function toPixi(b:BlendMode):Int {
		return switch (b) {
			case ADD: js.Syntax.code("PIXI.BLEND_MODES.ADD");
			case MULTIPLY: js.Syntax.code("PIXI.BLEND_MODES.MULTIPLY");
			case SCREEN: js.Syntax.code("PIXI.BLEND_MODES.SCREEN");
			// OVERLAY is not a blend of the WebGL renderer of PIXI (drawn NORMAL): SCREEN, the closest real one (a game
			// that needs the real one draws it with OverlayBlend)
			case OVERLAY: js.Syntax.code("PIXI.BLEND_MODES.SCREEN");
			default: js.Syntax.code("PIXI.BLEND_MODES.NORMAL");
		}
	}

	// A PIXI container has no blend of its own: given to the drawn leaves of the tree (sprites, graphics) and to its
	// filters (the output of a filter is composed with the blend of the filter)
	public static function apply(o:Dynamic, b:Int):Void {
		untyped {
			if (o.texture != null || o.geometry != null)
				o.blendMode = b;
			if (o.filters != null)
				for (f in (o.filters : Array<Dynamic>))
					f.blendMode = b;
			if (o.children != null)
				for (c in (o.children : Array<Dynamic>))
					apply(c, b);
		}
	}
}
