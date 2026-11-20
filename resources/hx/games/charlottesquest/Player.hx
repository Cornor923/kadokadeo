package charlottesquest;

typedef BuildSave = {
	speed:Int,
	front:Int,
	back:Int,
	up:Int,
	down:Int,
	capture:Int,
}

class PlayerBuild {
	public static inline var WMAX = 8;
	public static inline var SMAX = 5;

	public var speed:Int;
	public var front:Int;
	public var back:Int;
	public var up:Int;
	public var down:Int;
	public var capture:Int;

	public function new() {
		speed = 0;
		front = 0;
		back = 0;
		up = 0;
		down = 0;
		capture = 0;
	}

	public function save():BuildSave {
		return {
			speed: speed,
			front: front,
			back: back,
			up: up,
			down: down,
			capture: capture,
		}
	}

	public function toString() {
		return "front:" + front + ", " + "back:" + back + ", " + "up:" + up + ", " + "down:" + down + ", " + "capture:" + capture + ", " + "speed:"
			+ speed;
	}

	public function check() {
		if (speed > SMAX)
			speed = SMAX;

		var m = WMAX;
		if (front > m)
			front = m;
		if (back > m)
			back = m;
		if (up > m)
			up = m;
		if (down > m)
			down = m;
		if (capture > m)
			capture = m;
	}
}

class Player extends Entity {
	static inline var UBER_DURATION = 120;

	public var mc:MovieClip;

	var warning:Bitmap;

	public var lifeCont:Sprite;

	var lifeIcons:Array<MovieClip>;
	var scrollDeath:Int;
	var playerAnim:String;
	var normalRadius:Float;

	var hud:Sprite;

	public var build:PlayerBuild;

	// (the picture of lib.Rainbow drawn into the rainbow of the game)
	var rainbowMC:Bitmap;

	public function new() {
		super();

		hud = new Sprite();
		hud.addChild(lifeCont);

		applyBuild(new PlayerBuild());
		game.sdm.add(spr, Game.DP_PLAYER);

		color = 0xD55BFD;
		frictX = frictY = 0.85;
		radius = 20;
		scrollBounce = true;
		followScroll = true;
		collides = true;
		setPos(5, 5);
		pullPower = 0.5;
		speed = 0.02;
		scrollDeath = 0;
		normalRadius = radius;

		lifeCont.filters = [
			new DropShadowFilter(3, -120, 0x0, 0.5, 8, 8, 1, 1, true),
			new GlowFilter(0xffffff, 0.2, 2, 2, 5, 1, true),
		];

		initLife(2);

		var wspr = new Sprite();
		var m = new Matrix();
		m.createGradientBox(Game.WID, Game.HEI);
		wspr.graphics.beginGradientFill(GradientType.RADIAL, [0xC10000, 0xC10000], [0, 0.7], [128, 255], m);
		wspr.graphics.drawRect(0, 0, Game.WID, Game.HEI);
		wspr.width += 200;
		wspr.height += 200;
		wspr.x -= 100;
		wspr.y -= 100;
		var tf = game.createField(Lang.get("Danger"), true);
		wspr.addChild(tf);
		tf.scaleX = tf.scaleY = 2;
		tf.textColor = 0xC10000;
		tf.alpha = 0.7;
		tf.x = Std.int(Game.WID * 0.5 - tf.textWidth * tf.scaleX * 0.5);
		tf.y = Std.int(Game.HEI * 0.5 - tf.textHeight * tf.scaleY * 0.5);
		warning = Lib.flatten(wspr);
		game.dm.add(warning, Game.DP_FX);
		warning.blendMode = BlendMode.ADD;
		warning.alpha = 0;
		warning.visible = false;

		mc = new MovieClip("Charlotte");
		mc.scaleX = mc.scaleY = 0.75;
		mc.x = 6 * mc.scaleX;
		mc.y = -4 * mc.scaleY;
		mc.stop();
		spr.addChild(mc);

		// (the money counter of the LvUP: not ported)

		setPlayerAnim();
		applyBuild(new PlayerBuild());

		// (Ellon, at the level 20 of the LvUP: not ported)

		// AKApi.setStatusMC(hud): the lives at the top right of the game, where the Arkadeo loader showed them
		hud.x = Game.WID - 10 - 18 * 2 - 12;
		game.dm.add(hud, Game.DP_INTERF);

		rainbowMC = new Bitmap("Rainbow");
	}

