package arkadeo;

// flash.display.Graphics on PIXI.Graphics: beginFill / drawRect / lineStyle / moveTo / lineTo / endFill / clear /
// drawCircle are PIXI's, the Flash methods missing in PIXI are added
class Graphics extends pixi.core.graphics.Graphics {
	public function new() {
		super();
	}

	// Flash drawRoundRect(x, y, w, h, ellipseW, ellipseH): PIXI drawRoundedRect(x, y, w, h, radius)
	public function drawRoundRect(x:Float, y:Float, w:Float, h:Float, ellipseW:Float, ?ellipseH:Float):pixi.core.graphics.Graphics {
		return drawRoundedRect(x, y, w, h, ellipseW * 0.5);
	}

	// Flash curveTo: PIXI quadraticCurveTo
	public function curveTo(cx:Float, cy:Float, ax:Float, ay:Float):pixi.core.graphics.Graphics {
		return quadraticCurveTo(cx, cy, ax, ay);
	}

	// Flash beginBitmapFill: a plain fill (textured fills are not drawn)
	public function beginBitmapFill(bd:BitmapData, ?matrix:Matrix, ?repeat:Bool, ?smooth:Bool):pixi.core.graphics.Graphics {
		return beginFill(0xFFFFFF, 1);
	}
}
