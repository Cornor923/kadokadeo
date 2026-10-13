package logico;

import pixi.core.Pixi.BlendModes;
import pixi.core.Pixi.ScaleModes;
import pixi.core.display.Container;
import pixi.core.display.DisplayObject;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.RenderTexture;

private enum PlasmaOp {
	// Bmp.drawMc(ball): the ball of colour col (its picture at half size) at (x, y) pixels of the bitmap
	Draw(col:Int, x:Float, y:Float, sc:Float);
	// Plasma.update: the ColorTransform then the BlurFilter
	Pass;
	// end of a Flash frame (the pictures shown, see show)
	FrameEnd;
}

/**
 * The plasma of the original (mt.bumdum.Plasma, Game.initPlasma): a 150 x 150 transparent bitmap (q = 0.5: drawn at
 * 200 %, over the whole stage, at depth 20: over everything, blendMode "add") where the code draws the balls that
 * move fast (Ball.update) and the balls of a combo (Game.updateCombo); every Flash frame Plasma.update applies its
 * ColorTransform (alpha - 15) then its BlurFilter (4 x 4, quality 1): a glowing trail that fades in 17 frames. The
 * bitmap is attached without smoothing: its pixels are drawn as squares of 2 x 2 Flash pixels.
 *
 * On the GPU (the Plasma of Klinker Surprise): two textures, the drawings batched, then one shader pass does colour
 * transform + blur into the other. A picture only: nothing of the game reads it. The operations are queued and run
 * just before the screen is drawn (flush, from the ticker of the page): a replay seek or the catch up of a hidden tab,
 * which simulate many frames without drawing them, run only the last 17 frames, and what is older has faded out
 * completely by then (the alpha loses 15 per frame, the blur cannot raise it): the picture is the same.
 * The clips are shown one Flash frame late (MC): the bitmap is kept as it was at the end of the last two Flash frames
 * and the one nearest to the frame the clips show is drawn.
 */
class Plasma {
	static inline var LIFE = 17;
	public static inline var Q = 0.5;
	static var program:Dynamic;

	public var root:MC;

	var w:Int;
	var h:Int;
	var tex:Array<RenderTexture>;
	var cur = 0;
	var snaps:Array<RenderTexture>;
	var snapCur = 0;
	var views:Array<PixiSprite>;
	var copy:PixiSprite;
	var pass:Dynamic;
	var uniforms:Dynamic;
	var batch = new Container();
	var empty = new Container();
	var sprites:Array<PixiSprite> = [];
	var used = 0;
	var queue:Array<PlasmaOp> = [];
	var frames = 0;
	var dropped = false;
	var blank = true;
	var idle = 0;
	// which of the two pictures is shown (see show)
	var showPrev = false;

	public function new(mc:MC, w:Int, h:Int) {
		root = mc;
		this.w = Std.int(w * Q);
		this.h = Std.int(h * Q);
		tex = [newTexture(), newTexture()];
		snaps = [newTexture(), newTexture()];
		views = [];
		for (t in snaps) {
			var v = new PixiSprite(t);
			// Bmp: root._xscale = root._yscale = 100 / q
			v.scale.set(1 / Q, 1 / Q);
			v.blendMode = BlendModes.ADD;
			root.spr.addChild(v);
			views.push(v);
		}
		copy = new PixiSprite(tex[0]);

		var P:Dynamic = untyped PIXI;
		var geometry:Dynamic = js.Syntax.construct(P.Geometry);
		geometry.addAttribute("aVertexPosition", [0, 0, this.w, 0, this.w, this.h, 0, this.h], 2);
		geometry.addAttribute("aTextureCoord", [0, 0, 1, 0, 1, 1, 0, 1], 2);
		geometry.addIndex([0, 1, 2, 0, 2, 3]);
		var base:Dynamic = tex[0].baseTexture;
		uniforms = {
			uSrc: tex[0],
			uTexel: new js.lib.Float32Array([1 / base.realWidth, 1 / base.realHeight]),
		};
		if (program == null)
			program = P.Program.from(VERT, FRAG, "kkLogicoPlasma");
		pass = js.Syntax.construct(P.Mesh, geometry, js.Syntax.construct(P.Shader, program, uniforms));
		// compiles the shader now (at the start of the game) rather than at the first ball drawn
		render(pass, tex[1], true);
		clearAll();
		showViews();
	}

	function newTexture():RenderTexture {
		var t:RenderTexture = (cast RenderTexture : Dynamic).create({width: w, height: h, scaleMode: ScaleModes.NEAREST});
		return t;
	}

	// Bmp.drawMc(mc): draw(mc, scale(_xscale / 100 * q) translate(_x * q, _y * q)) (the balls are not rotated and are
	// opaque: no colour transform)
	public function drawMc(mc:MC, col:Int):Void {
		queue.push(Draw(col, mc._x * Q, mc._y * Q, mc._xscale / 100));
	}

	// Plasma.update: colorTransform then the BlurFilter
	public function update():Void {
		queue.push(Pass);
	}

