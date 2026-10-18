package arkadeo;

// flash.filters.BlurFilter: drawn by PIXI's BlurFilter (none when blurX and blurY are 0)
class BlurFilter extends BitmapFilter {
	// the strength of PIXI's blur per Flash blur pixel, and its quality whatever the Flash one (null: the Flash one); the
	// defaults are Mel's (Flash.reset)
	public static var scale:Float = 0.5;
	public static var forceQuality:Null<Int> = 2;

	public var blurX:Float;
	public var blurY:Float;
	public var quality:Int;

	public function new(blurX:Float = 4, blurY:Float = 4, quality:Int = 1) {
		this.blurX = blurX;
		this.blurY = blurY;
		this.quality = quality;
	}

	override public function toPixi():Dynamic {
		if (blurX <= 0 && blurY <= 0)
			return null;
		var b:Dynamic = js.Syntax.code("new PIXI.filters.BlurFilter()");
		b.blurX = blurX * scale;
		b.blurY = blurY * scale;
		b.quality = forceQuality != null ? forceQuality : quality;
		return b;
	}

	override public function clone():BitmapFilter {
		return new BlurFilter(blurX, blurY, quality);
	}
}
