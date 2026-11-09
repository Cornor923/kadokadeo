package labrute;

import pixi.core.graphics.Graphics;
import labrute.Data;
import labrute.Screen;
import labrute.view.Actors;
import labrute.view.Ui;
import labrute.view.V8;

// Phase 2: the choice of the opponent. Three brutes (easy, medium, hard) with their HP and stats, how many weapons,
// passive skills and supers they have (not which), their pets and the reward of a win.
class ChoiceScreen extends Screen {
	static var LEVELS = ["FACILE", "MOYEN", "DIFFICILE"];
	static var LEVEL_COLORS = [Col.GREEN, Col.ORANGE, Col.RED];
	// the outline of the difficulty around a card (its width, its opacity, its corners)
	static inline var OUTLINE_W = 4;
	static inline var OUTLINE_ALPHA = 0.9;
	static inline var OUTLINE_RADIUS = 8;
	// how much the colored outline goes further left than the card
	static inline var OUTLINE_LEFT = 2;
	// the brute: its scale, its feet; the stats: their scale, their top; the thin lines before them and after the pets
	static inline var BRUTE_SCALE = 1.1;
	static inline var BRUTE_Y = 184;
	static inline var STATS_SCALE = 1.2;
	static inline var STATS_Y = 202;
	// the heart of the HP: its scale, its middle from the left of the card
	static inline var HEART_SCALE = 1.1;
	static inline var HEART_X = 35;
	// the distance between the middles of two pets
	static inline var PET_STEP = 32;
	// their black outline (pixels)
	static inline var PET_OUTLINE = 1;
	static inline var SEP_STATS_Y = 197;
	static inline var SEP_PETS_Y = 342;
	// the turn of the broadsword of the number of weapons (degrees, clockwise)
	static inline var SWORD_ANGLE = 0;

	// the pictures of the skin when the screen was made
	var skinEpoch = -1;
	var holders:Array<V8FighterHolder> = [null, null, null];
	var holderReady:Array<Bool> = [false, false, false];
	// the frame each one was made (the next one waits for it at most HOLDER_WAIT frames: one that never loads)
	var holderFrame:Array<Int> = [0, 0, 0];
	static inline var HOLDER_WAIT = 60;
	var speed:Dynamic = {current: 1.0};

	public function new(game:Game) {
		super(game);
	}

	override public function apply(action:Int):Void {
		if (action >= A.PICK && action < A.PICK + 3) {
			var i = action - A.PICK;
			game.show(new FightScreen(game, game.run.opponents[i], i));
		}
	}

	override public function render(t:Float, mx:Float, my:Float, live:Bool):Void {
		if (skinEpoch != Skin.epoch + Lang.epoch) {
			skinEpoch = Skin.epoch + Lang.epoch;
			clearUi();
			build();
		}
		var actors = game.actors;
		// (one after the other: the pictures of a new look take long to make, the game is not frozen for the three)
		var waiting = false;
		for (i in 0...3) {
			var o = game.run.opponents[i];
			if (holders[i] == null && actors.ready && !waiting) {
				var h = actors.holder(Actors.bruteLook(o, 1, false, true), speed, BRUTE_SCALE);
				if (h != null) {
					h.container.x = 10 + i * 197 + 93;
					h.container.y = BRUTE_Y;
					actors.root.addChild(h.container);
					holders[i] = h;
					holderFrame[i] = game.frame;
				}
			}
			if (holders[i] != null && !holderReady[i] && holders[i].loaded) {
				holderReady[i] = true;
				holders[i].setAnimation("idle");
			}
			if (holders[i] == null || (!holders[i].loaded && game.frame - holderFrame[i] < HOLDER_WAIT))
				waiting = true;
		}
		super.render(t, mx, my, live);
	}

