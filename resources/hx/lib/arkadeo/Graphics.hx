package arkadeo;

// flash.display.Graphics on PIXI.Graphics: beginFill / drawRect / lineStyle / moveTo / lineTo / endFill / clear /
// drawCircle are PIXI's, the Flash methods missing in PIXI are added (lineStyle takes PIXI's arguments: the pixel hinting
// and scale mode of Flash have no PIXI equivalent)
class Graphics extends pixi.core.graphics.Graphics {
	static var gradients:Map<String, Dynamic> = new Map();

	public function new() {
		super();
	}

	// Flash drawRoundRect(x, y, w, h, ellipseW, ellipseH): PIXI drawRoundedRect(x, y, w, h, radius)
	public function drawRoundRect(x:Float, y:Float, w:Float, h:Float, ellipseW:Float, ?ellipseH:Float):pixi.core.graphics.Graphics {
		return drawRoundedRect(x, y, w, h, ellipseW * 0.5);
	}

	// Flash drawEllipse(x, y, width, height), the box of the ellipse: PIXI's takes its centre and its half sizes
	override public function drawEllipse(x:Float, y:Float, width:Float, height:Float):pixi.core.graphics.Graphics {
		return super.drawEllipse(x + width * 0.5, y + height * 0.5, width * 0.5, height * 0.5);
	}

	// Flash curveTo: PIXI quadraticCurveTo
	public function curveTo(cx:Float, cy:Float, ax:Float, ay:Float):pixi.core.graphics.Graphics {
		return quadraticCurveTo(cx, cy, ax, ay);
	}

	// Flash beginBitmapFill: the picture of the BitmapData (its own texture, repeated when `repeat`) placed by `matrix`
	public function beginBitmapFill(bd:BitmapData, ?matrix:Matrix, ?repeat:Bool = true, ?smooth:Bool = false):pixi.core.graphics.Graphics {
		var t:Dynamic = bd.getTexture();
		t.baseTexture.wrapMode = repeat ? js.Syntax.code("PIXI.WRAP_MODES.REPEAT") : js.Syntax.code("PIXI.WRAP_MODES.CLAMP");
		if (!smooth)
			t.baseTexture.scaleMode = 0;
		return untyped beginTextureFill({texture: t, matrix: matrix != null ? matrix.toPixi() : null});
	}

	// Flash beginGradientFill (LINEAR / RADIAL, pad spread): the gradient drawn in a texture, placed by the matrix of the
	// gradient box. PIXI repeats the texture of any fill (GraphicsGeometry): the texture spans K gradient squares each
	// way (-K x 819.2 to K x 819.2 of the gradient space), the square in its middle and the pad colour around it
	public function beginGradientFill(type:String, colors:Array<Int>, alphas:Array<Float>, ratios:Array<Int>, ?matrix:Matrix):pixi.core.graphics.Graphics {
		var N = 512, K = 4;
		var r = N / (2 * K);
		// (one texture by gradient: a game that draws the same gradient again does not make a new texture)
		var key = type + colors.join(",") + "/" + alphas.join(",") + "/" + ratios.join(",");
		var t:Dynamic = gradients.get(key);
		if (t == null) {
			var canvas:Dynamic = js.Browser.document.createElement("canvas");
			canvas.width = canvas.height = N;
			var ctx:Dynamic = canvas.getContext("2d");
			var g:Dynamic = type == "radial" ? ctx.createRadialGradient(N / 2, N / 2, 0, N / 2, N / 2, r) : ctx.createLinearGradient(N / 2 - r, 0, N / 2 + r, 0);
			for (i in 0...colors.length) {
				var c = colors[i];
				g.addColorStop(ratios[i] / 255, "rgba(" + ((c >> 16) & 0xFF) + "," + ((c >> 8) & 0xFF) + "," + (c & 0xFF) + "," + alphas[i] + ")");
			}
			ctx.fillStyle = g;
			ctx.fillRect(0, 0, N, N);
			t = js.Syntax.code("new PIXI.Texture(new PIXI.BaseTexture({0}, {scaleMode: PIXI.SCALE_MODES.LINEAR}))", canvas);
			gradients.set(key, t);
		}
		var m = new Matrix(K * 1638.4 / N, 0, 0, K * 1638.4 / N, -K * 819.2, -K * 819.2);
		if (matrix != null)
			m.concat(matrix);
		return untyped beginTextureFill({texture: t, matrix: m.toPixi()});
	}
}
