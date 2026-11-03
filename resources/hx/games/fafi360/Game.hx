package fafi360;

import haxe.io.UInt16Array;
import common_haxe_avm1.display.ASprite;
import mt.deepnight.Color;

enum GamePhase {
	Init;
	ChoosePerk;
	TeamAnnounce;
	Waiting(endTime:Float, suspend:Bool, onEnd:Void->Void);
	WaitingPlayers;
	Playing;
	End(time:Float);
}

enum Font {
	FSmall;
	FBig;
	FTime;
}

// Fafi 360 (Arkadeo, Motion Twin, 600 x 460 at 30 frames/s), its League: a match of 1 min 30 s against a team that gets
// stronger at each goal, the points of the passes, of the bottles and 1500 by goal of difference at the end. The code is the
// original Game (Haxe 3, AS3) on the AS3 display list of the lib (arkadeo); this class is also the game KadoKadeo creates,
// steps and records (the button and the mouse) instead of the Arkadeo loader (AKApi).
//
// What changes from the original, and why:
//  - the LvUP campaign (the teams of teams.xml, the perks chosen between the levels, the Versus screen, the snow, water,
//    mud and leather terrains), the in-game prizes of Arkadeo (it.KPoint) and the two players version (multi) are not
//    ported; the League only gives GoalJump to the opponent;
//  - the inputs: the listeners of the original (any key or the mouse button pressed: the charge of the shot, released: the
//    shot; M: the mini map) are the keys Space (Enter) / M and the left button polled at each step of KadoKadeo, their
//    changes played at the start of the next frame of the game like the AKApi events of the original;
//  - the camera follows the mouse (the original only in a live game: it read no mouse in a replay); what is on screen
//    decides the direction of a player (Player.update), which places the ball he carries: the mouse is recorded, the
//    camera is the same in a game and in its replay; the mouse out of the game (the MOUSE_LEAVE of the original) is its
//    recorded position out of the game area;
//  - the random: the seed of the game (AKApi.getSeed) is drawn from the seed of KadoKadeo, the generators of the original
//    (mt.Rand: the game's re-seeded at each round, each entity's re-seeded in Player.updateStats) are kept on it; the
//    pictures that only change the look (the dirt and the flowers of the stadium, the effects) are on the random of the
//    effects (Seed.*Vfx), so the perlin of the stadium no more changes the draws of the game;
//  - the trigonometry that moves the game is rounded (Game.cos / Game.sin): the same on every browser;
//  - no low quality (AKApi.getPerf, isLowQuality): the effects never depend on the speed of the machine;
//  - the debug build of the original changed the game (aim at the mouse, aim 360, skill 1, D / L keys, collisions
//    drawn): not ported, the debug build of KadoKadeo is the one tested;
//  - kept from the Arkadeo HTML5 port: the score of the match ("2 - 1") drawn in the game at the top, in white with a dark
//    outline (it was in the status bar of Arkadeo; the bar of KadoKadeo shows the points), the placements of the items and
//    obstacles bounded to 300 draws, bgScroll forgotten once faded.
@:expose('GameFafi360')
class Game extends Sprite implements kado.GameInterface {
	// the button of the original: Space (and Enter), M the mini map; a finger on a touch screen is the mouse
	public static var KEY_ALIASES = KeyboardManager.ALIASES_ENTER_SPACE;

	public static var PERK_LEVELS = [2,5,7,9,11,13,15,17,19];
	public static var ME : Game;
	public static var UPSCALE = 2;
	public static var FPS = 30;

	// the game runs at 30 frames/s and KadoKadeo steps it 32 times a second: 15 frames every 16 steps
	static inline var STEPS_PER_SECOND = 32;

	static inline var BEGIN_CHARGE_0 = 0;
	static inline var END_CHARGE_0 = 1;
	static inline var BEGIN_CHARGE_1 = 2;
	static inline var END_CHARGE_1 = 3;
	static inline var RUN_0 = 4;
	static inline var RUN_1 = 5;
	static inline var CHOOSE_UPGRADE_0 = 6;
	static inline var CHOOSE_UPGRADE_1 = 7;
	// (the M key of the original: the mini map)
	static inline var MINI_MAP = 8;

	//static inline var BG_SIZE = {w:120, h:120}

	public static inline var PASS_THRESHOLD = 5;

	static var _uniq = 0;
	public static var DP_BG1 = _uniq++;
	public static var DP_SNOW = _uniq++;
	public static var DP_BG2 = _uniq++;
	public static var DP_FX_BG = _uniq++;
	public static var DP_ZSORTABLES = _uniq++;
	public static var DP_GOAL_CAGE = _uniq++;
	public static var DP_FX = _uniq++;
	public static var DP_INTERF = _uniq++;
	public static var DP_BG_SCROLL = _uniq++;
	public static var DP_MENU = _uniq++;
	public static var DP_TIP = _uniq++;

	public static var FIELD_RATIO = 90/120;
	public static inline var GRID = 16;
	public static var WID = 600;
	public static var HEI = 460;
	public static var FPADDING = 8;
	public static var FWID = 45;
	public static var FHEI = 34;

	public static var BG_SCROLL_REPEAT = 3;

	static var GOAL_VALUE = 1;
	static var GOAL_SCORE = 1500;

	public var buffer		: Buffer;
	//var tip					: mt.deepnight.deprecated.Tip;
	public var scroller		: Sprite;
	public var dm			: DepthManager;
	public var sdm			: DepthManager;
	public var viewport		: Rectangle;
	public var zsortLayer	: Sprite;
	public var fx			: Fx;
	public var tw			: Tweenie;
	public var cd			: Cooldown;
	public var cm			: Cinematic;
	public var delayer		: Delayer;
	var fl_stopped			: Bool;
	var charging			: Bool;
	var fl_stageReady		: Bool;
	var engager				: Int;
	public var allowRun		: Bool;
	public var grass		: BitmapData;
	public var ground		: BitmapData;
	var miniMap				: Bitmap;
	var miniMapVisible		: Bool;

	var kbPanX				: Float;
	var kbPanY				: Float;

	public var round		: Int;
	public var scores		: Array<Int>;
	public var controlTimes	: Array<Float>;
	public var scoreTarget	: Int;
	public var seed			: Int;
	public var rseed		: Rand;
	public var time			: Int;
	public var totalDuration: Int;
	public var colMap		: Array<Array<Float>>;

	public var chrono		: Float;
	var chronoField			: TextField;
	var chronoBg			: MovieClip;
	public var diff			: Float; // ********************* TODO gérer difficulté !
	public var pass			: Int;
	public var passField	: TextField;
	public var scoreField	: TextField;

	public var ball			: fafi360.en.Ball;
	public var items		: Array<GenericItem>;
	public var miscEntities	: Array<Entity>;
	public var allPlayers	: Array<fafi360.en.Player>;
	public var playerTeam	: TeamInfos;
	public var oppTeam		: TeamInfos;
	public var zsortables	: Array<Entity>;
	public var killList		: Array<Entity>;
	public var goals		: Array<Bitmap>;
	var timeWarning			: Bitmap;
	var bgScroll			: Null<Bitmap>;
	var spawner				: Array<{t:Float, cb:Void->Void}>;

	var mouseOutside		: Bool;
	var outTimer			: Int;
	var clickStart			: Int;
	var phase				: GamePhase;
	var perlin				: BitmapData;
	var powerBar			: { wrapper:Sprite, bar:Sprite };
	public var lowq			: Bool;

	var lastAnnounce		: Null<Annonce>;

	var stats				: Map<String,Int>;

