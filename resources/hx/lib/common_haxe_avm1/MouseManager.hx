package common_haxe_avm1;

import haxe.ds.IntMap;
import pixi.core.Application;
import js.html.MouseEvent;
import common_haxe_avm1.kac.Natives;

private enum MouseOpType {
	BUTTON_DOWN;
	BUTTON_UP;
	POSITION;
}

private typedef MouseOp = {
	var type:MouseOpType;
	var button:Int;
	var x:Null<Int>;
	var y:Null<Int>;
	// time of the input (Event.timeStamp, ms), -1 for a replay
	var t:Float;
}

typedef MouseCoords = {
	var x:Int;
	var y:Int;
}

class MouseManager {
	static public inline var BUTTON_LEFT:Int = 0;
	static public inline var BUTTON_MIDDLE:Int = 1;
	static public inline var BUTTON_RIGHT:Int = 2;

	static private var app:Application;
	static private var isInitialized:Bool = false;
	static private var pendingCallbacks:Array<Void->Void> = [];
	static private var hasCapturedCoords:Bool = false;
	static private var capturedX:Int = 0;
	static private var capturedY:Int = 0;
	static private var interactionTrackingRegistered:Bool = false;
	static private var domTrackingRegistered:Bool = false;
	static private var buttonState:IntMap<Bool>;
	static private var justPressed:IntMap<Bool>;
	static private var justReleased:IntMap<Bool>;
	static private var frameButtonChanges:Array<{button:Int, isDown:Bool, t:Float}> = [];
	// time of the last input applied on this frame (-1: none), see kado.ReplayManager (phases)
	static private var frameInputTime:Float = -1;
	static private var polledX:Int = 0;
	static private var polledY:Int = 0;
	static private var hasPolledCoords:Bool = false;
	static private var pendingOps:Array<MouseOp> = [];
	static private var inputLocked:Bool = false;
	static private var bufferX:Int = 0;
	static private var bufferY:Int = 0;
	static private var _hasMouseMoved:Bool = false;

	static public function init(context:Application):Void {
		app = context;
		isInitialized = app != null;
		ensureStateInitialized();
		if (isInitialized) {
			registerInteractionTracking();
			registerDomTracking();
		}
	}

	static public function getMouseX():Int {
		return getX();
	}

	static public function getMouseY():Int {
		return getY();
	}

	// never negative: the replay records no negative position (kado.ReplayManager.captureFrameMousePosition), the pointer
	// that leaves the canvas on the left or the top (pointerleave, pointer capture) is read at 0 by the live game too
	static public function getX():Int {
		var x = hasPolledCoords ? polledX : getLiveX();
		return x < 0 ? 0 : x;
	}

	static public function getY():Int {
		var y = hasPolledCoords ? polledY : getLiveY();
		return y < 0 ? 0 : y;
	}

	// replay: the position of the player when the game began (its first recorded one), read by a game before its first
	// frame (the live game reads the pointer then)
	static public function presetPosition(x:Int, y:Int):Void {
		ensureStateInitialized();
		hasPolledCoords = true;
		polledX = x;
		polledY = y;
	}

	static public function isButtonDown(button:Int):Bool {
		ensureStateInitialized();
		return buttonState.exists(button);
	}

	static public function isButtonJustPressed(button:Int):Bool {
		ensureStateInitialized();
		return justPressed.exists(button);
	}

	static public function isButtonJustReleased(button:Int):Bool {
		ensureStateInitialized();
		return justReleased.exists(button);
	}

	static public function setInputLocked(value:Bool):Void {
		ensureStateInitialized();
		inputLocked = value;
		if (value) {
			pendingOps = [];
		}
	}

	static public function clearState():Void {
		ensureStateInitialized();
		buttonState = new IntMap();
		justPressed = new IntMap();
		justReleased = new IntMap();
		frameButtonChanges = [];
		pendingOps = [];
		pendingCallbacks = [];
		hasPolledCoords = false;
		polledX = 0;
		polledY = 0;
		hasCapturedCoords = false;
		capturedX = 0;
		capturedY = 0;
		interactionTrackingRegistered = false;
		bufferX = 0;
		bufferY = 0;
		_hasMouseMoved = false;
	}

	static public function setPosition(x:Int, y:Int):Void {
		queueMouseOp({
			type: POSITION,
			button: -1,
			x: x,
			y: y,
			t: -1
		}, true);
	}

	static public function setButtonDown(button:Int):Void {
		queueMouseOp({
			type: BUTTON_DOWN,
			button: button,
			x: null,
			y: null,
			t: -1
		}, true);
	}

	static public function setButtonUp(button:Int):Void {
		queueMouseOp({
			type: BUTTON_UP,
			button: button,
			x: null,
			y: null,
			t: -1
		}, true);
	}

	// virtual inputs (touch controls): at the time of the last input taken (Natives.lastInputTime)
	static public function queueVirtualPointerMove(x:Int, y:Int):Void {
		queueMouseOp({
			type: POSITION,
			button: -1,
			x: x,
			y: y,
			t: Natives.lastInputTime
		});
	}

