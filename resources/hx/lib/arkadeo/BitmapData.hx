package arkadeo;

import kado.Seed;
import js.lib.Int32Array;

// flash.display.BitmapData, in one of three places:
//
// - integer pixels (ARGB in an Int32Array) while it is only filled, set, copied from other integer pictures, thresholded
//   or flood filled: exact and the same in every browser, the pixels a game may read (Green Witch: its dungeon analysed
//   from the plan of a level: walls, rooms, what can be reached). The canvas that shows it is written from them once per
//   step, when it changed (Flash.display -> flushAll: a mini map of a thousand setPixel is one upload);
// - an off-screen 2D <canvas> once something only a canvas draws went in (draw of a picture, a canvas or an Image):
//   its pixels are not the same in every browser, nothing of it may be read by a game;
// - a PIXI.RenderTexture once something only the GPU can draw went in (Fafi 360: the stadium composed of the clips of the
//   SWF, the marks of the explosions on the ground, mt.deepnight.Lib.flatten): draw of a display object (the matrix,
//   colour transform and blend mode of draw; the own transform of the object ignored, like Flash), colorTransform,
//   applyFilter, the fills / copies after it. A picture drawn on the GPU has no pixels to read (getPixel reads what the
//   canvas had before).
//
// fromTexture: a picture of a sheet (an atlas of the original), read only: copied from, cut into textures.
class BitmapData {
	// the scale mode of the RenderTextures (Flash.reset: smoothed; 0 for the pixel art games)
	public static var gpuScaleMode:Int = 1;

	public var width:Int;
	public var height:Int;
	public var transparent:Bool;

	var canvas:Dynamic;
	var ctx:Dynamic;
	var tex:Dynamic; // PIXI.Texture (made when first needed)
	var texDirty:Bool;
	var _imgData:Dynamic; // cached ImageData of the canvas (dropped at each change)

	// the exact pixels (ARGB), null once a canvas or GPU drawing made them unknown; canvasStale: changed since the canvas
	// was last written from them
	var ints:Int32Array = null;
	var canvasStale:Bool = false;

	// the RenderTexture once the GPU drew in it, and the Bitmaps that show this BitmapData (given the RenderTexture)
	var rt:Dynamic = null;
	var users:Array<Bitmap> = [];
	// the canvas only holds the colour it was created with (moved to the GPU without uploading it)
	var plain:Bool = true;
	var fill0:Int;
	// a texture of a sheet this picture is (fromTexture), until something is drawn into it
	var texSrc:Dynamic = null;
	// pictures of sheets waiting to be drawn into the RenderTexture in one render (drawFrame: the tiles of a level)
	var queue:Array<Dynamic> = null;
	var queueSources:Array<BitmapData> = null;

	public function new(width:Int, height:Int, ?transparent:Bool = true, ?fillColor:Int = 0x0) {
		this.width = width;
		this.height = height;
		this.transparent = transparent;
		canvas = js.Browser.document.createElement("canvas");
		canvas.width = width;
		canvas.height = height;
		ctx = canvas.getContext("2d");
		texDirty = true;
		ints = new Int32Array(width * height);
		var c = opaque(fillColor);
		if (c != 0) {
			ints.fill(c);
			canvasStale = true;
		}
		plain = true;
		fill0 = fillColor;
	}

	// the colour a pixel of this picture gets (Flash: a picture that is not transparent has no alpha)
	inline function opaque(c:Int):Int {
		return transparent ? c : (c | 0xFF000000);
	}

	public var rect(get, never):Rectangle;
	inline function get_rect():Rectangle return new Rectangle(0, 0, width, height);

	// (Flash: the Bitmaps not updated until unlock; here the changes are shown once per step anyway)
	public inline function lock():Void {}

	public inline function unlock(?changeRect:Rectangle):Void {}

	// ---------------------------------------------------------------- uploads: once per step
	static var pending:Array<BitmapData> = [];

	// the integer pixels or the canvas changed: the texture that shows them is written again at the next flushAll
	inline function dirty():Void {
		plain = false;
		texDirty = true;
		_imgData = null;
		if (tex != null && pending.indexOf(this) < 0)
			pending.push(this);
	}

	// (Flash.display, once per step) the changed pictures shown again: their canvas written from their integer pixels, their
	// texture uploaded
	public static function flushAll() {
		if (pending.length == 0)
			return;
		var p = pending;
		pending = [];
		for (b in p) {
			b.flushQueue();
			if (b.tex != null && b.rt == null)
				b.getTexture();
		}
	}

	// the canvas written from the integer pixels (premultiplied by the canvas: a transparent pixel loses its colour there,
	// not in ints)
	function syncCanvas() {
		if (ints == null || !canvasStale || ctx == null)
			return;
		canvasStale = false;
		var img = ctx.createImageData(width, height);
		var d:Dynamic = img.data;
		var n = width * height;
		for (i in 0...n) {
			var c = ints[i];
			var j = i * 4;
			d[j] = (c >> 16) & 0xFF;
			d[j + 1] = (c >> 8) & 0xFF;
			d[j + 2] = c & 0xFF;
			d[j + 3] = transparent ? (c >>> 24) & 0xFF : 0xFF;
		}
		ctx.putImageData(img, 0, 0);
	}

	// the canvas is drawn by the canvas from now on: its pixels are no longer exact
	function toCanvas() {
		syncCanvas();
		ints = null;
		canvasStale = false;
	}

