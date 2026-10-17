package mel;

import mel.Fl;

/**
 * The libraries of Motion Twin the original used (mt.Rand, mt.gx.Pool, mt.gx.time.FTimer, mt.deepnight.Tweenie, mt.fx.*),
 * as compiled in the released game.swf (decompiled).
 *
 * AS3 computes with doubles and converts to a 32 bit int when a value is stored into an int (an int variable, field
 * or parameter): I32.of does that conversion where the original stored a value that can overflow (Haxe on JS keeps
 * the double).
 */
class I32 {
	public static inline function of(v:Float):Int {
		return js.Syntax.code("({0}) | 0", v);
	}

	// int(a * b) of AS3 (doubles, then the conversion)
	public static inline function mul(a:Float, b:Float):Int {
		return of(a * b);
	}
}

// mt.Rand (Parker-Miller-Carta LCG) as compiled for Flash 9: the seed is a double
class MRand {
	public var seed:Float;

	public function new(s:Int) {
		seed = (s < 0 ? -s : s) + 131;
	}

	public inline function int():Int {
		seed = (seed * 16807) % 2147483647;
		return I32.of(seed) & 0x3FFFFFFF;
	}

	// (n = 0: int(x % 0) = int(NaN) = 0, like AS3)
	public inline function random(n:Int):Int {
		var v:Float = int();
		return I32.of(v % n);
	}

	public inline function rand():Float {
		return (int() % 10007) / 10007.0;
	}

	public function initSeed(n:Int, ?k:Int = 5) {
		for (i in 0...k) {
			n ^= (n << 7) & 0x2b5b2500;
			n ^= (n << 15) & 0x1b8b0000;
			n ^= n >>> 16;
			n &= 0x3FFFFFFF;
			var h = 5381;
			h = I32.of((h << 5) + h + (n & 0xFF));
			h = I32.of((h << 5) + h + ((n >> 8) & 0xFF));
			h = I32.of((h << 5) + h + ((n >> 16) & 0xFF));
			h = I32.of((h << 5) + h + (n >> 24));
			n = h & 0x3FFFFFFF;
		}
		seed = (n & 0x1FFFFFFF) + 131;
	}
}

// random picks of mt.gx (LambdaEx.random, ListEx.random, ArrayEx.normRand): with a mt.Rand, or Std.random (only
// pictures: the effects random of KadoKadeo)
class Pick {
	public static function index(count:Int, ?rd:MRand):Int {
		if (rd != null)
			return rd.random(count);
		return count <= 0 ? 0 : kado.Seed.randomVfx(count);
	}

	public static function array<T>(a:Array<T>, ?rd:MRand):T {
		var i = index(a.length, rd);
		return i < a.length ? a[i] : null;
	}

	public static function list<T>(l:List<T>, ?rd:MRand):T {
		var i = index(l.length, rd);
		var k = 0;
		for (x in l) {
			if (k == i)
				return x;
			k++;
		}
		return null;
	}

	// index of an entry drawn by weight (ArrayEx.normRand)
	public static function normRand(a:Array<{weight:Int, pow:DefaultImport.CharPowers}>, ?rd:MRand):Null<Int> {
		var tot = 0;
		for (e in a)
			tot += e.weight;
		var r:Int = index(tot, rd);
		var i = 0;
		for (e in a) {
			r -= e.weight;
			if (r < 0)
				return i;
			i++;
		}
		return null;
	}
}

// mt.gx.Pool: free objects in a list (last freed, first reused)
class Pool<T> {
	var used:List<T>;
	var free:List<T>;
	var newProc:Void->T;

	public function new(f:Void->T) {
		free = new List();
		used = new List();
		newProc = f;
	}

	public function reserve(n:Int):Pool<T> {
		for (i in 0...n)
			free.push(newProc());
		return this;
	}

	public function create():T {
		var o = free.pop();
		if (o == null)
			o = newProc();
		used.push(o);
		return o;
	}

	public function destroy(o:T) {
		if (used.remove(o))
			free.push(o);
	}

	public inline function getUsed():List<T> {
		return used;
	}

	public inline function nbUsed():Int {
		return used.length;
	}

	public function kill() {
		used.clear();
		free.clear();
	}
}