	public function applyBuild(?b:PlayerBuild) {
		if (b != null)
			build = b;

		build.check();

		var v:Int = build.speed;
		switch (v) {
			case 0:
				speed = 0.026;
				frictX = frictY = 0.82;
			case 1:
				speed = 0.031;
				frictX = frictY = 0.83;
			case 2:
				speed = 0.037;
				frictX = frictY = 0.82;
			case 3:
				speed = 0.048;
				frictX = frictY = 0.80;
			case 4:
				speed = 0.058;
				frictX = frictY = 0.73;
			case 5:
				speed = 0.075;
				frictX = frictY = 0.70;
		}

		charlottesquest.bullet.Heart.clearCache();
	}

	public function shoot() {
		var gap = 2.0;
		var pt = getPoint();
		if (!hasCD("shootFront")) {
			setCD("shootFront", 14);
			var v = build.front;
			var range = 300; // + v*7;
			var n = (v >= 8 ? 2 : 1);
			for (i in 0...n) {
				var b = new charlottesquest.bullet.Heart(0, range, v);
				b.yr += gap * i / n - gap * (n - 1) * 0.25;
			}
		}

		if (!hasCD("shootBack")) {
			setCD("shootBack", 14);
			var v = build.back;
			var range = 250 + v * 6;
			var n = (v >= 4 ? 2 : 1);
			for (i in 0...n) {
				var b = new charlottesquest.bullet.Heart(3.14, range, v);
				b.yr += gap * i / n - gap * (n - 1) * 0.5;
			}
		}

		if (!hasCD("shootUp") && build.up > 0) {
			setCD("shootUp", 14);
			var v = build.up;
			var range = 150 + v * 6;
			var n = (v >= 6 ? 2 : 1);
			for (i in 0...n) {
				var b = new charlottesquest.bullet.Heart(-1.57, range, v);
				b.xr += gap * i / n - gap * (n - 1) * 0.5;
			}
		}

		if (!hasCD("shootDown") && build.down > 0) {
			setCD("shootDown", 14);
			var v = build.down;
			var range = 200 + v * 6;
			var n = (v >= 6 ? 2 : 1);
			for (i in 0...n) {
				var b = new charlottesquest.bullet.Heart(1.57, range, v);
				b.xr += gap * i / n - gap * (n - 1) * 0.5;
			}
		}
	}

	override public function toString() {
		return "Player#" + uid;
	}

	override function set_life(v:Float) {
		super.set_life(v);

		// (the original made lifeIcons / lifeCont before calling the constructor of Entity, which sets the life)
		if (lifeIcons == null) {
			lifeIcons = new Array();
			lifeCont = new Sprite();
		}
		if (lifeIcons.length != maxLife) {
			for (icon in lifeIcons) {
				icon.parent.removeChild(icon);
				icon.dispose();
			}
			lifeIcons = new Array();
			for (i in 0...Std.int(Math.min(5, maxLife))) {
				var icon = new MovieClip("Life");
				lifeCont.addChild(icon);
				lifeIcons.push(icon);
				icon.x = 10 + i * 18;
				icon.y = 11;
				icon.scaleX = icon.scaleY = 0.75;
			}
		}

		for (i in 0...lifeIcons.length) {
			if (i + 1 > life) {
				lifeIcons[i].filters = [Color.getSaturationFilter(-1)];
				lifeIcons[i].alpha = 0.5;
			} else {
				lifeIcons[i].filters = [];
				lifeIcons[i].alpha = 1;
			}
		}
		return life;
	}

	override public function onDie() {
		super.onDie();
		fx.playerDeath();
		game.gameOver(false);
	}

	public function setPlayerAnim(?k = "wait") {
		if (hasCD("uber"))
			return;
		mc.stop();
		playerAnim = k;
		if (k != "wait" && mc.currentFrameLabel == "wait")
			mc.gotoAndStop(k);
	}