	// the whole ImageData, cached (read again after a change)
	function pixels():Dynamic {
		if (_imgData == null)
			_imgData = ctx.getImageData(0, 0, width, height);
		return _imgData;
	}

	// pixel (x, y) as ARGB (exact pixels, or the canvas)
	inline function argbAt(x:Int, y:Int):Int {
		if (ints != null)
			return ints[y * width + x];
		var d:Dynamic = pixels().data;
		var i = (y * width + x) * 4;
		return (d[i + 3] << 24) | (d[i] << 16) | (d[i + 1] << 8) | d[i + 2];
	}

	// every pixel as ARGB (the exact ones, or read from the canvas)
	function argbArray():Int32Array {
		if (ints != null)
			return ints;
		var a = new Int32Array(width * height);
		var d:Dynamic = pixels().data;
		for (i in 0...width * height) {
			var j = i * 4;
			a[i] = (d[j + 3] << 24) | (d[j] << 16) | (d[j + 1] << 8) | d[j + 2];
		}
		return a;
	}

	inline function argb(c:Int):String {
		var a = transparent ? ((c >>> 24) & 0xFF) / 255 : 1.0;
		var r = (c >> 16) & 0xFF;
		var g = (c >> 8) & 0xFF;
		var b = c & 0xFF;
		return "rgba(" + r + "," + g + "," + b + "," + a + ")";
	}

	// (x0, y0, x1, y1) of r in the picture, whole pixels
	inline function clip(r:Rectangle):Array<Int> {
		var x0 = Std.int(Math.max(0, Math.round(r.x)));
		var y0 = Std.int(Math.max(0, Math.round(r.y)));
		var x1 = Std.int(Math.min(width, Math.round(r.x + r.width)));
		var y1 = Std.int(Math.min(height, Math.round(r.y + r.height)));
		return [x0, y0, x1, y1];
	}

	// ---------------------------------------------------------------- pixels
	public function fillRect(r:Rectangle, color:Int):Void {
		flushQueues();
		if (rt != null || texSrc != null) {
			gpuFill(r, color);
			return;
		}
		if (ints != null) {
			var b = clip(r);
			var c = opaque(color);
			for (y in b[1]...b[3]) {
				var i = y * width;
				ints.fill(c, i + b[0], i + b[2]);
			}
			canvasStale = true;
			dirty();
			return;
		}
		ctx.clearRect(r.x, r.y, r.width, r.height);
		ctx.fillStyle = argb(color);
		ctx.fillRect(r.x, r.y, r.width, r.height);
		dirty();
	}

	public function getPixel(x:Int, y:Int):Int {
		if (x < 0 || y < 0 || x >= width || y >= height)
			return 0;
		return argbAt(x, y) & 0xFFFFFF;
	}

	public function getPixel32(x:Int, y:Int):Int {
		if (x < 0 || y < 0 || x >= width || y >= height)
			return 0;
		return argbAt(x, y);
	}

	// (Flash: the alpha of the pixel is kept)
	public function setPixel(x:Int, y:Int, color:Int):Void {
		flushQueues();
		if (rt != null || texSrc != null) {
			gpuFill(new Rectangle(x, y, 1, 1), 0xFF000000 | color);
			return;
		}
		if (x < 0 || y < 0 || x >= width || y >= height)
			return;
		if (ints != null) {
			var i = y * width + x;
			ints[i] = opaque((ints[i] & 0xFF000000) | (color & 0xFFFFFF));
			canvasStale = true;
			dirty();
			return;
		}
		ctx.fillStyle = "rgb(" + ((color >> 16) & 0xFF) + "," + ((color >> 8) & 0xFF) + "," + (color & 0xFF) + ")";
		ctx.fillRect(x, y, 1, 1);
		dirty();
	}

	public function setPixel32(x:Int, y:Int, color:Int):Void {
		flushQueues();
		if (rt != null || texSrc != null) {
			gpuFill(new Rectangle(x, y, 1, 1), color);
			return;
		}
		if (x < 0 || y < 0 || x >= width || y >= height)
			return;
		if (ints != null) {
			ints[y * width + x] = opaque(color);
			canvasStale = true;
			dirty();
			return;
		}
		ctx.clearRect(x, y, 1, 1);
		ctx.fillStyle = argb(color);
		ctx.fillRect(x, y, 1, 1);
		dirty();
	}

	// bounds of the pixels whose (ARGB & mask) == (color & mask)
	public function getColorBoundsRect(mask:Int, color:Int, ?findColor:Bool = true):Rectangle {
		var a = argbArray();
		var target = color & mask;
		var minX = width, minY = height, maxX = -1, maxY = -1;
		var i = 0;
		for (y in 0...height) {
			for (x in 0...width) {
				var match = (a[i] & mask) == target;
				if (findColor ? match : !match) {
					if (x < minX) minX = x;
					if (x > maxX) maxX = x;
					if (y < minY) minY = y;
					if (y > maxY) maxY = y;
				}
				i++;
			}
		}
		if (maxX < 0)
			return new Rectangle(0, 0, 0, 0);
		return new Rectangle(minX, minY, maxX - minX + 1, maxY - minY + 1);
	}

