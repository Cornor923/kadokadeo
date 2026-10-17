package mel;

import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.Texture;
import pixi.core.textures.RenderTexture;
import pixi.core.display.Container;
import mel.Lib;
import mel.Gfx;
import mel.Char;
import mel.Nmy;
import mel.VScroller;

// a wall of the level (a platform): it fills its cells of the collision map
class LevelSprite extends Spr {
	public var coll:Bool;

	public var cw:Int;
	public var ch:Int;
	public var px:Int;
	public var py:Int;

	public var pageKey:Int;
	public var cooKey:Int;

	public var game(get, null):Game;

	function get_game()
		return Game.me;

	public function new(px:Int, py:Int, cw:Int, ch:Int, key:Int) {
		super();
		coll = true;
		this.cw = cw;
		this.ch = ch;
		this.px = px;
		this.py = py;
		x = Std.int(Lib.cw * px);
		y = Std.int(Lib.ch * py);
		cooKey = game.level.makeKey(px, py);
		pageKey = key;
		addToCol();
	}

	function addToCol() {
		var lev = lev();
		for (kcx in 0...cw)
			for (kcy in 0...ch)
				lev.setWall(px + kcx, py + kcy, this);
	}

	public function finalize() {
		detach();
	}

	public function remFromCol() {
		var lev = lev();
		for (kcx in 0...cw)
			for (kcy in 0...ch) {
				var p = lev.getWall(px + kcx, py + kcy);
				if (p == this)
					lev.setWall(px + kcx, py + kcy, null);
			}
	}

	inline function lev()
		return game.level;

	function setPos(npx:Int, npy:Int) {
		remFromCol();
		this.px = npx;
		this.py = npy;
		x = Std.int(Lib.cw * npx);
		y = Std.int(Lib.ch * npy);
		addToCol();
	}
}

/**
 * A platform: the pieces of one of the 5 platforms of gfx.Tiles side by side (bitmap fills of 16 px wide rectangles:
 * a corner at each end, the right one mirrored, body pieces between them, mirrored at random), sometimes a prop,
 * outlined by a black glow (cacheAsBitmap). The pieces and their glow are drawn once into a picture; the children
 * (prop, height sign) are drawn over it, like Flash draws a Sprite's graphics under its children (their own outline is
 * not drawn).
 */
class Crossing extends LevelSprite {
	static inline var PAD = 4;

	var strip:PixiSprite;
	var rt:RenderTexture;

	public function new(px:Int, py:Int, cw:Int, ch:Int, key:Int, prop = true) {
		super(px, py, cw, ch, key);
		if (ch > 1)
			throw "assert";
		var l = lev();
		var s = new MRand((px * py + Game.getSeed()) ^ (54354 * ch + 1337 * cw));
		var p = Pick.array(l.data.platforms, s);
		var c = Pick.array(p.corner, s);
		var pieces:Array<{p:Piece, x:Float, flip:Bool}> = [];
		var curX = 0.;
		for (x in 0...cw) {
			var t:Piece = null;
			if (cw == 1) {
				t = Pick.array(p.mid, s);
			} else {
				if (x == 0)
					t = c;
				else if (x == cw - 1)
					t = c;
				else
					t = Pick.array(p.mid, s);
			}
			var v = 16;
			var flip = (x == cw - 1) || (x != 0 && s.random(2) == 0);
			pieces.push({p: t, x: curX, flip: flip});
			curX += v;
		}
		bake(pieces);

		if (s.random(10) == 0 && prop) {
			var pr = Pick.array(l.data.props, s);
			var b = new Bmp(pr.a);
			addChild(b);
			b.y -= b.bmpHeight;
			b.x = s.random(Std.int(cw * Lib.cw - b.bmpWidth));
			b.scaleX = (s.random(10) < 5) ? 1 : -1;
		}
	}

	function bake(pieces:Array<{p:Piece, x:Float, flip:Bool}>) {
		var h = 0;
		for (pc in pieces)
			h = Std.int(Math.max(h, pc.p.h));
		var w = cw * 16;
		var holder = new Container();
		var inner = new Container();
		holder.addChild(inner);
		for (pc in pieces) {
			var sp = new PixiSprite(Tex.one(pc.p.a));
			sp.anchor.set(0, 0);
			sp.y = PAD;
			if (pc.flip) {
				sp.scale.x = -1;
				sp.x = PAD + pc.x + 16;
			} else
				sp.x = PAD + pc.x;
			inner.addChild(sp);
		}
		inner.filters = [new FlashGlow(1.5, 1.5, 2, 0x000000, 1)];
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		rt = (cast RenderTexture : Dynamic).create({width: w + 2 * PAD, height: h + 2 * PAD, resolution: renderer.resolution});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		strip = new PixiSprite(rt);
		strip.x = -PAD;
		strip.y = -PAD;
		node.addChildAt(strip, 0);
		base = 1;
	}

