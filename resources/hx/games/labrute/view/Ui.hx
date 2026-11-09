package labrute.view;

import pixi.core.display.Container;
import pixi.core.graphics.Graphics;
import pixi.core.sprites.Sprite;
import pixi.core.text.Text;
import pixi.core.textures.Texture;
import labrute.Data;

// the pictures of the sheets of the game (labrute-0.json and its packs, loaded by KadoKadeo before the game)
class Sheets {
	static var textures:Dynamic = null;

	public static function init():Void {
		textures = {};
		var res:Dynamic = untyped PIXI.Loader.shared.resources;
		for (k in Reflect.fields(res)) {
			var r:Dynamic = Reflect.field(res, k);
			var url:String = r.url != null ? r.url : k;
			if (r.spritesheet == null || url.indexOf("/labrute-") < 0)
				continue;
			var t:Dynamic = r.spritesheet.textures;
			for (name in Reflect.fields(t))
				Reflect.setField(textures, name, Reflect.field(t, name));
		}
	}

	public static function has(name:String):Bool {
		return textures != null && Reflect.field(textures, name) != null;
	}

	public static function tex(name:String):Texture {
		var t:Texture = textures == null ? null : Reflect.field(textures, name);
		return t != null ? t : untyped PIXI.Texture.EMPTY;
	}

	// an animation of the misc sheet: prefix + 1...count + suffix ("impact-1/" 13 ".png")
	public static function frames(prefix:String, count:Int, ?suffix:String = ".png", ?pad:Int = 0):Array<Texture> {
		var list = [];
		for (i in 1...count + 1) {
			var n = Std.string(i);
			while (n.length < pad)
				n = "0" + n;
			list.push(tex(prefix + n + suffix));
		}
		return list;
	}

	public static function sprite(name:String, ?ax:Float = 0.5, ?ay:Float = 0.5):Sprite {
		var s = new Sprite(tex(name));
		s.anchor.set(ax, ay);
		return s;
	}

	// a picture scaled to fit a box (aspect kept), centered on its anchor
	public static function fit(s:Sprite, w:Float, h:Float):Sprite {
		var tw = s.texture.width;
		var th = s.texture.height;
		if (tw > 0 && th > 0) {
			var k = Math.min(w / tw, h / th);
			s.scale.set(k, k);
		}
		return s;
	}
}

// the colors of the screens (parchment and wood)
class Col {
	public static inline var PARCHMENT = 0xFBF2AF;
	public static inline var PAPER = 0xF5E2B0;
	public static inline var CREAM = 0xFFF8DD;
	public static inline var WOOD = 0x4A2A10;
	public static inline var DARK = 0x2B170A;
	public static inline var INK = 0x1A0C04;
	public static inline var MUTED = 0x8A7A66;
	public static inline var RED = 0xB51D1D;
	public static inline var GREEN = 0x3B8A2E;
	public static inline var ORANGE = 0xD9861C;
	public static inline var GOLD = 0xFFCC33;
	public static inline var GOLD_TEXT = 0xB07A10;
	public static inline var WHITE = 0xFFFFFF;
	public static inline var HP = 0x17A717;
	public static inline var STRENGTH = 0xD62222;
	public static inline var AGILITY = 0x6A6AFF;
	public static inline var SPEED = 0xEB9800;
	// the tiers of a perk (1 green, 2 orange, 3 red; 0: not owned)
	public static var TIERS:Array<Int> = [0x999999, 0x7DBB2A, 0xFF9400, 0xE21C1C];
	// the boxes of a stat: every ten points fill them again with the next color (-1: empty), the colors of LaBrute
	public static var STAT_TIERS:Array<Int> = [
		-1, 0xCCCC00, 0xFFCC00, 0xFF9900, 0xFF6600, 0xFF3300, 0xFF0000, 0xCC0000, 0x990000, 0x660000, 0x330000, 0x000000, 0x00CCFF, 0x0099FF, 0x0066FF,
		0x0033FF, 0x0000FF, 0x0000CC, 0x000099, 0x000066, 0x000033, 0x000000
	];
	// the dark edge of the boxes
	public static inline var EDGE = 0x733D2C;

	public static function statTier(i:Int):Int {
		return STAT_TIERS[i < STAT_TIERS.length ? i : STAT_TIERS.length - 1];
	}

	// the colors of the stats in the tooltips (by S)
	public static function stat(s:Int):Int {
		return switch (s) {
			case S.HP, S.REGENERATION: HP;
			case S.STRENGTH, S.DAMAGE, S.CRIT_CHANCE, S.CRIT_DAMAGE: STRENGTH;
			case S.AGILITY, S.EVASION, S.ACCURACY, S.COMBO: AGILITY;
			case S.SPEED, S.INITIATIVE, S.HIT_SPEED: SPEED;
			case S.BLOCK, S.ARMOR: 0x5E6E7A;
			case S.DISARM, S.WEAPON_GRIP: 0xB0379C;
			case S.REVERSAL, S.COUNTER: 0x7A5230;
			default: 0x9C4A10;
		}
	}
}

// a piece of a line of a tooltip: its text, color, bold, alpha, size, a gold coin before it
typedef TipRun = {
	t:String,
	?c:Int,
	?b:Bool,
	?a:Float,
	?s:Float,
	?g:Bool,
	// (after the coin: the ear, the price in ears of a tier)
	?e:Bool,
}

class Ui {
	// the titles and the buttons (the fonts of the site), the texts of the tooltips
	public static var FONT:Array<String> = ["Helvetica", "sans-serif"];
	public static var BODY:Array<String> = ["Helvetica", "sans-serif"];
	// the titles of the pages, the banner of the winner, the texts of the buttons, the gold of the top band and of the
	// rewards, the names of the fighters (`font-title` of the skin)
	public static var TITLE:Array<String> = ["Fredoka Bold", "Helvetica", "sans-serif"];

	// a text in the font of the titles
	public static function title(t:Text):Text {
		t.style.fontFamily = TITLE;
		t.style.fontWeight = "normal";
		// (its size changed: on whole pixels again)
		snap(t);
		return t;
	}

