package mel;

import common_haxe_avm1.display.ASprite;
import common_haxe_avm1.display.ASprite.TransformState;
import pixi.core.graphics.Graphics;
import pixi.core.textures.Texture;

/**
 * The part of the Flash Player 11 display list (AS3) the original code uses, over PIXI: DisplayObject (DO),
 * DisplayObjectContainer (DOC), Sprite (Spr), Shape (Shp), Bitmap (Bmp), MovieClip (Mov, played by Clip), the AS3
 * mt.DepthManager (DM) and ColorTransform (CT).
 *
 * The code sets the Flash properties (x, y truncated to twips like Flash, scaleX, scaleY, rotation in degrees, alpha,
 * visible); the children keep the Flash order (index 0 at the bottom).
 *
 * Display: Mel ran at 40 Flash frames/s and KadoKadeo steps 32 times per second, a step plays 1 or 2 Flash frames
 * (Game.update). Every object shows its state one Flash frame ago, interpolated towards the last one by the fraction
 * of a Flash frame the steps are behind (Fl.display): the game moves by exactly 1.25 Flash frames per step, and PIXI
 * interpolates between two steps. An object put on the display list (or moved to another parent) is shown where it
 * is, without interpolation (snap).
 */
class Fl {
	// the space of getRect by default (the root of the level)
	public static var levelRoot:DO = null;

	// state of the previous Flash frame of every object of the display list
	public static function frameStart(root:DO) {
		root.keepPrev();
	}

	public static function display(root:DO, frac:Float) {
		root.show(frac);
	}

	// twips (1/20 px): the x / y of a Flash display object (truncated)
	public static inline function twips(v:Float):Float {
		return Std.int(v * 20) / 20;
	}

	// Flash rotation in degrees, in ]-180, 180]
	public static function normRot(v:Float):Float {
		v = v % 360;
		if (v > 180)
			v -= 360;
		else if (v <= -180)
			v += 360;
		return v;
	}
}

// flash.geom.ColorTransform (with the ofs / mul / rst helpers of mt.gx)
class CT {
	public var redMultiplier:Float = 1;
	public var greenMultiplier:Float = 1;
	public var blueMultiplier:Float = 1;
	public var alphaMultiplier:Float = 1;
	public var redOffset:Float = 0;
	public var greenOffset:Float = 0;
	public var blueOffset:Float = 0;
	public var alphaOffset:Float = 0;

	public function new() {}

	public function ofs(r:Float = 0, g:Float = 0, b:Float = 0, a:Float = 0):CT {
		redOffset = r;
		greenOffset = g;
		blueOffset = b;
		alphaOffset = a;
		return this;
	}

	public function mul(r:Float = 1, g:Float = 1, b:Float = 1, a:Float = 1):CT {
		redMultiplier = r;
		greenMultiplier = g;
		blueMultiplier = b;
		alphaMultiplier = a;
		return this;
	}

	public function rst():CT {
		ofs();
		mul();
		return this;
	}

	public function clone():CT {
		var c = new CT();
		c.redMultiplier = redMultiplier;
		c.greenMultiplier = greenMultiplier;
		c.blueMultiplier = blueMultiplier;
		c.alphaMultiplier = alphaMultiplier;
		c.redOffset = redOffset;
		c.greenOffset = greenOffset;
		c.blueOffset = blueOffset;
		c.alphaOffset = alphaOffset;
		return c;
	}

	// this transform applied after `inner` (a picture drawn with `inner`, then given this one)
	public function after(inner:CT):CT {
		var c = new CT();
		c.redMultiplier = inner.redMultiplier * redMultiplier;
		c.greenMultiplier = inner.greenMultiplier * greenMultiplier;
		c.blueMultiplier = inner.blueMultiplier * blueMultiplier;
		c.alphaMultiplier = inner.alphaMultiplier * alphaMultiplier;
		c.redOffset = inner.redOffset * redMultiplier + redOffset;
		c.greenOffset = inner.greenOffset * greenMultiplier + greenOffset;
		c.blueOffset = inner.blueOffset * blueMultiplier + blueOffset;
		c.alphaOffset = inner.alphaOffset * alphaMultiplier + alphaOffset;
		return c;
	}

	// multiplied colour 0xRRGGBB (tint) and added colour 0xRRGGBB
	public function tint():Int {
		return (ch(redMultiplier * 255) << 16) | (ch(greenMultiplier * 255) << 8) | ch(blueMultiplier * 255);
	}

