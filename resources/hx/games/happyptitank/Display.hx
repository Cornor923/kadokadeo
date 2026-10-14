package happyptitank;

import common_haxe_avm1.display.ASprite;
import pixi.core.sprites.Sprite as PSprite;
import pixi.core.textures.Texture;
import pixi.core.Pixi.BlendModes;

/**
 * The AS3 display list of the original (flash.display.*), kept by the game: the code of the port reads and writes it
 * like the original did (x, y, rotation, scaleX, alpha, visible, colorTransform, addChild, gotoAndStop, width,
 * getBounds...) and the gameplay reads it back (Collision.hx tests the pixels of the pictures, Flash's way). PIXI
 * only draws it (DisplayObject.syncView): nothing of the gameplay depends on the rendering.
 *
 * Flash rules kept:
 *  - x / y are stored in twips (1/20 pixel, truncated); rotation is kept in ]-180, 180]; alpha is 8.8 fixed point;
 *  - the symbols play their timelines on their own (MovieClip), one frame per Flash frame, before the code of the
 *    frame (advanceAll), unless stopped; a Sprite-bound symbol shows its first frame only;
 *  - an instance placed by a timeline is the same object while the timeline does not replace it (the keys of Data);
 *    its named children are fields of the clip (Reflect.setField: tank.canon, canon.col3, miner.smc...);
 *  - an object moved or coloured by the code is no longer moved by its timeline.
 *
 * Display: Happy Pti Tank ran at 30 Flash frames/s and KadoKadeo steps 32 times per second (15 Flash frames every 16
 * steps, Game.update). Every object is shown as it was one Flash frame ago, interpolated towards the last frame by
 * the fraction of a frame the steps are behind (like the 40 frames/s ports, Linea's MC.hx): an object created during
 * the last Flash frame is not shown yet, one removed during it is still shown (ghost) until the next Flash frame.
 */
class DisplayObject {
	// Flash frames played (the snapshots of the display)
	public static var flashFrame:Int = 0;

	public var parent(default, null):Sprite = null;
	public var name:String = null;

	// the matrix (a, b, c, d, tx, ty) and the values the properties read back (Flash caches them)
	var ma:Float = 1;
	var mb:Float = 0;
	var mc:Float = 0;
	var md:Float = 1;
	var mtx:Int = 0; // twips
	var mty:Int = 0;
	var csx:Float = 1;
	var csy:Float = 1;
	var crot:Float = 0;

	// colorTransform: multipliers (alpha = the alpha property) and offsets (0..255 and beyond)
	var cxm:Array<Float> = null;
	var cxa:Array<Float> = null;
	var alpha8:Float = 1;

	public var visible:Bool = true;

	// moved / coloured by the code: its timeline no longer changes it
	var scripted:Bool = false;

	// timeline instance key (Data), -1 for an object created by the code
	public var tlKey:Int = -1;
	public var tlDepth:Int = 0;
	// filters / blend mode of the timeline (Data.fx index), mask depth
	public var fx:Int = -1;
	public var clipDepth:Int = 0;
	// Config.addGroundShadow: a DropShadowFilter
	public var shadow:Bool = false;
	// the colour of a baked picture (index in Data.PALETTE) for this object and its children (-1: the parent's)
	public var variant:Int = -1;

	public var x(get, set):Float;
	public var y(get, set):Float;
	public var rotation(get, set):Float;
	public var scaleX(get, set):Float;
	public var scaleY(get, set):Float;
	public var alpha(get, set):Float;
	public var width(get, never):Float;
	public var height(get, never):Float;

	public function new() {}

	// ---------------------------------------------------------------- properties
	function get_x():Float {
		return mtx / 20;
	}

	function set_x(v:Float):Float {
		scripted = true;
		mtx = twips(v);
		return v;
	}

	function get_y():Float {
		return mty / 20;
	}

	function set_y(v:Float):Float {
		scripted = true;
		mty = twips(v);
		return v;
	}

