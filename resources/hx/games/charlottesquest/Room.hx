package charlottesquest;

enum RoomKind {
	Bedroom;
	Horizontal;
	VerticalUp;
	VerticalDown;
	ToUp;
	ToDown;
	FromUp;
	FromDown;
}

enum RoomTheme {
	Castle1;
	Castle2;
	Castle3;
	Bubbles1;
	Bubbles2;
}

class Room {
	public static var ALL:Array<Room> = [];
	static var ATTACHED:Array<Room> = [];
	static var DISTANCE = 0;
	public static inline var PADDING = 32;
	public static inline var GRID = 30;
	public static var CWID = Std.int(Game.WID / GRID);
	public static var CHEI = Std.int(Game.HEI / GRID);
	public static var PERLIN:BitmapData;

	public static function reset() {
		ALL = [];
		ATTACHED = [];
		DISTANCE = 0;
		if (PERLIN != null)
			PERLIN.dispose();
		PERLIN = null;
	}

	var game:Game;
	var marks:Map<String, Bool>; // pour placements des ennemis
	var theme:RoomTheme;

	public var walls:Bitmap;
	public var mcCont:Sprite;
	public var bg:Bitmap;
	public var splashes:Bitmap;

	public var cx:Int;
	public var cy:Int;
	public var collisions:Array<Array<Bool>>;

	var emptySpots:Array<{x:Int, y:Int}>;
	var wallSpots:Array<{x:Int, y:Int}>;

	public var kind:RoomKind;
	public var ready:Bool;

	// (the bitmaps of the herbs and bones: frames of the sheet, see Data.cache / Herbes, Bones)
	var extraCache:RandList<{a:String, f:Int}>;
	var drawCont:Sprite;
	var drawStep:Int;
	var addList:Array<DisplayObject>;

	public var seed:Int;

	var rseed:Rand;

	public var hasPowerUp:Bool;
	public var hasUber:Bool;
	public var distance:Int;

	// (the shop and the alarm clock of the arrival: LvUP)
	public var shop:Null<{cx:Int, cy:Int}> = null;
	public var arrival:Null<{cx:Int, cy:Int}> = null;

	// a bitmap of the room (splashes, background, walls): its pixels smoothed when the screen shows the game bigger (a
	// page zoomed, a high density screen), blocky like Flash's bitmaps otherwise (only the display changes)
	static function picture():BitmapData {
		var b = new BitmapData(CWID * GRID + PADDING * 2, CHEI * GRID + PADDING * 2, true, 0x0);
		b.gpuSmoothing = BitmapData.screenScale() > 1.05;
		return b;
	}

	public function new(x, y, k:RoomKind) {
		distance = DISTANCE++;
		ALL[distance] = this;
		kind = k;
		game = Game.ME;
		emptySpots = new Array();
		wallSpots = new Array();
		ready = false;
		cx = x;
		cy = y;
		seed = game.seed + distance * 999;
		rseed = new Rand(seed);
		marks = new Map();
		hasPowerUp = false;
		hasUber = false;
		extraCache = new RandList();
		drawStep = 0;
		theme = if (game.glevel < 5) Castle1; else if (game.glevel < 10) Castle2; else if (game.glevel < 15) Castle3; else if (game.glevel < 19) Bubbles1; else
			Bubbles2;

		if (PERLIN == null) {
			var pseed = game.seed;
			rseed.initSeed(pseed);
			PERLIN = new BitmapData(400, 400, true, 0x0);
			PERLIN.perlinNoise(rseed.irange(12, 25), rseed.irange(8, 30), rseed.irange(1, 2), pseed, true, true, 1, true);
			PERLIN.threshold(PERLIN, PERLIN.rect, new Point(0, 0), "<", Color.addAlphaF(0x838383), 0x0);
		}

		collisions = new Array();
		for (x in 0...CWID) {
			collisions[x] = new Array();
			for (y in 0...CHEI)
				collisions[x][y] = false;
		}

		bg = new Bitmap();
		bg.x = bg.y = -PADDING;

		splashes = new Bitmap();
		splashes.x = splashes.y = -PADDING;

		mcCont = new Sprite();

		walls = new Bitmap();
		walls.x = walls.y = -PADDING;

		game.setRoom(cx, cy, this);
		generate();
	}

	public inline function getEmptySpotsCopy() {
		return emptySpots.copy();
	}

