package killbulle;

import common_haxe_avm1.KeyboardManager;
import haxe.io.UInt16Array;
import kado.KadoKadeoManager;
import kado.Seed;
import mt.DepthManager;
import mt.Timer;
import mt.bumdum.Lib;
import pixi.filters.colormatrix.ColorMatrixFilter;
import kado.TouchControlsConfig.TouchControlsMode;
import kado.TouchControlsConfig.TouchButtonShape;

@:expose('GameKillBulle')
class Game implements kado.GameInterface {
	// mobile: left / right, the up arrow throws the grapple (Space)
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		buttons: [
			{
				id: "left",
				label: "◀",
				leftPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.LEFT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "right",
				label: "▶",
				leftPx: 90,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.RIGHT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "grapple",
				label: "▲",
				rightPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.SPACE,
				shape: TouchButtonShape.SQUARE,
			},
		],
	};

	public var root:ASprite;
	public var bg:ASprite;
	public var dmanager:DepthManager;
	public var hero:Hero;
	public var blobs:Array<Blob>;
	public var camera_x:Float;
	public var tsize:Float;
	public var level:Int;
	public var updates:Array<Void->Bool>;
	public var stats:{
		b:Array<Int>,
		s:Int,
		ts:Int,
		p:Array<Int>,
		bp:Array<Array<Int>>, // bubbles popped with bonuses
	};

	public var blob_timer:Float;

	var flash_timer:Float;
	var flash_color:Int;
	var flash_filter:ColorMatrixFilter;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		var replayKeys = new UInt16Array(9);
		replayKeys[0] = KeyboardManager.LEFT;
		replayKeys[1] = KeyboardManager.RIGHT;
		replayKeys[2] = KeyboardManager.SPACE;
		replayKeys[3] = KeyboardManager.Q;
		replayKeys[4] = KeyboardManager.A;
		replayKeys[5] = KeyboardManager.D;
		replayKeys[6] = KeyboardManager.S;
		replayKeys[7] = KeyboardManager.Z;
		replayKeys[8] = KeyboardManager.W;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: replayKeys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: false,
			recordedMouseButtons: null,
		});

		this.root = root;
		tsize = 0;
		blob_timer = 0;
		camera_x = Cs.WIDTH / 2;
		dmanager = new DepthManager(root);
		bg = dmanager.attach("bg", 0);
		dmanager.attach("bg2", 2);
		level = 1;
		stats = {
			s: 0,
			ts: 0,
			p: [],
			b: [0, 0, 0, 0],
			bp: [[], [], [], []],
		};
		updates = [];
		hero = new Hero(this);
		blobs = [];
	}

	public function addUpdate(f:Void->Bool):Void {
		updates.push(f);
	}

	function genBlob():Void {
		var size:Float = (randomProbas([100, level * 10, level]) + 1) * 50;
		var bid = randomProbas(Cs.BONUS_PROBAS);
		var bonus:Null<Bonus> = null;
		if (level >= Cs.BONUS_START_LEVEL && bid > 0) {
			bonus = new Bonus(this, bid - 1);
			size = 50;
		}
		var b = new Blob(this, size, bonus);
		if (b.update()) {
			tsize += size;
			blobs.push(b);
		}
	}

	public function flash(color:Int):Void {
		flash_timer = 100;
		flash_color = color;
	}

	function setFlashFilter(d:Float):Void {
		if (flash_filter == null) {
			flash_filter = new ColorMatrixFilter();
		}
		flash_filter.matrix = [
			1, 0, 0, 0, ((flash_color >> 16) & 255) * d / 255,
			0, 1, 0, 0,  ((flash_color >> 8) & 255) * d / 255,
			0, 0, 1, 0,         (flash_color & 255) * d / 255,
			0, 0, 0, 1,                                     0
		];

		var currentFilters:Array<Dynamic> = cast root.filters;
		if (currentFilters == null) {
			root.filters = [flash_filter];
			return;
		}
		if (!currentFilters.has(flash_filter)) {
			currentFilters.push(flash_filter);
			root.filters = cast currentFilters;
		}
	}

	function clearFlashFilter():Void {
		if (flash_filter == null) {
			return;
		}
		var currentFilters:Array<Dynamic> = cast root.filters;
		if (currentFilters == null) {
			return;
		}
		var nextFilters = [];
		for (filter in currentFilters) {
			if (filter != flash_filter) {
				nextFilters.push(filter);
			}
		}
		root.filters = nextFilters.length == 0 ? null : cast nextFilters;
	}

	function randomProbas(probas:Array<Int>):Int {
		var total = 0;
		for (v in probas) {
			total += v;
		}
		if (total <= 0) {
			return 0;
		}
		var rnd = Seed.random(total);
		for (i in 0...probas.length) {
			rnd -= probas[i];
			if (rnd < 0) {
				return i;
			}
		}
		return probas.length - 1;
	}

	public function update(delta:Float):Void {
		if (blob_timer > 0)
			blob_timer -= Timer.deltaT;

		if (flash_timer > 0) {
			flash_timer -= 10 * Timer.tmod;
			if (flash_timer <= 0)
				clearFlashFilter();
			else {
				var d = flash_timer / 100;
				setFlashFilter(d);
			}
		}

		var spawnChance = Std.int(Num.q((tsize / 100) * (Cs.BLOB_PROBAS / Math.sqrt(level)) / Timer.tmod));
		if (Seed.random(spawnChance) == 0)
			genBlob();
		hero.update();
		var p = Math.pow(0.9, Timer.tmod);
		camera_x = Num.q(camera_x * p + hero.x * (1 - p));

		root._x = -Math.min(Math.max(camera_x - KadoKadeoManager.I(150), 0), Cs.WIDTH - KadoKadeoManager.I(300));
		bg._x = -root._x / 3;

		if (blob_timer <= 0) {
			var i = 0;
			while (i < blobs.length) {
				if (!blobs[i].update()) {
					tsize -= blobs[i].size;
					blobs.splice(i--, 1);
				}
				i++;
			}
		}

		var i = 0;
		while (i < updates.length) {
			if (!updates[i]()) {
				updates.splice(i--, 1);
			}
			i++;
		}
	}

	public function destroy():Void {}
}
