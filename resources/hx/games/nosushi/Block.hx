package nosushi;

import nosushi.Game;

// A food of the tray (Block of the original): its clip gfx.Bloc (`mc`: the `_block` that breaks, the `_bonus` icon) and
// its flattened picture (`bmp`, Game.flatten) shown while it rests.
class Block {
	public var x:Int;
	public var y:Int;

	public var id:Int;
	public var bonus:Bonus;
	public var bonusTimer:Null<Int>;

	public var mc:MovieClip;
	public var bmp:Sprite;
	public var bmpOffset:{x:Float, y:Float};

	public var group:Group;

	public function new(px:Int, py:Int, isInit:Bool) {
		x = px;
		y = py;
		if (Game.me.blackProba > 0 && Game.me.rand(Game.me.blackProba) == 0)
			id = Game.BLACK_ID;
		else
			id = Game.me.rand(Game.MAX_ID);

		// (the bonuses from the first level of the LvUP, the bombs from its level 5: always in the League)
		bonus = mt.deepnight.RandList.fromEnum(Bonus, "proba").draw(Game.me.rand);

		switch (bonus) {
			case B_Bombe, B_Dynamite:
				bonusTimer = Game.BOMBE_TIMER;
			case B_MorePlay:
				if (Game.me.curMoreplay >= Game.MAX_MOREPLAY)
					bonus = B_None;
				else
					Game.me.curMoreplay++;
			case B_X2:
				if (Game.me.findSameBlock(this))
					bonus = B_None;
			default:
		}

		// (the in-game prizes of Arkadeo, a B_None turned into a gem B_AK1 to 4: none in KadoKadeo)

		draw(isInit);
	}

	function toString() {
		return "(" + x + "," + y + ")";
	}

	// the named children of gfx.Bloc
	public var _block(get, never):Clip;
	public var _bonus(get, never):Clip;

	inline function get__block()
		return mc.getClip("_block");

	inline function get__bonus()
		return mc.getClip("_bonus");

	function draw(init) {
		mc = new MovieClip(Data.BLOC);
		mc.gotoAndStop(id + 1);
		_bonus.gotoAndStop(Type.enumIndex(bonus) + 1);

		Game.me.dmtray.add(mc, Game.DP_BLOCKS);
		bmp = Game.flatten(id, bonus);
		bmpOffset = {x: bmp.x, y: bmp.y};
		Game.me.dmtray.add(bmp, Game.DP_BLOCKS);
		drawPos();

		if (init) {
			mc.visible = false;
		} else {
			bmp.visible = false;
			mc.scaleX = mc.scaleY = 1 / 4;
			var f = new mt.fx.Grow(mc, 0.3, 1);
			Game.me.addFx(f, function() {
				mc.visible = false;
				bmp.visible = true;
			});
		}
	}

	public function drawPos() {
		mc.x = x * Game.RAY - y * Game.RAY + Game.DELTA_X;
		mc.y = x * Game.RAY + y * Game.RAY + Game.DELTA_Y;
		bmp.x = mc.x + bmpOffset.x;
		bmp.y = mc.y + bmpOffset.y;
	}

	public function makeGroup(g:Group) {
		group = g;
		group.arr.push(this);

		if (id == Game.BLACK_ID)
			return;

		var grid = Game.me.grid;
		// (grid[x][-1] and grid[x][9] are undefined in Flash: null here too)
		var a = [
			grid[x][y - 1],
			grid[x][y + 1],
			x > 0 ? grid[x - 1][y] : null,
			x < Game.GRID_SIZE - 1 ? grid[x + 1][y] : null,
		];
		for (n in a) {
			if (n != null && n.group == null && n.id == id)
				n.makeGroup(g);
		}
	}

	public function gravityLeft() {
		Game.me.grid[x][y] = null;
		x++;
		Game.me.grid[x][y] = this;
		move();
	}

	public function gravityDown() {
		Game.me.grid[x][y] = null;
		y++;
		Game.me.grid[x][y] = this;
		move();
	}

	function move() {
		var nx = x * Game.RAY - y * Game.RAY + Game.DELTA_X + bmpOffset.x;
		var ny = x * Game.RAY + y * Game.RAY + Game.DELTA_Y + bmpOffset.y;
		var f = new mt.fx.Tween(bmp, nx, ny, 0.4);
		Game.me.addFx(f, function() {
			drawPos();
		});
	}

