package mel;

import js.lib.Int32Array;
import js.lib.Uint8Array;
import pixi.core.textures.Texture;
import pixi.core.math.shapes.Rectangle;
import mel.Lib;
import mel.Gfx;

// a flattened picture of the original (mt.deepnight.Lib.flatten): its animation, its size, its bounds offset
typedef Piece = {a:String, w:Int, h:Int, ?ofsY:Float};

// Data.hx of the original: the pictures cut out of gfx.Tiles, the level design (ld.png) and the page bitmap built from
// it, the movement fx (playFX), the red flash of a hit (bmpHit).
// Only the league mode of Arkadeo is ported (the endless climb with a score, like a KadoKado game): the 20 levels of
// the progression mode (Data.LD) are not.
class Data {
	public var platforms:Array<{corner:Array<Piece>, mid:Array<Piece>}>;
	public var props:Array<Piece>;
	public var walls:Array<Piece>;

	// 100 columns of wall tiles (indexes in walls), Lib.nbch() + 1 tiles each (flattened Shapes in the original)
	public var wallLine:Array<Array<Int>>;

	public var ldW:Int;
	public var ldH:Int;
	public var ldBmp:Int32Array;
	public var ldLines:Array<RectI>;

	var fxMove:Pool<MovementFX>;

	public static var ORANGE = 0xde7a00;

	public var bmpHit:Bitmap;

	public var game(get, null):Game;

	function get_game()
		return Game.me;

	public function playFX(str:String):MovementFX {
		var mc = fxMove.create();
		game.level.dm.add(mc, Level.FX_DEPTH);
		mc.gotoAndStop(str);
		mc.scaleX = mc.scaleY = 1;
		mc.rotationZ = 0;
		mc.snap();
		game.level.tasks.add(function() {
			var smc = mc.smc;
			if (smc != null) {
				smc.stop();
				if (smc.currentFrame >= smc.totalFrames) {
					smc.gotoAndStop(0);
					mc.detach();
					fxMove.destroy(mc);
					return true;
				} else {
					smc.nextFrame();
					return false;
				}
			}
			return false;
		});
		return mc;
	}

	public function new() {
		var meta = Art.meta();
		var raw = externs.Pako.inflate(new Uint8Array(haxe.crypto.Base64.decode(Art.LD).getData()));
		ldW = Art.LD_W;
		ldH = Art.LD_H;
		ldBmp = new Int32Array(ldW * ldH);
		for (i in 0...ldW * ldH)
			ldBmp[i] = (raw[i * 3] << 16) | (raw[i * 3 + 1] << 8) | raw[i * 3 + 2];
		fxMove = new Pool(() -> new MovementFX());
		// gfx.Tiles: 5 platforms (corner pieces 'start', body pieces 'body'), props, wall tiles
		platforms = [];
		for (p in (meta.tiles.plat : Array<Dynamic>))
			platforms.push({corner: p.corner, mid: p.mid});
		props = meta.tiles.props;
		walls = meta.tiles.walls;

		// (walls.random(): Std.random, pictures only)
		wallLine = [];
		for (i in 0...100) {
			var col = [];
			var prev = -1;
			for (j in 0...Lib.nbch() + 1) {
				var r = Seed.randomVfx(walls.length);
				if (r == prev)
					r = Seed.randomVfx(walls.length);
				prev = r;
				col.push(r);
			}
			wallLine.push(col);
		}

		makeLdLines();

		bmpHit = new Bitmap("hitflash");
		bmpHit.scaleX = bmpHit.scaleY = 2;
		bmpHit.blendMode = "add";
	}

	// a picture of a column of wall tiles (16 x 16 of each tile: the bitmap fill of a 16 x 16 rectangle)
	public function wallTexture(col:Int):Array<Texture> {
		return [
			for (t in wallLine[col]) {
				var tex = Tex.one(walls[t].a);
				new Texture(tex.baseTexture, new Rectangle(tex.frame.x, tex.frame.y, Math.min(16, tex.frame.width), Math.min(16, tex.frame.height)));
			}
		];
	}

