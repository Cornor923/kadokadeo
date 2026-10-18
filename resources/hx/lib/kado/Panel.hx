package kado;

import pixi.core.textures.Texture;
import pixi.mesh.NineSlicePlane;
import pixi.core.display.Container;

class Panel extends NineSlicePlane {
	var titleText:pixi.core.text.Text;
	var contentContainer:Container;

	public function new(kkm:KadoKadeoManager) {
		super(Texture.from("window_back.png"), 50, 70, 50, 50);
		this.contentContainer = new Container();
		this.addChild(this.contentContainer);
	}

	public function setTitle(title:String):Void {
		if (this.titleText != null) {
			this.removeChild(this.titleText);
		}
		this.titleText = new pixi.core.text.Text(title, {
			fontFamily: 'Fredoka Bold',
			fontSize: 40,
			fill: [0xFFFF00, 0xFF9900],
			align: 'center',
			stroke: 0xFF9900,
			strokeThickness: 6,
			letterSpacing: 2
		});
		this.titleText.x = (this.width - this.titleText.width) / 2;
		this.titleText.y = -6;
		this.addChild(this.titleText);
	}

	public function clearContent():Void {
		this.contentContainer.removeChildren();
	}

	public function addContentDisplayObject(obj:pixi.core.display.DisplayObject):Void {
		this.contentContainer.addChild(obj);
	}

	// grows to show the whole content
	public function fitHeight(minHeight:Float):Void {
		var bottom = contentContainer.y + contentContainer.getLocalBounds().bottom;
		this.height = Math.max(minHeight, bottom + KadoKadeoManager.I(15));
	}

	// a centered message (server connection, run sending...), with an optional smaller line under it
	public function showMessage(title:String, message:String, ?hint:String):Void {
		setTitle(title);
		clearContent();
		// (the messages of the server are not cut by lines)
		var text = new pixi.core.text.Text(message, {
			fontFamily: 'Fredoka Bold',
			fontSize: 30,
			fill: 0x78c3c9,
			align: 'center',
			wordWrap: true,
			wordWrapWidth: this.width - KadoKadeoManager.I(24),
		});
		addContentDisplayObject(text);
		text.x = (this.width - text.width) / 2;
		text.y = KadoKadeoManager.I(23);
		if (hint != null) {
			var hintText = new pixi.core.text.Text(hint, {
				fontFamily: 'Fredoka Bold',
				fontSize: 22,
				fill: 0xFF6400,
				align: 'center',
			});
			addContentDisplayObject(hintText);
			hintText.x = (this.width - hintText.width) / 2;
			hintText.y = text.y + text.height + KadoKadeoManager.I(4);
		}
	}
}
