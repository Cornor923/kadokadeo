package labrute;

import labrute.Data;
import labrute.view.Ui;

// The tooltips of the weapons, skills, pets and brutes: the values of the 3 tiers of a perk, the current one in bold.
// The weapons and the skills as LaBrute writes them (WeaponTooltip, SkillTooltip: their French texts, their order, their
// colors), the price of the next tier added in the shop.
class Describe {
	// the texts of LaBrute's tooltips (MUI: secondary.main, error.main, warning.main), the faded values (opacity 0.7)
	static inline var INK = 0x733D2C;
	static inline var ERROR = 0xD32F2F;
	static inline var WARNING = 0xED6C02;
	static inline var FADED = 0.7;
	// their width (250, minus the padding of the box)
	static inline var WIDTH = 234;
	// the skills: their width (x 0.9), their icon (34 pixels in the sheet: x 1.5) and the margin after it
	static inline var SKILL_WIDTH = 209;
	static inline var SKILL_ICON = 51;
	static inline var SKILL_ICON_MARGIN = 8;
	// the pictures of the weapons: their highest height, their shadow (CSS drop-shadow(2px 2px 2px #000): moved by
	// SHADOW, blurred by SHADOW_BLUR)
	static inline var PICTURE_H = 50;
	static inline var SHADOW = 2;
	static inline var SHADOW_BLUR = 1;
	static var TYPES = [
		"fast" => "rapide",
		"sharp" => "tranchant",
		"heavy" => "lourd",
		"long" => "long",
		"thrown" => "distance",
		"blunt" => "contondant"
	];
	static var TYPE_COLORS = [
		"fast" => 0x8686FF,
		"sharp" => 0xFF0000,
		"heavy" => 0xA52A2A,
		"long" => 0x008000,
		"thrown" => 0x800080,
		"blunt" => 0xFFA500
	];
	static var DETAILS = ["atOneHp" => "à 1 PV", "againstThrows" => "contre les lancers", "afterBlock" => "après blocage"];
	static var WEAPON_STATS = [
		S.CRIT_CHANCE, S.CRIT_DAMAGE, S.REVERSAL, S.EVASION, S.DEXTERITY, S.BLOCK, S.ACCURACY, S.DISARM, S.COMBO, S.DEFLECT
	];
	// the effect of the skills (`<name>.effect`), red under their description: <uses /> their uses, <stats … /> their
	// SkillData.extra (minus: « - » before them, percent: « % » after them)
	static var EFFECTS:Map<String, String> = [
		"weaponsMaster" => "Espion ne peut pas échanger vos armes tranchantes.",
		"survival" => "Le premier coup t'amenant à 0 PV ou moins te laisse à 1 PV.",
		"balletShoes" => "Le premier coup de chaque combat est automatiquement esquivé",
		"determination" => "Tant que le coup ne blesse pas, <stats percent /> de chance d'attaquer à nouveau.",
		"resistant" => "Chaque coup reçu ne peut pas te faire perdre plus de <stats percent /> de ta barre.",
		"ironHead" => "Pour chaque coup te ciblant, ton adversaire a <stats percent /> de chance de perdre son arme.",
		"thief" => "Action x<uses /> Ta brute prend l'arme de son adversaire",
		"fierceBrute" => "Action x<uses /> Ta brute double les dégâts du prochain assaut. Gagne une utilisation en plus par 30 points en force.",
		"tragicPotion" => "Action x<uses /> Ta brute récupère 25 à 50 % de ses PV. Soigne aussi le poison du Cuisinier.",
		"net" => "Action x<uses /> Le filet empêche la cible de bouger/esquiver/parer jusqu'au prochain coup reçu",
		"bomb" => "Action x<uses /> Entre 15 et 25 dégâts sur tous les adversaires.",
		"hammer" => "Action x<uses /> Ta brute inflige de gros dégâts qui dépendent de la force de ton adversaire. Lâche votre bouclier si vous en avez un.",
		"cryOfTheDamned" => "Action x<uses /> Votre brute repousse les animaux de votre adversaire ou se réveille d'un étourdissement (50% de chances de réussite)",
		"hypnosis" => "Action x<uses /> Votre Brute prend le contrôle des familiers de votre adversaire ou convainc l'adversaire de l'épargner (90% de chances de réussite).",
		"flashFlood" => "Action x<uses /> Votre Brute inflige instantanément des dégâts massifs à son adversaire avec 3 armes.",
		"tamer" => "Action x<uses /> Ta brute récupère entre 20 et 50% de sa vie selon la qualité de la viande.",
		"regeneration" => "Tu peux faire deux combats de plus par jour.",
		"chef" => "Tes adversaires subissent <stats percent /> de dégâts à la fin de chacune de leurs actions.",
		"spy" => "Échangez une version légèrement endommagée de vos armes avec votre adversaire (Adversaire <stats minus percent /> de dégâts d'arme)",
		"saboteur" => "Sabote une arme de ton adversaire (initiative adverse <stats minus /> lorsqu'elle est utilisée)",
		"backup" => "Votre brute appelle un allié plus faible pour l'aider à combattre (reste pendant <stats /> tours normaux).",
		"hideaway" => "Chances d'envoyer son arme : 50%. Les armes ne disparaissent pas après un lancer",
		"vampirism" => "Action x<uses /> Inflige 25% de vos points de vie manquants et vous soigne jusqu'à deux fois ce montant.",
		"chaining" => "Chaque 3e coup consécutif de mêlée étourdira ton adversaire.",
		"haste" => "Action x<uses /> Ta brute se précipite à travers son adversaire, infligeant des dégâts supplémentaires qui augmentent avec sa vitesse.",
		"treat" => "Action x<uses /> Ta brute soigne l'un de ses familiers à hauteur de 50% de leur santé, les rend immunisés à la prochaine attaque et les force à attaquer.",
		"fastMetabolism" => "À 50% PV, votre brute peut régénérer jusqu'à 10 fois 5% PV s'il elle ne subit pas de dégâts.",
		"mimic" => "Action x<uses /> Vous copiez la compétence utilisée par un adversaire.",
		"stickyHands" => "Votre brute a une chance d'empêcher d'être désarmé ou de jeter une arme quand vous en avez déjà une.",
		"rewind" => "Action x<uses /> Lorsqu'un coup tuerait votre Brute, rembobinez le combat de <stats /> tours, puis donnez-lui 3 tours d'initiative normaux.",
		"reload" => "Action x<uses /> Lorsque votre Brute a utilisé toutes ses armes et compétences rechargeables, elle les récupère."
	];

