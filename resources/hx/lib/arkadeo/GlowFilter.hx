package arkadeo;

enum GlowStyle {
	// Flash's: the alpha blurred by a box (FlashGlow)
	FLASH;
	// the shader of pixi-filters (SampledGlow)
	SAMPLED;
}

// flash.filters.GlowFilter
class GlowFilter extends BitmapFilter {
	// how the glows of the game are drawn (Flash.reset: FLASH)
	public static var style:GlowStyle = FLASH;

	public var color:Int;
	public var alpha:Float;
	public var blurX:Float;
	public var blurY:Float;
	public var strength:Float;
	public var quality:Int;
	public var inner:Bool;
	public var knockout:Bool;

	public function new(color:Int = 0xFF0000, alpha:Float = 1, blurX:Float = 6, blurY:Float = 6, strength:Float = 2, quality:Int = 1,
			inner:Bool = false, knockout:Bool = false) {
		this.inner = inner;
		this.knockout = knockout;
		this.color = color;
		this.alpha = alpha;
		this.blurX = blurX;
		this.blurY = blurY;
		this.strength = strength;
		this.quality = quality;
	}

	override public function toPixi():Dynamic {
		return switch (style) {
			case FLASH: new FlashGlow(blurX, blurY, strength, color, alpha, inner);
			case SAMPLED: new SampledGlow(color, alpha, blurX, blurY, strength, quality, inner);
		}
	}

	override public function clone():BitmapFilter {
		return new GlowFilter(color, alpha, blurX, blurY, strength, quality, inner, knockout);
	}
}
