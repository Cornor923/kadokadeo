package common_haxe_avm2.display;

// flash.display.Bitmap on a PIXI.Sprite: shows a BitmapData (canvas) as its texture.
class Bitmap extends pixi.core.sprites.Sprite {
	var _bd:BitmapData;
	public var smoothing:Bool = false;

	public function new(?bitmapData:BitmapData, ?pixelSnapping:String, ?smoothing:Bool = false) {
		super();
		this.smoothing = smoothing;
		if (bitmapData != null)
			set_bitmapData(bitmapData);
	}

	public var bitmapData(get, set):BitmapData;
	inline function get_bitmapData():BitmapData return _bd;
	function set_bitmapData(v:BitmapData):BitmapData {
		_bd = v;
		this.texture = (v != null) ? v.getTexture() : null;
		return v;
	}

	public var scaleX(get, set):Float;
	inline function get_scaleX():Float return scale.x;
	inline function set_scaleX(v:Float):Float { scale.x = v; return v; }

	public var scaleY(get, set):Float;
	inline function get_scaleY():Float return scale.y;
	inline function set_scaleY(v:Float):Float { scale.y = v; return v; }
}