	public function add():Int {
		return (ch(redOffset) << 16) | (ch(greenOffset) << 8) | ch(blueOffset);
	}

	public function isIdentity():Bool {
		return redMultiplier == 1 && greenMultiplier == 1 && blueMultiplier == 1 && redOffset == 0 && greenOffset == 0 && blueOffset == 0;
	}

	static inline function ch(v:Float):Int {
		var i = Math.round(v);
		return i < 0 ? 0 : (i > 255 ? 255 : i);
	}
}

// filters of the original applied at run time (the others are baked in the pictures)
enum Flt {
	Glow(color:Int, alpha:Float, blurX:Float, blurY:Float, strength:Float);
	Blur(blurX:Float, blurY:Float);
	Matrix(m:Array<Float>);
}

// flash.display.DisplayObject
class DO {
	public var node(default, null):ASprite;
	public var parent(default, null):DOC = null;
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

	var ct:CT = null;
	var flts:Array<Flt> = [];
	var blend:String = "normal";

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
			vx = Fl.twips(v);
		return v;
	}

	inline function get_y()
		return vy;

	function set_y(v:Float) {
		if (Math.isFinite(v))
			vy = Fl.twips(v);
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
			vrot = Fl.normRot(v);
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
		vvis = v;
		node.visible = v;
		return v;
	}

	// a jump of the object (no sliding from the old place)
	public function snap() {
		fresh = true;
	}

	// ---------------------------------------------------------------- colour, filters, blend
	public var colorTransform(get, set):CT;

	function get_colorTransform():CT {
		var c = ct != null ? ct.clone() : new CT();
		c.alphaMultiplier = valpha;
		return c;
	}

	// (Flash: the alpha of a display object is the alpha multiplier of its colour transform)
	function set_colorTransform(c:CT):CT {
		ct = c.clone();
		valpha = c.alphaMultiplier;
		applyColour();
		return c;
	}

	function applyColour() {
		node.tint = ct == null ? 0xFFFFFF : ct.tint();
	}

	public var filters(get, set):Array<Flt>;

	inline function get_filters()
		return flts.copy();

	function set_filters(f:Array<Flt>) {
		flts = f == null ? [] : f.copy();
		var out:Array<Dynamic> = [];
		for (x in flts)
			switch (x) {
				case Glow(c, a, bx, by, s):
					out.push(new FlashGlow(bx, by, s, c, a));
				case Blur(bx, by):
					if (bx > 0 || by > 0) {
						var b:Dynamic = js.Syntax.code("new PIXI.filters.BlurFilter()");
						b.blurX = bx * 0.5;
						b.blurY = by * 0.5;
						b.quality = 2;
						out.push(b);
					}
				case Matrix(m):
					var cm:Dynamic = js.Syntax.code("new PIXI.filters.ColorMatrixFilter()");
					var mm = m.copy();
					mm[4] /= 255;
					mm[9] /= 255;
					mm[14] /= 255;
					mm[19] /= 255;
					cm.matrix = mm;
					out.push(cm);
			}
		node.filters = out.length > 0 ? cast out : null;
		return f;
	}

	public var blendMode(get, set):String;

	inline function get_blendMode()
		return blend;

	function set_blendMode(b:String) {
		blend = b;
		setNodeBlend(node, b == "add" ? pixi.core.Pixi.BlendModes.ADD : pixi.core.Pixi.BlendModes.NORMAL);
		return b;
	}

	static function setNodeBlend(n:pixi.core.display.DisplayObject, mode:Dynamic) {
		if (Std.isOfType(n, pixi.core.sprites.Sprite))
			(cast n : pixi.core.sprites.Sprite).blendMode = mode;
		if (Std.isOfType(n, pixi.core.display.Container))
			for (c in (cast n : pixi.core.display.Container).children)
				setNodeBlend(c, mode);
	}

	// ---------------------------------------------------------------- getRect
	// rectangle of the object in its own space (without strokes and filters, like Flash's getRect), null: none
	public function localRect():Rect {
		return null;
	}

	// getRect(space): the rectangle of localRect in the space of `space` (default: the root of the level), the box of
	// its transformed corners
	public function getRect(?space:DO):Rect {
		if (space == null)
			space = Fl.levelRoot;
		var r = localRect();
		if (r == null)
			r = new Rect(0, 0, 0, 0);
		var xs = [r.x, r.x + r.width, r.x + r.width, r.x];
		var ys = [r.y, r.y, r.y + r.height, r.y + r.height];
		var o:DO = this;
		while (o != null && o != space) {
			o.applyMatrix(xs, ys);
			o = o.parent;
		}
		var x0 = Math.min(Math.min(xs[0], xs[1]), Math.min(xs[2], xs[3]));
		var x1 = Math.max(Math.max(xs[0], xs[1]), Math.max(xs[2], xs[3]));
		var y0 = Math.min(Math.min(ys[0], ys[1]), Math.min(ys[2], ys[3]));
		var y1 = Math.max(Math.max(ys[0], ys[1]), Math.max(ys[2], ys[3]));
		return new Rect(x0, y0, x1 - x0, y1 - y0);
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
	public function putAfter(o:DO) {
		detach();
		if (o.parent == null)
			return;
		var p = o.parent;
		p.addChildAt(this, p.getChildIndex(o));
	}

	// (DOC only)
	public function attached(p:DOC) {
		parent = p;
		fresh = true;
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
		if (fresh) {
			fresh = false;
			if (node._prevState == null)
				node._prevState = new TransformState(node);
			node._prevState.copyFrom(s);
		}
	}
}

