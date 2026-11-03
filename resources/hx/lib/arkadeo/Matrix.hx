package arkadeo;

// flash.geom.Matrix: x' = a x + c y + tx, y' = b x + d y + ty (the matrix of BitmapData.draw, of transform.matrix, of a
// gradient box)
class Matrix {
	public var a:Float;
	public var b:Float;
	public var c:Float;
	public var d:Float;
	public var tx:Float;
	public var ty:Float;

	public function new(a:Float = 1, b:Float = 0, c:Float = 0, d:Float = 1, tx:Float = 0, ty:Float = 0) {
		this.a = a;
		this.b = b;
		this.c = c;
		this.d = d;
		this.tx = tx;
		this.ty = ty;
	}

	public function identity() {
		a = d = 1;
		b = c = tx = ty = 0;
	}

	public function clone():Matrix {
		return new Matrix(a, b, c, d, tx, ty);
	}

	public function translate(dx:Float, dy:Float) {
		tx += dx;
		ty += dy;
	}

	public function scale(sx:Float, sy:Float) {
		a *= sx;
		b *= sy;
		c *= sx;
		d *= sy;
		tx *= sx;
		ty *= sy;
	}

	// (radians) the rotation after this matrix
	public function rotate(r:Float) {
		var cs = Math.cos(r), sn = Math.sin(r);
		var a0 = a, b0 = b, c0 = c, d0 = d, tx0 = tx, ty0 = ty;
		a = a0 * cs - b0 * sn;
		b = a0 * sn + b0 * cs;
		c = c0 * cs - d0 * sn;
		d = c0 * sn + d0 * cs;
		tx = tx0 * cs - ty0 * sn;
		ty = tx0 * sn + ty0 * cs;
	}

	// m applied after this matrix
	public function concat(m:Matrix) {
		var a0 = a, b0 = b, c0 = c, d0 = d, tx0 = tx, ty0 = ty;
		a = a0 * m.a + b0 * m.c;
		b = a0 * m.b + b0 * m.d;
		c = c0 * m.a + d0 * m.c;
		d = c0 * m.b + d0 * m.d;
		tx = tx0 * m.a + ty0 * m.c + m.tx;
		ty = tx0 * m.b + ty0 * m.d + m.ty;
	}

	// the box of a gradient: the gradient square of Flash (-819.2 to 819.2) turned, scaled to width x height (a gradient
	// turned by 90 degrees still fills the box), placed at (tx, ty)
	public function createGradientBox(width:Float, height:Float, rotation:Float = 0, tx:Float = 0, ty:Float = 0) {
		identity();
		rotate(rotation);
		scale(width / 1638.4, height / 1638.4);
		translate(tx + width / 2, ty + height / 2);
	}

	public function toPixi():pixi.core.math.Matrix {
		return new pixi.core.math.Matrix(a, b, c, d, tx, ty);
	}
}
