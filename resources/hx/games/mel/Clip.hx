package mel;

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
	?labList:Array<{name:String, frame:Int}>,
	?simple:Bool
};

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

	override public function update() {
		if (_prevState == null)
			_prevState = new TransformState(this);
		_prevState.copyFrom(_curState);
	}

	override public function updateGraphics(a:Float) {
		Clip.noFlipLerp(this);
		super.updateGraphics(a);
	}
}

/**
 * AS3 MovieClip replayed from the exported timeline tables (Flash Player 11 rules, the original is an Arkadeo game):
 *  - every clip advances one frame per Flash frame while it plays (Game.flashFrame calls tick on the clips it
 *    owns, nested clips advance with their parent), also when it is not on the display list;
 *  - the frame scripts of the AS3 classes (gfx_fla.*: stop / gotoAndPlay) of a frame reached by the playhead run after
 *    the game code of that frame (enterFrame, then frame scripts); a goto of the code runs the script of its frame at
 *    once;
 *  - nextFrame / prevFrame go to the next / previous frame and stop (not past the ends).
 * KadoKadeo's step (32 per second) does not move the playheads: update() only keeps the previous state.
 */
class Clip extends ASprite {
	public static inline var K = 2;

	static var defs:Map<String, ClipDef> = new Map();
	// scripts of the frames reached by the playheads during this Flash frame (run after the game code)
	static var pending:Array<Clip> = [];
	static var pendingFrame:Array<Int> = [];

	public var def(default, null):ClipDef;
	public var clipName(default, null):String;
	public var frame(default, null):Int;

	// frozen picture (afterimages): no timeline at all
	public var frozen:Bool;

	// a top level clip is in Flash pixels: scale 1 = textures at their resolution
	public var baseScale(default, null):Float;

	var objs:Array<ASprite>;
	var pids:Array<Int>;
	var deadPid:Array<Int>;
	var tintIn:Int;
	var addIn:Int;
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
			d.labList = [];
			if (d.labels != null)
				for (k in Reflect.fields(d.labels)) {
					d.lab.set(k, Reflect.field(d.labels, k));
					d.labList.push({name: k, frame: Reflect.field(d.labels, k)});
				}
			d.labList.sort((a, b) -> a.frame - b.frame);
			d.simple = d.layers.length == 1 && d.layers[0].k == 0;
			defs.set(name, d);
		}
		return d;
	}

	public static function reset() {
		pending = [];
		pendingFrame = [];
	}

	// pxPerUnit: pixels of the parent per Flash pixel (1 in the game, 0 = nested clip placed by its parent)
	public function new(name:String, ?pxPerUnit:Float = 1, ?tint:Int = 0xFFFFFF, ?add:Int = 0) {
		super();
		def = getDef(name);
		clipName = name;
		_name = name;
		_totalframes = def.n;
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
			_curState.xscale = baseScale;
			_curState.yscale = baseScale;
		}
		frame = 0;
		var f = def.start != null ? def.start : 1;
		isPlaying = def.still == null;
		display(f);
		// the script of the first frame runs at the creation (the constructor of the AS3 class)
		runActions(f, 0);
	}

	// A scale that changes its sign is a flip (a character turning around): in Flash it is instant, interpolated
	// between two steps it would show the picture squeezed flat
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

	// KadoKadeo step: the previous state only (the playheads move in tick)
	override public function update() {
		if (_prevState == null)
			_prevState = new TransformState(this);
		_prevState.copyFrom(_curState);
		for (c in children)
			if (Std.isOfType(c, ASprite))
				(cast c : ASprite).update();
	}

	// ---------------------------------------------------------------- AS3 MovieClip
	public var currentFrame(get, never):Int;
	public var totalFrames(get, never):Int;
	public var currentLabel(get, never):String;
	public var currentFrameLabel(get, never):String;

	inline function get_currentFrame()
		return frame;

	inline function get_totalFrames()
		return def.n;

	// label of the current frame or of the last labelled frame before it
	function get_currentLabel():String {
		var r:String = null;
		for (l in def.labList)
			if (l.frame <= frame)
				r = l.name;
		return r;
	}

	// label of the current frame only
	function get_currentFrameLabel():String {
		for (l in def.labList)
			if (l.frame == frame)
				return l.name;
		return null;
	}

	// currentScene.labels
	public function labels():Array<{name:String, frame:Int}> {
		return def.labList;
	}

	public inline function playing():Bool {
		return isPlaying;
	}

	// ---------------------------------------------------------------- playhead
	// one Flash frame: the nested clips that exist advance, then this one (new nested clips start on their frame 1)
	public function tick() {
		if (frozen)
			return;
		for (o in objs) {
			var c = Std.downcast(o, Clip);
			if (c != null)
				c.tick();
		}
		if (isPlaying) {
			var f = frame + 1;
			if (f > def.n)
				f = 1;
			if (f != frame) {
				display(f);
				if (def.act[f] != null) {
					pending.push(this);
					pendingFrame.push(f);
				}
			}
		}
	}

	// the frame scripts of the frames the playheads reached, after the game code of the Flash frame
	public static function runPending() {
		var i = 0;
		while (i < pending.length) {
			var c = pending[i];
			var f = pendingFrame[i];
			i++;
			if (c.frame == f && !c.frozen)
				c.runActions(f, 0);
		}
		pending = [];
		pendingFrame = [];
	}

	override public function nextFrame() {
		goto(frame + 1 > def.n ? def.n : frame + 1, false);
	}

	override public function prevFrame() {
		goto(frame > 1 ? frame - 1 : 1, false);
	}

	override public function play() {
		if (def.still == null)
			isPlaying = true;
	}

	override public function stop() {
		isPlaying = false;
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
				case _:
			}
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
			if (L.k != 2) {
				(cast o : Gfx).show(p);
				o.visible = true;
			}
			place(i, o, f);
			if (fresh)
				o.updateState();
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
		untyped o._zIndex = i;
		var idx = 0;
		for (j in 0...i)
			if (objs[j] != null)
				idx++;
		addChildAt(o, Std.int(Math.min(idx, children.length)));
		objs[i] = o;
		if (L.k == 3) {
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
		if (m != null) {
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
		var c = L.k == 2 ? (cast o : Clip) : null;
		if (c != null) {
			c.setColour(tn, ad);
		} else {
			o.tint = tn;
			if (ad != 0 || L.ad != null || L.ads != null || addIn != 0)
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

	public function getClip(name:String):Clip {
		return Std.downcast(get(name), Clip);
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
		if (src.frame != frame)
			display(src.frame);
		for (i in 0...objs.length) {
			var a = Std.downcast(objs[i], Clip);
			var b = Std.downcast(src.objs[i], Clip);
			if (a != null && b != null)
				a.copyFrames(b);
		}
	}

	public function stopAll() {
		isPlaying = false;
		for (o in objs) {
			var c = Std.downcast(o, Clip);
			if (c != null)
				c.stopAll();
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