	// a label of LaBrute's tooltips (its key in labrute-react), in the language of the game
	static function label(key:String, fr:String):String {
		return Lang.data("label", key, fr);
	}

	// the type of a weapon, in the language of the game
	static function typeName(type:String):String {
		return Lang.data("type", type, TYPES.get(type));
	}

	static function pct(v:Float):String {
		return Std.string(Math.round(Math.abs(v) * 100));
	}

	// a chance as LaBrute writes it: "0.58%"
	static function odds(r:Float):String {
		var v:String = js.Syntax.code("({0}).toFixed(2)", r * 100);
		return v + "%";
	}

	// the price of the next tier (price >= 0: the shop)
	static function upgrade(box:TipBox, tier:Int, gold:Int, price:Int, ?color:Int = Col.WOOD):Void {
		if (price < 0 || tier >= 3)
			return;
		// (and its ears, red when the player has not enough)
		var ears = Balance.TIER_EARS[tier + 1];
		var have = Game.ME != null && Game.ME.run != null ? Game.ME.run.ears : 0;
		box.separator(color);
		box.line([
			{t: Lang.f("Niveau {0} : ", [tier + 1]), c: color},
			{t: Std.string(price), c: gold < price ? Col.RED : Col.GOLD_TEXT, b: true, g: true},
			{t: "  "},
			{t: Std.string(ears), c: have < ears ? Col.RED : Col.GOLD_TEXT, b: true, e: true}
		]);
	}

	// the picture of a weapon of the skin at the size of its drawing (at most WIDTH × PICTURE_H), its shadow under it
	static function picture(box:TipBox, name:String):Void {
		var size = Skin.size(name);
		var k = Math.min(1, Math.min(WIDTH / size.w, PICTURE_H / size.h));
		box.shadowImage(Skin.tex(name), size.w * k, size.h * k, SHADOW, SHADOW, SHADOW_BLUR);
	}

	// « Label: » then its value in bold (faded, or in a color)
	static function labelled(box:TipBox, label:String, value:Array<TipRun>):Void {
		box.flow([({t: label + Lang.t(": "), c: INK} : TipRun)].concat(value));
	}

