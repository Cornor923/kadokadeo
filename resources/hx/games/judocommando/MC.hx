package judocommando;

import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.Texture;
import pixi.filters.colormatrix.ColorMatrixFilter;

/**
 * A MovieClip of the original code: an attached symbol (its Clip) or an empty clip (DepthManager.empty, a container
 * with its own planes), with the Flash properties the code reads and writes (_x / _y truncated to twips like Flash,
 * _xscale, _rotation, _alpha, _visible...).
 *
 * Flash rules the code relies on: a removed clip reads undefined (_visible is false: Hero.update releases a monster
 * that was removed) and ignores what is written to it; a number that is not finite written to a property is ignored.
 *
 * Display: Judo Commando ran at 40 Flash frames/s and KadoKadeo steps 32 times per second, so a step plays 1 or 2
 * Flash frames (Game.update). Showing the last Flash frame of each step would make everything jerk (1, 1, 1, 2
 * frames per step); like Linea, Paradice and Schizo Fuzz, every clip shows its state one Flash frame ago,
 * interpolated towards the last one by the fraction of a Flash frame the steps are behind (displayAll). The pictures
 * of the timelines are the current ones.
 */
class MC {
	public static var all:Array<MC> = [];

	// a move longer than this between two Flash frames is not interpolated (pixels of the parent): a safety net for the
	// jumps the code makes (Game.decale shifts the level by 650 px, the map 1300), above the fastest moves of the game (a
	// fall from the tower reaches ~40 px a frame, the map following it at x2): snapped, the map of a fall would jump
	// while the hero inside it is interpolated
	static inline var SNAP = 200;

	// _x loops over this period (a scrolling plane, Num.sMod): the move shown takes the short way, not back across
	public var wrapX:Float = 0;
	// shown as soon as it is attached (the HUD clips the code attaches again at each update, the gems every frame of
	// their effect: hidden for a step like a new clip, the old ones already removed, they would blink)
	public var showAtOnce:Bool = false;

	// the attached symbol (null: an empty clip)
	public var clip(default, null):Clip;
	// what is drawn: the clip, or the container of an empty clip
	public var spr(default, null):ASprite;
	// the planes of an empty clip (new mt.DepthManager(mc))
	public var dm(get, null):DM;

	// the mt.bumdum.Sprite driving the clip (obj.kill() of the frame scripts)
	public var obj:Sprite;

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
	var snap:Bool = false;
	// teleport() during the current Flash frame
	public var cut(default, null):Bool = false;
	var px:Float = 0;
	var py:Float = 0;
	var pxs:Float = 100;
	var pys:Float = 100;
	var prot:Float = 0;
	var pa:Float = 100;

	// colour transform (Color.setTransform): multipliers in percent, offsets in 0..255, rounded like Flash
	var colMul:Array<Int> = null;
	var colAdd:Array<Int> = null;
	var colFilter:ColorMatrixFilter;
	// the pictures of the clip are white: a colour transform is a multiplied colour (no filter)
	public var whiteTint:Bool = false;

	public var parentMC(default, null):MC;
	var _dm:DM;

	public function new(?name:String) {
		if (name != null) {
			clip = new Clip(name);
			clip.owner = this;
			spr = clip;
		} else {
			spr = new ASprite();
		}
		all.push(this);
	}