	override public function finalize() {
		super.finalize();
		if (strip != null) {
			strip.destroy();
			rt.destroy(true);
			strip = null;
		}
	}
}

typedef PoweredClip = {
	pow:CharPowers,
}

class PageItems {
	public var dl:List<Entity>;

	public var bonus:List<Bonus>;
	public var kdo:List<Dynamic>;

	public function new() {
		bonus = new List();
		dl = new List();
		kdo = new List();
	}

	public function mk() {
		for (d in bonus)
			dl.push(d);
	}
}

// the bitmap of a column of wall tiles of a page (VScroller.KeyedBitmap with the bitmapData of a wallLine)
class WallCol extends Spr {
	public var key:Null<Int>;

	var tiles:Array<PixiSprite> = [];

	public function new() {
		super();
		for (i in 0...Lib.nbch() + 1) {
			var s = new PixiSprite(Texture.EMPTY);
			s.y = i * 16;
			node.addChild(s);
			tiles.push(s);
		}
	}

	public function setColumn(data:Data, col:Int) {
		var t = data.wallTexture(col);
		for (i in 0...tiles.length)
			tiles[i].texture = t[i];
	}
}

class Level {
	public var sideDrops:Map<Int, Array<Bmp>>;

	public var bg:Array<{first:Bmp, second:Bmp}>;

	var char:Char;

	public var dm:DM;

	var root:Spr;

	public inline function getRoot()
		return root;

	var pages:Map<Int, Bool>;

	public var pagesData:Map<Int, PageItems>;

	public static inline var SIDE_DEPTH = 0;
	public static inline var PRE_SWARM_DEPTH = 10;
	public static inline var DANGER_DEPTH = 20;
	public static inline var PLATFORM_DEPTH = 30;
	public static inline var CHAR_DEPTH = 40;
	public static inline var FX_DEPTH = 50;

	public static var DEPTHS = [SIDE_DEPTH, PRE_SWARM_DEPTH, DANGER_DEPTH, PLATFORM_DEPTH, CHAR_DEPTH, FX_DEPTH];

	var mate:{p4:Bmp, p2mood:Bmp};

	var previousPage:Null<Int> = null;

	public var data:Data;
	public var p3:P3Scroller;
	public var p2:P2Scroller;
	public var p2b:P2BScroller;
	public var bmpPool:Pool<WallCol>;
	public var heightMeterPool:Pool<HeightSign>;

	var walls:Map<Int, LevelSprite>;

	public var deadLine:Shp;

	var dLevel:Float;

	public var life:Int;

	public var nmy:Map<Int, List<Nmy>>;
	public var others:List<Entity>;

	public var bonus:Array<CharPowers>;

	public var tasks:List<Void->Bool>; // true means remove me

	public static var SKIP_VIEW_SYNC = false;
	public static var ENABLE_FLIP = true;
	public static var NO_DEADLINE = false;
	public static var NO_KILL = false;

	public var floor:Crossing;

	public inline function makeFloor() {
		floor = new Crossing(0, Lib.nbch(), Lib.nbcw() + 1, 1, 0);
		dm.add(floor, PLATFORM_DEPTH);
	}

	public inline function getPage()
		return Std.int(game.view.y / Lib.ph());

	public inline function getCharPage()
		return Std.int(game.char.mc.y / Lib.ph());

	public inline function getD()
		return dLevel;

	static var m_shift = 6;
	static var m_mask = (1 << m_shift) - 1;

	public var deadlinePack:Array<Nmy>;
	public var gameOverCalled = false;

	public function new() {
		dLevel = 0;
		root = new Spr();
		Fl.levelRoot = root;
		dm = new DM(root);
		for (i in DEPTHS)
			dm.getPlan(i);
		pages = new Map();
		bg = [];
		walls = new Map();
		sideDrops = new Map();
		data = new Data();
		bmpPool = new Pool(() -> new WallCol()).reserve(4);
		nmy = new Map();
		tasks = new List();
		makeMate();
		deadlinePack = [];
		life = 0;
		others = new List();
		pagesData = new Map();
		makeBonuses();
	}

	public var game(get, null):Game;

	function get_game()
		return Game.me;

