package labrute.view;

import js.Browser;
import labrute.Brute;
import labrute.Data;
import labrute.view.V8;

// The fighters of the game, drawn by labrute-pixi-fighter with PixiJS 8 into a canvas of their own, shown in the
// PixiJS 6 stage of KadoKadeo as one sprite over the background of the screen. Only a picture: nothing of the game
// reads it (the replay verifier, headless, never creates it). One PixiJS 8 application for the page, kept between the
// games and the replays (a WebGL context each time would be lost after a few).
class Actors {
	public static inline var W = 600;
	public static inline var H = 460;

	static var app:V8Application;
	// 0: not started, 1: starting, 2: ready, 3: unavailable (the placeholders stay)
	static var state = 0;
	static var waiting:Array<Actors> = [];
	static var resolution:Float = 1;
	// the ticker of the application only moves forward: the times of every game follow each other
	static var lastTime:Float = 0;
	static var current:Actors;

	public var ready(default, null):Bool = false;

	// no PixiJS 8 renderer: simple shapes in place of the fighters
	public static inline function failed():Bool {
		return state == 3;
	}

	// the fighters of this game (PixiJS 8, screen coordinates)
	public var root:V8Container;

	var parent:pixi.core.display.Container;
	var sprite:pixi.core.sprites.Sprite;
	var texture:Dynamic;
	var destroyed = false;
	var timeBase:Float = 0;
	var holders:Array<V8FighterHolder> = [];

	public function new(parent:pixi.core.display.Container) {
		this.parent = parent;
		if (KadoKadeoManager.kkm != null && KadoKadeoManager.kkm.headless)
			return;
		start();
	}

	function start():Void {
		switch (state) {
			case 2:
				onReady();
			case 3:
			case 1:
				waiting.push(this);
			default:
				state = 1;
				waiting.push(this);
				resolution = Math.min(2, Math.max(1, Browser.window.devicePixelRatio));
				try {
					var a = new V8Application();
					a.init({
						width: W,
						height: H,
						backgroundAlpha: 0,
						antialias: true,
						resolution: resolution,
						autoDensity: false,
						autoStart: false,
						sharedTicker: false,
						preference: "webgl",
						preserveDrawingBuffer: true,
					}).then((_) -> {
						app = a;
						warmUp();
						state = 2;
						var list = waiting;
						waiting = [];
						for (w in list)
							w.onReady();
					}, (e) -> fail(e));
				} catch (e:Dynamic) {
					fail(e);
				}
		}
	}

	// the shaders of the filters of the fighters (their colors, their blurred shadow) compiled at once, while the shop is
	// shown: not in the first frames of the first fight
	static function warmUp():Void {
		try {
			var c = new V8Container();
			var g = new V8Graphics();
			g.rect(0, 0, 8, 8).fill(0xFFFFFF);
			c.addChild(g);
			c.filters = [new V8ColorMatrixFilter(), new V8BlurFilter({strength: 2})];
			var t:Dynamic = app.renderer.generateTexture({target: c});
			t.destroy(true);
			c.destroy({children: true});
		} catch (e:Dynamic) {}
	}

	static function fail(e:Dynamic):Void {
		state = 3;
		waiting = [];
		trace("LaBrute: no PixiJS 8 renderer, simple fighters (" + e + ")");
	}

	function onReady():Void {
		if (destroyed)
			return;
		root = new V8Container();
		root.sortableChildren = true;
		app.stage.addChild(root);
		texture = js.Syntax.code("new PIXI.Texture(new PIXI.BaseTexture({0}, {resolution: {1}}))", app.canvas, resolution);
		sprite = new pixi.core.sprites.Sprite(texture);
		parent.addChild(sprite);
		timeBase = lastTime + 100;
		ready = true;
	}

	// a fighter (null until PixiJS 8 is ready), drawn at RASTER_SCALE then its container scaled to `scale`: the pictures
	// of its parts (labrute-pixi-fighter draws them by scale, ~400 ms by look) are the same for the shop, the cards of
	// the choice, the fight and the heads of the HUD (a bigger one: at its own scale)
	static inline var RASTER_SCALE = 1.3;

