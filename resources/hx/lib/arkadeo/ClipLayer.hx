package arkadeo;

import common_haxe_avm1.display.ASprite;
import common_haxe_avm1.display.ASprite.TransformState;
import pixi.core.Pixi.BlendModes;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.Texture;

// image of a layer (flattened frames or a single shape), with its additive white silhouette when needed
class ClipLayer extends ASprite {
	public var frames(default, null):Array<Texture>;

	var anim:String;
	var addSpr:PixiSprite;
	var cur:Int;

	public function new(anim:String) {
		super();
		this.anim = anim;
		frames = Tex.get(anim);
		texture = frames[0];
		anchor.copyFrom(frames[0].defaultAnchor);
		_totalframes = frames.length;
		cur = 1;
	}

	public inline function show(i:Int) {
		var t = frames[i - 1];
		if (texture != t) {
			texture = t;
			cur = i;
			if (addSpr != null)
				addSpr.texture = Tex.get(anim + "W")[i - 1];
		}
	}

	// Flash colour offset: added colour, 0 = none
	public function setAdd(c:Int) {
		if (c == 0) {
			if (addSpr != null)
				addSpr.visible = false;
			return;
		}
		if (addSpr == null) {
			var w = Tex.get(anim + "W");
			addSpr = new PixiSprite(w[cur - 1]);
			addSpr.anchor.copyFrom(w[0].defaultAnchor);
			addSpr.blendMode = BlendModes.ADD;
			addChild(addSpr);
		}
		addSpr.visible = true;
		addSpr.tint = c;
	}

	override public function update() {
		if (_prevState == null)
			_prevState = new TransformState(this);
		_prevState.copyFrom(_curState);
	}

	override public function updateGraphics(a:Float) {
		Clip.noFlipLerp(this);
		super.updateGraphics(a);
	}
}