	public function getWallSpotsCopy() {
		return wallSpots.copy();
	}

	public inline function getPerlin(x:Float, y:Float) {
		var x = Std.int(x);
		var y = Std.int(y);

		while (x < 0)
			x += PERLIN.width;
		while (x >= PERLIN.width)
			x -= PERLIN.width;

		while (y < 0)
			y += PERLIN.height;
		while (y >= PERLIN.height)
			y -= PERLIN.height;

		return PERLIN.getPixel32(x, y);
	}

	public inline function mark(cx:Int, cy:Int) {
		marks.set(cx + "," + cy, true);
	}

	public inline function hasMark(cx:Int, cy:Int) {
		return marks.get(cx + "," + cy) == true;
	}

	public function generate() {
		rseed.initSeed(seed);
		var id = switch (kind) {
			case Bedroom: "bedroom";
			case Horizontal: "horizontal";
			case VerticalUp, VerticalDown: "vertical";
			case ToUp, ToDown: "toUp";
			case FromUp, FromDown: "toUp";
		}

		var min = 0;
		min += Std.int(game.diff * 0.35);
		var realMax = Data.LEVELS.get(id).length - 1;
		var max = Std.int(2 + realMax * game.diff / 17);
		if (min >= 10)
			min = 10;
		if (max > realMax)
			max = realMax;

		var f = if (distance == 0) 0 else rseed.irange(min, max);
		// (game.levels.getBitmapData(id, f): the plan of levels.png, one square per pixel, read from Data.hx)
		var bd = plan(id, f);

		// Miroirs
		switch (kind) {
			case Horizontal:
				if (rseed.random(2) == 0)
					bd = mirror(bd, false, true);
			case VerticalDown, VerticalUp:
				if (rseed.random(2) == 0) {
					var r = rseed.random(4);
					bd = mirror(bd, r & 1 != 0, r & 2 != 0);
				}
			case ToDown:
				bd = mirror(bd, false, true);
			case FromUp:
				bd = mirror(bd, true, false);
			case FromDown:
				bd = mirror(bd, true, true);
			default:
		}

		// Init collisions
		emptySpots = new Array();
		for (x in 0...CWID)
			for (y in 0...CHEI) {
				if (bd[x][y])
					collisions[x][y] = true;
				else {
					emptySpots.push({x: x, y: y});
					collisions[x][y] = false;
				}
			}

		for (pt in emptySpots)
			if (getCol(pt.x - 1, pt.y) || getCol(pt.x + 1, pt.y) || getCol(pt.x, pt.y - 1) || getCol(pt.x, pt.y + 1))
				if (pt.x >= 4 && pt.x < CWID - 4 || pt.y >= 4 && pt.y < CHEI - 4)
					wallSpots.push(pt);
	}

	// the plan f of the group id of levels.png: walls[x][y] (a white pixel)
	static function plan(id:String, f:Int):Array<Array<Bool>> {
		var rows = Data.LEVELS.get(id)[f];
		return [for (x in 0...CWID) [for (y in 0...CHEI) rows[y].charAt(x) == "1"]];
	}

	// (the original drew the plan flipped over itself: opaque pixels, the flipped plan)
	function mirror(bd:Array<Array<Bool>>, flipX:Bool, flipY:Bool):Array<Array<Bool>> {
		return [for (x in 0...CWID) [for (y in 0...CHEI) bd[flipX ? CWID - 1 - x : x][flipY ? CHEI - 1 - y : y]]];
	}

	public function getPoint() {
		return {x: cx * GRID * CWID, y: cy * GRID * CHEI}
	}

	public function toString() {
		return "Room_" + kind + "#" + distance + "@" + cx + "," + cy + "(" + CWID + "x" + CHEI + ")";
	}

	public function globalToLocal(gcx:Int, gcy:Int) {
		return {cx: gcx - this.cx * CWID, cy: gcy - this.cy * CHEI}
	}

	public function localToGlobal(lcx:Int, lcy:Int) {
		return {cx: lcx + this.cx * CWID, cy: lcy + this.cy * CHEI}
	}

	public function getNextDir():{dx:Int, dy:Int} {
		return switch (kind) {
			case Bedroom: {dx: 1, dy: 0};
			case Horizontal: {dx: 1, dy: 0};
			case VerticalUp: {dx: 0, dy: -1};
			case VerticalDown: {dx: 0, dy: 1};
			case ToUp: {dx: 0, dy: -1};
			case ToDown: {dx: 0, dy: 1};
			case FromUp: {dx: 1, dy: 0};
			case FromDown: {dx: 1, dy: 0};
		}
	}