	// a weapon (tier 0: not owned, its tier 1 shown); LaBrute's order: its name, its picture, its types, its odds, its hit
	// speed, its damage, its draw chance, its reach, then its stats
	public static function weapon(name:String, tier:Int, ?gold:Int = -1, ?price:Int = -1):TipBox {
		var w = Data.weapon(name);
		var owned = tier > 0;
		var t = owned ? tier : 1;
		var box = new TipBox(WIDTH);
		box.gap(4).stars(t).title(w.label, true, INK, 16, true);
		// (its horizontal picture of the skin, else the one of the board, else the one of the game)
		if (Skin.has("weapon-tip-" + name))
			picture(box, "weapon-tip-" + name);
		else if (Skin.has("weapon-" + name))
			picture(box, "weapon-" + name);
		else
			box.shadowImage(Sheets.tex("weapons/" + name + ".png"), 40, 30, SHADOW, SHADOW, SHADOW_BLUR);
		var types:Array<TipRun> = [];
		for (i in 0...w.types.length) {
			if (i > 0)
				types.push({t: ", ", c: INK});
			var type = typeName(w.types[i]);
			types.push({t: type.charAt(0).toUpperCase() + type.substr(1), c: TYPE_COLORS.get(w.types[i]), b: true});
		}
		labelled(box, label("types", "Types"), types);
		labelled(box, label("odds", "Obtention"), [{t: odds(w.odds / Data.WEAPONS_TOTAL_ODDS), c: INK, b: true, a: FADED}]);
		labelled(box, label("hitSpeed", "Vitesse de frappe"), TipBox.tiered([for (v in w.tempo) pct(Data.BASE_TEMPO / v)], t, INK, "", "%", true, FADED));
		labelled(box, label("damage", "Dégâts"), TipBox.tiered([for (d in w.damage) Std.string(d)], t, S.COLORS[S.DAMAGE]));
		labelled(box, label("drawChance", "Chance d'utilisation"), TipBox.tiered([for (v in w.toss) pct(v / (Data.NO_WEAPON_TOSS + v))], t, INK, "", "%", true, FADED));
		labelled(box, label("reach", "Portée"), [{t: Std.string(w.reach), c: INK, b: true, a: FADED}]);
		for (s in WEAPON_STATS) {
			// (shown when its first tier is not 0)
			var a = w.stats[s];
			if (a == null || a[0] == 0)
				continue;
			var c = S.COLORS[s];
			box.flow(TipBox.tiered([for (v in a) pct(v)], t, c, a[t - 1] > 0 ? "+" : "-", "%").concat([{t: " " + S.name(s), c: c, b: true}]));
		}
		if (owned)
			upgrade(box, tier, gold, price, INK);
		return box.gap(4);
	}

	// the bare hands: always there, nothing to upgrade (LaBrute: their hit speed, their damage, the stats of a brute
	// without a weapon)
	public static function bareHands():TipBox {
		var box = new TipBox(WIDTH);
		box.gap(4).title(label("bareHands", "Mains nues"), true, INK, 16, true);
		if (Skin.has("weapon-bare-hands"))
			picture(box, "weapon-bare-hands");
		labelled(box, label("hitSpeed", "Vitesse de frappe"), [{t: "100%", c: INK, b: true, a: FADED}]);
		labelled(box, label("damage", "Dégâts"), [{t: Std.string(Data.BARE_HANDS_DAMAGE), c: S.COLORS[S.DAMAGE], b: true}]);
		for (s in WEAPON_STATS) {
			var v = Data.BASE_FIGHTER_STATS[s];
			var c = S.COLORS[s];
			box.flow([{t: (v > 0 ? "+" : "-") + pct(v) + "% " + S.name(s), c: c, b: true}]);
		}
		return box.gap(4);
	}

