package judocommando;

class Ent {
	var flDeath:Bool;
	var sq:Square;

	public var type:EntType;
	public var sens:Int;
	public var missLine:Null<Int>;
	public var px:Int;
	public var py:Int;
	public var ox:Float;
	public var oy:Float;
	public var ray:Float;

	// PHYS
	var flPhys:Bool;

	public var vx:Float;
	public var vy:Float;
	public var frict:Float;
	public var weight:Float;
	public var bounceFrict:Float;
	public var groundFrict:Float;

	var phaseDist:Float;

	public var root:MC;

	public function new(mc:MC) {
		Game.me.ents.push(this);
		root = mc;
		ray = 0.5;
		phaseDist = 0.5;
	}

	public function update() {
		if (flPhys)
			updatePhys();
		if (vy > 60)
			kill();
		updatePos();
	}

	public dynamic function updatePos() {
		root._x = Math.round(Cs.getX(px + ox));
		root._y = Math.round(Cs.getY(py + oy));
	}

	public function phase() {}

	// PHYS ENGINE
	public function initPhys() {
		flPhys = true;
		vx = 0;
		vy = 0;
		frict = 1;
		weight = 0;
		bounceFrict = 0.0;
		groundFrict = 1.0;
		missLine = null;
	}

	function stopPhys() {
		flPhys = false;
	}

	function updatePhys() {
		vy += weight;
		vx *= frict;
		vy *= frict;

		var ec = Std.int(Math.max(Math.abs(vx / Cs.CS) / phaseDist, Math.abs(vy / Cs.CS) / phaseDist));
		var step = 1 + ec;
		var vvx = vx / step;
		var vvy = vy / step;
		var to = 0;

		while (true) {
			ox += vvx / Cs.CS;
			oy += vvy / Cs.CS;

			// COLLISION X
			var sx = Std.int(vvx / Math.abs(vvx));
			var next = Game.me.getSq(px + sx, py);
			if (next.type == BLOCK && Math.abs(ox + ray * sx - 0.5) > 0.5 && confirmCol(sx, 0)) {
				ox = 0.5 + (0.5 - ray) * sx;
				vvx *= -bounceFrict;
				vx *= -bounceFrict;
				vvy *= groundFrict;
				vy *= groundFrict;
				onCollision(sx, 0);
			}

			// MOVE X
			while (ox >= 1)
				swapSquare(0);
			while (ox < 0)
				swapSquare(2);

			// COLLISION Y
			var sy = Std.int(vvy / Math.abs(vvy));
			var next = Game.me.getSq(px, py + sy);
			if ((next.type == BLOCK || (vvy > 0 && next.type == PLAT)) && Math.abs(oy + ray * sy - 0.5) > 0.5 && confirmCol(0, sy)) {
				if (missLine != py + sy || next.type != PLAT) {
					oy = 1 - ray;
					vvy *= -bounceFrict;
					vy *= -bounceFrict;
					vvx *= groundFrict;
					vx *= groundFrict;
					onCollision(0, sy);
				}
			}

			// MOVE Y
			while (oy >= 1)
				swapSquare(1);
			while (oy < 0)
				swapSquare(3);

			phase();
			step--;
			if (step == 0 || !flPhys)
				break;

			// (PHYS ERROR: a loop of more than 50 steps, never reached by the speeds of the game)
			if (to++ > 50)
				break;
		}
	}

	function onCollision(sx:Int, sy:Int) {
		if (sy == 1)
			land();
	}

	public function confirmCol(sx:Int, sy:Int):Bool {
		return true;
	}

	function land() {}

	// MOVE
	public function moveTo(x:Int, y:Int) {
		removeFromGrid();
		px = x;
		py = y;
		ox = 0.5;
		oy = 0.5;
		insertInGrid();
	}

	public function setPos(x:Float, y:Float) {
		removeFromGrid();
		var ppx = (x - Cs.MARGIN) / Cs.CS;
		var ppy = (y - Cs.MARGIN) / Cs.CS;

		px = Std.int(ppx);
		py = Std.int(ppy);
		ox = ppx - px;
		oy = ppy - py;

		insertInGrid();
	}

	function swapSquare(dx:Int, ?dy:Null<Int>) {
		if (dy == null) {
			var d = Cs.DIR[dx];
			dx = d[0];
			dy = d[1];
		}
		removeFromGrid();
		ox -= dx;
		oy -= dy;
		px += dx;
		py += dy;
		insertInGrid();
	}

	public function setSens(?n:Null<Int>) {
		if (n == null) {
			n = Std.int(vx / Math.abs(vx));
			if (vx == 0 || vx == null)
				n = 1;
		}
		sens = n;
		root._xscale = sens * 100;
	}

	public function copyPos(e:Ent) {
		removeFromGrid();
		px = e.px;
		py = e.py;
		ox = e.ox;
		oy = e.oy;
		insertInGrid();
		updatePos();
	}

	public function setOffset(x:Float, y:Float) {
		ox = x;
		oy = y;
	}