// mt.gx.time.FTimer: functions called after a number of frames, or every frame with the ratio of the time spent
class FTimer {
	static var delayed:List<{func:Void->Void, end:Int}>;
	static var ticked:List<{func:Float->Void, end:Int, dur:Int}>;
	static var timer:Int = 0;

	public static function reset() {
		delayed = new List();
		ticked = new List();
		timer = 0;
	}

	public static function delay(f:Void->Void, n:Int) {
		delayed.push({func: f, end: timer + n});
	}

	public static function tick(f:Float->Void, n:Int) {
		ticked.push({func: f, end: timer + n, dur: n});
	}

	public static function update() {
		for (d in delayed)
			if (timer >= d.end) {
				d.func();
				delayed.remove(d);
			}
		for (t in ticked) {
			t.func(1 - (t.end - timer) / t.dur);
			if (timer >= t.end)
				ticked.remove(t);
		}
		timer++;
	}
}

enum TType {
	TLinear;
	TLoop;
	TLoopEaseIn;
	TLoopEaseOut;
	TEase;
	TEaseIn;
	TEaseOut;
	TBurn;
	TBurnIn;
	TBurnOut;
	TZigZag;
	TRand;
	TShake;
	TShakeBoth;
	TJump;
	TElasticEnd;
}

typedef Tween = {
	parent:Dynamic,
	vname:String,
	n:Float,
	ln:Float,
	speed:Float,
	from:Float,
	to:Float,
	type:TType,
	interpolate:Float->Float,
	?onUpdate:Void->Void,
	?onUpdateT:Float->Void,
	?onEnd:Void->Void
}

// mt.deepnight.Tweenie (Haxe 2 version): a property of an object goes to a value in a duration (ms at baseFPS)
class Tweenie {
	var tlist:List<Tween>;
	var baseFPS:Int;

	public function new(fps:Int) {
		baseFPS = fps;
		tlist = new List();
	}

	static inline function bezier(t:Float, p0:Float, p1:Float, p2:Float, p3:Float):Float {
		var u = 1 - t;
		return u * u * u * p0 + 3 * t * u * u * p1 + 3 * t * t * u * p2 + t * t * t * p3;
	}

	static function interp(t:TType):Float->Float {
		return switch (t) {
			case TLinear, TRand: s -> s;
			case TEase: s -> bezier(s, 0, 0, 1, 1);
			case TEaseIn: s -> bezier(s, 0, 0, 0.5, 1);
			case TEaseOut: s -> bezier(s, 0, 0.5, 1, 1);
			case TBurn: s -> bezier(s, 0, 1, 0, 1);
			case TBurnIn: s -> bezier(s, 0, 1, 1, 1);
			case TBurnOut: s -> bezier(s, 0, 0, 0, 1);
			case TZigZag: s -> bezier(s, 0, 2.5, -1.5, 1);
			case TLoop: s -> bezier(s, 0, 1.33, 1.33, 0);
			case TLoopEaseIn: s -> bezier(s, 0, 0, 2.25, 0);
			case TLoopEaseOut: s -> bezier(s, 0, 2.25, 0, 0);
			case TShake, TShakeBoth: s -> bezier(s, 0.5, 1.22, 1.25, 0);
			case TJump: s -> bezier(s, 0, 2, 2.79, 1);
			case TElasticEnd: s -> bezier(s, 0, 0.7, 1.5, 1);
		}
	}

	public function create(parent:Dynamic, v:String, to:Float, ?tp:TType, ?duration:Float):Tween {
		if (duration == null)
			duration = 1000;
		if (tp == null)
			tp = TEase;
		var old:TType = null;
		for (t in tlist)
			if (t.parent == parent && t.vname == v) {
				old = t.type;
				tlist.remove(t);
			}
		if (old != null && tp == TEase && (old == TEase || old == TEaseOut))
			tp = TEaseOut;
		var t:Tween = {
			parent: parent,
			vname: v,
			n: 0,
			ln: 0,
			speed: 1 / (duration * baseFPS / 1000),
			from: Reflect.getProperty(parent, v),
			to: to,
			type: tp,
			interpolate: interp(tp),
		};
		if (t.from == t.to)
			t.ln = 1;
		tlist.add(t);
		return t;
	}

