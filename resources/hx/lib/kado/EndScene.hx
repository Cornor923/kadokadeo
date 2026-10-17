package kado;

import pixi.extras.AnimatedSprite;
import common_haxe_avm1.pixi.DropShadowFilter;
import pixi.core.display.Container;
import pixi.core.sprites.Sprite;
import pixi.mesh.NineSlicePlane;
import mt.bumdum.Lib;

class EndScene extends Container {
	var kkm:KadoKadeoManager;
	var details:Dto.EndRunResponseDTO;
	var disposed:Bool = false;
	var tweens:Array<Dynamic> = [];
	var piouWalk:AnimatedSprite;
	var piouFloat:AnimatedSprite;

	var text:Array<String>;

	var fieldBest:pixi.core.text.Text;

	inline function registerTween(tween:Dynamic):Dynamic {
		tweens.push(tween);

		tween.on("end", () -> {
			var index = tweens.indexOf(tween);
			if (index >= 0) {
				tweens.splice(index, 1);
				untyped tween.stop();
				untyped tween.remove();
				untyped tween.removeAllListeners();
			}
		});
		return tween;
	}

	public function dispose():Void {
		if (disposed) {
			return;
		}
		disposed = true;
		for (tween in tweens) {
			if (tween != null) {
				untyped tween.stop();
				untyped tween.remove();
				untyped tween.removeAllListeners();
			}
		}
		tweens = [];
		if (piouWalk != null) {
			piouWalk.stop();
		}
		if (piouFloat != null) {
			piouFloat.stop();
		}
	}

	public function new(kkm:KadoKadeoManager, details:Dto.EndRunResponseDTO) {
		super();
		this.kkm = kkm;
		this.details = details;
		var textFr = [
			"VOUS ETES QUALIFIE !",
			"VOUS N\'ETES PAS QUALIFIE",
			"Attention a ne pas perdre votre place!",
			"CONTRAT REUSSI !",
			"DEFENSE REUSSIE !",
			"DEFENSE RATEE !",
			"ATTAQUE LANCEE !",
			"SCORE BATTU",
			"POINTS",
			"ETOILE",
			"NOUVELLE ETOILE",
			"VOTRE SCORE",
			"NOUVEAU RECORD",
			"RECORD DE LA PERIODE",
			"Cliquez pour rejouer",
			"Cliquez pour défendre à nouveau",
			"Cliquez pour retenter une attaque",
			"ETAPE MISSION OK !",
			"ETAPE MISSION RATEE !",
			"VOUS ETES PREMIER !",
			""
		];
		var textEn = [
			"YOU ARE QUALIFIED!",
			"YOU ARE NOT QUALIFIED",
			"Pay attention and do not lose your position!",
			"CONTRACT SUCCESS!",
			"DEFENSE SUCCESS!",
			"DEFENSE FAILED!",
			"ATTACK LAUNCHED!",
			"SCORE BEATEN",
			"POINTS",
			"STAR",
			"NEW STAR",
			"YOUR SCORE",
			"NEW RECORD",
			"PERIOD RECORD",
			"Click here to play again",
			"Click here to defend again",
			"Click here to relaunch your attack",
			"MISSION STEP OK!",
			"MISSION STEP FAILED!"
		];
		var textEs = [
			"¡ESTÁS CLASIFICADO!",
			"NO TE HAS CLASIFICADO",
			"¡Presta atención y no pierdas tu posición!",
			"¡CONTRATO CUMPLIDO!",
			"¡DEFENSA CONSEGUIDA!",
			"¡DEFENSA FRACASADA!",
			"¡DESAFÍO LANZADO!",
			"PTS. SUPERADOS",
			"PTS.",
			"ESTRELLA",
			"NUEVA ESTRELLA",
			"TU PUNTUACIÓN",
			"NUEVO RÉCORD",
			"RÉCORD DEL PERIODO",
			"Haz clic aquí para jugar de nuevo",
			"Haz clic aquí para defender de nuevo",
			"Haz clic aquí para reintentar el desafío",
			"¡ETAPA DE MISIÓN SUPERADA CON ÉXITO!",
			"¡ETAPA DE MISIÓN FRACASADA!"
		];
		var textDe = [
			"DU BIST QUALIFIZIERT!",
			"DU BIST NICHT QUALIFIZIERT\t",
			"Pass auf und halte deinen Platz in der Rangliste!",
			"AUFGABE ERFÜLLT!",
			"VERTEIDIGUNG ERFOLGREICH!",
			"VERTEIDIGUNG FEHLGESCHLAGEN!",
			"ANGRIFF GESTARTET!",
			"REKORD GESCHLAGEN",
			"PUNKTE",
			"STERN",
			"NEUER STERN",
			"DEINE PUNKTE",
			"NEUER REKORD",
			"SAISONREKORD",
			"Klick hier, um nochmal zu spielen",
			"Klick hier, um nochmal zu verteidigen",
			"Klick hier, um nochmal anzugreifen",
			"MISSIONSSCHRITT OK!",
			"MISSIONSSCHRITT FEHLGESCHLAGEN!"
		];

		text = switch (kkm.lang) {
			case "fr": textFr;
			case "en": textEn;
			case "es": textEs;
			case "de": textDe;
			default: textFr;
		};

		var back = this.addChild(Sprite.from("gameover_back.png"));
		back.width = kkm.screen.width;
		back.height = kkm.screen.height;
		// laid out for the 600 x 640 canvas of a KadoKado game: smaller in a lower canvas (an Arkadeo game: 600 x 500)
		var content = new Container();
		var k = Math.min(1, kkm.screen.height / KadoKadeoManager.I(320));
		content.scale.set(k);
		content.x = (kkm.screen.width - kkm.screen.width * k) / 2;
		this.addChild(content);
		content.addChild(makePanScore());
		content.addChild(makePiouTrack());
		content.addChild(clickToReplay());
	}

