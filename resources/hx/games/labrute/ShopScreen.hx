package labrute;

import pixi.core.display.Container;
import pixi.core.graphics.Graphics;
import labrute.Screen;
import labrute.view.Actors;
import labrute.view.Ui;
import labrute.view.V8;

// Phase 1: the shop. Its weapons (top left) and skills (bottom left), every one of the game, the ones of the brute in
// color with the frame of their tier (a click takes them to the next one); the brute, its HP in a heart and its stats
// in boxes, their purchase (top right); its pets and the button of the fight (bottom right).
class ShopScreen extends Screen {
	static var STAT_NAMES = ["Points de vie", "Force", "Agilité", "Rapidité"];
	static var STAT_COLORS = [Col.HP, Col.STRENGTH, Col.AGILITY, Col.SPEED];
	// (their icons in the skin)
	public static var STAT_KEYS = ["hp", "strength", "agility", "speed"];
	static var PET_ORDER = ["dog1", "dog2", "dog3", "panther", "bear"];
	// the middle of the elements of the top band (the shop, the choice)
	public static inline var TOP_Y = 25;
	// the gap between the gold and the ears of the top bar
	static inline var TOP_EARS_GAP = 14;
	// the top left corner of each block: the brute and its stats, the skills, the weapons, the pets
	static inline var STATS_X = 8;
	static inline var STATS_Y = 45;
	static inline var SKILLS_X = 312;
	static inline var SKILLS_Y = 56;
	// the board of the weapons (the picture `panel-weapons` of the skin, BOARD_W × BOARD_H): its top left corner, its
	// scale
	// (centered on the left part of the shop, LEFT_MID)
	static inline var LEFT_MID = 155;
	static inline var BOARD_X = LEFT_MID - BOARD_W * BOARD_SCALE / 2 - 5;
	static inline var BOARD_Y = 233;
	static inline var BOARD_SCALE = 0.85;
	static inline var BOARD_W = 311;
	static inline var BOARD_H = 210;
	// the weapons on the board (the pictures `weapon-…` of the skin), in the order they are drawn: the matrix
	// [a, b, c, d, tx, ty] of each one in the board (its drawing from its point (0, 0), its size w × h), moved by
	// WEAPONS_DX, WEAPONS_DY
	static inline var WEAPONS_DX = 5.2;
	static inline var WEAPONS_DY = 2.5;
	static var WEAPON_PLACES:Array<{
		name:String,
		m:Array<Float>,
		w:Float,
		h:Float
	}> = [
		{
			name: "sai",
			m: [1.0, 0.0, 0.0, 1.0, 195.0, 173.45],
			w: 60.6,
			h: 26.2
		},
		{
			name: "lance",
			m: [0.7269, 0.0, 0.0, 0.7269, 7.3798, 4.886],
			w: 14.8,
			h: 163.3
		},
		{
			name: "shuriken",
			m: [1.7143, 0.0, 0.0, 1.7143, 152.0914, 49.0489],
			w: 17.1,
			h: 15.35
		},
		{
			name: "hatchet",
			m: [0.7269, 0.0, 0.0, 0.7269, 123.1949, 10.7539],
			w: 77.15,
			h: 45.1
		},
		{
			name: "knife",
			m: [0.7269, 0.0, 0.0, 0.7269, 38.091, 4.4059],
			w: 55.6,
			h: 8.1
		},
		{
			name: "axe",
			m: [0.0, 0.7269, -0.7269, 0.0, 249.2428, 1.416],
			w: 71.75,
			h: 43.15
		},
		{
			name: "baton",
			m: [0.7269, 0.0, 0.0, 0.7269, 124.7055, 2.028],
			w: 116.55,
			h: 4.6
		},
		{
			name: "broadsword",
			m: [0.5771, -0.4402, 0.4402, 0.5771, 56.7885, 26.853],
			w: 81.15,
			h: 41.3
		},
		{
			name: "bumps",
			m: [0.1616, -0.8678, 0.8678, 0.1616, 171.0511, 79.6175],
			w: 83.45,
			h: 39.05
		},
		{
			name: "fan",
			m: [0.7269, 0.0, 0.0, 0.7269, 25.335, 19.3693],
			w: 48.65,
			h: 43.15
		},
		{
			name: "flail",
			m: [0.8995, 0.036, -0.036, 0.8995, 100.7669, 78.2476],
			w: 59.2,
			h: 56.45
		},
		{
			name: "fryingPan",
			m: [-0.279, 1.0412, -1.0412, -0.279, 299.6064, 120.4467],
			w: 70.4,
			h: 42.05
		},
		{
			name: "halbard",
			m: [-0.8949, -0.0958, 0.0958, -0.8949, 191.4224, 209.3746],
			w: 204.7,
			h: 34.0
		},
		{
			name: "keyboard",
			m: [1.7112, -0.2186, 0.2186, 1.7112, 22.7598, 134.7653],
			w: 33.3,
			h: 13.35
		},
		{
			name: "leek",
			m: [0.9007, 0.0, 0.0, 0.9007, 142.5953, 87.5244],
			w: 44.2,
			h: 61.95
		},
		{
			name: "mammothBone",
			m: [-0.5487, 0.7138, -0.7138, -0.5487, 300.3664, 67.016],
			w: 74.05,
			h: 27.35
		},
		{
			name: "morningStar",
			m: [0.3003, -0.8478, 0.8478, 0.3003, 14.9775, 93.1636],
			w: 42.2,
			h: 87.5
		},
		{
			name: "mug",
			m: [0.9007, 0.0, 0.0, 0.9007, 238.6467, 59.0669],
			w: 25.15,
			h: 24.5
		},
		{
			name: "noodleBowl",
			m: [1.0, 0.0, 0.0, 1.0, 169.65, 145.15],
			w: 36.2,
			h: 27.0
		},
		{
			name: "piopio",
			m: [-0.4374, -0.7859, 0.7859, -0.4374, 91.6181, 90.0935],
			w: 23.55,
			h: 24.85
		},
		{
			name: "racquet",
			m: [1.0, 0.0, 0.0, 1.0, 92.2, 123.2],
			w: 69.3,
			h: 40.0
		},
		{
			name: "scimitar",
			m: [0.514, -0.514, 0.514, 0.514, 61.7086, 72.2334],
			w: 101.15,
			h: 22.9
		},
		{
			name: "sword",
			m: [0.7269, 0.0, 0.0, 0.7269, 22.7385, 105.4265],
			w: 122.05,
			h: 22.5
		},
		{
			name: "trident",
			m: [-0.4643, -0.4643, 0.4643, -0.4643, 193.6863, 134.9724],
			w: 176.35,
			h: 40.4
		},
		{
			name: "trombone",
			m: [1.451, 0.0, 0.0, 1.5608, 204.7837, 76.2753],
			w: 26.3,
			h: 57.0
		},
		{
			name: "whip",
			m: [0.2331, -0.87, 0.87, 0.2331, 250.3412, 51.5226],
			w: 62.5,
			h: 31.7
		},
		];
	// the bare hands (`weapon-bare-hands`), under the others: always there, not upgraded
	static var BARE_HANDS = {m: [0.25, 0.0, 0.0, 0.25, 2.2, 178.0], w: 64.0, h: 94.0};
	// its black outline (pixels)
	static inline var BARE_HANDS_OUTLINE = 1;
	// the alpha of a weapon not owned
	static inline var WEAPON_MISSING_ALPHA = 0.3;
	// the button « Nouvelle arme »: its middle
	static inline var NEW_WEAPON_X = BOARD_X + BOARD_W * BOARD_SCALE / 2;
	static inline var NEW_WEAPON_Y = 437;
	// the place of each pet (its box: the picture fitted in it)
	static var PET_SLOTS:Map<String, {
		x:Float,
		y:Float,
		w:Float,
		h:Float
	}> = [
		"dog1" => {
			x: 312,
			y: 268,
			w: 56,
			h: 56
		},
		"dog2" => {
			x: 370,
			y: 268,
			w: 56,
			h: 56
		},
		"dog3" => {
			x: 428,
			y: 268,
			w: 56,
			h: 56
		},
		"panther" => {
			x: 312,
			y: 328,
			w: 172,
			h: 66
		},
		"bear" => {
			x: 490,
			y: 264,
			w: 100,
			h: 130
		}
		];
	// the outlines of the shop (pixels): at tiers 2 and 3, the black then the color of the tier around it; at tier 1,
	// the black only
	static inline var WEAPON_BLACK = 1;
	static inline var WEAPON_RING = 2;
	static inline var WEAPON_TIER1 = 1;
	static inline var PET_BLACK = 1;
	static inline var PET_RING = 3;
	static inline var PET_TIER1 = 1;
	// the buttons « Nouvelle arme » and « Nouvelle compétence » (their text keeps its size), centered under their grid
	static inline var NEW_W = 168 * 1.15;
	static inline var NEW_H = 38 * 1.15;
	// the button of the fight (the picture `fight` of the skin carries its text; its proportions kept: 166 × 55 for
	// 218 × 72)
	static inline var FIGHT_X = 425;
	static inline var FIGHT_Y = 402;
	static inline var FIGHT_W = 166;
	static inline var FIGHT_H = 55;
	// the banner of the last purchase (the picture `notif-banner` of the skin, NOTIF_W × NOTIF_H, its shadow under it:
	// the frame of the results of the fights of LaBrute): from the box of « Nouvelle arme » to the one of the fight,
	// NOTIF_BODY high (its shadow under it) centered on « Nouvelle arme »; its box of texts narrowed to fit (the picture
	// cut in three: its left part to the end of the separator and its NOTIF_END last pixels kept, the middle squeezed);
	// in the picture, the box of the icon and the box of the texts
	static inline var NOTIF_W = 375;
	static inline var NOTIF_H = 82;
	static inline var NOTIF_SHADOW = 8;
	static inline var NOTIF_BODY = 38;
	// (moved from the middle of « Nouvelle arme », its texts from the middle of their box)
	static inline var NOTIF_DY = -2;
	static inline var NOTIF_TEXT_DY = -1;
	static inline var NOTIF_END = 8;
	static var NOTIF_ICON = {
		x: 3,
		y: 3,
		w: 72,
		h: 69
	};
	static var NOTIF_TEXT = {
		x: 78,
		y: 3,
		w: 294,
		h: 69
	};
	// (the icon: its share of its box, the long weapons turned along its diagonal)
	static inline var NOTIF_ICON_FILL = 0.8;
	static inline var NOTIF_LONG = 2;
	// the frames it stays, the frames it fades at its end
	static inline var NOTIF_FRAMES = 80;
	static inline var NOTIF_FADE = 20;
	// the brute (its feet), from the corner of the stats
	static inline var BRUTE_X = STATS_X + 48;
	static inline var BRUTE_Y = STATS_Y + 132;