	public function update() {
		for (t in tlist) {
			var dist = t.to - t.from;
			t.ln += t.type == TRand ? (kado.Seed.randomVfx(100) < 33 ? t.speed : 0) : t.speed;
			t.n = t.interpolate(t.ln);
			if (t.ln < 1) {
				var v = t.from + t.n * dist;
				Reflect.setProperty(t.parent, t.vname, v);
				if (t.onUpdate != null)
					t.onUpdate();
				if (t.onUpdateT != null)
					t.onUpdateT(t.ln);
			} else {
				Reflect.setProperty(t.parent, t.vname, t.from + (t.to - t.from) * t.interpolate(1));
				if (t.onUpdate != null)
					t.onUpdate();
				if (t.onUpdateT != null)
					t.onUpdateT(1);
				if (t.onEnd != null) {
					var e = t.onEnd;
					t.onEnd = null;
					e();
				}
				tlist.remove(t);
			}
		}
	}
}

// ---------------------------------------------------------------- mt.fx
class FxManager {
	public static var DEFAULT:FxManager = null;

	public var fxs:Array<Fx> = [];

	public function new() {
		if (DEFAULT == null)
			DEFAULT = this;
	}

	public function update() {
		for (f in fxs.copy())
			f.update();
	}

	public function remove(f:Fx) {
		fxs.remove(f);
		f.manager = null;
	}

	public function add(f:Fx) {
		if (f.manager != null)
			f.manager.remove(f);
		f.manager = this;
		fxs.push(f);
	}
}

class Fx {
	public var onFinish:Void->Void;
	public var manager:FxManager;
	public var dead:Bool = false;
	public var curve:Float->Float;
	public var coef:Float = 0;

	public function new(?m:FxManager) {
		if (m == null)
			m = FxManager.DEFAULT;
		m.add(this);
		curve = v -> v;
	}

	public function update() {}

	public function kill() {
		if (dead)
			return;
		dead = true;
		if (onFinish != null)
			onFinish();
		if (manager != null)
			manager.remove(this);
	}
}

class Visibility extends Fx {
	public var root:DO;

	var fadeScale:{sx:Int, sy:Int, scx:Float, scy:Float} = null;
	var fadeBlur:{x:Float, y:Float} = null;

	public var fadeAlpha:Bool = false;

	var alpha:Float = 1;

	public function new(r:DO) {
		super();
		root = r;
	}

	public function setVisibility(c:Float) {
		if (fadeAlpha)
			root.alpha = c * alpha;
		if (fadeBlur != null)
			root.filters = [Blur(fadeBlur.x * (1 - c), fadeBlur.y * (1 - c))];
		if (fadeScale != null) {
			switch (fadeScale.sx) {
				case -1:
					root.scaleX = fadeScale.scx / c;
				case 1:
					root.scaleX = fadeScale.scx * c;
				case _:
			}
			switch (fadeScale.sy) {
				case -1:
					root.scaleY = fadeScale.scy / c;
				case 1:
					root.scaleY = fadeScale.scy * c;
				case _:
			}
		}
		return this;
	}
}

class Vanish extends Visibility {
	public var timer:Float;
	public var fadeLimit:Float;

	public function new(r:DO, ?timer:Float = 10, ?fadeLimit:Float = 10, ?fadeAlpha:Bool = false) {
		super(r);
		this.timer = timer;
		this.fadeLimit = fadeLimit;
		this.fadeAlpha = fadeAlpha;
		alpha = root.alpha;
	}

	override public function update() {
		if (root.parent == null) {
			kill();
			return;
		}
		var t = timer;
		timer = t - 1;
		if (t < fadeLimit) {
			setVisibility(curve(timer / fadeLimit));
			if (timer == 0)
				kill();
		}
	}

	public function setFadeScale(sx:Int, sy:Int):Vanish {
		fadeScale = {sx: sx, sy: sy, scx: root.scaleX, scy: root.scaleY};
		return this;
	}

	public function setFadeBlur(x:Float, y:Float):Vanish {
		fadeBlur = {x: x, y: y};
		return this;
	}

	override public function kill() {
		super.kill();
		root.detach();
	}
}