	// a text in another font (its weight normal)
	public static function useFont(t:Text, font:Array<String>):Text {
		t.style.fontFamily = font;
		t.style.fontWeight = "normal";
		snap(t);
		return t;
	}

	// the texts in a container in the font of the titles (a button)
	public static function buttonFont(c:Container):Void {
		for (child in c.children)
			if (Std.isOfType(child, Text)) {
				var t:Text = cast child;
				t.style.fontFamily = TITLE;
				snap(t);
			}
	}

	// PixiJS 6 measures each new font by reading the pixels of its canvas (TextMetrics.measureFont): a canvas made for it
	// (willReadFrequently: kept in memory, not on the GPU) measures it 4 times faster; the game measures about 170 of
	// them while it starts
	public static function fastTextMetrics():Void {
		var metrics:Dynamic = js.Syntax.code("PIXI.TextMetrics");
		if (metrics == null || metrics._kadoFast == true)
			return;
		var canvas = js.Browser.document.createCanvasElement();
		canvas.width = canvas.height = 10;
		var context:Dynamic = canvas.getContext("2d", {willReadFrequently: true});
		if (context == null)
			return;
		metrics._canvas = canvas;
		metrics._context = context;
		metrics._kadoFast = true;
	}

	public static function text(s:String, size:Float, color:Int, ?align:String = "left", ?stroke:Int = -1, ?wrap:Float = 0, ?body:Bool = false,
			?bold:Bool = false):Text {
		var style:pixi.core.text.DefaultStyle = {
			fontFamily: body ? BODY : FONT,
			fontSize: size,
			fill: color,
			align: align,
		};
		if (bold)
			style.fontWeight = "bold";
		if (stroke >= 0) {
			style.stroke = stroke;
			style.strokeThickness = Math.max(2, Math.round(size / 6));
			style.lineJoin = "round";
		}
		if (wrap > 0) {
			style.wordWrap = true;
			style.wordWrapWidth = wrap;
		}
		return new Text(s, style);
	}

	// a text placed by its anchor
	public static function label(parent:Container, s:String, x:Float, y:Float, size:Float, color:Int, ?ax:Float = 0, ?ay:Float = 0, ?stroke:Int = -1,
			?bold:Bool = false):Text {
		var t = text(s, size, color, ax == 0.5 ? "center" : ax == 1 ? "right" : "left", stroke, 0, false, bold);
		t.anchor.set(ax, ay);
		t.x = x;
		t.y = y;
		snap(t);
		parent.addChild(t);
		return t;
	}

	// a text moved by less than a pixel so that its top left corner is on a whole pixel (not blurred), its anchor kept
	public static function snap(t:Text):Void {
		t.x = Math.round(t.x - t.width * t.anchor.x) + t.width * t.anchor.x;
		t.y = Math.round(t.y - t.height * t.anchor.y) + t.height * t.anchor.y;
	}

	public static function panel(g:Graphics, x:Float, y:Float, w:Float, h:Float, fill:Int, ?border:Int = Col.WOOD, ?alpha:Float = 1,
			?radius:Float = 8):Graphics {
		g.lineStyle(3, border, 1);
		g.beginFill(fill, alpha);
		g.drawRoundedRect(x, y, w, h, radius);
		g.endFill();
		return g;
	}

	public static function bar(g:Graphics, x:Float, y:Float, w:Float, h:Float, ratio:Float, color:Int, ?back:Int = 0x3A1E0C):Void {
		if (ratio < 0)
			ratio = 0;
		if (ratio > 1)
			ratio = 1;
		g.lineStyle(2, Col.INK, 1);
		g.beginFill(back, 1);
		g.drawRect(x, y, w, h);
		g.endFill();
		if (ratio > 0) {
			g.lineStyle(0, 0, 0);
			g.beginFill(color, 1);
			g.drawRect(x + 1, y + 1, (w - 2) * ratio, h - 2);
			g.endFill();
			g.beginFill(0xFFFFFF, 0.25);
			g.drawRect(x + 1, y + 1, (w - 2) * ratio, (h - 2) * 0.4);
			g.endFill();
		}
	}

	// the HP in a heart (its number over it): the picture `hp` of the skin
	public static function heartValue(parent:Container, cx:Float, cy:Float, w:Float, hp:Int):Void {
		Skin.icon(parent, "hp", cx, cy, w, w * 0.85);
		label(parent, Std.string(hp), cx, cy - w * 0.04, Math.max(10, w * 0.34), Col.WHITE, 0.5, 0.5, 0x5A1010, true);
	}

	// the 10 boxes of a stat: every point fills one, every ten points fill them all again with the next color
	public static function statBoxes(g:Graphics, x:Float, y:Float, value:Int, ?boxW:Float = 12, ?boxH:Float = 20, ?gap:Float = 2):Void {
		var base = Std.int(value / 10);
		var extra = value % 10;
		for (i in 0...10) {
			var c = Col.statTier(i < extra ? base + 1 : base);
			g.lineStyle(2, Col.EDGE, 1, 0);
			if (c >= 0)
				g.beginFill(c, 1);
			g.drawRect(x + i * (boxW + gap), y, boxW, boxH);
			if (c >= 0)
				g.endFill();
		}
		g.lineStyle(0, 0, 0);
	}

	// a thin bar of a stat (the tooltips, the cards): the color of its tens, the next one for the rest
	public static function miniStat(g:Graphics, x:Float, y:Float, value:Int, ?w:Float = 58, ?h:Float = 8):Void {
		var base = Col.statTier(Std.int(value / 10));
		var next = Col.statTier(Std.int(value / 10) + 1);
		g.lineStyle(1, Col.EDGE, 1, 0);
		if (base >= 0)
			g.beginFill(base, 1);
		g.drawRect(x, y, w, h);
		if (base >= 0)
			g.endFill();
		var part = (value % 10) / 10;
		if (part > 0) {
			g.beginFill(next, 1);
			g.drawRect(x, y, w * part, h);
			g.endFill();
		}
		g.lineStyle(0, 0, 0);
	}

