package quadrikolor;

/**
 * A MovieClip attached by the game code (DepthManager.attach): the Flash properties the code reads and writes
 * (_x / _y truncated to twips like Flash, _xscale, _rotation, _alpha...) and the Clip that draws it.
 *
 * Flash rules the code relies on: a removed clip reads undefined (NaN in a calculation) and ignores what is written
 * to it; a number that is not finite written to _x, _y, _rotation or a scale is ignored.
 *
 * Display: Quadrikolor ran at 40 Flash frames/s and KadoKadeo steps 32 times per second, so a step plays 1 or 2 Flash
 * frames (Game.update). Like Linea, Magmax, Cosmo Crash and Cereal Punk, every clip shows its state one Flash frame ago,
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

	// removeMovieClip() was called (by the code or a frame script): Flash's _name == null
	public var removed(default, null):Bool = false;

	var x:Float = 0;
	var y:Float = 0;
	var xs:Float = 100;
	var ys:Float = 100;
	var rot:Float = 0;
	var alpha:Float = 100;
	var vis:Bool = true;

	// state of the previous Flash frame (display)
	var fresh:Bool = true;
	// made visible again by the code during the last Flash frame (shown at once, not slid from where it was hidden)
	var shown:Bool = false;
	var snap:Bool = false;
	// moved at once by the code (teleport) or shown again: no interpolation at the next display (shown is cleared by
	// the second Flash frame of a step, this is not)
	var jumped:Bool = false;
	var px:Float = 0;
	var py:Float = 0;
	var pxs:Float = 100;
	var pys:Float = 100;
	var prot:Float = 0;
	var pa:Float = 100;

	public function new(name:String) {
		clip = new Clip(name);
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
		if (!removed) {
			if (v && !vis) {
				shown = true;
				jumped = true;
			}
			vis = v;
		}
		return v;
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

	public function stop():Void {
		if (!removed)
			clip.stop();
	}

	// a named nested clip (null when it is not on the current frame, or when this clip is removed): mc.sub
	public function sub(name:String):Clip {
		return removed ? null : clip.getClip(name);
	}

	// Std.attachMC(this, name, depth): a clip inside this one (above the ones attached before)
	public function attachMC(name:String):MC {
		var m = new MC(name);
		if (!removed)
			clip.addChild(m.clip);
		return m;
	}

	public function removeMovieClip():Void {
		if (removed)
			return;
		removed = true;
		clip.removeMovieClip();
		clip.destroy({children: true});
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
			m.shown = false;
			m.px = m.x;
			m.py = m.y;
			m.pxs = m.xs;
			m.pys = m.ys;
			m.prot = m.rot;
			m.pa = m.alpha;
			i++;
		}
		for (m in all.copy())
			if (!m.removed)
				m.clip.tick();
		Clip.flushRemoved();
	}

	// the code moved it at once and its picture already draws it where it was (a teleport): no
	// lag nor interpolation of the position, or the picture is offset again by the part of the move not yet shown
	public function teleport():Void {
		px = x;
		py = y;
		jumped = true;
	}

	// the clip and the nested clips its timeline places : shown as they are now
	static function snapTree(s:common_haxe_avm1.display.ASprite):Void {
		if (s._prevState != null)
			s._prevState.copyFrom(s._curState);
		for (c in s.children)
			if (Std.isOfType(c, common_haxe_avm1.display.ASprite))
				snapTree(cast c);
	}

	public static function displayAll(f:Float):Void {
		for (m in all)
			if (!m.removed)
				m.display(f);
	}

	function display(f:Float):Void {
		var s = clip;
		// attached (or shown again) during the last Flash frame: the picture shown is still before it (f = 1: the start
		// of the game); shown from the next step, not interpolated from where it was created
		var hide = (fresh || shown) && f < 1;
		if (fresh || shown)
			f = 1;
		s._x = px + (x - px) * f;
		s._y = py + (y - py) * f;
		// a flip is instant in Flash: not interpolated (the holes are attached flipped)
		s._xscale = pxs * xs < 0 ? xs : pxs + (xs - pxs) * f;
		s._yscale = pys * ys < 0 ? ys : pys + (ys - pys) * f;
		var dr = rot - prot;
		if (dr > 180)
			dr -= 360;
		else if (dr < -180)
			dr += 360;
		s._rotation = prot + dr * f;
		var a = pa + (alpha - pa) * f;
		s._alpha = a < 0 ? 0 : a > 100 ? 100 : a;
		if (snap || jumped)
			snapTree(s);
		snap = hide;
		jumped = false;
		s.visible = vis && !hide && !s.selfRemoved;
	}

	// the last attached first: a score line is inside its sheet (attached after it), destroyed with its children
	public static function clearAll():Void {
		var list = all.copy();
		list.reverse();
		for (m in list)
			m.removeMovieClip();
		all = [];
	}
}

// the planes of the original DepthManager: one container per plane, the clips in the order they were attached (the
// last on top)
class Plans {
	var root:common_haxe_avm1.display.ASprite;
	var plans:Array<common_haxe_avm1.display.ASprite> = [];

	public function new(root:common_haxe_avm1.display.ASprite) {
		this.root = root;
	}

	public function get(plan:Int):common_haxe_avm1.display.ASprite {
		while (plans.length <= plan)
			plans.push(null);
		if (plans[plan] == null) {
			var p = new common_haxe_avm1.display.ASprite();
			var at = 0;
			for (i in 0...plan)
				if (plans[i] != null)
					at = root.getChildIndex(plans[i]) + 1;
			root.addChildAt(p, at);
			plans[plan] = p;
		}
		return plans[plan];
	}

	public function attach(name:String, plan:Int):MC {
		return add(new MC(name), plan);
	}

	// an empty clip (fiche: the score sheet)
	public function empty(plan:Int):MC {
		return add(new MC(Clip.EMPTY), plan);
	}

	public function add<T:MC>(mc:T, plan:Int):T {
		get(plan).addChild(mc.clip);
		return mc;
	}
}
