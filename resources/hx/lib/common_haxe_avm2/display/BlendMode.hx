package common_haxe_avm2.display;

// flash.display.BlendMode: an ENUM (like the flash extern), so that a game can write
// `s.blendMode = ADD` (an unqualified constructor, resolved by the expected type).
// It is turned into PIXI.BLEND_MODES when drawn.
enum BlendMode {
	NORMAL;
	LAYER;
	MULTIPLY;
	SCREEN;
	LIGHTEN;
	DARKEN;
	DIFFERENCE;
	ADD;
	SUBTRACT;
	INVERT;
	ALPHA;
	ERASE;
	OVERLAY;
	HARDLIGHT;
	SHADER;
}