	static public function queueVirtualPointerDown(button:Int, x:Int, y:Int):Void {
		queueMouseOp({
			type: BUTTON_DOWN,
			button: button,
			x: x,
			y: y,
			t: Natives.lastInputTime
		});
	}

	static public function queueVirtualPointerUp(button:Int, x:Int, y:Int):Void {
		queueMouseOp({
			type: BUTTON_UP,
			button: button,
			x: x,
			y: y,
			t: Natives.lastInputTime
		});
	}

	static public function captureInputEvent(event:Dynamic):Void {
		// (PIXI interaction event: the DOM event that made it must come from the player)
		var data:Dynamic = event != null ? Reflect.field(event, "data") : null;
		var original:Dynamic = data != null ? Reflect.field(data, "originalEvent") : null;
		if (original != null && !Natives.isTrustedEvent(original)) {
			return;
		}
		var x = extractCoord(event, true);
		var y = extractCoord(event, false);
		if (x == null || y == null) {
			return;
		}

		hasCapturedCoords = true;
		capturedX = x;
		capturedY = y;
	}

	static public function getMouseCoords():MouseCoords {
		return {
			x: getX(),
			y: getY()
		};
	}

	static public function getApp():Application {
		return app;
	}

	static public function queueInputCallback(callback:Void->Void):Void {
		if (callback == null) {
			return;
		}
		pendingCallbacks.push(callback);
	}

	static public function beginFrame():Int {
		ensureStateInitialized();
		justPressed.clear();
		justReleased.clear();
		frameButtonChanges = [];
		frameInputTime = -1;
		var applied = 0;
		_hasMouseMoved = false;

		if (pendingOps.length > 0) {
			var ops = pendingOps;
			pendingOps = [];
			for (op in ops) {
				applyCoords(op.x, op.y);
				if (op.t > frameInputTime) {
					frameInputTime = op.t;
				}
				switch (op.type) {
					case POSITION:
						_hasMouseMoved = polledX != bufferX || polledY != bufferY;
						bufferX = op.x;
						bufferY = op.y;
					case BUTTON_DOWN:
						var wasDown = buttonState.exists(op.button);
						buttonState.set(op.button, true);
						if (!wasDown) {
							justPressed.set(op.button, true);
							frameButtonChanges.push({button: op.button, isDown: true, t: op.t});
						}
					case BUTTON_UP:
						var wasDown = buttonState.exists(op.button);
						buttonState.remove(op.button);
						if (wasDown) {
							justReleased.set(op.button, true);
							frameButtonChanges.push({button: op.button, isDown: false, t: op.t});
						}
				}
				applied++;
			}
		}

		if (pendingCallbacks.length == 0) {
			return applied;
		}

		var callbacks = pendingCallbacks;
		pendingCallbacks = [];
		for (callback in callbacks) {
			callback();
			applied++;
		}
		return applied;
	}

	static public function getFrameButtonChanges():Array<{button:Int, isDown:Bool, t:Float}> {
		ensureStateInitialized();
		return frameButtonChanges.copy();
	}

	// time (Event.timeStamp, ms) of the last input applied on this frame, -1 when none (or a replay)
	static public function getFrameInputTime():Float {
		return frameInputTime;
	}

	// time of the press / release of a button applied on this frame, -1 when none
	static public function getFrameButtonTime(button:Int):Float {
		ensureStateInitialized();
		for (change in frameButtonChanges) {
			if (change.button == button) {
				return change.t;
			}
		}
		return -1;
	}

	static private function registerInteractionTracking():Void {
		if (interactionTrackingRegistered) {
			return;
		}

		var interaction = app.renderer.plugins.interaction;
		if (interaction == null || !Reflect.hasField(interaction, "on")) {
			return;
		}

		for (eventName in ["pointermove", "mousemove", "touchstart", "touchmove", "touchend", "touchcancel"]) {
			untyped interaction.on(eventName, captureInputEvent);
		}
		interactionTrackingRegistered = true;
	}

	static private function registerDomTracking():Void {
		if (domTrackingRegistered || app == null || app.view == null) {
			return;
		}

		// (with the addEventListener of the page: a script cannot wrap the events given to the game)
		Natives.listen(app.view, "pointermove", onPointerMove);
		Natives.listen(app.view, "pointerdown", onPointerDown);
		Natives.listen(app.view, "pointerup", onPointerUp);
		Natives.listen(app.view, "pointerleave", onPointerLeaveOrCancel);
		Natives.listen(app.view, "pointercancel", onPointerLeaveOrCancel);
		domTrackingRegistered = true;
	}

	static private function onPointerMove(event:MouseEvent):Void {
		if (inputLocked) {
			return;
		}
		var t = Natives.takeInput(event);
		if (Math.isNaN(t)) {
			return;
		}
		var coords = extractCanvasCoords(event);
		if (coords == null) {
			return;
		}
		setCapturedCoords(coords.x, coords.y);
		var x = coords.x;
		var y = coords.y;
		if (x == null || y == null) {
			return;
		}
		queueMouseOp({
			type: POSITION,
			button: -1,
			x: x,
			y: y,
			t: t
		});
	}

