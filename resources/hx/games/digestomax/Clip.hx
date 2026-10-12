package digestomax;

import common_haxe_avm1.display.ASprite.TransformState;
import pixi.core.Pixi.BlendModes;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.Texture;

// One layer of a clip (written by the asset pipeline, tools/clipexport.py):
//  k: 0 flattened images (one per frame) / 1 image moved by a matrix / 2 nested clip / 3 mask
//  a: animation (k 0, 1, 3) or clip (k 2) name
//  t: image of each frame (0: layer absent) / p: placement of each frame for nested clips (0: absent, new value: new instance)
//  m / m0: [x, y, scaleX, scaleY, rotation (deg), skewX, skewY] of each frame / of all the frames
//  al / al0: alpha, tn / tns: multiplied colour, ad / ads: added colour (white silhouette `a`W drawn additively)
//  nm: instance name, mk: layer masking this one
typedef LayerDef = {
	k:Int,
	a:String,
	?t:Array<Int>,
	?p:Array<Int>,
	?m:Array<Array<Float>>,
	?m0:Array<Float>,
	?al:Array<Float>,
	?al0:Float,
	?tn:Int,
	?tns:Array<Int>,
	?ad:Int,
	?ads:Array<Int>,
	?nm:String,
	?mk:Int
};

// n: frames, r: resolution of the textures (1 = 2 px per Flash pixel), start / still: frozen on a frame
typedef ClipDef = {
	n:Int,
	r:Float,
	layers:Array<LayerDef>,
	?acts:Dynamic,
	?labels:Dynamic,
	?start:Int,
	?still:Int,
	// built at load time
	?act:Array<Array<Array<Dynamic>>>,
	?lab:Map<String, Int>,
	?simple:Bool
};

// image of a layer (flattened frames or a single shape), with its additive white silhouette when needed
class Gfx extends ASprite {
	public var frames(default, null):Array<Texture>;

	// _visible = false set by the game code on this instance
	public var hidden:Bool = false;

	// moved by the game code: the timeline of its parent no longer moves it (Flash rule)
	public var scripted:Bool = false;

	var anim:String;
	var addSpr:PixiSprite;
	var cur:Int;

	public function new(anim:String) {
		super();
		this.anim = anim;
		frames = Tex.get(anim);
		texture = frames[0];
		anchor.copyFrom(frames[0].defaultAnchor);
		_totalframes = frames.length;
		cur = 1;
	}

	public inline function show(i:Int) {
		var t = frames[i - 1];
		if (texture != t) {
			texture = t;
			cur = i;
			if (addSpr != null)
				addSpr.texture = Tex.get(anim + "W")[i - 1];
		}
	}

	public inline function hasAdd():Bool {
		return addSpr != null;
	}

	// Flash colour offset: added colour, 0 = none
	public function setAdd(c:Int) {
		if (c == 0) {
			if (addSpr != null)
				addSpr.visible = false;
			return;
		}
		if (addSpr == null) {
			var w = Tex.get(anim + "W");
			addSpr = new PixiSprite(w[cur - 1]);
			addSpr.anchor.copyFrom(w[0].defaultAnchor);
			addSpr.blendMode = BlendModes.ADD;
			addChild(addSpr);
		}
		addSpr.visible = true;
		addSpr.tint = c;
	}

	override public function updateGraphics(a:Float) {
		Clip.noFlipLerp(this);
		super.updateGraphics(a);
	}
}

/**
 * Flash MovieClip replayed from the exported timeline tables (cosmocrash.Clip): nested clips keep their own playhead,
 * frame scripts (stop / play / goto / a few custom ones) run like in the Flash player.
 *
 * Digestomax ran at 40 Flash frames per second (the rate of the SWF and of the KadoKado loader): the playheads do not
 * move with the steps of KadoKadeo (32 per second) but with the Flash frames the game plays (Game.update calls
 * MC.frameStart, which ticks every clip). The code reads them (Piou.walk: `skin.smc._currentframe < 10`), and only the
 * game update moves them.
 *
 * AVM1 order: the frame scripts of a frame reached by a goto of the code, and the first frame scripts of the clips the
 * code attaches (or that a goto of the code places), run after the code (the action queue of the frame): the code
 * sets `$big`, `_fruit` and `_sens` on the hero's animation right after (or before) the goto and the scripts of the
 * cheeks and of the fruit swallowed upwards see it (runLater; `deferring` is on while the game code runs).
 */
