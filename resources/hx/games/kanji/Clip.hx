package kanji;

import common_haxe_avm1.display.ASprite.TransformState;
import mt.DepthManager;
import pixi.core.Pixi.BlendModes;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.Texture;

// One layer of a clip (written by the asset pipeline, tools/clipexport.py):
//  k: 0 flattened images (one per frame) / 1 image moved by a matrix / 2 nested clip / 3 mask
//  a: animation (k 0, 1, 3) or clip (k 2) name
//  t: image of each frame (0: layer absent) / p: placement of each frame for nested clips (0: absent, new value: new instance)
//  m / m0: [x, y, scaleX, scaleY, rotation (deg), skewX, skewY] of each frame / of all the frames
//  al / al0: alpha, tn / tns: multiplied colour, ad / ads: added colour (white silhouette `a`W drawn additively)
//  nm: instance name, mk: layer masking this one, bl: blend mode of the instance (add, mul, scr)
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
	?mk:Int,
	?bl:String
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

private typedef Override = {?rot:Float, ?xs:Float, ?ys:Float, ?x:Float, ?y:Float, ?al:Float};

// image of a layer (flattened frames or a single shape), with its additive white silhouette when needed
class Gfx extends ASprite {
	public var frames(default, null):Array<Texture>;

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
}

// Flash MovieClip replayed from the exported timeline tables: nested clips keep their own playhead, frame scripts
// (stop / play / goto / random start / a few custom ones) run like in the Flash player.
class Clip extends ASprite {
	public static inline var K = 2;

	static var defs:Map<String, ClipDef> = new Map();
	static var removed:Array<Clip> = [];

	public var def(default, null):ClipDef;
	public var clipName(default, null):String;
	public var frame(default, null):Int;

	// the transform was changed by a script of the clip: its parent timeline no longer moves it (Flash rule)
	public var scripted:Bool;

	// frozen picture (afterimages): no timeline at all
	public var frozen:Bool;

	// called when the clip removes itself (removeMovieClip in a frame script)
	public var onRemoved:Void->Void;

	// a top level clip is in Flash pixels: _xscale / _yscale 100 = textures at their resolution
	public var baseScale(default, null):Float;

	var objs:Array<ASprite>;
	var pids:Array<Int>;
	var deadPid:Array<Int>;
	var overrides:Map<Int, Override>;
	var tintIn:Int;
	var addIn:Int;
	var blendIn:BlendModes;
	var simpleFrames:Array<Texture>;
	var simpleAdd:PixiSprite;

