package brutalteenagecrisis;

import mt.deepnight.Lib;
import mt.deepnight.slb.BSprite;
import mt.deepnight.RandList;

// Two parts differ from the Flash original: readFromFile reads the collision map of the League from Data.LEVEL (the
// pixels of testLevel.png, read when the sheet is built: nothing is read from a picture at run time) instead of the
// embedded bitmap, and render draws PixiJS sprites instead of compositing a BitmapData. The pictures of render (skin,
// flips, decorations) are drawn on the visual random: the gameplay random only places the spots.
typedef MapCell = {
	var collide:Bool;
	var ladder:Bool;
}

class Level {
	var mode:Mode;
	var map:Array<Array<MapCell>>;
	var walls:Sprite;
	var spots:Map<String, Array<{cx:Int, cy:Int}>>;

	public function new() {
		mode = Mode.ME;
		map = new Array();
		spots = new Map();

		for (cx in 0...Const.LWID) {
			map[cx] = new Array();
			for (cy in 0...Const.LHEI)
				map[cx][cy] = {collide: false, ladder: false};
		}
	}

	// colour of a pixel of testLevel.png (only white and red mean something)
	static function getPixel(x:Int, y:Int):Int {
		var row = Data.LEVEL[y];
		var c = row == null ? "." : row.charAt(x);
		return c == "#" ? 0xFFFFFF : c == "H" ? 0xFF0000 : 0;
	}

	public function readFromFile(n:Int) {
		for (x in 0...Const.LWID) {
			map[x] = new Array();
			for (y in 0...Const.LHEI) {
				var pixel = getPixel(x, y + n * Const.LHEI);
				var under = getPixel(x, y + n * Const.LHEI + 1);
				var coll = pixel == 0xFFFFFF;
				map[x][y] = {
					collide: coll,
					ladder: pixel == 0xFF0000 || under == 0xff0000,
				}
				if (!coll && under == 0xFFFFFF) {
					addSpot("ground", x, y);
					addSpot("floor_" + getFloor(y), x, y);
				}
			}
		}
	}

	public static inline function getFloor(cy):Int {
		return 4 - Std.int(Math.min(4, Math.max(0, (cy - 2) / 3)));
	}

	public inline function addSpot(k:String, cx, cy) {
		if (!spots.exists(k))
			spots.set(k, new Array());
		spots.get(k).push({cx: cx, cy: cy});
	}

	public function destroy() {
		detach();
	}

	public function detach() {
		if (walls != null) {
			if (walls.parent != null)
				walls.parent.removeChild(walls);
			walls = null;
		}
	}

	public inline function isValid(cx, cy) {
		return cx >= 0 && cy >= 0 && cx < Const.LWID && cy < Const.LHEI;
	}

	public inline function hasCollision(cx, cy) {
		if (cy < 0 || cy >= Const.LHEI)
			return false;
		else if (cx < 0 || cx >= Const.LWID)
			return true;
		else
			return map[cx][cy].collide;
	}

	public function hasLadder(cx, cy) {
		if (cy < 0)
			return true;
		else if (isValid(cx, cy))
			return map[cx][cy].ladder;
		else
			return false;
	}