class Spawn extends Visibility {
	var spc:Float;

	public function new(r:DO, ?spc:Float = 0.1, ?fadeAlpha:Bool = true, ?fadeScale:Bool = false) {
		super(r);
		this.spc = spc;
		if (fadeAlpha) {
			alpha = root.alpha;
			root.alpha = 0;
			this.fadeAlpha = true;
		}
		if (fadeScale) {
			this.fadeScale = {sx: 1, sy: 1, scx: root.scaleX, scy: root.scaleY};
			root.scaleX = 0;
			root.scaleY = 0;
		}
	}

	override public function update() {
		super.update();
		coef = Math.min(coef + spc, 1);
		setVisibility(curve(coef));
		if (coef == 1)
			kill();
	}
}

class Blink extends Fx {
	var timer:Int;
	var on:Int;
	var off:Int;
	var mc:DO;

	public function new(mc:DO, ?timer:Int = 10, ?on:Int = 2, ?off:Int = 2) {
		super();
		this.mc = mc;
		this.timer = timer;
		this.on = on;
		this.off = off;
	}

	override public function update() {
		mc.visible = Math.abs(timer) % (on + off) < on;
		timer--;
		if (mc.parent == null)
			kill();
		if (timer == 0)
			kill();
	}
}

class Sleep extends Fx {
	var f:Fx;
	var count:Int;

	public var onWakeUp:Void->Void;

	public function new(f:Fx, ?onWakeUp:Void->Void, ?count:Int = 10) {
		super();
		this.f = f;
		this.onWakeUp = onWakeUp;
		this.count = count;
		FxManager.DEFAULT.remove(f);
	}

	override public function update() {
		super.update();
		var c = count;
		count = c - 1;
		if (c <= 0) {
			if (f != null) {
				FxManager.DEFAULT.add(f);
				f.update();
			}
			if (onWakeUp != null)
				onWakeUp();
			kill();
		}
	}
}

// mt.fx.Part: a particle (fadeType 2: scale)
class Part extends Fx {
	public var root:DO;
	public var x:Float;
	public var y:Float;
	public var vx:Float = 0;
	public var vy:Float = 0;
	public var weight:Float = 0;
	public var vr:Float = 0;
	public var rfr:Float = 1;
	public var sfr:Null<Float> = null;
	public var frict:Float = 1;
	public var scale:Float = 1;
	public var alpha:Float = 1;
	public var timer:Int = -1;
	public var fadeLimit:Int = 10;
	public var fadeType:Int = 0;

	var fadeInData:{timer:Int, limit:Int} = null;

	public function new(r:DO) {
		super();
		root = r;
		x = root.x;
		y = root.y;
	}

	function updatePos() {
		root.x = x;
		root.y = y;
	}

	function applyFade(c:Float) {
		switch (fadeType) {
			case 1:
				root.alpha = c * alpha;
			case 2:
				root.scaleX = root.scaleY = c * scale;
			case 3:
				root.scaleX = c * scale;
			case 4:
				root.scaleY = c * scale;
			case _:
		}
	}

	override public function update() {
		vy += weight;
		vx *= frict;
		vy *= frict;
		x += vx;
		y += vy;
		vr *= rfr;
		root.rotation += vr;
		if (sfr != null) {
			scale *= sfr;
			setScale(scale);
		}
		if (fadeInData != null) {
			fadeInData.timer++;
			var c = fadeInData.timer / fadeInData.limit;
			applyFade(c);
			if (c == 1)
				fadeInData = null;
		}
		timer--;
		if (timer < fadeLimit && timer >= 0)
			applyFade(timer / fadeLimit);
		if (timer == 0)
			kill();
		updatePos();
	}

	public function sleep(n:Int) {
		var s = new Sleep(this, null, n);
		root.visible = false;
		s.onFinish = () -> root.visible = true;
	}

	public function setScale(s:Float) {
		scale = s;
		root.scaleX = s;
		root.scaleY = s;
	}

	override public function kill() {
		root.detach();
		super.kill();
	}

	public function fadeIn(n:Int) {
		fadeInData = {timer: 0, limit: n};
		root.scaleX = root.scaleY = 0;
	}
}