	function get_dm():DM {
		if (_dm == null)
			_dm = new DM(this);
		return _dm;
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

	public static inline function twips(v:Float):Float {
		return Std.int(v * 20) / 20;
	}

	// (undefined for a removed clip: -1 is never equal to a frame)
	function get__currentframe():Int {
		return removed || clip == null ? -1 : clip.frame;
	}

	function get__totalframes():Int {
		return clip == null ? 1 : clip.def.n;
	}

	public function gotoAndStop(f:Dynamic):Void {
		if (!removed && clip != null)
			clip.gotoAndStop(f);
	}

	public function gotoAndPlay(f:Dynamic):Void {
		if (!removed && clip != null)
			clip.gotoAndPlay(f);
	}

	public function play():Void {
		if (!removed && clip != null)
			clip.play();
	}

	public function stop():Void {
		if (!removed && clip != null)
			clip.stop();
	}

	// a named nested clip (null when it is not on the current frame, or when this clip is removed): mc.smc
	public function sub(name:String):Clip {
		return removed || clip == null ? null : clip.getClip(name);
	}

	// mc.smc.smc
	public function sub2(a:String, b:String):Clip {
		var s = sub(a);
		return s == null ? null : s.getClip(b);
	}

	// attachBitmap: a picture drawn by the game (a render texture)
	public function attachBitmap(t:Texture):PixiSprite {
		var s = new PixiSprite(t);
		untyped s.roundPixels = true;
		spr.addChild(s);
		return s;
	}

	public function removeMovieClip():Void {
		if (removed)
			return;
		removed = true;
		if (_dm != null)
			_dm.removeAll();
		if (parentMC != null && parentMC._dm != null)
			parentMC._dm.forget(this);
		if (spr.parent != null)
			spr.parent.removeChild(spr);
		spr.destroy({children: true});
	}

	// ---------------------------------------------------------------- colour (mt.bumdum.Col of the original)
	// Col.setPercentColor(mc, prc, col, inc): (100 - prc)% of the colour + prc% of col (+ inc)
	public function setPercentColor(prc:Float, col:Int, ?inc:Float = 0) {
		var m = Std.int(100 - prc);
		var c = prc / 100;
		setTransform([m, m, m], [Std.int(c * (col >> 16) + inc), Std.int(c * ((col >> 8) & 0xFF) + inc), Std.int(c * (col & 0xFF) + inc)]);
	}

	// Col.setColor(mc, col, dec = -255): the colour kept, col + dec added (0x00FF00: only the green)
	public function setColor(col:Int, ?dec:Int = -255) {
		setTransform([100, 100, 100], [Std.int((col >> 16) + dec), Std.int(((col >> 8) & 0xFF) + dec), Std.int((col & 0xFF) + dec)]);
	}

	function setTransform(mul:Array<Int>, add:Array<Int>) {
		if (removed)
			return;
		var id = mul[0] == 100 && mul[1] == 100 && mul[2] == 100 && add[0] == 0 && add[1] == 0 && add[2] == 0;
		if (whiteTint && clip != null) {
			var t = 0;
			for (i in 0...3) {
				var v = Math.round(255 * mul[i] / 100 + add[i]);
				t = (t << 8) | (v < 0 ? 0 : v > 255 ? 255 : v);
			}
			clip.setTint(t);
			return;
		}
		if (id) {
			if (colFilter != null && spr.filters != null)
				spr.filters = null;
			colMul = null;
			return;
		}
		if (colMul != null && colMul.join(",") == mul.join(",") && colAdd.join(",") == add.join(","))
			return;
		colMul = mul;
		colAdd = add;
		if (colFilter == null) {
			colFilter = new ColorMatrixFilter();
			var r:Dynamic = KadoKadeoManager.kkm.renderer;
			if (r != null)
				untyped colFilter.resolution = r.resolution;
		}
		var m = [for (v in mul) v / 100];
		var a = [for (v in add) v / 255];
		colFilter.matrix = [m[0], 0, 0, 0, a[0], 0, m[1], 0, 0, a[1], 0, 0, m[2], 0, a[2], 0, 0, 0, 1, 0];
		spr.filters = [colFilter];
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
			// a jump in the Flash frame that ends, not shown yet (two Flash frames in a step): the state PIXI interpolates
			// from is dropped at the next display, or it would cross the screen during the step
			if (m.cut || m.jumped())
				m.snap = true;
			m.cut = false;
			m.px = m.x;
			m.py = m.y;
			m.pxs = m.xs;
			m.pys = m.ys;
			m.prot = m.rot;
			m.pa = m.alpha;
			i++;
		}
		for (m in all.copy())
			if (!m.removed && m.clip != null)
				m.clip.tick();
		Clip.flushRemoved();
	}

	// the move of the current Flash frame is one the code makes at once (the level shifted by Game.decale, the camera
	// on a new focus, the hero put on the square he climbs to while his animation starts from the old one): shown at
	// once, wherever the clip is at the end of the frame
	public function teleport():Void {
		if (!removed)
			cut = true;
	}

	inline function jumped():Bool {
		var dx = x - px;
		if (wrapX > 0) {
			if (dx > wrapX / 2)
				dx -= wrapX;
			else if (dx < -wrapX / 2)
				dx += wrapX;
		}
		return Math.abs(dx) > SNAP || Math.abs(y - py) > SNAP;
	}

	public static function displayAll(f:Float):Void {
		for (m in all)
			if (!m.removed)
				m.display(f);
	}