	public function handleReplayClick():Void {
		if (tweens.filter(t -> t != null && !t.loop).length == 0) {
			emit('replay');
			return;
		}
		for (tween in tweens) {
			if (tween != null && !tween.loop) {
				untyped tween._elapsedTime = tween.time - 1;
				untyped tween.delay = 0;
				tween.update(1, 1);
			}
		}
	}

	public function makePanScore():Container {
		var cont = new NineSlicePlane(Sprite.from("window_back_2.png").texture, KadoKadeoManager.I(17), KadoKadeoManager.I(23), KadoKadeoManager.I(17),
			KadoKadeoManager.I(17));
		cont.width = KadoKadeoManager.I(300);
		cont.height = KadoKadeoManager.I(68);
		cont.x = (kkm.screen.width - cont.width) / 2;
		cont.y = KadoKadeoManager.I(150);
		var fieldTitle = cont.addChild(new pixi.core.text.Text(text[11], {
			fontFamily: 'Fredoka Bold',
			fontSize: 40,
			fill: 0x056a83,
			align: 'center',
			letterSpacing: 2
		}));
		fieldTitle.x = (kkm.screen.width - fieldTitle.width) / 2;

		var fieldScore = cont.addChild(new pixi.core.text.Text(Std.string(kkm.score), {
			fontFamily: 'Junegull-Regular',
			fontSize: 100,
			fill: 0xfdb102,
			align: 'center',
			letterSpacing: 6
		}));
		fieldScore.x = (kkm.screen.width - fieldScore.width) / 2;
		fieldScore.y = details.is_best ? KadoKadeoManager.I(12) : KadoKadeoManager.I(20);
		Filt.glow(fieldScore, 6, 4, 0xba3801);
		fieldScore.filters.push(new DropShadowFilter({
			blur: 5,
			rotation: 90,
			distance: 18,
			color: 0xb8dee5,
		}));

		fieldBest = cont.addChild(new pixi.core.text.Text(text[13], {
			fontFamily: 'Junegull-Regular',
			fontSize: 24,
			fill: 0xff6a2b,
			align: 'center',
		}));
		fieldBest.x = (kkm.screen.width - fieldBest.width) / 2;
		fieldBest.y = KadoKadeoManager.I(56);
		fieldBest.alpha = details.is_best ? 1 : 0;
		Filt.glow(fieldBest, KadoKadeoManager.I(5), 2, 0xffff00);

		var tweenFilterBest = registerTween(pixi.core.Pixi.tweenManager.createTween(fieldBest));
		tweenFilterBest.time = 300;
		tweenFilterBest.pingPong = true;
		tweenFilterBest.easing = pixi.core.Pixi.tween.Easing.inSine();
		// var testFilter1 = {}
		// var testFilter2 = {}
		// testFilter1[0] = {padding: 0};
		// testFilter2[0] = {padding: 15};
		tweenFilterBest.from({
			tint: 0xff6a2b,
			// filters: testFilter1
		});
		tweenFilterBest.to({
			tint: 0xfecd40,
			// filters: testFilter2
		});
		tweenFilterBest.loop = true;
		tweenFilterBest.start();

		var tweenY = registerTween(pixi.core.Pixi.tweenManager.createTween(cont));
		tweenY.time = 1500;
		tweenY.easing = pixi.core.Pixi.tween.Easing.outExpo();
		tweenY.delay = 500;
		tweenY.from({
			y: KadoKadeoManager.I(150)
		});
		tweenY.to({
			y: KadoKadeoManager.I(17)
		});
		tweenY.start();

		return cont;
	}