	// the lists of enemies in the order of their kind (mt.gx.EnumHash)
	public function nmyLists():Array<List<Nmy>> {
		var out = [];
		for (i in 0...6)
			if (nmy.exists(i))
				out.push(nmy.get(i));
		return out;
	}

	public inline function nmyExists(t:NMY_TYPE)
		return nmy.exists(t.getIndex());

	public inline function nmyGet(t:NMY_TYPE)
		return nmy.get(t.getIndex());

	public function init() {
		var rd = new MRand(125435 - Game.getSeed());

		// (AKApi.getInGamePrizeTokens: the prizes of Arkadeo, none on KadoKadeo)

		for (i in 0...2)
			bg[i] = {first: null, second: null};

		heightMeterPool = new Pool(() -> new HeightSign());
		heightMeterPool.reserve(4);

		addMate();

		Game.me.char = char = new Char();
		dm.add(char.mc, CHAR_DEPTH);
		data.addLdLines(new MRand(Game.getSeed()));

		addPage(0);

		function spawnStartBonus() {
			var r = getUnknownBasic(rd);
			var p0 = pagesData.get(0);
			var brk = true;

			while (true) {
				brk = true;
				for (u in p0.bonus)
					if (u.isPow) {
						var pu = (cast u : UpBonus).pow;
						if (pu == r) {
							r = getBasic(rd);
							brk = false;
						}
					}
				if (brk)
					break;
			}

			var v = new UpBonus(0, r);
			v.cx = 4 + rd.random(Lib.nbcw() - 4) - 2;

			while (Std.int(Math.abs(char.cx - v.cx)) <= 4)
				v.cx = 4 + rd.random(Lib.nbcw() - 4) - 2;

			v.cy = game.char.cy;
			v.restager = Fixed;

			v.page = 0;
			var pd = p0;
			pd.dl.push(v);
			pd.bonus.push(v);
			v.restage();
		}

		spawnStartBonus();
	}

	public function makeMate() {
		var rd = new MRand(Game.getSeed() ^ 13371337);
		// gfx.Plan1: the drops on the sides (4 copies of each frame)
		var p1:Array<Dynamic> = Art.meta().planes.plan1;
		for (i in 1...p1.length + 1) {
			var c = new Bmp("plan1" + i);
			var a = [c, Bmp.copy(c), Bmp.copy(c), Bmp.copy(c)];
			sideDrops.set(i, a);
			for (p in a) {
				dm.add(p, SIDE_DEPTH);
				p.x = -2000;
				p.y = -2000;
			}
			a[0].x = 8;
			a[2].x = 8;
			a[1].x = Lib.w() - 4;
			a[1].scaleX = -1;
			a[3].x = Lib.w() - 4;
			a[3].scaleX = -1;
		}

		var p4 = makePlan4(rd);

		var r3 = 1 + rd.random(3);
		var r2 = 1 + rd.random(4);
		var r2b = 1 + rd.random(4);
		var rm = 1 + rd.random(1);
		mate = {p4: p4, p2mood: new Bmp("moodp2" + rm)};

		p3 = new P3Scroller();
		p2 = new P2Scroller();
		p2b = new P2BScroller();

		deadLine = new Shp();
		var g = deadLine.graphics;
		g.lineStyle(0.03, 0xFF0000);
		g.moveTo(0, 0);
		g.lineTo(Lib.w(), 0);
		deadLine.alpha = 0;
	}

	// mate.p4: gfx.BG flattened, 4 rows of gfx.Plan4 details drawn into it with random matrices (the first row upside
	// down at the top, the others from the bottom), gfx.MoodPlan4 drawn over; one picture
	function makePlan4(rd:MRand):Bmp {
		var dims:Array<Array<Float>> = Art.meta().planes.plan4dims;
		var bgDef = Art.meta().planes.bg[0];
		var holder = new Container();
		var bgs = new PixiSprite(Tex.one("bg1"));
		bgs.anchor.set(0, 0);
		holder.addChild(bgs);
		var cur4 = 1;
		var nf = dims.length;
		var shuff = [for (i in 1...nf + 1) i];
		for (i in 0...4) {
			var cur = 0.0;
			while (cur < Lib.w()) {
				var upDown = i == 0;
				var s = 0.4 + rd.rand() * 0.5 * (upDown ? 0.8 : 1.0);
				var sx = 1.0, sy = 1.0;
				if (rd.random(2) == 0)
					sx = -1;
				if (upDown)
					sy = -1;
				sx *= s;
				sy *= s;
				var ew = dims[cur4 - 1][0] * s;
				var tx = cur + Dice.rollF(rd, -ew * 0.2, 0);
				var ty = upDown ? -dims[cur4 - 1][1] * 0.2 : Lib.h();
				var idx = rd.random(shuff.length - 1);
				cur4 = 1 + shuff[idx];
				var d = new PixiSprite(Tex.one("plan4" + cur4));
				var pl:Array<Dynamic> = Art.meta().planes.plan4;
				var pd = pl[cur4 - 1];
				// (pictures of the frames: pixel (0, 0) at their bounds)
				d.anchor.set(0, 0);
				d.scale.set(sx, sy);
				d.x = tx + pd.x * sx;
				d.y = ty + pd.y * sy;
				holder.addChild(d);
				cur += ew;
			}
		}
		var mood = new PixiSprite(Tex.one("moodp41"));
		holder.addChild(mood);
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var rt:RenderTexture = (cast RenderTexture : Dynamic).create({width: bgDef.w, height: bgDef.h, resolution: 1});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		var b = new Bmp();
		b.setTexture(rt, bgDef.w, bgDef.h);
		plan4Tex = rt;
		return b;
	}

