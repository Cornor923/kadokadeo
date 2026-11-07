package pioupiou;

import haxe.io.UInt16Array;
import common_haxe_avm1.KeyboardManager;
import kado.KadoKadeoManager;
import kado.TouchControlsConfig.TouchControlsMode;
import pixi.core.text.Text;
import mt.DepthManager;

@:expose('GamePiouPiou')
class Game implements kado.GameInterface {
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		buttons: [
			{
				id: "left_zone",
				label: "",
				leftPx: -450,
				size: 600,
				keyCode: KeyboardManager.LEFT,
				invisible: true,
			},
			{
				id: "right_zone",
				label: "",
				rightPx: -450,
				size: 600,
				keyCode: KeyboardManager.RIGHT,
				invisible: true,
			},
		],
	};

	public var root:ASprite;
	public var level:Level;
	public var hero:Hero;

	var rootDm:DepthManager;
	var txt:Text;

	public var dmanager:DepthManager;
	public var interf:DepthManager;
	public var scroll:ASprite;
	public var data:{
		b:Array<Int>, // bubbles gathered [green, blue, red]
		l:Int, // meters
		fbl:Int, // first bubble level
		fb:Array<Int>, // falling bubbles gathered [green, blue, red]
		bp:Array<Int>, // bubble popped [green, blue, red]
		ch:Int, // max climb height
	};

	var bg:ASprite;
	var meter:ASprite;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		var replayKeys = new UInt16Array(6);
		replayKeys[0] = KeyboardManager.ARROW_LEFT;
		replayKeys[1] = KeyboardManager.ARROW_RIGHT;
		replayKeys[2] = KeyboardManager.A;
		replayKeys[3] = KeyboardManager.Q;
		replayKeys[4] = KeyboardManager.D;
		replayKeys[5] = KeyboardManager.Z;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: replayKeys,
			recordInputs: true,
			recordEvents: false,
		});

		this.root = root;
		rootDm = new DepthManager(root);
		bg = rootDm.attach("bg", 0);
		scroll = rootDm.empty(1);
		dmanager = new DepthManager(scroll);
		interf = new DepthManager(rootDm.empty(2));
		meter = interf.attach("meter", 10);
		meter._x = KadoKadeoManager.I(20);
		meter._y = KadoKadeoManager.I(300 - 3);
		txt = meter.initTextField("field", {
			font: "Junegull-Regular",
			size: 40,
			color: 0xFFFFFF,
			align: "center",
		});
		txt.x = KadoKadeoManager.I(25);
		txt.y = KadoKadeoManager.I(-20);

		setMeter(0);
		level = new Level(this);
		hero = new Hero(this);
		data = {
			b: [0, 0, 0],
			l: 0,
			fbl: -1,
			fb: [0, 0, 0],
			bp: [0, 0, 0],
			ch: 0,
		};
	}

	public function setMeter(n:Int):Void {
		txt.text = n + "M";
	}

	public function update(delta:Float):Void {
		level.update();
		hero.update();
	}

	public function destroy():Void {}
}