	// (Flash: NaN gives 0, the value truncated towards zero)
	static inline function twips(v:Float):Int {
		return Math.isNaN(v) ? 0 : Std.int(v * 20);
	}

	function get_rotation():Float {
		return crot;
	}

	function set_rotation(v:Float):Float {
		scripted = true;
		v = v % 360;
		if (v > 180)
			v -= 360;
		else if (v < -180)
			v += 360;
		crot = v;
		updateMatrix();
		return v;
	}

	function get_scaleX():Float {
		return csx;
	}

	function set_scaleX(v:Float):Float {
		scripted = true;
		csx = v;
		updateMatrix();
		return v;
	}

	function get_scaleY():Float {
		return csy;
	}

	function set_scaleY(v:Float):Float {
		scripted = true;
		csy = v;
		updateMatrix();
		return v;
	}

	function updateMatrix() {
		var r = crot * Math.PI / 180;
		var c = Math.cos(r);
		var s = Math.sin(r);
		ma = csx * c;
		mb = csx * s;
		mc = -csy * s;
		md = csy * c;
	}

	function get_alpha():Float {
		return alpha8;
	}

	// (8.8 fixed point)
	function set_alpha(v:Float):Float {
		scripted = true;
		alpha8 = Std.int(v * 256) / 256;
		return v;
	}

	// transform.colorTransform = new ColorTransform(rm, gm, bm, am, ro, go, bo, ao) (the alpha property is its am)
	public function setColorTransform(rm:Float, gm:Float, bm:Float, am:Float, ro:Float, go:Float, bo:Float, ao:Float) {
		scripted = true;
		cxm = [rm, gm, bm];
		cxa = [ro, go, bo, ao];
		alpha8 = Std.int(am * 256) / 256;
		if (rm == 1 && gm == 1 && bm == 1 && ro == 0 && go == 0 && bo == 0 && ao == 0) {
			cxm = null;
			cxa = null;
		}
	}

