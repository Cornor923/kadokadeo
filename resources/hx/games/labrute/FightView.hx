package labrute;

import haxe.ds.IntMap;
import pixi.core.display.Container;
import pixi.core.display.DisplayObject;
import pixi.core.graphics.Graphics;
import pixi.core.sprites.Sprite;
import pixi.core.text.Text;
import pixi.core.textures.Texture;
import labrute.Data;
import labrute.Screen;
import labrute.fight.Fighter;
import labrute.fight.Step;
import labrute.view.Actors;
import labrute.view.Ui;
import labrute.view.V8;

// a fighter on screen (arena coordinates of LaBrute: 500 x 320, the ground between y 175 and 281)
private class FV {
	public var index:Int;
	public var fighter:Fighter;
	public var team:Int;
	public var facesRight:Bool;
	public var model:String;
	public var pet:String;
	public var baseWidth:Float;
	public var baseHeight:Float;
	public var x:Float = 0;
	public var y:Float = 0;
	public var homeX:Float = 0;
	public var homeY:Float = 228;
	public var fromX:Float = 0;
	public var fromY:Float = 0;
	public var toX:Float = 0;
	public var toY:Float = 228;
	public var moveStart:Float = 0;
	public var moveDur:Float = 0;
	public var arc:Float = 0;
	// a second move (back home) after the first one
	public var backAt:Float = -1;
	public var backDur:Float = 0;
	public var present:Bool = false;
	public var leaveAt:Float = -1;
	public var dead:Bool = false;
	public var trapped:Bool = false;
	// the net is on it from this moment (when it lands)
	public var trappedAt:Float = 0;
	public var stunned:Bool = false;
	public var hypnotized:Bool = false;
	public var fierce:Bool = false;
	// its shadow shown (a brute)
	public var shadowShown:Bool = false;
	// « Increvable »: the next blow it takes shows it (LaBrute's playResistAnimation)
	public var resist:Bool = false;
	// the parts of its moves (LaBrute's multi-phase moves: the thief, vampirism, hammer, haste, flash flood, a jump back)
	public var segs:Array<Seg> = [];
	// after its parts: still there from this moment (-1: its move)
	public var restX:Float = 0;
	public var restY:Float = 0;
	public var restAt:Float = -1;
	// a blow taken: its shake from this moment, for this time (LaBrute's stagger)
	public var wobStart:Float = -1;
	public var wobDur:Float = 0;
	// the animations of its steps: from a moment until another, from a frame (LaBrute's setAnimation(name, frame)); the
	// last one started is played
	public var anims:Array<Anim> = [];
	// its weapon in hand before this moment (a weapon taken by the thief: still in the hand of the robbed one until then)
	public var weaponUntil:Float = -1;
	public var weaponBefore:Int = -1;
	// the side it faced before this moment (a pet hypnotised: it runs to its new side, then turns)
	public var faceUntil:Float = -1;
	public var faceBefore:Bool = false;
	// turned the other way meanwhile (running back to its place, its back to the opponents)
	public var turnStart:Float = -1;
	public var turnUntil:Float = -1;
	// its trail: « Brute féroce » or « Célérité »
	public var trailFierce:Bool = true;
	// a green outline (poison) until this moment, its copies
	public var auraUntil:Float = -1;
	public var aura:Array<V8Sprite> = [];
	// « Brute féroce »: its trail of pictures (the newest red, the oldest blue), the last one taken
	public var trail:Array<V8Sprite> = [];
	public var trailShots:Array<{
		tex:Dynamic,
		x:Float,
		y:Float,
		sx:Float,
		sy:Float
	}> = [];
	public var trailAt:Float = -1000;
	public var winner:Bool = false;
	public var hp:Int = 0;
	// the HP changes of its steps shown at their moment (a blow that lands, a potion drunk): their time and amount
	public var future:Array<{t:Float, d:Int}> = [];
	public var maxHp:Int = 1;
	public var weapon:Int = -1;
	public var shield:Bool = false;
	public var fastUntil:Float = 0;
	public var speedRef:Dynamic = {current: Balance.FIGHT_SPEED};
	// drawn
	public var holder:V8FighterHolder;
	public var shownKey:String = "";
	public var holderFacesRight:Bool;
	public var ph:Graphics;

	public function new() {}

	public inline function visibleAt(now:Float):Bool {
		return present && (leaveAt < 0 || now < leaveAt);
	}
}

private class FVState {
	public var x:Float;
	public var y:Float;
	public var homeX:Float;
	public var homeY:Float;
	public var present:Bool;
	public var leaveAt:Float;
	public var dead:Bool;
	public var trapped:Bool;
	public var stunned:Bool;
	public var hypnotized:Bool;
	public var fierce:Bool;
	public var hp:Int;
	public var weapon:Int;
	public var shield:Bool;
	public var team:Int;
	public var facesRight:Bool;

	public function new() {}
}

// a weapon or a super in the HUD
// an animation of a step: from a moment until another, from a frame, held on it (paused: a hand raised)
private typedef Anim = {
	name:String,
	start:Float,
	until:Float,
	frame:Int,
	serial:Int,
	hold:Bool,
}

private typedef Perk = {
	id:Int,
	tier:Int,
	left:Int,
}

// the HUD of a side: its main brute, the weapons it still has, its supers and their uses left
private class Side {
	public var fv:FV;
	public var right:Bool;
	public var brute:Brute;
	public var weapons:Array<Perk> = [];
	public var supers:Array<Perk> = [];
	public var dirty:Bool = true;
	public var icons:Container;
	public var tips:Array<Tip> = [];
	// the blows of the last moments (their time, their damage): the HP they took stay a moment in a lighter color
	public var blows:Array<{t:Float, d:Int}> = [];
	public var shownHp:Int = -1;
	public var portraitBox:V8Container;
	public var portrait:V8FighterHolder;
	public var portraitReady:Bool = false;
	public var portraitFitted:Bool = false;
	// the renders of the HUD until its head is drawn once into a texture (still: not its filters at each frame)
	public var portraitCacheIn:Int = -1;
	// its icons hidden until this moment (their flight: « Espion »)
	public var iconsHiddenUntil:Float = -1;
	public var weaponRow:Container;

	public function new() {}

	public function save():{weapons:Array<Perk>, supers:Array<Perk>} {
		return {
			weapons: [for (p in weapons) {id: p.id, tier: p.tier, left: p.left}],
			supers: [for (p in supers) {id: p.id, tier: p.tier, left: p.left}]
		};
	}

	public function load(s:{weapons:Array<Perk>, supers:Array<Perk>}):Void {
		weapons = [for (p in s.weapons) {id: p.id, tier: p.tier, left: p.left}];
		supers = [for (p in s.supers) {id: p.id, tier: p.tier, left: p.left}];
		dirty = true;
	}

	public function loseWeapon(id:Int):Perk {
		for (p in weapons)
			if (p.id == id) {
				weapons.remove(p);
				dirty = true;
				return p;
			}
		return null;
	}
}

// a part of a move of a fighter, from a place on the ground to another (arena units), lifted from up0 to up1, eased; it
// can face the other way, be in front of or behind the others (z), be upside down, shake
private class Seg {
	public var start:Float;
	public var dur:Float;
	public var x0:Float;
	public var y0:Float;
	public var x1:Float;
	public var y1:Float;
	public var up0:Float = 0;
	public var up1:Float = 0;
	// 0 linear, 1 in (quad), 2 out (quad), 3 out (cubic), 4 in (cubic)
	public var ease:Int = 0;
	public var flip:Bool = false;
	public var z:Null<Float> = null;
	public var upsideDown:Bool = false;
	// a fast shake up and down (pixels), a tint (-1: none)
	public var shake:Float = 0;
	public var tint:Int = -1;

	public function new(start:Float, dur:Float, x0:Float, y0:Float, x1:Float, y1:Float) {
		this.start = start;
		this.dur = dur;
		this.x0 = x0;
		this.y0 = y0;
		this.x1 = x1;
		this.y1 = y1;
	}

	public function at(now:Float):Float {
		var u = dur <= 0 ? 1 : Math.max(0, Math.min(1, (now - start) / dur));
		return switch (ease) {
			case 1: u * u;
			case 2: 1 - (1 - u) * (1 - u);
			case 3: 1 - (1 - u) * (1 - u) * (1 - u);
			case 4: u * u * u;
			default: u;
		}
	}
}

// an effect: a picture or a text for a time (a projectile, an animation of the misc sheet, a number)
private class Fx {
	public var obj:DisplayObject;
	public var start:Float;
	public var dur:Float;
	public var fromX:Float = 0;
	public var fromY:Float = 0;
	public var toX:Float = 0;
	public var toY:Float = 0;
	public var arc:Float = 0;
	public var spin:Float = 0;
	public var frames:Array<Texture>;
	public var rise:Float = 0;
	public var fade:Bool = false;
	// (the part of its time when it starts fading)
	public var fadeFrom:Float = 0.6;
	// appears in this part of its time (0: at once)
	public var fadeIn:Float = 0;
	// its pictures in a loop, this many by frame of the game (0: once over its time)
	public var loopRate:Float = 0;
	// its scale from scale0 to scale1 (eased out; 0: kept)
	public var scale0:Float = 0;
	public var scale1:Float = 0;
	// a lost weapon: falls, bounces, lies, fades (FightView.bounceAt)
	public var bounce:Bool = false;
	// at its end, it stays (its last picture, its last place), until this moment (-1: for ever)
	public var stay:Bool = false;
	public var until:Float = -1;

	public function new(obj:DisplayObject, start:Float, dur:Float) {
		this.obj = obj;
		this.start = start;
		this.dur = dur;
	}
}

// The pictures of a fight: the arena of LaBrute, the fighters of labrute-pixi-fighter (or simple shapes until they are
// loaded), what each step does (moves, animations, projectiles, impacts, the damage), the HUD (the heads, the HP, the
// weapons and the supers left, the countdown) and the gold of the bonuses where they are won. Only a view of
// FightScreen: it follows its steps, nothing here changes the game.
class FightView {
	static inline var ARENA_Y = 76;
	static inline var ARENA_SCALE = 1.2;
	// the floor of the fighters in the background (arena units): it stays in place when the background goes up to the top
	static inline var BG_ANCHOR_Y = 230;
	// the longest effect (the blood on the floor)
	static inline var EFFECT_FRAMES = 170;
	// the HUD (the left side, the right one mirrored): its band (the picture `header`) and its black outline
	static inline var HEADER_H = 93;
	static inline var HEADER_OUTLINE = 1;
	// the window of a head: its size, its middle
	static inline var HEAD_W = 53;
	static inline var HEAD_H = 45;
	static inline var HEAD_CX = 35;
	static inline var HEAD_CY = 66;
	// the brute in its window: its scale, the top of its head under the top of the window (+ lower), its middle moved
	// (+ right; mirrored on the right)
	static inline var HEAD_SCALE = 1.2;
	static inline var HEAD_GAP = 3;
	static inline var HEAD_DX = 0;
	// the black outline of the heads (pixels)
	static inline var HEAD_OUTLINE = 1;
	// a blow taken: its shake (LaBrute's stagger, seconds at speed 1); « Increvable »: its picture (frames)
	static inline var STAGGER_SECONDS = 0.5;
	// the steps whose fighter `f` acts (it is not stunned)
	static var ACTS = [
		StepType.MOVE,
		StepType.ATTEMPT_HIT,
		StepType.THROW,
		StepType.SKILL_ACTIVATE,
		StepType.TRAP,
		StepType.BOMB,
		StepType.HEAL,
		StepType.EAT,
		StepType.STEAL,
		StepType.VAMPIRISM,
		StepType.HASTE,
		StepType.HAMMER,
		StepType.FLASH_FLOOD,
		StepType.HYPNOTISE,
		StepType.EQUIP,
		StepType.TRASH,
		StepType.TREAT
	];
	static inline var RESIST_FRAMES = 14;
	// the waves of « Cri-qui-poutre »: their size, their pictures by frame (slow enough to see each one)
	static inline var CRY_SCALE = 0.8;
	static var CRY_FILTER:Dynamic = {
		var f = Ui.solid(0xFFFFFF);
		var m:Array<Float> = f.matrix;
		// (its soft edges more opaque)
		m[18] = CRY_ALPHA;
		f.matrix = m;
		f;
	};
	static inline var CRY_ALPHA = 2;
	static inline var CRY_RATE = 0.5;
	// the pets that flee a cry: after its waves appear
	static inline var FLEE_DELAY_SECONDS = 0.3;
	// the head drawn once into a texture this many renders after it is fitted
	static inline var HEAD_CACHE_RENDERS = 20;
	// the HP bar: its top left corner, its size, its corners
	static inline var BAR_X = 9;
	static inline var BAR_Y = 27;
	static inline var BAR_W = 282;
	static inline var BAR_H = 10;
	static inline var BAR_RADIUS = 6;
	// its colors from its edges (top and bottom) to its middle, one pixel each
	static var BAR_GRADIENT = [0xFF9A00, 0xFFB800, 0xFFD000, 0xFFE000];
	// the name (its bottom, above the bar; its size, its black outline), the timer (its middle, under the bars)
	static inline var NAME_Y = BAR_Y + 4;
	static inline var NAME_SIZE = 24;
	static inline var NAME_OUTLINE = 3;
	static inline var TIMER_Y = BAR_Y + BAR_H + 20;
	static inline var TIMER_SIZE = 20;
	// the rows of the weapons and the supers: right of the head, their width
	static inline var ICONS_X = HEAD_CX + HEAD_W / 2 + 6;
	static inline var ICONS_Y = 45;
	static inline var ICONS_W = 180;
	static inline var ICON = 14;
	// the halo of the weapons of tier 2 and 3: black around their colored outline, HALO_W pixels fading outward from
	// HALO_ALPHA (under all the icons: never over a neighbour)
	static inline var HALO_W = 2;
	static inline var HALO_ALPHA = 0.7;
	// a super used: its picture this many times larger over its icon, fading for this time
	static inline var SUPER_POP = 3;
	static inline var SUPER_POP_FRAMES = 96;
	// the gold of a bonus: how far above the fighter, how long after its step (frames)
	static inline var GOLD_ABOVE = 44;
	static inline var GOLD_DELAY = 6;
	// a lost weapon: its fall, its bounce (and its height), on the floor, its fade (frames, 32 a second)
	static inline var FALL_FRAMES = 14;
	static inline var BOUNCE_FRAMES = 10;
	static inline var BOUNCE_HEIGHT = 8;
	static inline var LIE_FRAMES = 40;
	static inline var FADE_FRAMES = 16;
	// a shield broken: its flight (frames)
	static inline var FAST_FALL_FRAMES = 14;
	static inline var HEAD_TOP = HEAD_CY - HEAD_H / 2;
	// the cross on the head of the loser, by the size of the head
	static inline var CROSS_SCALE = 2.8;
	// the width of its black outline (pixels)
	static inline var CROSS_OUTLINE = 1;
	// the time the HP of a blow stay in a lighter color
	static inline var PHANTOM_FRAMES = 22;
	static var PET_ANIMS = [
		"idle",
		"attack",
		"arrive",
		"hit",
		"run",
		"evade",
		"death",
		"grab",
		"grabbed",
		"trapped"
	];
	static var CONFETTI = [0xE74C3C, 0xF1C40F, 0x2ECC71, 0x3498DB, 0x9B59B6, 0xE67E22, 0x1ABC9C, 0xFF6EC7];
	// a pet that runs away is not waited for (its step takes no time): its run
	static inline var PET_LEAVE_FRAMES = 9;
	static var BACKGROUNDS = [
		{n: "1.jpg", o: 100.0},
		{n: "2.jpg", o: 2.0},
		{n: "5.jpg", o: 2.0},
		{n: "6.jpg", o: 2.0},
		{n: "7.jpg", o: 2.0},
		{n: "8.jpg", o: 2.0},
		{n: "9.jpg", o: 2.0},
		{n: "10.jpg", o: 2.0},
		{n: "11.jpg", o: 2.0},
		{n: "12.jpg", o: 2.0},
		{n: "13.jpg", o: 2.0}
	];

