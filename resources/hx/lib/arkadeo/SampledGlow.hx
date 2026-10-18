package arkadeo;

// A GlowFilter drawn by the glow shader of pixi-filters (GlowFilter.style SAMPLED, Brutal Teenage Crisis: the look of
// its Arkadeo HTML5 port): samples a circle around each pixel and adds a halo of `glowColor` where the neighbourhood has
// alpha (outer glow), + an optional inner tint. filterArea / filterClamp are given by the FilterSystem of PIXI.
class SampledGlow extends pixi.core.renderers.webgl.filters.Filter {
	public function new(color:Int, alpha:Float, blurX:Float, blurY:Float, strength:Float, quality:Int, inner:Bool) {
		// distance (radius) = blur, bounded for speed (the glow samples dist x angles)
		var dist = Std.int(Math.max(2, Math.min(10, Math.max(blurX, blurY))));
		var q = 0.12 + 0.04 * (quality - 1); // angular density (Flash quality 1..4)
		if (q < 0.08) q = 0.08;
		if (q > 0.3) q = 0.3;
		var angleStep = 1.0 / (q * dist);

		var frag = FRAG.join("\n");
		frag = StringTools.replace(frag, "__DIST__", dist + ".0");
		frag = StringTools.replace(frag, "__ANGLE_STEP_SIZE__", floatStr(angleStep));

		super(null, frag, {
			outerStrength: strength * alpha,
			innerStrength: inner ? strength * alpha : 0.0,
			glowColor: [((color >> 16) & 0xFF) / 255, ((color >> 8) & 0xFF) / 255, (color & 0xFF) / 255, 1.0]
		});
		this.padding = dist + 1;
	}

	static inline function floatStr(v:Float):String {
		var s = Std.string(v);
		return s.indexOf(".") < 0 ? s + ".0" : s;
	}

	static var FRAG:Array<String> = [
		"varying vec2 vTextureCoord;",
		"uniform sampler2D uSampler;",
		"uniform float outerStrength;",
		"uniform float innerStrength;",
		"uniform vec4 glowColor;",
		"uniform vec4 filterArea;",
		"uniform vec4 filterClamp;",
		"const float PI = 3.14159265358979323846264;",
		"const float DIST = __DIST__;",
		"const float ANGLE_STEP_SIZE = min(__ANGLE_STEP_SIZE__, PI * 2.0);",
		"const float ANGLE_STEP_NUM = ceil(PI * 2.0 / ANGLE_STEP_SIZE);",
		"const float MAX_TOTAL_ALPHA = ANGLE_STEP_NUM * DIST * (DIST + 1.0) / 2.0;",
		"void main(void) {",
		"    vec2 px = vec2(1.0 / filterArea.x, 1.0 / filterArea.y);",
		"    float totalAlpha = 0.0;",
		"    vec2 direction;",
		"    vec2 displaced;",
		"    vec4 curColor;",
		"    for (float angle = 0.0; angle < PI * 2.0; angle += ANGLE_STEP_SIZE) {",
		"        direction = vec2(cos(angle), sin(angle)) * px;",
		"        for (float curDistance = 0.0; curDistance < DIST; curDistance++) {",
		"            displaced = clamp(vTextureCoord + direction * (curDistance + 1.0), filterClamp.xy, filterClamp.zw);",
		"            curColor = texture2D(uSampler, displaced);",
		"            totalAlpha += (DIST - curDistance) * curColor.a;",
		"        }",
		"    }",
		"    curColor = texture2D(uSampler, vTextureCoord);",
		"    float alphaRatio = (totalAlpha / MAX_TOTAL_ALPHA);",
		"    float innerGlowAlpha = (1.0 - alphaRatio) * innerStrength * curColor.a;",
		"    float innerGlowStrength = min(1.0, innerGlowAlpha);",
		"    vec4 innerColor = mix(curColor, glowColor, innerGlowStrength);",
		"    float outerGlowAlpha = alphaRatio * outerStrength * (1.0 - curColor.a);",
		"    float outerGlowStrength = min(1.0 - innerColor.a, outerGlowAlpha);",
		"    vec4 outerGlowColor = outerGlowStrength * glowColor.rgba;",
		"    gl_FragColor = innerColor + outerGlowColor;",
		"}"
	];
}