	// ColorTransform.color = c: multipliers 0, offsets the colour, alpha 1
	public function setColor(c:Int) {
		setColorTransform(0, 0, 0, 1, (c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF, 0);
	}

	// the timeline places / moves the object
	public function setFromTimeline(a:Float, b:Float, c:Float, d:Float, tx:Float, ty:Float, cx:Array<Float>) {
		if (scripted)
			return;
		ma = a;
		mb = b;
		mc = c;
		md = d;
		mtx = Math.round(tx * 20);
		mty = Math.round(ty * 20);
		csx = Math.sqrt(a * a + b * b);
		csy = Math.sqrt(c * c + d * d);
		if (a * d - b * c < 0)
			csy = -csy;
		crot = Math.atan2(b, a) * 180 / Math.PI;
		if (cx == null) {
			cxm = null;
			cxa = null;
			alpha8 = 1;
		} else {
			cxm = [cx[0], cx[1], cx[2]];
			cxa = [cx[4], cx[5], cx[6], cx[7]];
			alpha8 = cx[3];
		}
	}

	// ---------------------------------------------------------------- matrices and bounds
	public inline function matA():Float
		return ma;

	public inline function matB():Float
		return mb;

	public inline function matC():Float
		return mc;

	public inline function matD():Float
		return md;

	// this object's matrix applied after m (m * own): the matrix from this object to the space of m
	public function concat(m:Mat):Mat {
		return new Mat(m.a * ma + m.c * mb, m.b * ma + m.d * mb, m.a * mc + m.c * md, m.b * mc + m.d * md,
			m.a * (mtx / 20) + m.c * (mty / 20) + m.tx, m.b * (mtx / 20) + m.d * (mty / 20) + m.ty);
	}

	// the matrix from this object to `space` (one of its ancestors, or null: the top of its tree)
	public function matrixTo(space:DisplayObject):Mat {
		var chain:Array<DisplayObject> = [];
		var o = this;
		while (o != null && o != space) {
			chain.push(o);
			o = o.parent;
		}
		if (o != space) {
			// not an ancestor: through the top of the tree
			var mine = matrixTo(null);
			var inv = space.matrixTo(null).invert();
			return inv.mul(mine);
		}
		var m = Mat.ident();
		var i = chain.length - 1;
		while (i >= 0) {
			m = chain[i].concat(m);
			i--;
		}
		return m;
	}

	// getBounds(space) / getRect(space): every picture's rectangle transformed by its whole matrix (Flash)
	public function getBounds(space:DisplayObject):Rect {
		var r = new Rect();
		boundsInto(matrixTo(space), r, false);
		return r.result();
	}

	public function getRect(space:DisplayObject):Rect {
		var r = new Rect();
		boundsInto(matrixTo(space), r, true);
		return r.result();
	}

	public function boundsInto(m:Mat, r:Rect, edges:Bool) {}

	function get_width():Float {
		var r = new Rect();
		boundsInto(concat(Mat.ident()), r, false);
		return r.result().width;
	}

	function get_height():Float {
		var r = new Rect();
		boundsInto(concat(Mat.ident()), r, false);
		return r.result().height;
	}

	// ---------------------------------------------------------------- display (PIXI)
	// views[0]: the picture, views[1]: the picture of the drop shadow of an ancestor (or of this object)
	public var views:Array<ASprite> = [null, null];

	// state of the last two Flash frames: x, y, scaleX, scaleY, rotation, alpha, skew
	var cur:Array<Float> = null;
	var prev:Array<Float> = null;
	var seenFrame:Int = -1;
	var bornFrame:Int = -1;
	// hidden (visible false) at the last snapshot, and the parent then
	var hiddenSnap:Bool = false;
	var parentSnap:Sprite = null;
	// set by the code: the object jumped during this Flash frame, shown at its new state without a slide (an arrow of
	// Game.incomingArrows now pointing at another foe)
	public var jumped:Bool = false;
	// removed during the last Flash frame: still shown, at its last state, until the next one
	public var ghostOf:Sprite = null;

	// end of a Flash frame: keeps the state of the frame before
	public function snapshot() {
		var fresh = seenFrame != flashFrame - 1;
		if (fresh)
			bornFrame = flashFrame;
		seenFrame = flashFrame;
		var old = cur;
		var sx = Math.sqrt(ma * ma + mb * mb);
		var rot = Math.atan2(mb, ma);
		var det = ma * md - mb * mc;
		var sy = Math.sqrt(mc * mc + md * md);
		if (det < 0)
			sy = -sy;
		// skew: the angle of the y axis compared with the one of a rotation
		var skew = 0.0;
		if (sy != 0) {
			var ay = Math.atan2(-mc / sy, md / sy);
			skew = rot - ay;
			while (skew > Math.PI)
				skew -= Math.PI * 2;
			while (skew < -Math.PI)
				skew += Math.PI * 2;
		}
		cur = [mtx / 20, mty / 20, sx, sy, rot, alpha8, skew];
		// (an object added again later, shown again or moved to another parent starts from where it is now: the war
		// zone, moved to the tank while hidden, slid across the screen from the last zone; a dead XBall, moved from
		// the turret to fxLayer, went from its place in the turret's space)
		var wasHidden = hiddenSnap;
		hiddenSnap = !visible;
		var moved = parentSnap != parent;
		parentSnap = parent;
		prev = fresh || old == null || wasHidden || moved || jumped ? cur : old;
		jumped = false;
	}

	// the colour of a picture (Leaf / TextField): multipliers m and offsets a of its parents' colour transforms
	public function syncLeaf(mode:Int, f:Float, m:Array<Float>, a:Array<Float>) {}

	public inline function isFresh():Bool {
		return bornFrame == flashFrame;
	}

	// the filters of the timeline (FlashFilters): set when they change
	var shownFx:Int = -1;

	public function applyFx(v:ASprite) {
		if (fx == shownFx)
			return;
		shownFx = fx;
		var list:Array<pixi.core.renderers.webgl.filters.Filter> = [];
		if (fx >= 0) {
			var F:Dynamic = Data.get().fx[fx];
			var fl:Array<Dynamic> = F.filters;
			for (f in fl) {
				var bx:Float = f.blurX;
				var by:Float = f.blurY;
				var passes:Int = f.passes;
				if (f.type == "blur" && (bx >= 1 || by >= 1))
					list.push(new FlashFilter(bx, by, passes, false));
				else if (f.type == "glow" && f.inner != true) {
					var c:Array<Int> = f.color;
					list.push(new FlashFilter(bx, by, passes, true, (c[0] << 16) | (c[1] << 8) | c[2], f.strength));
				}
			}
		}
		v.filters = list.length > 0 ? cast list : null;
	}

	// blend mode "overlay" of a timeline (the shading of the zone banner over the ground): not drawn
	public function isOverlay():Bool {
		if (fx < 0)
			return false;
		var F:Dynamic = Data.get().fx[fx];
		return F.blend == "overlay";
	}

	public function detachViews() {
		for (v in views)
			if (v != null && v.parent != null)
				v.parent.removeChild(v);
	}

	public function makeView(mode:Int):ASprite {
		return new ASprite();
	}

	public function view(mode:Int):ASprite {
		if (views[mode] == null)
			views[mode] = makeView(mode);
		return views[mode];
	}

	static inline function lerpAngle(a:Float, b:Float, f:Float):Float {
		var d = b - a;
		while (d > Math.PI)
			d -= Math.PI * 2;
		while (d < -Math.PI)
			d += Math.PI * 2;
		return a + d * f;
	}

	// shows the state between the last two Flash frames (f: 0 = the frame before, 1 = the last one)
	public function applyView(mode:Int, f:Float, ox:Float, oy:Float, ghost:Bool, snap:Bool) {
		var v = view(mode);
		var p = prev;
		var c = cur;
		if (c == null)
			return;
		if (ghost)
			c = p = cur;
		var s = v._curState;
		s.x = p[0] + (c[0] - p[0]) * f + ox;
		s.y = p[1] + (c[1] - p[1]) * f + oy;
		s.xscale = p[2] + (c[2] - p[2]) * f;
		// (a scale changing its sign is not interpolated)
		s.yscale = (p[3] < 0) != (c[3] < 0) ? c[3] : p[3] + (c[3] - p[3]) * f;
		s.rotation = lerpAngle(p[4], c[4], f);
		s.alpha = p[5] + (c[5] - p[5]) * f;
		v.skew.x = c[6];
		// (shown again, or for the first time: no slide from where its view was)
		if (snap || v._prevState == null)
			v.updateState();
	}
}

// a matrix (Flash order: x' = a x + c y + tx)
class Mat {
	public var a:Float;
	public var b:Float;
	public var c:Float;
	public var d:Float;
	public var tx:Float;
	public var ty:Float;