	// the badge of a league (its number, 1 for the first one): the picture `rank-<number>` of the skin
	public static function medal(parent:Container, cx:Float, cy:Float, league:Int, ?r:Float = 17):Void {
		Skin.icon(parent, "rank-" + (league + 1), cx, cy + r * 0.2, r * 2.4, r * 2.4);
	}

	// the wins toward the next league
	public static function progress(g:Graphics, x:Float, y:Float, done:Int, total:Int, ?boxW:Float = 12, ?boxH:Float = 18):Void {
		for (i in 0...total) {
			g.lineStyle(2, Col.EDGE, 1, 0);
			if (i < done)
				g.beginFill(0x4CAF50, 1);
			g.drawRect(x + i * (boxW + 2), y, boxW, boxH);
			if (i < done)
				g.endFill();
		}
		g.lineStyle(0, 0, 0);
	}

	// the flag of a language in w × h from x, y, a black outline of 1 pixel: the picture `flag-<lang>` of the skin, else
	// drawn (the languages without their picture: Italian, Korean), else its box only
	public static function flag(parent:Container, lang:String, x:Float, y:Float, w:Float, h:Float):Void {
		var g = new Graphics();
		g.beginFill(0x000000, 1);
		g.drawRect(x - 1, y - 1, w + 2, h + 2);
		g.endFill();
		parent.addChild(g);
		if (Skin.has("flag-" + lang)) {
			var s = new Sprite(Skin.tex("flag-" + lang));
			s.x = x;
			s.y = y;
			s.width = w;
			s.height = h;
			parent.addChild(s);
			return;
		}
		var f = new Graphics();
		switch (lang) {
			case "it":
				for (k in 0...3) {
					f.beginFill([0x009246, 0xFFFFFF, 0xCE2B37][k], 1);
					f.drawRect(x + k * w / 3, y, w / 3, h);
					f.endFill();
				}
			case "ko":
				// (white, the red and blue circle, the four black trigrams as bars)
				f.beginFill(0xFFFFFF, 1);
				f.drawRect(x, y, w, h);
				f.endFill();
				var r = h * 0.25;
				f.beginFill(0x0047A0, 1);
				f.drawCircle(x + w / 2, y + h / 2, r);
				f.endFill();
				f.beginFill(0xCD2E3A, 1);
				f.arc(x + w / 2, y + h / 2, r, Math.PI, 0);
				f.endFill();
				f.beginFill(0x000000, 1);
				for (c in [[0.18, 0.22], [0.82, 0.22], [0.18, 0.78], [0.82, 0.78]])
					f.drawRect(x + w * c[0] - w * 0.06, y + h * c[1] - h * 0.1, w * 0.12, h * 0.2);
				f.endFill();
			default:
				f.beginFill(0x808080, 1);
				f.drawRect(x, y, w, h);
				f.endFill();
		}
		parent.addChild(f);
	}

	// a five-pointed star (the tiers in the tooltips)
	public static function star(g:Graphics, cx:Float, cy:Float, r:Float, ?fill:Int = 0xFFD54A):Void {
		g.lineStyle(1.5, 0x6B4A12, 1);
		g.beginFill(fill, 1);
		for (i in 0...10) {
			var a = -Math.PI / 2 + i * Math.PI / 5;
			var d = i % 2 == 0 ? r : r * 0.45;
			if (i == 0)
				g.moveTo(cx + Math.cos(a) * d, cy + Math.sin(a) * d);
			else
				g.lineTo(cx + Math.cos(a) * d, cy + Math.sin(a) * d);
		}
		g.closePath();
		g.endFill();
	}

	// a weapon without a frame, centered on cx, cy: at tier 2 or 3, an outline of the color of its tier around its
	// pixels (copies of it in that color around it); at tier 1, the outline `tier1` if given (-1: none)
	public static function perkIcon(parent:Container, name:String, cx:Float, cy:Float, size:Float, tier:Int, ?alpha:Float = 1,
			?tier1:Int = -1):Sprite {
		var outline = tier >= 2 ? Col.TIERS[tier] : tier == 1 ? tier1 : -1;
		return outlined(parent, Sheets.tex(name), cx, cy, size, size, outline, TIER_OUTLINE, alpha);
	}

	// a picture fitted in w × h, centered on cx, cy, with an outline of this color (-1: none) and width around its pixels
	// (copies of it around it, painted in that color whatever the colors of the picture)
	public static function outlined(parent:Container, tex:Texture, cx:Float, cy:Float, w:Float, h:Float, color:Int, width:Float,
			?alpha:Float = 1):Sprite {
		function make(into:Container, dx:Float, dy:Float):Sprite {
			var s = Sheets.fit(new Sprite(tex), w, h);
			s.anchor.set(0.5, 0.5);
			s.x = cx + dx;
			s.y = cy + dy;
			s.alpha = alpha;
			into.addChild(s);
			return s;
		}
		if (color >= 0) {
			var group = new Container();
			parent.addChild(group);
			group.filters = [solid(color)];
			for (d in [[-1.0, 0.0], [1.0, 0.0], [0.0, -1.0], [0.0, 1.0], [-0.7, -0.7], [0.7, 0.7], [-0.7, 0.7], [0.7, -0.7]])
				make(group, d[0] * width, d[1] * width);
		}
		return make(parent, 0, 0);
	}

	// a perk of the shop with the outline of its tier: at tier 1, black (tier1 wide); at tier 2 or 3, black (inner wide)
	// then the color of its tier around it (ring wide, the colors of the frames of LaBrute: Col.TIERS); none at tier 0
	public static function tierOutlined(parent:Container, tex:Texture, cx:Float, cy:Float, w:Float, h:Float, tier:Int, inner:Float, ring:Float,
			tier1:Float, ?alpha:Float = 1):Sprite {
		return tierCopies(parent, tier, inner, ring, tier1, (into, dx, dy) -> {
			var s = Sheets.fit(new Sprite(tex), w, h);
			s.anchor.set(0.5, 0.5);
			s.x = cx + dx;
			s.y = cy + dy;
			s.alpha = alpha;
			into.addChild(s);
			return s;
		});
	}