	private function makePiouTrack():Container {
		var cont = new Container();

		var piouCont = new Container();
		piouWalk = new AnimatedSprite(untyped kkm.sheet.animations["piou_walk"]);
		var piouShade = Sprite.from("piou_shade.png");
		piouShade.scale.set(0.77);
		piouCont.addChild(piouShade);
		piouCont.addChild(piouWalk);
		piouCont.x = KadoKadeoManager.I(17);
		piouCont.y = KadoKadeoManager.I(33);
		piouWalk.y = KadoKadeoManager.I(7);
		piouWalk.animationSpeed = 0.5;
		piouWalk.gotoAndStop(0);

		var road = Sprite.from("road.png");
		cont.addChild(road);

		var end_line_cont = new Container();
		var end_line_1 = Sprite.from("end_line_1.png");
		var end_line_2 = Sprite.from("end_line_2.png");
		end_line_2.y = KadoKadeoManager.I(-17);
		end_line_2.x = 1;
		end_line_cont.addChild(end_line_1);
		end_line_cont.addChild(end_line_2);
		end_line_cont.x = KadoKadeoManager.I(235);
		end_line_cont.y = KadoKadeoManager.I(37);
		cont.addChild(end_line_cont);

		cont.addChild(piouCont);
		cont.x = KadoKadeoManager.I(17);
		cont.y = KadoKadeoManager.I(166);

		cont.alpha = 0;
		var tweenAppear = registerTween(pixi.core.Pixi.tweenManager.createTween(cont));
		tweenAppear.time = 1000;
		tweenAppear.easing = pixi.core.Pixi.tween.Easing.outExpo();
		tweenAppear.delay = 1000;
		tweenAppear.from({
			alpha: 0
		});
		tweenAppear.to({
			alpha: 1
		});
		tweenAppear.start();

		var textQualField = cont.addChild(new pixi.core.text.Text(text[19], {
			fontFamily: 'Junegull-Regular',
			fontSize: 24,
			fill: 0x056a83,
			align: 'center',
		}));
		textQualField.x = (kkm.screen.width - textQualField.width) / 2 - cont.x;
		textQualField.y = KadoKadeoManager.I(50);
		textQualField.alpha = details.people_to_beat == 0 ? 1 : 0;

		var textQual = cont.addChild(new pixi.core.text.Text(txtPlayersToOvertake(details.people_to_beat), {
			// fontFamily: 'Junegull-Regular',
			fontSize: 24,
			fill: 0x056a83,
			align: 'center',
		}));
		textQual.x = (kkm.screen.width - textQual.width) / 2 - cont.x;
		textQual.y = KadoKadeoManager.I(66);
		textQual.alpha = details.people_to_beat > 0 ? 1 : 0;
		cont.addChild(textQual);
		cont.addChild(textQualField);

		var tweenPiouMove = registerTween(pixi.core.Pixi.tweenManager.createTween(piouCont));
		var MOVE_TIME_PER_PX = 1500 / KadoKadeoManager.I(218);
		var MOVE_VALUES = [235, 213, 191, 169, 148, 126, 104, 83, 60, 38];
		var moveIndex = details.people_to_beat > 9 ? 9 : details.people_to_beat;
		var moveTargetX = KadoKadeoManager.I(MOVE_VALUES[moveIndex]);
		var moveDistance = Math.abs(moveTargetX - KadoKadeoManager.I(17));
		tweenPiouMove.time = Std.int(moveDistance * MOVE_TIME_PER_PX);
		// tweenPiouMove.time = 1500;
		tweenPiouMove.delay = 2000;
		tweenPiouMove.from({x: KadoKadeoManager.I(17)}).to({x: moveTargetX}).start();

		untyped tweenPiouMove.on("start", () -> {
			if (disposed || piouWalk == null) {
				return;
			}
			piouWalk.play();
		});

		untyped tweenPiouMove.on("end", () -> {
			if (disposed || piouWalk == null) {
				return;
			}
			piouWalk.gotoAndStop(0);
			if (details.people_to_beat == 0) {
				piouFloat = new AnimatedSprite(untyped kkm.sheet.animations["piou_float"]);
				piouFloat.animationSpeed = 0.5;
				piouFloat.y = KadoKadeoManager.I(-17);
				piouCont.removeChild(piouWalk);
				piouCont.addChild(piouFloat);
				piouFloat.play();

				var tweenFloat1 = registerTween(pixi.core.Pixi.tweenManager.createTween(piouFloat));
				tweenFloat1.time = 600;
				tweenFloat1.pingPong = true;
				tweenFloat1.loop = true;
				tweenFloat1.from({y: piouFloat.y}).to({y: piouFloat.y - KadoKadeoManager.I(7)}).start();
				var tweenFloat2 = registerTween(pixi.core.Pixi.tweenManager.createTween(piouFloat));
				tweenFloat2.time = 800;
				tweenFloat2.loop = true;
				tweenFloat2.from({rotation: 0}).to({rotation: 6.28}).start();
			}
		});

		return cont;
	}