// flash.display.DisplayObjectContainer
class DOC extends DO {
	public var children(default, null):Array<DO> = [];

	// PIXI children under the Flash children (a Sprite's graphics)
	var base:Int = 0;

	public var numChildren(get, never):Int;

	inline function get_numChildren()
		return children.length;

	public function addChild(o:DO):DO {
		if (o.parent == this) {
			setChildIndex(o, children.length - 1);
			return o;
		}
		return addChildAt(o, children.length);
	}

	public function addChildAt(o:DO, i:Int):DO {
		if (o.parent != null)
			o.parent.removeChild(o);
		if (i < 0)
			i = 0;
		if (i > children.length)
			i = children.length;
		children.insert(i, o);
		node.addChildAt(o.node, i + base);
		o.attached(this);
		return o;
	}

	public function removeChild(o:DO):DO {
		var i = children.indexOf(o);
		if (i < 0)
			return o;
		children.splice(i, 1);
		node.removeChild(o.node);
		o.detached();
		return o;
	}

	public inline function getChildAt(i:Int):DO {
		return children[i];
	}

	public inline function getChildIndex(o:DO):Int {
		return children.indexOf(o);
	}

	public function setChildIndex(o:DO, i:Int) {
		var j = children.indexOf(o);
		if (j < 0)
			return;
		if (i < 0)
			i = 0;
		if (i > children.length - 1)
			i = children.length - 1;
		if (i == j)
			return;
		children.splice(j, 1);
		children.insert(i, o);
		node.removeChild(o.node);
		node.addChildAt(o.node, i + base);
	}

	public function contains(o:DO):Bool {
		while (o != null) {
			if (o == this)
				return true;
			o = o.parent;
		}
		return false;
	}

	override public function keepPrev() {
		super.keepPrev();
		for (c in children)
			c.keepPrev();
	}

	override public function show(frac:Float) {
		super.show(frac);
		for (c in children)
			c.show(frac);
	}
}

// flash.display.Sprite (its graphics are drawn under its children)
class Spr extends DOC {
	public var graphics(get, never):Graphics;

	var gfx:Graphics = null;

	public function new() {
		super(new ASprite());
	}

	function get_graphics():Graphics {
		if (gfx == null) {
			gfx = new Graphics();
			node.addChildAt(gfx, 0);
			base = 1;
		}
		return gfx;
	}
}

// flash.display.Shape
class Shp extends DO {
	public var graphics(default, null):Graphics;

	public function new() {
		super(new ASprite());
		graphics = new Graphics();
		node.addChild(graphics);
	}
}

// flash.display.Bitmap: a picture (an animation frame of the sheets) drawn from its top left corner
class Bmp extends DO {
	public var bmpWidth(default, null):Float = 0;
	public var bmpHeight(default, null):Float = 0;

	public var anim(default, null):String;

	public function new(?anim:String, ?frame:Int = 1) {
		super(new ASprite());
		if (anim != null)
			setAnim(anim, frame);
	}

