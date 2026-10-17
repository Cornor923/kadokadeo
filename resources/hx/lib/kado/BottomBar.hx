package kado;

import pixi.core.graphics.Graphics;
import common_haxe_avm1.display.ASprite;
import pixi.core.textures.Texture;
import pixi.core.sprites.Sprite;

class BottomBar extends ASprite {
	var kkm:KadoKadeoManager;
	var bb:Sprite;

	var contractText:pixi.core.text.Text;
	var digitSprites:Array<Sprite> = [];
	var runDetails:Dto.RunDTO;
	var contractMask:Graphics;
	var contractBar:ASprite;
	// the score that fills the progress bar: the contract, a mission step, a defense or the attack to improve
	var progressGoal:Null<Int> = null;
	// a clan run, instead of the contract
	var clanGoal:Dto.ClanGoalDTO;

	public function new(kkm:KadoKadeoManager, runDetails:Dto.RunDTO) {
		super();
		this.kkm = kkm;
		this.runDetails = runDetails;

		this.makeBottomBar();
		this.initDigitSprites();
		this.updateScore(0);
	}

	public function makeBottomBar():Void {
		bb = Sprite.from("bottom_bar.png");
		bb.x = 0;
		bb.y = kkm.screen.height - KadoKadeoManager.S(22.6);
		this.addChild(bb);

		clanGoal = runDetails != null ? runDetails.clan : null;
		if (clanGoal != null) {
			makeClanGoal();
			return;
		}

		contractText = new pixi.core.text.Text(Std.string(runDetails != null ? runDetails.contract_points : 0), {
			fill: 0x206c7f,
			fontFamily: 'Fredoka Bold',
			fontSize: 30,
			align: 'left',
		});
		contractText.anchor.set(0.5);
		contractText.x = KadoKadeoManager.I(13);
		contractText.y = KadoKadeoManager.I(13);
		bb.addChild(contractText);

		progressGoal = runDetails != null ? runDetails.contract_score : null;
		makeProgressBar(KadoKadeoManager.I(50));

		var kadoIcon = Sprite.from("kado_icon.png");
		kadoIcon.anchor.set(0.5);
		kadoIcon.x = KadoKadeoManager.I(33);
		kadoIcon.y = KadoKadeoManager.I(13);
		kadoIcon.width = KadoKadeoManager.I(13);
		kadoIcon.height = KadoKadeoManager.I(13);
		bb.addChild(kadoIcon);
	}

	function makeProgressBar(x:Float):Void {
		var contractBarGrey = new ASprite("progress", this.kkm.sheet);
		contractBarGrey.x = x;
		contractBarGrey.y = KadoKadeoManager.I(8);
		contractBarGrey.gotoAndStop(1);
		bb.addChild(contractBarGrey);

		contractMask = new Graphics();
		contractMask.beginFill(0xffffff);
		contractMask.drawRect(0, 0, 0, 30);

		contractBar = new ASprite("progress", this.kkm.sheet);
		contractBar.x = x;
		contractBar.y = KadoKadeoManager.I(8);
		contractBar.gotoAndStop(2);
		contractBar.mask = contractMask;
		contractBar.addChild(contractMask);
		bb.addChild(contractBar);
	}

	// the clan games left (not for a mission step: it is free), then the icon of the clan run and the progress bar to its
	// goal: the score of a mission step, the score of the attack to beat (a defense) or to improve, nothing for a new attack
	// (its score 0: any score is an attack)
	function makeClanGoal():Void {
		var x:Float = KadoKadeoManager.I(5);
		if (clanGoal.type != "mission") {
			x = addIcon("/gfx/gemGreen.svg", 26, 24, KadoKadeoManager.I(10), x);
			x = right(addText(Std.string(clanGoal.attack_games), 26, x + KadoKadeoManager.I(2))) + KadoKadeoManager.I(5);
			x = addIcon("/gfx/gemOrange.svg", 26, 24, KadoKadeoManager.I(10), x);
			x = right(addText(Std.string(clanGoal.clan_games), 26, x + KadoKadeoManager.I(2))) + KadoKadeoManager.I(8);
		}
		var icon = switch (clanGoal.type) {
			case "attack": "/assets/img/gfx/icons/atk.gif";
			case "defense": "/assets/img/gfx/icons/def.gif";
			case _: "/gfx/clan/clan_mission_points.png";
		}
		x = addIcon(icon, 25, 25, KadoKadeoManager.I(13), x);
		// (a defense: the score of the attack + 1, given by the server)
		progressGoal = clanGoal.type != "attack" ? clanGoal.score : clanGoal.score > 0 ? clanGoal.score + 1 : null;
		if (progressGoal != null) {
			makeProgressBar(x + KadoKadeoManager.I(4));
		}
	}

	// (an image of the site, not of the spritesheet: sized from its known size, before it is loaded)
	function addIcon(url:String, width:Int, height:Int, displayHeight:Float, x:Float):Float {
		var scale = displayHeight / height;
		var icon = Sprite.from(url);
		icon.anchor.set(0, 0.5);
		icon.scale.set(scale);
		icon.x = x;
		icon.y = KadoKadeoManager.I(13);
		bb.addChild(icon);
		return x + width * scale;
	}

	function addText(value:String, fontSize:Int, x:Float):pixi.core.text.Text {
		var text = new pixi.core.text.Text(value, {
			fill: 0x206c7f,
			fontFamily: 'Fredoka Bold',
			fontSize: fontSize,
			align: 'left',
		});
		text.anchor.set(0, 0.5);
		text.x = x;
		text.y = KadoKadeoManager.I(13);
		bb.addChild(text);
		return text;
	}

	inline function right(text:pixi.core.text.Text):Float {
		return text.x + text.width;
	}

	public function updateScore(score:Int):Void {
		var paddedScore = Std.string(score);
		// pad with zeros to ensure it has at least 7 digits
		while (paddedScore.length < 7) {
			paddedScore = "0" + paddedScore;
		}

		for (i in 0...paddedScore.length) {
			if (i >= digitSprites.length) {
				// If there are more digits than sprites, we can choose to create new sprites or break the loop
				// For now, we'll just break the loop to avoid errors
				break;
			}
			var sprite = digitSprites[i];
			sprite.texture = this.textures[Std.parseInt(paddedScore.charAt(i))];
		}

		if (contractBar == null) {
			// (a new attack: no progress bar)
		} else if (progressGoal != null && contractMask != null) {
			var contractProgress = score / progressGoal;
			contractMask.clear();
			contractMask.beginFill(0xffffff);
			contractMask.drawRect(0, 0, contractBar._width * Math.min(contractProgress, 1), contractBar._height);
			if (contractProgress >= 1) {
				contractBar.gotoAndStop(3);
				contractBar.mask = null;
				contractMask.destroy();
				contractMask = null;
			}
		} else {
			contractBar.gotoAndStop(3);
			contractBar.mask = null;
		}
	}

	private function initDigitSprites():Void {
		for (i in 0...10) {
			textures.push(Texture.from("score/figure_" + i + ".svg"));
		}
		for (i in 0...7) {
			var digitSprite = Sprite.from("score/figure_0.svg");
			digitSprite.x = KadoKadeoManager.I(183) + i * KadoKadeoManager.I(14);
			digitSprite.y = KadoKadeoManager.I(22);
			digitSprites.push(digitSprite);
			bb.addChild(digitSprite);
		}
	}
}