	var dirty = true;
	// the pictures of the skin when the screen was made
	var skinEpoch = -1;
	var holder:V8FighterHolder;
	var holderReady = false;
	var holderShield = false;
	var speed:Dynamic = {current: 1.0};
	var toast:Container;

	public function new(game:Game) {
		super(game);
	}

	var run(get, never):Run;

	inline function get_run():Run {
		return game.run;
	}

	// ---------------------------------------------------------------- gameplay

	override public function apply(action:Int):Void {
		var b = run.brute;
		if (action >= A.STAT && action < A.STAT + 4) {
			var i = action - A.STAT;
			var price = Balance.statPrice(run.statsBought[i]);
			if (run.gold < price)
				return;
			run.gold -= price;
			run.statsBought[i]++;
			switch (i) {
				case 0:
					b.hpStat += Balance.HP_PER_BUY;
				case 1:
					b.strengthStat += Balance.STAT_PER_BUY;
				case 2:
					b.agilityStat += Balance.STAT_PER_BUY;
				default:
					b.speedStat += Balance.STAT_PER_BUY;
			}
			b.recompute();
		} else if (action == A.NEW_WEAPON || action == A.NEW_SKILL) {
			var weapon = action == A.NEW_WEAPON;
			var types = weapon ? ["weapon"] : ["pet", "skill"];
			var price = weapon ? Balance.weaponPrice(run.weaponsBought) : Balance.skillPrice(run.skillsBought);
			if (run.gold < price || !Brute.canGetNew(b, types))
				return;
			var perk = Brute.randomBonus(b, types, true, true);
			if (perk == null)
				return;
			run.gold -= price;
			if (weapon)
				run.weaponsBought++;
			else
				run.skillsBought++;
			b.addPerk(perk.type, perk.name);
			run.lastGain = perk.type;
			run.lastGainName = perk.name;
			run.lastGainTier = 1;
			run.lastGainFrame = game.frame;
		} else if (action >= A.UP_WEAPON && action < A.UP_WEAPON + 100) {
			upgrade("weapon", b.weapons, action - A.UP_WEAPON);
		} else if (action >= A.UP_SKILL && action < A.UP_SKILL + 100) {
			upgrade("skill", b.skills, action - A.UP_SKILL);
		} else if (action >= A.UP_PET && action < A.UP_PET + 100) {
			upgrade("pet", b.pets, action - A.UP_PET);
		} else if (action == A.FIGHT) {
			if (run.opponents == null)
				run.makeOpponents();
			game.show(new ChoiceScreen(game));
			return;
		}
		dirty = true;
	}

