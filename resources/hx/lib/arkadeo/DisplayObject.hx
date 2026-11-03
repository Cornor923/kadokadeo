package arkadeo;

import common_haxe_avm1.display.ASprite;
import common_haxe_avm1.display.ASprite.TransformState;

// flash.display.DisplayObject: the Flash state of the object, shown by its ASprite node (see Flash)
class DisplayObject {
	// the space of getRect by default (Mel: the root of the level)
	public static var defaultRectSpace:DisplayObject = null;

	public var node(default, null):ASprite;
	public var parent(default, null):DisplayObjectContainer = null;
	public var name:String;
	public var mouseEnabled:Bool = true;

	// Flash properties
	var vx:Float = 0;
	var vy:Float = 0;
	var vsx:Float = 1;
	var vsy:Float = 1;
	var vrot:Float = 0;
	var valpha:Float = 1;
	var vvis:Bool = true;
	// previous Flash frame
	var ox:Float = 0;
	var oy:Float = 0;
	var osx:Float = 1;
	var osy:Float = 1;
	var orot:Float = 0;
	var oalpha:Float = 1;
	// shown without interpolation on the next display (new on the display list, teleported)
	var fresh:Bool = true;
	// moved since it was put on the display list (Flash.snapFirstMove)
	var placed:Bool = false;

	var ct:ColorTransform = null;
	var flts:Array<BitmapFilter> = [];
	var blend:BlendMode = NORMAL;

	public function new(node:ASprite) {
		this.node = node;
		untyped node.__do = this;
	}

	public var x(get, set):Float;
	public var y(get, set):Float;
	public var scaleX(get, set):Float;
	public var scaleY(get, set):Float;
	public var rotation(get, set):Float;
	public var rotationZ(get, set):Float;
	public var alpha(get, set):Float;
	public var visible(get, set):Bool;

	inline function get_x()
		return vx;

	function set_x(v:Float) {
		if (Math.isFinite(v))
			vx = Flash.twips(v);
		return v;
	}

	inline function get_y()
		return vy;

	function set_y(v:Float) {
		if (Math.isFinite(v))
			vy = Flash.twips(v);
		return v;
	}

	inline function get_scaleX()
		return vsx;

	function set_scaleX(v:Float) {
		if (Math.isFinite(v))
			vsx = v;
		return v;
	}

	inline function get_scaleY()
		return vsy;

	function set_scaleY(v:Float) {
		if (Math.isFinite(v))
			vsy = v;
		return v;
	}

	inline function get_rotation()
		return vrot;

	function set_rotation(v:Float) {
		if (Math.isFinite(v))
			vrot = Flash.normRot(v);
		return v;
	}

	inline function get_rotationZ()
		return vrot;

	inline function set_rotationZ(v:Float)
		return set_rotation(v);

	inline function get_alpha()
		return valpha;

	function set_alpha(v:Float) {
		if (Math.isFinite(v))
			valpha = v;
		return v;
	}

	inline function get_visible()
		return vvis;

	function set_visible(v:Bool) {
		// (shown again: drawn at its new place, no sliding from where it was hidden)
		if (v && !vvis)
			snap();
		vvis = v;
		node.visible = v;
		return v;
	}

	// a jump of the object (no sliding from the old place)
	public function snap() {
		fresh = true;
	}

	// ---------------------------------------------------------------- colour, filters, blend
	public var colorTransform(get, set):ColorTransform;

	function get_colorTransform():ColorTransform {
		var c = ct != null ? ct.clone() : new ColorTransform();
		c.alphaMultiplier = valpha;
		return c;
	}

	// (Flash: the alpha of a display object is the alpha multiplier of its colour transform)
	function set_colorTransform(c:ColorTransform):ColorTransform {
		ct = c.clone();
		valpha = c.alphaMultiplier;
		applyColour();
		return c;
	}

	// the multipliers as the tint of the node; colour offsets (a Sprite or a Shape coloured by code: Fafi 360's aiming
	// arrow) as a colour matrix after the filters
	function applyColour() {
		node.tint = ct == null ? 0xFFFFFF : ct.tint();
		var withOffsets = ct != null && (ct.redOffset != 0 || ct.greenOffset != 0 || ct.blueOffset != 0);
		if (withOffsets || ctFilter != null) {
			ctFilter = withOffsets ? new ColorMatrixFilter([
				ct.redMultiplier, 0, 0, 0, ct.redOffset,
				0, ct.greenMultiplier, 0, 0, ct.greenOffset,
				0, 0, ct.blueMultiplier, 0, ct.blueOffset,
				0, 0, 0, 1, 0
			]) : null;
			if (withOffsets)
				node.tint = 0xFFFFFF;
			pixiFilters();
		}
	}