class Clip extends ASprite {
	public static inline var K = 2;

	// createEmptyMovieClip / DepthManager.empty: a clip without picture whose children are in Flash pixels
	public static inline var EMPTY = "__empty";

	static var defs:Map<String, ClipDef> = new Map();
	static var removed:Array<Clip> = [];
	static var later:Array<Void->Void> = [];

	// the game code is running: the frame scripts it triggers are queued (runLater)
	public static var deferring:Bool = false;

	// a goto of a frame script is running: the clips it places run their first frame scripts after the code of the frame
	// (AVM1: the frame scripts of the timelines are queued before the onEnterFrame of the game, the actions of the clips
	// a goto of those scripts places are queued when it runs, after it; Pioupiou's cheeks, placed by the
	// gotoAndStop(1) of his animation's last frame, see the `$big` the code sets in that frame)
	static var scriptGoto:Bool = false;

	public var def(default, null):ClipDef;
	public var clipName(default, null):String;
	public var frame(default, null):Int;

	// the MC moved by the game code, for a top level clip
	public var owner:MC;

	// removed by a frame script (removeMovieClip): taken out by flushRemoved
	public var selfRemoved(default, null):Bool = false;

	// the transform was changed by a script of the clip: its parent timeline no longer moves it (Flash rule)
	public var scripted:Bool;

	public var frozen:Bool;

	// fields the code sets on the hero's animation (skin.smc) and the frame scripts of its children read: `$big` (the
	// cheeks: false, then the number of fruits in the stomach; undefined: NaN), `_fruit` and `_sens` (the fruit
	// swallowed upwards)
	public var big:Float = Math.NaN;
	public var fruit:Null<Int> = null;
	public var sens:Null<Int> = null;

	public var baseName(default, null):String;

	var pendingStart:Bool = false;

	// a top level clip is in Flash pixels: _xscale / _yscale 100 = textures at their resolution
	public var baseScale(default, null):Float;

	var objs:Array<ASprite>;
	var pids:Array<Int>;
	var deadPid:Array<Int>;
	var tintIn:Int;
	var addIn:Int;
	var simpleFrames:Array<Texture>;
	var simpleAdd:PixiSprite;

	// blend mode of this clip ('add' on the explosion): PIXI blends sprites, not containers: given to every picture
	// inside (Flash adds the composed clip; the pictures added one by one only differ where they overlap)
	var blend:Null<BlendModes> = null;

	public static function getDef(name:String):ClipDef {
		var d = defs.get(name);
		if (d == null) {
			if (name == EMPTY)
				d = {n: 1, r: 0.5, layers: []};
			else
				d = Reflect.field(Data.clips(), name);
			if (d == null)
				throw 'unknown clip ' + name;
			d.act = [for (i in 0...d.n + 1) null];
			if (d.acts != null)
				for (k in Reflect.fields(d.acts))
					d.act[Std.parseInt(k)] = Reflect.field(d.acts, k);
			d.lab = new Map();
			if (d.labels != null)
				for (k in Reflect.fields(d.labels))
					d.lab.set(k, Reflect.field(d.labels, k));
			d.simple = d.layers.length == 1 && d.layers[0].k == 0;
			defs.set(name, d);
		}
		return d;
	}

	// pxPerUnit: pixels of the parent per Flash pixel (1 in the game, 0 = nested clip placed by its parent)
	public function new(name:String, ?pxPerUnit:Float = 1, ?tint:Int = 0xFFFFFF, ?add:Int = 0) {
		super();
		def = getDef(name);
		clipName = name;
		baseName = name;
		_name = name;
		_totalframes = def.n;
		scripted = false;
		frozen = false;
		tintIn = tint;
		addIn = add;
		baseScale = pxPerUnit > 0 ? pxPerUnit / (K * def.r) : 1;
		objs = [];
		pids = [];
		deadPid = [];
		if (def.simple) {
			simpleFrames = Tex.get(def.layers[0].a);
			anchor.copyFrom(simpleFrames[0].defaultAnchor);
			applySimpleColour();
		}
		if (baseScale != 1) {
			_xscale = 100;
			_yscale = 100;
		}
		frame = 0;
		var f = def.start != null ? def.start : 1;
		isPlaying = def.still == null;
		display(f);
		// a clip placed by the timeline of its parent runs the script of its first frame once placed (Flash: the
		// instance gets its matrix, then its actions run); attached by the code: after the code
		if (pxPerUnit > 0)
			runActions(f, 0, deferring);
		else
			pendingStart = true;
	}