	// the price of the next tier of a perk: from the price of a new weapon (the weapons) or of a new skill (the skills,
	// the pets)
	function upgradePrice(type:String, tier:Int):Int {
		return Balance.upgradePrice(tier, type == "weapon" ? Balance.weaponPrice(run.weaponsBought) : Balance.skillPrice(run.skillsBought));
	}

	function upgrade(type:String, list:Array<Brute.Perk>, index:Int):Void {
		var p = list[index];
		if (p == null || p.tier >= 3)
			return;
		var price = upgradePrice(type, p.tier);
		var ears = Balance.TIER_EARS[p.tier + 1];
		if (run.gold < price || run.ears < ears)
			return;
		if (run.brute.upgrade(type, index)) {
			run.gold -= price;
			run.ears -= ears;
			run.lastGain = type;
			run.lastGainName = p.name;
			run.lastGainTier = p.tier;
			run.lastGainFrame = game.frame;
		}
	}

	// ---------------------------------------------------------------- pictures

	override public function render(t:Float, mx:Float, my:Float, live:Bool):Void {
		if (dirty || skinEpoch != Skin.epoch + Lang.epoch) {
			dirty = false;
			skinEpoch = Skin.epoch + Lang.epoch;
			build();
		}
		drawBrute();
		super.render(t, mx, my, live);
		if (toast != null) {
			var age = game.frame - run.lastGainFrame;
			toast.visible = age < NOTIF_FRAMES && run.lastGain != null;
			toast.alpha = age < NOTIF_FRAMES - NOTIF_FADE ? 1 : (NOTIF_FRAMES - age) / NOTIF_FADE;
		}
	}

