package mt.deepnight.slb;

import kado.Seed;
import mt.MLib;
import mt.deepnight.slb.BLib; // the typedefs LibGroup / FrameData / SLBError

// slb.BSprite on the AS3 display list of arkadeo: a Sprite showing a child Bitmap (`bmp`, under the other children)
// with a frame of the sheet, placed by the pivot. AnimManager plays its anims.
class BSprite extends arkadeo.Sprite implements SpriteInterface {
	public static var ALL:Array<BSprite> = [];

	public var a:AnimManager;
	public var lib:BLib;
	public var groupName:String;
	public var group:LibGroup;
	public var frame:Int;
	public var frameData:FrameData;
	var slbPivot:SpritePivot; // renamed: `pivot` is DisplayObject.pivot in PixiJS
	public var destroyed:Bool;

	public var beforeRender:Null<Void->Void>;
	public var onFrameChange:Null<Void->Void>;

	var bmp:arkadeo.Bitmap;

	public function new(?l:BLib, ?g:String, ?frame = 0) {
		super();
		destroyed = false;
		this.frame = 0;
		slbPivot = new SpritePivot();
		a = new AnimManager(this);
		bmp = new arkadeo.Bitmap();
		addChild(bmp);
		ALL.push(this);
		if (l != null)
			set(l, g, frame);
	}

	public function set(?l:BLib, ?g:String, ?frame = 0, ?stopAllAnims = false):Void {
		if (l != null) {
			if (lib != null) lib.removeChild(this);
			lib = l;
			lib.addChild(this);
			if (g == null) {
				groupName = null;
				group = null;
				frameData = null;
			}
			if (slbPivot.isUndefined)
				setCenterRatio(lib.defaultCenterX, lib.defaultCenterY);
		}
		if (g != null && g != groupName)
			groupName = g;

		if (isReady()) {
			if (stopAllAnims) a.stopWithoutStateAnims();
			group = lib.getGroup(groupName);
			frameData = lib.getFrameData(groupName, frame);
			if (frameData == null) throw 'Unknown frame: $groupName($frame)';
			setFrame(frame);
		}
	}

	public function setFrame(f:Int):Void {
		frame = f;
		if (isReady()) {
			frameData = lib.getFrameData(groupName, frame);
			if (frameData == null) throw 'Unknown frame: $groupName($frame)';
			var t:Dynamic = lib.getFrameTexture(groupName, frame);
			bmp.setTexture(t, t.orig.width, t.orig.height);
			applyPivot();
			if (onFrameChange != null) onFrameChange();
		}
	}

	function applyPivot():Void {
		if (!isReady()) return;
		var px:Float;
		var py:Float;
		if (slbPivot.isUsingCoord()) {
			px = MLib.round(-slbPivot.coordX - frameData.realFrame.x);
			py = MLib.round(-slbPivot.coordY - frameData.realFrame.y);
		} else if (slbPivot.isUsingFactor()) {
			px = Std.int(-frameData.realFrame.realWid * slbPivot.centerFactorX - frameData.realFrame.x);
			py = Std.int(-frameData.realFrame.realHei * slbPivot.centerFactorY - frameData.realFrame.y);
		} else
			return;
		// (a new frame is drawn where its pivot puts it at once)
		if (bmp.x != px || bmp.y != py) {
			bmp.x = px;
			bmp.y = py;
			bmp.snap();
		}
	}

	// (the name of the original callers)
	public inline function setCenter(xr:Float, yr:Float):Void setCenterRatio(xr, yr);

	public inline function setCenterRatio(xr:Float, yr:Float):Void {
		slbPivot.setCenterRatio(xr, yr);
		applyPivot();
	}

	public inline function setPivotCoord(x:Float, y:Float):Void {
		slbPivot.setCoord(x, y);
		applyPivot();
	}

	public inline function setScale(v:Float):Void {
		scaleX = v;
		scaleY = v;
	}

	public inline function setPos(x:Float, y:Float):Void {
		this.x = x;
		this.y = y;
	}

	public inline function setSize(w:Float, h:Float):Void {
		this.width = w;
		this.height = h;
	}

	// multiplicative tint of the frame
	public function setTint(c:Int):Void
		if (bmp != null) bmp.node.tint = c;

	public function constraintSize(w:Float, ?h:Null<Float>, ?useFrameDataRealSize = false):Void {
		if (useFrameDataRealSize)
			setScale(MLib.fmin(w / frameData.realFrame.realWid, (h == null ? w : h) / frameData.realFrame.realHei));
		else
			setScale(MLib.fmin(w / this.width, (h == null ? w : h) / this.height));
	}

	public inline function setRandom(?l:BLib, g:String, rndFunc:Int->Int):Void {
		set(l, g, lib.getRandomFrame(g, rndFunc));
	}

	public inline function setRandomFrame(?rndFunc:Int->Int):Void {
		if (isReady())
			set(groupName, lib.getRandomFrame(groupName, rndFunc == null ? Seed.randomVfx : rndFunc));
	}

	public function getAnimDuration():Int {
		var g = isReady() ? group : null;
		return g != null ? g.anim.length : 0;
	}

	public inline function isGroup(k:String):Bool return groupName == k;
	public inline function is(k:String, f:Int):Bool return groupName == k && frame == f;
	public inline function isReady():Bool return !destroyed && groupName != null;
	public function totalFrames():Int return group.frames.length;

	// the pixels of an attach colour in the current frame (Hero: hair and chain), as the original found them with
	// getBitmapData().getColorBoundsRect(): measured in the frames when the sheet is built (Data.HAIR / Data.CHAIN),
	// nothing is read from the pictures at run time. (0, 0, 0, 0) when the frame has none.
	public function getAttachRect(points:Map<String, Array<Int>>):arkadeo.Rectangle {
		var r = isReady() ? points.get(groupName + "#" + frame) : null;
		return r == null ? new arkadeo.Rectangle(0, 0, 0, 0) : new arkadeo.Rectangle(r[0], r[1], r[2], r[3]);
	}

	public function clone<T>(?s:T):T {
		var c = new BSprite(lib, groupName, frame);
		return cast c;
	}

	public function toString():String return "BSprite_" + groupName + "[" + frame + "]";

	// (the name of the older SpriteLib the originals call)
	public inline function destroy():Void
		dispose();

	public function dispose():Void {
		if (destroyed) return;
		destroyed = true;
		if (lib != null) lib.removeChild(this);
		detach();
		ALL.remove(this);
		if (a != null) a.destroy();
		a = null;
		lib = null;
		frameData = null;
		group = null;
		groupName = null;
		slbPivot = null;
		beforeRender = null;
		onFrameChange = null;
	}

	// plays every living anim
	public static function updateAll():Void {
		for (s in ALL.copy())
			if (!s.destroyed) {
				s.a.update();
				if (s.beforeRender != null) s.beforeRender();
			}
	}
}