	private function clickToReplay():Container {
		var cont = new Container();
		var field = cont.addChild(new pixi.core.text.Text(text[14], {
			fontFamily: 'Verdana',
			fontSize: 20,
			fill: 0x056a83,
			align: 'center',
		}));
		field.x = (kkm.screen.width - field.width) / 2;
		field.y = KadoKadeoManager.I(300);
		field.alpha = 0;
		cont.addChild(field);

		var tweenBlink = registerTween(pixi.core.Pixi.tweenManager.createTween(field));
		tweenBlink.time = 500;
		tweenBlink.delay = 1000;
		tweenBlink.loop = true;
		tweenBlink.pingPong = true;
		tweenBlink.easing = untyped(a) -> a < 0.251 ? 0 : 1;
		tweenBlink.from({alpha: 1}).to({alpha: 0}).start();

		return cont;
	}

	private function txtPlayersToOvertake(n:Int):String {
		if (kkm.lang == "en") {
			return "You still have " + n + " players to overtake!";
		}
		if (kkm.lang == "es") {
			return "¡Todavía tienes que superar a " + n + " jugadores!";
		}
		if (kkm.lang == "de") {
			return "Du hast noch " + n + " Spieler vor dir!";
		}
		return "Il y a encore " + n + " joueurs à dépasser !";
	}

	public override function destroy(?options:Null<haxe.extern.EitherType<Bool, pixi.core.display.DisplayObject.DestroyOptions>>) {
		this.dispose();
		super.destroy(options);
	}
}
