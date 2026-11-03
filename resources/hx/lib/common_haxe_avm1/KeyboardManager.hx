package common_haxe_avm1;

import haxe.ds.IntMap;
import js.html.KeyboardEvent;
import common_haxe_avm1.kac.Natives;

// Extra key for a key read by the game: `code` is the physical key (KeyboardEvent.code, independent of the layout:
// "KeyW" is Z on AZERTY and W on QWERTY), `keyCode` the legacy key code. `key` is the key the game reads.
typedef KeyAlias = {
	@:optional var code:String;
	@:optional var keyCode:Int;
	var key:Int;
}

class KeyboardManager {
	static public inline var BACKSPACE = 8;
	static public inline var DELETE = 46;
	static public inline var ENTER = 13;
	static public inline var SHIFT = 16;
	static public inline var CONTROL = 17;
	static public inline var ESCAPE = 27;
	static public inline var SPACE = 32;
	static public inline var DIGIT_2 = 50;
	static public inline var DIGIT_3 = 51;
	static public inline var DIGIT_4 = 52;
	static public inline var DIGIT_5 = 53;
	static public inline var DIGIT_6 = 54;
	static public inline var DIGIT_7 = 55;
	static public inline var DOWN = 40;
	static public inline var UP = 38;
	static public inline var LEFT = 37;
	static public inline var RIGHT = 39;
	static public inline var ARROW_DOWN = 40;
	static public inline var ARROW_UP = 38;
	static public inline var ARROW_LEFT = 37;
	static public inline var ARROW_RIGHT = 39;
	static public inline var A = 65;
	static public inline var B = 66;
	static public inline var C = 67;
	static public inline var D = 68;
	static public inline var E = 69;
	static public inline var F = 70;
	static public inline var G = 71;
	static public inline var H = 72;
	static public inline var M = 77;
	static public inline var N = 78;
	static public inline var Q = 81;
	static public inline var R = 82;
	static public inline var S = 83;
	static public inline var V = 86;
	static public inline var W = 87;
	static public inline var Z = 90;
	static public inline var F1 = 112;
	static public inline var F2 = 113;
	static public inline var F3 = 114;
	static public inline var F4 = 115;
	static public inline var F5 = 116;
	static public inline var F6 = 117;
	static public inline var F7 = 118;
	static public inline var F8 = 119;

	// ZQSD (AZERTY) / WASD (QWERTY): the same physical keys move like the arrows
	static public var ALIASES_MOVE:Array<KeyAlias> = [
		{code: "KeyW", key: UP},
		{code: "KeyA", key: LEFT},
		{code: "KeyS", key: DOWN},
		{code: "KeyD", key: RIGHT}
	];
	// Enter (main keyboard and keypad) does what Space does
	static public var ALIASES_ENTER_SPACE:Array<KeyAlias> = [{keyCode: ENTER, key: SPACE}];
	// Control does what Space does (only for the games that do not read Control themselves)
	static public var ALIASES_CONTROL_SPACE:Array<KeyAlias> = [{keyCode: CONTROL, key: SPACE}];

	static private var keyState:IntMap<Bool>;
	static private var justPressed:IntMap<Bool>;
	static private var frameKeyChanges:Array<{keyCode:Int, isDown:Bool, t:Float}> = [];
	// time of the last key change applied on this frame (-1: none), see kado.ReplayManager (phases)
	static private var frameInputTime:Float = -1;
	static private var isInitialized:Bool = false;
	static private var inputLocked:Bool = false;
	// t: time of the input (Event.timeStamp, ms), -1 for a replay
	static private var pendingOps:Array<{keyCode:Int, isDown:Bool, t:Float}> = [];
	static private var aliases:Array<KeyAlias> = [];
	// game key -> physical keys holding it down (a key mapped on several keys is released with the last one)
	static private var heldBy:IntMap<Array<String>> = new IntMap();

	static public var lastDown:Int;

	static public function init() {
		if (isInitialized) {
			return;
		}

		keyState = new IntMap();
		justPressed = new IntMap();
		frameKeyChanges = [];
		isInitialized = true;

		// (with the addEventListener of the page: a script cannot wrap the events given to the game)
		Natives.listen(js.Browser.window, "keydown", onKeyDown);
		Natives.listen(js.Browser.window, "keyup", onKeyUp);
		Natives.listen(js.Browser.window, "blur", onBlur);

		/*window.js.Browser.dEventListener("keydown", function(e) {
			if (["Space", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].indexOf(e.code) > -1) {
				e.preventDefault();
			}
		}, false);*/
	}

	static private function onKeyUp(e:KeyboardEvent):Void {
		var targets = keyTargets(e);
		// a release is always taken (the key may have been pressed in the game before going to a field)
		if (!isTyping(e) && (targets.length > 1 || [SPACE, ARROW_UP, ARROW_DOWN, ARROW_LEFT, ARROW_RIGHT].contains(e.keyCode))) {
			e.preventDefault();
		}
		if (inputLocked) {
			return;
		}
		// (a key event made for a field of the page, e.g. by a password manager, is not counted)
		var t = isTyping(e) && !Natives.isTrustedEvent(e) ? Math.NaN : Natives.takeInput(e);
		if (Math.isNaN(t)) {
			return;
		}
		var source = physicalKey(e);
		for (key in targets) {
			var held = heldBy.get(key);
			if (held != null) {
				held.remove(source);
				if (held.length > 0) {
					continue;
				}
				heldBy.remove(key);
			}
			queueKeyOp(key, false, false, t);
		}
	}