	public var plan4Tex:RenderTexture;

	public var p3index:Int = 0;

	public function addMate() {
		var i = 0;
		var g:DO = mate.p4;
		Game.me.addChild(g);
		g.parent.setChildIndex(g, i++);

		p3index = i++;

		g = mate.p2mood;
		Game.me.addChild(g);
		g.parent.setChildIndex(g, i++);

		if (Game.me.hasDeadLine()) {
			calcDeadLine();
			dm.add(deadLine, FX_DEPTH);
			var r = new MRand(I32.of(Game.getLevel() * Game.getSeed()));
			var n = 50;
			for (i in 0...n) {
				var nm = addNmy(NT_SWARM, r.random(Lib.nbcw()), 0);
				deadlinePack.push(nm);
			}
		}

		new FxInit();
	}

	public inline function makeKey(cx:Int, cy:Int):Int {
		return (cx & m_mask) | (cy << m_shift);
	}

	public inline function setWall(cx:Int, cy:Int, obj:LevelSprite) {
		if (obj == null)
			walls.set(makeKey(cx, cy), null);
		else
			walls.set(makeKey(cx, cy), obj);
	}

	public inline function testColl(cx:Int, cy:Int):Bool {
		if (cx <= 0 || cx >= Lib.nbcw())
			return true;
		else {
			var w = getWall(cx, cy);
			return w != null && w.coll;
		}
	}

	public inline function testBorder(cx:Int, cy:Int):Bool
		return (cx <= 0 || cx >= Lib.nbcw());

	public function getWalls()
		return walls;

	public inline function getWall(cx:Int, cy:Int):LevelSprite {
		if (cx < 0 || cx >= Lib.nbcw())
			return null;
		else
			return walls.get(makeKey(cx, cy));
	}

	public function getRandomPlace(wallCache:Array<LevelSprite>, seed:Int):{pl:LevelSprite, px:Int, py:Int} {
		var rd = new MRand(seed);
		for (i in 0...5) {
			var pl = wallCache[rd.random(wallCache.length)];
			if (pl == null)
				continue;
			var px = rd.random(pl.cw - 1) + 1;
			var py = -1;

			var doIt = true;
			doIt = testColl(pl.px, pl.py + -1) == false;
			doIt = doIt && testColl(pl.px - 1, pl.py + 1) == false;
			doIt = doIt && testColl(pl.px - 1, pl.py + 1) == false;

			if (!doIt)
				continue;

			var fx = px + pl.px;
			var fy = py + pl.py;

			function testNm(enm:Nmy) {
				var smX = (enm.cx == fx) || (enm.cx == fx + 1) || (enm.cx == fx - 1) || (enm.cx == fx - 2) || (enm.cx == fx + 2);
				var smY = (enm.cy == fy + 1) || (enm.cy == fy) || (enm.cy == fy - 1) || (enm.cy == fy + 2) || (enm.cy == fy - 2);
				return smY && smX;
			};

			if (nmyExists(NT_BLADE))
				doIt = doIt && !Lambda.exists(nmyGet(NT_BLADE), testNm);
			if (nmyExists(NT_TORCH))
				doIt = doIt && !Lambda.exists(nmyGet(NT_TORCH), testNm);

			if (!doIt)
				continue;

			return {pl: pl, px: px, py: py};
		}
		return null;
	}

	public static inline function compKeys(pl0:LevelSprite, pl1:LevelSprite)
		return pl0.cooKey - pl1.cooKey;

