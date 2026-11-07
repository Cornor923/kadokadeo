package trigo;

import trigo.Game;

// A triangle being made (Group of the original): the blocks clicked (arr: 1, 2, then 3 of the same colour), the blocks in
// the triangle (blocks, of which newBlocks are not grouped yet), its border on the grid (borderPoints).
class Group {
	public var arr:Array<Block>;
	public var sp:Sprite;
	public var bsp:Sprite;

	public var id:Int;
	public var blocks:List<Block>;
	public var newBlocks:List<Block>;

	var good:Bool;
	var borderPoints:Array<Point>;

	public var xMin:Int;
	public var yMin:Int;

	var xMax:Int;
	var yMax:Int;

	// the blocks in the triangle (isInside): x * GRID_SIZE + y
	var mask:Array<Bool>;

	public function new(origin:Block) {
		if (origin.id == null)
			throw "can't create group with id null";
		arr = [origin];
		id = origin.id;

		blink();

		sp = new Sprite();
		Game.me.dm.add(sp, Game.DP_WGROUP);
	}

	function add(b:Block) {
		arr.push(b);

		good = true;

		if (b.id == null) {
			good = false;
			return true;
		}

		if (b.id != id) {
			good = false;
			return true;
		}

		if (b.grouped) {
			good = false;
			return true;
		}

		for (i in 0...arr.length - 1) {
			if (arr[i] == b) {
				good = false;
				return false;
			}
		}

		var grid = Game.me.grid;

		if (arr.length == 3) {
			blocks = new List();
			newBlocks = new List();

			// (the original drew the triangle in a BitmapData of 1 px per block, read by isInside: computeMask)
			computeMask();

			xMin = Game.GRID_SIZE;
			yMin = Game.GRID_SIZE;
			xMax = 0;
			yMax = 0;
			for (b in arr) {
				if (b.x < xMin)
					xMin = b.x;
				if (b.y < yMin)
					yMin = b.y;
				if (b.x > xMax)
					xMax = b.x;
				if (b.y > yMax)
					yMax = b.y;
			}

			if (xMin == xMax || yMin == yMax) {
				good = false;
				return true;
			}

			for (b in arr) {
				if (!isInside(b)) {
					good = false;
					return true;
				}
			}

			var gs = Game.GRID_SIZE;
			var blines = new List<Array<Point>>();
			var lRow = [];
			for (ix in 0...gs)
				lRow[ix] = false;
			for (ix in 0...gs) {
				var l = false;
				for (iy in 0...gs) {
					var b = grid[ix][iy];
					var isIn = isInside(b);
					if (isIn && !l)
						blines.add([b.tl(), b.tr()]);
					if (isIn && !lRow[iy])
						blines.add([b.bl(), b.tl()]);
					if (!isIn && l)
						blines.add([b.tr(), b.tl()]);
					if (!isIn && lRow[iy])
						blines.add([b.tl(), b.bl()]);
					if (isIn && ix == gs - 1)
						blines.add([b.tr(), b.br()]);
					if (isIn && iy == gs - 1)
						blines.add([b.br(), b.bl()]);
					lRow[iy] = isIn;
					l = isIn;
					if (!isIn)
						continue;
					blocks.add(b);
					if (!b.grouped)
						newBlocks.add(b);
				}
			}

			borderPoints = sortPoints(blines);

			if (newBlocks.length == 0) {
				good = false;
				return true;
			}

			if (Game.me.gblocks != null && blocks.length - newBlocks.length != Game.me.gblocks.length) {
				good = false;
				return true;
			}
		}
		return true;
	}

	// The blocks of the triangle. The original drew it (filled, with a 1.1 px outline) into a BitmapData of 15 x 15 pixels,
	// 1 px per block, anti-aliased by the rasterizer of the Flash player, and kept the blocks whose pixel was darker than
	// 160. A rasterizer cannot be replayed exactly (the HTML5 port drew it in a canvas: the pixels change with the browser,
	// the GPU or not, and with the place of the triangle). Here a block is in the triangle when its centre is in the
	// triangle of the centres of the 3 blocks, or at most half a block diagonal (sqrt(2) / 2) from one of its edges:
	// integer arithmetic only (2 c^2 <= l^2, the same in every browser). Measured against the canvas of the HTML5 port, it
	// keeps every block the canvas keeps (and 1.25 more per triangle, the ones on the edge of its threshold), and for every
	// triangle of the grid the blocks it keeps touch by a side, never by a corner only.
	function computeMask() {
		var gs = Game.GRID_SIZE;
		var ax = arr[0].x, ay = arr[0].y;
		var bx = arr[1].x, by = arr[1].y;
		var cx = arr[2].x, cy = arr[2].y;
		var s = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
		mask = [];
		for (x in 0...gs) {
			for (y in 0...gs) {
				var inside = false;
				if (s != 0) {
					var e0 = (bx - ax) * (y - ay) - (by - ay) * (x - ax);
					var e1 = (cx - bx) * (y - by) - (cy - by) * (x - bx);
					var e2 = (ax - cx) * (y - cy) - (ay - cy) * (x - cx);
					inside = s > 0 ? (e0 >= 0 && e1 >= 0 && e2 >= 0) : (e0 <= 0 && e1 <= 0 && e2 <= 0);
				}
				mask[x * gs + y] = inside || nearEdge(ax, ay, bx, by, x, y) || nearEdge(bx, by, cx, cy, x, y)
					|| nearEdge(cx, cy, ax, ay, x, y);
			}
		}
	}