	public function holder(appearance:Dynamic, speed:Dynamic, scale:Float = 1):V8FighterHolder {
		if (!ready)
			return null;
		var raster = scale > RASTER_SCALE ? scale : RASTER_SCALE;
		var h = new V8FighterHolder(app, appearance, speed, raster);
		// (its sign kept: the side it faces, set by labrute-pixi-fighter, -1 for the right team, the dogs the other way)
		if (raster != scale)
			h.container.scale.set(h.container.scale.x * scale / raster, h.container.scale.y * scale / raster);
		holders.push(h);
		return h;
	}

	public function release(h:V8FighterHolder):Void {
		if (h == null)
			return;
		holders.remove(h);
		try {
			if (h.container.parent != null)
				h.container.parent.removeChild(h.container);
			h.destroy();
		} catch (e:Dynamic) {}
	}

	// a black outline of `width` pixels around what a container draws now (a still fighter: the heads of the HUD): 8
	// black copies of a picture of it, behind it in its parent (null before the start of PixiJS 8)
	public function outline(c:V8Container, width:Float):Void {
		if (c.parent == null)
			return;
		var shot = snapshot(c);
		if (shot == null)
			return;
		var parent:V8Container = c.parent;
		var at = parent.children.indexOf(c);
		for (d in [[-1.0, 0.0], [1.0, 0.0], [0.0, -1.0], [0.0, 1.0], [-0.7, -0.7], [0.7, 0.7], [-0.7, 0.7], [0.7, -0.7]]) {
			var s = new V8Sprite(shot.tex);
			s.scale.set(shot.sx, shot.sy);
			s.x = shot.x + d[0] * width;
			s.y = shot.y + d[1] * width;
			s.tint = 0x000000;
			parent.addChildAt(s, at);
		}
	}

	// a soft black ellipse (the shadows of the brutes: labrute-pixi-fighter's ellipse 60 × 20 at 40 %, blurred), made once
	static var shadowTex:Dynamic = null;

	public function softShadow():Dynamic {
		if (shadowTex == null) {
			var c = Browser.document.createCanvasElement();
			c.width = 120;
			c.height = 40;
			var g = c.getContext2d();
			g.setTransform(1, 0, 0, 1 / 3, 0, 0);
			var r = g.createRadialGradient(60, 60, 0, 60, 60, 60);
			r.addColorStop(0, "rgba(0,0,0,0.45)");
			r.addColorStop(0.6, "rgba(0,0,0,0.35)");
			r.addColorStop(1, "rgba(0,0,0,0)");
			g.fillStyle = r;
			g.fillRect(0, 0, 120, 120);
			shadowTex = V8Texture.from(c);
			shadowTex.source.resolution = 2;
		}
		return shadowTex;
	}

	// a picture of what a container draws now, and where to put it in its parent (null before the start of PixiJS 8)
	public function snapshot(c:V8Container):{tex:Dynamic, x:Float, y:Float, sx:Float, sy:Float} {
		if (!ready)
			return null;
		var b = c.getLocalBounds();
		if (b.maxX - b.minX < 1 || b.maxY - b.minY < 1)
			return null;
		var tex:Dynamic = app.renderer.generateTexture({target: c, resolution: resolution * Math.abs(c.scale.x), antialias: true});
		return {
			tex: tex,
			x: c.x + b.minX * c.scale.x,
			y: c.y + b.minY * c.scale.y,
			sx: c.scale.x,
			sy: c.scale.y
		};
	}

	// a sprite of a picture of snapshot in a container, moved by dx, dy; owns: its picture destroyed with it (dropSprite)
	public function ghost(parent:V8Container, shot:{tex:Dynamic, x:Float, y:Float, sx:Float, sy:Float}, dx:Float, dy:Float, owns:Bool):V8Sprite {
		var s = new V8Sprite(shot.tex);
		s.scale.set(shot.sx, shot.sy);
		s.x = shot.x + dx;
		s.y = shot.y + dy;
		if (owns)
			untyped s.kadoOwns = true;
		parent.addChild(s);
		return s;
	}

