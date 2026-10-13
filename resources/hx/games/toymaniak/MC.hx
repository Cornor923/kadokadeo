package toymaniak;

import pixi.core.textures.Texture;

/**
 * A Flash MovieClip as the original code uses it (Hypercube's MC): _x / _y stored in twips (Flash truncates them to
 * 1/20 px, and ignores a NaN), scales as in Flash, frames chosen by the code or played by the timeline (one frame per
 * Flash frame, looping like a timeline without stop()); `frameChanged` runs when the frame changes and `script` runs
 * the frame scripts of the timeline after the playhead moved. A clip created without pictures is a container.
 *
 * Display: Toy Maniak ran at 40 Flash frames/s and KadoKadeo steps 32 times per second, so a step plays 1 or 2 Flash
 * frames (Game.update). Every clip shows the state one Flash frame ago, interpolated towards the last one by the
 * fraction of a Flash frame the steps are behind (display): the game moves by exactly 1.25 Flash frames per step.
 */
class MC {
	public static var all:Array<MC> = [];

	public var spr:ASprite;
	public var parent:MC;
	public var children:Array<MC> = [];
	// depth in the parent (children are kept in depth order: Std.attachMC, DepthManager)
	public var depth:Int = 0;

	public var _x(default, set):Float = 0;
	public var _y(default, set):Float = 0;
	public var _xscale:Float = 100;
	public var _yscale:Float = 100;
	public var _alpha(default, set):Float = 100;
	public var _visible:Bool = true;
	public var _currentframe(default, null):Int = 1;
	public var _totalframes(default, null):Int = 1;
	public var removed(default, null):Bool = false;
	public var playing:Bool = false;
	// frame scripts of the timeline (after the playhead moved: the new frame)
	public var script:Int->Void;

	// button: onPress handler, hand cursor over it, hit area (rectangles xmin, xmax, ymin, ymax in the clip, or a
	// function of a point of the clip; with those of its children)
	public var onPress:Void->Void;
	public var useHandCursor:Bool = true;
	public var hitRects:Array<Array<Float>>;
	public var hitFn:Float->Float->Bool;

	// colour: tint (multiplier of the picture, TextField.textColor on white digits)
	public var tint:Int = 0xFFFFFF;

	// x interpolated modulo this period (0: none): a strip that moves by one period back where it was
	public var wrapX:Float = 0;

	var frames:Array<Texture>;
	// texture pixels per Flash pixel
	var res:Float;
	// position scale of the clip in its parent (the scene itself: 2, see Game)
	public var posK:Float = 1;

	// state of the previous Flash frame (display)
	var fresh:Bool = true;
	var snap:Bool = false;
	// jump(): the next display is not interpolated by the renderer either (from the state of the previous step)
	var cut:Bool = false;
	var px:Float = 0;
	var py:Float = 0;
	var pxs:Float = 100;
	var pys:Float = 100;
	var pa:Float = 100;

	// anim: pictures of the sheet; res: texture pixels per Flash pixel (pictures of the sheet: 2; containers: 1, their
	// children keep their size)
	public function new(?anim:String, ?res:Float) {
		this.res = res != null ? res : anim != null ? Game.K : 1;
		spr = new ASprite();
		if (anim != null)
			setFrames(anim);
		all.push(this);
	}

	public function setFrames(anim:String):Void {
		frames = Tex.get(anim);
		_totalframes = frames.length;
		if (_currentframe > _totalframes)
			_currentframe = _totalframes;
		spr.texture = frames[_currentframe - 1];
		spr.anchor.copyFrom(spr.texture.defaultAnchor);
	}

	// another picture (one frame) at another resolution; null: none
	public function setPicture(anim:Null<String>, res:Float):Void {
		this.res = res;
		if (anim == null) {
			frames = [Texture.EMPTY];
			spr.texture = Texture.EMPTY;
		} else {
			frames = Tex.get(anim);
			_currentframe = 1;
			spr.texture = frames[0];
			spr.anchor.copyFrom(spr.texture.defaultAnchor);
		}
	}

	// a timeline without pictures of its own (its frames drive its children, see frameChanged)
	public function setTimeline(n:Int):Void {
		_totalframes = n;
	}

	// ---------------------------------------------------------------- display list
	public function attach<T:MC>(child:T):T {
		var d = children.length == 0 ? 0 : children[children.length - 1].depth + 1;
		return attachAt(child, d);
	}

	// attachMovie at a depth: in depth order, replacing the clip already at that depth (Flash removes it)
	public function attachAt<T:MC>(child:T, d:Int):T {
		var i = 0;
		while (i < children.length && children[i].depth < d)
			i++;
		if (i < children.length && children[i].depth == d)
			children[i].removeMovieClip();
		child.parent = this;
		child.depth = d;
		children.insert(i, child);
		spr.addChildAt(child.spr, i);
		return child;
	}

	// out of its parent (swapDepths to another plan: Plans.swap)
	public function detach():Void {
		if (parent != null)
			parent.children.remove(this);
		if (spr.parent != null)
			spr.parent.removeChild(spr);
		parent = null;
	}

	public function removeMovieClip():Void {
		if (removed)
			return;
		removed = true;
		for (c in children.copy())
			c.removeMovieClip();
		if (parent != null)
			parent.children.remove(this);
		if (spr.parent != null)
			spr.parent.removeChild(spr);
		spr.destroy({children: true});
	}

