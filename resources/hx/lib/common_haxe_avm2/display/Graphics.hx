package common_haxe_avm2.display;

// flash.display.Graphics on PIXI.Graphics. beginFill / drawRect / lineStyle /
// moveTo / lineTo / endFill / clear / drawCircle are inherited (compatible signatures);
// only the Flash methods missing in PIXI are added.
class Graphics extends pixi.core.graphics.Graphics {
	public function new() {
		super();
	}

	// Flash drawRoundRect(x,y,w,h,ellipseW,ellipseH) -> PIXI drawRoundedRect(x,y,w,h,radius).
	public function drawRoundRect(x:Float, y:Float, w:Float, h:Float, ellipseW:Float, ?ellipseH:Float):pixi.core.graphics.Graphics {
		return drawRoundedRect(x, y, w, h, ellipseW * 0.5);
	}

	// Flash curveTo -> PIXI quadraticCurveTo.
	public function curveTo(cx:Float, cy:Float, ax:Float, ay:Float):pixi.core.graphics.Graphics {
		return quadraticCurveTo(cx, cy, ax, ay);
	}

	// Flash beginBitmapFill: a plain fill (textured fills are not implemented)
	public function beginBitmapFill(bd:BitmapData, ?matrix:common_haxe_avm2.geom.Matrix, ?repeat:Bool, ?smooth:Bool):pixi.core.graphics.Graphics {
		return beginFill(0xFFFFFF, 1);
	}
}