	// the same, the picture put by a matrix [a, b, c, d, tx, ty] (from its pixels: Skin.matrix), turned or not
	public static function tierOutlinedAt(parent:Container, tex:Texture, m:Array<Float>, tier:Int, inner:Float, ring:Float, tier1:Float,
			?alpha:Float = 1):Sprite {
		return tierCopies(parent, tier, inner, ring, tier1, (into, dx, dy) -> {
			var s = new Sprite(tex);
			js.Syntax.code("{0}.transform.setFromMatrix(new PIXI.Matrix({1}, {2}, {3}, {4}, {5}, {6}))", s, m[0], m[1], m[2], m[3], m[4] + dx,
				m[5] + dy);
			s.alpha = alpha;
			into.addChild(s);
			return s;
		});
	}

	// the copies of a perk made by `make` in a container at an offset (pixels) for the outline of its tier, then the perk
	// itself
	static function tierCopies(parent:Container, tier:Int, inner:Float, ring:Float, tier1:Float, make:(Container, Float, Float) -> Sprite):Sprite {
		function ringOf(color:Int, r:Float):Void {
			// (in one plain color, whatever the colors of the picture: its copies in a group painted by a filter)
			var group = new Container();
			parent.addChild(group);
			group.filters = [solid(color)];
			// (16 directions: no gap in the thin parts)
			for (k in 0...16) {
				var a = k * Math.PI / 8;
				make(group, Math.cos(a) * r, Math.sin(a) * r);
			}
		}
		if (tier >= 2)
			ringOf(Col.TIERS[tier], inner + ring);
		if (tier >= 1)
			ringOf(0x000000, tier >= 2 ? inner : tier1);
		return make(parent, 0, 0);
	}

	// a filter painting all it covers in one color (its alpha kept)
	public static function solid(color:Int):Dynamic {
		var f:Dynamic = js.Syntax.code("new PIXI.filters.ColorMatrixFilter()");
		var m:Array<Float> = [
			0, 0, 0, 0, ((color >> 16) & 0xFF) / 255,
			0, 0, 0, 0, ((color >> 8) & 0xFF) / 255,
			0, 0, 0, 0, (color & 0xFF) / 255,
			0, 0, 0, 1, 0
		];
		f.matrix = m;
		f.resolution = js.Browser.window.devicePixelRatio;
		return f;
	}

	// the matrix m1 · m2 (m2 first), as [a, b, c, d, tx, ty]
	public static function mul(m1:Array<Float>, m2:Array<Float>):Array<Float> {
		return [
			m1[0] * m2[0] + m1[2] * m2[1],
			m1[1] * m2[0] + m1[3] * m2[1],
			m1[0] * m2[2] + m1[2] * m2[3],
			m1[1] * m2[2] + m1[3] * m2[3],
			m1[0] * m2[4] + m1[2] * m2[5] + m1[4],
			m1[1] * m2[4] + m1[3] * m2[5] + m1[5]
		];
	}

	// the width of the outline of a weapon of tier 2 or 3
	public static var TIER_OUTLINE:Float = 1;

	// a gold coin and an amount, placed by its anchor ax (the coin on the left)
	public static function gold(parent:Container, x:Float, y:Float, amount:String, size:Float, ?color:Int = Col.GOLD, ?stroke:Int = Col.INK,
			?ax:Float = 0, ?font:Array<String>):Float {
		return money(parent, "gold", x, y, amount, size, color, stroke, ax, font);
	}

	// the same with the ears (the picture `ear` of the skin): the price of the tiers of the perks
	public static function ears(parent:Container, x:Float, y:Float, amount:String, size:Float, ?color:Int = Col.GOLD, ?stroke:Int = Col.INK,
			?ax:Float = 0, ?font:Array<String>):Float {
		return money(parent, "ear", x, y, amount, size, color, stroke, ax, font);
	}

	// an amount after the icon of its money, ax of its width at x, its middle at y: its width
	static function money(parent:Container, icon:String, x:Float, y:Float, amount:String, size:Float, color:Int, stroke:Int, ax:Float,
			font:Array<String>):Float {
		var coin = Sheets.fit(new Sprite(Skin.tex(icon)), size * 1.15, size * 1.15);
		coin.anchor.set(0.5, 0.5);
		var t = text(amount, size, color, "left", stroke);
		if (font != null)
			t.style.fontFamily = font;
		t.anchor.set(0, 0.5);
		var w = size * 1.25 + t.width;
		var left = x - w * ax;
		coin.x = left + size * 0.55;
		coin.y = y;
		t.x = left + size * 1.25;
		t.y = y;
		snap(t);
		parent.addChild(coin);
		parent.addChild(t);
		return w;
	}

	// the icon of a stat (strength, agility, speed) of the skin, its left at x, its middle at cy (null: not given)
	public static function statIcon(parent:Container, stat:String, x:Float, cy:Float, ?size:Float = 13):Sprite {
		var s = Skin.icon(parent, stat, x + size / 2, cy, size, size);
		return s;
	}

	// a panel: the picture `name` of the skin stretched over it (its edges kept), nothing without it
	public static function skinPanel(g:Graphics, parent:Container, name:String, x:Float, y:Float, w:Float, h:Float, fill:Int, ?border:Int = Col.WOOD):Void {
		if (!Skin.has(name))
			return;
		// 9 pieces: the corners kept, the edges and the middle stretched
		var t = Skin.tex(name);
		var f = t.frame;
		var e = Math.min(16, Math.min(f.width, f.height) / 3);
		var sx = [0, e, f.width - e, f.width];
		var sy = [0, e, f.height - e, f.height];
		var dx = [x, x + e, x + w - e, x + w];
		var dy = [y, y + e, y + h - e, y + h];
		for (i in 0...3)
			for (j in 0...3) {
				var piece = new Texture(t.baseTexture,
					js.Syntax.code("new PIXI.Rectangle({0}, {1}, {2}, {3})", f.x + sx[i], f.y + sy[j], sx[i + 1] - sx[i], sy[j + 1] - sy[j]));
				var s = new Sprite(piece);
				s.x = dx[i];
				s.y = dy[j];
				s.width = dx[i + 1] - dx[i];
				s.height = dy[j + 1] - dy[j];
				parent.addChild(s);
			}
	}