	// the walls of a page, one entry per cell they fill (a platform of 5 cells is 5 times in the list), by origin
	public function getWallCache(p:Int):Array<LevelSprite> {
		var wallCache = [];
		for (k in wallKeys)
			if (walls.exists(k)) {
				var w = walls.get(k);
				if (w != null && w.pageKey == p)
					wallCache.push(w);
			}
		wallCache.sort(compKeys);
		return wallCache;
	}

	// keys of the collision map in the order they were first set (iteration order of the IntHash)
	var wallKeys(get, never):Array<Int>;

	function get_wallKeys() {
		return [for (k in walls.keys()) k];
	}

	public function addPage(n:Int) {
		if (n < 0)
			return;
		if (pages.exists(n) && pages.get(n))
			return;

		if (n == 0)
			makeFloor();
		var rd = new MRand(I32.of(Game.getSeed() * 351433848.0 + n * 138864868.0));
		var b = bmpPool.create();

		var ph = Lib.ph();
		b.setColumn(data, rd.random(data.wallLine.length));
		b.x = 0;
		b.y = -n * ph;
		b.scaleX = 1;
		b.key = n;
		dm.add(b, SIDE_DEPTH);

		b = bmpPool.create();
		b.setColumn(data, rd.random(data.wallLine.length));
		b.x = Lib.w() + 4;
		b.scaleX = -1;
		b.y = -n * ph;
		b.key = n;
		dm.add(b, SIDE_DEPTH);

		var d = pageDiff(n);

		data.iterPage(n, function(rx, ry, col) procPlatforms(rd, rx, ry + n * Lib.nbch(), col, d, n));
		data.iterPage(n, function(rx, ry, col) procOthers(rd, rx, ry + n * Lib.nbch(), col, d, n));

		pages.set(n, true);
		root.setChildIndex(char.mc, root.numChildren - 1);

		var kc:Int = n;
		var kdrb = new MRand(I32.of(kc * 354486.0 - Game.getSeed() * 3441.0));

		var wallCache = getWallCache(n);

		if (pagesData.exists(n)) {
			var pd = pagesData.get(n);
			for (i in pd.dl)
				if (i.mc != null)
					i.restage();
		} else {
			var pd = new PageItems();
			data.iterPage(n, function(rx, ry, col) procBonus(rd, rx, ry + n * Lib.nbch(), col, d, n, pd));
			var has = Dice.percent(kdrb, 45);
			if (has && Game.conf.spawnBonuses) {
				var wall = getRandomPlace(wallCache, kdrb.random(13371337));
				if (wall != null) {
					var rdi = Pick.normRand(bonuses, kdrb);
					if (rdi != null) {
						var e = bonuses[rdi];
						var epow = e.pow;
						if (!isBasic(epow) && !hasBasic())
							epow = getBasic(kdrb);

						if (!char.powers.has(epow)) {
							var fx = Std.int(wall.px + wall.pl.px);
							var fy = Std.int(wall.py + wall.pl.py);

							if (!Lambda.exists(pd.bonus, function(b) return fx == b.cx && fy == b.cy)) {
								var b = new UpBonus(n, epow);
								b.cx = fx;
								b.cy = fy;
								b.restager = Fixed;
								pd.bonus.push(b);
								pd.dl.push(b);
								b.restage();
							}
						}
					}
				}
			}

			if (Dice.percent(kdrb, 30)) {
				var wall = getRandomPlace(wallCache, kdrb.random(13371337));
				if (wall != null) {
					var fx = Std.int(wall.px + wall.pl.px);
					var fy = Std.int(wall.py + wall.pl.py);

					if (!Lambda.exists(pd.bonus, function(b) return b.cx == fx && b.cy == fy)) {
						var b = new Bonus(n);
						b.cx = fx;
						b.cy = fy;
						b.restager = Fixed;
						b.restage();
						pd.bonus.push(b);
						pd.dl.push(b);
					}
				}
			}

			// (the prizes of Arkadeo, kdos: none)

			pd.mk();
			pagesData.set(n, pd);
			for (l in nmyLists())
				for (nm in l)
					nm.restage();
		}
	}

	// league: the difficulty of a page (1, 2 or 3), harder and harder with the pages
	public function leagueDiff(n:Int):Float {
		var p = [{d: 1.0, w: 100}, {d: 2.0, w: 0}, {d: 3.0, w: 0}];
		var b = 4;
		for (i in 0...n) {
			if (p[0].w > 0) {
				p[0].w -= b;
				p[1].w += b;
			} else if (p[1].w > 0) {
				p[1].w -= b;
				p[2].w += b;
			}
		}
		var r = new MRand(n * 137 + Game.getSeed()).random(100);
		for (v in p) {
			if (r < v.w)
				return v.d;
			else
				r -= v.w;
		}
		return 1.0;
	}