	// placed by its parent: first frame actions
	function start() {
		if (pendingStart) {
			pendingStart = false;
			runActions(frame, 0, deferring || scriptGoto);
		}
	}

	// A scale that changes its sign is a flip: in Flash it is instant, interpolated between two steps it would show
	// the picture squeezed flat
	public static inline function noFlipLerp(s:ASprite) {
		var p = s._prevState;
		if (p != null) {
			var c = s._curState;
			if (p.xscale * c.xscale < 0)
				p.xscale = c.xscale;
			if (p.yscale * c.yscale < 0)
				p.yscale = c.yscale;
		}
	}

	override public function updateGraphics(a:Float) {
		noFlipLerp(this);
		super.updateGraphics(a);
	}

	// clips that removed themselves (frame script) since the last call: their MC is removed (its _name is null)
	public static function flushRemoved() {
		var l = removed;
		removed = [];
		for (c in l) {
			if (c.owner != null)
				c.owner.removeMovieClip();
			else
				c.removeMovieClip();
		}
	}

	// the action queue: the frame scripts the code triggered, after the code
	public static function runLater() {
		var d = deferring;
		deferring = false;
		var i = 0;
		while (i < later.length)
			later[i++]();
		later = [];
		deferring = d;
	}

	public static function reset() {
		scriptGoto = false;
		removed = [];
		later = [];
		deferring = false;
	}

	override public function get__xscale():Float {
		return _curState.xscale * 100 / baseScale;
	}

	override public function set__xscale(v:Float) {
		_curState.xscale = v / 100 * baseScale;
		return v;
	}

	override public function get__yscale():Float {
		return _curState.yscale * 100 / baseScale;
	}

	override public function set__yscale(v:Float) {
		_curState.yscale = v / 100 * baseScale;
		return v;
	}

	// ---------------------------------------------------------------- playhead
	// a step of KadoKadeo: only the state shown before it is kept for the interpolation (the playheads move in tick)
	override public function update() {
		if (_prevState == null)
			_prevState = new TransformState(this);
		_prevState.copyFrom(_curState);
		for (c in children)
			if (Std.isOfType(c, ASprite))
				(cast c : ASprite).update();
	}

	// a Flash frame: the nested clips advance, then this one (playheads move before the code runs)
	public function tick() {
		if (frozen || selfRemoved)
			return;
		var l = children.copy();
		for (c in l) {
			var cc = Std.downcast(c, Clip);
			if (cc != null && cc.parent == this)
				cc.tick();
		}
		if (isPlaying)
			nextFrame();
	}

	override public function nextFrame() {
		// a timeline of one frame does not run its frame script again
		if (def.n == 1)
			return;
		var f = frame + 1;
		if (f > def.n)
			f = 1;
		display(f);
		runActions(f, 0, false);
	}

	override public function play() {
		if (def.still == null)
			isPlaying = true;
	}

	override public function stop() {
		isPlaying = false;
	}

	public inline function playing():Bool {
		return isPlaying;
	}

	override public function gotoAndStop(f:Dynamic) {
		var n = resolve(f);
		if (n != null)
			goto(n, false);
	}

	override public function gotoAndPlay(f:Dynamic) {
		var n = resolve(f);
		if (n != null)
			goto(n, true);
	}

	// Flash: a number (or a string holding one) is a frame, another string a label; an unknown label does nothing
	public function resolve(f:Dynamic):Null<Int> {
		if (Std.isOfType(f, Int))
			return f;
		var s:String = Std.string(f);
		var n = Std.parseInt(s);
		if (n != null)
			return n;
		return def.lab.exists(s) ? def.lab.get(s) : null;
	}

	function goto(f:Int, play:Bool) {
		// Flash: a frame past the end is the last frame
		if (f < 1)
			f = 1;
		if (f > def.n)
			f = def.n;
		isPlaying = play && def.still == null;
		if (f == frame)
			return;
		display(f, f != frame + 1);
		runActions(f, 0, deferring);
	}