	public static function destroy(c:Container):Void {
		if (c == null)
			return;
		if (c.parent != null)
			c.parent.removeChild(c);
		untyped c.destroy({children: true});
	}

	// "1 234"
	public static function num(v:Int):String {
		var s = Std.string(v < 0 ? -v : v);
		var out = "";
		while (s.length > 3) {
			out = " " + s.substr(s.length - 3) + out;
			s = s.substr(0, s.length - 3);
		}
		return (v < 0 ? "-" : "") + s + out;
	}

	public static function percent(v:Float):String {
		var p = Math.round(v * 100);
		return (p > 0 ? "+" : "") + p + " %";
	}

	// "1,1"
	public static function mult(m:Float):String {
		var v = Math.round(m * 10);
		return Std.int(v / 10) + "," + (v % 10);
	}
}

// a button of a screen: its action is what the replay records when it is clicked
class Button {
	public var x:Float;
	public var y:Float;
	public var w:Float;
	public var h:Float;
	public var action:Int;
	public var enabled(default, null):Bool = true;
	public var view:Container;

	// the picture of the skin (`skin`, `skin`-hover), else drawn
	var pic:Sprite;
	var skin:String;

	// how much the texts and the coin of a button with a picture go up under the mouse (the picture `-hover` raised)
	public static var HOVER_LIFT:Float = 3;

	var txt:Text;
	// its texts and its coin: raised together under the mouse
	var content:Container;
	var hovered:Bool = false;

	public function new(parent:Container, x:Float, y:Float, w:Float, h:Float, label:String, action:Int, ?color:Int = Col.RED, ?size:Float = 16,
			?subLabel:String = null, ?skin:String = "button") {
		// (its corner on whole pixels: its picture and its texts not blurred)
		x = Math.round(x);
		y = Math.round(y);
		this.x = x;
		this.y = y;
		this.w = w;
		this.h = h;
		this.action = action;
		this.skin = skin;
		view = new Container();
		if (Skin.has(skin)) {
			// (the proportions of the picture: its width given, its height from it, around the same middle)
			var f = Skin.tex(skin).frame;
			w = this.w = Math.round(w);
			var ph = Math.round(w * f.height / f.width);
			// (on a whole pixel: not blurred)
			this.y = y = Math.round(y + (h - ph) / 2);
			this.h = h = ph;
			pic = new Sprite(Skin.tex(skin));
			pic.x = x;
			pic.width = w;
			pic.height = h;
			view.addChild(pic);
		}
		content = new Container();
		view.addChild(content);
		txt = Ui.text(label, size, Col.WHITE, "center", Col.INK);
		txt.anchor.set(0.5, 0.5);
		txt.x = x + w / 2;
		txt.y = subLabel == null ? y + h / 2 : y + h / 2 - size * 0.35;
		Ui.snap(txt);
		content.addChild(txt);
		if (subLabel != null) {
			// (a price, "250 or": the coin, then its amount)
			var subSize = Math.max(10, size * 0.65);
			if (StringTools.endsWith(subLabel, " or"))
				Ui.gold(content, x + w / 2, y + h / 2 + size * 0.5, subLabel.substr(0, subLabel.length - 3), subSize, Col.GOLD, Col.INK, 0.5);
			else
				Ui.label(content, subLabel, x + w / 2, y + h / 2 + size * 0.5, subSize, Col.GOLD, 0.5, 0.5, Col.INK);
		}
		Ui.buttonFont(content);
		parent.addChild(view);
		draw();
	}

	public inline function contains(mx:Float, my:Float):Bool {
		return mx >= x && mx < x + w && my >= y && my < y + h;
	}

	public function hit(mx:Float, my:Float):Bool {
		return enabled && view.visible && contains(mx, my);
	}

	public function setEnabled(b:Bool):Void {
		if (b == enabled)
			return;
		enabled = b;
		draw();
	}

	public function setHover(b:Bool):Void {
		b = b && enabled;
		if (b == hovered)
			return;
		hovered = b;
		draw();
	}

	function draw():Void {
		if (pic != null) {
			pic.texture = hovered && Skin.has(skin + "-hover") ? Skin.tex(skin + "-hover") : Skin.tex(skin);
			pic.y = y;
			content.y = hovered ? -HOVER_LIFT : 0;
			view.alpha = enabled ? 1 : 0.5;
			return;
		}
		// (without its picture: its texts only, nothing drawn)
		content.y = hovered ? -HOVER_LIFT : 0;
		view.alpha = enabled ? 1 : 0.5;
	}
}

// The content of a tooltip, line by line: titles, texts, lines of colored pieces, pictures
class TipBox {
	public var view(default, null):Container;
	public var width(default, null):Float;
	// its box square, with an outline of 1 pixel (the brutes of the fight)
	public var square:Bool = false;

	var y:Float = 0;
	// a picture floated on the left (floatTo): the texts above its bottom start after it
	var floatX:Float = 0;
	var floatBottom:Float = 0;

	public function new(?width:Float = 240) {
		this.width = width;
		view = new Container();
	}

	public function height():Float {
		return Math.max(y, floatBottom);
	}

	// where a line at the height `top` starts (after the floated picture, or at 0 under it)
	inline function left(top:Float):Float {
		return top < floatBottom ? floatX : 0;
	}

	// a picture on the left, w wide (its height from its proportions), margin pixels after it: the next texts go on its
	// right, then under it over the whole width (CSS float: left)
	public function floatTo(tex:Texture, w:Float, margin:Float):TipBox {
		var s = new Sprite(tex);
		s.scale.set(w / tex.width, w / tex.width);
		s.x = 0;
		s.y = y;
		view.addChild(s);
		floatX = w + margin;
		floatBottom = y + tex.height * w / tex.width;
		return this;
	}

	// a picture fitted in w × h, centered, with its shadow (CSS drop-shadow(dx dy blur black)) under it
	public function shadowImage(tex:Texture, w:Float, h:Float, dx:Float, dy:Float, blur:Float):TipBox {
		var shadow = Sheets.fit(new Sprite(tex), w, h);
		shadow.anchor.set(0.5, 0.5);
		shadow.x = width / 2 + dx;
		shadow.y = y + h / 2 + dy;
		var blurFilter:Dynamic = js.Syntax.code("new PIXI.filters.BlurFilter({0}, 2)", blur);
		blurFilter.resolution = js.Browser.window.devicePixelRatio;
		shadow.filters = [Ui.solid(0x000000), blurFilter];
		view.addChild(shadow);
		return image(tex, w, h);
	}