	public function pageDiff(n:Int):Float {
		return leagueDiff(n);
	}

	// the colour code of a pixel for a difficulty: blue (easy), green (medium), red (hard)
	public function extract(col:Int, d:Float):Int {
		col = col & 0xFFFFFF;
		var colR = (col >> 16) & 0xFF;
		var colG = (col >> 8) & 0xFF;
		var colB = (col >> 0) & 0xFF;
		if (d >= 2.01)
			return colR;
		if (d <= 1.01)
			return colB;
		else
			return colG;
	}

	public static var cry = -1;
	public static var cfx = -1;

	function mkLine(x:Int, y:Int, l:Int, n:Int) {
		var ry = -y + Lib.nbch();
		var cp = new Crossing(x, ry, l, 1, n, false);
		dm.add(cp, PLATFORM_DEPTH);
	}

	public var bonuses:Array<{weight:Int, pow:CharPowers}>;

	function makeBonuses():Void {
		bonuses = [];
		bonuses.push({weight: 30, pow: CP_DOUBLE_JUMP});
		bonuses.push({weight: 40, pow: CP_WALL_STICK});
		bonuses.push({weight: 40, pow: CP_SUPER_JUMP});
		bonuses.push({weight: 20, pow: CP_KICK});
		bonuses.push({weight: 10, pow: CP_CANCEL});
	}

	function isBasic(p:CharPowers) {
		return p == CP_DOUBLE_JUMP || p == CP_WALL_STICK || p == CP_SUPER_JUMP;
	}

	function hasBasic() {
		var p = game.char.powers;
		return p.has(CP_DOUBLE_JUMP) || p.has(CP_WALL_STICK) || p.has(CP_SUPER_JUMP);
	}

	function getBasic(rd:MRand) {
		if (Dice.percent(rd, 50))
			return CP_SUPER_JUMP;
		if (Dice.percent(rd, 50))
			return CP_WALL_STICK;
		return CP_DOUBLE_JUMP;
	}

	function getUnknownBasic(rd:MRand) {
		if (!char.powers.has(CP_SUPER_JUMP) && Dice.percent(rd, 50))
			return CP_SUPER_JUMP;
		if (!char.powers.has(CP_WALL_STICK) && Dice.percent(rd, 50))
			return CP_WALL_STICK;
		if (!char.powers.has(CP_DOUBLE_JUMP))
			return CP_DOUBLE_JUMP;
		else
			return CP_KICK;
	}

	public function procPlatforms(rd:MRand, rx:Int, ry:Int, col:Int, d:Float, n:Int) {
		function stop() {
			if (cfx >= 0)
				mkLine(cfx, cry, rx - cfx, n);
			cfx = -1;
			cry = ry;
		}

		var colCode = extract(col, d);
		if (colCode == Lib.WALL_ID) {
			if (cry != ry)
				stop();
			if (cfx < 0)
				cfx = rx;
		} else
			stop(); // not known
	}

	public function getNmyXY(t:NMY_TYPE, cx:Int, cy:Int, me:Nmy):Nmy {
		if (!nmyExists(t))
			return null;
		else {
			var r = null;
			for (n in nmyGet(t))
				if (n.cx == cx && n.cy == cy && n != me) {
					r = n;
					break;
				}
			return r;
		}
	}

	public function addNmy(?np:Int, t:NMY_TYPE, x:Int, y:Int, d = 1.0):Nmy {
		var nmy_ent:Nmy = new Nmy(np).init(t, x, y, d);
		if (!nmyExists(t))
			nmy.set(t.getIndex(), new List<Nmy>());
		nmyGet(t).add(nmy_ent);
		nmy_ent.restage();
		return nmy_ent;
	}

	public function procBonus(rd:MRand, rx:Int, ry:Int, col:Int, d:Float, n:Int, pd:PageItems) {
		var cy = -ry + Lib.nbch();
		if (col > 0xfa0000)
			switch (col) {
				case 0xFF6400, 0xFF7800, 0xFF8C00, 0xFFA000, 0xFFB400:
					var i = Std.int(((col & 0x00FFFF) >> 8) % 100 / 20);
					var bn = CharPowers.createByIndex(i);
					if (!char.powers.has(bn)) {
						if (!Lambda.exists(pd.bonus, function(p) return p.cx == rx && p.cy != cy)) {
							var v = new UpBonus(n, bn);
							v.cx = rx;
							v.cy = cy;
							v.restager = Fixed;
							v.restage();
							pd.bonus.push(v);
						}
					}
				case _:
			}
	}