	public static function getDef(name:String):ClipDef {
		var d = defs.get(name);
		if (d == null) {
			d = Reflect.field(Art.clips(), name);
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

	// pxPerUnit: pixels of the parent per Flash pixel (1 in the game world, 0 = nested clip placed by its parent)
	static function blendOf(s:String, inherited:BlendModes):BlendModes {
		return switch (s) {
			case "add": BlendModes.ADD;
			case "mul": BlendModes.MULTIPLY;
			case "scr": BlendModes.SCREEN;
			case _: inherited;
		}
	}

	public function new(name:String, ?pxPerUnit:Float = 1, ?tint:Int = 0xFFFFFF, ?add:Int = 0, ?blend:BlendModes) {
		super();
		def = getDef(name);
		clipName = name;
		_name = name;
		_totalframes = def.n;
		scripted = false;
		frozen = false;
		tintIn = tint;
		addIn = add;
		blendIn = blend != null ? blend : BlendModes.NORMAL;
		baseScale = pxPerUnit > 0 ? pxPerUnit / (K * def.r) : 1;
		objs = [];
		pids = [];
		deadPid = [];
		overrides = new Map();
		if (def.simple) {
			blendMode = blendOf(def.layers[0].bl, blendIn);
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
		runActions(f, 0);
	}

	// clips that removed themselves (frame script) since the last call
	public static function flushRemoved() {
		var l = removed;
		removed = [];
		for (c in l) {
			c.removeMovieClip();
			if (c.onRemoved != null)
				c.onRemoved();
		}
	}

	// top level clip attached at a plan of a depth manager
	public static function attach(dm:DepthManager, name:String, plan:Int):Clip {
		var c = new Clip(name);
		c.attachTo(dm, plan);
		return c;
	}

	public function attachTo(dm:DepthManager, plan:Int):Clip {
		var d = dm.reserve(this, plan);
		dm.getMC().addChild(this);
		_zIndex = d;
		zsort();
		return this;
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

	// pixels of the parent per Flash pixel changed (clip moved into another clip)
	public function setPxPerUnit(pxPerUnit:Float) {
		var sx = _xscale;
		var sy = _yscale;
		baseScale = pxPerUnit / (K * def.r);
		_xscale = sx;
		_yscale = sy;
	}

	// A scale that changes its sign is a flip (the hero turning round): in Flash it is instant, interpolated between two
	// steps it would show the picture squeezed flat
	override public function updateGraphics(a:Float) {
		var p = _prevState;
		if (p != null) {
			if (p.xscale * _curState.xscale < 0)
				p.xscale = _curState.xscale;
			if (p.yscale * _curState.yscale < 0)
				p.yscale = _curState.yscale;
		}
		super.updateGraphics(a);
	}

	// ---------------------------------------------------------------- playhead
	override public function update() {
		if (frozen) {
			updateState();
			return;
		}
		if (_prevState == null)
			_prevState = new TransformState(this);
		_prevState.copyFrom(_curState);
		for (c in children)
			if (Std.isOfType(c, ASprite))
				(cast c : ASprite).update();
		if (isPlaying)
			advance();
	}

	// the playhead of a playing clip: loops after the last frame
	function advance() {
		var f = frame + 1;
		if (f > def.n)
			f = 1;
		display(f);
		runActions(f, 0);
	}

	// nextFrame() of the code (Flash): next frame and stop, nothing after the last one
	override public function nextFrame() {
		if (frame < def.n)
			goto(frame + 1, false);
		else
			isPlaying = false;
	}

	override public function prevFrame() {
		if (frame > 1)
			goto(frame - 1, false);
		else
			isPlaying = false;
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
		goto(resolve(f), false);
	}

	override public function gotoAndPlay(f:Dynamic) {
		goto(resolve(f), true);
	}

	public function resolve(f:Dynamic):Int {
		if (Std.isOfType(f, Int))
			return f;
		var s:String = Std.string(f);
		if (def.lab.exists(s))
			return def.lab.get(s);
		var n = Std.parseInt(s);
		return n == null ? frame : n;
	}

	function goto(f:Int, play:Bool) {
		if (f < 1)
			f = 1;
		if (f > def.n)
			f = def.n;
		isPlaying = play && def.still == null;
		if (f == frame)
			return;
		display(f);
		runActions(f, 0);
	}

	function runActions(f:Int, depth:Int) {
		var acts = def.act[f];
		if (acts == null || depth > 8)
			return;
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
						display(t);
						runActions(t, depth + 1);
					}
				case "r":
					var lo:Int = a[1];
					var hi:Int = a[2];
					var t = lo + Seed.randomVfx(hi - lo + 1);
					if (t < 1)
						t = 1;
					if (t > def.n)
						t = def.n;
					isPlaying = true;
					if (t != frame) {
						display(t);
						runActions(t, depth + 1);
					}
				case "x":
					script(a[1]);
				case _:
			}
		}
	}

	// the frame scripts that do more than moving the playhead
	function script(name:String) {
		switch (name) {
			case "rmSelf":
				// removeMovieClip(): only a clip attached by the code (an instance placed by a timeline stays, like
				// in Flash). Hidden now, taken out at the start of the game update (removing it here, in the middle
				// of the loop of its parent on its children, would make the next one skip this frame)
				if (Std.isOfType(parent, Clip))
					return;
				isPlaying = false;
				visible = false;
				removed.push(this);
			case "objKill":
				// obj.kill(): the sprite of the clip is killed (at the start of the game update)
				isPlaying = false;
				visible = false;
				var self = this;
				var prev = onRemoved;
				onRemoved = function() {
					var o:Dynamic = Reflect.field(self, "obj");
					if (o != null)
						o.kill();
					if (prev != null)
						prev();
				};
				removed.push(this);
			case "rndRotH":
				// h._rotation = random(360)
				var s = get("h");
				if (s != null)
					s._rotation = Seed.randomVfx(360);
			case "rndStop":
				// gotoAndStop(random(_totalframes) + 1)
				goto(1 + Seed.randomVfx(def.n), false);
			case "rndRot":
				// smc._rotation = random(360)
				var s = get("smc");
				if (s != null)
					s._rotation = Seed.randomVfx(360);
			case _:
		}
	}

	// ---------------------------------------------------------------- display
	function display(f:Int) {
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
				overrides.remove(i);
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
			if (L.k != 2) {
				(cast o : Gfx).show(p);
				o.visible = hiddenLayers == null || !hiddenLayers.exists(i);
			}
			place(i, o, f);
			if (fresh)
				o.updateState();
		}
	}