	public function breakBmp() {
		if (bmp == null)
			return;
		bmp.parent.removeChild(bmp);
		bmp = null;
		mc.visible = true;
	}

	public function vanish() {
		if (bmp != null && bmp.visible)
			new mt.fx.Sleep(new nosushi.fx.Alpha(bmp, 0, 0.08), null, 10);
		else if (mc != null && mc.visible)
			new mt.fx.Sleep(new nosushi.fx.Alpha(mc, 0, 0.08), null, 10);
	}

	public function exec(isGroup:Bool, isValid:Bool, count:Int, pts:Int) {
		if (isGroup) {
			doBonus();
			mc.filters = [];
			breakBmp();
			var t = new nosushi.fx.Play(_block, 2..._block.totalFrames);
			t.onFinish = function() {
				mc.parent.removeChild(mc);
			};

			if (pts > 0) {
				// a TextField in the device font "arial", bold, 18, of the colour of the food
				var tf = new TextField("pts");
				tf.text = Std.string(pts);
				tf.textColor = Game.ID_COLORS[id];

				var sp = new Sprite();
				Game.me.dm.add(sp, Game.DP_PART);
				sp.x = mc.x - tf.textWidth / 2;
				sp.y = mc.y - tf.textHeight;
				sp.alpha = 0;

				// sp.cacheAsBitmap = true, sp.filters = [the white GlowFilter]
				var f = new GlowFilter();
				f.color = 0xFFFFFF;
				f.strength = 4;
				f.blurX = f.blurY = 4;
				f.alpha = 1;
				sp.addChild(Game.me.cachedPicture(tf, pts + ":" + id, f));

				var f = new nosushi.fx.Alpha(sp, 1, 0.2);
				f.onFinish = function() {
					var p = new mt.fx.Part(sp);
					p.weight = -0.2;
					p.timer = 15;
					p.fadeLimit = 5;
					p.fadeType = 1;
				}
				new mt.fx.Sleep(f, null, 14);
			}
		}
		Game.me.grid[x][y] = null;
	}

	public function doBonus(doBombe = false) {
		switch (bonus) {
			case B_None:
				return;
			case B_Bombe, B_Dynamite:
				if (doBombe) {
					Game.me.enqueueBomb(this);
					return;
				}
			case B_MorePlay:
				Game.me.addPlay(Game.BONUS_ASPIRINE);
			case B_AK1, B_AK2, B_AK3, B_AK4:
				// (AKApi.takePrizeTokens: never in KadoKadeo)
			case B_X2:
		}

		_bonus.gotoAndStop(Type.enumIndex(B_None) + 1);

		var bmc = new MovieClip(Data.BONUS);
		bmc.gotoAndStop(Type.enumIndex(bonus) + 1);

		bmc.x = mc.x;
		bmc.y = mc.y - 10;
		Game.me.dm.add(bmc, Game.DP_TOPPART);

		var scale = 2.5;
		if (bonus == B_Bombe || bonus == B_Dynamite)
			scale = 0.1;
		var fx = new nosushi.fx.BonusVanish(bmc, scale);
		fx.curveIn(2);
	}

	public function showBombe() {
		var bmc = new MovieClip(Data.BONUS);
		bmc.gotoAndStop(Type.enumIndex(bonus) + 1);

		bmc.x = mc.x;
		bmc.y = mc.y - 10;
		Game.me.dm.add(bmc, Game.DP_TOPPART);

		var f = new mt.fx.Radiate(bmc, 0.5, 0xFFFFFF, 10);
		f.onFinish = function() {
			var fx = new nosushi.fx.BonusVanish(bmc);
			fx.curveIn(2);
		}
	}

	public function turnBonus() {
		if (bonus != B_Bombe && bonus != B_Dynamite)
			return;
		bonusTimer--;

		bmp.visible = false;
		mc.visible = true;

		var col = bonus == B_Bombe ? 0xFF0000 : 0xFFFFFF;
		var p = bonus == B_Bombe ? 0.35 : 0.28;

		if (bonusTimer > 1) {
			Game.me.addFx(new nosushi.fx.Radiate(_bonus, 0.04, col, 0.6, 12), function() {
				bmp.visible = true;
				mc.visible = false;
			});
			return;
		} else if (bonusTimer > 0) {
			new nosushi.fx.Radiate(_bonus, 0.08, col, p, -1);
			return;
		}

		breakBmp();
		doBonus(true);
	}
}