	function runActions(f:Int, depth:Int, deferred:Bool) {
		var acts = def.act[f];
		if (acts == null || depth > 8)
			return;
		if (deferred) {
			// the action list of the frame runs after the code that moved the playhead (AVM1); the playhead may have moved
			// again by then (only the scripts of the frame shown are run)
			later.push(function() {
				if (frame == f && !removedFromStage())
					runActions(f, depth, false);
			});
			return;
		}
		for (a in acts) {
			switch (a[0]) {
				case "s":
					isPlaying = false;
				case "p":
					isPlaying = def.still == null;
				case "g":
					var t:Int = a[1];
					isPlaying = a[2] == 1;
					if (t != frame) {
						var sg = scriptGoto;
						scriptGoto = true;
						display(t, t != frame + 1);
						scriptGoto = sg;
						runActions(t, depth + 1, false);
					}
				case "x":
					script(a[1]);
				case _:
			}
		}
	}

	// removed (by the code, a frame script or its parent's timeline)
	function removedFromStage():Bool {
		if (selfRemoved)
			return true;
		if (owner != null)
			return owner.removed;
		return parent == null;
	}

	// the frame scripts that do more than moving the playhead
	function script(name:String) {
		switch (name) {
			case "rmSelf":
				// removeMovieClip(): hidden now, taken out once every clip has played its frame (removing it in the middle
				// of the loop over the clips would make the next one skip this frame)
				removeLater(this);
			case "big":
				// smc._visible = _parent.$big > 0; smc._xscale = smc._yscale = 50 + _parent.$big * 10 (a cheek; a NaN scale
				// is ignored by Flash)
				var p = Std.downcast(parent, Clip);
				var big = p != null ? p.big : Math.NaN;
				setVisible("smc", big > 0);
				var sc = 50 + big * 10;
				setSub("smc", null, null, sc, sc);
			case "fruit":
				// smc.gotoAndStop(_parent._fruit); smc._xscale = _parent._sens * 100 (the fruit swallowed upwards)
				var p = Std.downcast(parent, Clip);
				var s = getClip("smc");
				if (p != null && s != null) {
					if (p.fruit != null)
						s.gotoAndStop(p.fruit);
					setSub("smc", null, null, p.sens != null ? p.sens * 100 : Math.NaN);
				}
			case _:
		}
	}

	static function removeLater(c:Clip) {
		if (c.selfRemoved)
			return;
		c.selfRemoved = true;
		c.isPlaying = false;
		c.visible = false;
		removed.push(c);
	}

	// the same timeline with other pictures (a colour variant): same frame, same playhead
	public function setDef(name:String) {
		if (name == clipName)
			return;
		for (i in 0...objs.length)
			if (objs[i] != null)
				removeLayer(i);
		objs = [];
		pids = [];
		deadPid = [];
		def = getDef(name);
		clipName = name;
		if (def.simple) {
			simpleFrames = Tex.get(def.layers[0].a);
			anchor.copyFrom(simpleFrames[0].defaultAnchor);
			applySimpleColour();
		}
		var f = frame;
		frame = 0;
		display(f);
	}

	// ---------------------------------------------------------------- display
	// jump: a goto to another frame than the next one. Flash shows the new frame at once: the instances its timeline
	// keeps (and the pictures shown again after hidden frames) are not interpolated from their old place (the mask of the
	// beak, from the end of a swallow back to its start, when the hero chains two fruits)
	function display(f:Int, jump:Bool = false) {
		frame = f;
		untyped this._currentframe = f;
		if (def.simple) {
			var ti = def.layers[0].t[f - 1];
			texture = ti > 0 ? simpleFrames[ti - 1] : Texture.EMPTY;
			if (simpleAdd != null)
				simpleAdd.texture = ti > 0 ? Tex.get(def.layers[0].a + "W")[ti - 1] : Texture.EMPTY;
			return;
		}
		var layers = def.layers;
		for (i in 0...layers.length) {
			var L = layers[i];
			var o = objs[i];
			if (o != null && o.parent != this) {
				// removed by a script: not shown again before a new placement
				deadPid[i] = pids[i];
				objs[i] = o = null;
			}
			var p = L.k == 2 ? L.p[f - 1] : L.t[f - 1];
			if (p == 0) {
				if (o != null) {
					if (L.k == 2) {
						removeLayer(i);
					} else {
						o.visible = false;
					}
				}
				continue;
			}
			if (L.k == 2) {
				if (o != null && pids[i] != p) {
					removeLayer(i);
					o = null;
				}
				if (o == null && deadPid[i] == p)
					continue;
			}
			var fresh = false;
			if (o == null) {
				o = createLayer(i);
				pids[i] = p;
				deadPid[i] = 0;
				fresh = true;
			}
			var shownAgain = !fresh && !o.visible;
			if (L.k != 2) {
				var g:Gfx = cast o;
				g.show(p);
				// (_visible set by the code stays, like on a Flash instance)
				o.visible = !g.hidden;
			}
			place(i, o, f);
			if (fresh && L.k == 2)
				(cast o : Clip).start();
			if (fresh)
				o.updateState();
			else if ((jump || shownAgain) && o._prevState != null)
				o._prevState.copyFrom(o._curState);
		}
	}