	// Flash threshold: the pixels of srcRect of source whose (ARGB & mask) `operation` (threshold & mask) (unsigned) get
	// `color` at destPoint, the others the source pixel when copySource; the number of pixels changed
	public function threshold(source:BitmapData, srcRect:Rectangle, destPoint:Point, operation:String, threshold:Int, ?color:Int = 0,
			?mask:Int = 0xFFFFFFFF, ?copySource:Bool = false):Int {
		var src = source.argbArray();
		if (source == this && ints != null)
			src = src.slice(0);
		var dst = writable();
		var th = (threshold & mask) >>> 0;
		var c = opaque(color);
		var hits = 0;
		var sx0 = Std.int(srcRect.x), sy0 = Std.int(srcRect.y);
		var dx0 = Std.int(destPoint.x), dy0 = Std.int(destPoint.y);
		for (yy in 0...Std.int(srcRect.height)) {
			var sy = sy0 + yy, dy = dy0 + yy;
			if (sy < 0 || sy >= source.height || dy < 0 || dy >= height)
				continue;
			for (xx in 0...Std.int(srcRect.width)) {
				var sx = sx0 + xx, dx = dx0 + xx;
				if (sx < 0 || sx >= source.width || dx < 0 || dx >= width)
					continue;
				var p = src[sy * source.width + sx];
				var v = (p & mask) >>> 0;
				var cond = switch (operation) {
					case "<": v < th;
					case "<=": v <= th;
					case ">": v > th;
					case ">=": v >= th;
					case "==": v == th;
					case "!=": v != th;
					default: false;
				}
				if (cond) {
					dst[dy * width + dx] = c;
					hits++;
				} else if (copySource)
					dst[dy * width + dx] = opaque(p);
			}
		}
		written(dst);
		return hits;
	}

	// Flash floodFill: the 4-connected area of the colour (ARGB) of (x, y) gets `color`
	public function floodFill(x:Int, y:Int, color:Int):Void {
		if (x < 0 || y < 0 || x >= width || y >= height)
			return;
		var a = writable();
		var target = a[y * width + x];
		var c = opaque(color);
		if (target == c)
			return;
		var stack = [y * width + x];
		while (stack.length > 0) {
			var i = stack.pop();
			if (a[i] != target)
				continue;
			a[i] = c;
			var px = i % width;
			if (px > 0) stack.push(i - 1);
			if (px < width - 1) stack.push(i + 1);
			if (i >= width) stack.push(i - width);
			if (i < (height - 1) * width) stack.push(i + width);
		}
		written(a);
	}

	// the integer pixels to change (read from the canvas when they were lost: written back to it by written())
	function writable():Int32Array {
		if (rt != null || texSrc != null)
			throw "BitmapData: pixel operation on a picture drawn on the GPU";
		return ints != null ? ints : argbArray();
	}

	function written(a:Int32Array) {
		if (ints != null) {
			canvasStale = true;
			dirty();
			return;
		}
		// (a picture of the canvas: its pixels put back)
		var saved = ints;
		ints = a;
		canvasStale = true;
		syncCanvas();
		ints = saved;
		dirty();
	}

	// the picture mirrored (mt.deepnight.Lib.flipBitmap)
	public function flip(flipX:Bool, flipY:Bool) {
		flushQueues();
		if (!flipX && !flipY)
			return;
		if (ints != null) {
			var src = ints.slice(0);
			for (y in 0...height)
				for (x in 0...width)
					ints[y * width + x] = src[(flipY ? height - 1 - y : y) * width + (flipX ? width - 1 - x : x)];
			canvasStale = true;
			dirty();
			return;
		}
		var m = new Matrix(flipX ? -1 : 1, 0, 0, flipY ? -1 : 1, flipX ? width : 0, flipY ? height : 0);
		var c = clone();
		fillRect(rect, 0);
		draw(c, m);
		c.dispose();
	}

	// a region of a canvas / Image (atlas) copied into this BitmapData
	public function copyFromCanvas(img:Dynamic, sx:Int, sy:Int, sw:Int, sh:Int):Void {
		flushQueues();
		try {
			toCanvas();
			ctx.drawImage(img, sx, sy, sw, sh, 0, 0, sw, sh);
			dirty();
		} catch (e:Dynamic) {}
	}

	// matrix / colorTransform are TYPED (not Dynamic): the callers often write
	// `draw(src, colorTransform, blendMode)` and rely on Haxe skipping an optional argument
	// (a ColorTransform is not a Matrix: matrix is skipped). With Dynamic parameters,
	// Haxe skips nothing and the arguments shift.
	public function draw(source:Dynamic, ?matrix:Matrix, ?colorTransform:ColorTransform, ?blendMode:BlendMode, ?clipRect:Dynamic, ?smoothing:Dynamic):Void {
		flushQueues();
		var src:BitmapData = Std.downcast(source, BitmapData);
		if (Std.isOfType(source, DisplayObject) || rt != null || texSrc != null || (src != null && (src.rt != null || src.texSrc != null))) {
			if (src != null)
				drawTexture(src.getTexture(), matrix, colorTransform, blendMode);
			else if (Std.isOfType(source, DisplayObject))
				drawObject(source, matrix, colorTransform, blendMode);
			return;
		}
		try {
			toCanvas();
			if (src != null)
				src.syncCanvas();
			var img = src != null ? src.canvas : source;
			ctx.save();
			if (matrix != null)
				ctx.setTransform(matrix.a, matrix.b, matrix.c, matrix.d, matrix.tx, matrix.ty);
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
			case ERASE: "destination-out";
			default: null;
		}
	}