	// a skill: its icon floated on the left, its name and a line on its right, its description, its stats, its effect
	public static function skill(name:String, tier:Int, ?gold:Int = -1, ?price:Int = -1):TipBox {
		var s = Data.skill(name);
		var owned = tier > 0;
		var t = owned ? tier : 1;
		var box = new TipBox(SKILL_WIDTH);
		box.gap(4).floatTo(Sheets.tex("tier-" + t + "/" + name + ".png"), SKILL_ICON, SKILL_ICON_MARGIN);
		box.title(s.label, false, INK, 16, true).separator(INK, 1, 0).gap(12);
		box.flow([{t: s.text, c: INK}], 1.5);
		for (m in s.mods) {
			var c = S.COLORS[m.stat];
			var label = m.opponent ? (m.stat == S.DAMAGE ? Describe.label("opponent-damage", "Dégâts de l'adversaire") : Lang.f("{0} de l'adversaire",
				[S.name(m.stat)])) : S.name(m.stat);
			var weapons = Describe.label("weapons", "Armes");
			if (m.weaponType == 1)
				label += " (" + weapons + ": " + Describe.label("none", "Aucunes") + ")";
			else if (m.weaponType == 2 && m.wt != null)
				label += " (" + weapons + ": " + typeName(m.wt) + ")";
			if (m.details != null && DETAILS.exists(m.details))
				label += " " + Lang.data("detail", m.details, DETAILS.get(m.details));
			// (the flat bonus, then the percent one: both for the boosters; the sign of the first tier)
			for (flat in [true, false]) {
				var values = flat ? m.flat : m.percent;
				if (values == null)
					continue;
				var strings = [for (v in values) flat ? Std.string(Math.abs(v)) : pct(v)];
				var sign = values[0] < 0 ? "-" : "+";
				box.flow(TipBox.tiered(strings, t, c, sign, flat ? "" : "%", true, 1, 11.5).concat([{t: " " + label, c: c, b: true, s: 11.5}]),
					flat ? 1 : 1.2);
			}
		}
		var effect = EFFECTS.exists(name) ? Lang.data("effect", name, EFFECTS.get(name)) : null;
		if (effect != null)
			box.flow(effectRuns(effect, s, t), 1.5);
		if (s.uses != null && !s.canReload)
			box.flow([{t: label("skill.notReloadable", "Cette compétence ne peut pas être rechargée."), c: WARNING, b: true}], 1.5);
		if (s.toss != null)
			box.flow([({t: label("usageRate", "Taux d'utilisation") + Lang.t(": "), c: INK, a: FADED} : TipRun)].concat(TipBox.tiered([for (v in s.toss) pct(v / (Data.NO_SKILL_TOSS + v))], t,
				INK, "", "%", false, FADED)), 1);
		// (its odds on the left, its stars on the right)
		box.draw(21, (c, w) -> {
			var o = Ui.text(label("odds", "Obtention") + Lang.t(": ") + odds(s.odds / Data.SKILLS_TOTAL_ODDS), 12, INK, "left", -1, 0, true);
			o.alpha = FADED;
			o.y = Math.round((21 - o.height) / 2);
			c.addChild(o);
			var g = new pixi.core.graphics.Graphics();
			for (i in 0...t - 1)
				Ui.star(g, w - 8 - (t - 2 - i) * 16, 10.5, 7.5, 0xFFFFFF);
			c.addChild(g);
		});
		if (owned)
			upgrade(box, tier, gold, price, INK);
		return box.gap(4);
	}

	// the effect of a skill: its text, its tags <uses /> and <stats … /> as tiered values (bold, red)
	static function effectRuns(text:String, s:SkillData, t:Int):Array<TipRun> {
		var runs:Array<TipRun> = [];
		var tag = ~/<(uses|stats)([^>]*)\/>/;
		while (tag.match(text)) {
			runs.push({t: tag.matchedLeft(), c: ERROR, b: true});
			var attrs = tag.matched(2);
			if (tag.matched(1) == "uses") {
				if (s.uses != null)
					runs = runs.concat(TipBox.tiered([for (u in s.uses) Std.string(u)], t, ERROR));
			} else if (s.extra != null) {
				// (the shares as percents, the other values as they are)
				var values = [for (v in s.extra) v > -1 && v < 1 ? Std.string(Math.round(v * 100)) : Std.string(v)];
				runs = runs.concat(TipBox.tiered(values, t, ERROR, attrs.indexOf("minus") >= 0 ? "-" : "", attrs.indexOf("percent") >= 0 ? "%" : ""));
			}
			text = tag.matchedRight();
		}
		runs.push({t: text, c: ERROR, b: true});
		return runs;
	}

	// the stats of a pet with this brute as its master (LaBrute: they grow with the stats of the brute)
	public static function petStat(p:PetData, tier:Int, b:Brute, stat:Int):Int {
		var t = tier - 1;
		return switch (stat) {
			case S.HP: Std.int(p.hp[t]) + Math.ceil(p.scaling[3] * b.hpValue);
			case S.STRENGTH: Std.int(p.strength[t]) + Math.ceil(p.scaling[0] * b.strengthValue);
			case S.AGILITY: Std.int(p.agility[t]) + Math.ceil(p.scaling[1] * b.agilityValue);
			default: Std.int(p.speed[t]) + Math.ceil(p.scaling[2] * b.speedValue);
		}
	}

