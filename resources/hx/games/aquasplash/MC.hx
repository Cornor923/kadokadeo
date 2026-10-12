package aquasplash;

import pixi.core.Pixi.BlendModes;
import pixi.core.textures.Texture;
import pixi.filters.alpha.AlphaFilter;

/**
 * A Flash MovieClip as the original code uses it: _x / _y stored in twips (Flash truncates them to 1/20 px), scales
 * and alpha in percent, frames chosen by the code or played by the timeline (one frame per Flash frame), with the
 * few frame scripts of Aqua Splash's timelines: stop() on a frame (stopAt) and removeMovieClip() on a frame (removeAt:
 * the clip disappears when its playhead reaches that frame, before it is drawn).
 *
 * Display (the MC of the Linea and Hexile ports): Aqua Splash ran at 40 Flash frames/s and KadoKadeo steps 32 times per second, so a
 * step plays 1 or 2 Flash frames (Game.update). Showing the last Flash frame of each step would make the moves jerk
 * (1, 1, 1, 2 frames per step); instead every clip shows the state one Flash frame ago, interpolated towards the
 * last one by the fraction of a Flash frame the steps are behind (display).
 */
class MC {
	public static var all:Array<MC> = [];

	public var spr:ASprite;
	public var parent:MC;
	public var children:Array<MC> = [];
	// the mt.bumdum.Sprite driving the clip
	public var obj:Sprite;

	public var _x(default, set):Float = 0;
	public var _y(default, set):Float = 0;
	public var _xscale:Float = 100;
	public var _yscale:Float = 100;
	public var _alpha:Float = 100;
	public var _rotation:Float = 0;
	public var _visible:Bool = true;
	public var _currentframe:Int = 1;
	public var _totalframes:Int = 1;
	// a grey or colour multiplier (0xRRGGBB, multipliers of a colour transform)
	public var tint:Int = 0xFFFFFF;
	// pictures stored at 1 / texSx of their horizontal resolution (the blurred variants of nextLevel)
	public var texSx:Float = 1;
	// texSx of the picture of the last display
	var shownSx:Float = 1;
	// a clip under filters: Flash draws it composed, then applies its alpha to the composed picture (an AlphaFilter on
	// the container; otherwise PIXI multiplies the alpha into every picture, and the lower ones show through)
	public var alphaFilter:AlphaFilter;
	public var removed(default, null):Bool = false;

	public var playing:Bool = false;
	// frame scripts: stop() on frame stopAt, removeMovieClip() on frame removeAt (0: none)
	public var stopAt:Int = 0;
	public var removeAt:Int = 0;
	// placed by a timeline (soldiers of the bases): shown from the step it appears in, see display
	public var showNow:Bool = false;

	var frames:Array<Texture>;
	// texture pixels per Flash pixel
	var res:Float;
	// position scale of the clip in its parent (the scene itself: 2, see Game)
	public var posK:Float = 1;

	// state of the previous Flash frame (display)
	var fresh:Bool = true;
	var snap:Bool = false;
	var px:Float = 0;
	var py:Float = 0;
	var pxs:Float = 100;
	var pys:Float = 100;
	var pa:Float = 100;
	var pr:Float = 0;

	// res: texture pixels per Flash pixel (pictures of the sheet: 2; containers: 1, their children keep their size)
	public function new(?anim:String, ?res:Float) {
		spr = new ASprite();
		this.res = res != null ? res : anim != null ? Game.K : 1;
		if (anim != null)
			setFrames(anim);
		all.push(this);
	}

	// the pictures of the clip (the same clip under another colour transform: another baked picture)
	// the anim shown (setFrames)
	public var anim:String;

	public function setFrames(anim:String):Void {
		// (a clip removed: Flash ignores what the code still does with it)
		if (removed)
			return;
		this.anim = anim;
		frames = Tex.get(anim);
		_totalframes = frames.length;
		texSx = 1;
		if (_currentframe > _totalframes)
			_currentframe = _totalframes;
		showFrame();
	}

	// no picture (a frame without any shape drawn, as slime frame 5)
	public function setEmpty():Void {
		if (removed)
			return;
		frames = [Texture.EMPTY];
		_totalframes = 1;
		_currentframe = 1;
		showFrame();
	}

	// ---------------------------------------------------------------- display list
	public function attach(child:MC):MC {
		child.parent = this;
		children.push(child);
		spr.addChild(child.spr);
		return child;
	}