	public function procOthers(rd:MRand, rx:Int, ry:Int, col:Int, d:Float, n:Int) {
		var cy = -ry + Lib.nbch();
		var lev = game.level;

		function testPix(x:Int, y:Int)
			return extract(lev.data.getPixel(n, x, y), d) == Lib.WALL_ID;
		function genNmy(t:NMY_TYPE)
			return addNmy(n, t, rx, cy, d);
		function mkBlade() {
			var t = genNmy(NT_BLADE);
			t.rx = 0;
			if (lev.testColl(rx - 1, cy)) {
				t.mc.rotation = 90;
				t.cy--;
			} else if (lev.testColl(rx + 1, cy)) {
				t.mc.rotation = -90;
				t.cx++;
				t.cy++;
			} else if (lev.testColl(rx, cy + 1) || testPix(rx, cy + 1)) {
				t.mc.rotation = 0;
			} else if (lev.testColl(rx, cy - 1) || testPix(rx, cy - 1)) {
				t.cx++;
				t.cy--;
				t.ry += 0.25;
				t.mc.rotation = -180;
			}
			return t;
		}

		if (col > 0xfa0000) {
			if (col == 0xFF0000) {
				if (rd.random(8) <= 4) {
					var platform = lev.getWall(rx, cy + 1);
					var p = heightMeterPool.create();
					if (platform == null)
						return;
					platform.addChild(p);
					p.toBack();
					p.y = -p.height * 0.5 - 6 - 10;
					p.alpha = 0.8;
					var pry = ry;
					p._txt.text = Std.int(pry / 3.0) + "M";
				}
			}
		} else {
			var colCode = extract(col, d);
			switch (colCode) {
				case 0xAB:
					genNmy(NT_BAD_HANDLE);
				case 0x7F:
					genNmy(NT_HANDLE);
				case 0x5e:
					genNmy(NT_SWARM);
				case 0xAC: // not yet implemented
				// torch
				case 0xde:
					var t = genNmy(NT_TORCH);
					if (lev.testColl(rx, cy + 1)) {
						t.getMovieClip().gotoAndStop(2);
						t.rx = 0;
					} else if (lev.testColl(rx, cy - 1)) {
						t.cy -= 2;
						t.rx = 0;
						t.getMovieClip().gotoAndStop(1);
					}
				// blades
				case 0x36:
					mkBlade();
				// massives
				case 0xcd:
					genNmy(NT_MASSIVE);
				default: // do nothing
			}
		}
	}

	public function updatePages() {
		var wh = Lib.ph();
		var n = getPage(); // nth page
		removePage(n - 2);
		addPage(n - 1);
		addPage(n);
		addPage(n + 1);
		addPage(n + 2);
		removePage(n + 3);

		function rd(n:Int)
			return new MRand(I32.of(Game.getSeed() + 271622.0 * n + Game.getSeed() * (n * 402264.0 * 398287.0)));

		var rdPN = rd(n);
		var rdPNP = rd(n + 1);

		var t = Lambda.count(sideDrops);

		function assign(pn:{first:Bmp, second:Bmp}, pnp:{first:Bmp, second:Bmp}) {
			var vp1 = 1 + rdPN.random(t);
			var vp2 = 1 + rdPN.random(t);
			if (vp1 == vp2)
				vp2 = 1 + (vp1 % t);

			pn.first = sideDrops.get(vp1)[0];
			pn.second = sideDrops.get(vp2)[1];

			var vp1 = 1 + rdPNP.random(t);
			var vp2 = 1 + rdPNP.random(t);
			if (vp1 == vp2)
				vp2 = 1 + (vp1 % t);

			pnp.first = sideDrops.get(vp1)[2];
			pnp.second = sideDrops.get(vp2)[3];

			pn.first.y = -n * wh;
			pn.second.y = -n * wh;

			pnp.first.y = -(n + 1) * wh;
			pnp.second.y = -(n + 1) * wh;
			for (o in [pn.first, pn.second, pnp.first, pnp.second])
				o.snap();
		}

		if (n % 2 == 0)
			assign(bg[0], bg[1]);
		else
			assign(bg[1], bg[0]);
	}

