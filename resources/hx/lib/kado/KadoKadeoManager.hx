package kado;

import common_haxe_avm1.kac.AntiCheat;
import common_haxe_avm1.kac.ProtectedInt;
import mt.DepthManager;
import common_haxe_avm1.display.ASprite;
import pixi.loaders.Loader;
import js.lib.Promise;
import js.Browser;
import js.html.CanvasElement;
import js.html.CustomEvent;
import haxe.CallStack;
import kado.KadoRunFlow.RunStartContext;
import kado.Seed;
import kado.TouchControlsOverlay.TouchJoystickState;
import kado.TouchControlsConfig.TouchControlsConfig;
import kado.TouchControlsConfig.TouchControlsMode;
import pixi.core.Application;
import pixi.core.ticker.Ticker;

@:expose("KadoKadeo")
class KadoKadeoManager extends Application {
	public static var kkm:KadoKadeoManager;
	public static var NEW_GEN_SCALE = 2;

	public var canvas:CanvasElement;

	var gameClass:Class<GameInterface>;
	var game:GameInterface = null;
	var ff:FixedFramerate;

	public var lang = "fr";

	public var replay:ReplayManager;

	var root:ASprite;
	var gameRoot:ASprite;
	var dm:DepthManager;

	var startScene:StartScene;
	var gameOverScreen:GameOver = null;
	var endScene:EndScene = null;
	var submitPopup:SubmitPopup = null;
	var bottomBar:BottomBar = null;
	var replayHud:ReplayHud = null;
	var touchOverlay:TouchControlsOverlay = null;

	var runDetails:Dto.RunDTO;
	var systemTickerListener:Float->Void;
	var endRunDetails:Dto.EndRunResponseDTO;
	var endRunClient:KadoEndRun;
	var runFlow:KadoRunFlow;
	var params:GameParams;
	var hasPhysicsCrashReported:Bool = false;
	var simulationTimeMs:Float = mt.Timer.oldTime;
	var replaySpeed:Float = 1;
	var replayPaused:Bool = false;
	// the marks of the progress bar of the replay (setReplayMarkers): kept when its controls are made again
	var replayMarkers:Array<Int> = [];
	var replayComment:ReplayHud.ReplayHudComment = null;

	// replay seeking: the game is restarted when going back, then simulated without waiting up to the wanted frame.
	// Meanwhile the last picture stays on screen and the game is not drawn (nor interpolated): all the time of
	// a page frame goes to the simulation; a small progress ring appears only if the seek lasts.
	static inline var SEEK_BUDGET_MS = 80;
	static inline var SEEK_RING_DELAY_MS = 150;

	var seekTarget:Null<Int> = null;
	var seekFrom:Int = 0;
	var seekStartMs:Float = 0;
	var seekFreeze:pixi.core.sprites.Sprite = null;
	var seekRing:pixi.core.graphics.Graphics = null;

	// anti cheat: a game cannot be paused by hiding its tab (switching tab or app, the browser stops drawing it):
	// back to the tab, the time spent hidden is played at once, without being drawn (like a replay seek; the
	// inputs were released when the page lost the focus). Games where the time does not matter can keep the
	// pause with `public static var ALLOW_PAUSE = true;` in their class.
	static inline var CATCH_UP_MAX_MS = 20 * 60 * 1000;

	var hiddenAtMs:Null<Float> = null;
	var hiddenAtFrame:Int = 0;
	var catchUpTarget:Null<Int> = null;
	var seedHash:Int = 0;

	var fpsText:pixi.core.text.Text;
	var fpsFrames:Int = 0;
	var fpsSampleStartMs:Float = 0;

	public var sheet:pixi.core.textures.Spritesheet;

	public var score:ProtectedInt = 0;

	public static function S(n:Float):Float {
		return n * NEW_GEN_SCALE;
	}

	public static function I(n:Int):Int {
		return n * NEW_GEN_SCALE;
	}

	// height of the game area, above the score / contract bar (600 for a KadoKado game, 460 for an Arkadeo one: its
	// canvas is 600 x 500)
	public function gameAreaHeight():Float {
		return screen.height - S(20);
	}

