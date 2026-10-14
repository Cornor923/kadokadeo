package happyptitank;

import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchControlsMode;
import common_haxe_avm1.display.ASprite;
import happyptitank.EnemyShot;
import happyptitank.Scroll;
import happyptitank.Tank;
import happyptitank.GameOver;
import happyptitank.Warning;
import happyptitank.XMissile;
import happyptitank.UserInterface;

// @:bind IncomingArrow (symbol 88)
class IncomingArrow extends MovieClip {
	public function new() {
		super(88, true);
	}
}

// This is an hack for linux / flashplayer keyboard event UP/DOWN bug
// (port: the key events are the changes of the keys polled by KadoKadeo, recorded in the replay; ZQSD / WASD are
// the arrows through KEY_ALIASES)
class Key {
	static var keys:List<Key>;
	public static var UP:Key;
	public static var DOWN:Key;
	public static var LEFT:Key;
	public static var RIGHT:Key;

	public var isDown:Bool;

	var code:Int;
	var down:Bool;
	var frames:Int;
	// port: the key polled at the last Flash frame, and a press released before the next one
	var polled:Bool = false;
	var tapped:Bool = false;

	function new(c:Int) {
		code = c;
		isDown = false;
		down = false;
		frames = 0;
		keys.push(this);
	}

	function setDown(d:Bool) {
		if (d) {
			isDown = true;
			down = true;
			frames = 0;
		} else {
			down = false;
			frames = 1;
		}
	}

	public static function init() {
		keys = new List<Key>();
		UP = new Key(KeyboardManager.UP);
		DOWN = new Key(KeyboardManager.DOWN);
		LEFT = new Key(KeyboardManager.LEFT);
		RIGHT = new Key(KeyboardManager.RIGHT);
	}

	// port: every step (a press shorter than a step between two Flash frames is not lost)
	public static function pollStep() {
		for (k in keys)
			if (KeyboardManager.isJustDown(k.code) && !KeyboardManager.isDown(k.code))
				k.tapped = true;
	}

	// port: the KEY_DOWN / KEY_UP events received since the last Flash frame
	public static function events() {
		for (k in keys) {
			var d = KeyboardManager.isDown(k.code);
			if (k.tapped && !d && !k.polled) {
				k.setDown(true);
				k.setDown(false);
			} else if (d != k.polled)
				k.setDown(d);
			k.polled = d;
			k.tapped = false;
		}
	}

	public static function update() {
		for (k in keys) {
			if (k.isDown && !k.down) {
				k.frames++;
				if (k.frames > 3)
					k.isDown = false;
			}
		}
	}
}

