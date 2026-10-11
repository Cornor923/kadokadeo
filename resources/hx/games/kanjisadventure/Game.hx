package kanjisadventure;

import kado.TouchControlsConfig.TouchButtonShape;
import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchControlsMode;
import pixi.core.text.Text;
import kanjisadventure.ent.Hero;
import kanjisadventure.ent.Bad;
import kanjisadventure.ev.Bomb as EvBomb;
import kanjisadventure.ev.Floor as EvFloor;
import kanjisadventure.ev.Shoot as EvShoot;
import kanjisadventure.ev.Teleport as EvTeleport;
import kanjisadventure.ev.Trader as EvTrader;

enum MonsterStep {
	MAttack;
	MMove;
	MEnd;
}

enum Step {
	Shop;
	Event;
	Play;
	Work;
	GameOver;
}

@:expose('GameKanjisAdventure')
class Game implements kado.GameInterface {
	// turn based on a grid: a 4 way joystick (it follows the finger) and the shuriken button.
	// The items of the bag and the shop are tapped (or 1-5 on a keyboard)
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		buttons: [
			{
				id: "up",
				label: "▲",
				leftPx: 64,
				bottomPx: 76,
				size: 56,
				keyCode: KeyboardManager.UP,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "left",
				label: "◀",
				leftPx: 8,
				bottomPx: 20,
				size: 56,
				keyCode: KeyboardManager.LEFT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "right",
				label: "▶",
				leftPx: 120,
				bottomPx: 20,
				size: 56,
				keyCode: KeyboardManager.RIGHT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "down",
				label: "▼",
				leftPx: 64,
				bottomPx: 20,
				size: 56,
				keyCode: KeyboardManager.DOWN,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "action",
				label: "+",
				rightPx: 12,
				bottomPx: 20,
				size: 80,
				keyCode: KeyboardManager.SPACE,
			}
		],
	};

	// ZQSD / WASD move like the arrows, Enter and Control throw a shuriken like Space
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE.concat(KeyboardManager.ALIASES_ENTER_SPACE).concat(KeyboardManager.ALIASES_CONTROL_SPACE);

	public static var DP_ITEMS = 4;
	public static var DP_INTER = 3;
	public static var DP_FADER = 2;
	public static var DP_MAP = 1;
	public static var DP_BG = 0;

	// replay events (clicks of the player)
	public static inline var EV_USE = 0; // use the item x of the bag
	public static inline var EV_BUY = 1; // buy the item x of the shop
	public static inline var EV_LEAVE = 2; // leave the shop
	static inline var EV_DEBUG_SHOP = 3; // test hook (debug builds)

	static inline var DIGIT_1 = 49;
	static inline var SLOT = 28;

	public var flShoot:Bool;
	public var flMove:Bool;
	public var flQueue:Bool;
	public var flMute:Bool;

	public var event:Event;
	public var step:Step;
	public var endStep:Int;
	public var next:MonsterStep;

	public var floors:Array<Floor>;
	public var cfl:Floor;

	public var coef:Float;
	public var did:Int;

	public var bx:Int;
	public var by:Int;

	public var bagSize:Int;
	public var food:Int;
	public var gold:Int;
	public var shuriken:Int;
	public var weaponId:Int;
	public var armorId:Int;
	public var huntMax:Int;

	public var inventory:Array<Int>;

	public var flhColor:Int;
	public var flh:Null<Float>;

	var logCoef:Null<Float>;

	public var hero:Hero;
	public var work:Array<Ent>;
	public var active:Array<Ent>;
	public var allies:Array<Ent>;
	public var logs:Array<ASprite>;

	public var dm:DepthManager;
	public var root:ASprite;
	public var bg:ASprite;

	var mcInter:ASprite;
	var barLife:ASprite;
	var fieldLife:Text;
	var fieldFood:Text;
	var fieldGold:Text;
	var fieldShuriken:Text;
	var slotItems:Array<ASprite>;
	var slotsAction:Bool;

	public var mcLog:ASprite;

	var logTimer:Float;

	var isReplay:Bool;

	static public var me:Game;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		var replayKeys = new UInt16Array(5);
		replayKeys[0] = KeyboardManager.UP;
		replayKeys[1] = KeyboardManager.DOWN;
		replayKeys[2] = KeyboardManager.LEFT;
		replayKeys[3] = KeyboardManager.RIGHT;
		replayKeys[4] = KeyboardManager.SPACE;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: replayKeys,
			recordInputs: true,
			recordEvents: true,
		});
		this.isReplay = isReplay;

		Cs.init();
		this.root = root;
		me = this;
		dm = new DepthManager(root);
		bg = dm.empty(DP_BG);
		var g = bg.getGraphics();
		g.beginFill(Cs.COL_MCBG);
		g.drawRect(0, 0, Cs.mcw, Cs.mch);
		g.endFill();
		did = Seed.random(12000);

		huntMax = 10;

		flShoot = true;
		flMove = false;
		flQueue = false;
		flMute = false;

		bagSize = 3;
		food = 250;
		gold = 0;
		shuriken = 3;
		armorId = 0;
		weaponId = 0;

		allies = [];
		inventory = [];
		work = [];
		active = [];
		logs = [];
		slotItems = [];
		slotsAction = false;

		initInter();

		displayFood();
		displayGold();
		displayShuriken();
		displayItems();

		enterDungeon();
	}

	// UPDATE
	public function update(delta:Float) {
		for (e in KadoKadeoManager.kkm.replay.consumeEvents()) {
			applyEvent(e);
		}
		if (!isReplay)
			pollUiInput();

		switch (step) {
			case Play:
				updatePlay();
			case Work:
				updateWork();
			case Event:
				event.update();
			case GameOver:
				updateGameOver();
			default:
		}
		if (flh != null)
			updateFlash();
		if (logCoef != null)
			updateLog();
		if (mcLog != null && mcLog._alpha > 0)
			updateLogAlpha();

		if (step == Play)
			hoverItems(MouseManager.getX(), MouseManager.getY());

		mt.bumdum.Sprite.updateAll();
	}

	// clicks (mouse or tap) and the item keys of a live game become replay events
	function pollUiInput() {
		if (step == Play) {
			for (i in 0...bagSize) {
				if (KeyboardManager.isJustDown(DIGIT_1 + i) && inventory[i] != null) {
					recordAndApply(EV_USE, i);
					return;
				}
			}
		}
		if (!MouseManager.isButtonJustPressed(MouseManager.BUTTON_LEFT))
			return;
		var mx = MouseManager.getX();
		var my = MouseManager.getY();
		if (step == Play) {
			var i = slotAt(mx, my);
			if (i != null && inventory[i] != null)
				recordAndApply(EV_USE, i);
		} else if (step == Event && Std.isOfType(event, EvTrader)) {
			var shop:EvTrader = cast event;
			var a = shop.getClick(mx, my);
			if (a != null)
				recordAndApply(a[0], a[1]);
		}
	}

	function recordAndApply(k:Int, x:Int) {
		var e = {k: k, x: x, y: 0};
		KadoKadeoManager.kkm.replay.recordEvent(e, KadoKadeoManager.kkm.replay.getCurrentFrame());
		applyEvent(e);
	}

	function applyEvent(e:Dynamic) {
		if (e == null)
			return;
		var k:Null<Int> = Reflect.field(e, "k");
		var x:Null<Int> = Reflect.field(e, "x");
		if (k == null || x == null)
			return;
		switch (k) {
			case EV_USE:
				if (step == Play && inventory[x] != null)
					useItem(x);
			case EV_BUY:
				if (Std.isOfType(event, EvTrader))
					(cast event : EvTrader).buyAt(x);
			case EV_LEAVE:
				if (Std.isOfType(event, EvTrader))
					(cast event : EvTrader).leave();
			#if debug
			case EV_DEBUG_SHOP:
				if (step == Play)
					new EvTrader();
			#end
			default:
		}
	}

	// DUNGEON
	public function enterDungeon() {
		floors = [];
		hero = new Hero();
		hero.x = Std.int(Cs.XMAX * 0.5);
		hero.y = Std.int(Cs.YMAX * 0.5);
		loadFloor(0);
		step = Play;
		initPlay();
	}

	public function loadFloor(id:Int) {
		if (cfl != null)
			cfl.hide();
		cfl = getFloor(id);
		cfl.show();
		hero.setFloor(cfl);
		hero.setPos(hero.x, hero.y);
		bx = hero.x;
		by = hero.y;
		hero.display();
		cfl.scroll(hero, true);
	}

	public function getFloor(id:Int) {
		var fl = floors[id];
		if (fl == null) {
			fl = new Floor(id);
			floors[id] = fl;
			if (id > 0)
				Cs.probaLevelUp();
		}
		return fl;
	}

	// CHECK
	public function initEvents() {
		checkEvents();
	}

	public function checkEvents() {
		if (hero.life <= 0) {
			initGameOver();
			return;
		}

		if (flMove) {
			if (hero.sq.type == STAIR_UP)
				new EvFloor(1);
			else if (hero.sq.type == STAIR_DOWN)
				new EvFloor(-1);
			var sq = hero.sq;
			if (sq.itemId != null) {
				pickUp(sq.itemId, sq);
			}
		}
		if (allies.length > 0) {
			var sq = cfl.grid[bx][by];
			if (sq.ent == null) {
				var ent = allies.pop();
				ent.setFloor(cfl);
				ent.setPos(bx, by);
				ent.display();
			}
		}

		flMove = false;
		if (event == null) {
			if (food == 0) {
				log([
					"Vous avez tres faim !",
					"Il faut trouver de la nourriture !",
					"Vous avez besoin de manger !",
					"La faim vous terrasse"
				][Seed.randomVfx(4)]);
				hero.hurt(1);
			}
			if (hero.life <= 0)
				initGameOver();
			else
				initPlay();
		}
	}

	// PLAY
	public function initPlay() {
		step = Play;
		hero.setFuturAction(null);
		displayItems(true);
	}

	public function updatePlay() {
		if (KeyboardManager.isDown(KeyboardManager.RIGHT))
			move(0);
		else if (KeyboardManager.isDown(KeyboardManager.DOWN))
			move(1);
		else if (KeyboardManager.isDown(KeyboardManager.LEFT))
			move(2);
		else if (KeyboardManager.isDown(KeyboardManager.UP))
			move(3);
		else if (KeyboardManager.isDown(KeyboardManager.SPACE))
			shoot();
		else
			flShoot = true;
	}

	public function move(dir:Int) {
		var d = Cs.DIR[dir];
		var sq = cfl.getSquare(hero.sq.x + d[0], hero.sq.y + d[1]);
		if (sq == null)
			return;
		if (sq.isHeroFree()) {
			flMove = true;
			hero.setFuturAction(Goto(dir));
			gogogo();
		} else if (sq.ent != null) {
			if (sq.ent.flBad) {
				hero.setFuturAction(Attack(dir));
				gogogo();
			} else if (sq.ent.flGood) {
				flMove = true;
				hero.setFuturAction(Goto(dir));
				var ally:Bad = cast(sq.ent);
				ally.swapDir = (dir + 2) % 4;
				ally.first();
				gogogo();
			} else if (sq.ent.flTrader) {
				new EvTrader();
			}
		}
	}

	public function shoot() {
		if (!flShoot || shuriken <= 0)
			return;
		flShoot = false;
		var trg = hero.getNearestBad(2, 7);

		if (trg != null) {
			incShuriken(-1);
			var ev = new EvShoot(hero, trg, 1 + Seed.random(3));
			if (hero.flFire) {
				ev.dmg++;
				Filt.glow(ev.shot, 4, 4, 0xFFFF00);
				Filt.glow(ev.shot, 8, 2, 0xFFCC00);
			}
		} else {
			log("Aucun monstre a portée de tir !");
		}
	}

	// WORK
	function updateWork() {
		coef = Math.min(coef + Cs.SPEED, 1);
		if (flQueue) {
			work[0].update(coef);
			if (coef == 1) {
				coef = 0;
			}
		} else {
			var list = work.copy();
			for (e in list)
				e.update(coef);
		}

		if (work.length == 0) {
			if (next != null)
				nextTurn();
			else
				initEvents();
		}

		cfl.scroll(hero);
	}

	// NEXT TURN
	public function gogogo() {
		Game.me.hero.first();
		displayItems();
		if (food > 0) {
			food--;
			displayFood();
		}

		next = MAttack;
		coef = 0;
		step = Work;
		active = [];
		for (e in cfl.ents) {
			active.push(e);
		}
		nextTurn();
	}

	function nextTurn() {
		coef = 0;
		switch (next) {
			case MAttack:
				var list = active.copy();
				for (e in list)
					e.checkAttack();
				flQueue = true;
				next = MMove;
				if (work.length == 0)
					nextTurn();
			case MMove:
				var list = active.copy();
				for (e in list)
					e.checkMove();
				flQueue = false;
				next = MEnd;
			case MEnd:
				next = null;
				initEvents();
			case null:
		}
	}

	// ITEM
	public function pickUp(id:Int, ?sq:Square) {
		if (sq != null)
			sq.removeItem();
		switch (id) {
			case 1:
				incGold(1);
			case 2:
				incGold(2 + Seed.random(8));
			case 3:
				incGold(10 + Seed.random(15));
			case 4:
				incGold(50 + Seed.random(50));
			case 5:
				setArmor(1);
				Lang.take(id);
			case 6:
				setArmor(2);
				Lang.take(id);
			case 7:
				setWeapon(1);
				Lang.take(id);
			case 8:
				setWeapon(2);
				Lang.take(id);
			case 9:
				incFood(50);
				Lang.take(id);
			case 10:
				incFood(100);
				Lang.take(id);
			case 11:
				incShuriken(3);
			case 12:
				incShuriken(10);
			case 13:
				bagSize = 5;
				displayItems();
				Lang.take(id);
			case 21:
				gem(id - 21);
			case 22:
				gem(id - 21);
			case 23:
				gem(id - 21);
			default:
				take(id);
		}
	}

	function take(id:Int) {
		Lang.take(id);
		inventory.push(id);
		if (inventory.length > bagSize)
			dropItem(inventory.shift());
		displayItems();
		hero.buildCaracs();
	}

	function useItem(n:Int) {
		var id = inventory[n];

		switch (id) {
			case 14: // POTION
				hero.incLife(8);

			case 15: // BIG POTION
				hero.lifeMax += 2;
				hero.incLife(100);

			case 16: // GRAPPIN
				var fl = getFloor(cfl.id + 1);
				var sq = fl.grid[hero.x][hero.y];
				if (sq.isHeroFree()) {
					new EvFloor(1);
				} else {
					log("Vous ne parvenez pas a accrocher votre grappin !");
					return;
				}

			case 17: // TALISMAN
				var list = [];
				for (bad in cfl.bads)
					if (bad.flUndead)
						list.push(bad);
				if (list.length == 0) {
					log("Il n'y a aucun mort-vivant dans cette zone.");
					return;
				} else {
					log("Vous utilisez votre talisman contre les mort-vivants.");
					fxFlash(0xFFFFFF);
					for (b in list) {
						b.bhMove = BCoward;
						b.bhAtt = BRandom(0.1);
					}
				}

			case 18:
				log("il augmente d'un point vos dégats.");
				return;
			case 19:
				log("il augmente vos chance d'esquive");
				return;
			case 20:
				log("il augmente votre agilité.");
				return;
			case 24:
				log("C'est une patte d'ours blanc porte-bonheur");
				return;
			case 25: // SCROLL FIRE
				var list = hero.getNearBads(1);
				if (list.length == 0) {
					log("Il n'y a aucun ennemis proches de vous.");
					return;
				} else {
					for (ent in list) {
						ent.sq.fxFlame();
						ent.die();
					}
				}

			case 26: // SCROLL ICE
				var trg = hero.getNearestBad(1, 7);
				if (trg == null) {
					log("Il n'y a aucun ennemis proches de vous.");
					return;
				} else {
					var ev = new EvShoot(hero, trg, 0);
					ev.shot.gotoAndStop(2);
					ev.bhl = [1];
				}

			case 27: // BOMB
				new EvBomb();

			case 28: // OREILLER
				if (hero.life >= hero.lifeMax)
					log("Vous êtes déja en pleine forme !!");
				else if (food < 15)
					log("Vous avez trop faim pour dormir...");
				else {
					var flOk = true;
					var ray = 7;
					for (dx in 0...ray * 2 + 1) {
						for (dy in 0...ray * 2 + 1) {
							if (cfl.getBad(hero.x + dx - ray, hero.y + dy - ray) != null) {
								flOk = false;
								break;
							}
						}
					}
					if (!flOk) {
						log("Trop de monstres : c'est pas le moment de dormir !");
					} else {
						hero.sq.fxSleep();
						log("Vous vous endormez pendant une heure...");
						incFood(-10);
						hero.incLife(1);
					}
				}
				return;

			case 29: // TELEPORT
				new EvTeleport();

			case 30: // CHAOS
				var list = hero.getNearBads(6);
				fxFlash(0x8800FF);
				if (list.length > 0) {
					for (b in list)
						b.setChaos();
				} else {
					log("Il n'y a aucun ennemis proches dans les environs.");
					return;
				}

			case 31: // OURS
				var list = hero.getNearFreeList();
				if (list.length > 0) {
					var sq = list[Seed.random(list.length)];
					invoke(20, sq);
				} else {
					log("Il n'y a pas assez d'espace autour de vous !");
					return;
				}
			case 32: // DOG
				var list = hero.getNearFreeList();
				if (list.length > 0) {
					var sq = list[Seed.random(list.length)];
					invoke(21, sq);
				} else {
					log("Il n'y a pas assez d'espace autour de vous !");
					return;
				}

			case 33: // BRACELET
				log("Ce bracelet multiplie votre force par deux !");
				return;

			case 34: // ZIPPO
				log("Il permet d'enflammer vos shuriken !");

			default:
				log("sans effets...");
				return;
		}

		inventory.splice(n, 1);
		displayItems(event == null);
	}

	function gem(id:Int) {
		Lang.take(21 + id);
		hero.sq.fxGem(Cs.COLOR_GEM[id]);

		var sc = Cs.SCORE_GEM[id];
		KadoKadeoManager.kkm.addScore(sc);
		hero.sq.fxScore(sc);
	}

	public function invoke(id:Int, sq:Square) {
		var bad = new Bad(id);
		bad.setFloor(cfl);
		bad.setPos(sq.x, sq.y);
		bad.display();
		sq.fxGem(0xFFAA00);
		sq.fxGem(0xFF0000);
	}

	function dropItem(itemId:Int) {
		hero.sq.addItem(itemId);
		hero.sq.showItem();
	}

	function incGold(inc:Int) {
		if (inc == 1)
			log("Vous rammassez 1 pièce d'or !");
		if (inc > 1)
			log("Vous rammassez " + inc + " pièces d'or !");
		gold += inc;
		displayGold();
	}

	function incFood(inc:Int) {
		food += inc;
		if (food < 0)
			food = 0;
		displayFood();
	}

	function incShuriken(inc:Int) {
		if (inc > 0)
			log("Vous rammassez " + inc + " shurikens !");
		shuriken += inc;
		displayShuriken();
	}

	function setArmor(aid:Int) {
		var id:Null<Int> = null;
		if (armorId == 1)
			id = 5;
		if (armorId == 2)
			id = 6;
		if (id != null)
			dropItem(id);
		armorId = aid;
		hero.buildCaracs();
		hero.display();
	}

	function setWeapon(wid:Int) {
		var id:Null<Int> = null;
		if (weaponId == 1)
			id = 7;
		if (weaponId == 2)
			id = 8;
		if (id != null)
			dropItem(id);
		weaponId = wid;
		hero.buildCaracs();
		hero.display();
	}

	// INTER
	function initInter() {
		mcInter = dm.attach("inter", DP_INTER);
		barLife = mcInter.attachMovie("barLife", "barLife", 1);
		barLife._x = KadoKadeoManager.S(Data.BAR_LIFE[0]);
		barLife._y = KadoKadeoManager.S(Data.BAR_LIFE[1]);
		fieldLife = interText(Data.TEXT_LIFE);
		fieldFood = interText(Data.TEXT_FOOD);
		fieldGold = interText(Data.TEXT_GOLD);
		fieldShuriken = interText(Data.TEXT_SHURIKEN);
	}

	function interText(t:Array<Float>):Text {
		var txt = Txt.make(KadoKadeoManager.S(t[3]), Txt.VERDANA, "left", 0x323879, 4);
		txt.x = KadoKadeoManager.S(t[0]);
		txt.y = KadoKadeoManager.S(t[1]);
		mcInter.addChild(txt);
		return txt;
	}

	public function displayLife() {
		var coef = hero.life / hero.lifeMax;
		barLife._xscale = coef * 100;

		var col = 0x00FF00;
		if (coef < 1)
			col = 0x44DD00;
		if (coef <= 0.5)
			col = 0xFFCC00;
		if (coef <= 0.25)
			col = 0xFF0000;
		Col.setColor(barLife, col);

		fieldLife.text = hero.life + "/" + hero.lifeMax;
	}

	public function displayFood() {
		fieldFood.text = food + "";
	}

	public function displayGold() {
		fieldGold.text = gold + "";
	}

	public function displayShuriken() {
		fieldShuriken.text = shuriken + "";
	}

	public function displayItems(?flAction:Bool) {
		dm.clear(DP_ITEMS);
		slotItems = [];
		slotsAction = flAction == true;
		for (i in 0...bagSize) {
			var slot = dm.attach("mcSlot", DP_ITEMS);
			slot._x = Cs.mcw - KadoKadeoManager.S((bagSize - i) * SLOT);
			slot._y = KadoKadeoManager.S(3);
			var id = inventory[i];
			if (id != null) {
				var mc = dm.attach("mcItem", DP_ITEMS);
				mc._x = slot._x;
				mc._y = slot._y;
				mc.gotoAndStop(id + 1);
				slotItems[i] = mc;
			}
		}
	}

	// slot of the bag under a point of the screen
	function slotAt(mx:Float, my:Float):Null<Int> {
		if (!slotsAction)
			return null;
		var size = KadoKadeoManager.S(27);
		for (i in 0...bagSize) {
			var x0 = Cs.mcw - KadoKadeoManager.S((bagSize - i) * SLOT);
			var y0 = KadoKadeoManager.S(3);
			if (mx >= x0 && mx < x0 + size && my >= y0 && my < y0 + size)
				return i;
		}
		return null;
	}

	function hoverItems(mx:Float, my:Float) {
		var over = slotAt(mx, my);
		for (i in 0...slotItems.length) {
			var mc = slotItems[i];
			if (mc != null)
				mc.blendMode = over == i ? BlendModes.ADD : BlendModes.NORMAL;
		}
	}

	// GameOver
	public function initGameOver() {
		step = GameOver;
		endStep = 0;
		coef = 0;
		log("Vous êtes mort !");
	}

	public function updateGameOver() {
		switch (endStep) {
			case 0:
				coef = Math.min(coef + 0.1, 1);
				if (coef == 1) {
					endStep++;
					if (gold > 0) {
						var a = Cs.SCORE_GOLD;
						log("Bonus Or " + gold + " x" + a + " = " + (a * gold) + "pts");
					}
				}
			case 1:
				if (gold > 0) {
					incGold(-1);
					KadoKadeoManager.kkm.addScore(Cs.SCORE_GOLD);
				} else {
					endStep++;
					if (food > 0) {
						var a = Cs.SCORE_FOOD;
						log("Bonus Nourriture " + food + " x" + a + " = " + (a * food) + "pts");
					}
				}
			case 2:
				if (food > 0) {
					for (i in 0...5) {
						incFood(-1);
						KadoKadeoManager.kkm.addScore(Cs.SCORE_FOOD);
						if (food == 0)
							break;
					}
				} else {
					endStep++;
					KadoKadeoManager.kkm.gameOver({});
				}
		}
	}

	// FX
	public function updateFlash() {
		var prc = flh;
		flh *= 0.6;
		if (flh < 0.1) {
			flh = null;
			prc = 0;
		}
		Col.setPercentColor(root, prc, flhColor);
	}

	public function fxFlash(col:Int) {
		flhColor = col;
		flh = 100;
	}

	// LOG
	public function log(str:String) {
		if (flMute)
			return;
		if (mcLog == null) {
			mcLog = dm.empty(DP_INTER);
		}

		var mc = mcLog.createEmptyMovieClip("log", 1);
		var t = Txt.make(KadoKadeoManager.S(Data.TEXT_LOG[3]), Txt.VERDANA, "left", 0x000000, 5);
		t.x = KadoKadeoManager.S(Data.TEXT_LOG[0]);
		t.y = KadoKadeoManager.S(Data.TEXT_LOG[1]);
		t.text = str;
		mc.addChild(t);
		mc._y = Cs.mch;
		logs.unshift(mc);
		logCoef = 0;

		logTimer = 60;
		mcLog._alpha = 100;
	}

	public function updateLog() {
		logCoef = Math.min(logCoef + 0.2, 1);

		var lim = 5;
		var ec = KadoKadeoManager.S(12);
		for (i in 0...logs.length) {
			var mc = logs[i];
			mc._y = Cs.mch - ((i + logCoef) * ec + KadoKadeoManager.S(5));
			mc._alpha = Math.min(100, 100 - ((i + logCoef - 1) / (lim - 1)) * 100);
		}

		if (logCoef == 1) {
			while (logs.length >= lim)
				logs.pop().removeMovieClip();
			logCoef = null;
		}
	}

	public function updateLogAlpha() {
		if (logTimer > 0)
			logTimer--;
		else
			mcLog._alpha -= 10;
		if (mcLog._alpha <= 0) {
			while (logs.length > 0)
				logs.pop().removeMovieClip();
		}
	}

	#if debug
	// test hook of the harness (debug builds only): opens the trader's shop, recorded like a click so that the
	// replay does the same
	@:keep public function debugOpenShop() {
		if (step == Play)
			recordAndApply(EV_DEBUG_SHOP, 0);
	}
	#end

	public function destroy():Void {
		KadoKadeoManager.kkm.setTouchJoystickEnabled(true);
		me = null;
	}
}