	static private function onKeyDown(e:KeyboardEvent) {
		// typed in a text field of the page: for the field, not for the game
		if (isTyping(e)) {
			return;
		}
		var targets = keyTargets(e);
		if (targets.length > 1 || [SPACE, ARROW_UP, ARROW_DOWN, ARROW_LEFT, ARROW_RIGHT].contains(e.keyCode)) {
			e.preventDefault();
		}
		if (inputLocked) {
			return;
		}
		var t = Natives.takeInput(e);
		if (Math.isNaN(t)) {
			return;
		}
		var source = physicalKey(e);
		for (key in targets) {
			var held = heldBy.get(key);
			if (held == null) {
				held = [];
				heldBy.set(key, held);
			}
			if (!held.contains(source)) {
				held.push(source);
			}
			queueKeyOp(key, true, false, t);
		}
	}

	static private function isTyping(e:KeyboardEvent):Bool {
		var el:js.html.Element = cast e.target;
		if (el == null || el.tagName == null) {
			return false;
		}
		var tag = el.tagName.toUpperCase();
		return tag == "INPUT" || tag == "TEXTAREA" || tag == "SELECT" || el.isContentEditable;
	}

	// window lost the focus: the key releases will not be received
	static private function onBlur(_:js.html.Event):Void {
		if (inputLocked) {
			return;
		}
		for (key in heldBy.keys()) {
			queueKeyOp(key, false);
		}
		heldBy = new IntMap();
	}

	// the key itself and the game keys it is an alias of
	static private function keyTargets(e:KeyboardEvent):Array<Int> {
		var out = [e.keyCode];
		for (a in aliases) {
			if ((a.code != null && a.code == e.code) || (a.keyCode != null && a.keyCode == e.keyCode)) {
				if (!out.contains(a.key)) {
					out.push(a.key);
				}
			}
		}
		return out;
	}

	static private inline function physicalKey(e:KeyboardEvent):String {
		return e.code != null && e.code != "" ? e.code : "key" + e.keyCode;
	}

	// extra keys of the current game (see KeyAlias), e.g. ALIASES_MOVE.concat(ALIASES_ENTER_SPACE)
	static public function setAliases(list:Array<KeyAlias>):Void {
		aliases = list != null ? list : [];
		heldBy = new IntMap();
	}

	static public function setInputLocked(value:Bool):Void {
		inputLocked = value;
		heldBy = new IntMap();
		if (value) {
			pendingOps = [];
		}
	}

	// virtual keys (touch controls): at the time of the last input taken (Natives.lastInputTime)
	static public function queueVirtualKeyDown(keyCode:Int):Void {
		queueKeyOp(keyCode, true, false, Natives.lastInputTime);
	}

	static public function queueVirtualKeyUp(keyCode:Int):Void {
		queueKeyOp(keyCode, false, false, Natives.lastInputTime);
	}

	static public function queueReplayKeyDown(keyCode:Int):Void {
		queueKeyOp(keyCode, true, true);
	}

	static public function queueReplayKeyUp(keyCode:Int):Void {
		queueKeyOp(keyCode, false, true);
	}

	static public function beginFrame():Int {
		ensureInitialized();
		justPressed.clear();
		frameKeyChanges = [];
		frameInputTime = -1;
		if (pendingOps.length == 0) {
			return 0;
		}

		var ops = pendingOps;
		pendingOps = [];
		var applied = 0;
		for (op in ops) {
			if (op.t > frameInputTime) {
				frameInputTime = op.t;
			}
			if (op.isDown) {
				var wasDown = keyState.exists(op.keyCode);
				setKeyDown(op.keyCode);
				if (!wasDown) {
					justPressed.set(op.keyCode, true);
					frameKeyChanges.push({keyCode: op.keyCode, isDown: true, t: op.t});
				}
			} else {
				var wasDown = keyState.exists(op.keyCode);
				setKeyUp(op.keyCode);
				if (wasDown) {
					frameKeyChanges.push({keyCode: op.keyCode, isDown: false, t: op.t});
				}
			}
			applied++;
		}
		return applied;
	}

	static public function getFrameKeyChanges():Array<{keyCode:Int, isDown:Bool, t:Float}> {
		ensureInitialized();
		return frameKeyChanges.copy();
	}

	// time (Event.timeStamp, ms) of the last key change applied on this frame, -1 when none (or a replay)
	static public function getFrameInputTime():Float {
		return frameInputTime;
	}

	static public function setKeyDown(keyCode:Int):Void {
		ensureInitialized();
		keyState.set(keyCode, true);
		lastDown = keyCode;
	}

	static public function setKeyUp(keyCode:Int):Void {
		ensureInitialized();
		keyState.remove(keyCode);
	}

	static public function clearState():Void {
		ensureInitialized();
		keyState = new IntMap();
		justPressed = new IntMap();
		frameKeyChanges = [];
		pendingOps = [];
		heldBy = new IntMap();
		lastDown = 0;
	}

	static public function isDown(keyCode:Int):Bool {
		ensureInitialized();
		return keyState.exists(keyCode);
	}

	static public function isJustDown(keyCode:Int):Bool {
		ensureInitialized();
		return justPressed.exists(keyCode);
	}

	static public function isArrowDown():Bool {
		return isDown(ARROW_RIGHT) || isDown(ARROW_UP) || isDown(ARROW_LEFT) || isDown(ARROW_DOWN);
	}

	static private inline function ensureInitialized():Void {
		if (!isInitialized) {
			init();
		}
	}

	static private inline function queueKeyOp(keyCode:Int, isDown:Bool, bypassLock:Bool = false, t:Float = -1):Void {
		ensureInitialized();
		if (inputLocked && !bypassLock) {
			return;
		}
		pendingOps.push({keyCode: keyCode, isDown: isDown, t: t});
	}
}
