package pioupiou;

import kado.KadoKadeoManager;
import pixi.core.graphics.Graphics;
import mt.Timer;

class Level {
	var game:Game;

	public var tbl:Array<Array<Kind>>;

	var blocks:ASprite;
	var blocks_mask:Graphics;

	public var base_y:Int;

	var target_y:Int;
	var level:Int;
	var blk_speed:Float;
	var spawn:Float;
	var bonuses:Array<Bonus>;
	var fallings:Array<Block>;
	var blobings:Array<Block>;

	public function new(g:Game) {
		game = g;
		bonuses = [];
		fallings = [];
		blobings = [];
		spawn = 0;
		level = 0;
		blk_speed = Cs.BLK_SPEED + level * 0.1 * Cs.LVL_WIDTH;
		initLevel();
		updateMask();
	}

	function initLevel():Void {
		base_y = Cs.LVL_HEIGHT - 2;
		target_y = base_y;
		tbl = [];
		for (x in 0...Cs.LVL_WIDTH) {
			tbl[x] = [];
			tbl[x][0] = Kind.MASK;
		}
		blocks = game.dmanager.attach("blocks", Cs.PLAN_BLOCK);
		blocks._x = Cs.DELTA_X;
		blocks._y = Cs.DELTA_Y;
		blocks_mask = game.dmanager.empty(Cs.PLAN_BLOCK).getGraphics();
		blocks_mask.x = Cs.DELTA_X;
		blocks_mask.y = Cs.DELTA_Y;
		blocks.mask = blocks_mask;
	}

	function drawMask(x:Int, y:Int):Void {
		var ey = Cs.BLK_HEIGHT * Cs.LVL_HEIGHT;
		x *= Cs.BLK_WIDTH;
		y *= Cs.BLK_HEIGHT;
		blocks_mask.beginFill(0, 100);
		blocks_mask.moveTo(x, y);
		blocks_mask.lineTo(x + Cs.BLK_WIDTH, y);
		blocks_mask.lineTo(x + Cs.BLK_WIDTH, ey);
		blocks_mask.lineTo(x, ey);
		blocks_mask.lineTo(x, y);
		blocks_mask.endFill();
	}

	function randomProbas(probas:Array<Int>):Int {
		var total = 0;
		for (v in probas) {
			total += v;
		}
		if (total <= 0) {
			return 0;
		}
		var rnd = Seed.random(total);
		for (i in 0...probas.length) {
			rnd -= probas[i];
			if (rnd < 0) {
				return i;
			}
		}
		return 0;
	}

	function distMC(a:{x:Float, y:Float}, b:{x:Float, y:Float}):Float {
		var dx = a.x - b.x;
		var dy = a.y - b.y;
		return Math.sqrt(dx * dx + dy * dy);
	}

	function updateMask():Void {
		blocks_mask.clear();
		var sy = base_y - Cs.LVL_HEIGHT + 2;
		for (x in 0...Cs.LVL_WIDTH) {
			var y = sy;
			while (y <= base_y && tbl[x][y] == Kind.MASK) {
				y++;
			}
			if (y > sy) {
				drawMask(x, base_y + 1 - y);
			}
		}
	}

	function startFalling():Void {
		var x = 0;
		var y = base_y + 1;
		var ntrys = 20;
		do {
			x = Seed.random(Cs.LVL_WIDTH);
		} while (--ntrys > 0 && (tbl[x][y] != null || tbl[x][y - 1] != null));
		if (ntrys == 0) {
			return;
		}

		var i = 0;
		while (tbl[x][i + level] != null) {
			i++;
		}
		if (Seed.random(i * i) > 1) {
			startFalling();
			return;
		}

		tbl[x][y - 1] = Kind.BLOCK;
		var b = new Block(game, x, y);
		b.speed = blk_speed;
		b.mc._visible = false;
		b.time = 1;
		b.ann = game.interf.attach("announce", Cs.PLAN_FX);
		b.ann.loop = true;
		b.ann.play();
		b.ann._x = Cs.DELTA_X + Cs.BLK_WIDTH * x;
		fallings.push(b);
	}

	function genBonus():Void {
		var x = 0;
		var y = base_y + 1;
		var ntrys = 20;
		do {
			x = Seed.random(Cs.LVL_WIDTH);
		} while (--ntrys > 0 && (tbl[x][y] != null || tbl[x][y - 1] != null));
		if (ntrys == 0) {
			return;
		}
		for (bonus in bonuses) {
			if (bonus.x == x) {
				return;
			}
		}
		var t = randomProbas(Cs.BONUS_PROBAS_TBL);
		var b = new Bonus(game, x, y, t);
		bonuses.push(b);
	}

	public function getFalling(x:Int, y:Int):Null<Block> {
		for (b in fallings) {
			if (b.x == x && b.y == y) {
				return b;
			}
		}
		return null;
	}

	public function getPos(x:Float, y:Float):{x:Int, y:Int} {
		return {
			x: Std.int((x - Cs.DELTA_X) / Cs.BLK_WIDTH),
			y: game.level.base_y - Std.int((y - Cs.DELTA_Y) / Cs.BLK_HEIGHT)
		};
	}