	// Flash copyPixels: srcRect of source at dstPoint, replacing the pixels (mergeAlpha: over them), its alpha multiplied
	// by the one of alphaBitmapData (at alphaPoint) when given. alphaBitmapData / alphaPoint are TYPED: the callers skip
	// them (`copyPixels(src, r, pt, true)`: mergeAlpha)
	public function copyPixels(source:BitmapData, srcRect:Rectangle, dstPoint:Point, ?alphaBitmapData:BitmapData, ?alphaPoint:Point,
			?mergeAlpha:Bool):Void {
		var merge = mergeAlpha == true;
		// over the pixels, from a picture on the GPU: drawn with the other ones in one render, like drawFrame (the blood of a
		// fight on the ground of Green Witch)
		if (merge && alphaBitmapData == null && source != this && (source.rt != null || source.texSrc != null)) {
			var t:Dynamic = source.getTexture();
			queueSprite(subTexture(t, srcRect), dstPoint.x, dstPoint.y, source);
			return;
		}
		flushQueues();
		if (ints != null && source.ints != null && (alphaBitmapData == null || alphaBitmapData.ints != null)) {
			cpuCopy(source, srcRect, dstPoint, alphaBitmapData, alphaPoint, merge);
			return;
		}
		if (rt != null || texSrc != null || source.rt != null || source.texSrc != null || alphaBitmapData != null) {
			var r = new Rectangle(dstPoint.x, dstPoint.y, srcRect.width, srcRect.height);
			toGpu();
			// (the pixels to put taken first: the source or the alpha picture may be this one, cleared below)
			var piece:Dynamic = null;
			if (alphaBitmapData != null)
				piece = maskedPiece(source, srcRect, alphaBitmapData, alphaPoint);
			else if (source == this)
				piece = regionCopy(srcRect);
			if (!merge)
				gpuFill(r, 0);
			if (piece != null) {
				var s = new pixi.core.sprites.Sprite(piece);
				s.x = dstPoint.x;
				s.y = dstPoint.y;
				renderer().render(s, {renderTexture: rt, clear: false});
				s.destroy();
				piece.destroy(true);
			} else
				drawRegion(source.getTexture(), srcRect, dstPoint, null, null);
			return;
		}
		try {
			toCanvas();
			source.syncCanvas();
			if (!merge)
				ctx.clearRect(dstPoint.x, dstPoint.y, srcRect.width, srcRect.height);
			ctx.drawImage(source.canvas, srcRect.x, srcRect.y, srcRect.width, srcRect.height, dstPoint.x, dstPoint.y, srcRect.width, srcRect.height);
			dirty();
		} catch (e:Dynamic) {}
	}

	// copyPixels between exact pictures
	function cpuCopy(source:BitmapData, srcRect:Rectangle, dstPoint:Point, alphaBd:BitmapData, alphaPoint:Point, merge:Bool) {
		var src = source == this ? ints.slice(0) : source.ints;
		var sx0 = Std.int(srcRect.x), sy0 = Std.int(srcRect.y);
		var dx0 = Std.int(dstPoint.x), dy0 = Std.int(dstPoint.y);
		var ax0 = alphaPoint != null ? Std.int(alphaPoint.x) : 0, ay0 = alphaPoint != null ? Std.int(alphaPoint.y) : 0;
		for (yy in 0...Std.int(srcRect.height)) {
			var sy = sy0 + yy, dy = dy0 + yy;
			if (sy < 0 || sy >= source.height || dy < 0 || dy >= height)
				continue;
			for (xx in 0...Std.int(srcRect.width)) {
				var sx = sx0 + xx, dx = dx0 + xx;
				if (sx < 0 || sx >= source.width || dx < 0 || dx >= width)
					continue;
				var p = src[sy * source.width + sx];
				if (!source.transparent)
					p |= 0xFF000000;
				if (alphaBd != null) {
					var ax = ax0 + xx, ay = ay0 + yy;
					var am = ax < 0 || ay < 0 || ax >= alphaBd.width || ay >= alphaBd.height ? 0 : (alphaBd.ints[ay * alphaBd.width + ax] >>> 24) & 0xFF;
					var a = Math.round(((p >>> 24) & 0xFF) * am / 255);
					p = (a << 24) | (p & 0xFFFFFF);
				}
				var i = dy * width + dx;
				if (merge) {
					var sa = (p >>> 24) & 0xFF;
					if (sa == 0xFF)
						ints[i] = opaque(p);
					else if (sa > 0) {
						var d = ints[i];
						var da = transparent ? (d >>> 24) & 0xFF : 0xFF;
						var oa = sa + da * (255 - sa) / 255;
						inline function ch(s:Int, dd:Int):Int
							return Math.round((s * sa + dd * da * (255 - sa) / 255) / oa);
						var r = ch((p >> 16) & 0xFF, (d >> 16) & 0xFF);
						var g = ch((p >> 8) & 0xFF, (d >> 8) & 0xFF);
						var b = ch(p & 0xFF, d & 0xFF);
						ints[i] = opaque((Math.round(oa) << 24) | (r << 16) | (g << 8) | b);
					}
				} else
					ints[i] = opaque(p);
			}
		}
		canvasStale = true;
		dirty();
	}

	// a texture of a sheet (or a RenderTexture) drawn at (x, y) (its trim kept), over the pixels (mergeAlpha) or replacing
	// them (a picture of an atlas copied with copyPixels: mt.deepnight.retro.SpriteLibBitmap.drawIntoBitmap). The drawings
	// over the pixels wait for the next other operation on this picture and are drawn together, in one render (the
	// thousand tiles of a level)
	public function drawFrame(t:Dynamic, x:Float, y:Float, ?mergeAlpha:Bool = true) {
		if (!mergeAlpha) {
			flushQueue();
			gpuFill(new Rectangle(x, y, t.orig.width, t.orig.height), 0);
		}
		queueSprite(t, x, y, null);
	}