	public function new(canvas:CanvasElement, gameClass:Class<GameInterface>, params:GameParams) {
		super({
			view: canvas,
			width: params.canvasWidth,
			height: params.canvasHeight,
			// Keep logical coordinates at 600 x 640; Vue controls the CSS size.
			resolution: Math.max(1, Browser.window.devicePixelRatio),
			backgroundColor: 0x80c0e6e9
		});
		this.canvas = canvas;
		this.gameClass = gameClass;
		this.params = params;
		this.endRunClient = new KadoEndRun();
		this.runFlow = new KadoRunFlow(params);
		this.root = new ASprite();
		this.dm = new DepthManager(root);
		this.stage.addChild(root);
		KadoKadeoManager.kkm = this;
		Api.baseUrl = Browser.window.location.origin;

		// Pixi intro

		// this.loader = new Loader();
		loader.add('kkm', "/assets/img/content/default/kkm-0.json");
		loader.load(() -> {
			this.sheet = loader.resources["kkm"].spritesheet;
			loadFonts().then((e:Dynamic) -> {
				trace("KadoKadeoManager initialized");
				runFlow.transition(Intro, "assets-loaded");
				this.showIntroScreen();
				// score = 31300;
				// this.gameOver({});
			});
		});
		// (before the input managers: they listen with these functions)
		common_haxe_avm1.kac.Natives.init(params.natives);
		Reflect.deleteField(params, "natives");
		common_haxe_avm1.KeyboardManager.init();
		common_haxe_avm1.MouseManager.init(this);

		ff = new FixedFramerate(updatePhysics);
		initDebugFpsDisplay();

		// ANTI CHEAT: a closure, not the method (Haxe binds a method with a `scope` field: the manager would be reachable
		// from the global PIXI.Ticker.system)
		systemTickerListener = (delta:Float) -> systemTicker(delta);
		untyped Ticker.system.add(systemTickerListener);
		this.ticker.add(() -> {
			updateReplayHud();
			if (seekTarget == null && catchUpTarget == null)
				updateGraphics(ff.alpha);
			updateDebugFpsDisplay();
			pixi.core.Pixi.tweenManager.update();
		});
		this.replay = new ReplayManager(params?.replayData);
		Browser.document.addEventListener("visibilitychange", onVisibilityChange);
		// ANTI CHEAT: a live game: its classes are locked before anything can reach them (see Integrity)
		if (params.replayData == null) {
			common_haxe_avm1.kac.Integrity.lock(this);
		}
	}

	function systemTicker(delta:Float) {
		if (seekTarget != null) {
			runSeek();
			return;
		}
		if (catchUpTarget != null) {
			runCatchUp();
			return;
		}
		// speed and pause only for a replay being watched (a live game cannot be slowed down or paused)
		var watching = replay.isPlayingReplay();
		var paused = watching && replayPaused;
		if (paused) {
			common_haxe_avm1.KeyboardManager.beginFrame();
			common_haxe_avm1.MouseManager.beginFrame();
		}
		ff.onTick(untyped Ticker.system.elapsedMS * (paused ? 0 : watching ? replaySpeed : 1));
	}

	function initDebugFpsDisplay():Void {
		fpsSampleStartMs = Browser.window.performance.now();
		fpsText = new pixi.core.text.Text("FPS: --", {
			fill: 0xFFFFFF,
			fontFamily: "Arial",
			fontSize: 15,
			align: "right"
		});
		fpsText.x = screen.width - S(45);
		fpsText.y = S(4);
		#if !debug
		fpsText.visible = false;
		#end
		this.stage.addChild(fpsText);
	}

	function updateDebugFpsDisplay():Void {
		if (fpsText == null || !fpsText.visible) {
			return;
		}
		fpsFrames++;
		var now = Browser.window.performance.now();
		var elapsed = now - fpsSampleStartMs;
		if (elapsed >= 250) {
			var fps = fpsFrames * 1000 / elapsed;
			fpsText.text = "FPS: " + Std.int(fps + 0.5);
			fpsFrames = 0;
			fpsSampleStartMs = now;
		}
	}

	function destroyDebugFpsDisplay():Void {
		if (fpsText != null) {
			if (fpsText.parent != null) {
				fpsText.parent.removeChild(fpsText);
			}
			fpsText.destroy();
			fpsText = null;
		}
	}

	public function updateGraphics(a:Float) {
		if (gameRoot != null) {
			gameRoot.updateGraphics(a);
		}
		if (gameOverScreen != null) {
			gameOverScreen.updateGraphics(a);
		}
	}

	public function updatePhysics(dt:Float) {
		if (hasPhysicsCrashReported) {
			return;
		}
		try {
			simulationTimeMs += dt;
			mt.Timer.update(simulationTimeMs);
			mt.Timer.deltaT = dt / 1000;
			mt.Timer.calc_tmod = 1;
			mt.Timer.tmod = 1;
			if (runFlow.state == Playing && game != null) {
				pollGameTouchControls();
				replay.beginFrame();
				Seed.stir(replay.getCurrentFrame(), replay.getFrameSignature());
				pollManagerShortcuts();
				gameRoot.update();
				game.update(dt);
				replay.endFrame();
				if (common_haxe_avm1.kac.Integrity.shouldCheck(replay.getCurrentFrame())) {
					common_haxe_avm1.kac.Integrity.check();
				}
			} else {
				common_haxe_avm1.KeyboardManager.beginFrame();
				common_haxe_avm1.MouseManager.beginFrame();
				pollManagerShortcuts();
				pollManagerMouseInput();
			}
			if (gameOverScreen != null) {
				gameOverScreen.update();
			}
		} catch (e:Dynamic) {
			reportPhysicsCrash(e);
			throw e;
		}
	}

