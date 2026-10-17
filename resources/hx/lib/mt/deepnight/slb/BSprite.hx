package mt.deepnight.slb;

import kado.Seed;
import mt.MLib;
import mt.deepnight.slb.BLib; // the typedefs LibGroup / FrameData / SLBError

// slb.BSprite on PixiJS: a flash.display.Sprite (a PIXI.Container) showing a child PIXI.Sprite (`bmp`) textured with a
// frame of the sheet. AnimManager plays its anims.
class BSprite extends common_haxe_avm2.display.Sprite implements SpriteInterface {
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

	var bmp:Dynamic; // the child PIXI.Sprite

	public function new(?l:BLib, ?g:String, ?frame = 0) {
		super();
		destroyed = false;
		this.frame = 0;
		slbPivot = new SpritePivot();
		a = new AnimManager(this);
		bmp = js.Syntax.code("new PIXI.Sprite()");
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
			bmp.texture = lib.getFrameTexture(groupName, frame);
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
		// horizontal flip on the BITMAP, not on the container: the scale x of the container stays positive, so its
		// PIXI width too (Hero places its hair with it). bmp.x = -px when flipped: mirrored around the origin.
		bmp.scale.x = flipX;
		bmp.x = flipX > 0 ? px : -px;
		bmp.y = py;
	}

	// sign of the flip, kept apart so that the scale of the container stays positive: get_scaleX gives the signed value
	// (Hero tests scaleX < 0), set_scaleX sets a scale >= 0 on the container and flips the bitmap
	var flipX:Float = 1;

	override function get_scaleX():Float return flipX * scale.x;

	override function set_scaleX(v:Float):Float {
		flipX = v < 0 ? -1 : 1;
		scale.x = v < 0 ? -v : v;
		applyPivot();
		return v;
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
		untyped if (bmp != null) bmp.tint = c;

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
	public function getAttachRect(points:Map<String, Array<Int>>):common_haxe_avm2.geom.Rectangle {
		var r = isReady() ? points.get(groupName + "#" + frame) : null;
		return r == null ? new common_haxe_avm2.geom.Rectangle(0, 0, 0, 0) : new common_haxe_avm2.geom.Rectangle(r[0], r[1], r[2], r[3]);
	}

	public function clone<T>(?s:T):T {
		var c = new BSprite(lib, groupName, frame);
		return cast c;
	}

	public function toString():String return "BSprite_" + groupName + "[" + frame + "]";

	public function dispose():Void {
		if (destroyed) return;
		destroyed = true;
		if (lib != null) lib.removeChild(this);
		if (parent != null) parent.removeChild(this);
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
