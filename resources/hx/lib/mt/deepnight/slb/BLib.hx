package mt.deepnight.slb;

import kado.Seed;
import arkadeo.Rectangle;
import mt.MLib;

typedef FrameData = {
	x			: Int,
	y			: Int,
	wid			: Int,
	hei			: Int,
	realFrame	: {x:Int, y:Int, realWid:Int, realHei:Int},
	rect		: Rectangle,
	?pX			: Float,
	?pY			: Float,
}

typedef LibGroup = {
	id		: String,
	maxWid	: Int,
	maxHei	: Int,
	frames	: Array<FrameData>,
	anim	: Array<Int>,
};

enum SLBError {
	NoGroupSelected;
	GroupAlreadyExists(g:String);
	InvalidFrameDuration(s:String);
	EndFrameLower(s:String);
	InvalidFrames(s:String);
	NoCurrentGroup;
	AnimFrameExceeds(id:String, anim:String, frame:Int);
	AssetImportFailed(e:Dynamic);
	NotSameSLBFromBatch;
}

// slb.BLib on PixiJS: a frame is a texture of the game's sprite sheet (public/assets/img/content/<game>, packed from
// the atlases of the original) instead of a BitmapData blitted from the atlas. Same public API. The sheet frames are
// named `<group>/<frame>.png`: a trimmed texture keeps the size of its original frame, so a frame is drawn at (0, 0)
// of its frame like the original atlas did.
class BLib {
	var groups:Map<String, LibGroup>;
	var currentGroup:Null<LibGroup>;
	var frameRandDraw:Map<String, Array<Int>>;
	public var defaultCenterX(default, null):Float;
	public var defaultCenterY(default, null):Float;
	var gridX:Int;
	var gridY:Int;
	var children:Array<SpriteInterface>;
	var textures:Map<String, Array<Dynamic>>;

	public function new() {
		groups = new Map();
		frameRandDraw = new Map();
		textures = new Map();
		defaultCenterX = 0;
		defaultCenterY = 0;
		gridX = gridY = 16;
		children = [];
	}

	// the frames of the sheets (PIXI.Spritesheet) under `prefix`, in groups like the original importers made them:
	// ShoeBox, the anims given (group g, definition d, frame duration t: those of its .anims.xml), or TexturePacker
	// without `anims`, one anim per group, its frames in order
	public static function fromSheet(sheets:Array<Dynamic>, prefix:String, ?anims:Array<{g:String, d:String, t:Null<Int>}>):BLib {
		var lib = new BLib();
		var re = ~/^(.+)\/([0-9]+)\.png$/;
		for (sheet in sheets) {
			var tex:Dynamic = sheet.textures;
			for (name in Reflect.fields(tex)) {
				if (!StringTools.startsWith(name, prefix) || !re.match(name.substr(prefix.length)))
					continue;
				var group = re.matched(1);
				if (group.indexOf("/") >= 0)
					continue;
				var t:Dynamic = Reflect.field(tex, name);
				var w:Int = Std.int(t.orig.width);
				var h:Int = Std.int(t.orig.height);
				lib.sliceCustom(group, Std.parseInt(re.matched(2)), 0, 0, w, h);
				if (!lib.textures.exists(group))
					lib.textures.set(group, []);
				lib.textures.get(group)[Std.parseInt(re.matched(2))] = t;
			}
		}
		if (anims != null) {
			for (a in anims)
				if (lib.exists(a.g))
					lib.__defineAnim(a.g, parseAnimDefinition(a.d, a.t));
		} else {
			for (k in lib.groups.keys())
				lib.__defineAnim(k, [for (i in 0...lib.groups.get(k).frames.length) i]);
		}
		return lib;
	}

	public inline function getFrameTexture(k:String, frame:Int):Dynamic {
		return textures.get(k)[frame];
	}

	// no-op: the frames are textures of the sheet, nothing to blit (kept for the original callers)
	public function initBdGroups():Void {}

	public inline function get(k:String, ?frame = 0, ?xr = 0.0, ?yr = 0.0, ?p:arkadeo.DisplayObjectContainer):BSprite {
		var s = new BSprite(this, k, frame);
		s.setCenterRatio(xr, yr);
		if (p != null)
			p.addChild(s);
		return s;
	}

	public function getAndPlay(k:String, ?plays = 99999, ?killAfterPlay = false):BSprite {
		var s = new BSprite(this);
		s.a.play(k, plays);
		if (killAfterPlay)
			s.a.killAfterPlay();
		return s;
	}

	public inline function getRandom(k:String, ?rndFunc:Int->Int):BSprite {
		return get(k, getRandomFrame(k, rndFunc));
	}

	public inline function setDefaultCenter(cx, cy):Void {
		defaultCenterX = cx;
		defaultCenterY = cy;
	}

	public function setSliceGrid(w, h):Void {
		gridX = w;
		gridY = h;
	}

	public inline function getGroup(?k:String):Null<LibGroup> {
		return k == null ? currentGroup : groups.get(k);
	}

	public inline function getGroups() return groups;

