package arkadeo;

// flash.filters.ColorMatrixFilter: 4 x 5 matrix, offsets in 0..255 (PIXI's: 0..1)
class ColorMatrixFilter extends BitmapFilter {
	public var matrix:Array<Float>;

	public function new(?matrix:Array<Float>) {
		this.matrix = matrix != null ? matrix : [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
	}

	override public function toPixi():Dynamic {
		var cm:Dynamic = js.Syntax.code("new PIXI.filters.ColorMatrixFilter()");
		var mm = matrix.copy();
		mm[4] /= 255;
		mm[9] /= 255;
		mm[14] /= 255;
		mm[19] /= 255;
		cm.matrix = mm;
		return cm;
	}

	override public function clone():BitmapFilter {
		return new ColorMatrixFilter(matrix.copy());
	}
}
