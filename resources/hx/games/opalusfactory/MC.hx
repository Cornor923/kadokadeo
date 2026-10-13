package opalusfactory;

import pixi.core.Pixi.BlendModes;
import pixi.filters.alpha.AlphaFilter;

/**
 * A MovieClip attached by the game code (DepthManager.attach / empty, attachMovie, createEmptyMovieClip): the Flash
 * properties the code reads and writes (_x / _y truncated to twips like Flash, _xscale, _rotation, _alpha...) and the
 * Clip that draws it.
 *
 * Flash rules the code relies on: a removed clip reads undefined (NaN in a calculation) and ignores what is written
 * to it; a number that is not finite written to _x, _y, _rotation or a scale is ignored.
 *
 * Nested clips (a case in its line, a coin in its case, the nuts in blockHole._empty): `posK` is the number of pixels
 * of the parent per Flash pixel (1 in an empty clip, K x the resolution of the parent's pictures in a picture).
 *
 * Display: Opalus Factory ran at 40 Flash frames/s and KadoKadeo steps 32 times per second, so a step plays 1 or 2
 * Flash frames (Game.update). Like Linea, Hexile and Cosmo Crash, every clip shows its state one Flash frame ago,
 * interpolated towards the last one by the fraction of a Flash frame the steps are behind (displayAll): the game moves
 * by exactly 1.25 Flash frames per step. The pictures of the timelines are the current ones.
 */
class MC {
	public static var all:Array<MC> = [];

	public var clip(default, null):Clip;

	public var _x(get, set):Float;
	public var _y(get, set):Float;
	public var _xscale(get, set):Float;
	public var _yscale(get, set):Float;
	public var _rotation(get, set):Float;
	public var _alpha(get, set):Float;
	public var _visible(get, set):Bool;
	public var _currentframe(get, never):Int;
	public var _totalframes(get, never):Int;

	// removeMovieClip() was called (by the code, a frame script or the removal of its parent): Flash's _name == null
	public var removed(default, null):Bool = false;

	// the mt.bumdum.Sprite driving the clip (mc.obj)
	public var obj:Sprite;

	// pixels of the parent per Flash pixel
	public var posK:Float = 1;

	// the alpha is applied to the clip drawn as a whole (a clip with a filter: Flash draws it into a bitmap, then
	// applies its _alpha), not to each picture inside
	public var groupAlpha:Bool = false;

	var alphaFilter:AlphaFilter;

	// clips attached in this one: removed with it
	var kids:Array<MC> = null;

	var x:Float = 0;
	var y:Float = 0;
	var xs:Float = 100;
	var ys:Float = 100;
	var rot:Float = 0;
	var alpha:Float = 100;
	var vis:Bool = true;

	// state of the previous Flash frame (display)
	var fresh:Bool = true;
	// shown from the step it is attached in (showAtOnce)
	var atOnce:Bool = false;
	var snap:Bool = false;
	var px:Float = 0;
	var py:Float = 0;
	var pxs:Float = 100;
	var pys:Float = 100;
	var prot:Float = 0;
	var pa:Float = 100;

	public function new(name:String, ?posK:Float = 1) {
		this.posK = posK;
		clip = new Clip(name, posK);
		clip.owner = this;
		all.push(this);
	}

	// ---------------------------------------------------------------- Flash properties
	function get__x():Float {
		return removed ? Math.NaN : x;
	}

	function set__x(v:Float):Float {
		if (!removed && Math.isFinite(v))
			x = twips(v);
		return v;
	}

	function get__y():Float {
		return removed ? Math.NaN : y;
	}

	function set__y(v:Float):Float {
		if (!removed && Math.isFinite(v))
			y = twips(v);
		return v;
	}

	function get__xscale():Float {
		return removed ? Math.NaN : xs;
	}

	function set__xscale(v:Float):Float {
		if (!removed && Math.isFinite(v))
			xs = v;
		return v;
	}

	function get__yscale():Float {
		return removed ? Math.NaN : ys;
	}

	function set__yscale(v:Float):Float {
		if (!removed && Math.isFinite(v))
			ys = v;
		return v;
	}

	function get__rotation():Float {
		return removed ? Math.NaN : rot;
	}

	// Flash keeps the rotation of the matrix, read back in ]-180, 180]
	function set__rotation(v:Float):Float {
		if (removed || !Math.isFinite(v))
			return v;
		v = v % 360;
		if (v > 180)
			v -= 360;
		else if (v <= -180)
			v += 360;
		rot = v;
		return v;
	}