	function build():Void {
		var run = game.run;
		// (the pictures of the skin only: nothing drawn in place of a missing one)
		Skin.box(back, "background", 0, 0, 600, 460);
		ShopScreen.topBar(this, run, null);
		Ui.title(Ui.label(front, Lang.t("CHOISIS TON ADVERSAIRE"), 14, ShopScreen.TOP_Y, 15, Col.PARCHMENT, 0, 0.5, Col.INK));

		var boxes = new Graphics();
		for (i in 0...3) {
			var o = run.opponents[i];
			var x = 10 + i * 197;
			var cx = x + 93;
			var card = new Graphics();
			back.addChild(card);
			Ui.skinPanel(card, back, "card", x, 52, 186, 400, Col.PAPER, Col.WOOD);
			card = new Graphics();
			// the difficulty: a thin outline of its color around the card
			card.lineStyle(OUTLINE_W, LEVEL_COLORS[i], OUTLINE_ALPHA, 1);
			card.drawRoundedRect(x - OUTLINE_LEFT, 52, 186 + OUTLINE_LEFT, 400, OUTLINE_RADIUS);
			card.lineStyle(0, 0, 0);
			// the floor of the brute
			card.beginFill(0x000000, 0.12);
			card.drawEllipse(cx, BRUTE_Y, 44 * BRUTE_SCALE / 1.3, 8);
			card.endFill();
			// thin lines: before the stats, after the pets
			card.lineStyle(1, Col.WOOD, 0.35);
			for (ly in [SEP_STATS_Y, SEP_PETS_Y]) {
				card.moveTo(x + 11, ly);
				card.lineTo(x + 173, ly);
			}
			card.lineStyle(0, 0, 0);
			back.addChild(card);

			Ui.title(Ui.label(front, Lang.t(LEVELS[i]), cx, 67, 18, LEVEL_COLORS[i], 0.5, 0.5, Col.INK));
			Ui.label(front, o.name, cx, 92, 17, Col.WOOD, 0.5, 0.5);

			// the HP in a heart, the stats in bars (STATS_SCALE times their first size)
			var k12 = STATS_SCALE;
			Ui.heartValue(front, x + HEART_X, STATS_Y + 22 * k12, 40 * HEART_SCALE, o.hpValue);
			var stats = [
				{n: S.name(S.STRENGTH), v: o.strengthValue, c: Col.STRENGTH},
				{n: S.name(S.AGILITY), v: o.agilityValue, c: Col.AGILITY},
				{n: S.name(S.SPEED), v: o.speedValue, c: Col.SPEED}
			];
			for (k in 0...3) {
				var sy = STATS_Y + 2 + k * 15 * k12;
				// (the icon of the skin, else the name)
				if (Ui.statIcon(front, ShopScreen.STAT_KEYS[k + 1], x + 70, sy + 7 * k12, 13 * k12) == null)
					Ui.label(front, stats[k].n, x + 56, sy, 11 * k12, stats[k].c, 0, 0, -1, true);
				Ui.miniStat(boxes, x + 90, sy + 3 * k12, stats[k].v, 54 * k12, 8 * k12);
				Ui.label(front, Std.string(stats[k].v), x + 94 + 54 * k12, sy, 11 * k12, stats[k].c, 0, 0, -1, true);
			}

			// how many weapons, passive skills, supers
			var counts = [
				{icon: "weapons/broadsword.png", n: o.weapons.length, tip: Lang.t("Armes")},
				{icon: "tier-1/armor.png", n: o.countSkills(false), tip: Lang.t("Compétences passives")},
				{icon: "tier-1/fierceBrute.png", n: o.countSkills(true), tip: Lang.t("Supers")}
			];
			for (k in 0...3) {
				var ix = x + 12 + k * 58;
				var iy = 266;
				// (the broadsword turned SWORD_ANGLE, with a black outline of 1 pixel: it is seen on the card)
				if (k == 0)
					for (d in [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, 1], [-1, 1], [1, -1]]) {
						var edge = Sheets.fit(Sheets.sprite(counts[k].icon), 24, 22);
						edge.tint = 0x000000;
						edge.rotation = SWORD_ANGLE * Math.PI / 180;
						edge.x = ix + 12 + d[0];
						edge.y = iy + 12 + d[1];
						front.addChild(edge);
					}
				var icon = Sheets.fit(Sheets.sprite(counts[k].icon), 24, 22);
				if (k == 0)
					icon.rotation = SWORD_ANGLE * Math.PI / 180;
				icon.x = ix + 12;
				icon.y = iy + 12;
				front.addChild(icon);
				Ui.label(front, "×" + counts[k].n, ix + 28, iy + 12, 16, Col.WOOD, 0, 0.5, -1, true);
			}

			// the pets
			for (k in 0...o.pets.length) {
				var p = o.pets[k];
				var px = cx - (o.pets.length * PET_STEP) / 2 + k * PET_STEP + PET_STEP / 2;
				// (an outline of black pixels around it, whatever its tier)
				Ui.outlined(front, Skin.pet(p.name), px, 319, 34, 30, 0x000000, PET_OUTLINE);
			}

			// the reward
			Ui.label(front, Lang.t("Récompense"), cx, 352, 12, Col.MUTED, 0.5, 0.5);
			Ui.gold(front, cx, 372, "+" + Ui.num(run.reward(i)), 18, Col.GOLD_TEXT, -1, 0.5, Ui.TITLE);

			// (the picture `fight` of the skin, with its text)
			var btn = new Button(front, x + 10, 383, 166, 55, Skin.has("fight") ? "" : Lang.t("AFFRONTER"), A.PICK + i, LEVEL_COLORS[i], 18, null, "fight");
			buttons.push(btn);
		}
		front.addChild(boxes);
	}

	override public function destroy():Void {
		for (h in holders)
			game.actors.release(h);
		holders = [];
		super.destroy();
	}
}