	public inline function new(a, b, c, d, tx, ty) {
		this.a = a;
		this.b = b;
		this.c = c;
		this.d = d;
		this.tx = tx;
		this.ty = ty;
	}

	public static inline function ident():Mat {
		return new Mat(1, 0, 0, 1, 0, 0);
	}

	// this * m (m applied first)
	public function mul(m:Mat):Mat {
		return new Mat(a * m.a + c * m.b, b * m.a + d * m.b, a * m.c + c * m.d, b * m.c + d * m.d, a * m.tx + c * m.ty + tx,
			b * m.tx + d * m.ty + ty);
	}

	public function invert():Mat {
		var det = a * d - b * c;
		if (det == 0)
			return new Mat(0, 0, 0, 0, -tx, -ty);
		var ia = d / det;
		var ib = -b / det;
		var ic = -c / det;
		var id = a / det;
		return new Mat(ia, ib, ic, id, -(ia * tx + ic * ty), -(ib * tx + id * ty));
	}
}

// flash.geom.Rectangle, as getBounds builds it
class Rect {
	public var x:Float = 0;
	public var y:Float = 0;
	public var width:Float = 0;
	public var height:Float = 0;

	var x0:Float = Math.POSITIVE_INFINITY;
	var y0:Float = Math.POSITIVE_INFINITY;
	var x1:Float = Math.NEGATIVE_INFINITY;
	var y1:Float = Math.NEGATIVE_INFINITY;