	// a paragraph of pieces of text (one style each) cut into lines at its spaces, lineHeight × its size high each
	// (a CSS line box), beside the floated picture then under it; a piece without a space is never cut (a tiered value)
	public function flow(runs:Array<TipRun>, ?lineHeight:Float = 1.2, ?center:Bool = false):TipBox {
		var size = 0.0;
		for (r in runs)
			size = Math.max(size, r.s != null ? r.s : 12);
		var lh = Math.round(size * lineHeight);
		// the words: their pieces of text, the space after them
		var words:Array<{parts:Array<Text>, w:Float, space:Float}> = [];
		var word = null;
		for (r in runs) {
			if (r.t == null || r.t == "")
				continue;
			function make(s:String):Text {
				var t = Ui.text(s, r.s != null ? r.s : 12, r.c != null ? r.c : Col.WOOD, "left", -1, 0, true, r.b == true);
				t.alpha = r.a != null ? r.a : 1;
				return t;
			}
			var pieces = r.t.split(" ");
			for (i in 0...pieces.length) {
				if (i > 0) {
					// (a space: the end of the word, its width that of the style of the space)
					if (word == null)
						word = {parts: [], w: 0.0, space: 0.0};
					word.space += make("a a").width - make("aa").width;
					words.push(word);
					word = null;
				}
				if (pieces[i] == "")
					continue;
				if (word == null)
					word = {parts: [], w: 0.0, space: 0.0};
				var t = make(pieces[i]);
				word.parts.push(t);
				word.w += t.width;
			}
		}
		if (word != null)
			words.push(word);
		var line = new Container();
		var x = 0.0;
		var wait = 0.0;
		function close():Void {
			var off = left(y);
			line.x = off + (center ? Math.max(0, (width - off - x) / 2) : 0);
			line.y = y;
			view.addChild(line);
			y += lh;
			line = new Container();
			x = 0;
			wait = 0;
		}
		for (w in words) {
			if (x > 0 && x + wait + w.w > width - left(y))
				close();
			if (x > 0)
				x += wait;
			for (t in w.parts) {
				t.x = x;
				t.y = Math.round((lh - t.height) / 2);
				line.addChild(t);
				x += t.width;
			}
			wait = w.space;
		}
		if (x > 0 || line.children.length > 0)
			close();
		return this;
	}

	// a margin above the next texts
	public function gap(h:Float):TipBox {
		y += h;
		return this;
	}

	// (left: after the floated picture)
	public function title(s:String, ?center:Bool = true, ?color:Int = Col.WOOD, ?size:Float = 16, ?bold:Bool = false):TipBox {
		var off = center ? 0 : left(y);
		var t = Ui.text(s, size, color, center ? "center" : "left", -1, width - off, false, bold);
		t.anchor.set(center ? 0.5 : 0, 0);
		t.x = center ? width / 2 : off;
		t.y = y;
		view.addChild(t);
		y += t.height + 2;
		return this;
	}

	// the tier of a perk: one star by tier above the first
	public function stars(tier:Int):TipBox {
		if (tier <= 1)
			return this;
		var g = new Graphics();
		var n = tier - 1;
		for (i in 0...n)
			Ui.star(g, width / 2 - (n - 1) * 9 + i * 18, y + 8, 7.5, 0xFFFFFF);
		view.addChild(g);
		y += 18;
		return this;
	}

	public function image(tex:Texture, w:Float, h:Float):TipBox {
		var s = Sheets.fit(new Sprite(tex), w, h);
		s.anchor.set(0.5, 0.5);
		s.x = width / 2;
		s.y = y + h / 2;
		view.addChild(s);
		y += h + 4;
		return this;
	}

	// a text over the whole width
	public function para(s:String, ?size:Float = 12, ?color:Int = Col.WOOD, ?alpha:Float = 1, ?bold:Bool = false):TipBox {
		var t = Ui.text(s, size, color, "left", -1, width, true, bold);
		t.alpha = alpha;
		t.y = y;
		view.addChild(t);
		y += t.height + 2;
		return this;
	}

	// a line of pieces of text (one style each)
	public function line(runs:Array<TipRun>, ?center:Bool = false):TipBox {
		var c = new Container();
		var x = 0.0;
		var h = 0.0;
		for (r in runs) {
			if (r.t == null || r.t == "")
				continue;
			var t = Ui.text(r.t, r.s != null ? r.s : 12, r.c != null ? r.c : Col.WOOD, "left", -1, 0, true, r.b == true);
			t.alpha = r.a != null ? r.a : 1;
			if (r.g == true || r.e == true) {
				var coin = Sheets.fit(new Sprite(Skin.tex(r.e == true ? "ear" : "gold")), t.height * 0.9, t.height * 0.9);
				coin.anchor.set(0, 0.5);
				coin.x = x;
				coin.y = t.height / 2;
				c.addChild(coin);
				x += t.height * 0.9 + 2;
			}
			t.x = x;
			x += t.width;
			if (t.height > h)
				h = t.height;
			c.addChild(t);
		}
		var off = left(y);
		c.x = off + (center ? Math.max(0, (width - off - x) / 2) : 0);
		c.y = y;
		view.addChild(c);
		y += h + 1;
		return this;
	}

	// a horizontal line, margin pixels above and under it (after the floated picture)
	public function separator(?color:Int = Col.WOOD, ?alpha:Float = 0.35, ?margin:Float = 3):TipBox {
		var g = new Graphics();
		var off = left(y);
		g.lineStyle(1, color, alpha);
		g.moveTo(off, y + margin + 0.5);
		g.lineTo(width, y + margin + 0.5);
		view.addChild(g);
		y += margin * 2 + 1;
		return this;
	}

