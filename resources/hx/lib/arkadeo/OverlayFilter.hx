package arkadeo;

import pixi.core.math.Matrix as PixiMatrix;
import pixi.core.renderers.systems.FilterSystem;
import pixi.core.renderers.webgl.filters.Filter;
import pixi.core.textures.RenderTexture;
import pixi.core.textures.Texture;

/**
 * Flash's blend mode OVERLAY of a picture laid over a whole object (Trigo: gfx.Render, the paper over every plane of its
 * game). PIXI cannot read what is under a sprite (OverlayBlend only approximates a dark background), so the picture is
 * drawn by a filter of the object, which reads what the object drew: per channel, with b what is under the picture (the
 * background of Flash) and s the picture, b < 0.5 ? 2 s b : 1 - 2 (1 - s) (1 - b), mixed by the alpha of the picture.
 * The picture covers the space of the object from (0, 0) to (width, height) (outside of it nothing changes).
 * difference: Flash's DIFFERENCE instead, |b - s| per channel (BitmapData.draw with BlendMode.DIFFERENCE).
 */
class OverlayFilter extends Filter {
	var width:Float;
	var height:Float;
	var map:PixiMatrix;
	var inv:PixiMatrix;

	public function new(picture:Texture, width:Float, height:Float, ?difference:Bool = false) {
		var m = new PixiMatrix();
		// (a picture of a sheet: its frame in the texture of the sheet)
		var bt = picture.baseTexture;
		var f = picture.frame;
		super(null, FRAG, {
			uPicture: picture,
			uMap: m,
			uFrame: [f.x / bt.width, f.y / bt.height, f.width / bt.width, f.height / bt.height],
			uAlpha: 1.0,
			uMode: difference ? 1.0 : 0.0
		});
		map = m;
		inv = new PixiMatrix();
		this.width = width;
		this.height = height;
	}

	// the alpha of the picture (Charlotte's Quest: the plasma faded in, alpha 0 to 0.4)
	public var alpha(get, set):Float;

	inline function get_alpha():Float
		return uniforms.uAlpha;

	inline function set_alpha(v:Float):Float
		return uniforms.uAlpha = v;

	// another picture (a BitmapData drawn again: its texture)
	public function setPicture(picture:Texture) {
		var bt = picture.baseTexture;
		var f = picture.frame;
		uniforms.uPicture = picture;
		uniforms.uFrame = [f.x / bt.width, f.y / bt.height, f.width / bt.width, f.height / bt.height];
	}

	// a pixel of the filter -> the picture (like the sprite masks of PIXI, FilterSystem.calculateSpriteMatrix): the screen
	// point of the pixel, the inverse of the world transform of the object, its size (no inputSize / outputFrame in the
	// shader: highp in PIXI's vertex shader, this mediump shader would not link)
	override public function apply(filterManager:FilterSystem, input:RenderTexture, output:RenderTexture, ?clear:Bool,
			?currentState:Dynamic):Void {
		var src = currentState.sourceFrame;
		var dst = currentState.destinationFrame;
		map.a = dst.width;
		map.b = 0;
		map.c = 0;
		map.d = dst.height;
		map.tx = src.x;
		map.ty = src.y;
		var wt:PixiMatrix = currentState.target.worldTransform;
		inv.a = wt.a;
		inv.b = wt.b;
		inv.c = wt.c;
		inv.d = wt.d;
		inv.tx = wt.tx;
		inv.ty = wt.ty;
		inv.invert();
		map.prepend(inv);
		map.scale(1 / width, 1 / height);
		uniforms.uMap = map;
		filterManager.applyFilter(this, input, output, clear);
	}

	static var FRAG = "varying vec2 vTextureCoord;
uniform sampler2D uSampler;
uniform sampler2D uPicture;
uniform mat3 uMap;
uniform vec4 uFrame;
uniform float uAlpha;
uniform float uMode;

void main(void) {
	vec4 b = texture2D(uSampler, vTextureCoord);
	vec2 uv = (uMap * vec3(vTextureCoord, 1.0)).xy;
	if (b.a <= 0.0 || uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		gl_FragColor = b;
		return;
	}
	vec4 p = texture2D(uPicture, uFrame.xy + uv * uFrame.zw);
	if (p.a <= 0.0) {
		gl_FragColor = b;
		return;
	}
	vec3 cb = b.rgb / b.a;
	vec3 cs = p.rgb / p.a;
	vec3 lo = 2.0 * cs * cb;
	vec3 hi = 1.0 - 2.0 * (1.0 - cs) * (1.0 - cb);
	vec3 o = uMode > 0.5 ? abs(cb - cs) : mix(lo, hi, step(0.5, cb));
	gl_FragColor = vec4(mix(cb, o, p.a * uAlpha) * b.a, b.a);
}
";
}
