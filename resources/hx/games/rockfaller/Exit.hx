package rockfaller;

enum ExitEffect {
	Ex_Play_2;
	Ex_Play_3;
	Ex_Play_5;
	Ex_Play_8;
	Ex_Points_1;
	Ex_Points_2;
	Ex_Points_3;
}

// a tube under the bottom row: a rock on its cell falls into it (proc: plays or points), then the tube moves to
// another free cell with a new effect. Clip Exit: frames 1-7 the 7 effects (the value written on the cup, rendered
// with the text of the original by the Arkadeo port).
class Exit {
	public static inline var EXIT_DELTA = 65;
	public static inline var EXIT_HIDE = 150;
	public static var FX_WEIGHTS = [390, 122, 15, 1, 390, 82, 2];
	public static var FX_VALUES = [2, 3, 4, 6, 1500, 3000, 7000];

	public var dir:Array<Int>;
	public var mc:ASprite;
	public var fx:ExitEffect;
	public var slot:Slot;

	public function new() {
		mc = new ASprite("Exit");
		Game.me.layerExits.addChild(mc);
		setEffect(getRandomEffect());
	}

	public function setPos(x:Int, y:Int):Void {
		var pos = Slot.getStonePos(x, y);
		if (y == Game.STAGE_SIZE - 1) {
			mc._x = pos.x;
			mc._y = pos.y + EXIT_DELTA;
			dir = [0, 1];
		} else {
			mc._x = pos.x + EXIT_DELTA * (x == 0 ? -1 : 1);
			mc._y = pos.y;
			dir = [x == 0 ? -1 : 1, 0];
		}
	}

	public function setEffect(effect:ExitEffect):Void {
		fx = effect;
		mc.gotoAndStop(Type.enumIndex(fx) + 1);
	}

	public function getRandomEffect():ExitEffect {
		return Type.createEnumIndex(ExitEffect, Game.randomProbs(FX_WEIGHTS));
	}

	// a rock fell in: plays or points, then the tube goes down out of the screen, moves to another free cell with a
	// new effect and comes up again (EXIT_HIDE)
	public function proc():Void {
		var idx = Type.enumIndex(fx);
		if (idx < 4)
			Game.me.addPlay(FX_VALUES[idx]);
		else
			Game.me.addScore(FX_VALUES[idx]);

		GameSounds.play(switch (fx) {
			case Ex_Play_2: "Blackrock_life2";
			case Ex_Play_3: "Blackrock_life3";
			case Ex_Play_5 | Ex_Play_8: "Blackrock_life4";
			case Ex_Points_1: "Blackrock_points1";
			default: "Blackrock_points2";
		});

		var nfx = getRandomEffect();
		Game.me.tweenTo(mc, mc._x, mc._y + EXIT_HIDE, 6, function() {
			switchSlot();
			// the loop goes on once the tube has moved (the next getCombos sees it on its new cell)
			Game.me.waitDone();
			setEffect(nfx);
			mc._y = mc._y + EXIT_HIDE;
			// (moved under its new cell: not slid there)
			mc.updateState();
			GameSounds.play("Pipe");
			Game.me.tweenTo(mc, mc._x, mc._y - EXIT_HIDE, 6, null);
		});
	}

	public function switchSlot():Void {
		var slots = Game.me.getFreeExitSlots();
		if (slots.length == 0)
			return;
		var s = slots[Game.me.rand(slots.length)];
		if (slot != null)
			slot.exit = null;
		slot = s;
		s.exit = this;
		setPos(s.x, s.y);
	}
}