	function drawBrute():Void {
		var actors = game.actors;
		var b = run.brute;
		var shield = b.hasSkill("shield");
		if (holder != null && holderShield != shield) {
			actors.release(holder);
			holder = null;
		}
		if (holder == null && actors.ready) {
			holder = actors.holder(Actors.bruteLook(b, 0, shield), speed, 1.3);
			holderShield = shield;
			holderReady = false;
			if (holder != null) {
				holder.container.x = BRUTE_X;
				holder.container.y = BRUTE_Y;
				actors.root.addChild(holder.container);
			}
		}
		if (holder != null && !holderReady && holder.loaded) {
			holderReady = true;
			holder.setAnimation("idle");
		}
	}

	// the gold (in the middle), the league and the wins toward the next one (on the right): the top of the shop and of
	// the choice of the opponent
	public static function topBar(screen:Screen, run:Run, title:String):Void {
		// (the pictures of the skin only: nothing drawn in place of a missing one)
		Skin.box(screen.back, "topbar", 0, 0, 600, 44);
		// (the middle of its elements)
		var cy = TOP_Y;
		if (title != null)
			Ui.title(Ui.label(screen.front, title, 14, cy, 20, Col.PARCHMENT, 0, 0.5, Col.INK));
		// (the gold then the ears, together in the middle)
		var row = new Container();
		screen.front.addChild(row);
		var goldW = Ui.gold(row, 0, cy, Ui.num(run.gold), 21, Col.GOLD, Col.INK, 0, Ui.TITLE);
		var earsW = Ui.ears(row, goldW + TOP_EARS_GAP, cy, Std.string(run.ears), 21, Col.GOLD, Col.INK, 0, Ui.TITLE);
		row.x = Math.round(300 - (goldW + TOP_EARS_GAP + earsW) / 2);
		Ui.medal(screen.front, 569, cy - 3, run.league(), 15);
		var progress = run.leagueProgress();
		if (progress >= 0) {
			var pg = new Graphics();
			Ui.progress(pg, 505, cy - 10, progress, Balance.WINS_PER_LEAGUE, 12, 20);
			screen.front.addChild(pg);
			Skin.icon(screen.front, "ranking", 490, cy, 22, 20);
		}
	}