	public function new() {}

	public static function make(x:Float, y:Float, w:Float, h:Float):Rect {
		var r = new Rect();
		r.x = x;
		r.y = y;
		r.width = w;
		r.height = h;
		return r;
	}

	public inline function addPoint(px:Float, py:Float) {
		if (px < x0)
			x0 = px;
		if (px > x1)
			x1 = px;
		if (py < y0)
			y0 = py;
		if (py > y1)
			y1 = py;
	}

	// (twips, like Flash's rectangles; nothing drawn: 0, 0, 0, 0)
	public function result():Rect {
		if (x0 > x1)
			return this;
		x = Math.round(x0 * 20) / 20;
		y = Math.round(y0 * 20) / 20;
		width = Math.round(x1 * 20) / 20 - x;
		height = Math.round(y1 * 20) / 20 - y;
		return this;
	}

	public function isEmpty():Bool {
		return width <= 0 || height <= 0;
	}

	// Rectangle.intersection (empty: 0, 0, 0, 0)
	public function intersection(o:Rect):Rect {
		if (isEmpty() || o.isEmpty())
			return new Rect();
		var ix0 = Math.max(x, o.x);
		var ix1 = Math.min(x + width, o.x + o.width);
		var iy0 = Math.max(y, o.y);
		var iy1 = Math.min(y + height, o.y + o.height);
		if (ix1 <= ix0 || iy1 <= iy0)
			return new Rect();
		return make(ix0, iy0, ix1 - ix0, iy1 - iy0);
	}

	// Rectangle.containsPoint
	public function containsPoint(px:Float, py:Float):Bool {
		return px >= x && px < x + width && py >= y && py < y + height;
	}
}

// flash.display.Sprite (a DisplayObjectContainer)
class Sprite extends DisplayObject {
	public var children:Array<DisplayObject> = [];

	// children removed during the last Flash frame (shown until the next one), with their index
	var ghosts:Array<DisplayObject> = null;
	var ghostIdx:Array<Int> = null;
	var viewDirty:Array<Bool> = [true, true];
	// PIXI pictures of the sprite itself (Gfx: its graphics), under its children
	var ownViews:Array<pixi.core.display.DisplayObject> = null;

	public function new() {
		super();
	}

	public var numChildren(get, never):Int;

	function get_numChildren():Int {
		return children.length;
	}

	public function addChild(c:DisplayObject):DisplayObject {
		if (c.parent != null)
			c.parent.removeChild(c);
		children.push(c);
		attached(c);
		return c;
	}

	public function addChildAt(c:DisplayObject, i:Int):DisplayObject {
		if (c.parent != null)
			c.parent.removeChild(c);
		if (i > children.length)
			throw new FlashError("RangeError: addChildAt");
		children.insert(i, c);
		attached(c);
		return c;
	}

	function attached(c:DisplayObject) {
		untyped c.parent = this;
		dirty();
		if (ghosts != null) {
			var gi = ghosts.indexOf(c);
			if (gi >= 0) {
				ghosts.splice(gi, 1);
				ghostIdx.splice(gi, 1);
			}
		}
	}

	public function removeChild(c:DisplayObject):DisplayObject {
		var i = children.indexOf(c);
		if (i < 0)
			throw new FlashError("ArgumentError: Error #2025: The supplied DisplayObject must be a child of the caller.");
		children.splice(i, 1);
		untyped c.parent = null;
		if (c.cur != null && c.seenFrame >= DisplayObject.flashFrame - 1) {
			// shown (at its last state) until the next Flash frame
			if (ghosts == null) {
				ghosts = [];
				ghostIdx = [];
				withGhosts.push(this);
			}
			ghosts.push(c);
			ghostIdx.push(i);
		} else
			c.detachViews();
		dirty();
		return c;
	}

