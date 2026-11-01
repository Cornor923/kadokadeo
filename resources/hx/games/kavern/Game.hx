package kavern;

import common_haxe_avm1.kac.ProtectedInt;
import common_haxe_avm1.KeyboardManager;
import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchControlsMode;
import pixi.filters.colormatrix.ColorMatrixFilter;
import common_haxe_avm1.KKApi;
import kado.KadoKadeoManager;
import mt.DepthManager;
import mt.Timer;
import pixi.core.graphics.Graphics;
import pixi.core.text.Text;
import kado.TouchControlsConfig.TouchButtonShape;

class BgSprite extends ASprite {
	public var sub:ASprite;
}

class BonusSprite extends ASprite {
	public var t:Int;
	public var b:{x:Int, y:Int, t:Int};
}

class CasseSprite extends ASprite {
	public var f:Float;
}

class FallSprite extends ASprite {
	public var t:Float;
	public var py:Float;
	public var gridX:Int;
	public var gridY:Int;
}

class MeterSprite extends ASprite {
	public var field:Text;
}

class JaugeSprite extends ASprite {
	public var sub:ASprite;
	public var anim:ASprite;
}

@:expose('GameKavern')
class Game implements kado.GameInterface {
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		buttons: [
			{
				id: "left",
				label: "◀",
				leftPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.LEFT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "right",
				label: "▶",
				leftPx: 90,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.RIGHT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "down",
				label: "▼",
				rightPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.DOWN,
				shape: TouchButtonShape.SQUARE,
			},
		],
	};

	public var root_mc:ASprite;
	public var dmanager:DepthManager;
	public var level:Level;
	public var hero:Hero;

	var bg:BgSprite;
	var blocks:ASprite;
	var terre:ASprite;
	var terre_mask:Graphics;
	var mask:Graphics;

	public var needsUpdate:Bool;

	public var diff:Int;

	var life:ProtectedInt;
	var dlife:Float;
	var ilife:Int;
	var color:Int;

	var tmps:Array<ASprite>;
	var bonus:Array<Array<BonusSprite>>;
	var others:Array<Array<ASprite>>;
	var casse:Array<Array<CasseSprite>>;
	var parts:Array<{
		mc:ASprite,
		x:Float,
		y:Float,
		px:Int,
		py:Int,
		dx:Float,
		dy:Float,
		my:Float
	}>;

	public var falls:Array<FallSprite>;

	var meter:MeterSprite;
	var jauge:JaugeSprite;

	public var stats:{
		b:Array<Int>,
		l:Int,
		d:Int,
		k:Int,
		c:Int
	};

	public function new(root:ASprite, ?isReplay:Bool = false) {
		var replayKeys = new UInt16Array(7);
		replayKeys[0] = KeyboardManager.LEFT;
		replayKeys[1] = KeyboardManager.RIGHT;
		replayKeys[2] = KeyboardManager.DOWN;
		replayKeys[3] = KeyboardManager.A;
		replayKeys[4] = KeyboardManager.Q;
		replayKeys[5] = KeyboardManager.S;
		replayKeys[6] = KeyboardManager.D;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: replayKeys,
			recordInputs: true,
			recordEvents: false,
		});

		root_mc = root;
		diff = 0;
		life = new ProtectedInt(Cs.LIFE[0]);
		dlife = 0;
		dmanager = new DepthManager(root);
		bg = cast dmanager.attach("bg", Cs.PLAN_BG);
		terre = dmanager.attach("terre", Cs.PLAN_TERRE);
		terre_mask = dmanager.empty(Cs.PLAN_TERRE).getGraphics();
		blocks = dmanager.attach("blocks", Cs.PLAN_BLOCKS);
		mask = dmanager.empty(Cs.PLAN_BLOCKS).getGraphics();
		blocks.mask = mask;
		terre.mask = terre_mask;
		level = new Level(this);
		hero = new Hero(this, 1, Cs.HEIGHT - 2);
		stats = {
			b: [0, 0, 0, 0, 0, 0, 0, 0],
			d: 0,
			k: 0,
			c: 0,
			l: 0
		};
		meter = cast dmanager.attach("meter", Cs.PLAN_INTERF);
		meter._x = KadoKadeoManager.I(1);
		meter._y = KadoKadeoManager.I(300 - 1);
		meter.field = meter.initTextField("field", {
			font: "Junegull-Regular",
			size: 25,
			color: 0x376c64,
			align: "center",
			x: KadoKadeoManager.I(20),
			y: KadoKadeoManager.I(-15)
		});
		jauge = cast dmanager.attach("jauge", Cs.PLAN_INTERF);
		jauge._y = KadoKadeoManager.I(155);
		var filler = jauge.attachMovie("jaugeFiller", "sub");
		jauge.sub = filler.createEmptyMovieClip();
		var maskY = KadoKadeoManager.I(160);
		var maskHeight = KadoKadeoManager.I(128);
		var maskBottom = maskY + maskHeight;
		jauge.sub.pivot.y = maskBottom;
		jauge.sub._y = maskBottom - jauge._y;
		var mask1 = jauge.sub.getGraphics();
		mask1.beginFill(0xFFFFFF, 1);
		mask1.drawRect(KadoKadeoManager.I(5), maskY, KadoKadeoManager.I(14), maskHeight);
		mask1.endFill();
		filler.mask = mask1;
		jauge._x = KadoKadeoManager.I(301);
		jauge.anim = jauge.attachMovie("announce", "anim");
		jauge.anim.play();
		jauge.anim.loop = true;
		jauge.anim._yscale = -100;
		jauge.anim._x = KadoKadeoManager.S(12.5);
		jauge.anim._y = KadoKadeoManager.I(120);
		tmps = [];
		others = [];
		falls = [];
		parts = [];
		casse = [];
		bonus = [];
		changeLevel(0, 0);
	}

	public function getBonus(px:Int, py:Int):Void {
		var column = bonus[px];
		if (column == null)
			return;
		var b = column[py];
		if (b == null)
			return;
		stats.b[b.t]++;
		var max = Cs.LIFE[3];
		switch (b.t) {
			case 0:
				life += Std.int(Cs.LIFE[1]);
				if (life.get() >= KKApi.val(max))
					life = Std.int(max);
			case 1:
				life += Std.int(Cs.LIFE[2]);
				if (life.get() >= KKApi.val(max))
					life = Std.int(max);
			case _:
				KadoKadeoManager.kkm.addScore(Cs.LEGUMES_POINTS[b.t - 2]);
		}
		var fx = dmanager.attach("FXVanish", Cs.PLAN_PART);
		fx.play();
		fx._x = b._x + KadoKadeoManager.I(15);
		fx._y = b._y + KadoKadeoManager.I(15);
		tmps.push(fx);
		level.bonus.remove(b.b);
		b.removeMovieClip();
		bonus[px][py] = null;
	}

	function initFirstLevel():Void {
		var t = new Array();
		for (x in 0...Cs.WIDTH) {
			t[x] = new Array();
			var y:Int;
			for (y in 0...Cs.HEIGHT - 1)
				t[x][y] = Level.EMPTY;
			t[x][Cs.HEIGHT - 1] = Level.BLOCKSPE;
			t[x][Cs.HEIGHT] = Level.EMPTY;
		}
		t[0][8] = Level.BLOCKSPE;
		t[9][8] = Level.BLOCKSPE;
		for (i in 0...3)
			t[Seed.random(8) + 1][9] = Level.EARTH;
		level.tbl = t;
	}

	public function changeLevel(dx:Int, dy:Int):Void {
		for (x in 0...Cs.WIDTH)
			for (y in 0...Cs.HEIGHT) {
				if (others[x] != null && others[x][y] != null)
					others[x][y].removeMovieClip();
				if (casse[x] != null && casse[x][y] != null)
					casse[x][y].removeMovieClip();
				if (bonus[x] != null && bonus[x][y] != null)
					bonus[x][y].removeMovieClip();
			}
		for (tmp in tmps)
			tmp.removeMovieClip();
		for (part in parts)
			part.mc.removeMovieClip();
		for (fall in falls)
			fall.removeMovieClip();
		diff += dy;
		var terreFilter = new ColorMatrixFilter();
		var offset = 0.;
		if (diff > 40)
			offset = 0.761;
		else if (diff > 30)
			offset = 0.824;
		else if (diff > 20)
			offset = 0.883;
		else if (diff > 10)
			offset = 0.941;
		else
			offset = 1;
		terreFilter.matrix = [
			offset,      0,      0, 0, 0,
			     0, offset,      0, 0, 0,
			     0,      0, offset, 0, 0,
			     0,      0,      0, 1, 0
		];
		terre.filters = [terreFilter];
		bg.filters = [terreFilter];
		stats.d += dy;
		stats.l++;
		meter.field.text = ((diff == 0) ? "0" : ("-" + diff)) + "M";
		// meter.field.text = "-100m";
		tmps = new Array();
		others = new Array();
		falls = new Array();
		parts = new Array();
		casse = new Array();
		bonus = new Array();
		level.px += dx;
		level.py += dy;
		hero.x -= dx * KadoKadeoManager.I(290);
		hero.y -= dy * KadoKadeoManager.I(290);
		if (diff == 0) {
			bg.gotoAndStop(1);
			initFirstLevel();
		} else {
			bg.gotoAndStop(2);
			level.init(Std.int(hero.x / Cs.BLOCK_SIZE), Std.int(hero.y / Cs.BLOCK_SIZE), diff);
		}

		for (b in level.bonus) {
			var mc:BonusSprite = cast dmanager.attach("bonus", Cs.PLAN_BONUS);
			mc._x = b.x * Cs.BLOCK_SIZE;
			mc._y = b.y * Cs.BLOCK_SIZE;
			mc.gotoAndStop(b.t + 1);
			mc.t = b.t;
			mc.b = b;
			if (bonus[b.x] == null)
				bonus[b.x] = new Array();
			bonus[b.x][b.y] = mc;
		}
		for (x in 0...Cs.WIDTH)
			for (y in 0...Cs.HEIGHT) {
				var l = level.tbl[x][y];
				if (l == Level.BLOCKSPE) {
					var mc = dmanager.attach("hardblock", Cs.PLAN_BLOCKS);
					mc._x = x * Cs.BLOCK_SIZE;
					mc._y = y * Cs.BLOCK_SIZE;
					if (others[x] == null)
						others[x] = new Array();
					others[x][y] = mc;
				}
			}
		showLevel();
	}

	function draw(xp:Float, yp:Float, e:Int):Void {
		var s = Cs.BLOCK_SIZE;
		var dx = e * s;
		var cx = KadoKadeoManager.S(((xp / s * 30) % 7 + 1) * 2);
		var cy = KadoKadeoManager.S(((yp / s * 30) % 7 + 1) * 2);
		terre_mask.moveTo(xp - dx, yp);
		terre_mask.beginFill(0, 1);
		terre_mask.quadraticCurveTo(xp - dx / 2, yp - cy, xp, yp);
		terre_mask.quadraticCurveTo(xp + cx, yp + s / 2, xp, yp + s);
		terre_mask.quadraticCurveTo(xp - dx / 2, yp + s + cy, xp - dx, yp + s);
		terre_mask.quadraticCurveTo(xp - dx - cx, yp + s / 2, xp - dx, yp);
		terre_mask.endFill();
	}

	function showLevel():Void {
		mask.clear();
		terre_mask.clear();
		var e = 0;
		var s = Cs.BLOCK_SIZE;
		for (y in 0...Cs.HEIGHT) {
			var yp = y * s;
			var x = 0;
			while (x < Cs.WIDTH) {
				var l = level.tbl[x][y];
				var xp = x * s;
				if (l == Level.EARTH)
					e++;
				else {
					if (e > 0) {
						draw(xp, yp, e);
						e = 0;
					}
					if (l == Level.BLOCK) {
						if (level.tbl[x][y + 1] == Level.EMPTY && y != Cs.HEIGHT - 1) {
							level.tbl[x][y] = Level.FALLING;
							l = Level.FALLING;
							var mc:FallSprite = cast dmanager.attach("block", Cs.PLAN_BLOCKS);
							var c = casse[x] == null ? null : casse[x][y];
							if (c != null) {
								mc.gotoAndStop(c._currentframe);
								c.removeMovieClip();
							}
							mc.stop();
							mc.py = yp;
							mc.gridX = x;
							mc.gridY = y;
							mc.t = 1;
							mc._x = xp;
							mc._y = yp;
							falls.push(mc);
						} else {
							mask.moveTo(xp, yp);
							mask.beginFill(0, 100);
							mask.lineTo(xp + s, yp);
							mask.lineTo(xp + s, yp + s);
							mask.lineTo(xp, yp + s);
							mask.lineTo(xp, yp);
							mask.endFill();
						}
					}
				}
				x++;
			}
			if (e > 0) {
				draw(x * s, yp, e);
				e = 0;
			}
		}
	}

	public function genParts(px:Int, py:Int, dx:Float, dy:Float):Void {
		var n = Std.int(5 / Timer.tmod);

		deltaLife(-(50 + diff) / 200);

		for (i in 0...n) {
			var p = dmanager.attach("part", Cs.PLAN_BG);
			var x = px * Cs.BLOCK_SIZE + Seed.randomVfx(Cs.BLOCK_SIZE);
			var y = py * Cs.BLOCK_SIZE + Seed.randomVfx(Cs.BLOCK_SIZE);
			p.gotoAndStop(color);
			p._xscale = 50 + Seed.randomVfx(70);
			p._yscale = p._xscale;
			p._x = x;
			p._y = y;
			parts.push({
				mc: p,
				x: x,
				y: y,
				px: px,
				py: py,
				my: (py + 1) * Cs.BLOCK_SIZE,
				dx: KadoKadeoManager.S(dx + Seed.randomVfx(10) / 20),
				dy: KadoKadeoManager.S(dy - Seed.randomVfx(10) / 20)
			});
		}
	}

	public function deltaLife(d:Float):Void {
		dlife += d;
		var k = Std.int(dlife);
		dlife -= k;
		life += k;
	}

	public function doCasse(x:Int, y:Int):Void {
		if (casse[x] == null)
			casse[x] = new Array();
		var c = casse[x][y];
		if (c == null) {
			c = cast dmanager.attach("block", Cs.PLAN_BLOCKS);
			c._x = x * Cs.BLOCK_SIZE;
			c._y = y * Cs.BLOCK_SIZE;
			c.f = 0;
			c.stop();
			casse[x][y] = c;
		}
		if (c.f > 5)
			deltaLife(-Timer.tmod / 2);
		c.f += Timer.tmod / 2;
		c.gotoAndStop(Std.int(c.f) + 1);
		if (c.f >= c._totalframes) {
			c.removeMovieClip();
			stats.k++;
			level.tbl[x][y] = Level.EMPTY;
			needsUpdate = true;
		}
	}

	public function update(delta:Float):Void {
		var lf = life.get() + dlife;
		var il = Std.int(lf);
		if (ilife != il) {
			ilife = il;
			jauge.sub._yscale = il;
		}
		jauge.anim._visible = lf < 10;

		if (diff > 0 && jauge._x > KadoKadeoManager.I(275)) {
			jauge._x *= Math.pow(0.9, Timer.tmod);
			if (jauge._x < KadoKadeoManager.I(275))
				jauge._x = KadoKadeoManager.I(275);
		}

		if (lf <= 0) {
			life = Std.int(Cs.LIFE[4]);
			dlife = 0;
			if (hero.state == Hero.NORMAL && hero.anim != Hero.A_DEATH) {
				hero.state = Hero.DEATH;
				hero.anim = Hero.A_DEATH;
				hero.frame = 0;
			}
		}

		needsUpdate = false;
		hero.update();

		var i = 0;
		while (i < falls.length) {
			var f = falls[i];
			var removed = false;
			f.t -= Timer.deltaT;
			if (f.t < 0) {
				f._x = f.gridX * Cs.BLOCK_SIZE;
				f.py += KadoKadeoManager.I(5) * Timer.tmod;
				f._y = f.py;
				var py = Std.int(f.py / Cs.BLOCK_SIZE);
				if (py != f.gridY) {
					hero.moving = true;
					level.tbl[f.gridX][f.gridY] = Level.EMPTY;
					f.gridY++;
					hero.kill(f.gridX, f.gridY);
					if (level.tbl[f.gridX][f.gridY + 1] == Level.EMPTY)
						level.tbl[f.gridX][f.gridY] = Level.FALLING;
					else {
						level.tbl[f.gridX][f.gridY] = Level.BLOCK;
						f.removeMovieClip();
						needsUpdate = true;
						falls.splice(i, 1);
						removed = true;
					}
				}
			} else {
				f._x = f.gridX * Cs.BLOCK_SIZE + KadoKadeoManager.I(Seed.randomVfx(5) - 2);
			}
			if (!removed)
				i++;
		}
		if (needsUpdate)
			showLevel();

		i = 0;
		while (i < parts.length) {
			var p = parts[i];
			var removed = false;
			p.dy += Timer.tmod * KadoKadeoManager.S(0.5);
			p.x += p.dx * Timer.tmod;
			p.y += p.dy * Timer.tmod;
			if (level.tbl[p.px][p.py + 1] == Level.EMPTY) {
				p.my += Cs.BLOCK_SIZE;
				p.py++;
			}
			if (p.y > p.my) {
				p.y = p.my;
				p.dx = 0;
			}
			p.mc._xscale *= Math.pow(0.9, Timer.tmod);
			p.mc._x = p.x;
			p.mc._y = p.y;
			if (p.mc._xscale <= 10) {
				p.mc.removeMovieClip();
				parts.splice(i, 1);
				removed = true;
			}
			if (!removed)
				i++;
		}
	}

	public function destroy():Void {}
}
