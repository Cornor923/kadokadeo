package common_haxe_avm2.geom;

// flash.geom.Matrix (an affine value a, b, c, d, tx, ty).
class Matrix {
	public var a:Float;
	public var b:Float;
	public var c:Float;
	public var d:Float;
	public var tx:Float;
	public var ty:Float;

	public function new(?a:Float = 1, ?b:Float = 0, ?c:Float = 0, ?d:Float = 1, ?tx:Float = 0, ?ty:Float = 0) {
		this.a = a;
		this.b = b;
		this.c = c;
		this.d = d;
		this.tx = tx;
		this.ty = ty;
	}

	public function identity():Void {
		a = 1; b = 0; c = 0; d = 1; tx = 0; ty = 0;
	}

	public function translate(dx:Float, dy:Float):Void {
		tx += dx;
		ty += dy;
	}

	public function scale(sx:Float, sy:Float):Void {
		a *= sx; b *= sy; c *= sx; d *= sy; tx *= sx; ty *= sy;
	}

	public function clone():Matrix return new Matrix(a, b, c, d, tx, ty);
}