	function createLayer(i:Int):ASprite {
		var L = def.layers[i];
		var o:ASprite;
		if (L.k == 2) {
			o = new Clip(L.a, 0, mulColor(tintIn, layerTint(L, frame)), addColor(addIn, mulColor(tintIn, layerAdd(L, frame))));
		} else {
			o = new Gfx(L.a);
		}
		if (L.nm != null)
			o._name = L.nm;
		if (blend != null) {
			if (L.k == 2)
				(cast o : Clip).setBlend(blend);
			else
				o.blendMode = blend;
		}
		untyped o._zIndex = i;
		var idx = 0;
		for (j in 0...i)
			if (objs[j] != null)
				idx++;
		addChildAt(o, Std.int(Math.min(idx, children.length)));
		objs[i] = o;
		if (L.k == 3) {
			// mask: hides the layers that reference it
			for (j in 0...def.layers.length)
				if (def.layers[j].mk == i && objs[j] != null)
					objs[j].mask = o;
		} else if (L.mk != null && objs[L.mk] != null) {
			o.mask = objs[L.mk];
		}
		return o;
	}

	function removeLayer(i:Int) {
		var o = objs[i];
		if (o == null)
			return;
		if (def.layers[i].k == 3)
			for (j in 0...objs.length)
				if (objs[j] != null && objs[j].mask == o)
					objs[j].mask = null;
		o.removeMovieClip();
		o.destroy({children: true});
		objs[i] = null;
	}

	inline function layerTint(L:LayerDef, f:Int):Int {
		return L.tn != null ? L.tn : (L.tns != null ? L.tns[f - 1] : 0xFFFFFF);
	}

	inline function layerAdd(L:LayerDef, f:Int):Int {
		return L.ad != null ? L.ad : (L.ads != null ? L.ads[f - 1] : 0);
	}

	function place(i:Int, o:ASprite, f:Int) {
		var L = def.layers[i];
		var m = L.m0 != null ? L.m0 : (L.m != null ? L.m[f - 1] : null);
		var c = L.k == 2 ? (cast o : Clip) : null;
		if (m != null && (c == null || !c.scripted) && !(c == null && (cast o : Gfx).scripted)) {
			o._x = m[0];
			o._y = m[1];
			o._xscale = m[2] * 100;
			o._yscale = m[3] * 100;
			o._rotation = m[4];
			if (m.length > 5)
				o.skew.set(m[5], m[6]);
			else if (o.skew.x != 0 || o.skew.y != 0)
				o.skew.set(0, 0);
		}
		o._alpha = (L.al0 != null ? L.al0 : (L.al != null ? L.al[f - 1] : 1)) * 100;
		var tn = mulColor(tintIn, layerTint(L, f));
		var ad = addColor(addIn, mulColor(tintIn, layerAdd(L, f)));
		if (c != null) {
			c.setColour(tn, ad);
		} else {
			o.tint = tn;
			var g:Gfx = cast o;
			// (an added colour taken back by the code, Col.setPercentColor(..., 0, ...): its silhouette is hidden again)
			if (ad != 0 || L.ad != null || L.ads != null || addIn != 0 || g.hasAdd())
				g.setAdd(ad);
		}
	}

	public function setBlend(b:BlendModes) {
		blend = b;
		if (def.simple)
			blendMode = b;
		for (o in objs)
			if (o != null) {
				var c = Std.downcast(o, Clip);
				if (c != null)
					c.setBlend(b);
				else
					o.blendMode = b;
			}
	}

	// Flash colour transform without alpha: multiplied colour + added colour (0xRRGGBB)
	public function setColour(mul:Int, add:Int) {
		if (mul == tintIn && add == addIn)
			return;
		tintIn = mul;
		addIn = add;
		if (def.simple) {
			applySimpleColour();
			return;
		}
		for (i in 0...objs.length)
			if (objs[i] != null)
				place(i, objs[i], frame);
	}