	// DepthManager.over: on top of the other clips of its plane
	public function toTop(child:MC):Void {
		children.remove(child);
		children.push(child);
		spr.removeChild(child.spr);
		spr.addChild(child.spr);
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

	// blendMode = "add" (the particles, the gradient of nextLevel)
	public function setAdd():Void {
		spr.blendMode = BlendModes.ADD;
	}

	// ---------------------------------------------------------------- timeline
	public function gotoAndStop(f:Int):Void {
		playing = false;
		_currentframe = f < 1 ? 1 : f > _totalframes ? _totalframes : f;
	}

	public function gotoAndPlay(f:Int):Void {
		_currentframe = f < 1 ? 1 : f > _totalframes ? _totalframes : f;
		playing = true;
	}

	public function play():Void {
		playing = true;
	}

	public function stop():Void {
		playing = false;
	}

	// a Flash frame: playing timelines advance before the code runs, then the script of the new frame
	function advance():Void {
		if (!playing || removed)
			return;
		var f = _currentframe + 1;
		if (removeAt > 0 && f >= removeAt) {
			removeMovieClip();
			return;
		}
		if (f > _totalframes)
			f = 1;
		_currentframe = f;
		if (f == stopAt)
			playing = false;
		onFrame();
	}

	// the frame the timeline shows changed (subclasses moving children with their timeline)
	function onFrame():Void {}

	// ---------------------------------------------------------------- properties
	function set__x(v:Float):Float {
		return _x = twips(v);
	}

	function set__y(v:Float):Float {
		return _y = twips(v);
	}

	// a move the timeline or the code makes at once (a clip placed again): not interpolated
	public function teleport(x:Float, y:Float):Void {
		_x = x;
		_y = y;
		px = _x;
		py = _y;
		snap = true;
	}

	public static inline function twips(v:Float):Float {
		return Std.int(v * 20) / 20;
	}

	// ---------------------------------------------------------------- Flash frames and display
	public static function frameStart():Void {
		var i = 0;
		while (i < all.length) {
			var m = all[i];
			if (m.removed) {
				all.splice(i, 1);
				continue;
			}
			m.fresh = false;
			m.px = m._x;
			m.py = m._y;
			m.pxs = m._xscale;
			m.pys = m._yscale;
			m.pa = m._alpha;
			m.pr = m._rotation;
			i++;
		}
		// (a clip removed by its script stays in the list until the next frame)
		for (m in all.copy())
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
		var hide = fresh && f < 1 && !showNow;
		if (fresh)
			f = 1;
		s._x = (px + (_x - px) * f) * posK;
		s._y = (py + (_y - py) * f) * posK;
		s._xscale = (pxs + (_xscale - pxs) * f) * texSx / res;
		s._yscale = (pys + (_yscale - pys) * f) / res;
		var a = pa + (_alpha - pa) * f;
		a = a < 0 ? 0 : a > 100 ? 100 : a;
		if (alphaFilter != null) {
			alphaFilter.alpha = a / 100;
			a = 100;
		}
		s._alpha = a;
		s._rotation = pr + (_rotation - pr) * f;
		if (s.tint != tint)
			s.tint = tint;
		// the picture changes at once while the renderer interpolates the scale from the previous step: that scale
		// is converted to the resolution of the new picture (blurred variants of nextLevel: texSx 1 to 62), or the
		// banner and the plate stretch between the steps
		if (texSx != shownSx && s._prevState != null)
			s._prevState.xscale *= texSx / shownSx;
		shownSx = texSx;
		if (snap && s._prevState != null)
			s._prevState.copyFrom(s._curState);
		snap = hide;
		s.visible = _visible && !hide;
		if (frames != null)
			showFrame();
	}

	function showFrame():Void {
		var t = frames[_currentframe - 1];
		if (spr.texture != t) {
			spr.texture = t;
			spr.anchor.copyFrom(t.defaultAnchor);
		}
	}

	public static function clearAll():Void {
		for (m in all.copy())
			m.removeMovieClip();
		all = [];
	}
}

// the depths of the original (DepthManager planes): one container per plane, clips drawn in attach order
class Plans {
	var root:MC;
	var plans:Array<MC> = [];

	public function new(root:MC) {
		this.root = root;
	}

	public function get(plan:Int):MC {
		for (i in plans.length...plan + 1)
			plans[i] = null;
		if (plans[plan] == null) {
			var p = new MC();
			// in depth order among the existing planes
			var at = 0;
			for (i in 0...plan)
				if (plans[i] != null)
					at = root.spr.getChildIndex(plans[i].spr) + 1;
			p.parent = root;
			root.children.push(p);
			root.spr.addChildAt(p.spr, at);
			plans[plan] = p;
		}
		return plans[plan];
	}

	public function attach(anim:String, plan:Int):MC {
		var mc = new MC(anim);
		mc.playing = mc._totalframes > 1;
		return get(plan).attach(mc);
	}

	public function add<T:MC>(mc:T, plan:Int):T {
		get(plan).attach(mc);
		return mc;
	}

	public function empty(plan:Int):MC {
		return get(plan).attach(new MC());
	}

	public function over(mc:MC):Void {
		if (mc != null && mc.parent != null)
			mc.parent.toTop(mc);
	}
}