	function build():Void {
		clearUi();
		var b = run.brute;

		// the background
		Skin.box(back, "background", 0, 0, 600, 460);
		topBar(this, run, Lang.t("BOUTIQUE"));

		var tiles = new Graphics();
		front.addChild(tiles);
		var icons = new Container();
		front.addChild(icons);

		// ---- bottom left: every weapon of the game on its board (the pictures of the skin only), a new one
		Skin.box(back, "panel-weapons", BOARD_X, BOARD_Y, BOARD_W * BOARD_SCALE, BOARD_H * BOARD_SCALE);
		var board = [
			BOARD_SCALE,
			0.0,
			0.0,
			BOARD_SCALE,
			BOARD_X + WEAPONS_DX * BOARD_SCALE,
			BOARD_Y + WEAPONS_DY * BOARD_SCALE
		];
		var hands = Ui.mul(board, BARE_HANDS.m);
		Ui.tierOutlinedAt(icons, Skin.tex("weapon-bare-hands"), Skin.matrix("weapon-bare-hands", hands), 1, 0, 0, BARE_HANDS_OUTLINE);
		for (p in WEAPON_PLACES) {
			var index = indexOf(b.weapons, p.name);
			var tier = index < 0 ? 0 : b.weapons[index].tier;
			// (no frame: the outline of its tier)
			Ui.tierOutlinedAt(icons, Skin.tex("weapon-" + p.name), Skin.matrix("weapon-" + p.name, Ui.mul(board, p.m)), tier, WEAPON_BLACK, WEAPON_RING,
				WEAPON_TIER1, tier > 0 ? 1 : WEAPON_MISSING_ALPHA);
		}
		// (their tooltips, their clicks: the biggest first, a small one over a big one wins; the bare hands last)
		var places = WEAPON_PLACES.copy();
		places.sort((p, q) -> Reflect.compare(q.w * q.h * area(q.m), p.w * p.h * area(p.m)));
		for (p in places) {
			var index = indexOf(b.weapons, p.name);
			var tier = index < 0 ? 0 : b.weapons[index].tier;
			perk(0, 0, p.w, p.h, "weapon", A.UP_WEAPON, index, tier, p.name,
				() -> Describe.weapon(p.name, tier, run.gold, tier > 0 ? upgradePrice("weapon", tier) : -1), Ui.mul(board, p.m));
		}
		tips.push({
			x: 0,
			y: 0,
			w: BARE_HANDS.w,
			h: BARE_HANDS.h,
			m: hands,
			key: "bareHands",
			make: Describe.bareHands
		});
		var weaponPrice = Balance.weaponPrice(run.weaponsBought);
		var bw = new Button(front, NEW_WEAPON_X
			- NEW_W / 2, NEW_WEAPON_Y
			- NEW_H / 2, NEW_W, NEW_H, Lang.t("Nouvelle arme"), A.NEW_WEAPON, Col.RED, 14,
			weaponPrice
			+ " or");
		bw.setEnabled(run.gold >= weaponPrice && Brute.canGetNew(b, ["weapon"]));
		buttons.push(bw);

		// ---- top right: every skill, a new one (or a pet)
		for (i in 0...Data.SKILLS.length) {
			var s = Data.SKILLS[i];
			var x = SKILLS_X + (i % 10) * 27.2;
			var y = SKILLS_Y + Std.int(i / 10) * 27;
			var index = indexOf(b.skills, s.name);
			var tier = index < 0 ? 0 : b.skills[index].tier;
			// (no frame: the picture of its tier has its color)
			var icon = Sheets.fit(Sheets.sprite("tier-" + (tier > 0 ? tier : 1) + "/" + s.name + ".png"), 25, 25);
			icon.x = x + 12.5;
			icon.y = y + 12.5;
			icon.alpha = tier == 0 ? 0.3 : 1;
			icons.addChild(icon);
			perk(x, y, 25, 25, "skill", A.UP_SKILL, index, tier, s.name,
				() -> Describe.skill(s.name, tier, run.gold, tier > 0 ? upgradePrice("skill", tier) : -1));
		}
		var skillPrice = Balance.skillPrice(run.skillsBought);
		var bs = new Button(front, SKILLS_X
			+ 135
			- NEW_W / 2, SKILLS_Y
			+ 187
			- NEW_H / 2, NEW_W, NEW_H, Lang.t("Nouvelle compétence"), A.NEW_SKILL, Col.RED, 14,
			skillPrice
			+ " or");
		bs.setEnabled(run.gold >= skillPrice && Brute.canGetNew(b, ["pet", "skill"]));
		buttons.push(bs);

		// ---- top left: the brute (its shadow under its feet), its HP in a heart, its stats in boxes, their purchase
		var floorG = new Graphics();
		floorG.beginFill(0x000000, 0.12);
		floorG.drawEllipse(BRUTE_X, BRUTE_Y, 40, 7);
		floorG.endFill();
		back.addChild(floorG);
		var values = [b.hpValue, b.strengthValue, b.agilityValue, b.speedValue];
		var boxes = new Graphics();
		front.addChild(boxes);
		for (i in 0...4) {
			var price = Balance.statPrice(run.statsBought[i]);
			var gain = i == 0 ? "+" + Balance.HP_PER_BUY : "+" + Balance.STAT_PER_BUY;
			var y = STATS_Y + (i == 0 ? 10 : 8 + i * 44);
			var sx = STATS_X + 100;
			if (i == 0) {
				Ui.heartValue(front, STATS_X + 118, y + 18, 40, values[0]);
				Ui.label(front, Lang.t(STAT_NAMES[0]), STATS_X + 142, y + 18, 13, STAT_COLORS[0], 0, 0.5, -1, true);
			} else {
				var left = Ui.statIcon(front, STAT_KEYS[i], sx, y + 8) != null ? sx + 17 : sx;
				Ui.label(front, Lang.t(STAT_NAMES[i]) + Lang.t(" : ") + values[i], left, y, 13, STAT_COLORS[i], 0, 0, -1, true);
				Ui.statBoxes(boxes, sx, y + 17, values[i], 12, 20, 2);
			}
			var btn = new Button(front, STATS_X + 242, y, 42, 37, gain, A.STAT + i, Col.GREEN, 13, price + " or", "button-square");
			btn.setEnabled(run.gold >= price);
			buttons.push(btn);
		}

		// ---- bottom right: its pets, the fight
		// (each one in its own place, the picture fitted in it: the dogs in a row, the panther under them, the bear on
		// the right; no frame: the outline PET_BLACK, PET_RING, PET_TIER1)
		for (name in PET_ORDER) {
			var index = indexOf(b.pets, name);
			if (index < 0)
				continue;
			var tier = b.pets[index].tier;
			var r = PET_SLOTS.get(name);
			Ui.tierOutlined(icons, Skin.pet(name), r.x + r.w / 2, r.y + r.h / 2, r.w - 4, r.h - 4, tier, PET_BLACK, PET_RING, PET_TIER1);
			perk(r.x, r.y, r.w, r.h, "pet", A.UP_PET, index, tier, name, () -> Describe.pet(name, tier, b, run.gold, upgradePrice("pet", tier)));
		}

		// (the icons do not move until the screen is made again: drawn once into a picture, not their outlines (filters)
		// at each frame)
		icons.cacheAsBitmap = true;

		var fight = new Button(front, FIGHT_X, FIGHT_Y, FIGHT_W, FIGHT_H, Skin.has("fight") ? "" : "ARENA", A.FIGHT, Col.RED, 22, null, "fight");
		buttons.push(fight);

		// the last purchase, on its banner for NOTIF_FRAMES
		toast = new Container();
		toast.visible = false;
		front.addChild(toast);
		if (run.lastGain != null)
			notification(toast, run.lastGain, run.lastGainName, run.lastGainTier);
	}