	override public function hit(p:Float, ?from:Entity) {
		if (game.ended || hasCD("shield"))
			return;

		super.hit(p, from);

		if (from != null)
			fx.explodeLight(this, from.color);
		shield();
	}

	public function uber() {
		setPlayerAnim("big");
		setCD("uber", 30 * 20);
		clearCD("shield");
		radius = 65;
	}

	public function endUber() {
		setPlayerAnim();
		radius = normalRadius;
		shield();
	}

	public inline function shield() {
		setCD("shield", 30 * 3);
	}

	public inline function rainbowTail() {
		if (game.perf >= 0.7) {
			var s = build.speed;
			if (hasCD("uber"))
				s = 8;
			var pt = getScreenPoint();
			pt.x = Std.int(pt.x / Game.RAINBOW_SCALE);
			pt.y = Std.int(pt.y / Game.RAINBOW_SCALE);
			if (s >= 3) {
				var m = new Matrix();
				if (hasCD("uber"))
					m.scale(1.5 / Game.RAINBOW_SCALE, 1.3 / Game.RAINBOW_SCALE);
				else
					m.scale(1 / Game.RAINBOW_SCALE, 0.7 * 1 / Game.RAINBOW_SCALE);
				m.rotate(Math.atan2(dy, dx));
				m.translate(pt.x, pt.y);
				var ct = new ColorTransform();
				ct.alphaMultiplier = s / 5;
				game.rainbow.bitmapData.draw(rainbowMC, m, ct);
			} else if (s >= 1) {
				game.rainbow.bitmapData.fillRect(new Rectangle(pt.x, pt.y, 2, 2), s == 1 ? 0xffFF80FF : 0xffFFAE40);
			}
		}
	}

	override function onCD(k) {
		super.onCD(k);
		if (k == "shield")
			spr.alpha = 1;
		if (k == "uber")
			endUber();
	}

	#if debug
	// (test mode) not killed by the scrolling
	public function testKeepOnScreen() {
		scrollDeath = 0;
	}
	#end

	override public function update() {
		super.update();
		if (!onScreen) {
			warning.visible = true;
			warning.alpha -= 0.03;
			if (warning.alpha < 0.7)
				warning.alpha = 1;
			if (scrollDeath++ >= 50)
				kill();
		} else {
			if (warning.visible) {
				warning.alpha -= 0.04;
				if (warning.alpha <= 0)
					warning.visible = false;
			}
			scrollDeath = 0;
		}

		// Animation
		var smc = mc.getClip("_smc");
		if (mc.currentFrameLabel != playerAnim) {
			for (i in 0...(playerAnim != "wait" ? 4 : 2))
				smc.prevFrame();
			if (smc.currentFrame == 1) {
				mc.gotoAndStop(playerAnim);
				mc.getClip("_smc").stop();
			}
		} else
			// (Arkadeo HTML5 port) an animation that reached its last frame starts again: the original stayed on it (nextFrame
			// stops on the last frame; the loops of the wait, up and down animations are their frame scripts), Charlotte stayed
			// leaning while left or right was held
			if (smc.currentFrame >= smc.totalFrames)
				smc.gotoAndStop(1);
			else
				smc.nextFrame();

		// Bouclier
		var shield = hasCD("shield");
		if (shield)
			spr.alpha = game.time % 3 == 0 ? 1 : 0.4;
		if (shield && game.time % 2 == 0)
			spr.blendMode = BlendMode.ADD;
		else
			spr.blendMode = BlendMode.NORMAL;

		// (the shop: LvUP)

		// Mode uber
		if (hasCD("uber")) {
			spr.scaleX = 1 + Math.cos(uid + game.time * 0.1 * 3.14) * 0.03;
			spr.scaleY = 1 + Math.sin(uid + game.time * 0.07 * 3.14) * 0.02;
			var smc = mc.getClip("_smc");
			if (smc.currentFrame == smc.totalFrames) {
				var charlotte = smc.get("_smc");
				if (charlotte != null) {
					charlotte._rotation += dy * 40;
					charlotte._rotation *= 0.8;
				}
			}
			fx.uber();
		}

		mc.rotation *= 0.9;

		if (game.perf >= 0.7 && (dx != 0 || dy != 0))
			rainbowTail();
	}
}