	// a texture to draw at (x, y) with the other drawings of the queue (from the picture `from`, null: a sheet)
	function queueSprite(t:Dynamic, x:Float, y:Float, from:BitmapData) {
		// (the queues that will draw this picture as it is now: drawn before it changes)
		for (b in pending)
			if (b != this && b.queue != null && b.queueSources.indexOf(this) >= 0)
				b.renderQueue();
		toGpu();
		var s = new pixi.core.sprites.Sprite(t);
		s.x = x;
		s.y = y;
		if (queue == null) {
			queue = [];
			queueSources = [];
		}
		queue.push(s);
		if (from != null && queueSources.indexOf(from) < 0)
			queueSources.push(from);
		if (pending.indexOf(this) < 0)
			pending.push(this);
	}

	inline function flushQueue() {
		if (queue != null)
			renderQueue();
	}

	// the queues of every picture: before a change of one of them (a picture in a queue drawn as it was)
	static function flushQueues() {
		for (b in pending)
			if (b.queue != null)
				b.renderQueue();
	}

	function renderQueue() {
		var q = queue;
		queue = null;
		queueSources = null;
		var c = new pixi.core.display.Container();
		// (added in one call: the anti-cheat of KadoKadeo reads a stack trace by addChild of raw PIXI objects)
		untyped c.addChild.apply(c, q);
		renderer().render(c, {renderTexture: rt, clear: false});
		c.destroy({children: true});
	}

	// how perlinNoise draws (Flash.reset: false, the approximation the games were made with): a fractal gradient noise of
	// randomSeed (Green Witch: the cracks of the floors are the contours of its dark parts)
	public static var perlinFractal:Bool = false;

