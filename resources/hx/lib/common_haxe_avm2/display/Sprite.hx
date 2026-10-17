package common_haxe_avm2.display;

// common_haxe_avm2: the part of the AS3 display list (flash.display / filters / geom / text) the ports of AS3 games use,
// on PixiJS, like common_haxe_avm1 for the AS1 / AS2 games (the `flash` package can't be used on the js target).
//
// flash.display.Sprite on PIXI.Container: every drawn object extends it.
// It adds the Flash names the sources use (scaleX / scaleY, graphics,
// blendMode, mouse*). The filters are inherited (filters:Array<Filter>) and our
// flash.filters.* extend PIXI.Filter: `s.filters = [new GlowFilter(...)]` type-checks.
class Sprite extends pixi.core.display.Container {
	var _graphics:Graphics;

	// Flash blendMode (enum) -> PIXI.BLEND_MODES (Int). A Container has no blend of its
	// own: it is given to the drawn leaves (Sprite = texture, Graphics = geometry) of the subtree.
	var _blend:BlendMode = BlendMode.NORMAL;
	var _blendInt:Int = 0;
	public var blendMode(get, set):BlendMode;
	inline function get_blendMode():BlendMode return _blend;
	function set_blendMode(v:BlendMode):BlendMode {
		_blend = v;
		_blendInt = toPixiBlend(v);
		applyBlend(this, _blendInt);
		return v;
	}

	static function toPixiBlend(v:BlendMode):Int {
		return switch (v) {
			case ADD: js.Syntax.code("PIXI.BLEND_MODES.ADD");
			case MULTIPLY: js.Syntax.code("PIXI.BLEND_MODES.MULTIPLY");
			case SCREEN: js.Syntax.code("PIXI.BLEND_MODES.SCREEN");
			// OVERLAY is not supported by the WebGL renderer (falls back to NORMAL): SCREEN instead
			// (a real equation that lightens), the closest one.
			case OVERLAY: js.Syntax.code("PIXI.BLEND_MODES.SCREEN");
			default: js.Syntax.code("PIXI.BLEND_MODES.NORMAL");
		}
	}

	static function applyBlend(o:Dynamic, b:Int):Void {
		untyped {
			if (o.texture != null || o.geometry != null)
				o.blendMode = b; // a Sprite leaf (texture) or a Graphics one (geometry)
			// the output of a filter is composed with the blend OF the filter, otherwise drawn
			// NORMAL (the additive blend is lost): given to the filters too
			if (o.filters != null)
				for (f in (o.filters : Array<Dynamic>))
					f.blendMode = b;
			if (o.children != null)
				for (c in (o.children : Array<Dynamic>))
					applyBlend(c, b);
		}
	}

	public function new() {
		super();
	}

	// graphics made when first used: a child PIXI.Graphics under the others, with the blend
	public var graphics(get, never):Graphics;
	function get_graphics():Graphics {
		if (_graphics == null) {
			_graphics = new Graphics();
			addChildAt(_graphics, 0);
			untyped _graphics.blendMode = _blendInt;
		}
		return _graphics;
	}

	// not inline: BSprite overrides scaleX (flip through the bitmap, positive scale of the container)
	public var scaleX(get, set):Float;
	function get_scaleX():Float return scale.x;
	function set_scaleX(v:Float):Float { scale.x = v; return v; }

	public var scaleY(get, set):Float;
	inline function get_scaleY():Float return scale.y;
	inline function set_scaleY(v:Float):Float { scale.y = v; return v; }

	public var rotationDeg(get, set):Float; // Flash rotation, in degrees
	inline function get_rotationDeg():Float return rotation * 180 / Math.PI;
	inline function set_rotationDeg(v:Float):Float { rotation = v * Math.PI / 180; return v; }

	public var mouseEnabled(get, set):Bool;
	inline function get_mouseEnabled():Bool return interactive;
	inline function set_mouseEnabled(v:Bool):Bool { interactive = v; return v; }

	public var mouseChildren(get, set):Bool;
	inline function get_mouseChildren():Bool return interactiveChildren;
	inline function set_mouseChildren(v:Bool):Bool { interactiveChildren = v; return v; }

	// buttonMode comes from pixi.interaction.InteractiveTarget (inherited)
	public var useHandCursor:Bool = false;
	public var doubleClickEnabled:Bool = false;
	public var tabEnabled:Bool = false;
}