	// ---------------------------------------------------------------- KadoKadeo
	var isReplay			: Bool;
	var frameAcc			: Int;
	var frameCount			: Int;
	var over				: Bool;
	var gameScore			: Int;
	var gameRoot			: ASprite;
	var gameMask			: pixi.core.graphics.Graphics;
	var onPointerDown		: Dynamic->Void;
	// the changes of the inputs since the last frame of the game (the events of the AKApi queue)
	var events				: Array<Int>;
	var mouseWas			: Bool;
	var keyWas				: Bool;
	var miniMapKeyWas		: Bool;
	var lastMouseX			: Int;
	var lastMouseY			: Int;

	// (the local mouse of the original Game sprite: the game is drawn at 1 canvas pixel per Flash pixel, from (0, 0))
	public var mouseX(get, never):Float;
	public var mouseY(get, never):Float;

	inline function get_mouseX():Float return MouseManager.getX();

	inline function get_mouseY():Float return MouseManager.getY();

	// the trigonometry that moves the game, rounded to 1/65536 (the last bits of Math.cos / Math.sin differ between
	// browsers): the same game in every replay
	public static inline function q(v:Float):Float return Math.round(v * 65536) / 65536;

	public static inline function cos(a:Float):Float return q(Math.cos(a));

	public static inline function sin(a:Float):Float return q(Math.sin(a));

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		super();
		this.isReplay = isReplay;

