package kado;

import pixi.core.textures.Texture;
import pixi.core.graphics.Graphics;
import pixi.core.display.Container;
import pixi.core.sprites.Sprite;

class StartScene extends Container {
	var kkm:KadoKadeoManager;

	var clicToStartText:pixi.core.text.Text;
	var elapsed:Float;
	var panel:Panel;
	var overlay:Graphics;

	public function new(kkm:KadoKadeoManager, gameName:String) {
		super();
		this.kkm = kkm;
		this.elapsed = 0;

		this.addChild((new Graphics()).beginFill(0x6b95b4, 1).drawRect(0, 0, kkm.screen.width, kkm.screen.height).endFill());
		this.makeBottomBar();

		var art = Sprite.from("/assets/img/gfx/artwork/" + gameName + ".jpg");
		this.addChild(art);

		this.overlay = new Graphics();
		overlay.beginFill(0x6b95b4, 0.36);
		overlay.drawRect(0, 0, kkm.screen.width, kkm.screen.height);
		overlay.endFill();
		overlay.visible = false;
		this.addChild(overlay);

		this.panel = new Panel(kkm);
		panel.width = KadoKadeoManager.I(216);
		panel.height = KadoKadeoManager.I(83);
		panel.x = (kkm.screen.width - panel.width) / 2;
		panel.y = (kkm.screen.height - panel.height) / 2;
		panel.visible = false;
		this.addChild(panel);

		var updateFn = this.update;
		kkm.ticker.add(updateFn);
	}

	public function makeBottomBar():Void {
		var bb = Sprite.from("bottom_bar.png");
		bb.x = 0;
		bb.y = kkm.screen.height - KadoKadeoManager.I(23);
		this.addChild(bb);

		this.clicToStartText = new pixi.core.text.Text("CLIQUER POUR COMMENCER", {
			fontFamily: 'Fredoka Bold',
			fontSize: 35,
			fill: 0xFF6400,
			align: 'center',
			stroke: 0xFFFFFF,
			strokeThickness: 8,
			letterSpacing: 2
		});
		this.clicToStartText.x = (kkm.screen.width - this.clicToStartText.width) / 2;
		this.clicToStartText.y = kkm.screen.height - KadoKadeoManager.I(22);
		this.addChild(this.clicToStartText);
	}

	function update(delta:Float):Void {
		elapsed += delta;
		clicToStartText.visible = (Math.floor(elapsed / 30) % 2 == 0);
	}

	override public function destroy(?options:Null<haxe.extern.EitherType<Bool, pixi.core.display.DisplayObject.DestroyOptions>>) {
		kkm.ticker.remove(this.update);
		super.destroy(options);
	}

	public function disable():Void {
		kkm.ticker.remove(this.update);
		this.clicToStartText.visible = false;
		this.interactive = false;
		overlay.visible = true;
		panel.visible = true;
		showMessage("", 'CONNEXION AU\nSERVEUR EN COURS...');
	}

	// the run could not begin: the message of the server (no games left, the daily game already played...)
	public function showError(error:Dto.ApiError):Void {
		var message = switch (error.status) {
			case 0: "LE SERVEUR N'A PAS PU ÊTRE JOINT.";
			case status if (status >= 500): "ERREUR DU SERVEUR.";
			case _: error.message.toUpperCase();
		}
		// (refused by the server: asking again would be refused too)
		var refused = error.status == 403 || error.status == 422;
		showMessage("ERREUR", message, refused ? null : "CLIQUER POUR RÉESSAYER");
	}

	function showMessage(title:String, message:String, ?hint:String):Void {
		panel.showMessage(title, message, hint);
		panel.fitHeight(KadoKadeoManager.I(83));
		panel.y = (kkm.screen.height - panel.height) / 2;
	}

	public function showContract(contract:Dto.RunDTO):Void {
		panel.height = KadoKadeoManager.I(83);
		panel.y = (kkm.screen.height - panel.height) / 2;
		panel.setTitle("CONTRAT");
		panel.clearContent();
		var scoreToBeat = new pixi.core.text.Text('SCORE À BATTRE', {
			fontFamily: 'Fredoka Bold',
			fontSize: 30,
			fill: 0x78c8c8,
			align: 'left',
		});
		panel.addContentDisplayObject(scoreToBeat);
		scoreToBeat.x = KadoKadeoManager.I(10);
		scoreToBeat.y = KadoKadeoManager.I(23);

		var contractPoints = new pixi.core.text.Text('POINTS', {
			fontFamily: 'Fredoka Bold',
			fontSize: 30,
			fill: 0x78c8c8,
			align: 'left',
		});
		panel.addContentDisplayObject(contractPoints);
		contractPoints.x = KadoKadeoManager.I(150);
		contractPoints.y = KadoKadeoManager.I(23);

		var verticalBar = new Graphics();
		verticalBar.beginFill(0xd3d3d3).drawRect(KadoKadeoManager.I(133), KadoKadeoManager.I(23), KadoKadeoManager.I(3), KadoKadeoManager.I(50)).endFill();
		panel.addContentDisplayObject(verticalBar);

		var scoreToBeatValue = new pixi.core.text.Text(Std.string(contract.contract_score), {
			fontFamily: 'Fredoka Bold',
			fontSize: 40,
			fill: 0x0798FF,
			align: 'center',
		});
		scoreToBeatValue.x = KadoKadeoManager.I(66) - scoreToBeatValue.width / 2;
		scoreToBeatValue.y = KadoKadeoManager.I(46);
		panel.addContentDisplayObject(scoreToBeatValue);

		var contractPointsValue = new pixi.core.text.Text(Std.string(contract.contract_points), {
			fontFamily: 'Fredoka Bold',
			fontSize: 40,
			fill: 0x0798FF,
			align: 'right',
		});
		contractPointsValue.x = KadoKadeoManager.I(183) - contractPointsValue.width;
		contractPointsValue.y = KadoKadeoManager.I(46);
		panel.addContentDisplayObject(contractPointsValue);

		var kImg = new Sprite(Texture.from('kado_icon.png'));
		kImg.x = KadoKadeoManager.I(193);
		kImg.y = KadoKadeoManager.I(58);
		kImg.scale.set(0.5);
		panel.addContentDisplayObject(kImg);
	}
}