	function reportPhysicsCrash(error:Dynamic):Void {
		if (hasPhysicsCrashReported) {
			return;
		}
		hasPhysicsCrashReported = true;

		var message:String = Std.string(error);
		if (Reflect.hasField(error, "message")) {
			var rawMessage:Dynamic = Reflect.field(error, "message");
			if (rawMessage != null) {
				message = Std.string(rawMessage);
			}
		}

		var stack = CallStack.toString(CallStack.exceptionStack());
		if (stack == null || stack.length == 0) {
			stack = CallStack.toString(CallStack.callStack());
		}

		trace('Physics crash: ' + message);
		if (stack != null && stack.length > 0) {
			trace(stack);
		}

		emitWindowEvent("gameCrash", {
			message: message,
			stack: stack,
			name: params.name,
			gameId: params.gameId,
			runState: Std.string(runFlow.state),
			score: score,
			timestamp: Date.now().toString()
		});
	}

	public function showIntroScreen() {
		runFlow.transition(Intro, "show-intro");

		var replayContext = runFlow.createReplayContext();
		if (replayContext != null) {
			applyRunContext(replayContext);
			startGame();
			return;
		}

		#if debug
		applyRunContext(runFlow.createDebugContext());
		startGame();
		return;
		#end
		startScene = new StartScene(this, params.name);
		startScene.interactive = true;
		this.stage.addChild(startScene);
	}

	function pollManagerShortcuts():Void {
		if (fpsText != null) {
			if (common_haxe_avm1.KeyboardManager.isJustDown(common_haxe_avm1.KeyboardManager.F8)) {
				fpsText.visible = !fpsText.visible;
			}
		}
	}

	function pollManagerMouseInput():Void {
		if (!common_haxe_avm1.MouseManager.isButtonJustPressed(common_haxe_avm1.MouseManager.BUTTON_LEFT)) {
			return;
		}

		switch (runFlow.state) {
			case Intro:
				requestContractFromIntro();
			case ReadyToStart:
				startGame();
			case SubmitFailed:
				displayEndScene(neutralEndRunDetails());
			case EndScreen:
				if (endScene != null) {
					endScene.handleReplayClick();
				}
			case _:
		}
	}

	function requestContractFromIntro():Void {
		if (startScene == null) {
			return;
		}

		runFlow.transition(ContractLoading, "request-contract");
		startScene.disable();
		runFlow.requestContract((context) -> {
			applyRunContext(context);
			if (startScene != null) {
				startScene.showContract(context.runDetails);
				startScene.interactive = true;
			}
			runFlow.transition(ReadyToStart, "contract-received");
		}, (error) -> {
			runFlow.transition(Intro, "contract-failed");
			trace('Contract failed: ' + error.status + ' ' + error.message);
			// (a click asks again)
			if (startScene != null) {
				startScene.showError(error);
				startScene.interactive = true;
			}
		});
	}

	inline function applyRunContext(context:RunStartContext):Void {
		runDetails = context.runDetails;
		seedHash = context.seedHash;
		Seed.init(context.seedHash);
	}

	function startGame() {
		runFlow.transition(Playing, "start-game");
		if (startScene != null) {
			if (startScene.parent != null) {
				startScene.parent.removeChild(startScene);
			}
			startScene.destroy({children: true});
			startScene = null;
		}
		var loader:Loader = untyped PIXI.Loader.shared;

		var b = dm.empty(2);
		this.bottomBar = new BottomBar(this, runDetails);
		b.addChild(this.bottomBar);
		// (an old version of the game played for a replay has its own spritesheet: params.assetBase)
		var assetBase = this.params.assetBase != null ? this.params.assetBase : '/assets/img/content/' + this.params.name + '/';
		var assetName = assetBase + this.params.name + '-0.json';
		if (loader.resources[assetName] != null) {
			beginGame();
		} else {
			loader.add(assetName).load(() -> {
				beginGame();
			});
		}
	}

	private function loadFonts() {
		var fonts = [
			"Fredoka Bold",
			"Chubby Cheeks",
			"GAU",
			"Orbitron",
			"Junegull-Regular",
			"Jost-Medium",
			"LCD",
			"IronMan",
			"Pricedown",
			"Megaton",
			"Alien Encounters Solid",
			"LondonTwo",
			"Kozuka Gothic Pro H",
			"Neuropol",
		];
		return Promise.all(fonts.map(font -> Browser.window.document.fonts.load("16px " + font)));
	}

