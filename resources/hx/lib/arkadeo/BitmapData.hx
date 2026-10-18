package arkadeo;

import kado.Seed;

// flash.display.BitmapData on an off-screen 2D <canvas>, shown by a Bitmap (getTexture: the canvas as a PIXI.Texture,
// uploaded again after each change). Nothing of it is read by a game: its pixels are not the same in every browser.
class BitmapData {
	public var width:Int;
	public var height:Int;
	public var transparent:Bool;

	var canvas:Dynamic;
	var ctx:Dynamic;
	var tex:Dynamic; // PIXI.Texture (made when first needed)
	var texDirty:Bool;
	var _imgData:Dynamic; // cached ImageData (dropped at each change)

	public function new(width:Int, height:Int, ?transparent:Bool = true, ?fillColor:Int = 0x0) {
		this.width = width;
		this.height = height;
		this.transparent = transparent;
		canvas = js.Browser.document.createElement("canvas");
		canvas.width = width;
		canvas.height = height;
		ctx = canvas.getContext("2d");
		texDirty = true;
		if (fillColor != 0x0 || !transparent)
			fillRect(new Rectangle(0, 0, width, height), fillColor);
	}

	public var rect(get, never):Rectangle;
	inline function get_rect():Rectangle return new Rectangle(0, 0, width, height);

	inline function dirty():Void {
		texDirty = true;
		_imgData = null;
		// a PIXI.Texture already made must be uploaded again, or the change would not show
		if (tex != null) {
			untyped tex.update();
			texDirty = false;
		}
	}

	// the whole ImageData, cached (read again after a change)
	function pixels():Dynamic {
		if (_imgData == null)
			_imgData = ctx.getImageData(0, 0, width, height);
		return _imgData;
	}

	inline function argb(c:Int):String {
		var a = transparent ? ((c >>> 24) & 0xFF) / 255 : 1.0;
		var r = (c >> 16) & 0xFF;
		var g = (c >> 8) & 0xFF;
		var b = c & 0xFF;
		return "rgba(" + r + "," + g + "," + b + "," + a + ")";
	}

	public function fillRect(r:Rectangle, color:Int):Void {
		ctx.clearRect(r.x, r.y, r.width, r.height);
		ctx.fillStyle = argb(color);
		ctx.fillRect(r.x, r.y, r.width, r.height);
		dirty();
	}

	public function getPixel(x:Int, y:Int):Int {
		var d:Dynamic = pixels().data;
		var i = (y * width + x) * 4;
		return (d[i] << 16) | (d[i + 1] << 8) | d[i + 2];
	}

	public function getPixel32(x:Int, y:Int):Int {
		var d:Dynamic = pixels().data;
		var i = (y * width + x) * 4;
		return (d[i + 3] << 24) | (d[i] << 16) | (d[i + 1] << 8) | d[i + 2];
	}

	public function setPixel(x:Int, y:Int, color:Int):Void {
		ctx.fillStyle = "rgb(" + ((color >> 16) & 0xFF) + "," + ((color >> 8) & 0xFF) + "," + (color & 0xFF) + ")";
		ctx.fillRect(x, y, 1, 1);
		dirty();
	}

	public function setPixel32(x:Int, y:Int, color:Int):Void {
		ctx.fillStyle = argb(color);
		ctx.fillRect(x, y, 1, 1);
		dirty();
	}

	// bounds of the pixels whose (ARGB & mask) == (color & mask)
	public function getColorBoundsRect(mask:Int, color:Int, ?findColor:Bool = true):Rectangle {
		var d:Dynamic = pixels().data;
		var target = color & mask;
		var minX = width, minY = height, maxX = -1, maxY = -1;
		var i = 0;
		for (y in 0...height) {
			for (x in 0...width) {
				var argb = (d[i + 3] << 24) | (d[i] << 16) | (d[i + 1] << 8) | d[i + 2];
				var match = (argb & mask) == target;
				if (findColor ? match : !match) {
					if (x < minX) minX = x;
					if (x > maxX) maxX = x;
					if (y < minY) minY = y;
					if (y > maxY) maxY = y;
				}
				i += 4;
			}
		}
		if (maxX < 0)
			return new Rectangle(0, 0, 0, 0);
		return new Rectangle(minX, minY, maxX - minX + 1, maxY - minY + 1);
	}