	// display: the move of this Flash frame is made at once by the code (the animation it starts is drawn from the new
	// place), not interpolated; the camera following the entity jumps with it
	public function teleport() {
		root.teleport();
		if (Game.me.focus == this)
			Game.me.cutCamera();
	}

	public function insertInGrid() {
		sq = Game.me.getSq(px, py);
		if (sq != null)
			sq.ent.push(this);
	}

	public function removeFromGrid() {
		var s = Game.me.getSq(px, py);
		if (s != null)
			s.ent.remove(this);
		sq = null;
	}

	public function kill() {
		flDeath = true;
		removeFromGrid();
		Game.me.ents.remove(this);
		root.removeMovieClip();
	}

	// EXPLOSION
	public function explode(ray:Int) {
		if (flDeath)
			return;

		// FX
		for (i in 0...ray) {
			var p = new Phys(Game.me.dm.attach("mcExplosion", Game.DP_FX));
			p.x = Cs.getX(px + ox);
			p.y = Cs.getY(py + oy);
			if (i > 0) {
				p.root.stop();
				p.sleep = i * 0.5;
				p.root._visible = false;
				p.x += (Seed.randVfx() * 2 - 1) * i;
				p.y += (Seed.randVfx() * 2 - 1) * i;
				p.root._rotation = 90 * (i % 4);
			}
		}

		blast(ray, 5, Cs.CS * 0.5);
	}

	public function blast(ray:Float, damage:Int, dy = 0.0) {
		// getNears(ray, 2): Haxe skips the optional `type` (2 is not an EntType): every type, 2 squares around
		var a = getNears(ray, null, 2);
		for (e in a) {
			switch (e.type) {
				case MONSTER, HERO:
					if (e == this)
						break;
					var h:Human = cast e;
					var dx = h.root._x - root._x;
					var dy = h.root._y - (root._y + dy);
					var a = Math.atan2(dy, dx);
					var speed = 4;
					var vx = Cs.q(Math.cos(a) * speed);
					var vy = Cs.q(Math.sin(a) * speed);
					if (!(Math.isNaN(vx) || Math.isNaN(vy)))
						h.knockOut(vx, vy, damage);
				case null:
				default:
			}
		}
	}

	// GET
	public function getNears(distMax:Float, ?type:EntType, ?ray:Int = 1):Array<Mon> {
		var a = [];
		var x = Cs.getX(px + ox);
		var y = Cs.getY(py + oy);

		var max = 1 + ray * 2;
		for (ndx in 0...max) {
			for (ndy in 0...max) {
				var npx = px + ndx - ray;
				var npy = py + ndy - ray;
				var sq = Game.me.getSq(npx, npy);
				for (ent in sq.ent) {
					if (ent != this) {
						if (type == null || ent.type == type) {
							var dx = Cs.getX(ent.px + ent.ox) - x;
							var dy = Cs.getY(ent.py + ent.oy) - y;
							var dist = Math.sqrt(dx * dx + dy * dy);
							a.push({ent: ent, dist: dist});
						}
					}
				}
			}
		}

		var list:Array<Mon> = [];
		for (o in a) {
			if (o.dist < distMax) {
				// (a cast: flSafe of an entity that is not a monster is undefined, !undefined is true)
				var mon:Mon = cast o.ent;
				if (!mon.flSafe)
					list.push(mon);
			}
		}
		return list;
	}

	public function getSens(ent:Ent):Int {
		var dx = (ent.px + ent.ox) - (px + ox);
		var sx = Std.int(dx / Math.abs(dx));
		if (dx == 0)
			sx = 1;
		return sx;
	}

	public function getDist(ent:Ent):Float {
		var dx = Cs.getX((ent.px + ent.ox) - (px + ox));
		var dy = Cs.getY((ent.py + ent.oy) - (py + oy));
		return Math.sqrt(dx * dx + dy * dy);
	}

	public function getSDist(ent:Ent, rx = 0.0):Float {
		var dx = (ent.px + ent.ox) - (px + ox);
		var dy = (ent.py + ent.oy) - (py + oy);
		dx = Math.abs(dx) - rx;
		return Math.max(Math.abs(dx), Math.abs(dy));
	}

	public function getPDist(x:Float, y:Float, rx = 0.0):Float {
		var dx = x - Cs.getX(px + ox);
		var dy = y - Cs.getY(py + oy);
		dx = Math.abs(dx) - rx;
		return Math.sqrt(dx * dx + dy * dy);
	}

	function getSquares(ray:Int):Array<Square> {
		var a = [];
		var max = 1 + ray * 2;
		for (ndx in 0...max) {
			for (ndy in 0...max) {
				var npx = px + ndx - ray;
				var npy = py + ndy - ray;
				var sq = Game.me.getSq(npx, npy);
				a.push(sq);
			}
		}
		return a;
	}

	public function getPos():{x:Float, y:Float} {
		var x = root._x;
		var y = root._y;
		// root.smc.center: the marker of the current animation (the hero climbing)
		var smc = root.sub("smc");
		var dc = smc != null ? smc.marker("center") : null;
		if (dc != null) {
			x += dc[0] * sens;
			y += dc[1];
		}
		return {x: x, y: y};
	}
}