	private function beginGame() {
		common_haxe_avm1.KeyboardManager.clearState();
		common_haxe_avm1.MouseManager.clearState();
		// extra keys of the game (ZQSD / WASD, Enter...), see KeyboardManager.KeyAlias
		common_haxe_avm1.KeyboardManager.setAliases(cast Reflect.field(gameClass, "KEY_ALIASES"));
		this.replay.start();
		this.gameRoot = dm.empty(1);
		replayPaused = false;
		setReplaySpeed(1);
		var isReplay = this.replay.isPlayingReplay();
		// the daily game gives the same pieces to every player: no stir (a replay says if it was recorded with it)
		this.replay.setRngStir(runDetails == null || runDetails.shared_seed != true);
		Seed.setStirEnabled(this.replay.hasRngStir());
		if (isReplay) {
			this.gameRoot.interactive = false;
			this.gameRoot.interactiveChildren = false;
			if (this.replayHud == null) {
				this.replayHud = new ReplayHud(canvas, replay, FixedFramerate.STEP, {
					seek: seekReplay,
					setPaused: setReplayPaused,
					setSpeed: setReplaySpeed,
					step: stepReplay,
					markerHover: i -> emitWindowEvent("replayMarker", {index: i})
				});
				this.replayHud.setMarkers(replayMarkers);
				this.replayHud.setComment(replayComment);
			}
			this.stage.addChild(this.replayHud);
		} else {
			destroyReplayHud();
		}

		this.score = 0;
		common_haxe_avm1.kac.Natives.resetCounters();
		this.game = Type.createInstance(gameClass, [gameRoot, isReplay]);
		if (this.replay.isRecordingReplay()) {
			common_haxe_avm1.kac.Integrity.arm(this, game, replay, runFlow);
		} else {
			common_haxe_avm1.kac.Integrity.disarm();
		}
		setupTouchOverlay();
	}

	function displayEndScene(endRunDetails:Dto.EndRunResponseDTO) {
		runFlow.transition(EndScreen, "display-end-scene");
		reset(true);
		this.endScene = new EndScene(this, endRunDetails);
		this.stage.addChild(this.endScene);
		this.endScene.once('replay', () -> {
			runFlow.transition(ReplayTransition, "replay-clicked");
			reset();
			this.showIntroScreen();
		});
	}

	public function reset(?preserveScore:Bool = false):Void {
		replay.stop();
		seekTarget = null;
		catchUpTarget = null;
		hiddenAtMs = null;
		unfreezeSeek();
		destroyReplayHud();
		destroyTouchOverlay();
		replayPaused = false;
		replaySpeed = 1;
		if (!preserveScore) {
			score = 0;
		}
		common_haxe_avm1.KeyboardManager.clearState();
		common_haxe_avm1.MouseManager.clearState();
		AntiCheat.reset();
		common_haxe_avm1.kac.Integrity.disarm();

		if (game != null) {
			game.destroy();
			game = null;
		}

		if (startScene != null) {
			if (startScene.parent != null) {
				startScene.parent.removeChild(startScene);
			}
			startScene.destroy({children: true});
			startScene = null;
		}

		if (gameOverScreen != null) {
			if (gameOverScreen.parent != null) {
				gameOverScreen.parent.removeChild(gameOverScreen);
			}
			gameOverScreen.destroy({children: true});
			gameOverScreen = null;
		}

		if (submitPopup != null) {
			if (submitPopup.parent != null) {
				submitPopup.parent.removeChild(submitPopup);
			}
			submitPopup.destroy({children: true});
			submitPopup = null;
		}

		if (endScene != null) {
			if (endScene.parent != null) {
				endScene.parent.removeChild(endScene);
			}
			endScene.dispose();
			endScene.destroy({children: true});
			endScene = null;
		}

		if (bottomBar != null) {
			if (bottomBar.parent != null) {
				bottomBar.parent.removeChild(bottomBar);
			}
			bottomBar.destroy({children: true});
			bottomBar = null;
		}

		if (gameRoot != null) {
			if (gameRoot.parent != null) {
				gameRoot.parent.removeChild(gameRoot);
			}
			gameRoot.destroy({children: true});
			gameRoot = null;
		}

		mt.bumdum.Sprite.clearAll();
	}