	// the banner of a perk bought (tier 1) or upgraded: its icon on the left (its tier: the icon of a skill, the outline
	// of a weapon or a pet as in the shop), what happened and its name on the right
	function notification(parent:Container, type:String, name:String, tier:Int):Void {
		var s = NOTIF_BODY / (NOTIF_H - NOTIF_SHADOW);
		var left = NEW_WEAPON_X + NEW_W / 2;
		var right = FIGHT_X;
		var top = NEW_WEAPON_Y - NOTIF_BODY / 2 + NOTIF_DY;
		// (the end of its left part in the picture: the separator)
		var cut = NOTIF_TEXT.x;
		var middle = right - left - (cut + NOTIF_END) * s;
		if (Skin.has("notif-banner")) {
			var tex = Skin.tex("notif-banner");
			var f = tex.frame;
			// (its pixels by pixel of NOTIF_W: a picture made bigger)
			var k = f.width / NOTIF_W;
			for (part in [
				{
					from: 0.0,
					w: cut,
					x: left,
					dw: cut * s
				},
				{
					from: cut,
					w: NOTIF_W - cut - NOTIF_END,
					x: left + cut * s,
					dw: middle
				},
				{
					from: NOTIF_W - NOTIF_END,
					w: NOTIF_END,
					x: right - NOTIF_END * s,
					dw: NOTIF_END * s
				}
			]) {
				var frame = new pixi.core.math.shapes.Rectangle(f.x + part.from * k, f.y, part.w * k, f.height);
				var pic = new pixi.core.sprites.Sprite(new pixi.core.textures.Texture(tex.baseTexture, frame));
				pic.x = part.x;
				pic.y = top;
				pic.width = part.dw;
				pic.height = NOTIF_H * s;
				parent.addChild(pic);
			}
		} else {
			// (without its picture: its two green boxes, their dark outline)
			var g = new Graphics();
			g.lineStyle(3 * s, 0x6B5040, 1, 0);
			g.beginFill(0xACD15A, 1);
			g.drawRoundedRect(left, top, right - left, NOTIF_BODY, 6 * s);
			g.endFill();
			g.lineStyle(0, 0, 0);
			g.beginFill(0xCDE58E, 1);
			g.drawRect(left + NOTIF_ICON.x * s, top + NOTIF_ICON.y * s, NOTIF_ICON.w * s, NOTIF_ICON.h * s);
			g.endFill();
			parent.addChild(g);
		}
		// the icon
		var cx = left + (NOTIF_ICON.x + NOTIF_ICON.w / 2) * s;
		var cy = top + (NOTIF_ICON.y + NOTIF_ICON.h / 2) * s;
		var size = Math.min(NOTIF_ICON.w, NOTIF_ICON.h) * s * NOTIF_ICON_FILL;
		switch (type) {
			case "weapon":
				weaponIcon(parent, name, tier, cx, cy, size);
			case "pet":
				Ui.tierOutlined(parent, Skin.pet(name), cx, cy, size, size, tier, PET_BLACK, PET_RING, PET_TIER1);
			default:
				var icon = Sheets.fit(Sheets.sprite("tier-" + tier + "/" + name + ".png"), size, size);
				icon.anchor.set(0.5, 0.5);
				icon.x = cx;
				icon.y = cy;
				parent.addChild(icon);
		}
		// the texts: what happened, the name in bold (smaller when it is too long)
		var what = tier > 1 ? Lang.f("Niveau {0} !", [tier]) : Lang.t(switch (type) {
			case "weapon": "Nouvelle arme !";
			case "pet": "Nouvel animal !";
			default: "Nouvelle compétence !";
		});
		var label = type == "weapon" ? Data.weapon(name).label : type == "pet" ? Data.pet(name).label : Data.skill(name).label;
		var textLeft = left + NOTIF_TEXT.x * s;
		var textRight = right - (NOTIF_W - NOTIF_TEXT.x - NOTIF_TEXT.w) * s;
		var tx = (textLeft + textRight) / 2;
		var tw = textRight - textLeft - 6;
		var mid = top + (NOTIF_TEXT.y + NOTIF_TEXT.h / 2) * s + NOTIF_TEXT_DY;
		var t1 = Ui.label(parent, what, tx, mid - 1, 10, Col.WOOD, 0.5, 1);
		var t2 = Ui.label(parent, label, tx, mid, 13, Col.INK, 0.5, 0, -1, true);
		for (t in [t1, t2])
			if (t.width > tw)
				t.scale.set(tw / t.width, tw / t.width);
	}