		var keys = new UInt16Array(2);
		keys[0] = KeyboardManager.SPACE;
		keys[1] = KeyboardManager.M;
		var buttons = new UInt16Array(1);
		buttons[0] = MouseManager.BUTTON_LEFT;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: keys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: true,
			recordedMouseButtons: buttons,
		});

		resetStatics();
		frameAcc = FPS;
		frameCount = 0;
		over = false;
		gameScore = 0;
		events = [];
		mouseWas = keyWas = miniMapKeyWas = false;
		lastMouseX = lastMouseY = -1;

		// pixel art: the sheet drawn without smoothing, like the buffer of the original shown x2
		for (s in findSheets())
			s.baseTexture.scaleMode = 0;
		Tex.init("/fafi360");
		Clip.init(Data.clips);
		TextField.init(Data.fonts);
		OverlayBlend.register(KadoKadeoManager.kkm.renderer);

		gameRoot = mc;
		mc.addChild(node);
		// the game area of Arkadeo (600 x 460): what goes out of it is not drawn (under the bar of KadoKadeo)
		gameMask = new pixi.core.graphics.Graphics();
		gameMask.beginFill(0xFFFFFF);
		gameMask.drawRect(0, 0, WID, HEI);
		gameMask.endFill();
		mc.addChild(gameMask);
		node.mask = gameMask;

		// the mouse stays with the game while the button is held (Flash kept it out of the stage)
		if (!isReplay) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			if (canvas != null) {
				onPointerDown = function(e:Dynamic) {
					try {
						canvas.setPointerCapture(e.pointerId);
					} catch (_:Dynamic) {}
				};
				canvas.addEventListener("pointerdown", onPointerDown);
			}
		}

		ME = this;

		lowq = false;
		//FPS = Std.int( AKApi.getBaseFramerate() ); // TODO bug fps
		tw = new Tweenie( FPS );
		cm = new Cinematic(FPS);
		delayer = new Delayer(FPS);
		// (AKApi.getSeed: a seed of KadoKadeo)
		seed = Seed.random(0x3FFFFFFF);
		rseed = new Rand(0);
		kbPanX = kbPanY = 0;
		initSeed();
		allowRun = true;
		scores = [0,0];
		controlTimes = [0,0];
		fl_stageReady = false;
		scoreTarget = 1;
		totalDuration = 0;
		engager = 0;
		cd = new Cooldown();
		fl_stopped = false;
		diff = 0;
		pass = 0;
		round = -1;
		charging = false;
		mouseOutside = true;
		spawner = new Array();
		items = new Array();
		miscEntities = new Array();
		killList = new Array();
		allPlayers = new Array();
		zsortables = new Array();
		goals = new Array();
		time = 0;
		outTimer = 0;
		clickStart = -1;
		stats = new Map();
		phase = Init;

		playerTeam = new TeamInfos();
		playerTeam.color = 0x3980F4;
		// (the name of the player: shown by the Versus screen of the LvUP campaign only)
		playerTeam.name = "#missingName";

		oppTeam = new TeamInfos();

		if( isLeague() )
			chrono = 1.5 * 60 * FPS;

		//#if !prod chrono = 2 * FPS; #end // HACK

		fx = new Fx();

		genField();

		dm = new DepthManager(this);

		buffer = new Buffer(Math.ceil(WID/UPSCALE),Math.ceil(HEI/UPSCALE), UPSCALE, false, 0x0);
		dm.add(buffer.render, DP_BG1);
		//if( UPSCALE>1 )
			//buffer.setTexture( Buffer.makeScanline(0x0, 4), 0.2, true );

		viewport = new Rectangle(1000, GRID*(FPADDING+FHEI*0.5)-buffer.height*0.5, buffer.width, buffer.height);

		scroller = new Sprite();
		buffer.dm.add(scroller, DP_BG1);
		sdm = new DepthManager(scroller);

		zsortLayer = new Sprite();
		sdm.add(zsortLayer, DP_ZSORTABLES);

		// (the perlin of the lib is an approximation: it only places the dirt of the stadium, a picture)
		perlin = new BitmapData(300,300, false, 0x0);
		perlin.perlinNoise(64,128,1, seed, true, false, 1, true);
		//buffer.addChild( new Bitmap(perlin) );

		// Barre de puissance de tir
		var w = new Sprite();
		w.graphics.beginFill(0x222331, 0.7);
		w.graphics.lineStyle(1, 0x0, 1);
		w.graphics.drawRect(0,0, 16,3);
		var b = new Sprite();
		w.addChild(b);
		b.graphics.beginFill(0xFDD700, 1);
		b.graphics.drawRect(0,0, w.width,w.height);
		b.filters = [ new GlowFilter(0xFD9200, 0.8, 4,4,2) ];
		b.blendMode = BlendMode.ADD;
		powerBar = {wrapper:w, bar:b};
		sdm.add(powerBar.wrapper, DP_INTERF);

		drawStadium();

		// Mini map
		miniMap = new Bitmap( new BitmapData(FWID, FHEI, false, 0x0) );
		dm.add(miniMap, DP_INTERF);
		miniMap.scaleX = miniMap.scaleY = 3;
		miniMap.alpha = 0.6;
		miniMap.x = 3;
		miniMap.y = HEI;
		miniMap.bitmapData.fillRect(miniMap.bitmapData.rect, 0x0);
		miniMapVisible = false;

		// Tooltip
		//tip = new mt.deepnight.Tip( new mt.deepnight.Tip.TipSprite(0x0, 0xffffff));
		//tip.setFont(8, "big");
		//tip.bgFilters = [];
		//dm.add(tip.spr, DP_TIP);

		// Joueurs
		for(i in 0...11)
			new fafi360.en.Player(0, playerTeam);
		for(i in 0...oppTeam.playerCount)
			new fafi360.en.Player(1, oppTeam);

		// Ballon
		ball = new fafi360.en.Ball();
		ball.owner = playerTeam.players[0];
		ball.xx = ball.owner.xx;
		ball.yy = ball.owner.yy;

		var s = new Sprite();
		var h = 0.3;
		var m = new Matrix();
		m.createGradientBox(buffer.width, buffer.height*h, Math.PI*0.5, 0,buffer.height*h*0.5);
		s.graphics.beginGradientFill(GradientType.RADIAL, [0xFF0000,0xFF0000], [1,0], [0,255], m);
		s.graphics.drawRect(0,0, buffer.width,buffer.height*h);
		timeWarning = mt.deepnight.Lib.flatten(s);
		timeWarning.y = Math.ceil(buffer.height*(1-h));
		timeWarning.blendMode = BlendMode.ADD;
		timeWarning.visible = false;
		buffer.dm.add(timeWarning, DP_INTERF);


		// Compteur temps
		chronoBg = new MovieClip("Bg_score");
		buffer.dm.add(chronoBg, DP_INTERF);
		chronoField = createField("0:00", FTime);
		buffer.dm.add(chronoField, DP_INTERF);
		chronoField.scaleX = chronoField.scaleY = 2;
		chronoField.y = buffer.height-20;
		chronoField.filters = [];
		chronoField.blendMode = BlendMode.ADD;
		chronoBg.x = Std.int( buffer.width*0.5 - chronoBg.width*0.5 );
		chronoBg.y = buffer.height-18;
		updateChrono();

		// Score (Arkadeo HTML5 port: in the game, at the top, white with a dark outline; the original put it, black with
		// a white shadow, in the status bar of Arkadeo: AKApi.setStatusMC)
		scoreField = createField("00 - 00", FSmall, true);
		scoreField.textColor = 0xFFFFFF;
		scoreField.filters = [ SCORE_OUTLINE ];
		buffer.dm.add(scoreField, DP_INTERF);
		scoreField.y = 26;
		updateScore();

		// Compteur passes
		passField = createField("???");
		buffer.dm.add(passField, DP_INTERF);
		passField.scaleX = passField.scaleY = 2;
		passField.y = -3;
		passField.filters = [];
		onPassChange();

		// Init des bonus temps
		var n = rseed.random(3)+1;
		for(i in 0...n)
			spawner.push({
				t	: Std.int(chrono*rseed.range(0.1, 0.8)),
				cb	: function() new fafi360.it.Time(),
			});

		// Init des supers bonus
		if( isLeague() ) {
			var rlist = new RandList();
			rlist.add( 5, 200 );
			rlist.add( 6, 100 );
			rlist.add( 7, 70 );
			rlist.add( 8, 30 );
			rlist.add( 9, 10 );
			rlist.add( 11, 5 );
			rlist.add( 13, 2 );
			var n = rlist.draw(rseed.random);
			for(i in 0...n)
				spawner.push({
					t	: Std.int(chrono*rseed.range(0.1, 0.9)),
					cb	: function() new fafi360.it.Bonus(true),
				});
		}

		spawner.sort( function(a,b) return Reflect.compare(a.t, b.t) );

		// (the Arkadeo loader called it once the game was on the stage)
		onStageReady();

		warmShaders();
		Flash.display(this, 1);
	}

	// the score of the match in white (the Arkadeo HTML5 port: its stroke of 2 px of 0x0A1A2E)
	static var SCORE_OUTLINE = new GlowFilter(0x0A1A2E, 1, 2,2, 8);

	public inline function isLeague() {
		return true;
	}

	public inline function isProgression() {
		return false;
	}

	public inline function addStat(k:String, n:Int) {
		stats.set(k, getStat(k) + n);
	}

	public inline function getStat(k:String):Int {
		if( !stats.exists(k) )
			stats.set(k, 0);
		return stats.get(k);
	}

	public function onStageReady() {
		fl_stageReady = true;

		newRound(true);
		//#if debug onLeagueGoal(); #end // HACK
	}

	function onLeagueGoal() {
		initSeed(round);

		new fafi360.en.Player(1, oppTeam);

		var olist = [5,7,8];
		for(i in 0...rseed.random(2))
			new fafi360.en.Obstacle( olist[rseed.random(olist.length)] );

		for(i in 0...rseed.random(4)-1)
			new fafi360.en.Mine();

		if( getPlayerScore()>=3 && oppTeam.getSkill()==0 )
			oppTeam.skill += 1;

		if( getPlayerScore()>=7 )
			oppTeam.addPerk(_PGoalJump);

		if( getPlayerScore()>=9 && oppTeam.getSkill()==1 )
			oppTeam.skill += 1;
	}

	function showBgScroll(?fadeIn=true) {
		var damier = new MovieClip("Damier");
		var base = mt.deepnight.Lib.flatten( damier ).bitmapData;
		damier.dispose();
		var t = new Sprite();
		t.graphics.beginFill(0x162F6D,1);
		t.graphics.drawRect(0,0, base.width*BG_SCROLL_REPEAT, base.height*BG_SCROLL_REPEAT);
		t.graphics.beginBitmapFill(base, true, false);
		t.graphics.drawRect(0,0, base.width*BG_SCROLL_REPEAT, base.height*BG_SCROLL_REPEAT);
		bgScroll = mt.deepnight.Lib.flatten(t);
		buffer.dm.add(bgScroll, DP_INTERF);

		//#if debug
		//var bmp = mt.deepnight.Lib.flatten(t);
		//bmp.scaleX = bmp.scaleY = 0.6;
		//addChild(bmp);
		//#end

		if( fadeIn ) {
			bgScroll.alpha = 0;
			tw.create(bgScroll,"alpha", 1, 700);
		}

		base.dispose();
	}

	// (the picture of the perlin, the dirt of the stadium)
	public inline function checkPerlin(x,y) {
		return perlin.getPixel(x%perlin.width, y%perlin.height) >= 0x444444;
	}

	public function initSeed(?inc=0) {
		rseed.initSeed(seed+inc*159);
	}

	public function onSuccessfulPass(e:Entity) {
		addStat("pass", 1);
		var p = Std.int( Math.min(10, pass) );
		var v = 50*p;
		addScore(v, "pass");
		fx.popScore(e.xx, e.yy, v);
		fx.popPass(e.xx, e.yy, p);
	}

	public inline function getPlayerScore() {
		return scores[0];
	}

	public inline function getOpponentScore() {
		return scores[1];
	}

	public inline function isPlaying() {
		return phase==Playing;
	}

	public inline function isWaitingPlayers() {
		return phase==WaitingPlayers;
	}

	public inline function isChoosingPerk() {
		return phase==ChoosePerk;
	}

	public inline function isSuspended() {
		return switch(phase) {
			case Waiting(t, suspend, n) : suspend;
			default : false;
		}
	}

	public inline function matchStarted() {
		return phase!=Init;
	}

	public inline function matchEnded() {
		return Type.enumIndex(phase)==Type.enumIndex(End(0));
	}

	public function setPhase(p:GamePhase) {
		if( matchEnded() )
			return;

		resetCharge();
		phase = p;
	}


	public function onPassChange() {
		tw.terminate(passField);

		//passField.scaleX = passField.scaleY = Math.min(4, pass);
		passField.x = Std.int( buffer.width*0.5 - passField.textWidth*0.5*passField.scaleX );
		passField.y = Std.int( 8 - passField.textHeight*0.5*passField.scaleY );
		passField.text = pass+" pass";
		passField.visible = pass>0;
		passField.visible = false;
		tw.create(passField,"y", passField.y+10, TLoop, 250).onUpdateT = function(t) {
			passField.filters = [ new GlowFilter(0xFFEC00, Math.sin(t*3.14), 16,16,2) ];
		}
	}


	// (AKApi.addScore: the points go to KadoKadeo, nothing more after the end)
	public function addScore(v:Int, ?origin:String) {
		if( v<= 0 )
			return;
		if( origin!=null )
			addStat("score_"+origin, v);
		if( over )
			return;
		gameScore += v;
		KadoKadeoManager.kkm.addScore(v);
		//if( from!=null )
			//fx.popScore(from.xx, from.yy, v.get(), color);
	}


	public function announce(frame:Int, str:String, ?text=0xFFFF00, ?bg:Int) {
		removeAnnounce();

		var mc = new Annonce();
		lastAnnounce = mc;
		buffer.dm.add(mc, DP_INTERF);
		mc.y = 90;
		mc._illu.getClip("_sub").gotoAndStop(frame);
		mc._field.width = 400;
		mc._field.x = buffer.width;
		mc._field.y += 2;
		var tf = mc._field.getTextFormat();
		mc._field.setTextFormat(tf);
		mc._field.defaultTextFormat = tf;
		mc._field.text = str;
		mc._field.textColor = text;
		mc.play();
		//#if debug
		//mc.alpha = 0.4;
		//#end

		tw.create(mc._field, "x", -mc._field.textWidth, TLinear, 2500).onEnd = function() cm.signal("announce");

		if( bg!=null )
			mc._bg.filters = [ Color.getColorizeFilter(bg, 0.7, 0.3) ];
	}

	public function removeAnnounce() {
		if( lastAnnounce!=null ) {
			var mc = lastAnnounce;
			mc._illu.play();
			tw.create(mc, "alpha", 0, 800).onEnd = function () {
				mc.parent.removeChild(mc);
				mc.dispose();
			}
			lastAnnounce = null;
		}
	}

	function drawGoal(side:Int) {
		var r = getGoalRectangle(side);

		var b = new BitmapData(GRID*5, (r.h+4)*GRID, true, 0x0);
		var f = b.clone();

		// Fond
		var top = new MovieClip("But_back_shadow");
		b.draw(top, top.transform.matrix);
		var bottom = new MovieClip("But_front_shadow");
		bottom.y = GRID*r.h;
		b.draw(bottom, bottom.transform.matrix);
		for(y in 3...r.h) {
			var mc = new MovieClip("But_tile_shadow");
			mc.y = GRID*y;
			b.draw(mc, mc.transform.matrix);
			mc.dispose();
		}
		top.dispose();
		bottom.dispose();

		// Filet
		var top = new MovieClip("But_back");
		f.draw(top, top.transform.matrix);
		var bottom = new MovieClip("But_front");
		bottom.y = GRID*r.h;
		f.draw(bottom, bottom.transform.matrix);
		for(y in 3...r.h) {
			var mc = new MovieClip("But_tile");
			mc.y = GRID*y;
			f.draw(mc, mc.transform.matrix);
			mc.dispose();
		}
		top.dispose();
		bottom.dispose();

		return { rect:r, front:f, ground:b }
	}

	// The stadium: the clips of the SWF drawn into the bitmaps of the field. The dirt and the flowers are placed by the
	// random of the effects (the original drew them from the generator of the game, before the bonuses of the match: here
	// the perlin of the dirt cannot change the game). The pictures of the LvUP teams (leather, water, mud, the large and
	// moving cages, the right stand) are not ported.
	function drawStadium() {
		initSeed();
		var w = GRID*(FWID+FPADDING*2);
		var h = GRID*(FHEI+FPADDING*2);

		grass = new BitmapData(w,h, false, 0x4B7F48);
		var bmp1 = new Bitmap(grass);
		sdm.add(bmp1, DP_BG1);

		// Sol
		var s = new MovieClip("Gazon");
		s.stop();
		s.x = FPADDING*GRID;
		s.y = FPADDING*GRID;
		grass.draw(s, s.transform.matrix);
		s.dispose();

		// Saleté
		var dirt = new BitmapData(grass.width, grass.height, true, 0x0);
		for(i in 0...60) {
			var x,y;
			var tries = 500;
			do {
				x = GRID * ( Seed.randomVfx(FWID+FPADDING*2) );
				y = GRID * ( Seed.randomVfx(FHEI+FPADDING*2) );
			} while( !checkPerlin(x,y) && tries-->0 );
			var mc = new MovieClip("Taches");
			mc.gotoAndStop( Seed.randomVfx(mc.totalFrames)+1 );
			mc.x = x;
			mc.y = y;
			mc.scaleX = mc.scaleY = Seed.rangeVfx(2,3);
			mc.rotation = Seed.randVfx()*360;
			mc.alpha = Seed.rangeVfx(0.4, 0.9);
			dirt.draw(mc, mc.transform.matrix, mc.transform.colorTransform, BlendMode.MULTIPLY);
			mc.dispose();
		}
		dirt.colorTransform( dirt.rect, Color.getColorizeCT(0x858043, 1) );
		grass.draw(dirt);
		dirt.dispose();

		// Noise
		var noiseMc = new MovieClip("Noise");
		var noise = mt.deepnight.Lib.flatten(noiseMc);
		noiseMc.dispose();
		var texture = new Sprite();
		texture.graphics.beginBitmapFill(noise.bitmapData, true);
		texture.graphics.drawRect(0,0,w,h);
		grass.draw(texture, BlendMode.OVERLAY);
		noise.bitmapData.dispose();

		// Teinte
		var teint : BitmapFilter = new ColorMatrixFilter();
		var grand = new Rand(0);
		grand.initSeed( seed );
		var colors = [
			{c:0x0, r:0.},
			{c:0x806031, r:0.5},
			{c:0x40715F, r:0.5},
			{c:0x783848, r:0.5},
			{c:0xA35A4E, r:0.5},
			{c:0x6D4A30, r:0.8},
			{c:0x425B49, r:0.8},
			{c:0x732B37, r:0.5},
		];
		var c = colors[grand.random(colors.length)];
		if( c.r>0 ) {
			teint = Color.getColorizeFilter(c.c, c.r, 1-c.r);
			grass.applyFilter(grass, grass.rect, new Point(0,0), teint);
		}


		// Fleurs
		for(i in 0...120) {
			var mc = new MovieClip("Item_deco");
			mc.x = GRID * ( Seed.randomVfx(FWID+FPADDING*2) );
			mc.y = GRID * ( Seed.randomVfx(FHEI+FPADDING*2) );
			mc.gotoAndStop( Seed.randomVfx(mc.totalFrames)+1 );
			mc.alpha = Seed.randVfx()*0.3 + 0.5;
			mc.filters = [teint];
			grass.draw(mc, mc.transform.matrix, mc.transform.colorTransform);
			mc.dispose();
		}

		// ÉLÉMENTS AVANT
		var top_bd = new BitmapData(w,h, true, 0x0);
		var bmp = new Bitmap(top_bd);
		sdm.add(bmp, DP_BG2);

		// Public gauche
		var mc = new MovieClip("Public_cotes");
		mc.x = 72;
		//mc.filters = [teint];
		top_bd.draw(mc, mc.transform.matrix);
		mc.dispose();

		// Gradins
		var mc = new MovieClip("Gradins_fixe");
		mc.x = FPADDING*GRID;
		//mc.filters = [teint];
		top_bd.draw(mc, mc.transform.matrix);
		mc.dispose();

		// Mur
		var mc = new MovieClip("Muret");
		mc.x = FPADDING*GRID-10;
		mc.y = FPADDING*GRID-14;
		//mc.filters = [teint];
		top_bd.draw(mc, mc.transform.matrix, mc.transform.colorTransform);
		mc.dispose();

		// Trous des buts
		var r = getGoalRectangle(0);
		top_bd.fillRect(new Rectangle(r.x*GRID,r.y*GRID-15, 20+r.w*GRID, r.h*GRID+10), 0x0);
		var r = getGoalRectangle(1);
		top_bd.fillRect(new Rectangle(r.x*GRID-20,r.y*GRID-15, r.w*GRID, r.h*GRID+10), 0x0);

		// But 0
		var g = drawGoal(0);
		var m = new Matrix();
		m.translate( GRID*(g.rect.x-1)-10, GRID*(g.rect.y-3));
		top_bd.draw(g.ground, m);
		var bmp = new Bitmap(g.front);
		sdm.add(bmp, DP_GOAL_CAGE);
		bmp.transform.matrix = m;
		goals[0] = bmp;

		// But 1
		var g = drawGoal(1);
		var m = new Matrix();
		m.scale(-1, 1);
		m.translate(g.ground.width, 0);
		m.translate( GRID*(g.rect.x)-5, GRID*(g.rect.y-3));
		top_bd.draw(g.ground, m);
		var bmp = new Bitmap(g.front);
		sdm.add(bmp, DP_GOAL_CAGE);
		bmp.transform.matrix = m;
		goals[1] = bmp;


		ground = new BitmapData(w,h, true, 0x0);
		sdm.add(new Bitmap(ground), DP_BG2);
		// (its RenderTexture made now, not by the first mark of an explosion during the match)
		ground.draw(new Sprite());
	}

	public function createField(str:String, ?font:Font, ?adjustSize=false) {
		if( font==null )
			font = FSmall;
		var f = new TextFormat();
		switch(font) {
			case FSmall : f.font = "small"; f.size = 16;
			case FBig : f.font = "big"; f.size = 8;
			case FTime : f.font = "time"; f.size = 8;
		}
		f.color = 0xffffff;

		// (embedded font: the glyphs of the SWF, Data.fonts)
		var tf = new TextField(f.font);
		tf.width = adjustSize ? 500 : 300;
		tf.height = 50;
		tf.mouseEnabled = tf.selectable = false;
		tf.defaultTextFormat = f;
		tf.embedFonts = true;
		tf.htmlText = str;
		tf.multiline = tf.wordWrap = true;
		if( adjustSize ) {
			tf.width = tf.textWidth+5;
			tf.height = tf.textHeight+5;
		}

		tf.filters = [
			new GlowFilter(0x0,1, 2,2,5),
		];

		return tf;
	}

	public function getGoalRectangle(side:Int) {
		var grand = new Rand(0);
		grand.initSeed(seed + side*55);

		var r = {x:0, y:0, w:3, h:6};

		if( side==1 && oppTeam.hasPerk(_PSmallCage) )
			r.h = 4;

		if( side==0 && oppTeam.hasPerk(_PPlayerLargeCage) )
			r.h = 16;

		if( side==1 && oppTeam.hasPerk(_PLargeCage) )
			r.h = 8;

		r.x = side==0 ? FPADDING - r.w : FPADDING + FWID;
		r.y = Std.int(FPADDING + FHEI*0.5 - r.h*0.5);

		if( side==1 ) {
			if( oppTeam.hasPerk(_PRandomCage) )
				r.y = FPADDING + grand.random(FHEI-r.h-1);
			if( oppTeam.hasPerk(_PCornerCage) ) {
				if( grand.random(2)==0 )
					r.y = FPADDING + 1 + grand.random(4);
				else
					r.y = FPADDING + FHEI - r.h - 1 - grand.random(4);
			}
		}
		return r;
	}

	function genField() {
		colMap = new Array();
		for(x in 0...FWID+FPADDING*2) {
			colMap[x] = new Array();
			for(y in 0...FHEI+FPADDING*2)
				colMap[x][y] = 999;
		}

		for( x in 0...FWID )
			for( y in 0...FHEI )
				colMap[FPADDING+x][FPADDING+y] = 0;

		var r = getGoalRectangle(0);
		for( x in r.x...r.x+r.w )
			for( y in r.y...r.y+r.h)
				colMap[x][y] = 0;

		var r = getGoalRectangle(1);
		for( x in r.x...r.x+r.w )
			for( y in r.y...r.y+r.h)
				colMap[x][y] = 0;
	}



	public inline function getColHeight(x:Int,y:Int) {
		return
			if( x<0 || x>=FWID+FPADDING*2 || y<0 || y>=FHEI+FPADDING*2 )
				999;
			else
				colMap[x][y];
	}

	public inline function isClicking() {
		return clickStart>=0;
	}

	public inline function wait(ms:Float, ?suspend=false, ?cb:Void->Void) {
		setPhase(  Waiting(time+(ms/1000)*FPS, suspend, cb)  );
	}

	public function onLostBall() {
		pass = 0;
		onPassChange();
		cm.create({
			announce(3, Lang.LostBall, 0xFF0000, 0x9B0000) > end;
			removeAnnounce();
		});
		newRound(false);
	}

	public function newRound(repop:Bool) {
		if( matchEnded() )
			return;

		round++;
		initSeed(round);

		if( round==0 )
			wait(1000, function() setPhase(WaitingPlayers));
		else
			setPhase(WaitingPlayers);

		if( repop )
			repopBonus();
		initPlayers();
		engage();
	}

	public function initPlayers() {
		for( p in allPlayers )
			p.origin.x = p.origin.y = -9999;

		var tries = 0;
		for( p in allPlayers ) {
			var gr = getGoalRectangle(p.side);
			var or = getGoalRectangle(p.side==0 ? 1 :0);
			var minDist = 150;
			var tooClose = false;
			do {
				tries++;
				var cx = 0.;
				var cy = 0.;
				if( p.isGoal ) { // Gardien
					cx = FPADDING + rseed.range(2, 3);
					cy = gr.y + rseed.range(1, gr.h-1);
				}
				else if( !p.team.hasPerk(_PDoubleAttack) && p.id==1 ) { // Attaquant standard
					cx = FPADDING + rseed.range(FWID-12, FWID-8);
					cy = or.y + rseed.range(0, or.h);
				}
				else if( p.team.hasPerk(_PDoubleAttack) && p.id==1 ) { // Attaquant double 1
					cx = FPADDING + rseed.range(FWID-12, FWID-7);
					cy = or.y - or.h*0.5 + rseed.range(0, or.h);
				}
				else if( p.team.hasPerk(_PDoubleAttack) && p.id==3 ) { // Attaquant double 2
					cx = FPADDING + rseed.range(FWID-12, FWID-7);
					cy = or.y + or.h*0.5 + rseed.range(0, or.h);
				}
				else if( p.id==2 && p.side==0 ) { // Défenseur
					cx = FPADDING + rseed.range(8,10);
					cy = gr.y + rseed.range(0, gr.h);
				}
				else { // Autre joueur
					var m = 3;
					cx = FPADDING + rseed.range(m, FWID-m);
					cy = FPADDING + rseed.range(m, FHEI-m);
				}

				if( p.side==1 )
					cx = FPADDING*2 + FWID - cx;
				if( cy<FPADDING )
					cy = FPADDING;
				if( cy>=FPADDING+FHEI )
					cy = FPADDING+FHEI-1;

				p.origin.x = GRID*cx;
				p.origin.y = GRID*cy;

				// Check distances
				tooClose = false;
				for(p2 in allPlayers )
					if( p!=p2 && mt.deepnight.Lib.distance(p.origin.x, p.origin.y, p2.origin.x, p2.origin.y)<=minDist ) {
						tooClose = true;
						break;
					}
				if( minDist>20 )
					minDist-=5;
			} while( tooClose );
		}

		for(p in allPlayers)
			p.updateStats();
	}

	public function repopBonus() {
		for(i in items)
			if( i.fl_repop )
				i.removeItem();

		if( isLeague() ) {
			for(n in 0...25)
				new fafi360.it.Bonus(false);
		}
	}

	public function engage() {
		if( round==0 )
			for( e in allPlayers ) {
				e.cx = Math.round(e.origin.x/GRID);
				e.cy = Math.round(e.origin.y/GRID);
			}

		allowRun = false;

		var p = engager==0 ? playerTeam.players[0] : oppTeam.players[0];
		p.takeBall(false);
		p.setRestrictMode(true);
		if( round==0 ) {
			ball.cx = p.cx;
			ball.cy = p.cy;
		}

		for( e in allPlayers )
			e.setTarget(e.origin.x, e.origin.y);
	}

	public function loseTime(sec:Int) {
		chrono -= sec*FPS;

		//var tf = createField("Lost "+sec+" seconds", true); // TODO trad
		//buffer.dm.add(tf, DP_INTERF);
		//tf.textColor = 0xFF4935;
		//tf.scaleX = tf.scaleY = 2;
		//tf.x = Std.int(buffer.width*0.5 - tf.textWidth*0.5*tf.scaleX);
		//tf.y = buffer.height;
		//tf.filters = [];
		//tf.blendMode = flash.display.BlendMode.ADD;
		//
		//tw.create(tf, "y", buffer.height-40, TEaseOut, 500);
		//delayer.add( function() {
			//tw.create(tf, "alpha", 0, TEaseIn, 1000).onEnd = function() {
				//tf.parent.removeChild(tf);
			//}
		//}, 1000);

		updateChrono();
	}

	public function addTime(sec:Int) {
		chrono += sec*FPS;
	}

	public inline function getClickPower() {
		return
			if( clickStart<0 )
				0;
			else {
				var max = 20 - (ball.hasOwner() ? (1-ball.owner.precision)*10 : 0);
				var d = (time-clickStart) % max;
				var phase = Std.int((time-clickStart) / max)%2;
				if( phase==0 )
					Math.min(1, d/max);
				else
					Math.min(1, 1-d/max);
			}
	}

	public function resetCharge() {
		charging = false;
		clickStart = -1;
		powerBar.wrapper.visible = false;
	}

	function beginCharge(side:Int) {
		if( charging )
			return;

		if( !isPlaying() )
			return;

		if( !ball.hasOwner() || ball.owner.side!=side )
			return;

		if( ball.owner.cd.has("shootDelay") )
			return;

		if( !ball.owner.isPlayable() )
			return;

		charging = true;
		clickStart = time;
		powerBar.wrapper.visible = true;
	}

	function endCharge(side:Int) {
		if( !charging )
			return;

		if( !isPlaying() )
			return;

		if( !ball.hasOwner() || !ball.owner.isPlayable() || ball.owner.side!=side )
			return;

		var clickPow = getClickPower();
		resetCharge();

		//#if debug // freemove
		//var e = ball.owner;
		//e.dx = Math.cos(e.ang)*(0.2+clickPow*1.5);
		//e.dy = Math.sin(e.ang)*(0.2+clickPow*1.5);
		//return;
		//#end

		ball.owner.kickBall(ball.owner.ang, 0.5+clickPow*0.5, clickPow);
	}

	// The listeners of the original (onKeyDown / onKeyUp / onMouseDown / onMouseUp: AKApi.emitEvent) on the inputs of a step
	// of KadoKadeo (recorded): a press of the button or of a key begins the charge, a release ends it; M shows or hides
	// the mini map (its release also ends a charge, like any key of the original)
	function pollInputs() {
		var mouse = MouseManager.isButtonDown(MouseManager.BUTTON_LEFT);
		var key = KeyboardManager.isDown(KeyboardManager.SPACE);
		var mapKey = KeyboardManager.isDown(KeyboardManager.M);
		if( mapKey && !miniMapKeyWas )
			events.push(MINI_MAP);
		if( key && !keyWas )
			events.push(BEGIN_CHARGE_0);
		if( mouse && !mouseWas )
			events.push(BEGIN_CHARGE_0);
		if( !mapKey && miniMapKeyWas )
			events.push(END_CHARGE_0);
		if( !key && keyWas )
			events.push(END_CHARGE_0);
		if( !mouse && mouseWas )
			events.push(END_CHARGE_0);
		mouseWas = mouse;
		keyWas = key;
		miniMapKeyWas = mapKey;
	}

	function toggleMiniMap() {
		miniMapVisible = !miniMapVisible;
		tw.terminate(miniMap);
		if( miniMapVisible )
			tw.create(miniMap, "y", miniMap.y-miniMap.height, 400).fl_pixel = true;
		else
			tw.create(miniMap, "y", miniMap.y+miniMap.height, 400).fl_pixel = true;
	}

	// The MOUSE_MOVE / MOUSE_LEAVE of the stage: the recorded position of the mouse, out of the game area when the pointer
	// left the canvas (or went on the bar of KadoKadeo)
	function pollMouse() {
		var x = MouseManager.getX();
		var y = MouseManager.getY();
		var inside = x>0 && x<WID && y>0 && y<HEI;
		if( inside ) {
			if( x!=lastMouseX || y!=lastMouseY ) {
				kbPanX = kbPanY = 0;
				mouseOutside = false;
			}
		}
		else if( !mouseOutside ) {
			mouseOutside = true;
			outTimer = 30;
		}
		lastMouseX = x;
		lastMouseY = y;
	}


	public function goal(win:Bool) {
		for( p in allPlayers )
			p.gotBallThisRound = false;

		scores[ win ? 0 : 1 ] += GOAL_VALUE;

		var done = isProgression() && (getPlayerScore()>=scoreTarget || getOpponentScore()>=scoreTarget);

		if( done )
			setPhase( End(time+FPS*2.5) );

		if( win ) {
			fx.flashBang(0xFFDF00, 0.3, 1500);
			pass++;
			onPassChange();
			announce( 1, Lang.ScoreGoal, 0x77B5FF );

			cm.create({
				1000;
				updateScore(true);
				1000;
				if( !matchEnded() )
					removeAnnounce();
			});
			if( !matchEnded() ) {
				wait(1500, true, function() newRound(true));
				if( isLeague() )
					onLeagueGoal();
			}
		}
		else {
			pass = 0;
			onPassChange();

			announce( 2, ball.getLastOwnerSide()==1 ? Lang.ConcedeGoal : Lang.ConcedeGoalYourself, 0xFC8003, 0x9B0000 );
			fx.flashBang(0xFF0000, 0.7, 1000);

			cm.create({
				1000;
				updateScore(true);
				1000;
				if( !matchEnded() )
					removeAnnounce();
			});
			if( !matchEnded() )
				wait(1000, true, function() newRound(false));
		}
	}


	// (AKApi.gameOver: the end goes to KadoKadeo once; the League has no win)
	public function gameOver() {
		if( fl_stopped )
			return;
		fl_stopped = true;
		over = true;
		#if debug
		untyped js.Browser.window.__over = debugState();
		#end
		KadoKadeoManager.kkm.gameOver({});
	}

	public function endLeague() {
		if( matchEnded() )
			return;

		cm.create({
			announce(3, Lang.TimeOut, 0xFFFF00, 0x0);
			lastAnnounce.y = 40;
			end;
			removeAnnounce();
		});

		for(i in items)
			i.removeItem();
		items = [];
		setPhase( End(time+FPS*5) );

		delayer.add( function() showBgScroll(true), 1000 );

		var slist : Array<{label:String, value:Dynamic, bonus:Null<Int>}> = [];

		var delta = getPlayerScore()-getOpponentScore();
		var bonus = delta>0 ? delta*GOAL_SCORE : 0;
		slist.push({
			label	: Lang.StatScore,
			value	: "<font color='#BFFE01'>"+getPlayerScore()+"</font> - <font color='#F28657'>"+getOpponentScore()+"</font>",
			bonus	: bonus,
		});

		slist.push({
			label	: Lang.StatPass,
			value	: getStat("pass"),
			bonus	: null,
		});
		slist.push({
			label	: Lang.StatControl,
			value	: Math.round(100*controlTimes[0]/totalDuration)+"%",
			bonus	: null,
		});

		var i = 0;
		for(s in slist) {
			var y = 110 + i*30;
			// Labels
			var tf = createField(s.label, FBig, true);
			buffer.dm.add(tf, DP_MENU);
			tf.x = 20;
			tf.y = y;
			tf.filters = [];
			tf.textColor = 0xBEC6D8;
			tf.alpha = 0;
			delayer.add( function() {
				tw.create(tf, "x", tf.x+10, 200).fl_pixel = true;
				tw.create(tf, "alpha", 1, 500);
			}, 1500 + i*300);

			// Valeur
			var tf = createField(Std.string(s.value), FBig, true);
			buffer.dm.add(tf, DP_MENU);
			tf.x = 130;
			tf.y = y-8;
			tf.scaleX = tf.scaleY = 2;
			tf.textColor = 0xFFFFFF;
			tf.alpha = 0;
			tf.filters = [];
			delayer.add( function() {
				tw.create(tf, "x", tf.x+10, 200);
				tw.create(tf, "alpha", 1, 500);
			}, 1800 + i*300);

			// Bonus
			if( s.bonus!=null ) {
				var tf = createField("+"+s.bonus, FBig, true);
				buffer.dm.add(tf, DP_MENU);
				tf.scaleX = tf.scaleY = 2;
				tf.x = buffer.width-20-tf.textWidth*tf.scaleX;
				tf.y = y-8;
				tf.alpha = 0;
				tf.textColor = 0xFFFF80;
				tf.filters = [ new GlowFilter(0xFFB00D,0.9, 16,16,1, 2) ];
				delayer.add( function() {
					if( s.bonus!=0 )
						addScore(s.bonus, "goal");
					tw.create(tf, "x", tf.x-10, 200);
					tw.create(tf, "alpha", 1, 500);
				}, 2600 + i*300);
			}

			i++;
		}
	}

	function updateScore(?blink=false) {
		scoreField.width = 300;
		scoreField.text = Lang.Score({_player:getPlayerScore(), _opponent:getOpponentScore()});
		scoreField.width = scoreField.textWidth+5;
		// (Arkadeo HTML5 port: centred at the top of the game)
		scoreField.x = Std.int( buffer.width*0.5 - scoreField.textWidth*0.5 );

		if( blink ) {
			var o = {t:0.};
			tw.terminate(scoreField, "y");
			tw.create(scoreField, "y", scoreField.y+6, TShakeBoth, 350);
			tw.create(o, "t", 1, TBurnIn, 900).onUpdateT = function(t) {
				var t = Math.sin(t*3.14);
				scoreField.filters = [
					// (the outline of the white score instead of the white shadow of the black one)
					SCORE_OUTLINE,
					new GlowFilter(0xffffff,t, 4,4,4, 1,true),
					new GlowFilter(0xFFF200,t, 8,4,2),
					new GlowFilter(0xFFD900,t, 32,16,2),
				];
			}
		}
	}

	function updateChrono() {
		if( matchEnded() )
			return;

		var c = Std.int( chrono/FPS );
		var mins = Std.int( c/60 );
		var sec = Std.int( c-mins*60 );
		if( mins<0 ) mins = 0;
		if( sec<0 ) sec = 0;
		chronoField.text = mins+":"+mt.deepnight.Lib.leadingZeros(sec,2);
		chronoField.x = Std.int( buffer.width*0.5 - chronoField.textWidth*0.5*chronoField.scaleX - 3 );

		if( chronoField.scaleX!=3 && mins==0 && sec<=20 ) {
			chronoField.filters = [ new GlowFilter(0xFF0000, 0.9, 8,8,1) ];
			chronoField.textColor = 0xFF8600;
		}

		if( mins<=0 && sec>0 )
			if( sec<=10 ) {
				tw.terminate(timeWarning);
				timeWarning.visible = true;
				timeWarning.alpha = 0.7;
				tw.create(timeWarning, "alpha", 0, TLinear, 700);
				tw.create(chronoField, "y", chronoField.y-4, TLoop, 200);
			}
			else if( sec<=20 ) {
				tw.terminate(timeWarning);
				timeWarning.visible = true;
				timeWarning.alpha = 0.4;
				tw.create(timeWarning, "alpha", 0, TLinear, 700);
			}
	}

	inline function mapDot(cx,cy, col:Int) {
		if( miniMapVisible && time%3==0 )
			miniMap.bitmapData.setPixel(cx-FPADDING, cy-FPADDING, col);
	}

	// the update of the original Game (one frame at 30 frames/s)
	public function updateGame(render:Bool) {
		if( fl_stopped )
			return;

		pollMouse();

		var i = 0;
		while( i<events.length ) {
			var eid = events[i++];
			if( eid==BEGIN_CHARGE_0 ) beginCharge(0);
			else if( eid==END_CHARGE_0 ) endCharge(0);
			else if( eid==MINI_MAP ) toggleMiniMap();
		}
		events = [];

		cd.update();

		if( outTimer>0 )
			outTimer--;

		// Apparition des chronos
		while( spawner.length>0 && time>=spawner[0].t ) {
			spawner[0].cb();
			spawner.splice(0,1);
		}

		if( miniMapVisible && time%3==0 )
			miniMap.bitmapData.fillRect(miniMap.bitmapData.rect, 0x0);
		for(e in allPlayers) {
			e.update();
			mapDot(e.cx, e.cy, e.side==0 ? 0x009FFF : 0xFF5300);
		}
		for(e in items)
			e.update();
		for(e in miscEntities)
			e.update();
		ball.update();
		mapDot(ball.cx+1, ball.cy, 0xFFFFFF);

		// Destruction
		for(e in killList)
			e.unregister();
		killList = new Array();

		if( isClicking() && ball.hasOwner() && ball.owner.isPlayable() && isPlaying() ) {
			powerBar.wrapper.x = Std.int(ball.owner.xx-powerBar.wrapper.width*0.5);
			powerBar.wrapper.y = ball.owner.yy+3;
			powerBar.bar.scaleX = getClickPower();
		}


		//addBlurSpot( Std.random(100), Std.random(100), 0xFFFFFF, 5);

		// Scrolling
		if( !isChoosingPerk() ) {
			var mx = mouseX / WID - 0.5;
			var my = mouseY / WID - 0.5;
			if( mouseOutside && outTimer<=0 || phase==ChoosePerk )
				mx = my = 0;
			var mouseRange = !isPlaying() || ball.free() || ball.owner.side!=0 ? 0.2 : 0.45;
			var vx = ball.xx - viewport.width*0.5 + mx*WID*mouseRange + kbPanX;
			var vy = ball.yy - viewport.height*0.5 + my*HEI*mouseRange + kbPanY;
			viewport.x += (vx-viewport.x)*0.08;
			viewport.y += (vy-viewport.y)*0.08;
			var w = GRID*(FPADDING*2+FWID);
			var h = GRID*(FPADDING*2+FHEI);
			if( viewport.x<56 ) viewport.x = 56;
			if( viewport.x>w-viewport.width-56 ) viewport.x = w-viewport.width-56;
			if( viewport.y<0 ) viewport.y = 0;
			if( viewport.y>h-viewport.height-100) viewport.y = h-viewport.height-100;
			scroller.x = -Math.round( viewport.x );
			scroller.y = -Math.round( viewport.y );

			// Z-Sort
			if( time%4==0 ) {
				zsortables.sort(function(a,b) return Reflect.compare(a.yy+a.zpriority, b.yy+b.zpriority));
				var z = 0;
				for(e in zsortables)
					e.spr.parent.setChildIndex(e.spr, z++);
			}
		}

		//var bd = blur.bitmapData;
		//bd.applyFilter(bd, bd.rect, new flash.geom.Point(0,0), new flash.filters.BlurFilter(4,4));

		delayer.update();
		cm.update();
		tw.update();
		//tip.update();
		if( render )
			fx.update();
		if( render )
			buffer.update();
		time++;

		switch( phase ) {
			case Waiting(t, s, cb) :
				if( time>=t ) cb();
			case WaitingPlayers :
				var l = Lambda.filter(allPlayers, function(p) return !p.nearOrigin());
				if( l.length==0 )
					setPhase(Playing);
			default :
		}

		// Chrono
		if( matchStarted() && isPlaying() ) {
			if( chrono<=0 && ball.hasOwner() ) {
				if( isLeague() )
					endLeague();
			}
			chrono--;
			if( chrono<0 )
				chrono = 0;
			chronoBg.alpha = chronoField.alpha = 1;
			if( chrono%FPS==0 )
				updateChrono();

			// Temps de contrôle de la balle
			totalDuration++;
			var bside = ball.hasOwner() ? ball.owner.side : ball.getLastOwnerSide();
			if( bside!=-1 )
				controlTimes[bside]++;
		}
		else
			chronoBg.alpha = chronoField.alpha = 0.3;

		if( matchEnded() )
			switch( phase ) {
				case End(t) : if( time>=t ) gameOver();
				default :
			}

		// Textures qui scrollent en fond
		if( bgScroll!=null ) {
			var s = 1;
			bgScroll.x-=s;
			bgScroll.y+=s*0.5;
			if( bgScroll.x<-bgScroll.width/BG_SCROLL_REPEAT )
				bgScroll.x+=bgScroll.width/BG_SCROLL_REPEAT;
			if( bgScroll.y>-bgScroll.height/BG_SCROLL_REPEAT )
				bgScroll.y-=bgScroll.height/BG_SCROLL_REPEAT;
		}
	}

	// ---------------------------------------------------------------- KadoKadeo step: 15 frames of the game every 16 steps
	// Shown 30/32 of a frame behind the last frame of the game (see arkadeo.Flash), ASprite interpolating between two steps
	public function update(delta:Float) {
		pollInputs();
		frameAcc += FPS;
		while (frameAcc >= STEPS_PER_SECOND) {
			frameAcc -= STEPS_PER_SECOND;
			Flash.frameStart(this);
			MovieClip.tickAll();
			updateGame(true);
			Clip.runPending();
			frameCount++;
			Flash.frameEnd(this);
		}
		Flash.display(this, (frameAcc + STEPS_PER_SECOND - FPS) / STEPS_PER_SECOND);
	}

	public function destroy():Void {
		if (onPointerDown != null) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			if (canvas != null)
				canvas.removeEventListener("pointerdown", onPointerDown);
			onPointerDown = null;
		}
		mt.deepnight.Particle.clearAll();
		resetStatics();
		node.mask = null;
		if (gameMask.parent != null)
			gameMask.parent.removeChild(gameMask);
		gameMask.destroy();
		if (node.parent != null)
			node.parent.removeChild(node);
		node.destroy({children: true});
		ME = null;
		fafi360.it.Bonus.disposePictures();
	}

	// statics of the game: one page plays several games and replays
	static function resetStatics() {
		// the display: the positions of the original at whole pixels (pixel art drawn x2), the RenderTextures of its bitmaps
		// without smoothing; the bottles flattened by the previous game
		Flash.reset();
		Flash.useTwips = false;
		Flash.roundMoving = true;
		BitmapData.gpuScaleMode = 0;
		Entity.UNIQ = 0;
		mt.deepnight.Particle.ALL = [];
		mt.deepnight.Particle.LIMIT = 100;
		ME = null;
		fafi360.it.Bonus.disposePictures();
	}

	// the sheets of this game in the loader of KadoKadeo (the frame names of another game cannot collide)
	static function findSheets():Array<Dynamic> {
		var sheets = [];
		var res = untyped PIXI.Loader.shared.resources;
		for (k in Reflect.fields(res)) {
			var r = Reflect.field(res, k);
			var url:String = r.url != null ? r.url : k;
			if (r.spritesheet != null && url.indexOf("/fafi360") >= 0)
				sheets.push(r.spritesheet);
		}
		return sheets;
	}

	// the first use of a filter compiles its shader (a frozen frame of 10 to 80 ms): each filter of the game is drawn once
	// here (the glows of Flash, the inner glows, the drop shadow and the blurs of pixi-filters, the colour matrices, the
	// overlay)
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var flts:Array<BitmapFilter> = [
			new GlowFilter(0x0, 1, 2, 2, 5),
			new GlowFilter(0x1E3909, 0.5, 4, 4, 1, 1, true),
			new GlowFilter(0xffffff, 1, 4, 4, 4, 1, true),
			new DropShadowFilter(4, -120, 0x1E3909, 0.7, 4, 4, 1, 1, true),
			new DropShadowFilter(3, 90, 0x0, 0.5, 0, 0, 1, 1, true),
			new DropShadowFilter(2, 90, 0x0, 1, 0, 0, 1, 1, true),
			new BlurFilter(8, 8),
			new BlurFilter(2, 2),
			new ColorMatrixFilter(),
		];
		var filters:Array<Dynamic> = [for (f in flts) f.toPixi()];
		filters.push(new OverlayBlend());
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		for (f in filters) {
			var holder = new pixi.core.display.Container();
			var s = new pixi.core.sprites.Sprite(pixi.core.textures.Texture.WHITE);
			s.x = s.y = 12;
			s.width = s.height = 8;
			s.filters = [f];
			holder.addChild(s);
			renderer.render(holder, {renderTexture: rt, clear: true});
			holder.destroy({children: true});
		}
		rt.destroy(true);
	}

	#if debug
	// (test mode of the harness) a big bonus (or a chrono) near the ball, placed by the frame of the game
	public function testBonus(big:Bool) {
		var item:GenericItem = big ? new fafi360.it.Bonus(true) : new fafi360.it.Time();
		var a = frameCount * 0.7;
		item.xx = ball.xx + cos(a) * 40;
		item.yy = ball.yy + sin(a) * 30;
		item.updateFromScreenCoords();
	}

	// (test mode of the harness) a mine under the ball: it explodes
	public function testMine() {
		var m = new fafi360.en.Mine();
		m.cx = ball.cx;
		m.cy = ball.cy;
	}

	// state compared between a game and its replay (test harness)
	public function debugState():Dynamic {
		var h = 0;
		for (p in allPlayers)
			h = (h * 31 + Math.round(p.xx * 100) * 7 + Math.round(p.yy * 100)) | 0;
		return {
			frame: frameCount,
			time: time,
			score: KadoKadeoManager.kkm.score.get(),
			gscore: gameScore, // the points the game gave
			goals: getPlayerScore() + ":" + getOpponentScore(),
			pass: getStat("pass"),
			bonus: getStat("bonus"),
			round: round,
			chrono: chrono,
			players: allPlayers.length,
			ball: ball == null ? "" : Math.round(ball.xx * 1000) + ":" + Math.round(ball.yy * 1000) + ":" + Math.round(ball.z * 1000),
			ph: h,
			uid: Entity.UNIQ,
			cam: Math.round(viewport.x * 1000) + ":" + Math.round(viewport.y * 1000),
		};
	}

	// what the test bots read to play (harness): the phase, the ball and its owner, the aim and the charge, the goals
	public function botState():Dynamic {
		var o = ball != null ? ball.owner : null;
		var gr = getGoalRectangle(1);
		return {
			frame: frameCount,
			time: time,
			over: over,
			playing: isPlaying(),
			ended: matchEnded(),
			chrono: chrono,
			mine: o != null && o.side == 0,
			ang: o != null ? o.ang : 0.0,
			charging: isClicking(),
			power: getClickPower(),
			ox: o != null ? o.xx : 0.0,
			oy: o != null ? o.yy : 0.0,
			bx: ball != null ? ball.xx : 0.0,
			by: ball != null ? ball.yy : 0.0,
			goal: {x: (gr.x + gr.w * 0.5) * GRID, y: (gr.y + gr.h * 0.5) * GRID, top: gr.y * GRID, bottom: (gr.y + gr.h) * GRID},
			mates: [for (p in playerTeam.players) if (p != o) {x: p.xx, y: p.yy}],
			opps: [for (p in oppTeam.players) {x: p.xx, y: p.yy}],
			goals: getPlayerScore() + ":" + getOpponentScore(),
			cam: {x: viewport.x, y: viewport.y},
		};
	}
	#end
}