	public function gameOver(params:Dynamic):Void {
		if (gameOverScreen != null) {
			return;
		}
		var wasInReplay = this.replay.isPlayingReplay();
		this.replay.stop();
		destroyTouchOverlay();
		// this.stage.removeChildren();
		gameOverScreen = new GameOver(() -> {
			if (wasInReplay) {
				runFlow.transition(EndScreen, "replay-ended");
				this.displayEndScene(neutralEndRunDetails());
			} else {
				runFlow.transition(SubmittingRun, "submit-end-run");
				// (the last check: before the mask is sent)
				common_haxe_avm1.kac.Integrity.check();
				common_haxe_avm1.kac.Integrity.disarm();
				#if debug
				trace('AntiCheat: ' + AntiCheat.getMask());
				#end
				submitPopup = new SubmitPopup(this);
				this.stage.addChild(submitPopup);
				var request = KadoEndRun.buildRequest(runFlow.getRunDetails(), score, runFlow.currentTimestamp(), replay.encodeReplayString(), params,
					AntiCheat.getPayload());
				makeEndRunHttpRequest(request).then((endRunDetails:Dto.EndRunResponseDTO) -> {
					this.displayEndScene(endRunDetails);
					emitWindowEvent("gameFinished", endRunDetails);
				}, (error:Dynamic) -> {
					onSubmitFailed(request, Api.toError(error));
				});
			}
		});
		this.stage.addChild(gameOverScreen);
		// the controls of a replay stay usable over the fade (going back to a moment of the replay)
		if (replayHud != null && wasInReplay) {
			this.stage.addChild(replayHud);
		}
		// trace('Game finished, showing end screen');
		#if debug
		trace('Replay data: ' + replay.encodeReplayString());
		#end
	}

	override public function destroy(?removeView:Bool):Void {
		this.stop();
		reset();
		destroyDebugFpsDisplay();
		this.ticker.stop();
		untyped Ticker.system.remove(systemTickerListener);
		Browser.document.removeEventListener("visibilitychange", onVisibilityChange);
		untyped Ticker.system.stop();
		this.root = null;
		super.destroy(removeView);
	}

	// REPLAY SEEKING
	// length of the replay in frames (older replays do not store it: estimated, it grows while they are played)
	public function getReplayLength():Int {
		var total = replay.getTotalFrames();
		if (total > 0) {
			return total;
		}
		return Std.int(Math.max(replay.getLastRecordedFrame() + 1, replay.getCurrentFrame()));
	}

	// go to a frame of the replay being watched (backwards too)
	public function seekReplay(frame:Int):Void {
		if (params == null || params.replayData == null || game == null || replayHud == null) {
			return;
		}
		var length = getReplayLength();
		frame = Std.int(Math.max(0, Math.min(length, frame)));
		var ended = gameOverScreen != null || !replay.isPlayingReplay();
		if (!ended && frame == replay.getCurrentFrame()) {
			return;
		}
		if (ended || frame < replay.getCurrentFrame()) {
			if (frame >= length && ended) {
				return;
			}
			freezeSeek();
			restartReplay();
		} else {
			freezeSeek();
		}
		seekFrom = replay.getCurrentFrame();
		seekTarget = frame;
	}

	// one frame forward or back, the replay being paused (forward: simulated and shown without interpolation)
	public function stepReplay(delta:Int):Void {
		if (replayHud == null || game == null || seekTarget != null) {
			return;
		}
		setReplayPaused(true);
		if (delta < 0) {
			seekReplay(replay.getCurrentFrame() - 1);
			return;
		}
		if (gameOverScreen != null || !replay.isPlayingReplay()) {
			return;
		}
		updatePhysics(FixedFramerate.STEP);
		if (gameRoot != null) {
			gameRoot.updateState();
		}
	}

	// the picture of the game stays on screen while the replay is simulated up to the wanted frame
	function freezeSeek():Void {
		if (seekFreeze == null && root != null) {
			var r:Dynamic = untyped this.renderer;
			var tex:pixi.core.textures.Texture = r.generateTexture(root, 1, 1, new pixi.core.math.shapes.Rectangle(0, 0, screen.width, gameAreaHeight()));
			seekFreeze = new pixi.core.sprites.Sprite(tex);
			stage.addChildAt(seekFreeze, stage.getChildIndex(root) + 1);
			seekStartMs = Browser.window.performance.now();
		}
		if (gameRoot != null)
			gameRoot.renderable = false;
	}

	function unfreezeSeek():Void {
		if (seekFreeze != null) {
			if (seekFreeze.parent != null)
				seekFreeze.parent.removeChild(seekFreeze);
			seekFreeze.destroy({children: true, texture: true, baseTexture: true});
			seekFreeze = null;
		}
		if (seekRing != null) {
			if (seekRing.parent != null)
				seekRing.parent.removeChild(seekRing);
			seekRing.destroy();
			seekRing = null;
		}
		if (gameRoot != null) {
			gameRoot.renderable = true;
			// shown at the reached frame, without interpolation from the frozen picture
			gameRoot.updateState();
			gameRoot.updateGraphics(1);
		}
	}