	// a weapon in a square of `size` centered on cx, cy, with the outline of the board (its tier): its horizontal picture
	// of the skin, else the one of the board, else the one of the game; a long one turned along the diagonal
	function weaponIcon(parent:Container, name:String, tier:Int, cx:Float, cy:Float, size:Float):Void {
		var tex = Skin.has("weapon-tip-" + name) ? Skin.tex("weapon-tip-" + name) : Skin.has("weapon-" + name) ? Skin.tex("weapon-" +
			name) : Sheets.tex("weapons/"
			+ name + ".png");
		var tw = tex.width;
		var th = tex.height;
		var a = tw > th * NOTIF_LONG ? -Math.PI / 4 : 0.0;
		var cos = Math.cos(a);
		var sin = Math.sin(a);
		var k = Math.min(size / (tw * Math.abs(cos) + th * Math.abs(sin)), size / (tw * Math.abs(sin) + th * Math.abs(cos)));
		var m = [k * cos, k * sin, -k * sin, k * cos, 0.0, 0.0];
		m[4] = cx - (m[0] * tw + m[2] * th) / 2;
		m[5] = cy - (m[1] * tw + m[3] * th) / 2;
		Ui.tierOutlinedAt(parent, tex, m, tier, WEAPON_BLACK, WEAPON_RING, WEAPON_TIER1);
	}