	function get__alpha():Float {
		return removed ? Math.NaN : alpha;
	}

	function set__alpha(v:Float):Float {
		if (!removed && Math.isFinite(v))
			alpha = v;
		return v;
	}

	function get__visible():Bool {
		return !removed && vis;
	}

	function set__visible(v:Bool):Bool {
		if (!removed)
			vis = v;
		return v;
	}

	// a move that is not shown as a move (a sprite parked off screen placed by its first update): not interpolated
	public function teleport(nx:Float, ny:Float):Void {
		if (removed)
			return;
		_x = nx;
		_y = ny;
		px = x;
		py = y;
		snap = true;
	}

	// a clip that takes the place of one the code just removed (the coins of a play flying to their hole, the coins
	// falling off the roll): shown at once where it is, or nothing is shown there for a step
	public function showAtOnce():Void {
		atOnce = true;
	}

	public static inline function twips(v:Float):Float {
		return Std.int(v * 20) / 20;
	}

	// (undefined for a removed clip: -1 is never equal to a frame)
	function get__currentframe():Int {
		return removed ? -1 : clip.frame;
	}

	function get__totalframes():Int {
		return clip.def.n;
	}

	public function gotoAndStop(f:Dynamic):Void {
		if (!removed)
			clip.gotoAndStop(f);
	}

	public function gotoAndPlay(f:Dynamic):Void {
		if (!removed)
			clip.gotoAndPlay(f);
	}

	public function play():Void {
		if (!removed)
			clip.play();
	}

	public function stop():Void {
		if (!removed)
			clip.stop();
	}

	// a named nested clip (null when it is not on the current frame, or when this clip is removed): mc.sub
	public function sub(name:String):Clip {
		return removed ? null : clip.getClip(name);
	}

	// mc.sub._x = ... (Flash pixels of this clip)
	public function setSub(name:String, ?x:Float, ?y:Float, ?xscale:Float, ?yscale:Float, ?rotation:Float) {
		if (!removed)
			clip.setSub(name, x, y, xscale, yscale, rotation);
	}

	public function subX(name:String):Float {
		return removed ? Math.NaN : clip.subX(name);
	}

	public function subY(name:String):Float {
		return removed ? Math.NaN : clip.subY(name);
	}

	// mc.sub._visible = v
	public function setSubVisible(name:String, v:Bool) {
		if (!removed)
			clip.setVisible(name, v);
	}

	// mc.blendMode = "add"
	public function blendAdd() {
		if (!removed)
			clip.setBlend(BlendModes.ADD);
	}

	// mc.attachMovie(name, ...) / mc.createEmptyMovieClip(...): a clip in this one, on top of what it holds
	public function attach(name:String):MC {
		var k = clip.def.r == 0.5 && clip.def.layers.length == 0 ? 1.0 : Clip.K * clip.def.r;
		var m = new MC(name, k);
		clip.addChild(m.clip);
		addKid(m);
		return m;
	}

	// a clip attached in a picture of this one (blockHole._empty): `into` holds it, posK pixels per Flash pixel
	public function attachIn(into:common_haxe_avm1.display.ASprite, name:String, k:Float):MC {
		var m = new MC(name, k);
		into.addChild(m.clip);
		addKid(m);
		return m;
	}

	public function removeMovieClip():Void {
		if (removed)
			return;
		removed = true;
		if (kids != null)
			for (k in kids)
				k.removeMovieClip();
		clip.removeMovieClip();
		clip.destroy({children: true});
	}

	public function addKid(m:MC) {
		if (kids == null)
			kids = [];
		kids.push(m);
	}

	// ---------------------------------------------------------------- Flash frames and display
	// a Flash frame starts: the state shown keeps the last one, every timeline advances (before the code runs), then
	// the clips removed by their frame scripts are taken out
	public static function frameStart():Void {
		var i = 0;
		while (i < all.length) {
			var m = all[i];
			if (m.removed) {
				all.splice(i, 1);
				continue;
			}
			m.fresh = false;
			m.px = m.x;
			m.py = m.y;
			m.pxs = m.xs;
			m.pys = m.ys;
			m.prot = m.rot;
			m.pa = m.alpha;
			i++;
		}
		// (only the clips at the top of a tree: Clip.tick advances the nested ones first)
		for (m in all.copy())
			if (!m.removed && !Std.isOfType(m.clip.parent, Clip))
				m.clip.tick();
		Clip.flushRemoved();
	}