	// Approximation: grey noise in small blocks, around ~128 so that an OVERLAY / SCREEN draw stays almost neutral (a
	// black perlin would darken the veil); drawn on the random of the effects. With perlinFractal: a gradient noise of
	// baseX x baseY, numOctaves octaves of half the size (summed, fractalNoise), on its own generator of randomSeed (a
	// picture only: the same in a replay, nothing drawn from the random of KadoKadeo)
	public function perlinNoise(baseX:Float, baseY:Float, numOctaves:Int, randomSeed:Int, stitch:Bool, fractalNoise:Bool, ?channelOptions:Int = 7, ?grayScale:Bool = false, ?offsets:Dynamic):Void {
		flushQueues();
		if (perlinFractal) {
			fractalNoiseInto(baseX, baseY, numOctaves, randomSeed, fractalNoise, channelOptions, grayScale);
			return;
		}
		var a = ints != null ? ints : new Int32Array(width * height);
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
						a[yy * width + xx] = 0xFF000000 | (v << 16) | (v << 8) | v;
						xx++;
					}
					yy++;
				}
				bx += block;
			}
			by += block;
		}
		written(a);
	}

	function fractalNoiseInto(baseX:Float, baseY:Float, octaves:Int, seed:Int, fractal:Bool, channels:Int, gray:Bool) {
		// the gradients: a permutation of 256 drawn by an LCG of the seed
		var st = (seed & 0x7FFFFFFF) + 1;
		inline function next():Int {
			st = (st * 16807) % 2147483647;
			return st;
		}
		var perm = [for (i in 0...256) i];
		var i = 255;
		while (i > 0) {
			var j = next() % (i + 1);
			var t = perm[i];
			perm[i] = perm[j];
			perm[j] = t;
			i--;
		}
		var p = [for (k in 0...512) perm[k & 255]];
		inline function fade(t:Float):Float return t * t * t * (t * (t * 6 - 15) + 10);
		inline function grad(h:Int, x:Float, y:Float):Float {
			return switch (h & 7) {
				case 0: x + y;
				case 1: -x + y;
				case 2: x - y;
				case 3: -x - y;
				case 4: x;
				case 5: -x;
				case 6: y;
				default: -y;
			}
		}
		function noise(x:Float, y:Float, o:Int):Float {
			var xi = Math.floor(x), yi = Math.floor(y);
			var xf = x - xi, yf = y - yi;
			var X = (xi + o * 37) & 255, Y = (yi + o * 91) & 255;
			var u = fade(xf), v = fade(yf);
			var aa = p[p[X] + Y], ab = p[p[X] + Y + 1], ba = p[p[X + 1] + Y], bb = p[p[X + 1] + Y + 1];
			var x1 = grad(aa, xf, yf) + (grad(ba, xf - 1, yf) - grad(aa, xf, yf)) * u;
			var x2 = grad(ab, xf, yf - 1) + (grad(bb, xf - 1, yf - 1) - grad(ab, xf, yf - 1)) * u;
			return (x1 + (x2 - x1) * v) * 0.7;
		}
		var a = ints != null ? ints : new Int32Array(width * height);
		var nch = gray ? 1 : 4;
		for (y in 0...height)
			for (x in 0...width) {
				var col = 0;
				var alpha = 255;
				for (c in 0...nch) {
					var bit = gray ? 7 : (c == 3 ? 8 : 1 << c);
					if (!gray && channels & bit == 0)
						continue;
					var sum = 0.0, amp = 1.0, tot = 0.0, fx = 1 / baseX, fy = 1 / baseY;
					for (o in 0...octaves) {
						var n = noise(x * fx, y * fy, o + c * 13);
						sum += (fractal ? n : Math.abs(n)) * amp;
						tot += amp;
						amp *= 0.5;
						fx *= 2;
						fy *= 2;
					}
					var v = sum / tot;
					var b = Std.int(Math.max(0, Math.min(255, fractal ? 128 + v * 255 : v * 255)));
					if (gray)
						col = (b << 16) | (b << 8) | b;
					else if (c == 3)
						alpha = b;
					else
						col |= b << (16 - 8 * c);
				}
				a[y * width + x] = opaque((alpha << 24) | col);
			}
		written(a);
	}

	public function copyChannel(source:Dynamic, srcRect:Rectangle, dstPoint:Point, srcChannel:Int, dstChannel:Int):Void {}

	// the region srcRect of source drawn through the filter (a BitmapFilter of arkadeo) at dstPoint, replacing it
	public function applyFilter(source:BitmapData, srcRect:Rectangle, dstPoint:Point, filter:BitmapFilter):Void {
		flushQueues();
		var t:Dynamic = source == this ? copyTexture() : source.getTexture();
		gpuFill(new Rectangle(dstPoint.x, dstPoint.y, srcRect.width, srcRect.height), 0);
		drawRegion(t, srcRect, dstPoint, filter.toPixi(), null);
		if (source == this)
			t.destroy(true);
	}

	// the pixels of rect through the colour transform
	public function colorTransform(r:Rectangle, ct:ColorTransform):Void {
		applyFilter(this, r, new Point(r.x, r.y), new ColorMatrixFilter([
			ct.redMultiplier, 0, 0, 0, ct.redOffset,
			0, ct.greenMultiplier, 0, 0, ct.greenOffset,
			0, 0, ct.blueMultiplier, 0, ct.blueOffset,
			0, 0, 0, ct.alphaMultiplier, ct.alphaOffset
		]));
	}

	public function clone():BitmapData {
		flushQueues();
		var b = new BitmapData(width, height, transparent, 0x0);
		if (rt != null || texSrc != null) {
			b.toGpu();
			b.drawTexture(getTexture(), null, null, null);
			return b;
		}
		if (ints != null) {
			b.ints.set(ints);
			b.canvasStale = true;
			b.dirty();
			return b;
		}
		b.toCanvas();
		b.ctx.drawImage(canvas, 0, 0);
		b.dirty();
		return b;
	}

	public function dispose():Void {
		if (queue != null)
			for (q in queue)
				q.destroy();
		queue = null;
		queueSources = null;
		// (the queues drawing this picture: drawn before it goes)
		flushQueues();
		if (rt != null)
			rt.destroy(true);
		rt = null;
		// (the texture of the canvas freed with its BaseTexture: PIXI keeps it in its caches until destroyed)
		if (tex != null)
			tex.destroy(true);
		canvas = null;
		ctx = null;
		tex = null;
		_imgData = null;
		ints = null;
		texSrc = null;
		pending.remove(this);
	}

	public function getTexture():Dynamic {
		flushQueues();
		if (rt != null)
			return rt;
		if (texSrc != null)
			return texSrc;
		syncCanvas();
		if (tex == null)
			tex = js.Syntax.code("PIXI.Texture.from({0})", canvas);
		else if (texDirty)
			tex.update();
		texDirty = false;
		return tex;
	}

	public function getCanvas():Dynamic {
		flushQueues();
		syncCanvas();
		return canvas;
	}

	public static function fromImage(img:Dynamic):BitmapData {
		var b = new BitmapData(img.width, img.height, true, 0x0);
		b.toCanvas();
		b.ctx.drawImage(img, 0, 0);
		b.dirty();
		return b;
	}

	// a picture of a sheet (its size: the original size of the frame, before the trim of the packer)
	public static function fromTexture(t:Dynamic):BitmapData {
		var b = new BitmapData(1, 1, true, 0x0);
		b.width = Std.int(t.orig.width);
		b.height = Std.int(t.orig.height);
		b.texSrc = t;
		b.canvas = null;
		b.ctx = null;
		b.ints = null;
		b.plain = false;
		return b;
	}

	// the part r of a texture (in the space of its original frame: the trim of a packed frame kept, nothing where the packer
	// cut transparent pixels away). inset (a fraction of a texel): the picture and its quad pulled in by it on every side,
	// for a slice of an atlas without padding shown at any scale (a screen at 125 %: an edge falling on the centre of a
	// pixel would read the next row of the atlas there)
	public static function subTexture(t:Dynamic, r:Rectangle, ?inset:Float = 0):Dynamic {
		var trimX = t.trim != null ? t.trim.x : 0.0, trimY = t.trim != null ? t.trim.y : 0.0;
		var fw:Float = t.frame.width, fh:Float = t.frame.height;
		var x0 = Math.max(r.x, trimX), y0 = Math.max(r.y, trimY);
		var x1 = Math.min(r.x + r.width, trimX + fw), y1 = Math.min(r.y + r.height, trimY + fh);
		var orig = js.Syntax.code("new PIXI.Rectangle(0, 0, {0}, {1})", r.width, r.height);
		if (x1 <= x0 || y1 <= y0)
			return js.Syntax.code("new PIXI.Texture({0}.baseTexture, new PIXI.Rectangle({0}.frame.x, {0}.frame.y, 1, 1), {1}, new PIXI.Rectangle(0, 0, 0, 0))", t,
				orig);
		var e = inset, w = x1 - x0 - 2 * inset, h = y1 - y0 - 2 * inset;
		var frame = js.Syntax.code("new PIXI.Rectangle({0}, {1}, {2}, {3})", t.frame.x + x0 - trimX + e, t.frame.y + y0 - trimY + e, w, h);
		var trim = js.Syntax.code("new PIXI.Rectangle({0}, {1}, {2}, {3})", x0 - r.x + e, y0 - r.y + e, w, h);
		return js.Syntax.code("new PIXI.Texture({0}.baseTexture, {1}, {2}, {3})", t, frame, orig, trim);
	}

	// (Bitmap) the Bitmaps showing this BitmapData
	public function addUser(b:Bitmap) {
		if (users.indexOf(b) < 0)
			users.push(b);
	}

	public function removeUser(b:Bitmap) {
		users.remove(b);
	}

	// ---------------------------------------------------------------- GPU
	static inline function renderer():Dynamic {
		return kado.KadoKadeoManager.kkm.renderer;
	}

	// the picture moves to a RenderTexture (what the canvas had drawn first), shown from then on by the Bitmaps
	function toGpu() {
		if (rt != null)
			return;
		rt = js.Syntax.code("PIXI.RenderTexture.create({width: {0}, height: {1}, scaleMode: {2}})", width, height, gpuScaleMode);
		if (texSrc != null) {
			var s = new pixi.core.sprites.Sprite(texSrc);
			renderer().render(s, {renderTexture: rt, clear: true});
			s.destroy();
			texSrc = null;
		} else if (plain) {
			var g = new pixi.core.graphics.Graphics();
			renderer().render(g, {renderTexture: rt, clear: true});
			g.destroy();
			if (fill0 != 0x0 || !transparent)
				gpuFill(new Rectangle(0, 0, width, height), fill0);
		} else {
			syncCanvas();
			var t:Dynamic = js.Syntax.code("PIXI.Texture.from({0})", canvas);
			var s = new pixi.core.sprites.Sprite(t);
			renderer().render(s, {renderTexture: rt, clear: true});
			s.destroy();
			t.destroy(true);
		}
		if (tex != null)
			tex.destroy(true);
		tex = null;
		canvas = null;
		ctx = null;
		_imgData = null;
		ints = null;
		canvasStale = false;
		pending.remove(this);
		for (b in users)
			if (b.bitmapData == this)
				b.setTexture(rt, width, height);
	}

	// a copy of the RenderTexture (to draw this picture into itself)
	function copyTexture():Dynamic {
		toGpu();
		var c:Dynamic = js.Syntax.code("PIXI.RenderTexture.create({width: {0}, height: {1}, scaleMode: {2}})", width, height, gpuScaleMode);
		var s = new pixi.core.sprites.Sprite(rt);
		renderer().render(s, {renderTexture: c, clear: true});
		s.destroy();
		return c;
	}

	// pixels of r set to the colour (ARGB), the alpha included (the rectangle is cleared first: Flash replaces)
	function gpuFill(r:Rectangle, color:Int) {
		toGpu();
		var g = new pixi.core.graphics.Graphics();
		g.beginFill(0, 1);
		g.drawRect(r.x, r.y, r.width, r.height);
		g.endFill();
		untyped g.blendMode = js.Syntax.code("PIXI.BLEND_MODES.ERASE");
		renderer().render(g, {renderTexture: rt, clear: false});
		var a = transparent ? ((color >>> 24) & 0xFF) / 255 : 1.0;
		if (a > 0) {
			g.clear();
			g.beginFill(color & 0xFFFFFF, a);
			g.drawRect(r.x, r.y, r.width, r.height);
			g.endFill();
			untyped g.blendMode = js.Syntax.code("PIXI.BLEND_MODES.NORMAL");
			renderer().render(g, {renderTexture: rt, clear: false});
		}
		g.destroy();
	}

	// a blend of draw: the PIXI blend of the drawn leaves, or of the filter that ends the drawing (a filtered picture is
	// composed only once, by its last filter). OVERLAY: the 2 x src x dst of OverlayBlend when the game registered it (its
	// filter puts the picture over 50 % grey), else the SCREEN of BlendMode
	static function overlayFilter(b:BlendMode):Dynamic {
		return b == OVERLAY && untyped renderer().state.blendModes[OverlayBlend.MODE] != null ? new OverlayBlend() : null;
	}

	static function pixiBlend(b:BlendMode):Int {
		if (b == null)
			return js.Syntax.code("PIXI.BLEND_MODES.NORMAL");
		return b == ERASE ? js.Syntax.code("PIXI.BLEND_MODES.ERASE") : BlendMode.toPixi(b);
	}

	// the colour transform of draw: the alpha alone on the alpha of the drawn object, anything else as a colour matrix
	static function ctFilter(ct:ColorTransform):Dynamic {
		if (ct == null || (ct.redMultiplier == 1 && ct.greenMultiplier == 1 && ct.blueMultiplier == 1 && ct.redOffset == 0 && ct.greenOffset == 0
			&& ct.blueOffset == 0 && ct.alphaOffset == 0))
			return null;
		return new ColorMatrixFilter([
			ct.redMultiplier, 0, 0, 0, ct.redOffset,
			0, ct.greenMultiplier, 0, 0, ct.greenOffset,
			0, 0, ct.blueMultiplier, 0, ct.blueOffset,
			0, 0, 0, 1, ct.alphaOffset
		]).toPixi();
	}

	// renders `o` (a PIXI object at its own place) into the RenderTexture with these extra filters and this blend; the
	// blends of its leaves and filters are put back after
	function renderWith(o:Dynamic, extra:Array<Dynamic>, blend:BlendMode, ?transform:Matrix) {
		var saved:Array<Dynamic> = [];
		var flts:Array<Dynamic> = o.filters;
		var ov = overlayFilter(blend);
		if (ov != null)
			extra.push(ov);
		var all:Array<Dynamic> = (flts == null ? [] : flts.copy()).concat(extra);
		var pb = pixiBlend(blend);
		if (all.length > 0) {
			o.filters = all;
			var last = all[all.length - 1];
			if (ov == null) {
				saved.push({o: last, b: last.blendMode});
				last.blendMode = pb;
			}
		} else if (pb != pixiBlend(NORMAL)) {
			collectBlends(o, saved);
			BlendMode.apply(o, pb);
		}
		renderer().render(o, {renderTexture: rt, clear: false, transform: transform != null ? transform.toPixi() : null});
		for (l in saved)
			l.o.blendMode = l.b;
		o.filters = flts;
	}

	function drawTexture(t:Dynamic, matrix:Matrix, ct:ColorTransform, blend:BlendMode) {
		toGpu();
		var s = new pixi.core.sprites.Sprite(t);
		if (ct != null)
			s.alpha = ct.alphaMultiplier;
		var f = ctFilter(ct);
		renderWith(s, f != null ? [f] : [], blend, matrix);
		s.destroy();
	}

	// the region r of the texture t drawn at pt (through the PIXI filter f)
	function drawRegion(t:Dynamic, r:Rectangle, pt:Point, f:Dynamic, blend:BlendMode) {
		toGpu();
		var sub:Dynamic = subTexture(t, r);
		var s = new pixi.core.sprites.Sprite(sub);
		s.x = pt.x;
		s.y = pt.y;
		var holder = new pixi.core.display.Container();
		holder.addChild(s);
		// (a filter works on the whole target)
		untyped holder.filterArea = new pixi.core.math.shapes.Rectangle(0, 0, width, height);
		renderWith(holder, f != null ? [f] : [], blend);
		holder.destroy({children: true});
		sub.destroy(false);
	}

	// copyPixels with an alpha picture: the region r of source with its alpha multiplied by the one of alphaBd (the part of
	// alphaBd at alphaPoint, drawn over it with the blend DST_IN), in a new RenderTexture of the size of r
	function maskedPiece(source:BitmapData, r:Rectangle, alphaBd:BitmapData, alphaPoint:Point):Dynamic {
		var w = Std.int(r.width), h = Std.int(r.height);
		var tmp:Dynamic = js.Syntax.code("PIXI.RenderTexture.create({width: {0}, height: {1}, scaleMode: {2}})", w, h, gpuScaleMode);
		var sub:Dynamic = subTexture(source.getTexture(), r);
		var s = new pixi.core.sprites.Sprite(sub);
		renderer().render(s, {renderTexture: tmp, clear: true});
		var ap = alphaPoint != null ? alphaPoint : new Point(0, 0);
		var asub:Dynamic = subTexture(alphaBd.getTexture(), new Rectangle(ap.x, ap.y, w, h));
		var m = new pixi.core.sprites.Sprite(asub);
		untyped m.blendMode = js.Syntax.code("PIXI.BLEND_MODES.DST_IN");
		renderer().render(m, {renderTexture: tmp, clear: false});
		s.destroy();
		m.destroy();
		sub.destroy(false);
		asub.destroy(false);
		return tmp;
	}

	// the region r of this picture in a new RenderTexture of its size
	function regionCopy(r:Rectangle):Dynamic {
		var tmp:Dynamic = js.Syntax.code("PIXI.RenderTexture.create({width: {0}, height: {1}, scaleMode: {2}})", Std.int(r.width), Std.int(r.height),
			gpuScaleMode);
		var sub:Dynamic = subTexture(getTexture(), r);
		var s = new pixi.core.sprites.Sprite(sub);
		renderer().render(s, {renderTexture: tmp, clear: true});
		s.destroy();
		sub.destroy(false);
		return tmp;
	}

	// a display object drawn as Flash draws it: at its current Flash state, without its own transform (the matrix of draw),
	// with its filters, the colour transform and the blend mode of draw
	function drawObject(o:DisplayObject, matrix:Matrix, ct:ColorTransform, blend:BlendMode) {
		toGpu();
		var n:Dynamic = o.node;
		o.show(1);
		n.updateGraphics(1);
		var px = n.position.x, py = n.position.y, sx = n.scale.x, sy = n.scale.y, rot = n.rotation, al = n.alpha, vis = n.visible;
		var k = o.nodeScaleOf();
		n.position.set(0, 0);
		n.scale.set(k, k);
		n.rotation = 0;
		n.alpha = ct != null ? ct.alphaMultiplier : 1;
		n.visible = true;
		var f = ctFilter(ct);
		renderWith(n, f != null ? [f] : [], blend, matrix);
		n.position.set(px, py);
		n.scale.set(sx, sy);
		n.rotation = rot;
		n.alpha = al;
		n.visible = vis;
	}

	static function collectBlends(o:Dynamic, out:Array<Dynamic>) {
		if (o.texture != null || o.geometry != null)
			out.push({o: o, b: o.blendMode});
		if (o.filters != null)
			for (f in (o.filters : Array<Dynamic>))
				out.push({o: f, b: f.blendMode});
		if (o.children != null)
			for (c in (o.children : Array<Dynamic>))
				collectBlends(c, out);
	}
}
