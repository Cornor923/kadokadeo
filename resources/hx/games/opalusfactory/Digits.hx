package opalusfactory;

import opalusfactory.Data.FieldDef;
import pixi.core.display.Container;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.Texture;

// a text field of the SWF holding a number (the goal of a hole, the nuts of blockHole, the points that rise): the
// digits of the Trebuchet MS Bold font embedded in the SWF (white pictures, pivot on the pen position of the
// baseline), tinted, placed like Flash lays out a centred field (2 px gutter, first baseline at the ascent): no browser
// font, the same on every computer. The filters of the field are layers of pictures under the digits (Flash draws a
// glow under what it surrounds; every glyph's glow, then the glyphs), the drop shadow of the clip holding the field
// (points._p) a layer moved down (setShadow). A child of the picture or clip that holds the field, `k` of its pixels
// per Flash pixel. (The holes' fields use the player's device font in the SWF: the outlines embedded for the points'
// field are the same font.)
class Digits extends ASprite {
	var field:FieldDef;
	var adv:Array<Float>;
	var k:Float;
	var text:String;
	var layers:Array<Container> = [];
	var glyphs:Array<Array<Texture>> = [];

	// the drop shadow layer, moved down by `dist` stage pixels; `sy`: the _yscale / 100 of the clip holding the field
	// (setShadow). Both are interpolated like the clip from the state of the last step, the layer placed at each render
	var shadowOn:Bool = false;
	var dist:Float = 0;
	var sy:Float = 1;
	var pdist:Null<Float> = null;
	var psy:Float = 1;

	public function new(field:FieldDef, adv:Array<Float>, k:Float) {
		super();
		this.field = field;
		this.adv = adv;
		this.k = k;
		for (l in field.layers) {
			var c = new Container();
			addChild(c);
			layers.push(c);
			glyphs.push(Tex.get(l.anim));
		}
	}

	public function setShadow(dist:Float, sy:Float) {
		if (!shadowOn) {
			pdist = dist;
			psy = sy;
		}
		shadowOn = true;
		this.dist = dist;
		this.sy = sy;
	}

	override public function update() {
		super.update();
		pdist = dist;
		psy = sy;
	}

	// (after the clip holding the field: its scale shown is already interpolated)
	override public function updateGraphics(a:Float) {
		super.updateGraphics(a);
		if (!shadowOn)
			return;
		var s = psy + (sy - psy) * a;
		if (Math.abs(s) <= 0.001)
			return;
		var v = (pdist + (dist - pdist) * a) / s;
		for (i in 0...layers.length)
			if (field.layers[i].shadow)
				layers[i].y = v * k;
	}

	// field.text = s
	public function setText(s:String) {
		if (s == text)
			return;
		text = s;
		var idx = [for (i in 0...s.length) "0123456789".indexOf(s.charAt(i))];
		var width = 0.0;
		for (d in idx)
			if (d >= 0)
				width += adv[d];
		// glyphs drawn at K px per Flash pixel
		var sc = k / Clip.K;
		for (li in 0...layers.length) {
			var layer = layers[li];
			var pen = field.x + (field.w - width) * 0.5;
			var n = 0;
			for (d in idx) {
				if (d < 0)
					continue;
				var t = glyphs[li][d];
				var sp:PixiSprite;
				if (n < layer.children.length) {
					sp = cast layer.children[n];
					sp.texture = t;
					sp.visible = true;
				} else {
					sp = new PixiSprite(t);
					sp.anchor.copyFrom(t.defaultAnchor);
					sp.tint = field.layers[li].color;
					sp.scale.set(sc, sc);
					layer.addChild(sp);
				}
				sp.x = pen * k;
				sp.y = field.base * k;
				pen += adv[d];
				n++;
			}
			for (i in n...layer.children.length)
				layer.children[i].visible = false;
		}
	}
}