	function snum(s:LD_PATTERN):Int {
		return switch (s) {
			case LDPage(_): 1;
			case LDGen(nb): nb;
		}
	}

	var nth = 0;

	public var genLines:Array<RectI>;
	public var pageBmp:Int32Array;
	public var pageW:Int;
	public var pageH:Int;

	public inline function ldPixel(x:Int, y:Int):Int {
		return (x < 0 || y < 0 || x >= ldW || y >= ldH) ? 0 : ldBmp[y * ldW + x];
	}

	public inline function pagePixel(x:Int, y:Int):Int {
		return (x < 0 || y < 0 || x >= pageW || y >= pageH) ? 0 : pageBmp[y * pageW + x];
	}

	// the page bitmap: lines of the level design one above the other (league: the first line, then random ones from
	// the 19th), each flipped or not
	public function addLdLines(rd:Rand) {
		var totalH = Lib.nbch() * 128;
		pageW = Lib.nbcw();
		pageH = totalH;
		pageBmp = new Int32Array(pageW * pageH);
		genLines = [];
		var cy = 0;
		var cx = 0;
		var procStart = 19;
		function std() {
			var idx = procStart + rd.random(ldLines.length - procStart);
			return ldLines[idx];
		}
		while (true) {
			var e = nth == 0 ? ldLines[procStart] : std();
			var eh = Std.int(e.height + 0.5);
			var ew = Std.int(e.width + 0.5);
			var flipX = rd.random(2) == 1;
			if (!Level.ENABLE_FLIP)
				flipX = false;
			for (y in 0...eh) {
				var ry = eh - y - 1;
				for (x in 0...ew) {
					var dx = cx;
					if (flipX)
						dx = pageW - cx;
					var p = ldPixel(e.x + x, e.y + ry);
					if (dx >= 0 && dx < pageW && cy < pageH)
						pageBmp[cy * pageW + dx] = p;
					cx++;
				}
				cx = 0;
				cy++;
			}
			if (cy > totalH)
				return;
			genLines.push(e);
			nth++;
		}
	}

	public inline function getPixel(n:Int, lx:Int, ly:Int):Int {
		ly = -ly;
		return pagePixel(lx, ly + Lib.nbch() * n);
	}

	public inline function iterPage(n:Int, proc:Int->Int->Int->Void) {
		for (y in 0...Lib.nbch())
			for (x in 0...Lib.nbcw() + 1)
				proc(x, y, pagePixel(x, Lib.nbch() * n + y));
	}

	// the lines of ld.png: runs of rows between white rows (column 0), up to the first 0xEEEEEE / 0xEEFF00 row
	public function makeLdLines() {
		var a:Array<RectI> = [];
		var streakY = -1;
		for (y in 0...ldH) {
			var pix = ldPixel(0, y);
			function push() {
				a.push({
					x: 0,
					y: streakY,
					width: Std.int(0.5 + ldW),
					height: y - streakY,
				});
				streakY = -1;
			}
			if (pix == 0xFFFFFF) {
				if (streakY >= 0)
					push();
			} else if (pix == 0xEEEEEE || pix == 0xEEFF00) {
				if (streakY >= 0)
					push();
				break;
			} else {
				if (streakY < 0)
					streakY = y;
			}
		}
		ldLines = a;
	}

	public static var SMS_RAND_REP = Text.sms_flash.split('|');
	public static var SMS_P = Text.var_p.split(',');
	public static var SMS_N = Text.var_n.split(',');

	public static function getSmsVar():String {
		var rd = new Rand(I32.of(Game.getSeed() * 8788383.0 + Game.getLevel() + Game.getFrame()));
		var s = Pick.array(SMS_RAND_REP, rd);
		s = s.split("$n").join(Pick.array(SMS_N, rd));
		return s.split("$p").join(Pick.array(SMS_P, rd));
	}
}