	public function getNext() {
		return ALL[distance + 1];
	}

	public function goneThrough():Bool {
		var x = walls.x + PADDING - game.viewport.x;
		var y = walls.y + PADDING - game.viewport.y;
		var wid = CWID * GRID;
		var hei = CHEI * GRID;
		return switch (kind) {
			case Horizontal, Bedroom: x <= -wid;
			case VerticalUp: y >= hei;
			case VerticalDown: y <= -hei;
			case ToUp: y >= hei;
			case ToDown: y <= -hei;
			case FromUp: x <= -wid;
			case FromDown: x <= -wid;
		}
	}

	public function attach() {
		ATTACHED.push(this);
		game.sdm.add(bg, Game.DP_BG);
		game.sdm.add(splashes, Game.DP_BG);
		game.sdm.add(mcCont, Game.DP_BG);
		game.sdm.add(walls, Game.DP_LEVEL);

		bg.x = splashes.x = walls.x = cx * CWID * GRID - PADDING;
		bg.y = splashes.y = walls.y = cy * CHEI * GRID - PADDING;
		mcCont.x = cx * CWID * GRID;
		mcCont.y = cy * CHEI * GRID;

		if (!ready)
			draw();
	}

	public function detach() {
		ATTACHED.remove(this);
		var a = Game.TW.create(bg, "alpha", 0, 3000);
		a.onUpdate = function() {
			splashes.alpha = mcCont.alpha = walls.alpha = bg.alpha;
		}
		a.onEnd = function() {
			bg.parent.removeChild(bg);
			splashes.parent.removeChild(splashes);
			mcCont.parent.removeChild(mcCont);
			walls.parent.removeChild(walls);
			// (the pictures of the room freed: PIXI keeps their GPU memory otherwise)
			for (b in [bg, splashes, walls])
				if (b.bitmapData != null)
					b.bitmapData.dispose();
			releaseClips(mcCont);
		}
	}

	// the MovieClips of a container: their timelines stop (drawn into a bitmap, or gone)
	static function releaseClips(c:DisplayObjectContainer) {
		for (o in c.children) {
			var m = Std.downcast(o, MovieClip);
			if (m != null)
				m.dispose();
		}
	}

	public inline function last(?endDistance = 0) {
		return distance >= ALL.length - 1 - endDistance;
	}

	inline function isTheme(t:RoomTheme) {
		return Type.enumIndex(theme) == Type.enumIndex(t);
	}

