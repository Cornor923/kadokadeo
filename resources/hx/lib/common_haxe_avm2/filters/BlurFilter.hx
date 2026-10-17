package common_haxe_avm2.filters;

// PIXI.filters.BlurFilter is part of PixiJS (unlike Glow / DropShadow, which need
// pixi-filters): flash.filters.BlurFilter is a real PixiJS blur.
@:native("PIXI.filters.BlurFilter")
private extern class PixiBlur extends pixi.core.renderers.webgl.filters.Filter {
	function new(?strength:Float, ?quality:Float, ?resolution:Float, ?kernelSize:Int);
	var blur:Float;
	var blurX:Float;
	var blurY:Float;
	var quality:Int;
}

class BlurFilter extends PixiBlur {
	public function new(?blurX:Float = 4.0, ?blurY:Float = 4.0, ?quality:Int = 1) {
		super(Math.max(blurX, blurY), quality > 0 ? quality : 1);
		this.blurX = blurX;
		this.blurY = blurY;
	}
}