	public static function displayAll(f:Float):Void {
		for (m in all)
			if (!m.removed)
				m.display(f);
	}

	// the alpha shown (0..100), after display
	public var shownAlpha(default, null):Float = 100;
	public var shownYScale(default, null):Float = 100;

	function display(f:Float):Void {
		var s = clip;
		// attached during the last Flash frame: the picture shown is still before it (f = 1: the start of the game);
		// shown from the next step, not interpolated from where it was created
		var hide = fresh && f < 1 && !atOnce;
		if (fresh)
			f = 1;
		s._x = (px + (x - px) * f) * posK;
		s._y = (py + (y - py) * f) * posK;
		s._xscale = pxs + (xs - pxs) * f;
		shownYScale = pys + (ys - pys) * f;
		s._yscale = shownYScale;
		var dr = rot - prot;
		if (dr > 180)
			dr -= 360;
		else if (dr < -180)
			dr += 360;
		s._rotation = prot + dr * f;
		var a = pa + (alpha - pa) * f;
		a = a < 0 ? 0 : a > 100 ? 100 : a;
		shownAlpha = a;
		if (groupAlpha) {
			s._alpha = 100;
			if (a < 100) {
				if (alphaFilter == null)
					alphaFilter = new AlphaFilter(1);
				alphaFilter.alpha = a / 100;
				if (s.filters == null || s.filters.indexOf(alphaFilter) < 0)
					s.filters = (s.filters == null ? [] : s.filters.filter(x -> x != alphaFilter)).concat([alphaFilter]);
			} else if (alphaFilter != null && s.filters != null && s.filters.indexOf(alphaFilter) >= 0) {
				var l = s.filters.filter(x -> x != alphaFilter);
				s.filters = l.length == 0 ? null : l;
			}
		} else {
			s._alpha = a;
		}
		if (snap && s._prevState != null)
			s._prevState.copyFrom(s._curState);
		snap = hide;
		s.visible = vis && !hide && !s.selfRemoved;
	}

	public static function clearAll():Void {
		for (m in all.copy())
			m.removeMovieClip();
		all = [];
	}
}

// the planes of the original DepthManager (mt.DepthManager of Flash 8): one container per plane, the clips in the
// order they were attached (the last on top)
class Plans {
	var root:common_haxe_avm1.display.ASprite;
	var owner:MC;
	// the planes under `split` are in `low` (a child of root drawn under the others: Game's overlay of the tapi)
	var low:common_haxe_avm1.display.ASprite;
	var split:Int;
	var plans:Map<Int, common_haxe_avm1.display.ASprite> = new Map();
	var order:Array<Int> = [];

	public function new(root:common_haxe_avm1.display.ASprite, ?owner:MC, ?low:common_haxe_avm1.display.ASprite, ?split:Int = 0) {
		this.root = root;
		this.owner = owner;
		this.low = low;
		this.split = split;
	}

	// (a plane may be negative: Flash depths plan * 1000 + n)
	public function get(plan:Int):common_haxe_avm1.display.ASprite {
		var p = plans.get(plan);
		if (p == null) {
			p = new common_haxe_avm1.display.ASprite();
			var parent = low != null && plan < split ? low : root;
			var at = 0;
			if (parent == root && low != null)
				at = root.getChildIndex(low) + 1;
			for (i in order)
				if (i < plan && plans.get(i).parent == parent)
					at = Std.int(Math.max(at, parent.getChildIndex(plans.get(i)) + 1));
			parent.addChildAt(p, at);
			plans.set(plan, p);
			order.push(plan);
		}
		return p;
	}

	public function attach(name:String, plan:Int):MC {
		var mc = new MC(name);
		get(plan).addChild(mc.clip);
		if (owner != null)
			owner.addKid(mc);
		return mc;
	}

	// DepthManager.empty: an empty clip
	public function empty(plan:Int):MC {
		return attach(Clip.EMPTY, plan);
	}

	// DepthManager.swap: the clip moves to the top of another plane
	public function swap(mc:MC, plan:Int) {
		var p = get(plan);
		if (mc.clip.parent == p)
			return;
		if (mc.clip.parent != null)
			mc.clip.parent.removeChild(mc.clip);
		p.addChild(mc.clip);
	}
}