	static private function onPointerDown(event:MouseEvent):Void {
		if (inputLocked) {
			return;
		}
		var t = Natives.takeInput(event);
		if (Math.isNaN(t)) {
			return;
		}
		var coords = extractCanvasCoords(event);
		var x:Null<Int> = null;
		var y:Null<Int> = null;
		if (coords != null) {
			x = coords.x;
			y = coords.y;
			setCapturedCoords(coords.x, coords.y);
		}
		queueMouseOp({
			type: BUTTON_DOWN,
			button: event.button,
			x: x,
			y: y,
			t: t
		});
	}

	static private function onPointerUp(event:MouseEvent):Void {
		if (inputLocked) {
			return;
		}
		var t = Natives.takeInput(event);
		if (Math.isNaN(t)) {
			return;
		}
		var coords = extractCanvasCoords(event);
		var x:Null<Int> = null;
		var y:Null<Int> = null;
		if (coords != null) {
			x = coords.x;
			y = coords.y;
			setCapturedCoords(coords.x, coords.y);
		}
		queueMouseOp({
			type: BUTTON_UP,
			button: event.button,
			x: x,
			y: y,
			t: t
		});
	}

	static private function onPointerLeaveOrCancel(event:MouseEvent):Void {
		if (inputLocked) {
			return;
		}
		var t = Natives.takeInput(event);
		if (Math.isNaN(t)) {
			return;
		}
		var coords = extractCanvasCoords(event);
		var x:Null<Int> = null;
		var y:Null<Int> = null;
		if (coords != null) {
			x = coords.x;
			y = coords.y;
			setCapturedCoords(coords.x, coords.y);
		}
		for (button in 0...5) {
			queueMouseOp({
				type: BUTTON_UP,
				button: button,
				x: x,
				y: y,
				t: t
			});
		}
	}

	static private inline function setCapturedCoords(x:Int, y:Int):Void {
		hasCapturedCoords = true;
		capturedX = x;
		capturedY = y;
	}

	static private function extractCanvasCoords(event:MouseEvent):Null<{x:Int, y:Int}> {
		if (event == null || app == null || app.view == null) {
			return null;
		}

		var rect = app.view.getBoundingClientRect();
		if (rect == null || rect.width == 0 || rect.height == 0) {
			return null;
		}

		var localX = (event.clientX - rect.left) * (app.screen.width / rect.width);
		var localY = (event.clientY - rect.top) * (app.screen.height / rect.height);
		return {x: Std.int(localX), y: Std.int(localY)};
	}

	static private inline function applyCoords(x:Null<Int>, y:Null<Int>):Void {
		if (x != null && y != null) {
			hasPolledCoords = true;
			polledX = x;
			polledY = y;
		}
	}

	static private inline function queueMouseOp(op:MouseOp, bypassLock:Bool = false):Void {
		ensureStateInitialized();
		if (inputLocked && !bypassLock) {
			return;
		}
		pendingOps.push(op);
	}

	static private inline function ensureStateInitialized():Void {
		if (buttonState == null) {
			buttonState = new IntMap();
		}
		if (justPressed == null) {
			justPressed = new IntMap();
		}
		if (justReleased == null) {
			justReleased = new IntMap();
		}
		if (frameButtonChanges == null) {
			frameButtonChanges = [];
		}
		if (pendingOps == null) {
			pendingOps = [];
		}
		if (pendingCallbacks == null) {
			pendingCallbacks = [];
		}
	}

	static private inline function getLiveX():Int {
		if (!isInitialized) {
			return 0;
		}
		if (hasCapturedCoords) {
			return capturedX;
		}
		return Std.int(app.renderer.plugins.interaction.mouse.global.x);
	}

	static private inline function getLiveY():Int {
		if (!isInitialized) {
			return 0;
		}
		if (hasCapturedCoords) {
			return capturedY;
		}
		return Std.int(app.renderer.plugins.interaction.mouse.global.y);
	}

	static private function extractCoord(event:Dynamic, forX:Bool):Null<Int> {
		if (event == null) {
			return null;
		}

		var data = Reflect.field(event, "data");
		if (data != null) {
			var global = Reflect.field(data, "global");
			if (global != null) {
				var value = Reflect.field(global, forX ? "x" : "y");
				if (value != null) {
					return Std.int(value);
				}
			}
		}

		var global = Reflect.field(event, "global");
		if (global != null) {
			var value = Reflect.field(global, forX ? "x" : "y");
			if (value != null) {
				return Std.int(value);
			}
		}

		var src = Reflect.field(event, "changedTouches");
		if (src == null) {
			src = Reflect.field(event, "touches");
		}
		if (src != null && Reflect.hasField(src, "length") && src.length > 0) {
			var touch = src[0];
			var touchValue = Reflect.field(touch, forX ? "clientX" : "clientY");
			if (touchValue != null) {
				return Std.int(touchValue);
			}
		}

		var clientValue = Reflect.field(event, forX ? "clientX" : "clientY");
		if (clientValue != null) {
			return Std.int(clientValue);
		}

		return null;
	}

	static public function hasMouseMoved():Bool {
		return _hasMouseMoved;
	}
}