	function createLayer(i:Int):ASprite {
		var L = def.layers[i];
		var o:ASprite;
		var bm = blendOf(L.bl, blendIn);
		if (L.k == 2) {
			o = new Clip(L.a, 0, mulColor(tintIn, layerTint(L, frame)), addColor(addIn, mulColor(tintIn, layerAdd(L, frame))), bm);
		} else {
			o = new Gfx(L.a);
			if (L.k != 3)
				o.blendMode = bm;
		}
		if (L.nm != null)
			o._name = L.nm;
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
		overrides.remove(i);
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
		if (m != null && (c == null || !c.scripted)) {
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
		var ov = overrides.get(i);
		if (ov != null) {
			if (ov.x != null)
				o._x = ov.x;
			if (ov.y != null)
				o._y = ov.y;
			if (ov.rot != null)
				o._rotation = ov.rot;
			if (ov.xs != null)
				o._xscale = ov.xs;
			if (ov.ys != null)
				o._yscale = ov.ys;
		}
		o._alpha = (ov != null && ov.al != null) ? ov.al : (L.al0 != null ? L.al0 : (L.al != null ? L.al[f - 1] : 1)) * 100;
		var tn = mulColor(tintIn, layerTint(L, f));
		var ad = addColor(addIn, mulColor(tintIn, layerAdd(L, f)));
		if (c != null) {
			c.setColour(tn, ad);
		} else {
			o.tint = tn;
			// (also back to 0: the white flash of a hit enemy must go away)
			(cast o : Gfx).setAdd(ad);
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

	// _visible = false on a named instance by the code: it stays hidden on the next frames (Flash keeps it)
	var hiddenLayers:Map<Int, Bool>;

	public function hideLayer(name:String) {
		var i = layerIndex(name);
		if (i < 0)
			return;
		if (hiddenLayers == null)
			hiddenLayers = new Map();
		hiddenLayers.set(i, true);
		if (objs[i] != null)
			objs[i].visible = false;
	}

	public function getClip(name:String):Clip {
		return Std.downcast(get(name), Clip);
	}

	// transform of a named instance set by the code (like _rotation, _x... on a Flash clip): kept while the instance
	// lives, ignored when it is not on the current frame
	public function setOverride(name:String, rot:Null<Float>, xs:Null<Float>, ys:Null<Float>, ?x:Null<Float>, ?y:Null<Float>, ?alpha:Null<Float>) {
		var i = layerIndex(name);
		if (i < 0 || objs[i] == null)
			return;
		var ov = overrides.get(i);
		if (ov == null) {
			ov = {};
			overrides.set(i, ov);
		}
		if (rot != null)
			ov.rot = rot;
		if (xs != null)
			ov.xs = xs;
		if (ys != null)
			ov.ys = ys;
		if (x != null)
			ov.x = x;
		if (y != null)
			ov.y = y;
		if (alpha != null)
			ov.al = alpha;
		place(i, objs[i], frame);
	}

	// transform of a named layer from the tables: [x, y, scaleX, scaleY, rotation (deg)] in pixels of the clip
	public function layerMatrix(name:String, ?f:Int):Array<Float> {
		var i = layerIndex(name);
		if (i < 0)
			return null;
		var L = def.layers[i];
		return L.m0 != null ? L.m0 : L.m[(f == null ? frame : f) - 1];
	}

	// pixels of the clip per Flash pixel
	public inline function pxPerUnit():Float {
		return K * def.r;
	}

	// a frozen copy of the picture (afterimages): same frame, nested clips on their current frames
	public function snapshot(?pxPerUnit:Float = 1):Clip {
		var c = new Clip(clipName, pxPerUnit, tintIn, addIn);
		c.copyFrames(this);
		c.freeze();
		return c;
	}

	function copyFrames(src:Clip) {
		if (src.frame != frame) {
			display(src.frame);
		}
		for (i in 0...objs.length) {
			var a = Std.downcast(objs[i], Clip);
			var b = Std.downcast(src.objs[i], Clip);
			if (a != null && b != null)
				a.copyFrames(b);
		}
		for (i => ov in src.overrides)
			if (objs[i] != null) {
				overrides.set(i, {rot: ov.rot, xs: ov.xs, ys: ov.ys, x: ov.x, y: ov.y, al: ov.al});
				place(i, objs[i], frame);
			}
	}

	public function freeze() {
		frozen = true;
		isPlaying = false;
		for (o in objs) {
			var c = Std.downcast(o, Clip);
			if (c != null)
				c.freeze();
		}
	}

	override public function removeMovieClip() {
		super.removeMovieClip();
		isPlaying = false;
	}
}
