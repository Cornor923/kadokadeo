package arkadeo;

// flash.geom.Transform of a display object (o.transform): its matrix (x, y, scale, rotation) and its colour transform. The
// matrix set is split back into x, y, scaleX, scaleY and rotation (no skew: a mirror is a negative scaleX)
class Transform {
	var o:DisplayObject;

	public function new(o:DisplayObject) {
		this.o = o;
	}

	public var matrix(get, set):Matrix;
	public var colorTransform(get, set):ColorTransform;

	function get_matrix():Matrix {
		var xs = [1.0, 0.0, 0.0], ys = [0.0, 1.0, 0.0];
		o.applyMatrix(xs, ys);
		// (the images of (1, 0), (0, 1) and (0, 0))
		return new Matrix(xs[0] - xs[2], ys[0] - ys[2], xs[1] - xs[2], ys[1] - ys[2], xs[2], ys[2]);
	}

	function set_matrix(m:Matrix):Matrix {
		var sx = Math.sqrt(m.a * m.a + m.b * m.b);
		var sy = Math.sqrt(m.c * m.c + m.d * m.d);
		var rot = Math.atan2(m.b, m.a);
		if (m.a * m.d - m.b * m.c < 0) {
			sx = -sx;
			rot = Math.atan2(-m.b, -m.a);
		}
		o.x = m.tx;
		o.y = m.ty;
		o.scaleX = sx;
		o.scaleY = sy;
		o.rotation = rot * 180 / Math.PI;
		return m;
	}

	inline function get_colorTransform():ColorTransform
		return o.colorTransform;

	inline function set_colorTransform(c:ColorTransform):ColorTransform
		return o.colorTransform = c;
}
