package xianxiang;

typedef CellPos = {x:Int, y:Int};

class Level {
	var game:Game;

	public var tbl:Array<Array<Card>>;
	public var combis:Array<Int>;

	// the perfect pairs (all sent for the achievements, nothing reads them in the game): by color, and on neighbouring cells
	public var perfectColors:Array<Int>;
	public var perfectNeighbours:Int;

	public function new(g) {
		this.game = g;
		combis = [0, 0, 0, 0];
		perfectColors = [0, 0, 0, 0];
		perfectNeighbours = 0;
		initLevel();
	}

	public function breakCards(c1:Card, c2:Card) {
		var matchs = c1.id.matchs(c2.id);
		if (c1 == c2)
			return false;

		var m = computePath(c1, c2);
		if (m[c2.x][c2.y] == null)
			return false;

		combis[matchs]++;
		if (matchs == 3) {
			perfectColors[c1.id.color]++;
			if (Math.abs(c1.x - c2.x) + Math.abs(c1.y - c2.y) == 1)
				perfectNeighbours++;
		}

		KadoKadeoManager.kkm.addScore(Const.POINTS_ENCODE[matchs]);
		game.spawn(c1, matchs);
		game.spawn(c2, matchs);
		tbl[c1.x][c1.y] = null;
		tbl[c2.x][c2.y] = null;
		return true;
	}

	public function canBreak() {
		for (x in 0...Const.LVL_WIDTH) {
			for (y in 0...Const.LVL_HEIGHT) {
				var c = tbl[x][y];
				if (c != null) {
					if (Const.NTURNS >= 1)
						return true;

					var px, py;
					px = x;
					while (++px < Const.LVL_WIDTH)
						if (tbl[px][y] != null)
							return true;
					py = y;
					while (++py < Const.LVL_HEIGHT)
						if (tbl[x][py] != null)
							return true;
					px = x;
					while (--px >= 0)
						if (tbl[px][y] != null)
							return true;
					py = y;
					while (--py >= 0)
						if (tbl[x][py] != null)
							return true;
				}
			}
		}
		return false;
	}

	// Topmost active card under the given point (cards of the next row overlap the bottom of the previous one)
	public function getCardAt(px:Float, py:Float):Card {
		var y = Const.LVL_HEIGHT - 1;
		while (y >= 0) {
			var x = Const.LVL_WIDTH - 1;
			while (x >= 0) {
				var c = tbl[x][y];
				if (c != null && c.hitTest(px, py))
					return c;
				x--;
			}
			y--;
		}
		return null;
	}

	function computePath(c1:Card, c2:Card) {
		tbl[c1.x][c1.y] = null;
		tbl[c2.x][c2.y] = null;
		var m:Array<Array<Null<Int>>> = new Array();
		for (i in 0...Const.LVL_WIDTH) {
			m[i] = new Array();
		}
		genColMap(tbl, m, c1.x, c1.y);
		tbl[c1.x][c1.y] = c1;
		tbl[c2.x][c2.y] = c2;
		return m;
	}

	/****** GENERATION *******/
	function fillColMapRec(tmp:Array<Array<Card>>, m:Array<Array<Null<Int>>>, x:Int, y:Int, d:Int, p:Int) {
		var k = m[x][y];
		if ((k != null && k > p) || tmp[x][y] != null)
			return;
		m[x][y] = p;
		if (x > 0) {
			if (d == 0)
				fillColMapRec(tmp, m, x - 1, y, d, p);
			else if (p > 0)
				fillColMapRec(tmp, m, x - 1, y, 0, p - 1);
		}
		if (y > 0) {
			if (d == 1)
				fillColMapRec(tmp, m, x, y - 1, d, p);
			else if (p > 0)
				fillColMapRec(tmp, m, x, y - 1, 1, p - 1);
		}
		if (x < Const.LVL_WIDTH - 1) {
			if (d == 2)
				fillColMapRec(tmp, m, x + 1, y, d, p);
			else if (p > 0)
				fillColMapRec(tmp, m, x + 1, y, 2, p - 1);
		}
		if (y < Const.LVL_HEIGHT - 1) {
			if (d == 3)
				fillColMapRec(tmp, m, x, y + 1, d, p);
			else if (p > 0)
				fillColMapRec(tmp, m, x, y + 1, 3, p - 1);
		}
	}

	function genColMap(tmp, m, x, y) {
		fillColMapRec(tmp, m, x, y, 0, Const.NTURNS);
		fillColMapRec(tmp, m, x, y, 1, Const.NTURNS);
		fillColMapRec(tmp, m, x, y, 2, Const.NTURNS);
		fillColMapRec(tmp, m, x, y, 3, Const.NTURNS);
	}

	function initLevel() {
		var w = Const.LVL_WIDTH;
		var h = Const.LVL_HEIGHT;

		tbl = new Array();
		for (x in 0...w) {
			tbl[x] = new Array();
		}
		for (y in 0...h) {
			for (x in 0...w) {
				tbl[x][y] = new Card(game, CardID.random(), x, y);
			}
		}
	}

	public function pathLength(c1:CellPos, c2:CellPos) {
		var x, y;
		var n = 0;
		if (c1.x < c2.x) {
			x = c1.x;
			while (x < c2.x) {
				if (tbl[x][c1.y] != null)
					n++;
				x++;
			}
		} else {
			x = c1.x;
			while (x > c2.x) {
				if (tbl[x][c1.y] != null)
					n++;
				x--;
			}
		}
		if (c1.y < c2.y) {
			y = c1.y;
			while (y < c2.y) {
				if (tbl[x][y] != null)
					n++;
				y++;
			}
		} else {
			y = c1.y;
			while (y > c2.y) {
				if (tbl[x][y] != null)
					n++;
				y--;
			}
		}
		return n - 1;
	}
}