	// a drawing of a given height
	public function draw(h:Float, paint:(Container, Float) -> Void):TipBox {
		var c = new Container();
		c.y = y;
		paint(c, width);
		view.addChild(c);
		y += h;
		return this;
	}

	// the values of the 3 tiers as LaBrute writes them (TieredStat): « +[10/15/20]% », the brackets and the other tiers
	// faded, the current one in bold, the others not bold (the rest bold or not: bold), alpha and size for all of them
	// (a single value when they are the same)
	public static function tiered(values:Array<String>, tier:Int, color:Int, ?prefix:String = "", ?suffix:String = "", ?bold:Bool = true,
			?alpha:Float = 1, ?size:Float = 12):Array<TipRun> {
		var same = true;
		for (v in values)
			if (v != values[0])
				same = false;
		if (same)
			return [{t: prefix + values[0] + suffix, c: color, b: bold, a: alpha, s: size}];
		var runs:Array<TipRun> = [];
		if (prefix != "")
			runs.push({t: prefix, c: color, b: bold, a: alpha, s: size});
		runs.push({t: "[", c: color, b: bold, a: alpha * TIER_FADE, s: size});
		for (i in 0...values.length) {
			if (i > 0)
				runs.push({t: "/", c: color, b: bold, a: alpha * TIER_FADE, s: size});
			runs.push({
				t: values[i],
				c: color,
				b: i == tier - 1,
				a: i == tier - 1 ? alpha : alpha * TIER_FADE,
				s: size
			});
		}
		runs.push({t: "]", c: color, b: bold, a: alpha * TIER_FADE, s: size});
		if (suffix != "")
			runs.push({t: suffix, c: color, b: bold, a: alpha, s: size});
		return runs;
	}

	// the opacity of the brackets and the other tiers
	static inline var TIER_FADE = 0.3;
}

// the box of what the mouse is over (in a replay: the mouse of the player, recorded), made when it is first shown
class Tooltip {
	public var view:Container;

	var bg:Graphics;
	var content:Container;
	var key:String = null;
	var w:Float = 0;
	var h:Float = 0;

	public function new(parent:Container) {
		view = new Container();
		bg = new Graphics();
		view.addChild(bg);
		view.visible = false;
		parent.addChild(view);
	}

	public function show(key:String, make:Void->TipBox, mx:Float, my:Float):Void {
		if (key == null) {
			hide();
			return;
		}
		if (key != this.key) {
			this.key = key;
			if (content != null)
				Ui.destroy(content);
			var box = make();
			content = box.view;
			// (square: its corners, its outline of 1 pixel, closer to its content)
			var pad = box.square ? 6 : 10;
			content.x = pad;
			content.y = box.square ? 5 : 8;
			view.addChild(content);
			w = box.width + pad * 2;
			h = box.height() + (box.square ? 9 : 14);
			bg.clear();
			if (box.square) {
				bg.lineStyle(1, Col.WOOD, 1, 0);
				bg.beginFill(Col.PARCHMENT, 0.98);
				bg.drawRect(0, 0, w, h);
				bg.endFill();
				bg.lineStyle(0, 0, 0);
			} else {
				bg.beginFill(0x000000, 0.25);
				bg.drawRoundedRect(3, 4, w, h, 6);
				bg.endFill();
				// (an outline of 1 pixel, inside the box)
				bg.lineStyle(1, Col.WOOD, 1, 0);
				bg.beginFill(Col.PARCHMENT, 0.98);
				bg.drawRoundedRect(0, 0, w, h, 6);
				bg.endFill();
				bg.lineStyle(0, 0, 0);
			}
		}
		var x = mx + 16;
		var y = my + 16;
		if (x + w > 596)
			x = mx - w - 10;
		if (y + h > 456)
			y = my - h - 10;
		view.x = Math.max(4, x);
		view.y = Math.max(4, Math.min(456 - h, y));
		view.visible = true;
	}

	public function hide():Void {
		view.visible = false;
	}

	// a screen made again: its tooltip too
	public function reset():Void {
		key = null;
		hide();
	}
}

// The pictures of the team in place of the drawings of the game (public/assets/img/content/labrute/skin, listed in its
// skin.json by build_skin.mjs). Each one is optional: without it the drawing stays. Loaded after the start of the game
// (only pictures: the screens are made again when they come, `epoch`), never in the replay verifier.
class Skin {
	public static var epoch(default, null):Int = 0;
	static inline var DIR = "/assets/img/content/labrute/skin/";
	static var textures:Map<String, Texture> = new Map();
	// the pictures drawn from an SVG (here, or once for all by optimize_skin.mjs: `origins` of skin.json): where the point
	// (0, 0) of their drawing is in them (in units of the drawing), how many pixels they have by unit
	static var origins:Map<String, {x:Float, y:Float, k:Float}> = new Map();
	static inline var SVG_SCALE = 2;
	static var asked = false;
	// its pictures and fonts loaded (or failed, or after READY_MS): the game is shown from then on, not its drawings
	// before them
	public static var ready(default, null):Bool = false;
	static inline var READY_MS = 4000;

	static function done():Void {
		if (!ready) {
			ready = true;
			epoch++;
		}
	}

	public static function load():Void {
		if (asked)
			return;
		asked = true;
		if (KadoKadeoManager.kkm != null && KadoKadeoManager.kkm.headless) {
			ready = true;
			return;
		}
		js.Browser.window.setTimeout(done, READY_MS);
		try {
			var w:Dynamic = js.Browser.window;
			w.fetch(DIR + "skin.json", {cache: "no-cache"})
				.then((r:Dynamic) -> r.ok ? r.json() : null)
				.then((m:Dynamic) -> {
					if (m == null || m.files == null) {
						done();
						return null;
					}
					var all:Array<Dynamic> = [];
					if (m.origins != null)
						for (name in Reflect.fields(m.origins)) {
							var o:Dynamic = Reflect.field(m.origins, name);
							origins.set(name, {x: o.x, y: o.y, k: o.k});
						}
					// (the same file under several names: loaded once)
					var loads:Map<String, Dynamic> = new Map();
					for (name in Reflect.fields(m.files)) {
						var url = DIR + Reflect.field(m.files, name);
						if (StringTools.startsWith(name, "font")) {
							all.push(loadFont(name, url, name == "font" && !Reflect.hasField(m.files, "font-body")));
							continue;
						}
						if (StringTools.endsWith(url.toLowerCase(), ".svg")) {
							all.push(loadSvg(name, url));
							continue;
						}
						// (with its mipmaps: smooth when it is drawn smaller)
						if (!loads.exists(url))
							loads.set(url, js.Syntax.code("PIXI.Texture.fromURL({0}, {1})", url, {mipmap: 2}));
						all.push(loads.get(url).then((t:Texture) -> {
							textures.set(name, t);
							return null;
						}, (_) -> null));
					}
					// (late: the screens made again with them)
					return js.Syntax.code("Promise.all({0})", all).then((_) -> ready ? epoch++ : {
						done();
						epoch;
					});
				})
				.catchError((_) -> done());
		} catch (e:Dynamic) {
			done();
		}
	}