	// small ring over the frozen picture, only when the catch up of a hidden tab lasts (the controls of a replay show
	// the progress of a seek themselves)
	function updateSeekRing():Void {
		var target:Null<Int> = seekTarget != null ? seekTarget : catchUpTarget;
		if (target == null || seekFreeze == null || replayHud != null)
			return;
		var elapsed = Browser.window.performance.now() - seekStartMs;
		if (elapsed < SEEK_RING_DELAY_MS)
			return;
		if (seekRing == null) {
			seekRing = new pixi.core.graphics.Graphics();
			stage.addChildAt(seekRing, stage.getChildIndex(seekFreeze) + 1);
		}
		var span = Math.max(1, target - seekFrom);
		var p = Math.max(0, Math.min(1, (replay.getCurrentFrame() - seekFrom) / span));
		var g = seekRing;
		// (the middle of the game area)
		var cx = screen.width / 2;
		var cy = gameAreaHeight() / 2;
		g.clear();
		g.beginFill(0x000000, 0.55);
		g.drawCircle(cx, cy, 21);
		g.endFill();
		g.lineStyle(4, 0xFFFFFF, 0.3);
		g.drawCircle(cx, cy, 13);
		if (p > 0) {
			g.lineStyle(4, 0xFFFFFF, 1);
			g.moveTo(cx, cy - 13);
			g.arc(cx, cy, 13, -Math.PI / 2, -Math.PI / 2 + p * Math.PI * 2);
		}
	}

	// the replay starts again from its first frame, without leaving the screen of the game
	function restartReplay():Void {
		var paused = replayPaused;
		var speed = replaySpeed;
		if (gameOverScreen != null) {
			if (gameOverScreen.parent != null) {
				gameOverScreen.parent.removeChild(gameOverScreen);
			}
			gameOverScreen.destroy({children: true});
			gameOverScreen = null;
		}
		if (game != null) {
			game.destroy();
			game = null;
		}
		if (gameRoot != null) {
			if (gameRoot.parent != null) {
				gameRoot.parent.removeChild(gameRoot);
			}
			gameRoot.destroy({children: true});
			gameRoot = null;
		}
		mt.bumdum.Sprite.clearAll();
		AntiCheat.reset();
		replay.stop();
		Seed.init(seedHash);
		score = 0;
		if (bottomBar != null && seekFreeze == null) {
			bottomBar.updateScore(score);
		}
		beginGame();
		setReplaySpeed(speed);
		setReplayPaused(paused);
	}

	// ANTI CHEAT: NO PAUSE BY HIDING THE TAB

	function canCatchUp():Bool {
		return runFlow.state == Playing
			&& game != null
			&& gameOverScreen == null
			&& !replay.isPlayingReplay()
			&& Reflect.field(gameClass, "ALLOW_PAUSE") != true;
	}

	function onVisibilityChange(_):Void {
		var now = Browser.window.performance.now();
		if (Browser.document.hidden) {
			if (canCatchUp() && hiddenAtMs == null) {
				hiddenAtMs = now;
				hiddenAtFrame = replay.getCurrentFrame();
			}
			return;
		}
		if (hiddenAtMs == null)
			return;
		var lost = Math.min(now - hiddenAtMs, CATCH_UP_MAX_MS);
		hiddenAtMs = null;
		if (!canCatchUp())
			return;
		var target = hiddenAtFrame + Std.int(lost / FixedFramerate.STEP);
		if (target <= replay.getCurrentFrame())
			return;
		if (catchUpTarget == null) {
			freezeSeek();
			seekFrom = replay.getCurrentFrame();
		}
		catchUpTarget = target;
	}

	function runCatchUp():Void {
		var start = Browser.window.performance.now();
		if (gameRoot != null)
			gameRoot.renderable = false;
		while (catchUpTarget != null) {
			if (!canCatchUp() || replay.getCurrentFrame() >= catchUpTarget) {
				endCatchUp();
				return;
			}
			updatePhysics(FixedFramerate.STEP);
			if (Browser.window.performance.now() - start >= SEEK_BUDGET_MS) {
				return;
			}
		}
	}

	function endCatchUp():Void {
		catchUpTarget = null;
		unfreezeSeek();
		if (bottomBar != null) {
			bottomBar.updateScore(score);
		}
		emitWindowEvent("score", {score: score.get()});
		ff.reset();
	}