	// (x, y) at most sqrt(2) / 2 from the segment (ax, ay) - (bx, by): squared distance <= 1 / 2
	static function nearEdge(ax:Int, ay:Int, bx:Int, by:Int, x:Int, y:Int):Bool {
		var ex = bx - ax, ey = by - ay;
		var px = x - ax, py = y - ay;
		var l2 = ex * ex + ey * ey;
		var t = px * ex + py * ey;
		if (t <= 0)
			return 2 * (px * px + py * py) <= 1;
		if (t >= l2) {
			var qx = x - bx, qy = y - by;
			return 2 * (qx * qx + qy * qy) <= 1;
		}
		var c = ex * py - ey * px;
		return 2 * c * c <= l2;
	}

	function isInside(p:Block) {
		return mask[p.x * Game.GRID_SIZE + p.y];
	}

	#if debug
	// (test bots) the blocks a triangle of 3 cells would take, without touching the game: x * GRID_SIZE + y
	public static function maskOf(cells:Array<Array<Int>>):Array<Bool> {
		var g:Group = Type.createEmptyInstance(Group);
		g.arr = [for (c in cells) {var b:Block = Type.createEmptyInstance(Block); b.x = c[0]; b.y = c[1]; b;}];
		g.computeMask();
		return g.mask;
	}
	#end

	public function over(b:Block) {
		sp.graphics.clear();

		if (b.grouped)
			return;

		add(b);

		var c = good ? 0xFFFFFF : 0xFF0000;

		if (good && arr.length == 3)
			showBorders();

		sp.graphics.flashLineStyle(4, c, 0.5);

		var s = arr[0].center();
		sp.graphics.moveTo(s.x, s.y);
		for (i in 1...arr.length) {
			var b = arr[i].center();
			sp.graphics.lineTo(b.x, b.y);
		}
		sp.graphics.lineTo(s.x, s.y);
		sp.graphics.endFill();

		arr.pop();
	}

	public function click(b:Block):Null<Bool> {
		if (!add(b)) {
			deselect();
			return false;
		}
		if (!good) {
			arr.pop();
			return false;
		}

		if (arr.length < 3)
			return null;

		bsp = new Sprite();
		Game.me.dm.add(bsp, Game.DP_GROUP);
		showBorders(bsp, 0x434448);

		unblink();

		return true;
	}

	public function showFPlay(r:Float) {
		var n = borderPoints.length;
		var e = Math.ceil(r * n);

		sp.graphics.clear();
		var l = borderPoints[borderPoints.length - 1];
		sp.graphics.flashLineStyle(5, 0xFFF6D2, 0.8);
		sp.graphics.moveTo(l.x, l.y);
		for (i in 0...e) {
			var p = borderPoints[i];

			if (i == e - 1) {
				var sr = (r * n) - i;
				var mp = new Point(l.x + (p.x - l.x) * sr, l.y + (p.y - l.y) * sr);
				sp.graphics.lineTo(mp.x, mp.y);

				var part = Game.me.createPart(mp, 2);
				part.vx += (p.x - l.x) * 1 / Game.BLOCK_SIZE;
				part.vy += (p.y - l.y) * 1 / Game.BLOCK_SIZE;
			} else {
				sp.graphics.lineTo(p.x, p.y);
				l = p;
			}
		}
	}

	public function hide() {
		if (sp.parent != null)
			sp.parent.removeChild(sp);
		if (bsp != null && bsp.parent != null)
			bsp.parent.removeChild(bsp);
		unblink();
	}

	public function unblink() {
		Lambda.iter(Game.me.listBlocks(id), function(b) b.unblink());
	}

	public function blink() {
		Lambda.iter(Game.me.listBlocks(id), function(b) b.blink());
	}

	public function deselect() {
		hide();
		if (Game.me.group == this)
			Game.me.group = null;
	}

	public function calcPts():Int {
		var m = Game.me.combo;
		return Math.round(blocks.length * (blocks.length - 1) / 2 * Game.PTS * m);
	}

	function sortPoints(blines:List<Array<Point>>) {
		var points = [];
		var f = blines.pop();
		var first = f[0];
		var last = f[1];
		points.push(last);
		while (true) {
			// (the fix of the HTML5 port: a turn that does not lengthen the border ends the loop, where the original looped
			// for ever. The border of a set of blocks always closes (every corner has as many lines in as out): kept as a
			// guard, it changes nothing)
			var progress = false;
			for (l in blines) {
				if (l[0].x == last.x && l[0].y == last.y) {
					blines.remove(l);
					last = l[1];
					points.push(last);
					progress = true;
					if (last.x == first.x && last.y == first.y) {
						return points;
					}
				}
			}
			if (!progress)
				break;
		}
		return points;
	}

	public function showBorders(?s:Sprite, col = 0xFFF6D2) {
		if (s == null)
			s = sp;
		s.graphics.flashLineStyle(2, col);
		var l = borderPoints[borderPoints.length - 1];
		s.graphics.moveTo(l.x, l.y);
		for (p in borderPoints)
			s.graphics.lineTo(p.x, p.y);
	}

	public function center() {
		return new Point((xMin + xMax) / 2, (yMin + yMax) / 2);
	}
}