	var ctFilter:ColorMatrixFilter = null;

	public var filters(get, set):Array<BitmapFilter>;

	inline function get_filters()
		return flts.copy();

	function set_filters(f:Array<BitmapFilter>) {
		flts = f == null ? [] : f.copy();
		pixiFilters();
		return f;
	}

	function pixiFilters() {
		var out:Array<Dynamic> = [];
		for (x in flts) {
			var p = x.toPixi();
			if (p != null)
				out.push(p);
		}
		if (ctFilter != null)
			out.push(ctFilter.toPixi());
		// filters given to an object that has a blend mode: the blend of the filtered picture (Flash: the blend mode of the
		// object applies to it with its filters)
		if (blend != NORMAL)
			for (p in out)
				p.blendMode = pixiBlend();
		node.filters = out.length > 0 ? cast out : null;
	}

	// flash.geom.Transform: transform.matrix, transform.colorTransform
	public var transform(get, never):Transform;

	inline function get_transform():Transform
		return new Transform(this);

	public var blendMode(get, set):BlendMode;

	inline function get_blendMode():BlendMode
		return blend;

	function set_blendMode(b:BlendMode) {
		blend = b;
		BlendMode.apply(node, BlendMode.toPixi(b));
		return b;
	}

	// the PIXI blend of what the object draws later (Sprite.graphics)
	inline function pixiBlend():Int
		return BlendMode.toPixi(blend);

	// ---------------------------------------------------------------- mask, size
	// Flash mask: the shape of `m` (drawn nowhere) shows this object
	public var mask(default, set):DisplayObject = null;

	function set_mask(m:DisplayObject) {
		if (mask != null)
			mask.maskShape().renderable = true;
		mask = m;
		node.mask = m == null ? null : cast m.maskShape();
		if (m != null)
			m.maskShape().renderable = false;
		return m;
	}

	// what PIXI masks with (a Graphics: a node is a PIXI sprite, its empty picture would mask everything)
	function maskShape():pixi.core.display.DisplayObject {
		return node;
	}

	// what the object draws, in its own space (null: nothing): the bounds of width / height
	public function contentRect():Rectangle {
		return null;
	}

	// the box of contentRect through the scale and the rotation of the object (its size in the space of its parent)
	function sizeBox():Rectangle {
		var r = contentRect();
		if (r == null)
			return new Rectangle(0, 0, 0, 0);
		var xs = [r.x, r.x + r.width, r.x + r.width, r.x];
		var ys = [r.y, r.y, r.y + r.height, r.y + r.height];
		applyMatrix(xs, ys);
		return boxOf(xs, ys);
	}

	public static function boxOf(xs:Array<Float>, ys:Array<Float>):Rectangle {
		var x0 = Math.min(Math.min(xs[0], xs[1]), Math.min(xs[2], xs[3]));
		var x1 = Math.max(Math.max(xs[0], xs[1]), Math.max(xs[2], xs[3]));
		var y0 = Math.min(Math.min(ys[0], ys[1]), Math.min(ys[2], ys[3]));
		var y1 = Math.max(Math.max(ys[0], ys[1]), Math.max(ys[2], ys[3]));
		return new Rectangle(x0, y0, x1 - x0, y1 - y0);
	}

	public var width(get, set):Float;
	public var height(get, set):Float;

	function get_width():Float
		return sizeBox().width;

	function get_height():Float
		return sizeBox().height;

	// (Flash: the scale that gives this size)
	function set_width(v:Float):Float {
		var r = contentRect();
		if (r != null && r.width > 0)
			scaleX = v / r.width * (vsx < 0 ? -1 : 1);
		return v;
	}

	function set_height(v:Float):Float {
		var r = contentRect();
		if (r != null && r.height > 0)
			scaleY = v / r.height * (vsy < 0 ? -1 : 1);
		return v;
	}

	// ---------------------------------------------------------------- getRect
	// rectangle of the object in its own space (without strokes and filters, like Flash's getRect), null: none
	public function localRect():Rectangle {
		return null;
	}