	// Background + platforms (side tiles + random flip) + decorations + ladders.
	public function render() {
		detach();
		walls = new Sprite();
		mode.dm.add(walls, Const.DP_BG);

		// z: background < back decorations < shadows < platforms / front decorations < ladders
		var bgLayer = new Sprite();
		var backLayer = new Sprite();
		var shadowLayer = new Sprite();
		var platLayer = new Sprite();
		var ladderLayer = new Sprite();
		walls.addChild(bgLayer);
		walls.addChild(backLayer);
		walls.addChild(shadowLayer);
		walls.addChild(platLayer);
		walls.addChild(ladderLayer);

		// Drop shadow under the exposed bottom edge of each platform (relief)
		var shadow = new Shape();
		shadowLayer.addChild(shadow);
		var shadowG = shadow.graphics;

		// Background (frame 0 in the League)
		if (mode.bgs != null && mode.bgs.exists("bg")) {
			var bg = mode.bgs.get("bg", 0);
			bg.setCenter(0, 0);
			bg.scaleX = bg.scaleY = 2;
			bgLayer.addChild(bg);
		}

		// Skin of the scenery: "Rock" in the League; a skin is drawn for each cell
		var skinSet:Array<Map<String, Int>> = [["Rock" => 10]];
		var skin = skinSet[Seed.randomVfx(skinSet.length)];
		var skinList = new RandList<String>();
		for (k in skin.keys())
			skinList.add(k, skin.get(k));

		var hasBack = mode.tiles.exists("deco_back");
		var hasFront = mode.tiles.exists("deco_front");

		for (cx in 0...Const.LWID)
			for (cy in 0...Const.LHEI) {
				var x = cx * Const.GRID;
				var y = cy * Const.GRID;

				if (hasCollision(cx, cy)) {
					var id = skinList.draw(Seed.randomVfx);
					if (mode.tiles.exists("plateform" + id)) {
						var hasSide = mode.tiles.exists("plateform" + id + "Side");
						var s:BSprite;
						if (hasSide && !hasCollision(cx + 1, cy)) {
							s = mode.tiles.get("plateform" + id + "Side");
							s.x = x;
						} else if (hasSide && !hasCollision(cx - 1, cy)) {
							s = mode.tiles.get("plateform" + id + "Side");
							s.scaleX = -1;
							s.x = x + Const.GRID;
						} else {
							s = mode.tiles.get("plateform" + id);
							s.scaleX = Seed.signVfx();
							s.x = s.scaleX < 0 ? x + Const.GRID : x;
						}
						s.setCenter(0, 0);
						s.y = y;
						platLayer.addChild(s);
					}

					// Drop shadow when the space below is open (2 bands: a fade)
					if (!hasCollision(cx, cy + 1)) {
						shadowG.beginFill(0x120726, 0.38);
						shadowG.drawRect(x, y + Const.GRID, Const.GRID, 7);
						shadowG.endFill();
						shadowG.beginFill(0x120726, 0.18);
						shadowG.drawRect(x, y + Const.GRID + 7, Const.GRID, 7);
						shadowG.endFill();
					}
				}

				var interior = hasCollision(cx, cy) && hasCollision(cx - 1, cy) && hasCollision(cx + 1, cy);

				// Back decoration (25 %)
				if (Seed.randomVfx(100) < 25 && interior && hasBack) {
					var s = mode.tiles.getRandom("deco_back", Seed.randomVfx);
					s.setCenter(0.5, 0);
					s.x = x;
					s.y = y - Const.GRID;
					backLayer.addChild(s);
				}

				// Front decoration (10 %)
				if (Seed.randomVfx(100) < 10 && interior && hasFront) {
					var s = mode.tiles.getRandom("deco_front", Seed.randomVfx);
					s.scaleX = Seed.signVfx();
					s.scaleY = Seed.rangeVfx(0.5, 1);
					s.x = x;
					s.y = y;
					s.setPivotCoord(s.width * 0.5, 34);
					platLayer.addChild(s);
				}
			}

		// Ladders (frame: 1 = top, 2 = bottom, 0 = middle)
		if (mode.tiles.exists("ladder"))
			for (cx in 0...Const.LWID)
				for (cy in 0...Const.LHEI)
					if (hasLadder(cx, cy)) {
						var f = !hasLadder(cx, cy - 1) ? 1 : (!hasLadder(cx, cy + 1) ? 2 : 0);
						var s = mode.tiles.get("ladder", f);
						s.setCenter(0, 0);
						s.x = cx * Const.GRID;
						s.y = cy * Const.GRID;
						ladderLayer.addChild(s);
					}
	}

	public function getGroundSpotsCopy() {
		return spots.get("ground").copy();
	}

	public function getGroundSpotsAround(cx, cy, ?min = 0, ?max = 5) {
		var all = [];
		for (pt in spots.get("ground")) {
			var d = Lib.distanceSqr(cx, cy, pt.cx, pt.cy);
			if (d >= min * min && d <= max * max)
				all.push(pt);
		}
		return all;
	}

	public function getRandomSpotFar(?floor:Int) {
		var pt = null;
		var tries = 200;
		do {
			pt = getRandomSpot(floor);
		} while (tries-- > 0 && Lib.distance(mode.hero.cx, mode.hero.cy, pt.cx, pt.cy) <= 5);
		return pt;
	}

	public function getRandomSpot(?floor:Int) {
		if (floor == null) {
			var all = spots.get("ground");
			return all[Seed.random(all.length)];
		} else {
			var all = spots.get("floor_" + floor);
			// fallback: a floor without any spot gives the ground spots (no all[random(0)] = null)
			if (all == null || all.length == 0)
				all = spots.get("ground");
			return all[Seed.random(all.length)];
		}
	}
}