	function runSeek():Void {
		var start = Browser.window.performance.now();
		if (gameRoot != null)
			gameRoot.renderable = false;
		while (seekTarget != null) {
			if (game == null || !replay.isPlayingReplay() || replay.getCurrentFrame() >= seekTarget) {
				endSeek();
				return;
			}
			updatePhysics(FixedFramerate.STEP);
			if (Browser.window.performance.now() - start >= SEEK_BUDGET_MS) {
				return;
			}
		}
	}

	function endSeek():Void {
		seekTarget = null;
		unfreezeSeek();
		if (bottomBar != null) {
			bottomBar.updateScore(score);
		}
		emitWindowEvent("score", {score: score.get()});
		ff.reset();
	}

	// every picture: the controls of the replay follow it (they draw again only what changed)
	function updateReplayHud():Void {
		updateSeekRing();
		if (replayHud == null || replayHud.parent == null) {
			return;
		}
		var length = getReplayLength();
		var ended = gameOverScreen != null || !replay.isPlayingReplay();
		var frame = ended ? length : replay.getCurrentFrame();
		replayHud.update(frame, length, replay.getTotalFrames() > 0, replayPaused, replaySpeed, seekTarget, ended);
	}

	function destroyReplayHud():Void {
		if (replayHud != null) {
			replayHud.dispose();
			if (replayHud.parent != null) {
				replayHud.parent.removeChild(replayHud);
			}
			replayHud.destroy({children: true});
			replayHud = null;
		}
	}

	// API OF THE REPLAY PAGE (resources/js/composables/useReplayClock.js): the comments of the replay as marks of the
	// progress bar (frames; the pointer over one sends the window event "replayMarker" {index}, -1 when it leaves it), the
	// comment reached shown in the game (null: none; C hides them), the frame shown (-1 out of a replay)
	public function setReplayMarkers(frames:Array<Int>):Void {
		replayMarkers = frames == null ? [] : [for (f in frames) Std.int(f)];
		if (replayHud != null) {
			replayHud.setMarkers(replayMarkers);
		}
	}

	public function setReplayComment(comment:ReplayHud.ReplayHudComment):Void {
		replayComment = comment;
		if (replayHud != null) {
			replayHud.setComment(comment);
		}
	}

	public function areReplayCommentsShown():Bool {
		return replayHud == null || replayHud.areCommentsShown();
	}

	public function getReplayFrame():Int {
		if (params == null || params.replayData == null || game == null || replayHud == null) {
			return -1;
		}
		var ended = gameOverScreen != null || !replay.isPlayingReplay();
		return ended ? getReplayLength() : replay.getCurrentFrame();
	}

	public function isReplayPaused():Bool {
		return replayPaused;
	}

	// a seek is being computed (the frame jumps)
	public function isReplaySeeking():Bool {
		return seekTarget != null;
	}

	public function setReplaySpeed(speed:Float):Void {
		replaySpeed = Math.max(0.1, Math.min(16, speed));
	}

	public function setReplayPaused(paused:Bool):Void {
		replayPaused = paused;
	}

	public function addScore(points:Int):Void {
		score += points;
		// while a replay seek runs, the score is shown once at the end (no counting on screen)
		if (seekFreeze != null) {
			return;
		}
		if (bottomBar != null) {
			bottomBar.updateScore(score);
		}
		emitWindowEvent("score", {score: score.get()});
	}

	private function emitWindowEvent(eventName:String, ?detail:Dynamic):Void {
		var win:Dynamic = Browser.window;
		if (win == null || !Reflect.hasField(win, "evts")) {
			return;
		}
		var evts:Dynamic = Reflect.field(win, "evts");
		untyped evts.dispatchEvent(new CustomEvent(eventName, {detail: detail}));
	}

	// the end screen without result (replay watched, run not sent)
	inline function neutralEndRunDetails():Dto.EndRunResponseDTO {
		return {
			is_best: false,
			previous_star: -1,
			current_star: -1,
			people_to_beat: -1,
		};
	}

	// the run is kept in the local storage, to see why it was not sent and to send it again later from the site
	function onSubmitFailed(request:Null<Dto.EndRunPlainDTO>, error:Dto.ApiError):Void {
		trace('Run not sent: ' + error.status + ' ' + error.message);
		var stored = request != null && PendingRuns.save({
			run_id: request.run_id,
			game_id: params.gameId,
			game_name: params.name,
			saved_at: new js.lib.Date().toISOString(),
			request: request,
			error: error,
			attempts: 1,
		});
		runFlow.transition(SubmitFailed, "submit-failed");
		if (submitPopup != null) {
			submitPopup.showFailure(stored);
		}
		emitWindowEvent("runSubmitFailed", {
			run_id: request == null ? null : request.run_id,
			stored: stored,
			error: error,
		});
	}