	// the picture of another bitmap (new Bitmap(b.bitmapData))
	public static function copy(b:Bmp):Bmp {
		var c = new Bmp();
		c.setTexture(b.node.texture, b.bmpWidth, b.bmpHeight);
		c.anim = b.anim;
		return c;
	}

	public function setAnim(a:String, ?frame:Int = 1) {
		anim = a;
		var t = Tex.get(a)[frame - 1];
		node.texture = t;
		node.anchor.copyFrom(t.defaultAnchor);
		bmpWidth = t.orig.width;
		bmpHeight = t.orig.height;
	}

	public function setTexture(t:Texture, w:Float, h:Float) {
		node.texture = t;
		node.anchor.set(0, 0);
		bmpWidth = w;
		bmpHeight = h;
	}

	public var width(get, never):Float;
	public var height(get, never):Float;

	inline function get_width()
		return bmpWidth * Math.abs(vsx);

	inline function get_height()
		return bmpHeight * Math.abs(vsy);

	override function applyColour() {
		node.tint = ct == null ? 0xFFFFFF : ct.tint();
	}
}

// flash.display.MovieClip of the library: a Clip (timeline of the SWF)
class Mov extends DO {
	// every MovieClip created advances its timeline, on the display list or not (AS3)
	public static var all:Array<Mov> = [];

	public var clip(default, null):Clip;

	public function new(name:String) {
		clip = new Clip(name);
		super(clip);
		all.push(this);
	}

	// no more timeline (the clip is not used any more)
	public function dispose() {
		all.remove(this);
	}

	public static function tickAll() {
		for (m in all.copy())
			m.clip.tick();
	}

	// mt.gx.as.Lib.stopAllAnimation(game.root): every MovieClip of the display list stops (nested ones too)
	public static function stopAllIn(g:Game) {
		function walk(o:DO) {
			var m = Std.downcast(o, Mov);
			if (m != null)
				m.clip.stopAll();
			var c = Std.downcast(o, DOC);
			if (c != null)
				for (k in c.children)
					walk(k);
		}
		walk(g.gs);
	}

	override function nodeScale():Float {
		return clip.baseScale;
	}

	public var smc(get, never):Clip;

	inline function get_smc()
		return clip.getClip("smc");

	public inline function getClip(n:String):Clip
		return clip.getClip(n);

	public var currentFrame(get, never):Int;
	public var totalFrames(get, never):Int;
	public var currentLabel(get, never):String;
	public var currentFrameLabel(get, never):String;
	public var isPlaying(get, never):Bool;

	inline function get_currentFrame()
		return clip.currentFrame;

	inline function get_totalFrames()
		return clip.totalFrames;

	inline function get_currentLabel()
		return clip.currentLabel;

	inline function get_currentFrameLabel()
		return clip.currentFrameLabel;

	inline function get_isPlaying()
		return clip.playing();

	public inline function gotoAndStop(f:Dynamic)
		clip.gotoAndStop(f);

	public inline function gotoAndPlay(f:Dynamic)
		clip.gotoAndPlay(f);

	public inline function stop()
		clip.stop();

	public inline function play()
		clip.play();

	public inline function nextFrame()
		clip.nextFrame();

	public inline function prevFrame()
		clip.prevFrame();

	override function applyColour() {
		if (ct == null)
			clip.setColour(0xFFFFFF, 0);
		else
			clip.setColour(ct.tint(), ct.add());
	}
}

// mt.DepthManager (AS3): every plan is an invisible marker in the list of children of the root, the objects of a
// plan are put just under its marker
class DM {
	var root:DOC;
	var plans:Array<DO> = [];
	var baseChildren:Int;

	public function new(root:DOC) {
		this.root = root;
		baseChildren = root.numChildren;
	}

	public function getPlan(p:Int):DO {
		var d = plans[p];
		if (d != null)
			return d;
		d = new Shp();
		d.visible = false;
		d.name = "Plan#" + p;
		root.addChildAt(d, getBottom(p));
		plans[p] = d;
		return d;
	}

	function getBottom(p:Int):Int {
		var i = p;
		while (--i >= 0) {
			var d = plans[i];
			if (d != null)
				return root.getChildIndex(d) + 1;
		}
		return baseChildren;
	}

	public function add<T:DO>(o:T, p:Int):T {
		o.detach();
		root.addChildAt(o, root.getChildIndex(getPlan(p)));
		return o;
	}
}