	public function update() {
		char.update();

		if (Game.getFrame() % 10 == 0 && !gameOverCalled) {
			// AKApi.emitEvent / getEvent: Arkadeo records the position of Mel every 10 frames and a replay puts it back
			// (live, the events come back at once): the position is kept to 1/256 of a cell
			char.cx = Std.int(char.cx);
			char.cy = Std.int(char.cy);
			char.rx = (Std.int(char.rx * 256.0 + 512.0) - 512.0) / 256.0;
			char.ry = (Std.int(char.ry * 256.0 + 512.0) - 512.0) / 256.0;
		}

		var charRect = char.getRect();
		for (l in nmyLists())
			for (e in l) {
				e.update();
				var rme = e.getRect();
				if (rme.intersects(charRect)) {
					var die = char.onColl(e);
					if (die)
						l.remove(e);
				}
			}

		var wh = Lib.h();
		var n = getPage(); // nth page

		var r = 0.18;
		var view = game.view;
		var prevView = ((1.0 - r) * view.y + r * (-char.mc.y + wh / 2));

		if (!SKIP_VIEW_SYNC) {
			view.y = Std.int(prevView);
			if (view.y < -30)
				view.y = -30;
		}

		p3.update();
		p2.update();
		p2b.update();

		if (n != previousPage) {
			previousPage = n;
			updatePages();
		}

		if (game.hasDeadLine())
			calcDeadLine();

		var cr = char.getRect();
		for (p in others) {
			if (p.mc == null) {
				others.remove(p);
				continue;
			}

			p.updatePhy();

			var diff:Float = Math.abs(p.mc.getRect(root).y - char.mc.y);
			p.mc.visible = !(diff > Lib.h());

			if (p.mc.visible) {
				var rect = p.getRect();
				if (rect.intersects(cr))
					p.onProc();
			}
		}

		if (tasks.length > 0)
			for (t in tasks)
				if (t())
					tasks.remove(t);

		rlife++;
		if (!pulpzStarted && (rlife == 20 * 40 || char.getMeter() > 40)) {
			pulpzStarted = true;
			new FxInit(Text.flee_0);
			new SMS(Text.flee_1);
		}

		if (pulpzStarted)
			life++;
	}

	public function getBonus() {
		return others.filter(function(e) return Std.isOfType(e, Bonus));
	}

	var pulpzStarted = false;
	var rlife = 0;

	// the deadline: the line under which the pulpz (the swarm) swallow Mel, rising slowly, then faster and faster
	public function calcDeadLine() {
		var cyLevel = 0.0;
		var diffTune = 1.0; // more is easier

		if (life <= 0) {
			dLevel = 20 + Lib.nbch();
			return;
		}

		if (Game.conf.deadLineSpeed != null)
			diffTune = Game.conf.deadLineSpeed;

		var cyPal1 = 25.0;
		var sPal1 = 40 * 15 * (1.0 / diffTune);

		var cyPal2 = 500.0;
		var sPal2 = 40 * 120 * (1.0 / diffTune);

		if (life <= sPal1)
			cyLevel = (cyPal1 / sPal1) * life; // first section make slow beginnint
		else if (life <= sPal2)
			cyLevel = cyPal1 + (cyPal2 / sPal2) * (life - sPal1); // moderate speed
		else {
			var b = cyPal1 + (cyPal2 / sPal2) * (sPal2 - sPal1);
			var r = life - sPal2;
			var vb = (cyPal2 / sPal2); // continue on old rythm
			var vbfactor = (1.0 + Game.q(Math.pow(r / (40.0 * 20.0), 0.333)) / diffTune); // 1...n // speed up frankly
			b += r * (vb * vbfactor);
			cyLevel = b;
		}

		cyLevel -= 20.0;
		dLevel = -cyLevel + Lib.nbch();
		deadLine.y = Std.int(dLevel * 16.0);
	}

	public function removePage(i:Int) {
		for (b in bmpPool.getUsed())
			if (b.key == i) {
				b.detach();
				bmpPool.destroy(b);
			}

		for (k in wallKeys) {
			var w = walls.get(k);
			if (w != null && w.pageKey == i) {
				w.remFromCol();
				w.finalize();
				walls.remove(makeKey(w.px, w.py));
			}
		}

		for (k in [for (k in nmy.keys()) k]) {
			var kept = new List<Nmy>();
			for (e in nmy.get(k)) {
				var del = e.page == i;
				if (del && e.mc.parent != null)
					root.removeChild(e.mc);
				if (!del)
					kept.add(e);
			}
			nmy.set(k, kept);
		}

		for (b in others)
			if (b.page == i)
				b.unstage();

		pages.set(i, false);
	}
}