@:expose('GameHappyPtiTank')
class Game extends Sprite implements kado.GameInterface {
	// the left half of the screen: a joystick moving the tank (8 directions, like the arrows); a finger elsewhere is
	// the mouse: it aims and fires while it stays on the screen
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.JOYSTICK,
		joystick: {dynamicCenter: true, directions: 8},
		passthroughMouseButtons: true,
	};

	// ZQSD / WASD move like the arrows (the original's Key class)
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE;

	// Happy Pti Tank played at 30 Flash frames/s (game.swf, the KadoKado loader and mt.Timer.wantedFPS)
	public static inline var FLASH_FPS = 30;
	// the original's 300 x 300 pixels, drawn x2
	public static inline var K = 2;

	static var FATAL_MISSILE_TIME:KKConst;
	static var FATAL_MISSILE_LAUNCH:KKConst; // countdown timer start at wave n°X
	static var INIT_CIRCLE:KKConst; // first two circles do not count

	public static var MAX_ARMOR:KKConst;

	public var now:Float;

	public static var color:ColorSet;
	public static var W = 300;
	public static var H = 300;
	public static var mouseDown = false;
	public static var instance:Game;

	public var userInterface:UserInterface; // above all layer for user interface
	public var gameLayer:Sprite; // where sprites live and die
	public var warZone:WarZone; // wall locking user
	public var warning:Warning; // warning message

	var lastZone:Float; // last warzone end time

	public var groundLayer:Sprite; // ground layer
	public var scroll:GroundScroll; // ground
	public var tank:Tank; // player
	public var target:Target; // player's target
	public var activeOption:Option; // player's current active option
	public var shots:List<Shot>; // player's shots
	public var options:List<Option>; // options on ground
	public var spawners:List<Spawner>; // foes spawners
	public var foes:List<Enemy>; // list of foes
	public var foesShots:List<EnemyShot>; // foes' shots
	public var foesMines:List<Mine>; // foes' mines
	public var missiles:List<XMissile>; // falling missiles
	public var fxLayer:Sprite; // play explosions and stuff there
	public var anims:List<Anim>; // things to update each frame
	public var incomingArrows:Array<IncomingArrow>; // small ui arrows pointing at enemies
	var arrowFoes:Array<Enemy>; // (port) the foe each arrow pointed at during the last frame
	public var optTimes:KKConst; // number of time options used during this game

	var quake:{timer:Float, power:Float}; // quake fx time and intensity

	public var endTime:Null<Float>; // end of game time

	var lastShot:Float;

	public var shotRate:Float;

	var gameover:Bool;
	var gameOverAnim:Anim;
	var lastMissile:Float;
	var lastMissileK:Int;
	var kills:Int;
	var started:Bool;
	var waves:KKConst;

	public var armor:KKConst;
	public var score:KKConst;
	public var circle:KKConst;

	var slowFrames:Int;

	public var slowLevel:Int;
	public var tankRecall:{x:Float, y:Float};

	// flash.Lib.current: the root of the game's display list
	public static var root:MovieClip;

	// port
	var isReplay:Bool;
	var stage:ASprite;
	// Flash frames owed, in 16ths of a step (15 per step)
	var frameAcc:Int = 16;
	var frameCount:Int = 0;
	var over:Bool = false;
	var cursorHidden:Bool = false;
	var onPointerDown:Dynamic->Void = null;
	#if debug
	// test harness: errors the Flash player would have swallowed, events of the game
	public var flashErrors:Array<String> = [];
	public var stats = {
		shots: 0,
		kills: 0,
		hits: 0,
		options: 0,
		missiles: 0,
		zones: 0,
		circles: 0
	};
	public var killsBy:Dynamic = {};
	#end

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		super();
		this.isReplay = isReplay;
		var keys = new UInt16Array(4);
		keys[0] = KeyboardManager.UP;
		keys[1] = KeyboardManager.DOWN;
		keys[2] = KeyboardManager.LEFT;
		keys[3] = KeyboardManager.RIGHT;
		var buttons = new UInt16Array(1);
		buttons[0] = MouseManager.BUTTON_LEFT;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: keys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: true,
			recordedMouseButtons: buttons,
		});
		// one page plays several games and replays: the statics of the original start again
		resetStatics();
		// the root of the display list (flash.Lib.current), drawn x2
		stage = mc.createEmptyMovieClip("scene", 0);
		stage._xscale = stage._yscale = 100 * K;
		stage.updateState();
		var r = new MovieClip(-1);
		stage.addChild(r.view(0));
		// like the Flash player, a pressed button keeps the mouse until it is released (KadoKadeo releases the buttons
		// when the pointer leaves the canvas)
		if (!isReplay) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			onPointerDown = function(e:Dynamic) {
				try {
					canvas.setPointerCapture(e.pointerId);
				} catch (_:Dynamic) {}
			};
			canvas.addEventListener("pointerdown", onPointerDown);
		}
		init(r);
		#if debug
		// test harness: classes for the staged pictures (hart.mjs)
		untyped js.Browser.window.HPT = {
			Foe: Foe,
			FoeBack: Foe.FoeBack,
			Shot: Shot,
			XMissile: XMissile,
			EnemyDeathAnim: EnemyDeathAnim,
			OptShot: OptShot,
			OptSpeed: OptSpeed,
			Geom: Geom,
			MovieClip: MovieClip,
			BigBulleter: BigBullet.BigBulleter
		};
		#end
		// Manager.init, then the loader calls Manager.main at once: the first frame, with no playhead moved
		flashFrame(false);
		display(1);
		warmShaders();
	}

	// the first use of a filter compiles its shader (a frozen frame): the masks of the zone banner, the blurs and glows
	// of the end animations, a texture fill of the ground and the additive pictures, drawn once now
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		if (renderer == null)
			return;
		var holder = new pixi.core.display.Container();
		var t = Tex.get("TEX1")[0];
		var a = new pixi.core.sprites.Sprite(t);
		a.filters = [new FlashFilter(4, 4, 1, false)];
		holder.addChild(a);
		var b = new pixi.core.sprites.Sprite(t);
		b.filters = [new FlashFilter(4, 4, 2, true, 0, 1)];
		holder.addChild(b);
		var m = new pixi.core.sprites.Sprite(t);
		var c = new pixi.core.sprites.Sprite(t);
		c.filters = [new MaskFilter(m)];
		holder.addChild(m);
		holder.addChild(c);
		var d = new pixi.core.sprites.Sprite(t);
		d.blendMode = pixi.core.Pixi.BlendModes.ADD;
		holder.addChild(d);
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	function resetStatics() {
		Sprite.resetAll();
		Sprite.clearGhosts();
		MovieClip.factories = new Map();
		MovieClip.factories.set(162, () -> new TankTracks());
		MovieClip.factories.set(180, () -> new TankCanon());
		MovieClip.factories.set(97, () -> new OptTimer());
		Shot.COLOR = 0;
		mouseDown = false;
		instance = null;
		// mt.Timer of the original: 32 until Game sets 30 (the tank is built before)
		Timer.wantedFPS = 32;
		Timer.tmod = 1;
		Key.init();
		untyped Tank.oldVector = "";
	}

	// the original's constructor
	function init(r:MovieClip) {
		FATAL_MISSILE_LAUNCH = KKApi.const(3);
		FATAL_MISSILE_TIME = KKApi.const(120);

		INIT_CIRCLE = KKApi.const(4);
		MAX_ARMOR = KKApi.const(10);
		Game.root = r;
		kills = 0;
		color = new ColorSet();
		// flash.ui.Mouse.hide(): the target follows the mouse
		hideCursor(true);
		instance = this;
		slowFrames = 0;
		slowLevel = 0;
		armor = KKApi.const(8);
		score = KKApi.const(0);
		waves = KKApi.const(0);
		optTimes = KKApi.const(0);
		gameover = false;
		circle = KKApi.const(KKApi.val(INIT_CIRCLE));
		endTime = null;
		lastShot = 0;
		shotRate = 333;
		incomingArrows = [];
		arrowFoes = [null, null, null];
		shots = new List();
		options = new List();
		foes = new List();
		foesShots = new List();
		foesMines = new List();
		spawners = new List();
		anims = new List();
		missiles = new List();
		now = 0;
		lastZone = now + 2000;
		lastMissile = now + 2000;
		lastMissileK = -1;
		initGameLayer();
		for (i in 0...3) {
			var arrow = new IncomingArrow();
			arrow.visible = false;
			incomingArrows.push(arrow);
			groundLayer.addChild(arrow);
		}
		initUserInterface();
		started = false;
		Timer.wantedFPS = 30;
		Game.root.addChild(this);
		// (KKApi.registerButton(Game.root) and the MOUSE_DOWN / MOUSE_UP listeners: Game.mouseDown is the polled button,
		// the key listeners: Key.events)
	}

	public function doQuake(time:Float, power:Float) {
		if (slowLevel == 3)
			return;
		if (slowLevel == 2)
			power = power / 2;
		if (quake != null && quake.power > power) {
			quake.timer += time / 2;
			quake.power += 0.01;
			quake.power = Math.min(0.02, quake.power);
			return;
		}
		quake = {timer: time, power: power};
	}

	function initGameLayer() {
		groundLayer = new Sprite();
		addChild(groundLayer);
		scroll = new GroundScroll();
		groundLayer.addChild(scroll);
		groundLayer.x = W / 2;
		groundLayer.y = H / 2;
		gameLayer = new Sprite();
		gameLayer.x = W / 2;
		gameLayer.y = H / 2;
		addChild(gameLayer);
		warZone = new WarZone();
		gameLayer.addChild(warZone);
		groundLayer = new Sprite();
		gameLayer.addChild(groundLayer);
		tank = new Tank();
		tank.x = 0;
		tank.y = 0;
		gameLayer.addChild(tank);
		fxLayer = new Sprite();
		addChild(fxLayer);
		target = new Target();
		tank.target = target;
		addChild(target);
	}

	function initUserInterface() {
		userInterface = new UserInterface();
		addChild(userInterface);
	}

	static var frames = 0;

	// the original's update(): one Flash frame
	function origUpdate() {
		frames++;
		var resetSlow = false;
		// (mt.Timer.tmod is 1: the frame rate is always the wanted one, the quality is never lowered)
		if (Timer.tmod > 1.01 && slowLevel < 3) {
			slowFrames++;
			var slowRatio = slowFrames / frames;
			if (frames < Timer.wantedFPS * 5) {} else {
				if (slowLevel < 1 && slowRatio > 0.3) {
					slowLevel = 1;
					resetSlow = true;
					hideCursor(false);
					target.visible = false;
				} else if (slowLevel < 2 && slowRatio > 0.5) {
					slowLevel = 2;
					resetSlow = true;
				} else if (slowRatio > 0.8) {
					slowLevel = 3;
					resetSlow = true;
				}
			}
		}
		if (resetSlow || frames > Timer.wantedFPS * 10) {
			frames = Math.round(frames / 2);
			slowFrames = Math.round(slowFrames / 2);
		}
		Key.update();
		var gameWasOver = gameover;
		now += Timer.deltaT * 1000;
		if (quake != null && quake.timer > 0.0) {
			quake.timer -= Timer.deltaT;
			if (quake.timer <= 0.0) {
				quake = null;
				x = 0;
				y = 0;
			} else {
				// (the picture only: visual random)
				x = (Seed.randVfx() * quake.power * W * 2 - quake.power * W);
				y = (Seed.randVfx() * quake.power * H * 2 - quake.power * H);
			}
		}
		if (started && warZone.visible == false) {
			if ((now - lastZone) / 5000 > 1 + Seed.rand())
				enterWarZone();
			else
				launchMissiles();
		}
		if (!gameover) {
			started = tank.updateControls(Key.UP.isDown, Key.DOWN.isDown, Key.LEFT.isDown, Key.RIGHT.isDown) || started;
			tank.move();
		}
		tank.update();
		// do not move over warzone's courtesy line
		if (warZone.visible) {
			if (warZone.minX >= tank.x || warZone.maxX <= tank.x || warZone.minY >= tank.y || warZone.maxY <= tank.y)
				tank.unmove();
		}

		for (s in spawners)
			s.update();

		// update options
		for (o in options) {
			o.update(now);
			if (Collision.isColliding(tank, o, gameLayer, true, 0)) {
				if (activeOption != null) {
					activeOption.inactivate();
					activeOption = null;
				}
				o.activate();
				addScore(o.value);
				if (o.time != 0) {
					activeOption = o;
					o.end = now + o.time;
				}
				gameLayer.removeChild(o);
				options.remove(o);
				userInterface.gotOption(o);
				#if debug
				stats.options++;
				#end
			} else if (o.dead) {
				gameLayer.removeChild(o);
				options.remove(o);
			}
		}
		if (activeOption != null && activeOption.end <= now) {
			activeOption.inactivate();
			activeOption = null;
		}

		updateShotsAndFoes();

		if (!gameover && mouseDown)
			createShot(now);

		// update view and scroll
		target.visible = target.visible && !gameover;
		target.x = mouseX();
		target.y = mouseY();
		var vx = tank.x;
		var vy = tank.y;
		if (warZone.visible) {
			var minX = warZone.minX + W / 2 - 32;
			var maxX = warZone.maxX - W / 2 + 32;
			var minY = warZone.minY + H / 2 - 32;
			var maxY = warZone.maxY - H / 2 + 32;
			vx = Math.min(maxX, Math.max(minX, tank.x));
			vy = Math.min(maxY, Math.max(minY, tank.y));
		} else if (tankRecall != null) {
			var rtime = 0.4;
			vx += tankRecall.x * rtime * Timer.tmod;
			vy += tankRecall.y * rtime * Timer.tmod;
			tankRecall.x -= tankRecall.x * rtime * Timer.tmod;
			tankRecall.y -= tankRecall.y * rtime * Timer.tmod;
			if (Math.abs(tankRecall.x) < 5.0 && Math.abs(tankRecall.y) < 5.0)
				tankRecall = null;
		}
		tank.screenX = tank.x - vx + W / 2;
		tank.screenY = tank.y - vy + H / 2;
		gameLayer.x = -vx + W / 2;
		gameLayer.y = -vy + H / 2;
		fxLayer.x = gameLayer.x;
		fxLayer.y = gameLayer.y;
		scroll.update(vx, vy);
		if (scroll.getCurrentCircle() > KKApi.val(circle)) {
			new NewCircleAnim();
			circle = KKApi.const(scroll.getCurrentCircle());
			addScore(KKApi.const((KKApi.val(circle) - KKApi.val(INIT_CIRCLE)) * 250));
			#if debug
			stats.circles++;
			#end
		}
		// check life
		if (KKApi.val(armor) <= 0) {
			gameover = true;
			tank.speed = 0;
		}
		var timeover = false;
		// check remaining time
		if (endTime != null) {
			var remain = Math.max(0, endTime - now);
			timeover = remain == 0;
			gameover = gameover || timeover;
			var ex = remain % 1000;
			remain = Std.int(remain / 1000.0);
			var seconds = remain % 60;
			remain = Std.int(remain / 60);
			var minutes = remain;
			// update ui option
			if (activeOption == null || !Std.isOfType(activeOption, OptTime))
				userInterface.time.text = StringTools.lpad(Std.string(minutes), "0", 2) + ":" + StringTools.lpad(Std.string(seconds), "0", 2);
		}
		// update ui circle
		userInterface.level.text = Std.string(KKApi.val(circle) - KKApi.val(INIT_CIRCLE));
		// game over reached during this frame
		if (!gameWasOver && gameover)
			gameOver(timeover);
		// no more foe
		if (warZone.visible == true && spawners.length == 0 && foes.length == 0) {
			leaveWarZone(now);
			tankRecall = {x: vx - tank.x, y: vy - tank.y};
		}
		// update extra anims
		for (anim in anims)
			if (!anim.update())
				anims.remove(anim);
		// update user interface
		userInterface.update(now);
		// update incoming Arrows
		for (arrow in incomingArrows)
			arrow.visible = false;
		var done = 0;
		for (foe in foes) {
			var dist = Geom.distance(tank, foe);
			if (dist > W / 2) {
				var angle = Geom.angleRad(tank, foe);
				var arrow = incomingArrows[done];
				arrow.visible = true;
				arrow.x = tank.x;
				arrow.y = tank.y;
				arrow.rotation = Geom.rad2deg(angle) - 180;
				Geom.moveAngle(arrow, angle, 100);
				// (port) the arrows are given to the far foes in the order of the list: when a foe comes near (or dies),
				// the arrows after it go to other foes, and back when it goes away. Flash showed the jump; the
				// interpolated display slid the arrow around the tank from one foe to the other, and back
				if (arrowFoes[done] != foe) {
					arrowFoes[done] = foe;
					arrow.jumped = true;
				}
				done++;
				if (done == incomingArrows.length)
					break;
			}
		}
		if (gameOverAnim != null && !gameOverAnim.update()) {
			// (the loader goes on calling Game.update: KKApi.gameOver every frame, once is enough here)
			if (!over) {
				over = true;
				hideCursor(false);
				KadoKadeoManager.kkm.gameOver({
					_waves: KKApi.val(waves),
					_circle: KKApi.val(circle),
					_extraSeconds: KKApi.val(optTimes),
					_kills: kills,
				});
			}
		}
	}

	function updateShotsAndFoes() {
		var boundaries = {
			min: {x: tank.x - W / 2 - 64, y: tank.y - H / 2 - 64},
			max: {x: tank.x + W / 2 + 64, y: tank.y + H / 2 + 64}
		};
		for (shot in shots) {
			shot.update();
			var destroyed = false;
			for (e in foes) {
				if (e.collideWithShot(shot)) {
					destroyed = true;
					shots.remove(shot);
					gameLayer.removeChild(shot);
					break;
				}
			}
			if (!destroyed
				&& (shot.x < boundaries.min.x || shot.x > boundaries.max.x || shot.y < boundaries.min.y || shot.y > boundaries.max.y)) {
				gameLayer.removeChild(shot);
				shots.remove(shot);
			}
		}
		for (mine in foesMines) {
			mine.update();
			if (Collision.isColliding(mine, tank, Game.root, true, 0)) {
				foesMines.remove(mine);
				gameLayer.removeChild(mine);
				tankDamaged();
				tank.setState(Hurt);
			}
		}
		for (shot in foesShots) {
			shot.update();
			if (Collision.isColliding(shot, tank, Game.root, true, 0)) {
				if (Std.isOfType(shot, Lazer)) {
					anims.push(shot);
					foesShots.remove(shot);
				} else {
					gameLayer.removeChild(shot);
					foesShots.remove(shot);
				}
				tankDamaged(shot.power);
				tank.setState(Hurt);
			} else if (shot.x < boundaries.min.x || shot.x > boundaries.max.x || shot.y < boundaries.min.y || shot.y > boundaries.max.y || shot.destroyed) {
				if (shot.parent != null)
					shot.parent.removeChild(shot);
				foesShots.remove(shot);
			}
		}
		for (enemy in foes) {
			if (Collision.isColliding(enemy, tank, Game.root, true, 0)) {
				enemy.damaged(10);
				tankDamaged();
				tank.setState(Hurt);
				if (enemy.life <= 0)
					enemyDestroyed(enemy, true);
			} else if (enemy.life <= 0)
				enemyDestroyed(enemy);
			else
				enemy.update();
		}
		for (missile in missiles) {
			missile.update();
			if (missile.dangerous && missile.isColliding(tank)) {
				missile.dangerous = false;
				tankDamaged();
				tank.setState(Hurt);
			}
		}
	}

	function tankDamaged(damages:Int = 1) {
		var a = KKApi.val(armor);
		a -= damages;
		a = Std.int(Math.max(0, a));
		armor = KKApi.const(a);
		doQuake(1 / 2, 1 * 0.05);
		updateArmorBits();
		#if debug
		stats.hits++;
		#end
	}

	public function updateArmorBits() {
		userInterface.updateArmorBits();
	}

	function createShot(now:Float) {
		if (lastShot > now - shotRate)
			return;
		var angles = [tank.getAimAngle()];
		if (activeOption != null && Std.isOfType(activeOption, OptShot)) {
			angles.push(angles[0] - 10);
			angles.push(angles[0] + 10);
		}
		Shot.nextColor();
		for (angle in angles) {
			var vector = Geom.radToVector(Geom.deg2rad(angle));
			var shot = new Shot(vector, Shot.COLOR);
			shot.x = tank.x + vector.x * 30;
			shot.y = tank.y + vector.y * 30;
			shot.rotation = angle - 180;
			shot.speed = Math.max(tank.maxSpeed * 1.5, shot.speed);
			gameLayer.addChild(shot);
			shots.push(shot);
			#if debug
			stats.shots++;
			#end
		}
		lastShot = now;
	}

	function enemyDestroyed(e:Enemy, ?onCollisionWithTank = false) {
		kills++;
		e.onDeath();
		foes.remove(e);
		new EnemyDeathAnim(e);
		if (!gameover)
			addScore(e.value);
		if (e.maxLife > 5)
			doQuake(0.5 * Seed.randVfx(), 0.008);
		if (onCollisionWithTank == false)
			spawnOptionAt(e.x, e.y);
		#if debug
		stats.kills++;
		var cn = Type.getClassName(Type.getClass(e)).split(".").pop();
		Reflect.setField(killsBy, cn, (Reflect.hasField(killsBy, cn) ? Reflect.field(killsBy, cn) : 0) + 1);
		#end
	}

	static var OPT_TABLE:Array<Class<Option>> = {
		var probabilities:Array<{k:Class<Option>, p:Int}> = [
			{k: null, p: 30},
			{k: OptShot, p: 3},
			{k: OptTime, p: 1},
			{k: OptArmor, p: 1},
			{k: OptSpeed, p: 2},
			{k: OptShotRate, p: 2}
		];
		var bigtable:Array<Class<Option>> = [];
		var i = 0;
		for (p in probabilities) {
			if (p.k == null)
				i = p.p;
			else {
				for (j in 0...p.p)
					bigtable[i++] = p.k;
			}
		}
		bigtable;
	};

	function randomOption():Option {
		var ran = Seed.random(OPT_TABLE.length);
		if (OPT_TABLE[ran] == null)
			return null;
		if (KKApi.val(waves) < KKApi.val(FATAL_MISSILE_LAUNCH) && OPT_TABLE[ran] == OptTime)
			return null;
		return Type.createInstance(OPT_TABLE[ran], []);
	}

	function spawnOptionAt(x:Float, y:Float) {
		var option = randomOption();
		if (option == null)
			return;
		option.x = x;
		option.y = y;
		for (s in spawners)
			if (s.getRect(s.parent).containsPoint(x, y))
				return;
		for (o in options)
			if (o.getRect(o.parent).containsPoint(x, y))
				return;
		gameLayer.addChild(option);
		options.push(option);
	}

	function gameOver(timeup:Bool) {
		gameOverAnim = if (timeup) new TheEnd() else new YouDie();
	}

	public function addAnimation(a:Anim) {
		anims.push(a);
	}

	public function delAnimation(a:Anim):Bool {
		return anims.remove(a);
	}

	public function addSpawner(s:Spawner) {
		spawners.push(s);
		groundLayer.addChild(s);
	}

	public function addFoe(f:Enemy) {
		foes.push(f);
		gameLayer.addChild(f);
	}

	public function createEnemyShot(emitter:Enemy, ?vector:Geom._Ptx):EnemyShot {
		if (vector == null)
			vector = Geom.radToVector(Geom.angleRad(emitter, tank));
		var shot = new EnemyShot(vector);
		shot.x = emitter.x;
		shot.y = emitter.y;
		gameLayer.addChild(shot);
		foesShots.push(shot);
		return shot;
	}

	public function createEnemyLazer(origin:{x:Float, y:Float}, angleDeg:Float) {
		var shot = new Lazer();
		shot.x = origin.x;
		shot.y = origin.y;
		// shot.rotation = Geom.rad2deg(angle) - 90;
		shot.rotation = angleDeg;
		gameLayer.addChild(shot);
		foesShots.push(shot);
	}

	function enterWarZone() {
		if (warZone.visible == true || gameover)
			return;
		warZone.init(tank.x, tank.y);
		tank.setBounds(warZone);
		if (!gameover)
			setWarning(new Warning());
		var diff = Std.int(Math.max(1, KKApi.val(circle) - KKApi.val(INIT_CIRCLE)));
		diff = Std.int(Math.max(diff, KKApi.val(waves)));
		WarZoneBuilder.build(diff);
		#if debug
		stats.zones++;
		#end
	}

	function leaveWarZone(now:Float) {
		waves = KKApi.const(KKApi.val(waves) + 1);
		if (endTime == null && KKApi.val(waves) >= KKApi.val(FATAL_MISSILE_LAUNCH)) {
			// TODO: check which fatal time is used there
			endTime = now + KKApi.val(FATAL_MISSILE_TIME) * 1000.0;
			userInterface.enableTime();
		}
		warZone.visible = false;
		lastZone = now;
		lastMissile = now;
		for (mine in foesMines) {
			gameLayer.removeChild(mine);
			// TODO: mine explose
		}
		tank.setBounds(null);
		foesMines = new List();
		if (!gameover)
			setWarning(new Rainbow1());
	}

	function setWarning(w:Warning) {
		if (warning != null) {
			delAnimation(warning);
			if (warning.parent != null)
				warning.parent.removeChild(warning);
		}
		warning = w;
	}

	function launchMissiles() {
		if (missiles.length >= 10 || (now - lastMissile) <= 1500 || Seed.rand() < 0.3)
			return;
		lastMissile = now;
		lastMissileK++;
		var angle = tank.angle;
		switch (lastMissileK % 3) {
			case 0:
				var coord = {x: tank.x, y: tank.y};
				Geom.moveAngle(coord, angle, tank.direction * tank.speed * 30);
				new XMissile(coord.x, coord.y);
			case 1:
				for (i in 0...3) {
					angle = angle + (15 - Seed.random(30));
					var coord = {x: tank.x, y: tank.y};
					Geom.moveAngle(coord, angle, tank.direction * tank.speed * 30);
					new XMissile(coord.x, coord.y, 0.5 * i);
				}
			case 2:
				var coord = {x: tank.x, y: tank.y};
				Geom.moveAngle(coord, angle, tank.direction * tank.speed * 30);
				new XMissile(coord.x, coord.y, 0.0);
				var relative = {x: coord.x - tank.x, y: coord.y - tank.y};
				Geom.rotate(relative, Math.PI / 3);
				new XMissile(tank.x + relative.x, tank.y + relative.y, 0.5);
				var relative = {x: coord.x - tank.x, y: coord.y - tank.y};
				Geom.rotate(relative, -Math.PI / 3);
				new XMissile(tank.x + relative.x, tank.y + relative.y, 0.5);
		}
		#if debug
		stats.missiles++;
		#end
	}

	// ================================================================ port
	// KKApi.addScore: nothing after the end of the game
	function addScore(v:KKConst):KKConst {
		if (!over)
			KadoKadeoManager.kkm.addScore(KKApi.val(v));
		score = KKApi.const(KKApi.val(score) + KKApi.val(v));
		return score;
	}

	// a step of KadoKadeo (32 per second): 15 Flash frames every 16 steps, then the picture one Flash frame late
	public function update(delta:Float) {
		Key.pollStep();
		frameAcc += 15;
		while (frameAcc >= 16) {
			frameAcc -= 16;
			flashFrame();
		}
		display(frameAcc / 16);
	}

	// one Flash frame: the playheads move, then Manager.main (mt.Timer: 30 frames/s, tmod 1), then the state shown
	function flashFrame(advance:Bool = true) {
		Sprite.clearGhosts();
		DisplayObject.flashFrame++;
		Timer.tmod = 1;
		Timer.deltaT = 1 / FLASH_FPS;
		if (advance)
			MovieClip.advanceAll(root);
		Key.events();
		mouseDown = MouseManager.isButtonDown(MouseManager.BUTTON_LEFT);
		try {
			origUpdate();
		} catch (e:FlashError) {
			// the Flash player stops the code of the frame and goes on with the next one
			#if debug
			flashErrors.push(e.msg);
			#end
		}
		root.snapshotTree();
		frameCount++;
		#if debug
		untyped js.Browser.window.__state = debugState();
		if (over && untyped js.Browser.window.__over == null)
			untyped js.Browser.window.__over = debugState();
		#end
	}

	function display(f:Float) {
		root.syncTree(0, f, [1, 1, 1], [0, 0, 0, 0], false, false);
		root.applyView(0, f, 0, 0, false, false);
	}

	// the root of the PIXI picture (x2)
	public function stageView():ASprite {
		return stage;
	}

	// Game.root.mouseX / mouseY (the stage of 300 x 300)
	static function mouseX():Float {
		return Math.max(0, MouseManager.getX()) / K;
	}

	static function mouseY():Float {
		return Math.max(0, MouseManager.getY()) / K;
	}

	function hideCursor(h:Bool) {
		if (isReplay || cursorHidden == h)
			return;
		cursorHidden = h;
		var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
		if (canvas != null)
			canvas.style.cursor = h ? "none" : "";
	}

	// the joystick of a touch screen: the arrows
	public function pollTouchControls():Void {
		var j = KadoKadeoManager.kkm.getTouchJoystickState();
		if (j == null)
			return;
		var ax = j.active ? j.dirX : 0;
		var ay = j.active ? j.dirY : 0;
		setDirectionalKey(KeyboardManager.LEFT, ax < 0);
		setDirectionalKey(KeyboardManager.RIGHT, ax > 0);
		setDirectionalKey(KeyboardManager.UP, ay < 0);
		setDirectionalKey(KeyboardManager.DOWN, ay > 0);
	}

	var touchKeys:Map<Int, Bool> = new Map();

	function setDirectionalKey(code:Int, down:Bool) {
		var was = touchKeys.get(code) == true;
		if (down == was)
			return;
		touchKeys.set(code, down);
		if (down)
			KeyboardManager.setKeyDown(code);
		else
			KeyboardManager.setKeyUp(code);
	}

	public function destroy():Void {
		hideCursor(false);
		if (onPointerDown != null) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			canvas.removeEventListener("pointerdown", onPointerDown);
			onPointerDown = null;
		}
		GroundScroll.destroyTextures();
		resetStatics();
		if (stage != null && stage.parent != null)
			stage.parent.removeChild(stage);
	}

	#if debug
	function debugState():Dynamic {
		var fx = 0.0;
		for (f in foes)
			fx += f.x * 7 + f.y;
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			gscore: KKApi.val(score),
			tx: tank.x,
			ty: tank.y,
			ta: tank.angle,
			armor: KKApi.val(armor),
			circle: KKApi.val(circle),
			waves: KKApi.val(waves),
			now: now,
			endTime: endTime,
			foes: foes.length,
			fsum: Math.round(fx * 1000) / 1000,
			shots: shots.length,
			eshots: foesShots.length,
			missiles: missiles.length,
			zone: warZone.visible,
			over: over,
			errors: flashErrors.length,
			stats: haxe.Json.stringify(stats),
			killsBy: haxe.Json.stringify(killsBy)
		};
	}
	#end
}