	function applySimpleColour() {
		tint = tintIn;
		if (addIn != 0 && simpleAdd == null) {
			var w = Tex.get(def.layers[0].a + "W");
			var ti = frame > 0 ? def.layers[0].t[frame - 1] : 0;
			simpleAdd = new PixiSprite(ti > 0 ? w[ti - 1] : Texture.EMPTY);
			simpleAdd.anchor.copyFrom(w[0].defaultAnchor);
			simpleAdd.blendMode = BlendModes.ADD;
			addChild(simpleAdd);
		}
		if (simpleAdd != null) {
			simpleAdd.visible = addIn != 0;
			simpleAdd.tint = addIn;
		}
	}

	static function mulColor(a:Int, b:Int):Int {
		if (a == 0xFFFFFF)
			return b;
		if (b == 0xFFFFFF)
			return a;
		var r = ((a >> 16) & 0xFF) * ((b >> 16) & 0xFF) / 255;
		var g = ((a >> 8) & 0xFF) * ((b >> 8) & 0xFF) / 255;
		var bl = (a & 0xFF) * (b & 0xFF) / 255;
		return (Math.round(r) << 16) | (Math.round(g) << 8) | Math.round(bl);
	}

	static function addColor(a:Int, b:Int):Int {
		if (a == 0)
			return b;
		if (b == 0)
			return a;
		var r = Std.int(Math.min(255, ((a >> 16) & 0xFF) + ((b >> 16) & 0xFF)));
		var g = Std.int(Math.min(255, ((a >> 8) & 0xFF) + ((b >> 8) & 0xFF)));
		var bl = Std.int(Math.min(255, (a & 0xFF) + (b & 0xFF)));
		return (r << 16) | (g << 8) | bl;
	}

	// ---------------------------------------------------------------- named instances
	function layerIndex(name:String):Int {
		var found = -1;
		for (i in 0...def.layers.length)
			if (def.layers[i].nm == name) {
				if (objs[i] != null)
					return i;
				if (found < 0)
					found = i;
			}
		return found;
	}

	// current instance of a named layer (null when it is not on the current frame)
	public function get(name:String):ASprite {
		var i = layerIndex(name);
		return i < 0 ? null : objs[i];
	}

	public function getClip(name:String):Clip {
		return Std.downcast(get(name), Clip);
	}

	// _visible of a named instance set by the code (kept by the instance until it leaves the timeline)
	public function setVisible(name:String, v:Bool):Void {
		var o = get(name);
		if (o == null)
			return;
		var g = Std.downcast(o, Gfx);
		if (g != null)
			g.hidden = !v;
		o.visible = v;
	}

	// a named instance moved by the code (Flash: its parent's timeline no longer moves it), in Flash pixels of this clip
	public function setSub(name:String, ?x:Float, ?y:Float, ?xscale:Float, ?yscale:Float, ?rotation:Float) {
		var o = get(name);
		if (o == null)
			return;
		var c = Std.downcast(o, Clip);
		if (c != null)
			c.scripted = true;
		else
			(cast o : Gfx).scripted = true;
		var u = K * def.r;
		if (x != null && Math.isFinite(x))
			o._x = x * u;
		if (y != null && Math.isFinite(y))
			o._y = y * u;
		// (_xscale 100: the Flash size; a nested clip's textures are at its own resolution, a picture's at this clip's: the
		// named pictures the code scales are not scaled by their timeline, the exporter keeps them at this resolution)
		var rs = c != null ? def.r / c.def.r : 1.0;
		if (xscale != null && Math.isFinite(xscale))
			o._xscale = xscale * rs;
		if (yscale != null && Math.isFinite(yscale))
			o._yscale = yscale * rs;
		if (rotation != null && Math.isFinite(rotation))
			o._rotation = rotation;
	}

	// the position of a named instance (Flash pixels of this clip)
	public function subX(name:String):Float {
		var o = get(name);
		return o == null ? Math.NaN : o._x / (K * def.r);
	}

	public function subY(name:String):Float {
		var o = get(name);
		return o == null ? Math.NaN : o._y / (K * def.r);
	}

	// playhead of a named nested clip (1 when it is not there)
	public function frameOf(name:String):Int {
		var c = getClip(name);
		return c == null ? 1 : c.frame;
	}

	override public function removeMovieClip() {
		super.removeMovieClip();
		isPlaying = false;
	}
}