	// a region of a canvas / Image (atlas) copied into this BitmapData
	public function copyFromCanvas(img:Dynamic, sx:Int, sy:Int, sw:Int, sh:Int):Void {
		try {
			ctx.drawImage(img, sx, sy, sw, sh, 0, 0, sw, sh);
			dirty();
		} catch (e:Dynamic) {}
	}

	// matrix / colorTransform are TYPED (not Dynamic): the callers often write
	// `draw(src, colorTransform, blendMode)` and rely on Haxe skipping an optional argument
	// (a ColorTransform is not a Matrix: matrix is skipped). With Dynamic parameters,
	// Haxe skips nothing and the arguments shift.
	public function draw(source:Dynamic, ?matrix:Matrix, ?colorTransform:ColorTransform, ?blendMode:BlendMode, ?clipRect:Dynamic, ?smoothing:Dynamic):Void {
		try {
			var img = Std.isOfType(source, BitmapData) ? (cast source : BitmapData).canvas : source;
			ctx.save();
			// global alpha from the ColorTransform
			if (colorTransform != null) {
				var am:Dynamic = untyped colorTransform.alphaMultiplier;
				if (am != null) ctx.globalAlpha = am;
			}
			// Flash blendMode -> canvas composite operation
			if (blendMode != null) {
				var op = blendToComposite(blendMode);
				if (op != null) ctx.globalCompositeOperation = op;
			}
			ctx.drawImage(img, 0, 0);
			ctx.restore();
			dirty();
		} catch (e:Dynamic) {}
	}

	static function blendToComposite(b:BlendMode):Null<String> {
		return switch (b) {
			case OVERLAY: "overlay";
			case MULTIPLY: "multiply";
			case SCREEN: "screen";
			case ADD: "lighter";
			default: null;
		}
	}

	public function copyPixels(source:BitmapData, srcRect:Rectangle, dstPoint:Point, ?alphaBitmapData:Dynamic, ?alphaPoint:Dynamic, ?mergeAlpha:Bool):Void {
		try {
			ctx.drawImage(source.canvas, srcRect.x, srcRect.y, srcRect.width, srcRect.height, dstPoint.x, dstPoint.y, srcRect.width, srcRect.height);
			dirty();
		} catch (e:Dynamic) {}
	}

	// Approximation: grey noise in small blocks, around ~128 so that an OVERLAY / SCREEN draw stays almost neutral (a
	// black perlin would darken the veil); drawn on the random of the effects
	public function perlinNoise(baseX:Float, baseY:Float, numOctaves:Int, randomSeed:Int, stitch:Bool, fractalNoise:Bool, ?channelOptions:Int, ?grayScale:Bool, ?offsets:Dynamic):Void {
		var img = ctx.createImageData(width, height);
		var data = img.data;
		var block = 6;
		var by = 0;
		while (by < height) {
			var bx = 0;
			while (bx < width) {
				var v = 124 + Seed.randomVfx(12); // almost neutral grey (~124..136)
				var yy = by;
				while (yy < by + block && yy < height) {
					var xx = bx;
					while (xx < bx + block && xx < width) {
						var i = (yy * width + xx) * 4;
						data[i] = v;
						data[i + 1] = v;
						data[i + 2] = v;
						data[i + 3] = 255;
						xx++;
					}
					yy++;
				}
				bx += block;
			}
			by += block;
		}
		ctx.putImageData(img, 0, 0);
		dirty();
	}
	public function copyChannel(source:Dynamic, srcRect:Rectangle, dstPoint:Point, srcChannel:Int, dstChannel:Int):Void {}
	public function applyFilter(source:Dynamic, srcRect:Rectangle, dstPoint:Point, filter:Dynamic):Void {}

	public function clone():BitmapData {
		var b = new BitmapData(width, height, transparent, 0x0);
		b.ctx.drawImage(canvas, 0, 0);
		b.dirty();
		return b;
	}

	public function dispose():Void {
		canvas = null;
		ctx = null;
		tex = null;
		_imgData = null;
	}

	public function getTexture():Dynamic {
		if (tex == null)
			tex = js.Syntax.code("PIXI.Texture.from({0})", canvas);
		else if (texDirty)
			tex.update();
		texDirty = false;
		return tex;
	}

	public function getCanvas():Dynamic return canvas;

	public static function fromImage(img:Dynamic):BitmapData {
		var b = new BitmapData(img.width, img.height, true, 0x0);
		b.ctx.drawImage(img, 0, 0);
		b.dirty();
		return b;
	}
}