	public function getChildIndex(c:DisplayObject):Int {
		var i = children.indexOf(c);
		if (i < 0)
			throw new FlashError("ArgumentError: getChildIndex");
		return i;
	}

	public function swapChildren(a:DisplayObject, b:DisplayObject) {
		var ia = getChildIndex(a);
		var ib = getChildIndex(b);
		children[ia] = b;
		children[ib] = a;
		dirty();
	}

	public function contains(c:DisplayObject):Bool {
		var o = c;
		while (o != null) {
			if (o == this)
				return true;
			o = o.parent;
		}
		return false;
	}

	inline function dirty() {
		viewDirty[0] = true;
		viewDirty[1] = true;
	}

	override public function boundsInto(m:Mat, r:Rect, edges:Bool) {
		for (c in children)
			c.boundsInto(c.concat(m), r, edges);
	}

	// ---------------------------------------------------------------- display
	static var withGhosts:Array<Sprite> = [];

	// start of a Flash frame: the objects removed during the last one are no longer shown
	public static function clearGhosts() {
		for (s in withGhosts) {
			if (s.ghosts == null)
				continue;
			for (g in s.ghosts)
				if (g.parent == null)
					g.detachViews();
			s.ghosts = null;
			s.ghostIdx = null;
			s.dirty();
		}
		withGhosts = [];
	}

	public static function resetAll() {
		withGhosts = [];
		DisplayObject.flashFrame = 0;
	}

	// end of a Flash frame: the state of every object
	public function snapshotTree() {
		snapshot();
		for (c in children) {
			var s = Std.downcast(c, Sprite);
			if (s != null)
				s.snapshotTree();
			else
				c.snapshot();
		}
	}


	// shows the tree (mode 0: the pictures, 1: inside a drop shadow); cx: the colour transform of the parents
	public function syncTree(mode:Int, f:Float, cxm:Array<Float>, cxa:Array<Float>, ghost:Bool, snap:Bool) {
		var v = view(mode);
		if (viewDirty[mode]) {
			viewDirty[mode] = false;
			rebuildViews(mode);
		}
		for (c in children)
			syncChild(c, mode, f, cxm, cxa, ghost, snap);
		if (ghosts != null)
			for (g in ghosts)
				syncChild(g, mode, f, cxm, cxa, true, snap);
	}

	function syncChild(c:DisplayObject, mode:Int, f:Float, pm:Array<Float>, pa:Array<Float>, ghost:Bool, snap:Bool) {
		// the colour transform of the child: its own applied first, then the parents'
		var m = pm;
		var a = pa;
		if (c.cxm != null) {
			m = [c.cxm[0] * pm[0], c.cxm[1] * pm[1], c.cxm[2] * pm[2]];
			a = [c.cxa[0] * pm[0] + pa[0], c.cxa[1] * pm[1] + pa[1], c.cxa[2] * pm[2] + pa[2], 0];
		}
		var hide = !c.visible || (c.isFresh() && !ghost);
		if (c.shadow && mode == 0) {
			// the drop shadow: 1 pixel down-right of the stage (the filter is in stage pixels)
			var sv = c.view(1);
			var sn = snap || !sv.visible;
			sv.visible = !hide;
			if (!hide) {
				var o = shadowOffset();
				c.applyView(1, f, o.x, o.y, ghost, sn);
				var s = Std.downcast(c, Sprite);
				if (s != null)
					s.syncTree(1, f, [1, 1, 1], [0, 0, 0, 0], ghost, sn);
				else
					c.syncLeaf(1, f, [1, 1, 1], [0, 0, 0, 0]);
			}
		}
		var v = c.view(mode);
		var sn = snap || !v.visible;
		if (c.isOverlay())
			hide = true;
		v.visible = !hide;
		if (hide)
			return;
		c.applyView(mode, f, 0, 0, ghost, sn);
		if (mode == 0)
			c.applyFx(v);
		var s = Std.downcast(c, Sprite);
		if (s != null)
			s.syncTree(mode, f, m, a, ghost, sn);
		else
			c.syncLeaf(mode, f, m, a);
	}