	// getRect(space): the rectangle of localRect in the space of `space` (default: the root of the level), the box of
	// its transformed corners
	public function getRect(?space:DisplayObject):Rectangle {
		if (space == null)
			space = defaultRectSpace;
		var r = localRect();
		if (r == null)
			r = new Rectangle(0, 0, 0, 0);
		var xs = [r.x, r.x + r.width, r.x + r.width, r.x];
		var ys = [r.y, r.y, r.y + r.height, r.y + r.height];
		var o:DisplayObject = this;
		while (o != null && o != space) {
			o.applyMatrix(xs, ys);
			o = o.parent;
		}
		return boxOf(xs, ys);
	}

	// the transform of this object applied to points of its space (scale, rotation, translation)
	public function applyMatrix(xs:Array<Float>, ys:Array<Float>) {
		var c = 1.0, s = 0.0;
		if (vrot == 90) {
			c = 0;
			s = 1;
		} else if (vrot == -90) {
			c = 0;
			s = -1;
		} else if (vrot == 180 || vrot == -180) {
			c = -1;
			s = 0;
		} else if (vrot != 0) {
			c = Math.cos(vrot * Math.PI / 180);
			s = Math.sin(vrot * Math.PI / 180);
		}
		var a = c * vsx, b = s * vsx, cc = -s * vsy, d = c * vsy;
		for (i in 0...xs.length) {
			var x = xs[i], y = ys[i];
			xs[i] = a * x + cc * y + vx;
			ys[i] = b * x + d * y + vy;
		}
	}

	// ---------------------------------------------------------------- display list
	public function detach() {
		if (parent != null)
			parent.removeChild(this);
	}

	public function toFront() {
		if (parent != null)
			parent.setChildIndex(this, parent.numChildren - 1);
	}

	public function toBack() {
		if (parent != null)
			parent.setChildIndex(this, 0);
	}

	// mt.gx putAfter (as compiled in the game): this object takes the place of `o` in its parent, `o` above it
	public function putAfter(o:DisplayObject) {
		detach();
		if (o.parent == null)
			return;
		var p = o.parent;
		p.addChildAt(this, p.getChildIndex(o));
	}

	// (DisplayObjectContainer only)
	public function attached(p:DisplayObjectContainer) {
		parent = p;
		fresh = true;
		placed = false;
	}

	public function reparented(p:DisplayObjectContainer) {
		parent = p;
	}

	public function detached() {
		parent = null;
	}

	// ---------------------------------------------------------------- interpolation
	public function keepPrev() {
		ox = vx;
		oy = vy;
		osx = vsx;
		osy = vsy;
		orot = vrot;
		oalpha = valpha;
	}

	// pixels of the node per Flash pixel (a Clip of textures at another resolution)
	function nodeScale():Float {
		return 1;
	}

	public inline function nodeScaleOf():Float {
		return nodeScale();
	}

	public function show(frac:Float) {
		var s = node._curState;
		var k = nodeScale();
		if (fresh) {
			keepPrev();
			frac = 1;
		}
		s.x = ox + (vx - ox) * frac;
		s.y = oy + (vy - oy) * frac;
		// a flip is instant
		s.xscale = (osx * vsx < 0 ? vsx : osx + (vsx - osx) * frac) * k;
		s.yscale = (osy * vsy < 0 ? vsy : osy + (vsy - osy) * frac) * k;
		var dr = vrot - orot;
		if (dr > 180)
			dr -= 360;
		else if (dr < -180)
			dr += 360;
		s.rotation = (orot + dr * frac) * Math.PI / 180;
		var a = oalpha + (valpha - oalpha) * frac;
		s.alpha = a < 0 ? 0 : (a > 1 ? 1 : a);
		if (Flash.roundMoving)
			(cast node : Node).exact = s.x == vx && s.y == vy;
		if (fresh) {
			fresh = false;
			if (node._prevState == null)
				node._prevState = new TransformState(node);
			node._prevState.copyFrom(s);
		}
	}

	// after a Flash frame (Flash.frameEnd): the moves shown as jumps
	public function checkJumps() {
		if (fresh)
			return;
		var moved = vx != ox || vy != oy;
		if ((Flash.snapFirstMove && moved && !placed) || Math.abs(vx - ox) > Flash.teleport || Math.abs(vy - oy) > Flash.teleport)
			fresh = true;
		if (moved)
			placed = true;
	}
}
