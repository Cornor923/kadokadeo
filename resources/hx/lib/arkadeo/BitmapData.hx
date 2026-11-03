package arkadeo;

import kado.Seed;

// flash.display.BitmapData on an off-screen 2D <canvas>, shown by a Bitmap (getTexture: the canvas as a PIXI.Texture,
// uploaded again after each change). Nothing of it is read by a game: its pixels are not the same in every browser.
//
// What only the GPU can draw (Fafi 360: the stadium composed of the clips of the SWF, the marks of the explosions on the
// ground, mt.deepnight.Lib.flatten) moves the picture to a PIXI.RenderTexture, kept from then on: draw of a display
// object (the matrix, colour transform and blend mode of draw; the own transform of the object ignored, like Flash),
// colorTransform, applyFilter, and the fills / copies after it. A picture drawn on the GPU has no pixels to read (getPixel
// reads what the canvas had before).
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
	var _imgData:Dynamic; // cached ImageData (dropped at each change)

	// the RenderTexture once the GPU drew in it, and the Bitmaps that show this BitmapData (given the RenderTexture)
	var rt:Dynamic = null;
	var users:Array<Bitmap> = [];
	// the canvas only holds the colour it was created with (moved to the GPU without uploading it)
	var plain:Bool = true;
	var fill0:Int;

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
		plain = true;
		fill0 = fillColor;
	}

	public var rect(get, never):Rectangle;
	inline function get_rect():Rectangle return new Rectangle(0, 0, width, height);

	inline function dirty():Void {
		plain = false;
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
		if (rt != null) {
			gpuFill(r, color);
			return;
		}
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
		if (rt != null) {
			gpuFill(new Rectangle(x, y, 1, 1), 0xFF000000 | color);
			return;
		}
		ctx.fillStyle = "rgb(" + ((color >> 16) & 0xFF) + "," + ((color >> 8) & 0xFF) + "," + (color & 0xFF) + ")";
		ctx.fillRect(x, y, 1, 1);
		dirty();
	}

	public function setPixel32(x:Int, y:Int, color:Int):Void {
		if (rt != null) {
			gpuFill(new Rectangle(x, y, 1, 1), color);
			return;
		}
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
		var src:BitmapData = Std.downcast(source, BitmapData);
		if (Std.isOfType(source, DisplayObject) || rt != null || (src != null && src.rt != null)) {
			if (src != null)
				drawTexture(src.getTexture(), matrix, colorTransform, blendMode);
			else if (Std.isOfType(source, DisplayObject))
				drawObject(source, matrix, colorTransform, blendMode);
			return;
		}
		try {
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

	public function copyPixels(source:BitmapData, srcRect:Rectangle, dstPoint:Point, ?alphaBitmapData:Dynamic, ?alphaPoint:Dynamic, ?mergeAlpha:Bool):Void {
		if (rt != null || source.rt != null) {
			var r = new Rectangle(dstPoint.x, dstPoint.y, srcRect.width, srcRect.height);
			if (mergeAlpha != true)
				gpuFill(r, 0);
			drawRegion(source.getTexture(), srcRect, dstPoint, null, null);
			return;
		}
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

	// the region srcRect of source drawn through the filter (a BitmapFilter of arkadeo) at dstPoint, replacing it
	public function applyFilter(source:BitmapData, srcRect:Rectangle, dstPoint:Point, filter:BitmapFilter):Void {
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
		var b = new BitmapData(width, height, transparent, 0x0);
		if (rt != null) {
			b.toGpu();
			b.drawTexture(rt, null, null, null);
			return b;
		}
		b.ctx.drawImage(canvas, 0, 0);
		b.dirty();
		return b;
	}

	public function dispose():Void {
		if (rt != null)
			rt.destroy(true);
		rt = null;
		canvas = null;
		ctx = null;
		tex = null;
		_imgData = null;
	}

	public function getTexture():Dynamic {
		if (rt != null)
			return rt;
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
		if (plain) {
			var g = new pixi.core.graphics.Graphics();
			renderer().render(g, {renderTexture: rt, clear: true});
			g.destroy();
			if (fill0 != 0x0 || !transparent)
				gpuFill(new Rectangle(0, 0, width, height), fill0);
		} else {
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
		var sub:Dynamic = js.Syntax.code("new PIXI.Texture({0}.baseTexture, new PIXI.Rectangle({1}, {2}, {3}, {4}))", t, t.frame.x + r.x, t.frame.y + r.y,
			r.width, r.height);
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
