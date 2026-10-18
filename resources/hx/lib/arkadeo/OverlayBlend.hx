package arkadeo;

import pixi.core.renderers.webgl.filters.Filter;

/**
 * Flash's blend mode OVERLAY for the afterimages of Mel (fx.Shade2): over a darker than 50 % grey picture, overlay is
 * 2 x the picture under it x the colour of the afterimage, mixed by its alpha a: under = under x (1 + a (2 c - 1))
 * (the city of Mel is dark). PIXI cannot read what is under a sprite: the afterimage is drawn by this filter as its
 * colour over 50 % grey (premultiplied: c a + 0.5 (1 - a)), multiplied twice into what is under it by the blend mode
 * DST_COLOR x SRC_COLOR (2 x src x dst): exactly the formula above, and nothing changes around the picture (0.5).
 * Over a lighter picture (the sun) overlay would be a screen: this brightens a little more.
 */
class OverlayBlend extends Filter {
	public static inline var MODE = 31;

	static var done:Dynamic = null;

	// the blend mode of the renderer (once per renderer)
	public static function register(renderer:Dynamic) {
		if (done == renderer)
			return;
		done = renderer;
		var gl:Dynamic = renderer.gl;
		var modes:Array<Dynamic> = renderer.state.blendModes;
		modes[MODE] = [gl.DST_COLOR, gl.SRC_COLOR, gl.ZERO, gl.ONE];
	}

	public function new() {
		super(null, FRAG);
		untyped this.blendMode = MODE;
	}

	static var FRAG = "varying vec2 vTextureCoord;
uniform sampler2D uSampler;

void main(void) {
	vec4 c = texture2D(uSampler, vTextureCoord);
	gl_FragColor = vec4(c.rgb + 0.5 * (1.0 - c.a), 1.0);
}
";
}