	var screen:FightScreen;
	var game:Game;
	var steps:Array<Step>;
	var fvs:Array<FV> = [];
	var byIndex:IntMap<FV>;
	var applied:Int = -1;
	// the random of the pictures of this fight, its own and made again for each step: the same pictures in a replay,
	// played or reached by a seek
	var vr:mt.Rand;
	var baseSeed:Int;
	var built = false;
	var lastDrain:Int = Balance.TIMER_FRAMES;
	// the index of the next Drain step after each step (-1: none, the sudden death shows nothing more)
	var nextDrain:Array<Int>;
	// the uses of the supers, by step
	var usesAt:IntMap<Array<{f:Int, s:Int}>>;
	var snapshots:Array<{fvs:Array<FVState>, sides:Array<{weapons:Array<Perk>, supers:Array<Perk>}>}> = null;
	var effects:Array<Fx> = [];
	var animSerial = 0;
	var sides:Array<Side> = [];

	var arena:Container;
	var floor:Container;
	var fxLayer:Container;
	var hud:Container;
	var hudG:Graphics;
	var header:Sprite;
	var hudFx:Container;
	var timer:Text;
	var sudden:Text;
	#if debug
	var pointsText:Text;
	#end
	var banner:Text;
	// the names of the HUD; the skin when their fonts were given (a font of the skin loaded during the fight: given again)
	var names:Array<Text> = [];
	var fontEpoch = -1;
	var arenaV8:V8Container;
	var hudV8:V8Container;

	public function new(screen:FightScreen, game:Game) {
		this.screen = screen;
		this.game = game;
		steps = screen.steps;
		byIndex = new IntMap();
		var seed = steps.length * 7919 + screen.fightNumber * 104729;
		for (f in screen.gen.initialFighters)
			seed += f.maxHp * 31 + f.strength;
		baseSeed = seed & 0x3FFFFFF;
		vr = new mt.Rand(baseSeed);
		for (s in steps)
			if (s.a == StepType.REWIND) {
				snapshots = [];
				break;
			}
		nextDrain = [];
		var next = -1;
		var i = steps.length - 1;
		while (i >= 0) {
			nextDrain[i] = next;
			if (steps[i].a == StepType.DRAIN)
				next = i;
			i--;
		}
		usesAt = new IntMap();
		for (u in screen.gen.superUses) {
			var list = usesAt.get(u.step);
			if (list == null)
				usesAt.set(u.step, list = []);
			list.push({f: u.f, s: u.s});
		}
		for (f in screen.gen.initialFighters) {
			var fv = new FV();
			fv.index = f.index;
			fv.fighter = f;
			fv.team = f.team;
			fv.facesRight = f.team == 0;
			fv.holderFacesRight = fv.facesRight;
			fv.pet = f.isPet() ? f.pet : null;
			fv.model = f.isPet() ? Data.pet(f.pet).model : f.brute.gender;
			if (f.isPet()) {
				var d = Data.pet(f.pet);
				var k = Actors.petScale(f.pet);
				fv.baseWidth = (d.model == "bear" ? 100 : 58) * k;
				fv.baseHeight = (d.model == "bear" ? 100 : 40) * k;
			} else {
				fv.baseWidth = Data.BRUTE_WIDTH * f.size();
				fv.baseHeight = Data.BRUTE_HEIGHT * f.size();
			}
			fv.hp = f.hp;
			fv.maxHp = f.maxHp;
			fv.shield = f.shield;
			fv.x = fv.toX = fv.fromX = f.team == 0 ? -60 : 560;
			fvs.push(fv);
			byIndex.set(f.index, fv);
		}
		// the main brutes (1: the player, 2: the opponent)
		for (k in 1...3) {
			var fv = byIndex.get(k);
			var side = new Side();
			side.fv = fv;
			side.right = k == 2;
			side.brute = fv.fighter.brute;
			for (w in fv.fighter.weapons)
				side.weapons.push({id: w.data.id, tier: w.tier, left: 0});
			for (s in fv.fighter.skills)
				if (s.data.uses != null && s.usesLeft() > 0)
					side.supers.push({id: s.data.id, tier: s.tier, left: s.usesLeft()});
			sides.push(side);
		}
	}

	inline function sideOf(index:Int):Side {
		return index == 1 ? sides[0] : index == 2 ? sides[1] : null;
	}

	// ---------------------------------------------------------------- the scene

	function build():Void {
		built = true;
		var g = new Graphics();
		g.beginFill(Col.DARK, 1);
		g.drawRect(0, 0, 600, 460);
		g.endFill();
		screen.back.addChild(g);

		arena = new Container();
		arena.y = ARENA_Y;
		arena.scale.set(ARENA_SCALE, ARENA_SCALE);
		screen.back.addChild(arena);
		var bgName = pickBackground();
		// (up to the top of the screen, under the band: enlarged around the floor of the fighters, which stays in place)
		var bg = Sheets.sprite("background/" + bgName, 0, 0);
		var k = (BG_ANCHOR_Y + ARENA_Y / ARENA_SCALE) / BG_ANCHOR_Y;
		bg.width = 500 * k;
		bg.height = 320 * k;
		bg.x = 250 - 250 * k;
		bg.y = BG_ANCHOR_Y - BG_ANCHOR_Y * k;
		arena.addChild(bg);
		floor = new Container();
		arena.addChild(floor);

		fxLayer = new Container();
		fxLayer.y = ARENA_Y;
		fxLayer.scale.set(ARENA_SCALE, ARENA_SCALE);
		screen.front.addChild(fxLayer);

		hud = new Container();
		screen.front.addChild(hud);
		hudG = new Graphics();
		hud.addChild(hudG);
		drawBand();
		for (side in sides) {
			// (the font `font-title` of the skin, in capitals, white with a black outline; its bottom at NAME_Y)
			var name = Ui.title(Ui.label(hud, Lang.t(side.fv.fighter.name).toUpperCase(), side.right ? 600 - BAR_X : BAR_X, NAME_Y, NAME_SIZE, Col.WHITE,
				side.right ? 1 : 0, 1, 0x000000));
			name.style.strokeThickness = NAME_OUTLINE;
			names.push(name);
			side.icons = new Container();
			hud.addChild(side.icons);
			var b = side.brute;
			var league = game.run.league();
			screen.tips.push({
				x: headX(side),
				y: HEAD_TOP,
				w: HEAD_W,
				h: HEAD_H,
				key: "head" + b.uid,
				make: () -> Describe.brute(b, league)
			});
		}
		// (the timer: no background, in Helvetica whatever the skin)
		timer = Ui.useFont(Ui.label(hud, "0:30", 300, TIMER_Y, TIMER_SIZE, Col.PARCHMENT, 0.5, 0.5, Col.INK), ["Helvetica", "Arial", "sans-serif"]);
		sudden = Ui.label(hud, Lang.t("MORT SUBITE"), 300, TIMER_Y + 17, 11, 0xFF5544, 0.5, 0.5, Col.INK);
		#if debug
		pointsText = Ui.label(hud, "", 300, TIMER_Y + 30, 10, Col.GOLD, 0.5, 0.5, Col.INK);
		#end
		hudFx = new Container();
		hud.addChild(hudFx);

		banner = Ui.title(Ui.text("", 22, Col.WHITE, "center", Col.INK));
		banner.anchor.set(0.5, 0.5);
		banner.x = 300;
		banner.y = 440;
		banner.visible = false;
		screen.front.addChild(banner);
	}

	// the left of the window of a head
	inline function headX(side:Side):Float {
		return side.right ? 600 - HEAD_CX - HEAD_W / 2 : HEAD_CX - HEAD_W / 2;
	}