	function draw() {
		var pt0 = new Point(0, 0);

		// (a new one at each step, like the original: the previous one freed)
		var old = splashes.bitmapData;
		splashes.bitmapData = picture();
		if (old != null)
			old.dispose();
		splashes.blendMode = BlendMode.SCREEN;

		rseed.initSeed(seed + drawStep);

		// Fond
		if (drawStep == 3) {
			addList = [];
			var w = 8;
			var h = 6;
			var scaleX = (CWID * GRID / w) / GRID;
			var scaleY = (CHEI * GRID / h) / GRID;
			for (x in 0...w)
				for (y in 0...h) {
					if (getPerlin((x + cx * w) * 4, (y + cy * h) * 4) == 0x0)
						continue;
					var spr:MovieClip = switch (theme) {
						case Castle1, Castle2, Castle3: new MovieClip("Brick");
						case Bubbles1, Bubbles2: new MovieClip("Brick2");
					}
					spr.gotoAndStop(rseed.random(spr.totalFrames) + 1);
					spr.x = scaleX * (x * GRID + GRID * 0.5);
					spr.y = scaleY * (y * GRID + GRID * 0.5);

					if (x > 0 && x < w - 1 && y > 0 && y < h - 1) {
						var s = rseed.range(0.8, 1.4);
						spr.scaleX = scaleX * s;
						spr.scaleY = scaleY * s;
					} else {
						var s = rseed.range(1, 1.2);
						spr.scaleX = scaleX * s;
						spr.scaleY = scaleY * s;
					}
					spr.rotation = rseed.rand() * 3 * (rseed.random(2) * 2 - 1);
					switch (theme) {
						case Castle1, Castle2, Castle3:
							spr.filters = [
								new DropShadowFilter(rseed.range(3, 10), -90, 0x0, 0.6, 0, 0, 1, 1, true),
								new GlowFilter(0x0, 0.4, 16, 16, 2),
							];
						case Bubbles1, Bubbles2:
							spr.scaleX *= 0.8;
							spr.scaleY *= 0.8;
							spr.alpha = rseed.range(0.6, 0.9);
					}
					addList.push(spr);
				}
			drawCont = new Sprite();
			while (addList.length > 0)
				drawCont.addChild(addList.splice(rseed.random(addList.length), 1)[0]);
		}

		// Cache bitmap fond
		if (drawStep == 4) {
			bg.bitmapData = picture();
			var bd = bg.bitmapData;
			var m = new Matrix();
			m.translate(PADDING, PADDING);
			// (stage.quality LOW while drawing: the bricks of the sheet are drawn smoothed)
			bd.draw(drawCont, m);
			releaseClips(drawCont);
			bd.applyFilter(bd, bd.rect, pt0, Color.getContrastFilter(-0.5));
			bd.applyFilter(bd, bd.rect, pt0, Color.getColorizeMatrixFilter(game.bgColor, 0.75, 0.25));
			// (the clouds of the arrival: LvUP)
		}

		// Murs
		if (drawStep == 0) {
			drawCont = new Sprite();
			addList = [];
			for (x in 0...CWID)
				for (y in 0...CHEI) {
					if (!getCol(x, y))
						continue;
					var spr:MovieClip = switch (theme) {
						case Castle1, Castle2: new MovieClip("Brick");
						case Castle3: rseed.random(100) < 85 ? new MovieClip("Brick") : new MovieClip("Brick2");
						case Bubbles1: new MovieClip("Brick2");
						case Bubbles2: new MovieClip("Brick2");
					}
					spr.gotoAndStop(rseed.random(spr.totalFrames) + 1);
					spr.x = x * GRID + GRID * 0.5;
					spr.y = y * GRID + GRID * 0.5;
					spr.rotation = rseed.range(0, 15, true);
					switch (theme) {
						case Castle1:
							spr.scaleX = spr.scaleY = rseed.range(0.9, 1.3);
						case Castle2:
							spr.scaleX = spr.scaleY = rseed.range(0.9, 1.3);
							var r = rseed.range(0.5, 0.7);
							spr.filters = [
								new DropShadowFilter(rseed.range(3, 10), -90, 0x0, 0.4, 0, 0, 1, 1, true),
								Color.getColorizeMatrixFilter(0xA55243, r, 1 - r),
							];
						case Castle3:
							spr.scaleX = spr.scaleY = rseed.range(0.9, 1.3);
							var r = rseed.range(0.7, 0.8);
							spr.filters = [
								new DropShadowFilter(rseed.range(3, 6), 90, 0xffffff, 0.2, 0, 0, 1, 1, true),
								Color.getColorizeMatrixFilter(0x447777, r, 1 - r),
							];
						case Bubbles1:
							spr.scaleX = spr.scaleY = rseed.range(0.7, 1.5);
							spr.transform.colorTransform = Color.getColorizeCT(0x181B30, rseed.range(0, 0.4));
							spr.alpha = rseed.range(0.7, 0.9);
						case Bubbles2:
							spr.scaleX = spr.scaleY = rseed.range(0.7, 1.5);
							spr.transform.colorTransform = Color.getColorizeCT(0x181B30, rseed.range(0, 0.4));
							spr.filters = [Color.getColorizeMatrixFilter(0x6053A6, 0.7, 0.3)];
							spr.alpha = rseed.range(0.7, 0.9);
					}
					addList.push(spr);
				}
		}

		// Extras
		if (drawStep == 1) {
			var herbChance = 1;
			var boneChance = 1;
			switch (theme) {
				case Castle1:
					herbChance = 1;
				case Castle2:
					herbChance = 7;
				case Castle3:
					herbChance = 0;
				case Bubbles1, Bubbles2:
					herbChance = 0;
			}
			// Herbes: lib.DecorHerbes drawn x2 into a bitmap of 100 x 100 per frame (frames of the sheet)
			if (herbChance > 0) {
				for (f in 1...Tex.get("Herbes").length + 1)
					extraCache.add({a: "Herbes", f: f}, herbChance);
			}
			// Ossements
			if (boneChance > 0) {
				for (f in 1...Tex.get("Bones").length + 1)
					extraCache.add({a: "Bones", f: f}, boneChance);
			}

			var chance = switch (theme) {
				case Castle1: 40;
				case Castle2: 80;
				case Castle3: 50;
				case Bubbles1: 20;
				case Bubbles2: 70;
			}
			if (chance > 0)
				for (x in 0...CWID)
					for (y in 0...CHEI) {
						if (!getCol(x, y) || rseed.random(100) >= chance)
							continue;
						if (!getCol(x, y - 1))
							continue;
						for (i in 0...rseed.irange(1, 2)) {
							var e = extraCache.draw(rseed.random);
							var bmp = new Bitmap(e.a, e.f);
							addList.push(bmp);
							var m = new Matrix();
							m.translate(-bmp.width * 0.5, -bmp.height * 0.5);
							m.rotate(rseed.range(0, 6.28));
							var s = 0.5 * rseed.range(0.4, 1.6);
							m.scale(s, s);
							m.translate(x * GRID + GRID * 0.5 + rseed.range(GRID * 0.2, GRID * 0.5, true),
								y * GRID + GRID * 0.5 + rseed.range(GRID * 0.2, GRID * 0.5, true));
							bmp.transform.matrix = m;
						}
					}
		}

		// Cache bitmap murs
		if (drawStep == 2) {
			while (addList.length > 0)
				drawCont.addChild(addList.splice(rseed.random(addList.length), 1)[0]);
			walls.bitmapData = picture();
			var bd = walls.bitmapData;
			var m = new Matrix();
			m.translate(PADDING, PADDING);
			bd.draw(drawCont, m);
			releaseClips(drawCont);

			switch (theme) {
				case Castle1, Castle2:
					bd.applyFilter(bd, bd.rect, pt0, new GlowFilter(0x000000, 0.7, 32, 32, 2, 2));
				case Castle3:
					bd.applyFilter(bd, bd.rect, pt0, new DropShadowFilter(3, 90, 0x535A25, 0.8, 4, 2, 2, 1, true));
					bd.applyFilter(bd, bd.rect, pt0, new DropShadowFilter(1, -90, 0x96A82F, 0.7, 2, 2, 3));
					bd.applyFilter(bd, bd.rect, pt0, new GlowFilter(0x000000, 0.7, 32, 32, 2, 2));
				case Bubbles1, Bubbles2:
					bd.applyFilter(bd, bd.rect, pt0, new GlowFilter(0x0, 0.8, 4, 4, 1, 2));
					bd.applyFilter(bd, bd.rect, pt0, new GlowFilter(0x0, 0.8, 32, 32, 1, 2));
					bd.applyFilter(bd, bd.rect, pt0, new GlowFilter(0x472E5C, 0.8, 16, 16, 1, 2, true));
					bd.applyFilter(bd, bd.rect, pt0, new DropShadowFilter(10, 90, 0x181B30, 0.4, 32, 32, 1));
			}

			bd.applyFilter(bd, bd.rect, pt0, Color.getColorizeMatrixFilter(game.bgColor, 0.2, 0.8));
		}

		if (drawStep == 4) {
			// Chambre (Lib.flatten of lib.Room: its picture of the sheet)
			if (distance == 0)
				addMC(new MovieClip("Room"), 0, 0);

			// (the shop and the alarm clock: LvUP)
		}

		if (drawStep >= 4)
			ready = true;

		if (drawStep == 0)
			game.populateRoom(this);

		drawStep++;
	}

	public function getDuration() { // en secondes
		return switch (kind) {
			case Bedroom, Horizontal, ToUp, ToDown: 12.5;
			case VerticalUp, VerticalDown, FromUp, FromDown: 9.5;
		}
	}

	public function addMC(mc:DisplayObject, x, y) {
		mc.x += x;
		mc.y += y;
		mcCont.addChild(mc);
	}

	public inline function getCol(x:Int, y:Int) {
		if (x < 0 || x >= CWID || y < 0 || y >= CHEI)
			return false;
		else
			return collisions[x][y];
	}

	public static inline function updateAll() {
		for (r in ATTACHED)
			if (r.update())
				break;
	}

	public static inline function getByDist(distance:Int) {
		return ALL[distance];
	}

	public inline function update() {
		if (game.absoluteTime % 10 == 0 && !ready) {
			draw();
			return true;
		} else
			return false;
	}
}