	// the end of a Flash frame (Game.flashFrame)
	public function frameEnd():Void {
		queue.push(FrameEnd);
		frames++;
		if (frames > LIFE) {
			// what the oldest frame drew has faded out before the screen shows the last one
			var i = queue.indexOf(FrameEnd);
			queue.splice(0, i + 1);
			frames--;
			dropped = true;
		}
	}

	// the clips show the Flash frame before the last one, moved towards the last one by f (MC.displayAll)
	public function show(f:Float):Void {
		showPrev = f < 0.5;
	}

	// the operations queued, on the GPU (before the screen is drawn)
	public function flush():Void {
		if (queue.length > 0) {
			if (dropped) {
				clearAll();
				dropped = false;
			}
			var left = frames;
			var draws:Array<PlasmaOp> = [];
			for (op in queue) {
				switch (op) {
					case Draw(_, _, _, _):
						draws.push(op);
					case Pass:
						drawBalls(draws);
						draws = [];
						if (blank)
							continue;
						uniforms.uSrc = tex[cur];
						cur = 1 - cur;
						render(pass, tex[cur], true);
						if (++idle >= LIFE) {
							// faded out completely: nothing to do until the next drawing
							clearAll();
						}
					case FrameEnd:
						drawBalls(draws);
						draws = [];
						left--;
						// (only the last two frames are shown)
						if (left < 2)
							snapshot();
				}
			}
			drawBalls(draws);
			queue = [];
			frames = 0;
		}
		showViews();
	}

	// (blank: the four textures were cleared by clearAll, the copy would draw nothing)
	function snapshot():Void {
		if (blank)
			return;
		snapCur = 1 - snapCur;
		copy.texture = tex[cur];
		render(copy, snaps[snapCur], true);
	}

	// (blank: nothing to add over the screen, the full screen pictures are not drawn)
	function showViews():Void {
		views[snapCur].visible = !blank && !showPrev;
		views[1 - snapCur].visible = !blank && showPrev;
	}

	function drawBalls(draws:Array<PlasmaOp>):Void {
		if (draws.length == 0)
			return;
		var pics = Tex.get("ballP");
		for (op in draws) {
			switch (op) {
				case Draw(col, x, y, sc):
					var t = pics[col];
					var s = sprite();
					s.texture = t;
					s.anchor.copyFrom(t.defaultAnchor);
					s.position.set(x, y);
					s.scale.set(sc, sc);
				default:
			}
		}
		render(batch, tex[cur], false);
		batch.removeChildren();
		used = 0;
		blank = false;
		idle = 0;
	}

	function sprite():PixiSprite {
		if (used == sprites.length)
			sprites.push(new PixiSprite());
		var s = sprites[used++];
		batch.addChild(s);
		return s;
	}

	function clearAll():Void {
		render(empty, tex[0], true);
		render(empty, tex[1], true);
		render(empty, snaps[0], true);
		render(empty, snaps[1], true);
		blank = true;
		idle = 0;
	}

	public function destroy():Void {
		batch.removeChildren();
		for (s in sprites)
			s.destroy();
		sprites = [];
		pass.destroy();
		copy.destroy();
		empty.destroy();
		for (v in views)
			v.destroy();
		for (t in tex.concat(snaps))
			t.destroy(true);
		queue = [];
	}

	inline function render(o:DisplayObject, target:RenderTexture, clear:Bool) {
		KadoKadeoManager.kkm.renderer.render(o, cast {renderTexture: target, clear: clear});
	}

	static var VERT = "precision highp float;
attribute vec2 aVertexPosition;
attribute vec2 aTextureCoord;
uniform mat3 projectionMatrix;
uniform mat3 translationMatrix;
varying vec2 vUv;
void main(void) {
	vUv = aTextureCoord;
	gl_Position = vec4((projectionMatrix * translationMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);
}";

	// one Flash frame of the bitmap: colorTransform (on the colours without premultiplied alpha: alpha - 15), then
	// BlurFilter 4 x 4 quality 1 (a box of 4 pixels centred: weights 1/8 1/4 1/4 1/4 1/8 on each axis, outside is
	// transparent)
	static var FRAG = "#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
varying vec2 vUv;
uniform sampler2D uSrc;
uniform vec2 uTexel;
vec4 tap(vec2 p) {
	vec2 inside = step(vec2(0.0), p) * step(p, vec2(1.0));
	if (inside.x * inside.y < 0.5) return vec4(0.0);
	vec4 s = texture2D(uSrc, p);
	vec3 c = s.a > 0.0 ? s.rgb / s.a : vec3(0.0);
	float a = clamp(s.a - 15.0 / 255.0, 0.0, 1.0);
	return vec4(c * a, a);
}
vec4 row(vec2 p) {
	vec2 dx = vec2(uTexel.x, 0.0);
	return (tap(p - 2.0 * dx) + tap(p + 2.0 * dx)) * 0.125 + (tap(p - dx) + tap(p) + tap(p + dx)) * 0.25;
}
void main(void) {
	vec2 dy = vec2(0.0, uTexel.y);
	gl_FragColor = (row(vUv - 2.0 * dy) + row(vUv + 2.0 * dy)) * 0.125 + (row(vUv - dy) + row(vUv) + row(vUv + dy)) * 0.25;
}";
}