	// the band of the HUD over the top of the arena, with its black outline: the picture `header` of the skin
	// (600 × HEADER_H, under the heads: its windows and its transparent parts show what is under it), else drawn
	function drawBand():Void {
		if (Skin.has("header")) {
			// (its outline around its pixels: black copies around it)
			if (header == null) {
				for (d in [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, 1], [-1, 1], [1, -1], [0, 0]]) {
					header = new Sprite(Skin.tex("header"));
					header.width = 600;
					header.height = HEADER_H;
					header.x = d[0] * HEADER_OUTLINE;
					header.y = d[1] * HEADER_OUTLINE;
					if (d[0] != 0 || d[1] != 0)
						header.tint = 0x000000;
					screen.back.addChild(header);
				}
			}
		}
	}

	function pickBackground():String {
		var total = 0.0;
		for (b in BACKGROUNDS)
			total += b.o;
		var r = vr.rand() * total;
		for (b in BACKGROUNDS) {
			r -= b.o;
			if (r < 0)
				return b.n;
		}
		return "1.jpg";
	}

	function ensureHolders():Void {
		var actors = game.actors;
		if (!actors.ready)
			return;
		if (arenaV8 == null) {
			arenaV8 = actors.layer();
			arenaV8.y = ARENA_Y;
			arenaV8.scale.x = ARENA_SCALE;
			arenaV8.scale.y = ARENA_SCALE;
		}
		for (fv in fvs) {
			if (fv.holder != null)
				continue;
			var f = fv.fighter;
			var look = f.isPet() ? Actors.petLook(f.pet, f.team) : Actors.bruteLook(f.brute, f.team, f.shield);
			var scale = f.isPet() ? Actors.petScale(f.pet) : f.size();
			fv.holder = actors.holder(look, fv.speedRef, scale);
			if (fv.holder == null)
				return;
			fv.holderFacesRight = f.team == 0;
			fv.shownKey = "";
			arenaV8.addChild(fv.holder.container);
		}
		// the heads of the HUD: the brute from its shoulders up, in the windows of the band
		if (hudV8 == null) {
			hudV8 = actors.layer();
			for (side in sides) {
				var box = new V8Container();
				box.x = headX(side);
				box.y = HEAD_TOP;
				var mask = new V8Graphics();
				mask.rect(0, 0, HEAD_W, HEAD_H).fill(0xFFFFFF);
				box.addChild(mask);
				box.mask = mask;
				var f = side.fv.fighter;
				var h = actors.holder(Actors.bruteLook(f.brute, f.team, false, true), {current: 1.0}, HEAD_SCALE);
				if (h != null) {
					h.container.x = HEAD_W / 2 + (side.right ? -HEAD_DX : HEAD_DX);
					// (until its pose is measured: hidden under the window)
					h.container.y = 1000;
					box.addChild(h.container);
				}
				side.portrait = h;
				side.portraitBox = box;
				hudV8.addChild(box);
			}
		}
		for (side in sides) {
			if (side.portrait != null && !side.portraitReady && side.portrait.loaded) {
				side.portraitReady = true;
				side.portrait.setAnimation("idle");
				side.portrait.pause();
			}
			// (still, like the profile of LaBrute: the top of its head HEAD_GAP under the top of the window, whatever its
			// size and its look; measured once its pose is drawn)
			if (side.portraitReady && !side.portraitFitted) {
				var c = side.portrait.container;
				var b = c.getLocalBounds();
				if (b.maxY - b.minY > 1) {
					side.portraitFitted = true;
					c.y = HEAD_GAP - b.minY * c.scale.y;
					c.x = HEAD_W / 2 - (b.minX + b.maxX) / 2 * c.scale.x + (side.right ? -HEAD_DX : HEAD_DX);
					actors.outline(c, HEAD_OUTLINE);
					side.portraitCacheIn = HEAD_CACHE_RENDERS;
				}
			}
			// (a few pictures later: all its parts drawn)
			if (side.portraitCacheIn > 0 && --side.portraitCacheIn == 0)
				side.portraitBox.cacheAsTexture(true);
		}
	}

	// ---------------------------------------------------------------- every picture

	public function render(now:Float, mx:Float, my:Float, live:Bool):Void {
		if (!built)
			build();
		if (fontEpoch != Skin.epoch) {
			fontEpoch = Skin.epoch;
			// (a new array: the texts are drawn again)
			for (n in names)
				n.style.fontFamily = Ui.TITLE.copy();
			banner.style.fontFamily = Ui.TITLE.copy();
		}
		ensureHolders();
		// the steps started since the last picture; after a jump of the game, the old ones without their effects (the
		// effects of the recent ones are made at their moment: the picture is the same as if the fight had been played)
		while (applied < screen.cur) {
			applied++;
			var s = steps[applied];
			applyStep(applied, s, s.start + s.dur + EFFECT_FRAMES >= now);
		}
		for (fv in fvs)
			drawFighter(fv, now);
		drawEffects(now);
		drawHud(now);
	}

	// the place on the ground at a moment (the height of a jump apart: lift)
	// the part of a move of a fighter at a moment (null: none)
	static function segAt(fv:FV, now:Float):Seg {
		var i = fv.segs.length - 1;
		while (i >= 0) {
			var s = fv.segs[i];
			if (now >= s.start && now < s.start + s.dur)
				return s;
			i--;
		}
		return null;
	}

	// the shake of a blow taken (LaBrute's _staggerObject: +8, -4, +4, -4, +4, -8 pixels in 10 %, 10 %, 10 %, 10 %, 20 %, 20 %
	// of its time, back in the last 20 %)
	static var WOBBLE_T = [0, 0.1, 0.2, 0.3, 0.4, 0.6, 0.8, 1];
	static var WOBBLE_X = [0, 8, 4, 8, 4, 8, 0, 0];

	static function wobble(fv:FV, now:Float):Float {
		if (fv.wobStart < 0 || now < fv.wobStart || now >= fv.wobStart + fv.wobDur)
			return 0;
		var u = (now - fv.wobStart) / fv.wobDur;
		for (k in 1...WOBBLE_T.length)
			if (u < WOBBLE_T[k]) {
				var p = (u - WOBBLE_T[k - 1]) / (WOBBLE_T[k] - WOBBLE_T[k - 1]);
				return WOBBLE_X[k - 1] + (WOBBLE_X[k] - WOBBLE_X[k - 1]) * p;
			}
		return 0;
	}

	function posAt(fv:FV, now:Float):{x:Float, y:Float} {
		var s = segAt(fv, now);
		if (s != null) {
			var e = s.at(now);
			return {x: s.x0 + (s.x1 - s.x0) * e, y: s.y0 + (s.y1 - s.y0) * e};
		}
		if (fv.restAt >= 0 && now >= fv.restAt)
			return {x: fv.restX, y: fv.restY};
		if (fv.moveDur > 0 && now < fv.moveStart + fv.moveDur) {
			var u = (now - fv.moveStart) / fv.moveDur;
			if (u < 0)
				u = 0;
			var e = u * u * (3 - 2 * u);
			return {x: fv.fromX + (fv.toX - fv.fromX) * e, y: fv.fromY + (fv.toY - fv.fromY) * e};
		}
		return {x: fv.toX, y: fv.toY};
	}

	function lift(fv:FV, now:Float):Float {
		var s = segAt(fv, now);
		if (s != null) {
			var e = s.at(now);
			return s.up0 + (s.up1 - s.up0) * e + (s.shake != 0 ? Math.sin(now * 2.2) * s.shake : 0);
		}
		if (fv.arc == 0 || fv.moveDur <= 0 || now >= fv.moveStart + fv.moveDur || now < fv.moveStart)
			return 0;
		var u = (now - fv.moveStart) / fv.moveDur;
		return fv.arc * 4 * u * (1 - u);
	}

	// the move queued after the first one (back home)
	function settle(fv:FV, now:Float):Void {
		if (fv.backAt >= 0 && now >= fv.backAt) {
			var p = posAt(fv, fv.backAt);
			fv.fromX = p.x;
			fv.fromY = p.y;
			fv.toX = fv.homeX;
			fv.toY = fv.homeY;
			fv.moveStart = fv.backAt;
			fv.moveDur = fv.backDur;
			fv.arc = 0;
			fv.backAt = -1;
		}
	}

	function drawFighter(fv:FV, now:Float):Void {
		settle(fv, now);
		var p = posAt(fv, now);
		fv.x = p.x;
		fv.y = p.y;
		var up = lift(fv, now);
		var visible = fv.visibleAt(now);
		fv.speedRef.current = now < fv.fastUntil ? Balance.THROWN_SPEED : Balance.FIGHT_SPEED;

		var h = fv.holder;
		var loaded = h != null && h.loaded;
		if (h != null) {
			var seg = segAt(fv, now);
			h.container.visible = visible;
			h.container.x = fv.x + wobble(fv, now);
			// (upside down: turned over its feet, its head where its feet were)
			var upside = seg != null && seg.upsideDown;
			h.container.y = fv.y - up - (upside ? fv.baseHeight : 0);
			h.container.zIndex = seg != null && seg.z != null ? seg.z : up > 0 ? 1000 : fv.y;
			var facing = now < fv.faceUntil ? fv.faceBefore : fv.facesRight;
			var right = seg != null && seg.flip ? !facing : facing;
			if (now >= fv.turnStart && now < fv.turnUntil)
				right = !right;
			if (right != fv.holderFacesRight) {
				h.container.scale.x = -h.container.scale.x;
				fv.holderFacesRight = right;
			}
			var sy = Math.abs(h.container.scale.y);
			h.container.scale.y = upside ? -sy : sy;
			var weapon = now < fv.weaponUntil ? fv.weaponBefore : fv.weapon;
			h.weapon = weapon >= 0 ? Data.weaponId(weapon).name : null;
			h.shield = fv.shield;
			h.container.alpha = 1;
			h.container.tint = seg != null && seg.tint >= 0 ? seg.tint : fv.hypnotized && !fv.dead ? 0xD8A8F0 : 0xFFFFFF;
			if (loaded) {
				var a = animAt(fv, now);
				var stepAnim = a != null;
				var caught = fv.trapped && now >= fv.trappedAt;
				// (a brute stunned: down on a knee, LaBrute's « death » until it wakes up)
				var name = fv.dead ? "death" : stepAnim ? a.name : caught ? "trapped" : fv.stunned
					&& fv.pet == null ? "death" : fv.winner ? "win" : "idle";
				var key = name + "#" + (stepAnim && !fv.dead ? a.serial : -1);
				if (key != fv.shownKey) {
					fv.shownKey = key;
					h.setAnimation(supported(fv, name), stepAnim ? a.frame : 0);
					// (a hand raised: held on its picture)
					if (stepAnim && a.hold)
						h.pause();
					else
						h.play();
				}
				if (fv.pet == null)
					shadow(fv, h, upside ? 0 : up);
				ghosts(fv, h, now);
			}
		}

		// a simple shape without PixiJS 8 only (else nothing until the fighter is loaded)
		if (fv.ph == null) {
			fv.ph = new Graphics();
			floor.addChild(fv.ph);
		}
		fv.ph.visible = visible && !loaded && Actors.failed();
		if (fv.ph.visible) {
			var g = fv.ph;
			g.clear();
			var c = fv.team == 0 ? 0x3366CC : 0xCC3333;
			g.beginFill(0x000000, 0.25);
			g.drawEllipse(fv.x, fv.y, fv.baseWidth * 0.35, 5);
			g.endFill();
			g.lineStyle(2, Col.INK, 1);
			g.beginFill(fv.dead ? 0x777777 : c, 1);
			var y = fv.y - up;
			if (fv.pet != null) {
				g.drawEllipse(fv.x, y - fv.baseHeight * 0.4, fv.baseWidth * 0.4, fv.baseHeight * 0.3);
			} else if (fv.dead) {
				g.drawRoundedRect(fv.x - fv.baseHeight * 0.4, y - 14, fv.baseHeight * 0.8, 12, 5);
			} else {
				g.drawRoundedRect(fv.x - 12, y - fv.baseHeight * 0.8, 24, fv.baseHeight * 0.8, 8);
				g.drawCircle(fv.x, y - fv.baseHeight * 0.85, 10);
			}
			g.endFill();
		}
	}

	// the shadow of a brute (labrute-pixi-fighter's, hidden until it is told the brute is on the ground; its blur drawn
	// once): on the ground under it, smaller and fainter the higher it is (LaBrute's updateShadow)
	function shadow(fv:FV, h:V8FighterHolder, up:Float):Void {
		if (!fv.shadowShown) {
			fv.shadowShown = true;
			h.setAirborn(false);
			// (its blurred ellipse: a soft one instead, its blur filter draws nothing here)
			var sp:Dynamic = h.shadow.children[0];
			if (sp != null) {
				sp.filters = null;
				sp.texture = game.actors.softShadow();
			}
		}
		// (dead: fainter and smaller, LaBrute's death)
		if (fv.dead) {
			h.shadow.y = 0;
			h.shadow.alpha = 0.8;
			h.shadow.scale.set(0.65, 0.7);
			return;
		}
		var reach = 100 * fv.baseWidth / 50;
		var fade = Math.max(0.2, Math.min(1, (reach - up) / reach));
		h.shadow.y = up / Math.abs(h.container.scale.y);
		h.shadow.alpha = fade;
		h.shadow.scale.set(0.5 + fade * 0.5, 0.5 + fade * 0.5);
	}

	// the pictures of a fighter around it or behind it, taken again at each picture: the green outline of the poison
	// (LaBrute's OutlineFilter, 1 pixel, dark green), the trail of « Brute féroce » (LaBrute's FierceBruteEffect: its last
	// TRAIL pictures behind it, the newest red, the oldest blue), until it is back and still
	static inline var TRAIL = 6;
	static inline var POISON_COLOR = 0x006400;

	function ghosts(fv:FV, h:V8FighterHolder, now:Float):Void {
		var actors = game.actors;
		// (its pictures without its shadow)
		var snapshot = (c:V8Container) -> {
			var shown = h.shadow.visible;
			h.shadow.visible = false;
			var shot = actors.snapshot(c);
			h.shadow.visible = shown;
			return shot;
		};
		if (now < fv.auraUntil && fv.visibleAt(now)) {
			var shot = snapshot(h.container);
			for (s in fv.aura)
				actors.dropSprite(s);
			fv.aura = [];
			if (shot != null)
				for (d in [
					[-1.0, 0.0],
					[1.0, 0.0],
					[0.0, -1.0],
					[0.0, 1.0],
					[-0.7, -0.7],
					[0.7, 0.7],
					[-0.7, 0.7],
					[0.7, -0.7]
				]) {
					var s = actors.ghost(arenaV8, shot, d[0], d[1], fv.aura.length == 0);
					s.tint = POISON_COLOR;
					s.zIndex = h.container.zIndex - 0.5;
					fv.aura.push(s);
				}
		} else if (fv.aura.length > 0) {
			for (s in fv.aura)
				actors.dropSprite(s);
			fv.aura = [];
		}
		var seg = segAt(fv, now);
		var moving = seg != null || (fv.moveDur > 0 && now < fv.moveStart + fv.moveDur) || fv.backAt >= 0;
		// (« Célérité »: its trail, yellow, while it rushes)
		var rushing = seg != null && seg.tint == HASTE_TINT;
		if (fv.trailShots.length == 0 && (fv.fierce || rushing))
			fv.trailFierce = fv.fierce;
		if (fv.fierce || rushing || (fv.trailShots.length > 0 && moving)) {
			// (a picture of it at each frame: the copies are it 1, 2... TRAIL frames ago)
			if (now - fv.trailAt >= 1) {
				fv.trailAt = now;
				var shot = snapshot(h.container);
				if (shot != null) {
					fv.trailShots.unshift(shot);
					while (fv.trailShots.length > TRAIL)
						dropShot(fv.trailShots.pop());
				}
			}
			while (fv.trail.length < fv.trailShots.length) {
				var s = new V8Sprite(fv.trailShots[fv.trail.length].tex);
				s.filters = [new V8ColorMatrixFilter()];
				arenaV8.addChild(s);
				fv.trail.push(s);
			}
			// (the newest one red, the oldest blue, saturated and brighter; « Célérité »: yellow; behind it)
			for (k in 0...fv.trail.length) {
				var s = fv.trail[k];
				var shot = fv.trailShots[k];
				s.visible = shot != null;
				if (shot == null)
					continue;
				untyped s.texture = shot.tex;
				s.scale.set(shot.sx, shot.sy);
				s.x = shot.x;
				s.y = shot.y;
				var u = k / (TRAIL - 1);
				var gains = fv.trailFierce ? [2.2 - 1.4 * u, 0.7, 0.8 + 1.4 * u] : [1.7, 1.6, 0.5];
					(untyped s.filters[0]).matrix = ghostMatrix(gains);
				s.alpha = 0.8 - 0.4 * u;
				s.zIndex = h.container.zIndex - 1 - k * 0.01;
			}
		} else if (fv.trail.length > 0 || fv.trailShots.length > 0) {
			for (s in fv.trail)
				actors.dropSprite(s);
			for (shot in fv.trailShots)
				dropShot(shot);
			fv.trail = [];
			fv.trailShots = [];
		}
	}

	static function dropShot(shot:{
		tex:Dynamic,
		x:Float,
		y:Float,
		sx:Float,
		sy:Float
	}):Void {
		try {
			shot.tex.destroy(true);
		} catch (e:Dynamic) {}
	}

	// a copy of the trail: half grey, each color by its gain, a little lighter (LaBrute's AdjustmentFilter, saturated)
	static function ghostMatrix(g:Array<Float>):Array<Float> {
		var m:Array<Float> = [];
		var lum = [0.3, 0.59, 0.11];
		for (c in 0...3) {
			for (k in 0...3)
				m.push(g[c] * ((c == k ? 0.5 : 0) + 0.5 * lum[k]));
			m.push(0);
			m.push(0.08);
		}
		m = m.concat([0, 0, 0, 1, 0]);
		return m;
	}

	// the animations of LaBrute a model has
	static function supported(fv:FV, name:String):String {
		if (fv.model == "dog" || fv.model == "bear") {
			if (PET_ANIMS.indexOf(name) >= 0)
				return name;
			if (name == "fist" || name == "slash" || name == "estoc" || name == "whip")
				return "attack";
			if (name.indexOf("hit") == 0)
				return "hit";
			return "idle";
		}
		if (name == "attack")
			return "fist";
		if (fv.model == "female" && name.indexOf("hit-") == 0)
			return "hit";
		if (fv.model == "male" && name == "hit")
			return "hit-0";
		return name;
	}

	// the HP of the sudden death not applied yet: up to the next Drain step only (none after the blow that decided the
	// fight: the HP stop there)
	function pendingDrain(fv:FV, now:Float):Int {
		if (!fv.present || fv.dead || applied < 0)
			return 0;
		var next = nextDrain[applied];
		if (next < 0)
			return 0;
		var over = Std.int(now) - Balance.TIMER_FRAMES;
		if (over <= 0)
			return 0;
		var d = Balance.drainTotal(over, screen.drainLevel) - Balance.drainTotal(lastDrain - Balance.TIMER_FRAMES, screen.drainLevel);
		var s = steps[next];
		var cap = 0;
		for (k in 0...s.targets.length)
			if (s.targets[k] == fv.index)
				cap = s.dmgs[k];
		return d < 0 ? 0 : d > cap ? cap : d;
	}

	function shownHp(fv:FV, now:Float):Int {
		var hp = fv.hp - pendingDrain(fv, now);
		for (e in fv.future)
			if (e.t > now)
				hp -= e.d;
		while (fv.future.length > 0 && fv.future[0].t < now - 300)
			fv.future.shift();
		return hp < 0 ? 0 : hp > fv.maxHp ? fv.maxHp : hp;
	}

	function drawHud(now:Float):Void {
		var g = hudG;
		g.clear();
		drawBand();
		for (side in sides) {
			var fv = side.fv;
			var hp = shownHp(fv, now);
			side.shownHp = hp;
			// the HP of the blows of the last moments, in a lighter color (from the time of the game: the same after a
			// jump in a replay)
			var recent = 0.0;
			for (b in side.blows)
				if (b.t <= now && now < b.t + PHANTOM_FRAMES)
					recent += b.d * Math.min(1, (b.t + PHANTOM_FRAMES - now) / (PHANTOM_FRAMES * 0.4));
			while (side.blows.length > 0 && side.blows[0].t + PHANTOM_FRAMES < now - 200)
				side.blows.shift();
			var x = side.right ? 600 - BAR_X - BAR_W : BAR_X;
			var ratio = Math.min(1, hp / fv.maxHp);
			var ghost = Math.min(1, (hp + recent) / fv.maxHp);
			g.lineStyle(1, Col.INK, 1, 1);
			g.beginFill(0x3A1E0C, 1);
			g.drawRoundedRect(x, BAR_Y, BAR_W, BAR_H, BAR_RADIUS);
			g.endFill();
			g.lineStyle(0, 0, 0);
			// (a piece of the bar, from its side: its corners rounded as far as its width allows)
			function piece(from:Float, to:Float, color:Int, ?alpha:Float = 1, ?h:Float = BAR_H, ?dy:Float = 0):Void {
				var w = BAR_W * (to - from);
				if (w <= 0)
					return;
				var px = side.right ? x + BAR_W * (1 - to) : x + BAR_W * from;
				g.beginFill(color, alpha);
				g.drawRoundedRect(px, BAR_Y + dy, w, h, Math.min(BAR_RADIUS, Math.min(w, h) / 2));
				g.endFill();
			}
			// the HP of the blows of the last moments in red, under the rest in yellow (from the side of the bar: no
			// corner where the HP left start)
			if (ghost > ratio)
				piece(0, ghost, 0xD32F2F);
			// (yellow, fading to orange toward its top and bottom edges: bands narrower and yellower toward its middle)
			if (ratio > 0)
				for (k in 0...BAR_GRADIENT.length)
					piece(0, ratio, BAR_GRADIENT[k], 1, BAR_H - k * 2, k);
			if (side.dirty)
				drawIcons(side);
			if (side.weaponRow != null)
				side.weaponRow.visible = now >= side.iconsHiddenUntil;
		}

		// the countdown (stopped at the end of the fight)
		var remaining = Balance.TIMER_FRAMES - Std.int(Math.min(now, steps[screen.endIndex].start));
		if (remaining < 0)
			remaining = 0;
		var secs = Math.ceil(remaining / Balance.FPS);
		timer.text = "0:" + (secs < 10 ? "0" : "") + secs;
		var over = remaining == 0 && applied < screen.endIndex;
		timer.tint = remaining == 0 ? 0xFF5544 : 0xFFFFFF;
		sudden.visible = over && (Std.int(now / 8) % 2 == 0);
		#if debug
		pointsText.text = screen.points > 0 ? "+" + Ui.num(screen.points) + Lang.t(" pts") : "";
		#end
	}

	// the supers it can still use
	static function usable(side:Side):Array<Perk> {
		return [for (p in side.supers) if (p.left > 0) p];
	}

	// the top left corner of an icon of the HUD (its row: 0 the weapons, 1 the supers)
	// (LaBrute: 11 by line, the weapons then the supers on the lines under them, as many as needed)
	function iconAt(side:Side, row:Int, i:Int):{x:Float, y:Float} {
		var perRow = Std.int(ICONS_W / (ICON + 2));
		var weaponLines = Std.int(Math.max(1, Math.ceil(side.weapons.length / perRow)));
		var line = (row == 0 ? 0 : weaponLines) + Std.int(i / perRow);
		var c = i % perRow;
		return {
			x: side.right ? 600 - ICONS_X - (c + 1) * (ICON + 2) + 2 : ICONS_X + c * (ICON + 2),
			y: ICONS_Y + line * (ICON + 2)
		};
	}

	// a super used: its picture in large over its icon, fading
	function superUsed(side:Side, p:Perk, start:Float):Void {
		var i = usable(side).indexOf(p);
		if (i < 0)
			return;
		var at = iconAt(side, 1, i);
		var sp = Sheets.fit(Sheets.sprite("tier-" + p.tier + "/" + Data.skillId(p.id).name + ".png"), ICON * SUPER_POP, ICON * SUPER_POP);
		var fx = addFx(sp, start, SUPER_POP_FRAMES, hudFx);
		fx.fromX = fx.toX = at.x + ICON / 2;
		fx.fromY = fx.toY = at.y + ICON / 2;
		fx.fade = true;
		fx.fadeFrom = 0;
		// (rising by its height: its bottom ends where its top started)
		fx.rise = ICON * SUPER_POP;
	}

	// the halo of a weapon of tier 2 or 3, centered on cx, cy: rings of black copies around its colored outline, the
	// outer ones first and fainter
	static function halo(into:Container, tex:Texture, cx:Float, cy:Float):Void {
		for (k in 0...HALO_W) {
			var ring = new Container();
			ring.alpha = HALO_ALPHA * (k + 1) / HALO_W;
			ring.filters = [Ui.solid(0x000000)];
			into.addChild(ring);
			var r = Ui.TIER_OUTLINE + HALO_W - k;
			for (d in 0...16) {
				var a = d * Math.PI / 8;
				var s = Sheets.fit(new Sprite(tex), ICON, ICON);
				s.anchor.set(0.5, 0.5);
				s.x = cx + Math.cos(a) * r;
				s.y = cy + Math.sin(a) * r;
				ring.addChild(s);
			}
		}
	}

	// the weapons it still has, not in hand, its supers it can still use and their tooltips
	function drawIcons(side:Side):Void {
		side.dirty = false;
		for (c in side.icons.children.copy())
			Ui.destroy(cast c);
		for (t in side.tips)
			screen.tips.remove(t);
		side.tips = [];
		// (the weapons and the supers apart: the weapons hidden alone while they fly, « Espion »)
		var weaponRow = new Container();
		var superRow = new Container();
		side.icons.addChild(weaponRow);
		side.icons.addChild(superRow);
		side.weaponRow = weaponRow;
		var halos = new Container();
		weaponRow.addChild(halos);
		var rows = [side.weapons, usable(side)];
		for (row in 0...2) {
			var list = rows[row];
			var into = row == 0 ? weaponRow : superRow;
			for (i in 0...list.length) {
				var p = list[i];
				var at = iconAt(side, row, i);
				var x = at.x;
				var y = at.y;
				var weapon = row == 0;
				// (a weapon: its outline of the color of its tier 2 or 3; a super: its picture has the color)
				if (weapon && p.tier >= 2)
					halo(halos, Sheets.tex("weapons/" + Data.weaponId(p.id).name + ".png"), x + ICON / 2, y + ICON / 2);
				if (weapon)
					Ui.perkIcon(into, "weapons/" + Data.weaponId(p.id).name + ".png", x + ICON / 2, y + ICON / 2, ICON, p.tier, 1, 0x000000);
				else {
					var icon = Sheets.fit(Sheets.sprite("tier-" + p.tier + "/" + Data.skillId(p.id).name + ".png"), ICON, ICON);
					icon.x = x + ICON / 2;
					icon.y = y + ICON / 2;
					into.addChild(icon);
				}
				var name = weapon ? Data.weaponId(p.id).name : Data.skillId(p.id).name;
				var tier = p.tier;
				var tip:Tip = {
					x: x,
					y: y,
					w: ICON,
					h: ICON,
					key: (weapon ? "hw" : "hs") + name + tier,
					make: weapon ? () -> Describe.weapon(name, tier) : () -> Describe.skill(name, tier)
				};
				side.tips.push(tip);
				screen.tips.push(tip);
			}
		}
		// (still until they change: drawn once into a picture, not their outlines (filters) at each frame; not empty)
		weaponRow.cacheAsBitmap = weaponRow.children.length > 1;
		superRow.cacheAsBitmap = superRow.children.length > 0;
	}

	// ---------------------------------------------------------------- effects

	function addFx(obj:DisplayObject, start:Float, dur:Float, ?parent:Container):Fx {
		var fx = new Fx(obj, start, dur);
		obj.visible = false;
		(parent != null ? parent : fxLayer).addChild(obj);
		effects.push(fx);
		return fx;
	}

	function drawEffects(now:Float):Void {
		var i = 0;
		while (i < effects.length) {
			var fx = effects[i];
			var u = (now - fx.start) / fx.dur;
			if (u >= 1 && fx.stay && (fx.until < 0 || now < fx.until))
				u = 1;
			else if (u >= 1) {
				Ui.destroy(cast fx.obj);
				effects.splice(i, 1);
				continue;
			}
			i++;
			if (u < 0) {
				fx.obj.visible = false;
				continue;
			}
			fx.obj.visible = true;
			if (fx.bounce) {
				bounceAt(fx, u * fx.dur);
				continue;
			}
			fx.obj.x = fx.fromX + (fx.toX - fx.fromX) * u;
			fx.obj.y = fx.fromY + (fx.toY - fx.fromY) * u - fx.arc * 4 * u * (1 - u) - fx.rise * u;
			if (fx.spin != 0)
				fx.obj.rotation = fx.spin * u;
			if (fx.frames != null) {
				var k = fx.loopRate > 0 ? Std.int((now - fx.start) * fx.loopRate) % fx.frames.length : Std.int(u * fx.frames.length);
				if (k >= fx.frames.length)
					k = fx.frames.length - 1;
						(cast fx.obj : Sprite).texture = fx.frames[k];
			}
			if (fx.fade)
				fx.obj.alpha = u < fx.fadeFrom ? 1 : (1 - u) / (1 - fx.fadeFrom);
			else if (fx.fadeIn > 0)
				fx.obj.alpha = 1;
			if (fx.fadeIn > 0 && u < fx.fadeIn)
				fx.obj.alpha = Math.min(fx.obj.alpha, u / fx.fadeIn);
			if (fx.scale0 > 0) {
				var k = fx.scale0 + (fx.scale1 - fx.scale0) * (1 - (1 - u) * (1 - u));
				fx.obj.scale.set(k, k);
			}
		}
	}

	// a number over a fighter (the damage, the HP healed)
	// (in the font of the buttons, bold)
	function floating(fv:FV, s:String, color:Int, size:Float, start:Float, ?dur:Float = 26):Void {
		var t = Ui.title(Ui.text(s, size, color, "center", Col.INK));
		t.style.fontWeight = "bold";
		t.anchor.set(0.5, 1);
		var fx = addFx(t, start, dur);
		fx.fromX = fx.toX = fv.x + (vr.rand() - 0.5) * 16;
		fx.fromY = fx.toY = fv.y - fv.baseHeight - 4;
		fx.rise = 22;
		fx.fade = true;
	}

	// the gold of a bonus, where it is won
	function goldFx(fv:FV, amount:Int, start:Float):Void {
		var c = new Container();
		Ui.gold(c, 0, 0, "+" + amount, 15, Col.GOLD, Col.INK, 0.5);
		// (above the number of the damage of the same blow, a little after it: not under it)
		var fx = addFx(c, start + GOLD_DELAY, 44);
		fx.fromX = fx.toX = fv.x;
		fx.fromY = fx.toY = fv.y - fv.baseHeight - GOLD_ABOVE;
		fx.rise = 30;
		fx.fade = true;
	}

	function animFx(prefix:String, count:Int, x:Float, y:Float, start:Float, dur:Float, ?scale:Float = 1, ?pad:Int = 0, ?parent:Container):Fx {
		var frames = Sheets.frames(prefix, count, ".png", pad);
		var sp = new Sprite(frames[0]);
		sp.anchor.set(0.5, 0.5);
		sp.scale.set(scale, scale);
		var fx = addFx(sp, start, dur, parent);
		fx.frames = frames;
		fx.fromX = fx.toX = x;
		fx.fromY = fx.toY = y;
		return fx;
	}

	function projectile(texture:String, fx0:Float, fy0:Float, fx1:Float, fy1:Float, start:Float, dur:Float, ?arc:Float = 0, ?spin:Float = 0, ?scale:Float = 1,
			?flip:Bool = false):Void {
		var sp = Sheets.sprite(texture);
		sp.scale.set(flip ? -scale : scale, scale);
		var fx = addFx(sp, start, dur);
		fx.fromX = fx0;
		fx.fromY = fy0;
		fx.toX = fx1;
		fx.toY = fy1;
		fx.arc = arc;
		fx.spin = spin;
	}

	// a weapon (or a shield) lost behind its owner: it falls, bounces a little, lies on the floor, then fades
	// (fast: thrown straight and fast behind it, LaBrute's broken shield: then it lies and fades)
	function falling(texture:String, x:Float, y:Float, start:Float, dir:Float, ?fast:Bool = false):Void {
		if (fast) {
			// (out of the arena)
			var fly = Sheets.sprite(texture);
			var fx = addFx(fly, start, FAST_FALL_FRAMES);
			fx.fromX = x;
			fx.fromY = y - 20;
			fx.toX = x + dir * 700;
			fx.toY = y - 60;
			fx.arc = 20;
			fx.spin = dir * 12;
			return;
		}
		var sp = Sheets.sprite(texture);
		var fx = addFx(sp, start, FALL_FRAMES + BOUNCE_FRAMES + LIE_FRAMES + FADE_FRAMES);
		fx.fromX = x;
		fx.fromY = y - 40;
		fx.toX = x + dir * 30;
		fx.toY = y;
		fx.arc = 30;
		fx.spin = dir * 6;
		fx.bounce = true;
	}

	// its place, its turn, its opacity at frame k of its effect
	static function bounceAt(fx:Fx, k:Float):Void {
		var o = fx.obj;
		var dx = fx.toX - fx.fromX;
		if (k < FALL_FRAMES) {
			// the fall, on an arc, 80 % of its way
			var p = k / FALL_FRAMES;
			o.x = fx.fromX + dx * 0.8 * p;
			o.y = fx.fromY + (fx.toY - fx.fromY) * p - fx.arc * 4 * p * (1 - p);
			o.rotation = fx.spin * p;
		} else if (k < FALL_FRAMES + BOUNCE_FRAMES) {
			// a little bounce, the rest of its way
			var q = (k - FALL_FRAMES) / BOUNCE_FRAMES;
			o.x = fx.fromX + dx * (0.8 + 0.2 * q);
			o.y = fx.toY - BOUNCE_HEIGHT * 4 * q * (1 - q);
			o.rotation = fx.spin * (1 + 0.15 * q);
		} else {
			o.x = fx.toX;
			o.y = fx.toY;
			o.rotation = fx.spin * 1.15;
		}
		var fade = k - (FALL_FRAMES + BOUNCE_FRAMES + LIE_FRAMES);
		o.alpha = fade <= 0 ? 1 : Math.max(0, 1 - fade / FADE_FRAMES);
	}

	// confetti on the winner, that stay on the ground
	// (the frames `confetti-1`, `confetti-2`... of the skin, played while they fall; none without them)
	function confetti(fv:FV, start:Float):Void {
		var frames = Skin.frames("confetti");
		if (frames.length == 0)
			return;
		for (k in 0...40) {
			var sp = Sheets.fit(new Sprite(frames[0]), 12, 12);
			sp.anchor.set(0.5, 0.5);
			// (white pictures take the color)
			sp.tint = CONFETTI[vr.random(CONFETTI.length)];
			var fx = addFx(sp, start + vr.random(24), 44 + vr.random(44));
			fx.frames = frames;
			fx.fromX = fv.x + (vr.rand() - 0.5) * 110;
			fx.fromY = fv.y - fv.baseHeight - 70 - vr.rand() * 60;
			fx.toX = fx.fromX + (vr.rand() - 0.5) * 30;
			fx.toY = fv.y - 6 + (vr.rand() - 0.5) * 16;
			fx.spin = (vr.rand() - 0.5) * 14;
			fx.stay = true;
		}
	}

	// ---------------------------------------------------------------- the steps

	function snapshot():{fvs:Array<FVState>, sides:Array<{weapons:Array<Perk>, supers:Array<Perk>}>} {
		return {
			fvs: [
				for (fv in fvs) {
					var s = new FVState();
					s.x = fv.toX;
					s.y = fv.toY;
					s.homeX = fv.homeX;
					s.homeY = fv.homeY;
					s.present = fv.present;
					s.leaveAt = fv.leaveAt;
					s.dead = fv.dead;
					s.trapped = fv.trapped;
					s.stunned = fv.stunned;
					s.hypnotized = fv.hypnotized;
					s.fierce = fv.fierce;
					s.hp = fv.hp;
					s.weapon = fv.weapon;
					s.shield = fv.shield;
					s.team = fv.team;
					s.facesRight = fv.facesRight;
					s;
				}
			],
			sides: [for (side in sides) side.save()]
		};
	}

	function restore(state:{fvs:Array<FVState>, sides:Array<{weapons:Array<Perk>, supers:Array<Perk>}>}):Void {
		for (i in 0...fvs.length) {
			var fv = fvs[i];
			var s = state.fvs[i];
			fv.toX = fv.fromX = s.x;
			fv.toY = fv.fromY = s.y;
			fv.moveDur = 0;
			fv.backAt = -1;
			fv.homeX = s.homeX;
			fv.homeY = s.homeY;
			fv.present = s.present;
			fv.leaveAt = s.leaveAt;
			fv.dead = s.dead;
			fv.trapped = s.trapped;
			fv.stunned = s.stunned;
			fv.hypnotized = s.hypnotized;
			fv.fierce = s.fierce;
			fv.hp = s.hp;
			fv.weapon = s.weapon;
			fv.shield = s.shield;
			fv.team = s.team;
			fv.facesRight = s.facesRight;
			fv.anims = [];
			fv.segs = [];
			fv.restAt = -1;
			fv.wobStart = -1;
		}
		for (i in 0...sides.length)
			sides[i].load(state.sides[i]);
	}

	// (frame: the picture it starts at, LaBrute's setAnimation(name, frame))
	function setAnim(fv:FV, name:String, start:Float, dur:Float, ?frame:Int = 0, ?hold:Bool = false):Void {
		animSerial++;
		fv.anims.push({
			name: name,
			start: start,
			until: start + (dur < 6 ? 6 : dur),
			frame: frame,
			serial: animSerial,
			hold: hold
		});
		// (the old ones forgotten)
		if (fv.anims.length > 12)
			fv.anims.shift();
	}

	// the animation of a step a fighter plays at a moment (null: its own)
	static function animAt(fv:FV, now:Float):Anim {
		var best:Anim = null;
		for (a in fv.anims)
			if (now >= a.start && now < a.until && (best == null || a.start >= best.start))
				best = a;
		return best;
	}

	// a part of a multi-phase move (Seg), from x0, y0 to x1, y1 on the ground, lifted from up0 to up1; the fighter stays at
	// its end after it
	function seg(fv:FV, start:Float, dur:Float, x0:Float, y0:Float, x1:Float, y1:Float, ?up0:Float = 0, ?up1:Float = 0, ?ease:Int = 0):Seg {
		var s = new Seg(start, dur, x0, y0, x1, y1);
		s.up0 = up0;
		s.up1 = up1;
		s.ease = ease;
		fv.segs.push(s);
		if (start + dur >= fv.restAt) {
			fv.restX = x1;
			fv.restY = y1;
			fv.restAt = start + dur;
		}
		return s;
	}

	// a knockback away from its opponents, kept in the arena (LaBrute's getRealKnockBack)
	function realKnockBack(fv:FV, x:Float, d:Float):Float {
		var margin = fv.baseWidth / 2 + 2;
		if (fv.team == 0)
			return -Math.max(0, Math.min(x - margin, d));
		return Math.max(0, Math.min(500 - x - margin, d));
	}

	// the knockback of a blow (LaBrute's getHitKnockBack): by its damage against the HP of the target, more on a critical
	// hit; a blow on its own side (a counter): none, but far for a stun (chaining)
	function hitKnockBack(f:FV, t:FV, damage:Int, crit:Bool, stun:Bool):Float {
		var d = 0.0;
		var side = f != null ? (f.x > 250 ? 1 : 0) : -1;
		var own = f != null && f.team == side && (t.x > 250 ? 1 : 0) == side;
		if (!own) {
			var fifth = t.maxHp * 0.2;
			d = damage > fifth ? 16 * (1 + (damage - fifth) / (t.maxHp * 0.8)) : 16 * (damage / fifth);
			if (d < 1)
				d = 2;
			d = Math.min(32, d);
		} else if (stun)
			d = 65;
		return d + (crit ? 12 : 0);
	}

	// a blow taken: pushed back by kb, shaken (LaBrute's stagger, STAGGER_SECONDS)
	function stagger(fv:FV, kb:Float, start:Float, ?dur:Float = -1):Void {
		if (dur < 0)
			dur = frames(STAGGER_SECONDS);
		var p = posAt(fv, start);
		var d = realKnockBack(fv, p.x, kb);
		if (d != 0)
			moveTo(fv, p.x + d, p.y, start, dur);
		fv.wobStart = start;
		fv.wobDur = dur;
	}

	// a jump back (LaBrute's jumpBack: an evasion, the end of the hammer), as high as half its height (80 at most)
	function jumpBack(fv:FV, dist:Float, start:Float, dur:Float):Void {
		var p = posAt(fv, start);
		var d = realKnockBack(fv, p.x, dist);
		var high = Math.min(80, fv.baseHeight * 0.5);
		seg(fv, start, dur / 2, p.x, p.y, p.x + d / 2, p.y, 0, high, 2);
		seg(fv, start + dur / 2, dur / 2, p.x + d / 2, p.y, p.x + d, p.y, high, 0, 1);
		setAnim(fv, "evade", start, dur);
	}

	// LaBrute's seconds at speed 1 in frames of the fight
	static inline function frames(seconds:Float):Float {
		return seconds * Balance.FPS / Balance.FIGHT_SPEED;
	}

	function moveTo(fv:FV, x:Float, y:Float, start:Float, dur:Float, ?arc:Float = 0):Void {
		var p = posAt(fv, start);
		fv.restAt = -1;
		fv.fromX = p.x;
		fv.fromY = p.y;
		fv.toX = x;
		fv.toY = y;
		fv.moveStart = start;
		fv.moveDur = dur;
		fv.arc = arc;
		fv.backAt = -1;
	}

	// a move there and back home
	function dash(fv:FV, x:Float, y:Float, start:Float, dur:Float, ?arc:Float = 0):Void {
		moveTo(fv, x, y, start, dur * 0.45, arc);
		fv.backAt = start + dur * 0.55;
		fv.backDur = dur * 0.45;
	}

	function hitDistance(f:FV, t:FV):Float {
		var reach = f.weapon >= 0 ? Data.weaponId(f.weapon).reach : 0;
		return f.baseWidth * 0.5 + t.baseWidth * 0.5 + reach * 16;
	}

	function home(fv:FV):Void {
		var left = fv.facesRight;
		var minX = left ? 40.0 : 460.0;
		var maxX = left ? 125.0 : 375.0;
		var factor = 0.4 + vr.rand() * 0.6;
		fv.homeX = minX + factor * (maxX - minX);
		// the place of the side farthest from the fighters already there
		var best = 228.0;
		var bestGap = -1.0;
		for (k in 0...8) {
			var y = 178 + k * 14 + vr.rand() * 8;
			var gap = 1000.0;
			for (o in fvs)
				if (o != fv && o.present && !o.dead && o.facesRight == fv.facesRight) {
					var d = Math.abs(o.homeY - y);
					if (d < gap)
						gap = d;
				}
			if (gap > bestGap) {
				bestGap = gap;
				best = y;
			}
		}
		fv.homeY = best;
	}

	function hitAnim(fv:FV):String {
		return fv.model == "male" ? "hit-" + vr.random(3) : "hit";
	}

	function attackAnim(fv:FV, weapon:Int):String {
		if (fv.pet != null)
			return "attack";
		return weapon >= 0 ? Data.weaponId(weapon).animation : "fist";
	}

	// a fighter caught in the net is freed by a blow (a brute is stunned by it): the pieces of the net fly away
	function untrap(fv:FV, start:Float, live:Bool):Void {
		if (!fv.trapped)
			return;
		fv.trapped = false;
		if (fv.pet == null)
			fv.stunned = true;
		if (!live)
			return;
		for (k in 0...5) {
			var dir = vr.rand() * 2 - 1;
			projectile("net-part.png", fv.x + dir * 12, fv.y - fv.baseHeight * 0.5, fv.x + dir * 50, fv.y - 4, start, 18, 26 + vr.rand() * 20, dir * 8, 0.8);
		}
	}

	// damage on a fighter at a moment (its number, its animation, an impact; « Increvable »: its picture now), waking it up
	function hurt(fv:FV, damage:Int, start:Float, live:Bool, ?crit:Bool = false, ?color:Int = 0xFFFFFF, ?impact:Bool = true):Void {
		fv.hp -= damage;
		fv.future.push({t: start, d: -damage});
		fv.stunned = false;
		if (damage > 0)
			untrap(fv, start, live);
		var resist = fv.resist;
		fv.resist = false;
		if (!live)
			return;
		if (resist)
			animFx("resist/", 8, fv.x + (fv.team == 0 ? -10 : 10), fv.y - fv.baseHeight * 0.36, start, RESIST_FRAMES);
		var side = sideOf(fv.index);
		// (the red of the bar from its HP before the blow, not further: a killing blow takes only what was left)
		if (side != null && damage > 0)
			side.blows.push({t: start, d: Std.int(Math.min(damage, Math.max(0, fv.hp + damage)))});
		setAnim(fv, hitAnim(fv), start, 8);
		floating(fv, "-" + damage, crit ? 0xFF4433 : color, crit ? 24 : 19, start);
		if (impact)
			animFx("impact-1/", 13, fv.x, fv.y - fv.baseHeight * 0.55, start, 12, 0.8);
	}

	function heal(fv:FV, amount:Int, start:Float, live:Bool):Void {
		var before = fv.hp;
		fv.hp += amount;
		if (fv.hp > fv.maxHp)
			fv.hp = fv.maxHp;
		fv.future.push({t: start, d: fv.hp - before});
		if (live && amount > 0)
			floating(fv, "+" + amount, 0x55EE55, 19, start);
	}

	// « Voleur » (LaBrute's steal): a quick jump onto the shoulders of the target (behind it, turned), the robbed one holds
	// its weapon up, both shake, the thief takes it and jumps back to its place
	function thief(f:FV, t:FV, w:Int, st:Float, dur:Float):Void {
		var p = posAt(f, st);
		var tp = posAt(t, st);
		var jump = dur * 0.12;
		var hold = dur - jump * 4;
		var high = Data.BRUTE_HEIGHT / 2;
		var z = tp.y - 1;
		var mx = (p.x + tp.x) / 2;
		var my = (p.y + tp.y) / 2;
		seg(f, st, jump, p.x, p.y, mx, my, 0, high + 10, 1).z = z;
		seg(f, st + jump, jump, mx, my, tp.x, tp.y, high + 10, high).z = z;
		var on = seg(f, st + jump * 2, hold, tp.x, tp.y, tp.x, tp.y, high, high);
		on.z = z;
		on.flip = true;
		on.shake = 1.2;
		seg(t, st + jump * 2, hold, tp.x, tp.y, tp.x, tp.y).shake = 1;
		var back = st + jump * 2 + hold;
		var bx = (tp.x + f.homeX) / 2;
		var by = (tp.y + f.homeY) / 2;
		seg(f, back, jump, tp.x, tp.y, bx, by, high, high + 10, 1).flip = true;
		seg(f, back + jump, jump, bx, by, f.homeX, f.homeY, high + 10, 0).flip = true;
		setAnim(f, "evade", st, jump * 2);
		setAnim(f, "steal", st + jump * 2, hold);
		setAnim(f, "evade", back, jump * 2);
		setAnim(t, "stolen", st + jump * 2, hold);
		// (the weapon changes hands at the end)
		t.weaponBefore = w;
		t.weaponUntil = back;
		f.weaponBefore = f.weapon;
		f.weaponUntil = back;
		t.weapon = -1;
		f.weapon = w;
		t.stunned = false;
	}

	// « Vampirisme »: a quick dash behind the target, the bite (its head shakes), back as quickly
	function vampire(f:FV, t:FV, s:Step, st:Float, dur:Float, live:Bool):Void {
		var p = posAt(f, st);
		var tp = posAt(t, st);
		var dash = dur * 0.154;
		var hold = dur - dash * 2;
		var bx = t.team == 1 ? tp.x + t.baseWidth / 2 : tp.x - t.baseWidth / 2;
		var z = tp.y - 1;
		seg(f, st, dash, p.x, p.y, bx, tp.y - 1).z = z;
		var bite = seg(f, st + dash, hold, bx, tp.y - 1, bx, tp.y - 1);
		bite.z = z;
		bite.flip = true;
		bite.shake = 1.5;
		// (back as it came, its back to the target)
		seg(f, st + dash + hold, dash, bx, tp.y - 1, f.homeX, f.homeY).flip = true;
		setAnim(f, "evade", st, dash);
		setAnim(f, "steal", st + dash, hold);
		setAnim(f, "evade", st + dash + hold, dash);
		if (t.pet == null)
			setAnim(t, "stolen", st + dash, hold);
		hurt(t, s.d, st + dash, live, false, 0xFFFFFF, false);
		// (its HP healed where it bites)
		var fx0 = f.x;
		var fy0 = f.y;
		f.x = bx;
		f.y = tp.y;
		heal(f, s.h, st + dash, live);
		f.x = fx0;
		f.y = fy0;
		if (live)
			animFx("blood/", 15, tp.x, tp.y - t.baseHeight * 0.7, st + dash, 18, 0.7);
	}

	// « Célérité »: winds up, rushes through the target (yellow, its trail behind it) and out of the arena on the other
	// side, then runs back to its place from its own side
	static inline var HASTE_TINT = 0xFFFF70;

	function haste(f:FV, t:FV, s:Step, st:Float, dur:Float, live:Bool):Void {
		var p = posAt(f, st);
		var tp = posAt(t, st);
		var wind = dur * 0.3;
		var rush = dur * 0.13;
		var through = dur * 0.07;
		var back = dur - wind - rush - through;
		setAnim(f, "strengthen", st, wind);
		var a = seg(f, st + wind, rush, p.x, p.y, tp.x, tp.y);
		a.tint = HASTE_TINT;
		var hit = st + wind + rush;
		var past = tp.x + (t.team == 0 ? -200 : 200);
		seg(f, hit, through, tp.x, tp.y, past, tp.y).tint = HASTE_TINT;
		var out = f.team == 0 ? -f.baseWidth * 2 : 500 + f.baseWidth * 2;
		seg(f, hit + through, back, out, f.homeY, f.homeX, f.homeY);
		setAnim(f, "run", st + wind, rush + through + back);
		hurt(t, s.d, hit, live, s.crit);
		stagger(t, s.crit ? 12 : 0, hit);
	}

	// « Marteau-pilon » (LaBrute's hammer): both pushed back, then up to the top of the arena, the brute turning around the
	// other one (changing sides three times), both upside down, down very fast onto their heads
	function hammer(f:FV, t:FV, s:Step, st:Float, dur:Float, live:Bool):Void {
		var p = posAt(f, st);
		var tp = posAt(t, st);
		var push = realKnockBack(t, tp.x, 30);
		var top = f.baseHeight * 0.2;
		var rise = Math.max(0, p.y - top);
		var riseT = Math.max(0, tp.y - top);
		var pushT = frames(0.16);
		var jump = frames(0.0032 * rise);
		var drop = jump * 0.38;
		// (in the time of its step)
		var k = Math.min(1, dur * 0.9 / (pushT + jump + drop));
		pushT *= k;
		jump *= k;
		drop *= k;
		var fx0 = p.x + push;
		var tx = tp.x + push;
		seg(f, st, pushT, p.x, p.y, fx0, p.y);
		seg(t, st, pushT, tp.x, tp.y, tx, tp.y);
		if (live)
			animFx("dust/", 49, tp.x, tp.y - 8, st, 20, 0.6, 5);
		var t1 = st + pushT;
		var dist = Math.abs(tx - fx0);
		var dir = f.team == 0 ? 1 : -1;
		var xs = [fx0, tx, tx + dist * dir, tx, tx - dist * dir, tx, tx + dist * dir];
		// (the sides it is on: turned, in front of or behind the other one)
		var flips = [false, true, true, false, false, true];
		for (i in 0...6) {
			var a = seg(f, t1 + jump * i / 6, jump / 6, xs[i], p.y, xs[i + 1], p.y, rise * i / 6, rise * (i + 1) / 6);
			a.flip = flips[i];
			a.z = 1000 + (flips[i] ? -1 : 1);
			var b = seg(t, t1 + jump * i / 6, jump / 6, tx, tp.y, tx, tp.y, riseT * i / 6, riseT * (i + 1) / 6);
			b.flip = flips[i];
			b.z = 1000;
		}
		setAnim(f, "grab", t1 + jump / 3, jump * 2 / 3 + drop);
		setAnim(t, "grabbed", t1 + jump / 3, jump * 2 / 3 + drop);
		var t2 = t1 + jump;
		var a = seg(f, t2, drop, xs[6], p.y, xs[6], p.y, rise, 0);
		a.upsideDown = true;
		a.z = 1001;
		var b = seg(t, t2, drop, tx, tp.y, tx, tp.y, riseT, 0);
		b.upsideDown = true;
		b.z = 1000;
		var land = t2 + drop;
		// (back on its feet where it was pushed, the jump back comes with the end of the skill)
		seg(f, land, 1, fx0, p.y, fx0, p.y);
		if (live)
			animFx("dust/", 49, tx, tp.y - 8, land, 20, 0.7, 5);
		hurt(t, s.d, land, live, s.crit);
		stagger(t, s.crit ? 12 : 0, land);
	}

	// « Déluge » (LaBrute's flashFlood): a weapon (or the shield) thrown from the air, fast, straight, planted in the
	// ground where it lands, toward where it comes from, covered by the animation of the throw, then fading
	function flood(f:FV, t:FV, s:Step, st:Float, dur:Float, live:Bool):Void {
		var p = posAt(f, st);
		var up = lift(f, st);
		var tp = posAt(t, st);
		var sx = f.team == 0 ? p.x + f.baseWidth : p.x;
		var sy = p.y - up - f.baseHeight * 0.5;
		var ex = s.stun ? (t.team == 0 ? tp.x - t.baseWidth * 0.25 : tp.x + t.baseWidth * 0.25) : (t.team == 0 ? tp.x - f.baseWidth * 0.6 : tp.x
			+ f.baseWidth * 0.6);
		var ey = s.stun ? tp.y - t.baseHeight * 0.8 : tp.y + 5;
		setAnim(f, "throw", st, dur);
		var flight = Math.max(1, frames(0.1));
		var hit = st + flight;
		if (live) {
			var angle = Math.atan2(ey - sy, ex - sx);
			var tex = s.stun ? "shield.png" : "thrown/" + weaponName(s.w >= 0 ? s.w : 0) + ".png";
			var item = Sheets.sprite(tex, 1, 0.5);
			item.rotation = angle;
			var fly = addFx(item, st, flight);
			fly.fromX = sx;
			fly.fromY = sy;
			fly.toX = ex;
			fly.toY = ey;
			if (!s.stun) {
				// (planted: it stays, then fades)
				var planted = Sheets.sprite(tex, 1, 0.5);
				planted.rotation = angle;
				var stay = addFx(planted, hit, frames(1) + frames(1.5));
				stay.fromX = stay.toX = ex;
				stay.fromY = stay.toY = ey;
				stay.fade = true;
				stay.fadeFrom = frames(1) / (frames(1) + frames(1.5));
				var cover = animFx("flashFlood/", 7, ex - (sx - ex) * 0.1, ey - (sy - ey) * 0.1, st, frames(7 / 0.35 / 60), 1);
				cover.obj.rotation = angle;
				(cast cover.obj : Sprite).anchor.set(1, 0.5);
			} else
				falling("shield.png", tp.x, tp.y, hit, t.facesRight ? -1 : 1, true);
		}
		if (s.stun) {
			if (t.pet == null)
				t.stunned = true;
		} else {
			hurt(t, s.d, hit, live, s.crit);
			stagger(t, 18 + (s.crit ? 12 : 0), hit, frames(0.1) + 2);
		}
	}

	// the poison cured: its icon left of the HP healed, rising and fading (LaBrute's cure.png)
	function cure(fv:FV, start:Float):Void {
		var sp = Sheets.fit(Sheets.sprite("cure.png"), 30, 30);
		var fx = addFx(sp, start, frames(2));
		fx.fromX = fx.toX = Math.max(20, Math.min(480, fv.x)) - 35;
		fx.fromY = fv.y - fv.baseHeight;
		fx.toY = fx.fromY - 100;
		fx.fade = true;
		fx.fadeFrom = 0;
	}

	// a pet that flees: the steps after it (other pets fleeing) end with the cry it flees
	function fleesCry(i:Int):Bool {
		for (k in i + 1...steps.length) {
			var s = steps[k];
			if (s.a == StepType.LEAVE && s.concurrent)
				continue;
			return s.a == StepType.SKILL_ACTIVATE && s.s >= 0 && Data.skillId(s.s).name == "cryOfTheDamned";
		}
		return false;
	}

	// the picture of LaBrute's « win » where the hand is raised (its event win:hand-raised)
	static function handRaised(fv:FV):Int {
		return fv.model == "male" ? 52 : 27;
	}

	// the end of a skill that started in a step before: the start of its SkillExpire (-1: none)
	function expireOf(from:Int, f:Int, skill:String):Float {
		for (k in from + 1...steps.length) {
			var s = steps[k];
			if (s.a == StepType.SKILL_EXPIRE && s.f == f && s.s >= 0 && Data.skillId(s.s).name == skill)
				return s.start;
		}
		return -1;
	}

	// the places of the weapons of the HUD now (their middles), by side and weapon
	function iconPlaces():Array<Map<Perk, {x:Float, y:Float}>> {
		return [
			for (side in sides) {
				var m = new Map<Perk, {x:Float, y:Float}>();
				for (i in 0...side.weapons.length) {
					var at = iconAt(side, 0, i);
					m.set(side.weapons[i], {x: at.x + ICON / 2, y: at.y + ICON / 2});
				}
				m;
			}
		];
	}

	// « Espion »: each weapon of the HUD flies from its place before (before) to its place now on a curve, the HUD of
	// both sides hidden meanwhile (LaBrute's spy: 1.1 to 2 seconds, up or down by a random height)
	function flyIcons(before:Array<Map<Perk, {x:Float, y:Float}>>, start:Float):Void {
		var end = start;
		var flights:Array<Fx> = [];
		for (si in 0...sides.length) {
			var side = sides[si];
			for (i in 0...side.weapons.length) {
				var p = side.weapons[i];
				var from:{x:Float, y:Float} = null;
				for (m in before)
					if (m.exists(p))
						from = m.get(p);
				var at = iconAt(side, 0, i);
				var c = new Container();
				Ui.perkIcon(c, "weapons/" + weaponName(p.id) + ".png", 0, 0, ICON, p.tier, 1, 0x000000);
				var dur = frames(1 + (1 + vr.random(10)) / 10);
				var fx = addFx(c, start, dur, hudFx);
				fx.fromX = from != null ? from.x : at.x + ICON / 2;
				fx.fromY = from != null ? from.y : at.y + ICON / 2;
				fx.toX = at.x + ICON / 2;
				fx.toY = at.y + ICON / 2;
				fx.arc = (vr.rand() * 2 - 1) * 30;
				// (it stays at its place until all have landed)
				fx.stay = true;
				flights.push(fx);
				if (start + dur > end)
					end = start + dur;
			}
		}
		for (fx in flights)
			fx.until = end;
		for (side in sides)
			side.iconsHiddenUntil = end;
	}

	// a perk come into the HUD (a skill copied, a weapon or a skill reloaded): its picture 3 times larger over its icon,
	// down to its size (LaBrute's animatePerkGain)
	function gained(side:Side, row:Int, i:Int, texture:String, start:Float):Void {
		if (i < 0)
			return;
		var at = iconAt(side, row, i);
		var sp = Sheets.sprite(texture);
		var k = ICON / Math.max(sp.texture.width, sp.texture.height);
		var fx = addFx(sp, start, frames(2), hudFx);
		fx.fromX = fx.toX = at.x + ICON / 2;
		fx.fromY = fx.toY = at.y + ICON / 2;
		fx.scale0 = k * 3;
		fx.scale1 = k;
	}

	// a spiral over the screen, turning (dir: its way), in a color that comes and goes (« Hypnose », « Rembobinage »)
	function spiral(start:Float, dur:Float, color:Int, dir:Int):Void {
		var veil = new Graphics();
		veil.beginFill(color, 0.4);
		veil.drawRect(0, 0, 600, 460);
		veil.endFill();
		var v = addFx(veil, start, dur, hudFx);
		v.fadeIn = 0.25;
		v.fade = true;
		v.fadeFrom = 0.6;
		var g = new Graphics();
		g.lineStyle(10, 0xFFFFFF, 0.35);
		var a = 0.0;
		g.moveTo(0, 0);
		while (a < Math.PI * 10) {
			var r = a * 12;
			g.lineTo(Math.cos(a) * r, Math.sin(a) * r);
			a += 0.15;
		}
		var sp = addFx(g, start, dur, hudFx);
		sp.fromX = sp.toX = 300;
		sp.fromY = sp.toY = 230;
		sp.spin = dir * Math.PI * 3;
		sp.fadeIn = 0.25;
		sp.fade = true;
		sp.fadeFrom = 0.6;
	}

	// « RELOAD » across the screen: in from the left to the middle, a moment, out to the right
	function reloadText(start:Float):Void {
		var mk = () -> {
			var t = Ui.title(Ui.text("RELOAD", 30, Col.WHITE, "center", Col.INK));
			t.anchor.set(0.5, 0.5);
			t.rotation = -0.07;
			return t;
		};
		var a = addFx(mk(), start, frames(0.7), hudFx);
		a.fromX = -100;
		a.toX = 300;
		a.fromY = a.toY = 230;
		a.fadeIn = 0.5;
		var hold = addFx(mk(), start + frames(0.7), frames(0.3), hudFx);
		hold.fromX = hold.toX = 300;
		hold.fromY = hold.toY = 230;
		var b = addFx(mk(), start + frames(1), frames(1), hudFx);
		b.fromX = 300;
		b.toX = 720;
		b.fromY = b.toY = 230;
		b.fade = true;
		b.fadeFrom = 0;
	}

	inline function weaponName(id:Int):String {
		return Data.weaponId(id).name;
	}

	function applyStep(i:Int, s:Step, live:Bool):Void {
		if (snapshots != null)
			snapshots[i] = snapshot();
		vr = new mt.Rand((baseSeed + (i + 1) * 7919) & 0x3FFFFFF);
		var st:Float = s.start;
		var dur:Float = s.dur > 0 ? s.dur : 1;
		var f = byIndex.get(s.f);
		var t = byIndex.get(s.t);
		if (!live) {
			// an old step: no animation, its state at once
			st -= 1000;
		}
		// the places of the fighters when the step starts (several steps can start between two pictures)
		for (fv in fvs) {
			settle(fv, st);
			var p = posAt(fv, st);
			fv.x = p.x;
			fv.y = p.y;
		}
		// a super used: one use less on its icon
		var uses = usesAt.get(i);
		if (uses != null)
			for (u in uses) {
				var side = sideOf(u.f);
				if (side == null)
					continue;
				for (p in side.supers)
					if (p.id == u.s && p.left > 0) {
						if (live)
							superUsed(side, p, st);
						p.left--;
						side.dirty = true;
						break;
					}
			}

		// (a fighter that acts is not stunned any more: the generator wakes some up without a step, a cry of a stunned brute)
		if (f != null && ACTS.indexOf(s.a) >= 0)
			f.stunned = false;

		switch (s.a) {
			case StepType.ARRIVE:
				if (f == null)
					return;
				f.present = true;
				f.leaveAt = -1;
				home(f);
				f.toX = f.homeX - (f.facesRight ? 140 : -140);
				f.toY = f.homeY - 40;
				f.moveDur = 0;
				moveTo(f, f.homeX, f.homeY, st, dur, 70);
				setAnim(f, "arrive", st, dur + 6);
				if (live)
					animFx("dust/", 49, f.homeX, f.homeY - 10, st + dur * 0.8, 24, 0.6, 5);

			case StepType.LEAVE:
				if (f == null)
					return;
				// (a pet frightened by a cry: once its waves are there)
				if (s.concurrent && f.pet != null && fleesCry(i))
					st += frames(FLEE_DELAY_SECONDS);
				// (a pet runs away the other way)
				var run = f.pet != null ? PET_LEAVE_FRAMES : dur;
				if (f.pet != null)
					f.facesRight = !f.facesRight;
				moveTo(f, f.team == 0 ? -80 : 580, f.y, st, run);
				setAnim(f, "run", st, run);
				f.leaveAt = st + run;

			case StepType.MOVE:
				if (f == null || t == null)
					return;
				var tp = posAt(t, st);
				var d = s.same ? 20 : hitDistance(f, t);
				moveTo(f, f.facesRight ? tp.x - d : tp.x + d, tp.y + 1, st, dur);
				setAnim(f, "run", st, dur);

			case StepType.MOVE_BACK:
				if (f == null)
					return;
				// (turned to run back to its place, LaBrute's moveBack)
				var p = posAt(f, st);
				if (f.team == 0 ? p.x > f.homeX + 1 : p.x < f.homeX - 1) {
					f.turnStart = st;
					f.turnUntil = st + dur;
				}
				moveTo(f, f.homeX, f.homeY, st, dur);
				setAnim(f, "run", st, dur);

			case StepType.ATTEMPT_HIT:
				if (f == null)
					return;
				setAnim(f, attackAnim(f, s.w), st, dur + 6);

			case StepType.HIT:
				if (t == null)
					return;
				hurt(t, s.d, st, live, s.crit);
				stagger(t, hitKnockBack(f, t, s.d, s.crit, s.stun), st);
				// (chaining: down on a knee)
				if (s.stun)
					t.stunned = true;

			case StepType.POISON:
				if (t == null)
					return;
				// (no impact, a green outline while it is shaken)
				hurt(t, s.d, st, live, false, 0xFFFFFF, false);
				stagger(t, hitKnockBack(f, t, s.d, false, false), st);
				if (live)
					t.auraUntil = st + frames(STAGGER_SECONDS);

			case StepType.FLASH_FLOOD:
				if (f == null || t == null)
					return;
				flood(f, t, s, st, dur, live);
				// (the weapon thrown: from its hand, else from its weapons; the shield: lost)
				if (s.stun)
					f.shield = false;
				else if (s.w >= 0) {
					if (f.weapon == s.w)
						f.weapon = -1;
					else if (sideOf(s.f) != null)
						sideOf(s.f).loseWeapon(s.w);
				}

			case StepType.HAMMER:
				if (f == null || t == null)
					return;
				hammer(f, t, s, st, dur, live);

			case StepType.HASTE:
				if (f == null || t == null)
					return;
				haste(f, t, s, st, dur, live);

			case StepType.VAMPIRISM:
				if (f == null || t == null)
					return;
				vampire(f, t, s, st, dur, live);

			case StepType.BOMB:
				if (f == null)
					return;
				setAnim(f, "launch", st, dur * 0.5);
				for (k in 0...s.targets.length) {
					var tv = byIndex.get(s.targets[k]);
					if (tv == null)
						continue;
					var tp = posAt(tv, st);
					if (live) {
						projectile("bomb/1.png", f.x, f.y - 40, tp.x, tp.y - 10, st, dur * 0.5, 60, 8);
						animFx("explosion/", 32, tp.x, tp.y - 30, st + dur * 0.5, 22, 0.9);
					}
					hurt(tv, s.dmgs[k], st + (live ? dur * 0.5 : 0), live);
				}

			case StepType.EVADE:
				if (f == null)
					return;
				// (a jump back, it stays there)
				jumpBack(f, 30, st, dur);

			case StepType.BLOCK:
				if (f == null)
					return;
				// (its head in, its arms up, from its 3rd picture; pushed back a little, the dust of its feet)
				setAnim(f, "block", st, dur, 3);
				var p = posAt(f, st);
				moveTo(f, p.x + realKnockBack(f, p.x, 9), p.y, st, Math.min(dur, frames(0.25)));
				if (live)
					animFx("dust/", 49, p.x, p.y - 6, st, 16, 0.35, 5);

			case StepType.DEATH:
				if (f == null)
					return;
				f.dead = true;
				f.trapped = false;
				f.fierce = false;
				if (f.hp > 0)
					f.hp = 0;

			case StepType.THROW:
				if (f == null || t == null)
					return;
				var weapon = Data.weaponId(s.w);
				// (sent back, « Repoussoir »: a blow of its weapon or its fist; else prepared then thrown)
				if (s.ret)
					setAnim(f, attackAnim(f, f.weapon), st, dur);
				else {
					setAnim(f, "prepare-throw", st, dur * 0.4);
					setAnim(f, "throw", st + dur * 0.4, dur * 0.6);
				}
				// (pushed back by its weight)
				var fp = posAt(f, st);
				moveTo(f, fp.x + realKnockBack(f, fp.x, weapon.damage[0] * 0.25), fp.y, st, Math.min(dur, frames(0.25)));
				if (weapon.has("thrown"))
					f.fastUntil = st + dur;
				if (!s.keep) {
					if (f.weapon == s.w)
						f.weapon = -1;
					var side = sideOf(s.f);
					if (side != null)
						side.loseWeapon(s.w);
				}
				if (live) {
					var tp = posAt(t, st);
					projectile("thrown/"
						+ weapon.name
						+ ".png", f.x
						+ (f.facesRight ? 20 : -20), f.y
						- f.baseHeight * 0.6, tp.x, tp.y
						- t.baseHeight * 0.5,
						st, dur, 0, 0, 1, !f.facesRight);
				}

			case StepType.TRASH:
				if (f == null)
					return;
				setAnim(f, "trash", st, dur);
				if (f.weapon >= 0) {
					if (live)
						falling("weapons/" + weaponName(f.weapon) + ".png", f.x, f.y, st + dur * 0.3, f.facesRight ? -1 : 1);
					var side = sideOf(s.f);
					if (side != null)
						side.loseWeapon(f.weapon);
				}
				f.weapon = -1;

			case StepType.EQUIP:
				if (f == null)
					return;
				setAnim(f, "equip", st, dur);
				f.weapon = s.w;
				// (a weapon in hand is not in the HUD any more)
				var side = sideOf(s.f);
				if (side != null)
					side.loseWeapon(s.w);

			case StepType.DISARM:
				if (t == null)
					return;
				if (live)
					falling("weapons/" + weaponName(s.w) + ".png", t.x, t.y, st, t.facesRight ? -1.5 : 1.5);
				if (t.weapon == s.w)
					t.weapon = -1;
				var side = sideOf(s.t);
				if (side != null)
					side.loseWeapon(s.w);

			case StepType.STEAL:
				if (f == null || t == null)
					return;
				thief(f, t, s.w, st, dur);
				// (in the hand of the thief: not in its HUD)
				if (sideOf(s.t) != null)
					sideOf(s.t).loseWeapon(s.w);

			case StepType.TRAP:
				if (f == null || t == null)
					return;
				setAnim(f, "launch", st, dur * 0.6);
				if (live) {
					var tp = posAt(t, st);
					projectile("thrown-net.png", f.x, f.y - 40, tp.x, tp.y - 30, st, dur * 0.6, 40, 0, 0.8);
				}
				// caught when the net lands
				t.trapped = true;
				t.trappedAt = st + (live ? dur * 0.6 : 0);

			case StepType.HEAL:
				if (f == null)
					return;
				setAnim(f, "drink", st, dur);
				heal(f, s.h, st + dur * 0.5, live);
				// (the poison cured: its icon left of the HP healed)
				if (live && s.cured)
					cure(f, st);

			case StepType.RESIST:
				// (shown by the blow it comes with, after it)
				if (f != null)
					f.resist = true;

			case StepType.SURVIVE:
				if (f == null)
					return;
				f.hp = 1;

			case StepType.SKILL_ACTIVATE:
				if (f == null)
					return;
				switch (Data.skillId(s.s).name) {
					case "fierceBrute":
						// (its trail of pictures until the skill ends)
						f.fierce = true;
						setAnim(f, "strengthen", st, dur);
					case "hammer":
						setAnim(f, "strengthen", st, dur);
					case "cryOfTheDamned":
						setAnim(f, "strengthen", st, dur);
						// (3 cries, one under the other, the middle one ahead: they fade in and go forward; the pets that stay are
						// shaken)
						if (live)
							for (k in 0...3) {
								var cx = f.x + (k % 2) * 20 * (f.team == 0 ? 1 : -1);
								var cy = f.y - f.baseHeight / 2 + k * 20 - 20;
								var cry = animFx("cry/", 6, cx, cy, st, frames(1), CRY_SCALE);
								cry.toX = cx + (f.team == 0 ? 100 : -100);
								cry.loopRate = CRY_RATE;
								cry.fadeIn = 0.25;
								// (pure white, opaque)
								cry.obj.filters = [CRY_FILTER];
								cry.obj.scale.x *= f.team == 0 ? 1 : -1;
							}
						if (s.pets != null) for (k in s.pets) {
							var pv = byIndex.get(k);
							if (pv != null)
								stagger(pv, 0, st);
						}
					case "flashFlood":
						// (up in the middle of the arena, in front of all, until the end of the skill)
						var p = posAt(f, st);
						var cx = 250 + (f.team == 0 ? -f.baseWidth / 2 : f.baseWidth / 2);
						var high = Math.max(0, p.y - 100);
						var rise = Math.min(dur, frames(0.4));
						var end = expireOf(i, s.f, "flashFlood");
						if (end < st + rise)
							end = st + rise + 200;
						seg(f, st, rise, p.x, p.y, cx, p.y, 0, high, 3).z = 1000;
						seg(f, st + rise, end - st - rise, cx, p.y, cx, p.y, high, high).z = 1000;
						setAnim(f, "evade", st, rise);
						if (live) animFx("dust/", 49, p.x, p.y - 8, st, 20, 0.6, 5);
					default:
				}

			case StepType.SKILL_EXPIRE:
				if (f == null)
					return;
				switch (Data.skillId(s.s).name) {
					case "net", "chaining":
						// (it frees itself, wakes up: a brute gets up)
						untrap(f, st, live);
						f.trapped = false;
						f.stunned = false;
						if (f.pet == null) setAnim(f, "strengthen", st, Math.max(dur, frames(0.6)));
					case "hypnosis":
						f.hypnotized = false;
					case "fierceBrute":
						f.fierce = false;
					case "flashFlood":
						// (down to its place, the dust of the landing)
						var p = posAt(f, st);
						var down = Math.max(1, Math.min(dur, frames(0.4)));
						seg(f, st, down, p.x, p.y, f.homeX, f.homeY, lift(f, st), 0, 4);
						setAnim(f, "arrive", st, Math.max(dur, down + 4));
						if (live) animFx("dust/", 49, f.homeX, f.homeY - 8, st + down, 20, 0.6, 5);
					case "hammer":
						// (a jump back from the impact)
						jumpBack(f, 110, st, Math.max(dur, frames(0.33)));
					default:
				}

			case StepType.SPY:
				// the weapons exchanged before the fight, in the HUD (with their tiers): every weapon of both flies on a curve to
				// its new place, the ones not exchanged too
				var a = sideOf(s.f);
				var b = sideOf(s.t);
				var before = live ? iconPlaces() : null;
				if (s.sent != null)
					for (k in 0...s.sent.length) {
						var given = a != null ? a.loseWeapon(s.sent[k]) : null;
						var got = b != null ? b.loseWeapon(s.recv[k]) : null;
						if (a != null && got != null)
							a.weapons.push(got);
						if (b != null && given != null)
							b.weapons.push(given);
					}
				if (before != null)
					flyIcons(before, st);

			case StepType.HYPNOTISE:
				if (f == null)
					return;
				// (its hand raised, held: LaBrute's « win » on its hand-raised picture; the spiral over the screen)
				setAnim(f, "win", st, dur, handRaised(f), true);
				if (live)
					spiral(st, frames(0.8), 0xAD3C8F, 1);
				if (s.targets != null)
					for (k in s.targets) {
						var tv = byIndex.get(k);
						if (tv != null)
							tv.hypnotized = true;
					}
				if (s.pets != null)
					for (k in s.pets) {
						var pv = byIndex.get(k);
						if (pv == null)
							continue;
						pv.team = f.team;
						// (it runs to its new side, then turns to face its new opponents)
						pv.faceBefore = pv.facesRight;
						pv.faceUntil = st + dur;
						pv.facesRight = f.facesRight;
						home(pv);
						moveTo(pv, pv.homeX, pv.homeY, st + dur * 0.3, dur * 0.7);
						setAnim(pv, "run", st + dur * 0.3, dur * 0.7);
					}

			case StepType.EAT:
				if (f == null)
					return;
				setAnim(f, "eat", st, dur);
				heal(f, s.h, st + dur * 0.6, live);
				if (t != null) {
					t.leaveAt = st + dur * 0.6;
				}

			case StepType.TREAT:
				if (t == null)
					return;
				if (f != null)
					setAnim(f, "eat", st, dur);
				heal(t, s.h, st + dur * 0.5, live);
				if (live && s.cured)
					cure(t, st);
				t.trapped = false;

			case StepType.SABOTAGE:
				if (t == null)
					return;
				if (live)
					falling("broken-weapons/" + weaponName(s.w) + ".png", t.x, t.y, st, t.facesRight ? -1 : 1);
				var side = sideOf(s.t);
				if (side != null)
					side.loseWeapon(s.w);

			case StepType.SABOTEUR:
				if (f == null)
					return;
				if (live)
					falling("broken-weapons/" + weaponName(s.w) + ".png", f.x, f.y, st + dur * 0.3, f.facesRight ? -1 : 1);
				f.weapon = -1;
				var side = sideOf(s.f);
				if (side != null)
					side.loseWeapon(s.w);

			case StepType.DROP_SHIELD:
				if (f == null)
					return;
				// (broken: thrown back fast and straight)
				if (live && f.shield)
					falling("shield.png", f.x, f.y - f.baseHeight * 0.25, st, f.facesRight ? -1 : 1, true);
				f.shield = false;

			case StepType.REGENERATION:
				if (f != null)
					heal(f, s.h, st, live);

			case StepType.MIMIC:
				// the ones that copy the skill raise their hand a moment; it comes into their HUD (large, then its size)
				var skill = s.s >= 0 ? Data.skillId(s.s) : null;
				if (s.targets != null && skill != null)
					for (k in s.targets) {
						var mv = byIndex.get(k);
						if (mv != null)
							setAnim(mv, "win", st, dur * 0.7, handRaised(mv), true);
						var side = sideOf(k);
						if (side != null && skill.uses != null) {
							var tier = s.tier > 0 ? s.tier : 1;
							var p:Perk = {id: s.s, tier: tier, left: skill.uses[tier - 1]};
							side.supers.push(p);
							side.dirty = true;
							if (live)
								gained(side, 1, usable(side).indexOf(p), "tier-" + tier + "/" + skill.name + ".png", st + dur * 0.4);
						}
					}

			case StepType.RELOAD:
				// its hand raised, « RELOAD » across the screen, its weapons and its skills back in its HUD one after the other
				if (f == null)
					return;
				setAnim(f, "win", st, dur, handRaised(f), true);
				var side = sideOf(s.f);
				var at = st + dur * 0.3;
				if (live)
					reloadText(st);
				if (side != null) {
					var k = 0;
					while (s.reloadW != null && k + 1 < s.reloadW.length) {
						var p:Perk = {id: s.reloadW[k], tier: s.reloadW[k + 1], left: 0};
						side.weapons.push(p);
						if (live)
							gained(side, 0, side.weapons.length - 1, "weapons/" + weaponName(p.id) + ".png", at);
						at += frames(0.05);
						k += 2;
					}
					k = 0;
					while (s.reloadS != null && k + 1 < s.reloadS.length) {
						var skill = Data.skillId(s.reloadS[k]);
						var tier = s.reloadS[k + 1];
						if (skill.uses != null) {
							var p:Perk = null;
							for (q in side.supers)
								if (q.id == skill.id)
									p = q;
							if (p == null)
								side.supers.push(p = {id: skill.id, tier: tier, left: 0});
							p.left = skill.uses[tier - 1];
							if (live)
								gained(side, 1, usable(side).indexOf(p), "tier-" + tier + "/" + skill.name + ".png", at);
							at += frames(0.05);
						}
						k += 2;
					}
					side.dirty = true;
				}

			case StepType.REWIND:
				// (the time going back: the spiral, turning the other way)
				if (live)
					spiral(st, frames(0.8), 0x2E4FB8, -1);
				if (snapshots != null) {
					var k = i - s.n;
					if (k < 0)
						k = 0;
					if (snapshots[k] != null)
						restore(snapshots[k]);
				}
				// its use (after the restore: the turns undone kept it)
				var caster = sideOf(s.f);
				if (caster != null)
					for (p in caster.supers)
						if (Data.skillId(p.id).name == "rewind" && p.left > 0) {
							if (live)
								superUsed(caster, p, st);
							p.left--;
							caster.dirty = true;
						}

			case StepType.END:
				if (f != null) {
					f.winner = true;
					// (the player: its own words, « Vous » does not take the verb of a name)
					banner.text = (f.fighter.index == 1 ? Lang.t("Vous avez gagné le match") : Lang.f("{0} a gagné le match",
						[Lang.t(f.fighter.name)])).toUpperCase();
					banner.visible = true;
					if (live)
						confetti(f, st);
				}
				// the cross on the loser's head, that stays
				var loser = sideOf(s.t);
				if (loser != null) {
					var cx = loser.right ? 600 - HEAD_CX : HEAD_CX;
					var cy = HEAD_CY;
					// (its last picture CROSS_SCALE times the size of the head; a black outline: 8 black copies around it)
					for (d in [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, 1], [-1, 1], [1, -1], [0, 0]]) {
						var cross = animFx("dead/", 7, cx + d[0] * CROSS_OUTLINE, cy + d[1] * CROSS_OUTLINE, st, 24, 1, 0, hudFx);
						cross.stay = true;
						var last = cross.frames[cross.frames.length - 1];
						var k = CROSS_SCALE * HEAD_H / Math.max(last.width, last.height);
						cross.obj.scale.set(k, k);
						if (d[0] != 0 || d[1] != 0)
							(cast cross.obj : Sprite).tint = 0x000000;
					}
				}

			case StepType.DRAIN:
				lastDrain = s.start;
				for (k in 0...s.targets.length) {
					var tv = byIndex.get(s.targets[k]);
					if (tv != null)
						tv.hp -= s.dmgs[k];
				}

			default:
		}

		// the gold of a bonus won with this step, where it happened
		var gold = screen.stepGold.get(i);
		if (gold != null && live) {
			var at = s.a == StepType.DISARM ? t : f;
			if (at != null)
				goldFx(at, gold, st);
		}
	}

	#if debug
	// the HP shown by the HUD (test harness)
	public function hudHp():Array<Int> {
		return [for (side in sides) side.shownHp];
	}
	#end

	public function destroy():Void {
		for (fv in fvs) {
			for (s in fv.aura.concat(fv.trail))
				game.actors.dropSprite(s);
			for (shot in fv.trailShots)
				dropShot(shot);
			game.actors.release(fv.holder);
		}
		fvs = [];
		for (side in sides)
			game.actors.release(side.portrait);
		for (layer in [arenaV8, hudV8])
			if (layer != null)
				try {
					layer.destroy({children: true});
				} catch (e:Dynamic) {}
		arenaV8 = null;
		hudV8 = null;
		effects = [];
	}
}