	// (stage pixels in this container: the inverse of its linear matrix to the top)
	function shadowOffset():{x:Float, y:Float} {
		var m = matrixTo(null);
		var inv = new Mat(m.a, m.b, m.c, m.d, 0, 0).invert();
		var k = Math.sqrt(0.5);
		return {x: inv.a * k + inv.c * k, y: inv.b * k + inv.d * k};
	}

	// the views of the children in the order of the display list (masks: the masked children in a group)
	function rebuildViews(mode:Int) {
		var v = view(mode);
		var list:Array<DisplayObject> = children.copy();
		if (ghosts != null) {
			// (in the reverse order of the removals: each index was taken once the children removed before were gone;
			// in the order of the removals, the burger's three pictures removed at index 0 came back upside down)
			var k = ghosts.length - 1;
			while (k >= 0) {
				list.insert(Std.int(Math.min(ghostIdx[k], list.length)), ghosts[k]);
				k--;
			}
		}
		// (the sprite's own pictures first: its graphics)
		var wanted:Array<pixi.core.display.DisplayObject> = ownViews != null ? ownViews.copy() : [];
		var group:ASprite = null;
		var groupEnd = -1;
		for (c in list) {
			// (a shadowed object inside a shadow: its own shadow is not drawn again, see syncChild)
			if (group != null && (c.tlKey < 0 || c.tlDepth > groupEnd))
				group = null;
			if (c.shadow && mode == 0) {
				if (group != null)
					wantedGroup(group, c.view(1));
				else
					wanted.push(c.view(1));
			}
			var cv = c.view(mode);
			if (group != null)
				wantedGroup(group, cv);
			else
				wanted.push(cv);
			if (c.clipDepth > 0) {
				// the next children up to clipDepth are drawn through this one
				group = maskGroup(c, mode);
				groupEnd = c.clipDepth;
				wanted.push(group);
			}
		}
		// (re)attach in order
		for (ch in v.children.copy())
			if (wanted.indexOf(ch) < 0)
				v.removeChild(ch);
		for (i in 0...wanted.length) {
			var w = wanted[i];
			if (w.parent != v || v.getChildIndex(w) != i) {
				if (w.parent != null)
					w.parent.removeChild(w);
				v.addChildAt(w, Std.int(Math.min(i, v.children.length)));
			}
		}
	}

	var groups:Map<DisplayObject, ASprite> = null;

	function maskGroup(maskObj:DisplayObject, mode:Int):ASprite {
		if (groups == null)
			groups = new Map();
		var g = groups.get(maskObj);
		if (g == null) {
			g = new ASprite();
			groups.set(maskObj, g);
		}
		for (ch in g.children.copy())
			g.removeChild(ch);
		var ms:PSprite = cast maskSprite(maskObj, mode);
		g.filters = ms != null ? [new MaskFilter(ms)] : null;
		return g;
	}

	function wantedGroup(g:ASprite, v:ASprite) {
		if (v.parent != null)
			v.parent.removeChild(v);
		g.addChild(v);
	}

	// the picture a mask draws with (the first leaf under it)
	static function maskSprite(o:DisplayObject, mode:Int):pixi.core.display.DisplayObject {
		var l = Std.downcast(o, Leaf);
		if (l != null)
			return l.maskPicture(mode);
		var s = Std.downcast(o, Sprite);
		if (s != null)
			for (c in s.children) {
				var r = maskSprite(c, mode);
				if (r != null)
					return r;
			}
		return null;
	}
}

// an error the Flash player would have thrown: the rest of the frame's code is skipped (Game.flashFrame)
class FlashError {
	public var msg:String;

	public function new(m:String) {
		msg = m;
	}

	public function toString():String {
		return msg;
	}
}