	public function dropSprite(s:V8Sprite):Void {
		if (s == null)
			return;
		try {
			var tex:Dynamic = untyped s.texture;
			var owns = untyped s.kadoOwns == true;
			s.destroy();
			if (owns && tex != null)
				tex.destroy(true);
		} catch (e:Dynamic) {}
	}

	// a new container of fighters in the root (the arena of a fight, the cards of the opponents...)
	public function layer():V8Container {
		if (!ready)
			return null;
		var c = new V8Container();
		c.sortableChildren = true;
		root.addChild(c);
		return c;
	}

	// draws the fighters at this time of the game (ms): their animations follow the game, its replay speed, its pauses
	public function render(timeMs:Float):Void {
		if (!ready || destroyed)
			return;
		if (current != this) {
			current = this;
			for (c in app.stage.children)
				c.visible = c == root;
		}
		var t = timeBase + timeMs;
		if (t > lastTime) {
			app.ticker.update(t);
			lastTime = t;
		}
		app.render();
		texture.baseTexture.update();
	}

	public function destroy():Void {
		destroyed = true;
		waiting.remove(this);
		for (h in holders.copy())
			release(h);
		if (root != null) {
			try {
				root.destroy({children: true});
			} catch (e:Dynamic) {}
			root = null;
		}
		if (sprite != null) {
			if (sprite.parent != null)
				sprite.parent.removeChild(sprite);
			untyped sprite.destroy();
			sprite = null;
		}
		if (texture != null) {
			untyped texture.destroy(true);
			texture = null;
		}
		if (current == this)
			current = null;
		ready = false;
	}

	// ---------------------------------------------------------------- the looks (client/src/utils/fight/FighterHolder.ts)

	// plain: the brute as it is, standing (not the pose of « Moine »)
	public static function bruteLook(b:Brute, team:Int, shield:Bool, ?plain:Bool = false):Dynamic {
		return {
			type: "brute",
			name: b.name,
			model: b.gender,
			team: team == 0 ? "L" : "R",
			shield: shield,
			parts: b.parts,
			colors: b.colors,
			width: Data.BRUTE_WIDTH,
			height: Data.BRUTE_HEIGHT,
			idleAnimation: !plain && b.hasSkill("monk") ? "monk" : "idle",
		};
	}

	static var ZERO_PARTS = {p1: 0, p1a: 0, p1b: 0, p2: 0, p3: 0, p4: 0, p5: 0, p6: 0, p7: 0, p7b: 0, p8: 0};
	static var BLACK = {
		col0: "#000000",
		col0a: "#000000",
		col0c: "#000000",
		col1: "#000000",
		col1a: "#000000",
		col1b: "#000000",
		col1c: "#000000",
		col1d: "#000000",
		col2: "#000000",
		col2a: "#000000",
		col2b: "#000000",
		col3: "#000000",
		col3b: "#000000",
		col4: "#000000",
		col4a: "#000000",
		col4b: "#000000",
	};

	// pixi-filters AdjustmentFilter of LaBrute for the colors of the dogs, as a color matrix of PixiJS 8
	static function tint(r:Float, g:Float, b:Float):Dynamic {
		var f = new V8ColorMatrixFilter();
		f.matrix = [r, 0, 0, 0, 0, 0, g, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, 1, 0];
		return f;
	}

	public static function petLook(pet:String, team:Int):Dynamic {
		var d = Data.pet(pet);
		var filters:Array<Dynamic> = [];
		if (pet == "dog2")
			filters.push(tint(1.3 * 1.1, 1.1, 1.1));
		else if (pet == "dog3")
			filters.push(tint(0.7 * 2.5, 2.5, 2.5));
		return {
			type: "pet",
			name: pet,
			model: d.model,
			team: team == 0 ? "L" : "R",
			shield: false,
			parts: ZERO_PARTS,
			colors: BLACK,
			width: d.model == "bear" ? 100 : 58,
			height: d.model == "bear" ? 100 : 40,
			filters: filters,
			colorOffset: pet == "panther" ? {r: -82, g: -97, b: -82} : null,
		};
	}

	// the scale of the model of a pet (the panther is a big dog)
	public static function petScale(pet:String):Float {
		return pet == "panther" ? 1.5 : 1;
	}
}