	public inline function getAnim(k):Array<Int> return getGroup(k).anim;
	public inline function getAnimDuration(k):Int return getAnim(k).length;

	public function createGroup(k:String):Null<LibGroup> {
		if (groups.exists(k))
			throw SLBError.GroupAlreadyExists(k);
		groups.set(k, {id: k, maxWid: 0, maxHei: 0, frames: new Array(), anim: new Array()});
		return setCurrentGroup(k);
	}

	inline function setCurrentGroup(k:String):Null<LibGroup> {
		currentGroup = getGroup(k);
		return getGroup();
	}

	public function getRectangle(k:String, ?frame = 0):Null<Rectangle> {
		var g = getGroup(k);
		if (g == null) return null;
		var fr = g.frames[frame];
		if (fr == null) return null;
		return new Rectangle(fr.x, fr.y, fr.wid, fr.hei);
	}

	public inline function getFrameData(k:String, ?frame = 0):Null<FrameData> {
		var g = getGroup(k);
		return g == null ? null : g.frames[frame];
	}

	public inline function exists(k:String, ?frame = 0):Bool {
		return k != null && frame >= 0 && groups.exists(k) && groups.get(k).frames.length > frame;
	}

	// without a random function: KadoKadeo's visual random
	public function getRandomFrame(k:String, ?rndFunc:Int->Int):Int {
		if (rndFunc == null) rndFunc = Seed.randomVfx;
		return if (frameRandDraw.exists(k)) {
			var a = frameRandDraw.get(k);
			a[rndFunc(a.length)];
		} else rndFunc(countFrames(k));
	}

	public inline function countFrames(k:String):Int return getGroup(k).frames.length;

	public function sliceCustom(groupName:String, frame:Int, x:Int, y:Int, wid:Int, hei:Int, ?realFrame:{x:Int, y:Int, realWid:Int, realHei:Int}, ?pX:Float, ?pY:Float):Void {
		var g = if (exists(groupName)) getGroup(groupName) else createGroup(groupName);
		g.maxWid = MLib.max(g.maxWid, wid);
		g.maxHei = MLib.max(g.maxHei, hei);
		if (realFrame == null)
			realFrame = {x: 0, y: 0, realWid: wid, realHei: hei};
		g.frames[frame] = {x: x, y: y, wid: wid, hei: hei, realFrame: realFrame, rect: new Rectangle(x, y, wid, hei), pX: pX, pY: pY};
	}

	public function __defineAnim(?group:String, anim:Array<Int>):Void {
		if (currentGroup == null && group == null)
			throw SLBError.NoCurrentGroup;
		if (group != null)
			setCurrentGroup(group);
		var a = [];
		for (f in anim) {
			if (f >= currentGroup.frames.length)
				throw SLBError.AnimFrameExceeds(currentGroup.id, "[" + anim.join(",") + "] " + currentGroup.frames.length, f);
			a.push(f);
		}
		currentGroup.anim = a;
	}

	// anim definition "0-5, 6(2), 7(1)": frame n, or frames n to m, each shown (d) frames
	public static function parseAnimDefinition(animDef:String, ?timin = 1):Array<Int> {
		if (timin == null) timin = 1;
		animDef = StringTools.replace(animDef, ")", "(");
		var frames:Array<Int> = new Array();
		var parts = animDef.split(",");
		for (p in parts) {
			p = StringTools.trim(p);
			if (p == "") continue;
			var curTiming = timin;
			if (p.indexOf("(") > 0) {
				var t = Std.parseInt(p.split("(")[1]);
				if (t == null || Math.isNaN(t)) throw SLBError.InvalidFrameDuration(p);
				curTiming = t;
				p = p.substr(0, p.indexOf("("));
			}
			if (p.indexOf("-") < 0) {
				var f = Std.parseInt(p);
				for (i in 0...curTiming) frames.push(f);
				continue;
			}
			if (p.indexOf("-") > 0) {
				var from = Std.parseInt(p.split("-")[0]);
				var to = Std.parseInt(p.split("-")[1]) + 1;
				if (to < from) throw SLBError.EndFrameLower(p);
				while (from < to) {
					for (i in 0...curTiming) frames.push(from);
					from++;
				}
				continue;
			}
			throw SLBError.InvalidFrames(p);
		}
		return frames;
	}

	// children driven by their anims
	public function addChild(s:SpriteInterface):Void children.push(s);
	public function removeChild(s:SpriteInterface):Void children.remove(s);
	public inline function countChildren():Int return children.length;
	public function updateChildren():Void {
		for (bs in children)
			if (!bs.destroyed) {
				bs.a.update();
				if (bs.beforeRender != null) bs.beforeRender();
			}
	}

	public function destroy():Void {
		while (children.length > 0)
			children[0].dispose();
		textures = new Map();
	}

	public function toString():String {
		var l = [];
		for (k in groups.keys()) {
			var g = getGroup(k);
			l.push(k + " (" + g.maxWid + "x" + g.maxHei + ") : " + g.frames.length + "f");
		}
		return l.join("\n");
	}
}