	// a font of the skin: `font` the labels (and the tooltips, the titles without their own one), `font-body` the
	// tooltips, `font-title` the titles, the buttons, the gold of the top band and of the rewards, the names of the
	// fighters (Ui.TITLE)
	static function loadFont(name:String, url:String, body:Bool):Dynamic {
		var family = "LaBrute skin " + name;
		var face:Dynamic = js.Syntax.code("new FontFace({0}, {1})", family, "url(" + url + ")");
		return face.load().then((f:Dynamic) -> {
			js.Syntax.code("document.fonts.add({0})", f);
			// (`font` also for the titles without their own one, whatever comes first)
			if (name == "font") {
				Ui.FONT.unshift(family);
				if (Ui.TITLE[0].indexOf("LaBrute skin") != 0)
					Ui.TITLE.unshift(family);
			}
			if (name == "font-title") {
				if (Ui.TITLE[0] == "LaBrute skin font")
					Ui.TITLE.shift();
				Ui.TITLE.unshift(family);
			}
			if (name == "font-body" || body)
				Ui.BODY.unshift(family);
			return null;
		}, (_) -> null);
	}

	// an SVG picture: drawn SVG_SCALE times bigger (sharp when it is scaled up, smoothed down by its mipmaps), the
	// point (0, 0) of its drawing kept (its viewBox may start left of and above it: the outline of the weapons)
	static function loadSvg(name:String, url:String):Dynamic {
		var w:Dynamic = js.Browser.window;
		return w.fetch(url).then((r:Dynamic) -> r.ok ? r.text() : null).then((text:String) -> {
			if (text == null)
				return null;
			var box = ~/viewBox="\s*([-0-9.eE]+)[\s,]+([-0-9.eE]+)/;
			var has = box.match(text);
			origins.set(name, {x: has ? -Std.parseFloat(box.matched(1)) : 0, y: has ? -Std.parseFloat(box.matched(2)) : 0, k: SVG_SCALE});
			var data = "data:image/svg+xml;base64," + w.btoa(js.Syntax.code("unescape(encodeURIComponent({0}))", text));
			var options = {mipmap: 2, resourceOptions: {scale: SVG_SCALE}};
			return js.Syntax.code("PIXI.Texture.fromURL({0}, {1})", data, options).then((t:Texture) -> {
				textures.set(name, t);
				return null;
			});
		}).then(null, (_) -> null);
	}

	// the matrix [a, b, c, d, tx, ty] of the picture `name` put where the matrix `m` puts its drawing: from the pixels
	// of the picture (one drawn from an SVG bigger, its origin inside it)
	public static function matrix(name:String, m:Array<Float>):Array<Float> {
		var o = origins.get(local(name));
		var k = o != null ? 1 / o.k : 1.0;
		var ox = o != null ? o.x : 0.0;
		var oy = o != null ? o.y : 0.0;
		return [m[0] * k, m[1] * k, m[2] * k, m[3] * k, m[4] - m[0] * ox - m[2] * oy, m[5] - m[1] * ox - m[3] * oy];
	}

	// the picture `name` in the language of the game: `<name>-<lang>` when there is one (`fight-en`), else the English
	// one (as the texts), else `name`
	static function local(name:String):String {
		var lang = labrute.Lang.current;
		if (lang == labrute.Lang.LANGS[0])
			return name;
		for (l in [lang, labrute.Lang.FALLBACK])
			if (textures.exists(name + "-" + l))
				return name + "-" + l;
		return name;
	}

	public static function has(name:String):Bool {
		return textures.exists(local(name));
	}

	// the size of the drawing of the picture `name` (one drawn from an SVG: its texture is bigger)
	public static function size(name:String):{w:Float, h:Float} {
		var t = tex(name);
		var o = origins.get(local(name));
		var k = o != null ? 1 / o.k : 1.0;
		return {w: t.width * k, h: t.height * k};
	}

	public static function tex(name:String):Texture {
		var t = textures.get(local(name));
		return t != null ? t : untyped PIXI.Texture.EMPTY;
	}

	// a picture fitted in a box (aspect kept), centered on cx, cy (null: not given)
	public static function icon(parent:Container, name:String, cx:Float, cy:Float, w:Float, h:Float):Sprite {
		if (!has(name))
			return null;
		var s = Sheets.fit(new Sprite(tex(name)), w, h);
		s.anchor.set(0.5, 0.5);
		s.x = cx;
		s.y = cy;
		parent.addChild(s);
		return s;
	}

	// a picture stretched over a box (false: not given)
	public static function box(parent:Container, name:String, x:Float, y:Float, w:Float, h:Float):Bool {
		if (!has(name))
			return false;
		var s = new Sprite(tex(name));
		s.x = x;
		s.y = y;
		s.width = w;
		s.height = h;
		parent.addChild(s);
		return true;
	}

	// the frames `name`-1, `name`-2... (empty: not given)
	public static function frames(name:String):Array<Texture> {
		var list = [];
		var i = 1;
		while (has(name + "-" + i))
			list.push(tex(name + "-" + i++));
		return list;
	}

	// a pet: its picture of the skin (`pet-dog1`...), else the one of the game
	public static function pet(name:String):Texture {
		return tex("pet-" + name);
	}
}
