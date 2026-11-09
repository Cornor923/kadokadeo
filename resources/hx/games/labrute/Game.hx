package labrute;

import haxe.io.UInt16Array;
import pixi.core.display.Container;
import pixi.core.graphics.Graphics;
import common_haxe_avm1.display.ASprite;
import kado.TouchControlsConfig.TouchControlsMode;
import labrute.view.Actors;
import labrute.view.Ui;

// the pictures of the game are made when KadoKadeo draws (updateGraphics of the sprites of the game), not in its
// update: a replay seek or a catch up simulates without drawing
private class RenderHook extends ASprite {
	var game:Game;

	public function new(game:Game) {
		super();
		this.game = game;
	}

	override public function updateGraphics(a:Float) {
		game.render(a);
	}
}

// La Brute (KadoKadeo, Arkadeo size: 600 x 460), after LaBrute (Eternaltwin, labrute-react): a shop, the choice of an
// opponent, an accelerated fight of LaBrute, again until a defeat. A run lasts about 5 minutes: each fight raises the
// level of the opponents, and a fight that lasts more than 21 seconds (Balance.TIMER_FRAMES) ends in a sudden death
// that grows.
//
// KadoKadeo: the game is played with the mouse (or the finger), its clicks on the buttons are the events of the replay
// (the action of the button, recorded for the frame and applied in it, in the live game as in the replay). The moves of
// the mouse are recorded too, and the changes of the pointer (mouse, touch, out) and the taps as events from 10000:
// the replay shows the hovers, the tooltips, a cursor and the taps, the game never reads them. Every random draw of the
// gameplay is made in update() (kado.Seed), the fights included (generated at once when the opponent is chosen).
// (the name of the game is « La Brute »: Game::getPascalNameAttribute gives GameLaBrute, getGameKeyAttribute labrute)
@:expose('GameLaBrute')
class Game implements kado.GameInterface {
	// the mouse only
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.NONE,
		buttons: [],
	};

	// the time between two clicks does not matter: the hidden tab pauses the game
	public static var ALLOW_PAUSE = true;

	public static var ME:Game;

	public var run(default, null):Run;
	public var frame(default, null):Int = 0;
	public var score(default, null):Int = 0;
	public var actors(default, null):Actors;
	// under the fighters, the fighters (PixiJS 8), over them, the tooltip
	public var backLayer(default, null):Container;
	public var actorLayer(default, null):Container;
	public var frontLayer(default, null):Container;

	var isReplay:Bool;
	var mc:ASprite;
	var root:Container;
	var tipLayer:Container;
	var tooltip:Tooltip;
	var hook:RenderHook;
	var screen:Screen;
	var over:Bool = false;

	// the pointer of the player, drawn by the game (its taps on a touch screen; its cursor in the replay): its changes are
	// events of the replay (from 10000, after the actions), never read by the game
	static inline var POINTER_OUT = 10000;
	static inline var POINTER_MOUSE = 10001;
	static inline var POINTER_TOUCH = 10002;
	static inline var TAP = 10003;
	static inline var TAP_FRAMES = 16;

	// the pointer recorded (the replay: played), the one of the browser (live)
	var pointer:Int = POINTER_OUT;
	var livePointer:Int = POINTER_OUT;
	var onPointer:js.html.PointerEvent->Void;
	var tapFrame:Int = -1000;
	var tapX:Float = 0;
	var tapY:Float = 0;
	var cursorMark:Graphics;
	var tapMark:Graphics;

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.mc = mc;
		this.isReplay = isReplay;
		ME = this;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: new UInt16Array(0),
			recordInputs: false,
			recordEvents: true,
			// (the mouse too: a replay shows the hovers and the tooltips of the player; only its moves are kept, compact)
			recordMousePosition: true,
			recordedMouseButtons: new UInt16Array(0),
		});
		// one page plays several games and replays
		Brute.nextUid = 1;

		Sheets.init();
		Ui.fastTextMetrics();
		Skin.load();
		Lang.load();
		root = new Container();
		mc.addChild(root);
		backLayer = new Container();
		actorLayer = new Container();
		frontLayer = new Container();
		tipLayer = new Container();
		root.addChild(backLayer);
		root.addChild(actorLayer);
		root.addChild(frontLayer);
		root.addChild(tipLayer);
		tooltip = new Tooltip(tipLayer);
		langLayer = new Container();
		root.addChild(langLayer);
		makePointerMarks();
		actors = new Actors(actorLayer);
		hook = new RenderHook(this);
		mc.addChild(hook);
		// (the key L: the next language; the pictures and the texts only, nothing of the game: not an input of the replay)
		if (!KadoKadeoManager.kkm.headless) {
			onKey = (e:js.html.KeyboardEvent) -> {
				if (e.repeat || e.ctrlKey || e.metaKey || e.altKey || (e.key != "l" && e.key != "L"))
					return;
				var target:Dynamic = e.target;
				var tag = target != null && target.tagName != null ? Std.string(target.tagName).toLowerCase() : "";
				if (tag == "input" || tag == "textarea" || (target != null && target.isContentEditable == true))
					return;
				Lang.next();
				tooltip.reset();
				langShown = haxe.Timer.stamp();
				langFlag = null;
			};
			js.Browser.window.addEventListener("keydown", onKey);
		}
		// (the events of the player only: their changes are recorded)
		if (!isReplay && !KadoKadeoManager.kkm.headless) {
			onPointer = (e:js.html.PointerEvent) -> {
				if (!common_haxe_avm1.kac.Natives.isTrustedEvent(e))
					return;
				if (e.pointerType == "touch")
					livePointer = POINTER_TOUCH;
				else
					livePointer = e.type == "pointerleave" ? POINTER_OUT : POINTER_MOUSE;
			};
			for (type in POINTER_EVENTS)
				common_haxe_avm1.kac.Natives.listen(KadoKadeoManager.kkm.canvas, type, onPointer);
		}
	}

	static var POINTER_EVENTS = ["pointermove", "pointerdown", "pointerenter", "pointerleave"];

	// the flag of the language after a change: bottom left, small, LANG_SECONDS then fading in LANG_FADE
	static inline var LANG_SECONDS = 1.5;
	static inline var LANG_FADE = 0.5;
	static inline var LANG_X = 6;
	static inline var LANG_W = 16;
	static inline var LANG_H = 12;

	var langLayer:Container;
	var langFlag:String = null;
	var langShown:Float = -1000;
	var onKey:js.html.KeyboardEvent->Void;

	function drawLang():Void {
		var age = haxe.Timer.stamp() - langShown;
		langLayer.visible = age < LANG_SECONDS + LANG_FADE;
		if (!langLayer.visible)
			return;
		langLayer.alpha = age < LANG_SECONDS ? 1 : 1 - (age - LANG_SECONDS) / LANG_FADE;
		if (langFlag != Lang.current) {
			langFlag = Lang.current;
			for (c in langLayer.removeChildren())
				untyped c.destroy({children: true});
			Ui.flag(langLayer, Lang.current, LANG_X, 460 - LANG_X - LANG_H, LANG_W, LANG_H);
		}
	}

	// ---------------------------------------------------------------- the game (32 frames a second)

	public function update(delta:Float):Void {
		frame++;
		// the run starts on the first frame (its draws are stirred like the others)
		if (run == null) {
			run = new Run();
			show(new ShopScreen(this));
		}
		// after the end of the run the screen goes on without the mouse: the fade of KadoKadeo comes over a fight that still
		// moves
		if (!over) {
			var replay = KadoKadeoManager.kkm.replay;
			if (isReplay) {
				for (e in replay.consumeEvents()) {
					var n = Std.int(e);
					if (n == TAP)
						tap();
					else if (n >= POINTER_OUT)
						pointer = n;
					else
						apply(n);
				}
			} else {
				if (livePointer != pointer) {
					pointer = livePointer;
					replay.recordEvent(pointer, replay.getCurrentFrame());
				}
				if (MouseManager.isButtonJustPressed(MouseManager.BUTTON_LEFT)) {
					if (pointer == POINTER_TOUCH) {
						replay.recordEvent(TAP, replay.getCurrentFrame());
						tap();
					}
					var action = screen.actionAt(MouseManager.getX(), MouseManager.getY());
					if (action >= 0) {
						replay.recordEvent(action, replay.getCurrentFrame());
						apply(action);
					}
				}
			}
		}
		screen.update();
	}

	function tap():Void {
		var m = mouse();
		if (m == null)
			return;
		tapFrame = frame;
		tapX = m.x;
		tapY = m.y;
	}

	// the mouse of the player: live, or recorded (the replay)
	function mouse():{x:Float, y:Float} {
		if (!isReplay)
			return {x: MouseManager.getX(), y: MouseManager.getY()};
		var played = KadoKadeoManager.kkm.replay.getReplayMouse();
		return played != null ? {x: played.x, y: played.y} : null;
	}

	function apply(action:Int):Void {
		if (screen != null)
			screen.apply(action);
	}

	public function show(next:Screen):Void {
		if (screen != null)
			screen.destroy();
		screen = next;
		tooltip.reset();
	}

	// points and gold, the same amount
	public function addPoints(n:Int):Void {
		if (over || n <= 0)
			return;
		score += n;
		run.gold += n;
		KadoKadeoManager.kkm.addScore(n);
	}

	// the end of the run (a lost fight without bandage)
	public function endRun():Void {
		if (over)
			return;
		over = true;
		#if debug
		untyped js.Browser.window.__over = debugState();
		#end
		KadoKadeoManager.kkm.gameOver({wins: run.wins, fights: run.fights, league: run.league()});
	}

	#if debug
	// state compared between a game and its replay (test harness)
	public function debugState():Dynamic {
		var b = run.brute;
		return {
			frame: frame,
			score: KadoKadeoManager.kkm.score.get(),
			gscore: score,
			gold: run.gold,
			ears: run.ears,
			fights: run.fights,
			wins: run.wins,
			hp: b.hpValue,
			str: b.strengthValue,
			agi: b.agilityValue,
			spd: b.speedValue,
			weapons: [for (w in b.weapons) w.name + w.tier].join(","),
			skills: [for (s in b.skills) s.name + s.tier].join(","),
			pets: [for (p in b.pets) p.name + p.tier].join(","),
		};
	}

	// what the test bots read to play
	public function botState():Dynamic {
		var name = Type.getClassName(Type.getClass(screen));
		var fight = Std.downcast(screen, FightScreen);
		return {
			frame: frame,
			screen: name,
			gold: run == null ? 0 : run.gold,
			over: over,
			result: fight != null ? fight.resultFrame : -1,
			fightFrame: fight != null ? fight.frame : -1,
			fightEnd: fight != null ? fight.steps[fight.endIndex].start : -1,
			hud: fight != null ? fight.hudHp() : [],
			buttons: screen == null ? [] : [for (b in screen.buttons) if (b.enabled) {x: b.x + b.w / 2, y: b.y + b.h / 2, action: b.action}],
			zones: screen == null ? [] : [for (z in screen.zones) if (z.enabled) {x: z.x + z.w / 2, y: z.y + z.h / 2, action: z.action}],
		};
	}
	#end

	// ---------------------------------------------------------------- pictures

	public function render(alpha:Float):Void {
		if (screen == null || KadoKadeoManager.kkm.headless)
			return;
		// (nothing shown before the pictures of the skin: not its drawings first)
		root.visible = Skin.ready;
		var t = frame + alpha;
		var live = !isReplay;
		// (a replay: the mouse of the player when it was recorded, its hovers, its tooltips, its cursor and its taps)
		var m = mouse();
		var kind = live ? livePointer : pointer;
		var pointing = m != null && kind != POINTER_OUT;
		var mx = pointing ? m.x : -1000;
		var my = pointing ? m.y : -1000;
		screen.render(t, mx, my, pointing);
		var tip = pointing ? screen.tipAt(mx, my) : null;
		if (tip == null)
			tooltip.hide();
		else
			tooltip.show(tip.key, tip.make, mx, my);
		// (the live game: the cursor of the system; the replay: the player's, drawn, until the end of the run)
		cursorMark.visible = !live && pointing && kind == POINTER_MOUSE && !over;
		if (cursorMark.visible)
			cursorMark.position.set(Math.round(mx), Math.round(my));
		var age = t - tapFrame;
		tapMark.visible = age >= 0 && age < TAP_FRAMES;
		if (tapMark.visible) {
			var u = age / TAP_FRAMES;
			tapMark.position.set(tapX, tapY);
			var k = 0.5 + 0.9 * u;
			tapMark.scale.set(k, k);
			tapMark.alpha = 1 - u;
		}
		actors.render(t * 1000 / Balance.FPS);
		drawLang();
	}

	// the cursor (an arrow, its tip on the mouse) and the ring of a tap: drawn once, moved
	function makePointerMarks():Void {
		cursorMark = new Graphics();
		cursorMark.lineStyle(1.5, 0x000000, 1);
		cursorMark.beginFill(0xFFFFFF, 1);
		cursorMark.drawPolygon([0, 0, 0, 17, 4.5, 13, 7.5, 19.5, 10.5, 18, 7.5, 11.5, 12.5, 11.5]);
		cursorMark.endFill();
		cursorMark.visible = false;
		tapMark = new Graphics();
		tapMark.lineStyle(3, 0xFFFFFF, 0.9);
		tapMark.beginFill(0xFFFFFF, 0.35);
		tapMark.drawCircle(0, 0, 16);
		tapMark.endFill();
		tapMark.visible = false;
		root.addChild(tapMark);
		root.addChild(cursorMark);
	}

	public function destroy():Void {
		if (onPointer != null)
			for (type in POINTER_EVENTS)
				common_haxe_avm1.kac.Natives.unlisten(KadoKadeoManager.kkm.canvas, type, onPointer);
		if (screen != null)
			screen.destroy();
		screen = null;
		if (onKey != null)
			js.Browser.window.removeEventListener("keydown", onKey);
		actors.destroy();
		if (hook.parent != null)
			hook.parent.removeChild(hook);
		Ui.destroy(root);
		ME = null;
	}
}