	private function makeEndRunHttpRequest(request:Null<Dto.EndRunPlainDTO>):Promise<Dto.EndRunResponseDTO> {
		#if !debug
		if (request == null) {
			return cast Promise.reject(Api.toError("Missing run details"));
		}
		return endRunClient.submit(request).then((data) -> {
			endRunDetails = data;
			return endRunDetails;
		});
		#else
		trace(params);
		return Promise.resolve({
			is_best: true,
			previous_star: -1,
			current_star: 0,
			people_to_beat: 0,
		});
		#end
	}

	function setupTouchOverlay():Void {
		if (this.replay.isPlayingReplay() || !isTouchEnvironment()) {
			return;
		}

		var config:TouchControlsConfig = getTouchControlsConfig();
		if (config == null || config.mode == TouchControlsMode.NONE) {
			return;
		}

		destroyTouchOverlay();
		var passthroughMouseButtons = config.passthroughMouseButtons != false;
		touchOverlay = new TouchControlsOverlay(canvas, config, {
			onKeyDown: (keyCode:Int) -> {
				common_haxe_avm1.KeyboardManager.queueVirtualKeyDown(keyCode);
			},
			onKeyUp: (keyCode:Int) -> {
				common_haxe_avm1.KeyboardManager.queueVirtualKeyUp(keyCode);
			},
			onJoystick: (nx:Float, ny:Float, active:Bool) -> {
				common_haxe_avm1.MouseManager.queueInputCallback(() -> dispatchTouchJoystick(nx, ny, active));
			},
			onAction: (action:String) -> {
				common_haxe_avm1.MouseManager.queueInputCallback(() -> dispatchTouchAction(action));
			},
			onPointerDown: (x:Int, y:Int) -> {
				if (passthroughMouseButtons)
					common_haxe_avm1.MouseManager.queueVirtualPointerDown(common_haxe_avm1.MouseManager.BUTTON_LEFT, x, y);
				else
					common_haxe_avm1.MouseManager.queueVirtualPointerMove(x, y);
			},
			onPointerMove: (x:Int, y:Int) -> {
				common_haxe_avm1.MouseManager.queueVirtualPointerMove(x, y);
			},
			onPointerUp: (x:Int, y:Int) -> {
				if (passthroughMouseButtons)
					common_haxe_avm1.MouseManager.queueVirtualPointerUp(common_haxe_avm1.MouseManager.BUTTON_LEFT, x, y);
				else
					common_haxe_avm1.MouseManager.queueVirtualPointerMove(x, y);
			}
		});
	}

	function destroyTouchOverlay():Void {
		if (touchOverlay != null) {
			touchOverlay.destroy();
			touchOverlay = null;
		}
	}

	function getTouchControlsConfig():TouchControlsConfig {
		var raw = Reflect.field(gameClass, "TOUCH_CONTROLS");
		if (raw == null) {
			return null;
		}
		return cast raw;
	}

	function dispatchTouchJoystick(nx:Float, ny:Float, active:Bool):Void {
		if (game == null) {
			return;
		}
		var fn = Reflect.field(game, "onTouchJoystick");
		if (fn != null) {
			Reflect.callMethod(game, fn, [nx, ny, active]);
		}
	}

	function dispatchTouchAction(action:String):Void {
		if (game == null) {
			return;
		}
		var fn = Reflect.field(game, "onTouchAction");
		if (fn != null) {
			Reflect.callMethod(game, fn, [action]);
		}
	}

	// a game turns the touch joystick off while one of its menus is tapped
	public function setTouchJoystickEnabled(enabled:Bool):Void {
		if (touchOverlay != null) {
			touchOverlay.setJoystickEnabled(enabled);
		}
	}

	public function getTouchJoystickState():Null<TouchJoystickState> {
		if (touchOverlay == null) {
			return null;
		}
		return touchOverlay.getJoystickState();
	}

	function pollGameTouchControls():Void {
		if (game == null) {
			return;
		}
		var fn = Reflect.field(game, "pollTouchControls");
		if (fn != null) {
			Reflect.callMethod(game, fn, []);
		}
	}

	function isTouchEnvironment():Bool {
		var nav:Dynamic = Browser.navigator;
		if (nav != null && Reflect.hasField(nav, "maxTouchPoints")) {
			var points:Dynamic = Reflect.field(nav, "maxTouchPoints");
			if (points != null && points > 0) {
				return true;
			}
		}

		var hasTouchEvent = Reflect.hasField(Browser.window, "ontouchstart");
		if (hasTouchEvent) {
			return true;
		}

		var matchMedia = Browser.window.matchMedia;
		if (matchMedia != null) {
			return matchMedia("(pointer: coarse)").matches;
		}
		return false;
	}
}