	function checkMove():Void {
		var y = base_y - (Cs.LVL_HEIGHT - 3);
		for (x in 0...Cs.LVL_WIDTH) {
			if (tbl[x][y] != Kind.MASK) {
				return;
			}
		}
		target_y = base_y + 1;
	}

	public function scrollUp():Void {
		base_y++;
		for (b in fallings) {
			if (b.time > 0) {
				tbl[b.x][b.y - 1] = null;
				b.y++;
				tbl[b.x][b.y - 1] = Kind.BLOCK;
			}
			b.setPos();
			b.mc.updateState();
		}
		for (b in blobings) {
			b.setPos();
			b.mc.updateState();
		}
		for (b in bonuses) {
			b.mc._y += Cs.BLK_HEIGHT;
			b.mc.updateState();
		}
		game.hero.scrollUp();
		game.hero.mc._y = game.hero.y + Cs.BLK_HEIGHT;
		game.hero.mc.updateState();
		if (game.hero.state != Hero.DEATH) {
			level++;
			game.data.l++;
			game.setMeter(level);
		}
	}

	public function destroyBlock(b:Block):Void {
		tbl[b.x][b.y] = Kind.MASK;
		blobings.remove(b);
		b.destroy();
		updateMask();
		checkMove();
	}

	function updateFalling(b:Block):Bool {
		var r = true;
		var me = this;
		if (b.time > 0) {
			b.time -= Timer.deltaT;
			if (b.time <= 0) {
				b.mc._visible = true;
				b.ann.removeMovieClip();
			}
		} else {
			b.dy += Timer.tmod * b.speed;
			if (b.dy > Cs.BLK_HEIGHT) {
				b.dy -= Cs.BLK_HEIGHT;
				b.y--;
				tbl[b.x][b.y] = null;
				if (tbl[b.x][b.y - 1] != null) {
					b.dy = 0;
					b.mc.play();
					tbl[b.x][b.y] = Kind.BLOB;
					blk_speed += 0.1;
					blobings.push(b);
					r = false;
				} else {
					tbl[b.x][b.y - 1] = Kind.BLOCK;
				}
			}
			b.setPos();
		}
		return r;
	}

	public function update():Void {
		spawn += Timer.tmod / (1 + fallings.length) / Math.max(2, 15 - Math.max((level - 10) / 2, 0));

		while (Seed.random(10) < spawn * 10) {
			spawn--;
			var n = randomProbas([10, 5, 2, 1]);
			while (n >= 0) {
				startFalling();
				n--;
			}
		}

		if (Seed.random(Std.int(Cs.BONUS_PROBAS * bonuses.length / Timer.tmod)) == 0) {
			genBonus();
		}

		var i = 0;
		while (i < fallings.length) {
			if (!updateFalling(fallings[i])) {
				fallings.splice(i, 1);
			} else {
				i++;
			}
		}

		i = 0;
		while (i < bonuses.length) {
			var b = bonuses[i];
			if (game.hero.state != Hero.DEATH
				&& distMC({x: b.mc._x + Cs.BLK_WIDTH / 2, y: b.mc._y + Cs.BLK_WIDTH / 2}, {x: game.hero.mc._x, y: game.hero.mc._y}) < KadoKadeoManager.I(30)) {
				var mc = game.dmanager.attach("FXVanish" + (b.type + 1), Cs.PLAN_FX);
				mc.removeOnFrame = 60;
				mc.play();
				mc._x = b.mc._x + KadoKadeoManager.I(16);
				mc._y = b.mc._y + KadoKadeoManager.I(16);
				KadoKadeoManager.kkm.addScore(Cs.BONUS_POINTS[b.type]);
				game.data.b[b.type]++;
				if (game.data.fbl == -1) {
					game.data.fbl = level;
				}
				if (b.falling) {
					game.data.fb[b.type]++;
				}
				b.destroy();
				bonuses.splice(i, 1);
				continue;
			}

			if (b.falling) {
				b.mc._y += KadoKadeoManager.I(5) * Timer.tmod;
			}
			var p = getPos(b.mc._x, b.mc._y);
			if (!b.falling && tbl[p.x][p.y] != null) {
				var bl = getFalling(p.x, p.y + 1);
				if (bl == null || bl.dy > Cs.BLK_HEIGHT * 95 / 100) {
					b.destroy();
					game.data.bp[b.type]++;
					bonuses.splice(i, 1);
					continue;
				}
				b.mc._yscale = 100 - bl.dy * 100 / Cs.BLK_HEIGHT;
				b.recall(p.x, p.y);
				b.mc._y += (1 - b.mc._yscale / 100) * Cs.BLK_HEIGHT;
			} else if (tbl[p.x][p.y - 1] != null && tbl[p.x][p.y - 1] != Kind.BLOCK) {
				if (b.falling) {
					b.recall(null, p.y);
					b.falling = false;
				}
			} else {
				b.falling = true;
			}

			i++;
		}

		if (target_y != base_y) {
			game.scroll._y += Timer.tmod * KadoKadeoManager.I(5);
			if (game.scroll._y > Cs.BLK_HEIGHT) {
				game.scroll._y = 0;
				game.scroll.updateState();
				scrollUp();
				updateMask();
				checkMove();
			}
		}
	}
}