	static function indexOf(list:Array<Brute.Perk>, name:String):Int {
		for (i in 0...list.length)
			if (list[i].name == name)
				return i;
		return -1;
	}

	// the scale of the areas of a matrix
	static inline function area(m:Array<Float>):Float {
		return Math.abs(m[0] * m[3] - m[1] * m[2]);
	}

	// a perk of the game: its tooltip; owned, a click takes it to its next tier (not owned, its zone only hides the ones
	// under it); m: its box turned (a weapon of the board)
	function perk(x:Float, y:Float, w:Float, h:Float, type:String, action:Int, index:Int, tier:Int, name:String, make:Void->TipBox, ?m:Array<Float>):Void {
		var gold = run.gold;
		var ears = run.ears;
		tips.push({
			x: x,
			y: y,
			w: w,
			h: h,
			m: m,
			key: type + name + tier + "/" + gold + "/" + ears,
			make: make
		});
		zones.push({
			x: x,
			y: y,
			w: w,
			h: h,
			m: m,
			action: index < 0 ? -1 : action + index,
			enabled: index >= 0 && tier < 3 && gold >= upgradePrice(type, tier) && ears >= Balance.TIER_EARS[tier + 1]
		});
	}

	override public function destroy():Void {
		game.actors.release(holder);
		holder = null;
		super.destroy();
	}
}