	// hideTier: its values only, not its tier (the pets of an opponent)
	public static function pet(name:String, tier:Int, b:Brute, ?gold:Int = -1, ?price:Int = -1, ?hideTier:Bool = false):TipBox {
		var p = Data.pet(name);
		var owned = tier > 0;
		var t = owned ? tier : 1;
		var box = new TipBox(236);
		if (!hideTier)
			box.stars(t);
		box.title(p.label).image(Skin.pet(name), 70, 46);
		function tiered(values:Array<String>, color:Int, ?prefix:String = "", ?suffix:String = ""):Array<TipRun> {
			return TipBox.tiered(hideTier ? [values[t - 1]] : values, hideTier ? 1 : t, color, prefix, suffix);
		}
		for (s in [S.HP, S.STRENGTH, S.AGILITY, S.SPEED]) {
			var c = Col.stat(s);
			box.line([({t: S.name(s) + Lang.t(" : "), c: c} : TipRun)].concat(tiered([for (k in 1...4) Std.string(petStat(p, k, b, s))], c)));
		}
		box.line([({t: S.name(S.DAMAGE) + Lang.t(" : ")} : TipRun)].concat(tiered([for (d in p.damage) Std.string(d)], Col.STRENGTH)));
		for (e in [
			{s: S.COMBO, v: p.combo},
			{s: S.EVASION, v: p.evasion},
			{s: S.ACCURACY, v: p.accuracy},
			{s: S.DISARM, v: p.disarm},
			{s: S.BLOCK, v: p.block}
		]) {
			if ((e.v[0] == 0 && e.v[1] == 0 && e.v[2] == 0) || (hideTier && e.v[t - 1] == 0))
				continue;
			var c = Col.stat(e.s);
			box.line(tiered([for (v in e.v) pct(v)], c, e.v[t - 1] < 0 ? "-" : "+", " % ").concat([{t: S.name(e.s), c: c, b: true}]));
		}
		box.line([({t: Lang.t("Malus de PV") + Lang.t(" : ")} : TipRun)].concat(tiered([for (v in p.hpMalus) pct(v)], Col.HP, "-", " %")));
		if (owned)
			upgrade(box, tier, gold, price);
		return box;
	}

	// a brute of the fight: its level, its HP and stats, its supers and skills
	// (square, compact: every text in the same size; its league after its level)
	public static function brute(b:Brute, league:Int):TipBox {
		var box = new TipBox(214);
		box.square = true;
		box.line([{t: Lang.t(b.name), b: true}]);
		box.draw(16, (c, w) -> {
			var t = Ui.text(Lang.t("Niveau") + " ", 12, Col.WOOD, "left", -1, 0, true);
			t.alpha = 0.8;
			c.addChild(t);
			var v = Ui.text(Std.string(b.level), 12, Col.WOOD, "left", -1, 0, true, true);
			v.x = t.width;
			c.addChild(v);
			Ui.medal(c, t.width + v.width + 10, 7, league, 6);
		});
		box.draw(44, (c, w) -> {
			Ui.heartValue(c, 20, 21, 38, b.hpValue);
			var g = new pixi.core.graphics.Graphics();
			c.addChild(g);
			var rows = [
				{n: S.name(S.STRENGTH), v: b.strengthValue, c: Col.STRENGTH},
				{n: S.name(S.AGILITY), v: b.agilityValue, c: Col.AGILITY},
				{n: S.name(S.SPEED), v: b.speedValue, c: Col.SPEED}
			];
			for (i in 0...3) {
				var y = 2 + i * 15;
				// (the icon of the skin, else the name)
				if (Ui.statIcon(c, ShopScreen.STAT_KEYS[i + 1], 88, y + 7) == null) {
					var t = Ui.text(rows[i].n, 11, rows[i].c, "left", -1, 0, true, true);
					t.x = 50;
					t.y = y;
					c.addChild(t);
				}
				Ui.miniStat(g, 106, y + 3, rows[i].v, 80, 8);
				var v = Ui.text(Std.string(rows[i].v), 11, rows[i].c, "left", -1, 0, true, true);
				v.x = 192;
				v.y = y;
				c.addChild(v);
			}
		});
		var supers = [for (s in b.skills) if (Data.skill(s.name).type == "super") Data.skill(s.name).label + (s.tier > 1 ? " (" + s.tier + ")" : "")];
		var others = [for (s in b.skills) if (Data.skill(s.name).type != "super") Data.skill(s.name).label + (s.tier > 1 ? " (" + s.tier + ")" : "")];
		perks(box, Lang.t("Supers"), supers);
		perks(box, Lang.t("Compétences"), others);
		return box;
	}

	// « Supers : » in bold, the list after it (nothing after it without any)
	static function perks(box:TipBox, title:String, list:Array<String>):Void {
		box.line([{t: title + Lang.t(" : "), b: true}]);
		if (list.length > 0)
			box.para(list.join(", "), 12, Col.WOOD);
	}
}