	// ---------------------------------------------------------------- timeline
	public function gotoAndStop(f:Int):Void {
		playing = false;
		goto(f);
	}

	public function gotoAndPlay(f:Int):Void {
		playing = true;
		goto(f);
	}

	function goto(f:Int):Void {
		var old = _currentframe;
		_currentframe = f < 1 ? 1 : f > _totalframes ? _totalframes : f;
		frameChanged(old);
	}

	// the timeline placed / moved / removed its children (old: the frame before)
	function frameChanged(old:Int):Void {}

	public function play():Void {
		playing = true;
	}

	public function stop():Void {
		playing = false;
	}

	// a Flash frame: playing timelines advance, then their frame scripts run
	function advance():Void {
		if (playing && _totalframes > 1) {
			goto(_currentframe == _totalframes ? 1 : _currentframe + 1);
			if (script != null)
				script(_currentframe);
		}
	}

	// ---------------------------------------------------------------- properties
	function set__x(v:Float):Float {
		// (Flash ignores a NaN: the clip stays where it is)
		return Math.isNaN(v) ? _x : _x = twips(v);
	}

	function set__y(v:Float):Float {
		return Math.isNaN(v) ? _y : _y = twips(v);
	}

	function set__alpha(v:Float):Float {
		return Math.isNaN(v) ? _alpha : _alpha = Std.int(v * 2.56) / 2.56;
	}

	public static inline function twips(v:Float):Float {
		return Std.int(v * 20) / 20;
	}

	// hit area of the clip and its children (the point in the clip's coordinates); hidden clips are not hit
	public function hitTest(x:Float, y:Float):Bool {
		if (!_visible || removed)
			return false;
		if (hitRects != null)
			for (r in hitRects)
				if (x >= r[0] && x <= r[1] && y >= r[2] && y <= r[3])
					return true;
		if (hitFn != null && hitFn(x, y))
			return true;
		for (c in children)
			if (c.hitTest((x - c._x) * 100 / c._xscale, (y - c._y) * 100 / c._yscale))
				return true;
		return false;
	}

	// ---------------------------------------------------------------- Flash frames and display
	// a change that is not a move (another picture placed elsewhere): shown at once, not interpolated (neither
	// between the Flash frames nor between the steps: another picture at another resolution would be drawn at the
	// scale of the previous one)
	public function jump():Void {
		keep();
		cut = true;
	}

	function keep():Void {
		px = _x;
		py = _y;
		pxs = _xscale;
		pys = _yscale;
		pa = _alpha;
	}

	// the state shown during the next Flash frame (display): taken before the frame changes anything
	public static function snapshotAll():Void {
		var i = 0;
		while (i < all.length) {
			var m = all[i];
			if (m.removed) {
				all.splice(i, 1);
				continue;
			}
			m.fresh = false;
			m.keep();
			i++;
		}
	}

	public static function advanceAll():Void {
		// (a copy: a frame script can remove clips)
		for (m in all.copy())
			if (!m.removed)
				m.advance();
	}

	public static function displayAll(f:Float):Void {
		for (m in all)
			if (!m.removed)
				m.display(f);
	}

	function display(f:Float):Void {
		var s = spr;
		// created during the last Flash frame: the picture shown is still before it (f = 1: the start of the game);
		// shown from the next step, not interpolated from where it was created
		var hide = fresh && f < 1;
		if (fresh)
			f = 1;
		var x0 = px;
		if (wrapX > 0) {
			// the nearest copy of the previous position (a strip moved back by one period)
			var d = _x - x0;
			d -= Math.round(d / wrapX) * wrapX;
			x0 = _x - d;
		}
		s._x = (x0 + (_x - x0) * f) * posK;
		s._y = (py + (_y - py) * f) * posK;
		s._xscale = (pxs + (_xscale - pxs) * f) / res;
		s._yscale = (pys + (_yscale - pys) * f) / res;
		var a = pa + (_alpha - pa) * f;
		s._alpha = a < 0 ? 0 : a > 100 ? 100 : a;
		if (wrapX > 0 && s._prevState != null) {
			// the renderer too: from the nearest copy of the position shown at the previous step
			var p = wrapX * posK;
			var d = s._curState.x - s._prevState.x;
			s._prevState.x += Math.round(d / p) * p;
		}
		if ((snap || cut) && s._prevState != null)
			s._prevState.copyFrom(s._curState);
		snap = hide;
		cut = false;
		s.visible = _visible && !hide;
		s.tint = tint;
		if (frames != null) {
			var t = frames[_currentframe - 1];
			if (s.texture != t) {
				s.texture = t;
				s.anchor.copyFrom(t.defaultAnchor);
			}
		}
	}

	public static function clearAll():Void {
		for (m in all.copy())
			m.removeMovieClip();
		all = [];
	}
}

// the depths of the original (mt.DepthManager): one container per plan, clips drawn in the order they were attached
class Plans {
	var root:MC;
	var plans:Array<MC> = [];

	public function new(root:MC) {
		this.root = root;
	}

	public function get(plan:Int):MC {
		var p = plans[plan];
		if (p == null) {
			p = new MC();
			root.attachAt(p, plan);
			plans[plan] = p;
		}
		return p;
	}

	public function add<T:MC>(mc:T, plan:Int):T {
		get(plan).attach(mc);
		return mc;
	}

	// DepthManager.swap: on top of another plan
	public function swap(mc:MC, plan:Int):Void {
		mc.detach();
		get(plan).attach(mc);
	}
}
