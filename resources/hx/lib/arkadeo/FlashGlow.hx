package arkadeo;

import pixi.core.renderers.systems.FilterSystem;
import pixi.core.renderers.webgl.filters.Filter;
import pixi.core.textures.RenderTexture;

/**
 * Flash GlowFilter / DropShadowFilter (quality 1) at run time: the alpha of the object blurred by a box of blurX x blurY
 * stage pixels (moved by the offset of a drop shadow), multiplied by the strength, in the glow colour: drawn under the
 * object (outer), or over it inside its shape where the blurred alpha is low (inner) (schizofuzz/FlashGlow.hx). An
 * Arkadeo game is drawn at 1 canvas pixel per Flash pixel: the box is blurX x the resolution of the page, x the upscale
 * of a Buffer around the object (Flash filtered its scene in the BitmapData of the buffer, then scaled it up). The
 * GlowFilter of the games (GlowFilter.style FLASH), their DropShadowFilter, and Mel's platforms.
 */
class FlashGlow extends Filter {
	static inline var MAXN = 16;

	// the biggest upscale of a Buffer of the game (Flash.reset: 1): the padding of the filters drawn in it
	public static var maxStageScale:Float = 1;

	var blurX:Float;
	var blurY:Float;
	var dx:Float;
	var dy:Float;

	public function new(blurX:Float, blurY:Float, strength:Float, color:Int, alpha:Float = 1, inner:Bool = false, dx:Float = 0,
			dy:Float = 0) {
		super(null, FRAG, {
			uBox: [0.0, 0.0],
			uTexel: [0.0, 0.0],
			uN: [1.0, 1.0],
			uOffset: [0.0, 0.0],
			uInner: inner ? 1.0 : 0.0,
			uStrength: strength,
			uColor: [((color >> 16) & 0xFF) / 255, ((color >> 8) & 0xFF) / 255, (color & 0xFF) / 255, alpha],
		});
		this.blurX = blurX;
		this.blurY = blurY;
		this.dx = dx;
		this.dy = dy;
		padding = (Math.ceil(Math.max(blurX, blurY) / 2) + Math.ceil(Math.max(Math.abs(dx), Math.abs(dy))) + 2) * maxStageScale;
	}

	// the upscale of the Buffers around a node (mt.deepnight.Buffer marks its scaled container)
	static function stageScale(node:Dynamic):Float {
		var s = 1.0;
		while (node != null) {
			if (node.flashStageScale != null)
				s *= node.flashStageScale;
			node = node.parent;
		}
		return s;
	}

	override public function apply(filterManager:FilterSystem, input:RenderTexture, output:RenderTexture, ?clear:Bool,
			?currentState:Dynamic):Void {
		var k = input.baseTexture.resolution * (currentState != null ? stageScale(currentState.target) : 1);
		var bx = blurX * k;
		var by = blurY * k;
		uniforms.uBox = [bx, by];
		// (not inputSize: highp in PIXI's vertex shader, a uniform shared with this mediump shader would not link)
		uniforms.uTexel = [1 / input.baseTexture.realWidth, 1 / input.baseTexture.realHeight];
		uniforms.uN = [Math.min(MAXN, Math.max(1, Math.ceil(bx))), Math.min(MAXN, Math.max(1, Math.ceil(by)))];
		uniforms.uOffset = [dx * k, dy * k];
		filterManager.applyFilter(this, input, output, clear);
	}

	static var FRAG = "varying vec2 vTextureCoord;
uniform sampler2D uSampler;
uniform vec2 uTexel;
uniform vec4 inputClamp;
uniform vec2 uBox;
uniform vec2 uN;
uniform vec2 uOffset;
uniform float uInner;
uniform float uStrength;
uniform vec4 uColor;

void main(void) {
	vec4 src = texture2D(uSampler, vTextureCoord);
	vec2 at = vTextureCoord - uOffset * uTexel;
	float sum = 0.0;
	for (int j = 0; j < 16; j++) {
		if (float(j) >= uN.y) break;
		float oy = (float(j) + 0.5) * uBox.y / uN.y - uBox.y * 0.5;
		for (int i = 0; i < 16; i++) {
			if (float(i) >= uN.x) break;
			float ox = (float(i) + 0.5) * uBox.x / uN.x - uBox.x * 0.5;
			vec2 uv = clamp(at + vec2(ox, oy) * uTexel, inputClamp.xy, inputClamp.zw);
			sum += texture2D(uSampler, uv).a;
		}
	}
	float blurred = sum / (uN.x * uN.y);
	if (uInner > 0.5) {
		// inside the shape, where the (moved) blurred alpha is low: the colour over the object
		float g = clamp((1.0 - blurred) * uStrength, 0.0, 1.0) * uColor.a;
		gl_FragColor = vec4(src.rgb * (1.0 - g) + uColor.rgb * g * src.a, src.a);
	} else {
		float g = clamp(blurred * uStrength, 0.0, 1.0) * uColor.a;
		gl_FragColor = src + vec4(uColor.rgb * g, g) * (1.0 - src.a);
	}
}
";
}
