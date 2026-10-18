package arkadeo;

import pixi.core.renderers.systems.FilterSystem;
import pixi.core.renderers.webgl.filters.Filter;
import pixi.core.textures.RenderTexture;

/**
 * Flash GlowFilter (outer, quality 1) at run time: the alpha of the object blurred by a box of blurX x blurY stage
 * pixels, multiplied by the strength, in the glow colour, drawn under the object (schizofuzz/FlashGlow.hx). An Arkadeo
 * game is drawn at 1 canvas pixel per Flash pixel: the box is blurX x the resolution of the page. The GlowFilter of the
 * games (GlowFilter.style FLASH), and Mel's platforms.
 */
class FlashGlow extends Filter {
	static inline var MAXN = 16;

	var blurX:Float;
	var blurY:Float;

	public function new(blurX:Float, blurY:Float, strength:Float, color:Int, alpha:Float = 1) {
		super(null, FRAG, {
			uBox: [0.0, 0.0],
			uTexel: [0.0, 0.0],
			uN: [1.0, 1.0],
			uStrength: strength,
			uColor: [((color >> 16) & 0xFF) / 255, ((color >> 8) & 0xFF) / 255, (color & 0xFF) / 255, alpha],
		});
		this.blurX = blurX;
		this.blurY = blurY;
		padding = Math.ceil(Math.max(blurX, blurY) / 2) + 2;
	}

	override public function apply(filterManager:FilterSystem, input:RenderTexture, output:RenderTexture, ?clear:Bool,
			?currentState:Dynamic):Void {
		var k = input.baseTexture.resolution;
		var bx = blurX * k;
		var by = blurY * k;
		uniforms.uBox = [bx, by];
		// (not inputSize: highp in PIXI's vertex shader, a uniform shared with this mediump shader would not link)
		uniforms.uTexel = [1 / input.baseTexture.realWidth, 1 / input.baseTexture.realHeight];
		uniforms.uN = [Math.min(MAXN, Math.max(1, Math.ceil(bx))), Math.min(MAXN, Math.max(1, Math.ceil(by)))];
		filterManager.applyFilter(this, input, output, clear);
	}

	static var FRAG = "varying vec2 vTextureCoord;
uniform sampler2D uSampler;
uniform vec2 uTexel;
uniform vec4 inputClamp;
uniform vec2 uBox;
uniform vec2 uN;
uniform float uStrength;
uniform vec4 uColor;

void main(void) {
	vec4 src = texture2D(uSampler, vTextureCoord);
	float sum = 0.0;
	for (int j = 0; j < 16; j++) {
		if (float(j) >= uN.y) break;
		float oy = (float(j) + 0.5) * uBox.y / uN.y - uBox.y * 0.5;
		for (int i = 0; i < 16; i++) {
			if (float(i) >= uN.x) break;
			float ox = (float(i) + 0.5) * uBox.x / uN.x - uBox.x * 0.5;
			vec2 uv = clamp(vTextureCoord + vec2(ox, oy) * uTexel, inputClamp.xy, inputClamp.zw);
			sum += texture2D(uSampler, uv).a;
		}
	}
	float g = clamp(sum / (uN.x * uN.y) * uStrength, 0.0, 1.0) * uColor.a;
	gl_FragColor = src + vec4(uColor.rgb * g, g) * (1.0 - src.a);
}
";
}
