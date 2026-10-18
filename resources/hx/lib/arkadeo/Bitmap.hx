package arkadeo;

import pixi.core.textures.Texture;

// flash.display.Bitmap: a picture (an animation frame of the sheets, or a BitmapData) drawn from its top left corner
class Bitmap extends DisplayObject {
	public var bmpWidth(default, null):Float = 0;
	public var bmpHeight(default, null):Float = 0;

	public var anim(default, null):String;

	public function new(?anim:String, ?frame:Int = 1, ?bitmapData:BitmapData) {
		super(new Node());
		if (anim != null)
			setAnim(anim, frame);
		if (bitmapData != null)
			this.bitmapData = bitmapData;
	}

	// (a picture drawn at run time: its changes are shown)
	public var bitmapData(default, set):BitmapData = null;

	function set_bitmapData(b:BitmapData):BitmapData {
		bitmapData = b;
		if (b != null)
			setTexture(b.getTexture(), b.width, b.height);
		else
			setTexture(Texture.EMPTY, 0, 0);
		return b;
	}

	// the picture of another bitmap (new Bitmap(b.bitmapData))
	public static function copy(b:Bitmap):Bitmap {
		var c = new Bitmap();
		c.setTexture(b.node.texture, b.bmpWidth, b.bmpHeight);
		c.anim = b.anim;
		return c;
	}

	public function setAnim(a:String, ?frame:Int = 1) {
		anim = a;
		var t = Tex.get(a)[frame - 1];
		node.texture = t;
		node.anchor.copyFrom(t.defaultAnchor);
		bmpWidth = t.orig.width;
		bmpHeight = t.orig.height;
	}

	public function setTexture(t:Texture, w:Float, h:Float) {
		node.texture = t;
		node.anchor.set(0, 0);
		bmpWidth = w;
		bmpHeight = h;
	}

	override function get_width():Float
		return bmpWidth * Math.abs(vsx);

	override function get_height():Float
		return bmpHeight * Math.abs(vsy);

	override public function contentRect():Rectangle {
		var a = node.anchor;
		return new Rectangle(-a.x * bmpWidth, -a.y * bmpHeight, bmpWidth, bmpHeight);
	}

	override function applyColour() {
		node.tint = ct == null ? 0xFFFFFF : ct.tint();
	}
}