	function display(f:Float):Void {
		var s = spr;
		// attached during the last Flash frame: the picture shown is still before it (f = 1: the start of the game);
		// shown from the next step, not interpolated from where it was created
		var hide = fresh && f < 1 && !showAtOnce;
		if (fresh)
			f = 1;
		var dx = x - px;
		if (wrapX > 0) {
			if (dx > wrapX / 2)
				dx -= wrapX;
			else if (dx < -wrapX / 2)
				dx += wrapX;
		}
		// a jump (a teleport, a move too long to come from the game): shown at once
		var jump = cut || jumped();
		if (jump)
			f = 1;
		var nx = px + dx * f;
		if (wrapX > 0)
			nx = ((nx % wrapX) + wrapX) % wrapX;
		s._x = nx;
		s._y = py + (y - py) * f;
		// a scale that changes its sign is a flip (setSens: _xscale -100 / 100), instant in Flash: interpolated, the
		// picture would be squeezed flat for a step (the rotation of a held body turns with it)
		var flip = pxs * xs < 0 || pys * ys < 0;
		var fs = flip ? 1 : f;
		s._xscale = pxs + (xs - pxs) * fs;
		s._yscale = pys + (ys - pys) * fs;
		var dr = rot - prot;
		if (dr > 180)
			dr -= 360;
		else if (dr < -180)
			dr += 360;
		s._rotation = prot + dr * fs;
		var a = pa + (alpha - pa) * f;
		s._alpha = a < 0 ? 0 : a > 100 ? 100 : a;
		var ps = s._prevState;
		if (ps != null) {
			var cs = s._curState;
			if (snap || jump)
				ps.copyFrom(cs);
			else {
				// the same between two steps (the flip may be in the first of the two Flash frames of a step)
				if (ps.xscale * cs.xscale < 0 || ps.yscale * cs.yscale < 0) {
					ps.xscale = cs.xscale;
					ps.yscale = cs.yscale;
					ps.rotation = cs.rotation;
				}
				// the position shown looped since the last step: the state PIXI interpolates from loops with it
				if (wrapX > 0) {
					var d = cs.x - ps.x;
					if (d > wrapX / 2)
						ps.x += wrapX;
					else if (d < -wrapX / 2)
						ps.x -= wrapX;
				}
			}
		}
		snap = hide;
		cut = false;
		s.visible = vis && !hide && (clip == null || !clip.selfRemoved);
	}

	public static function clearAll():Void {
		for (m in all.copy())
			m.removeMovieClip();
		all = [];
	}
}

// mt.DepthManager of an empty clip: one container per plane (depth), the clips of a plane in attach order
class DM {
	var owner:MC;
	var plans:Array<ASprite> = [];
	var lists:Array<Array<MC>> = [];

	public function new(owner:MC) {
		this.owner = owner;
	}

	function get(plan:Int):ASprite {
		while (plans.length <= plan) {
			plans.push(null);
			lists.push(null);
		}
		if (plans[plan] == null) {
			var p = new ASprite();
			var at = 0;
			for (i in 0...plan)
				if (plans[i] != null)
					at = owner.spr.getChildIndex(plans[i]) + 1;
			owner.spr.addChildAt(p, at);
			plans[plan] = p;
			lists[plan] = [];
		}
		return plans[plan];
	}

	function add(mc:MC, plan:Int):MC {
		get(plan).addChild(mc.spr);
		lists[plan].push(mc);
		untyped mc.parentMC = owner;
		return mc;
	}

	public function attach(name:String, plan:Int):MC {
		return add(new MC(name), plan);
	}

	public function empty(plan:Int):MC {
		return add(new MC(), plan);
	}

	// on top of the other clips of its plane
	public function over(mc:MC):Void {
		var p = mc.spr.parent;
		if (p != null)
			p.setChildIndex(mc.spr, p.children.length - 1);
		for (l in lists)
			if (l != null && l.remove(mc))
				l.push(mc);
	}

	// every clip of a plane removed
	public function clear(plan:Int):Void {
		if (plan >= lists.length || lists[plan] == null)
			return;
		for (mc in lists[plan].copy())
			mc.removeMovieClip();
		lists[plan] = [];
	}

	public function forget(mc:MC):Void {
		for (l in lists)
			if (l != null)
				l.remove(mc);
	}

	public function removeAll():Void {
		for (l in lists)
			if (l != null)
				for (mc in l.copy())
					mc.removeMovieClip();
	}
}
