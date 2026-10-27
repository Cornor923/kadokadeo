package kado;

import haxe.crypto.Base64;
import haxe.ds.IntMap;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.UInt16Array;
import js.lib.Uint8Array;

typedef ReplayInitParams = {
	var recordedKeys:UInt16Array;
	@:optional var recordInputs:Bool;
	@:optional var recordEvents:Bool;
	@:optional var recordMousePosition:Bool;
	@:optional var recordedMouseButtons:UInt16Array;
}

typedef ReplayEvent = Dynamic;

typedef ReplayInputEvent = {
	var keyCode:Int;
	var isDown:Bool;
	// version 4: time of the change in its frame (see phaseOf)
	@:optional var phase:Int;
}

typedef ReplayFrameRecord = {
	var events:Array<ReplayEvent>;
	var inputs:Array<ReplayInputEvent>;
	@:optional var mousePosition:Null<{x:Int, y:Int}>;
	@:optional var mouseButtons:Array<{button:Int, isDown:Bool, ?phase:Int}>;
	// version 4: by event, its phase and its bytes in the replay (written as recorded: the hash of the stir is the same
	// in the game and in its replay, even if the game changes the event object later)
	@:optional var eventPhases:Array<Int>;
	@:optional var eventBytes:Array<Bytes>;
}

private typedef PendingEvent = {
	var event:ReplayEvent;
	var phase:Int;
	var bytes:Bytes;
}

// Binary replay: "KADO", version, flags, init params (recorded keys / mouse buttons), then one section per kind of
// record, and the number of frames of the game ("LEN" trailer, ignored by older readers). Deflated, then base64.
// Version 3 (written since 2026-10) packs the sections column by column: all the frame gaps, then all the values
// (deflate finds the repetitions of each column), keys and buttons written as their index in the init params, the
// mouse position as its move (minus the move of the frame before when the mouse moved on consecutive frames:
// smooth moves give numbers close to 0). Mouse games give replays about 2 times smaller than with version 2.
// Versions 1 and 2 (one group per frame: gap, count, values) are still read.
// Version 4 (2026-10, anti cheat) adds the PHASES section (flag INPUT_PHASES, games with the RNG stir): one byte by input
// change, event and mouse button change (in the order of their sections): the moment of the frame (quarter of ms) the
// player did it, read from the DOM event (Event.timeStamp). The gameplay draws are stirred by it (see beginFrame): the
// coming pieces depend on a time no player controls, so they can't be predicted before the input.
// Version 5 (2026-10): the game computed Math.sin, Math.pow... in plain JavaScript (kado.ExactMath), the same on every
// browser; the replays before it are played with the functions of the browser, as they were recorded.
class ReplayManager {
	public static inline var REPLAY_VERSION:Int = 5;
	// first version recorded with kado.ExactMath
	private static inline var EXACT_MATH_VERSION:Int = 5;
	private static inline var MAGIC_HEADER:String = "KADO";
	// optional trailer (ignored by older readers): number of frames of the game
	private static inline var MAGIC_LENGTH:String = "LEN";
	private static inline var FLAG_INPUTS:Int = 1;
	private static inline var FLAG_EVENTS:Int = 2;
	private static inline var FLAG_MOUSE_POSITION:Int = 4;
	private static inline var FLAG_MOUSE_BUTTONS:Int = 8;
	// version 3: the inputs / buttons are written as their code, not as their index in the init params
	private static inline var FLAG_KEY_CODES:Int = 16;
	private static inline var FLAG_BUTTON_CODES:Int = 32;
	// the gameplay draws of the game are stirred by the frames and the inputs (kado.Seed.stir)
	private static inline var FLAG_RNG_STIR:Int = 64;
	// version 4: the PHASES section is written (see phaseOf); the frame signature also depends on the events
	private static inline var FLAG_INPUT_PHASES:Int = 128;
	// phase of a change without time (replay, state resync, event made by the game outside of an input)
	public static inline var PHASE_NONE:Int = 125;
	// phase of an event recorded for a frame already played: not in the frame signature (it would differ in the replay)
	public static inline var PHASE_EXCLUDED:Int = 127;
	private static inline var EVENT_ENCODING_PACKED_GRID:Int = 0;
	private static inline var EVENT_ENCODING_SERIALIZED:Int = 1;
	private static inline var DEFLATE_LEVEL:Int = 9;

	private var replayData:Bytes;
	private var currentFrame:Int = 0;
	private var totalFrames:Int = -1;
	private var lastRecordedFrame:Int = 0;
	private var isRecording:Bool = false;
	private var isPlaying:Bool = false;
	private var params:ReplayInitParams;

	// recording: records by frame
	private var frameRecords:IntMap<ReplayFrameRecord>;
	// playing: the frames that have a record, in order, and the next one to apply
	private var playFrames:Array<Int>;
	private var playRecords:Array<ReplayFrameRecord>;
	private var playCursor:Int = 0;
	// playing: last mouse position applied
	private var playMouseX:Int = 0;
	private var playMouseY:Int = 0;
	private var hasPlayMouse:Bool = false;

	private var pendingEvents:Array<PendingEvent>;
	private var frameEvents:Array<ReplayEvent>;
	private var trackedKeys:IntMap<Bool>;
	private var trackedKeyList:Array<Int>;
	private var trackAllKeys:Bool = true;
	private var trackedMouseButtons:IntMap<Bool>;
	private var hasTrackedMouseButtons:Bool = false;
	private var recordedKeyStates:IntMap<Bool>;
	private var shouldRecordInputs:Bool = true;
	private var shouldRecordEvents:Bool = true;
	private var shouldRecordMousePosition:Bool = false;
	private var lastRecordedMouseX:Int = 0;
	private var lastRecordedMouseY:Int = 0;
	private var hasLastRecordedMouse:Bool = false;
	private var rngStir:Bool = false;
	// inputs and mouse buttons changed on the current frame (recorded or replayed): see getFrameSignature
	private var frameSignature:Int = 0;
	// version 4 (FLAG_INPUT_PHASES): the frame signature has the phases, the mouse position and the events of the frame
	// before (an event is recorded by the game during its frame, after the stir of the frame)
	private var phasesEnabled:Bool = false;
	// playing: hash of the events of the frame before
	private var carriedEventSig:Int = 0;
	// between beginFrame and endFrame
	private var inFrame:Bool = false;
	// the game computes its Math functions with kado.ExactMath: a live game, or a replay recorded with it
	private var exactMath:Bool = true;

	public function new(?replayData:String = null) {
		this.replayData = parseReplayString(replayData);
		this.frameRecords = new IntMap();
		this.playFrames = [];
		this.playRecords = [];
		this.pendingEvents = [];
		this.frameEvents = [];
		this.recordedKeyStates = new IntMap();
		this.params = defaultParams();
		refreshTrackedKeys();
		refreshTrackedMouseButtons();

		if (this.replayData != null) {
			try {
				decodeBinaryData(this.replayData);
			} catch (e:Dynamic) {
				trace("Invalid replay data: " + e);
				this.replayData = null;
				this.playFrames = [];
				this.playRecords = [];
				this.exactMath = true;
			}
		}
		ExactMath.setEnabled(exactMath);
	}

	public function init(params:ReplayInitParams):Void {
		// a replay keeps the params it was recorded with
		if (this.replayData != null) {
			return;
		}
		this.params = normalizeParams(params);
		refreshTrackedKeys();
		refreshTrackedMouseButtons();
		this.shouldRecordInputs = this.params.recordInputs;
		this.shouldRecordEvents = this.params.recordEvents;
		this.shouldRecordMousePosition = this.params.recordMousePosition;
	}

	public function start():Void {
		if (this.isRecording || this.isPlaying) {
			trace("ReplayManager is already started");
			return;
		}

		pendingEvents = [];
		frameEvents = [];
		recordedKeyStates = new IntMap();
		hasLastRecordedMouse = false;
		currentFrame = 0;
		playCursor = 0;
		hasPlayMouse = false;
		carriedEventSig = 0;
		inFrame = false;

		if (this.replayData != null) {
			this.isPlaying = true;
			common_haxe_avm1.KeyboardManager.setInputLocked(true);
			common_haxe_avm1.MouseManager.setInputLocked(true);
			common_haxe_avm1.KeyboardManager.clearState();
			common_haxe_avm1.MouseManager.clearState();
			// a game that reads the mouse when it is built (Alphabounce) gets the position of the player at frame 0, the
			// one its live game read then, not the pointer of the viewer
			if (playFrames.length > 0 && playFrames[0] == 0 && playRecords[0].mousePosition != null) {
				common_haxe_avm1.MouseManager.presetPosition(playRecords[0].mousePosition.x, playRecords[0].mousePosition.y);
			}
		} else {
			this.isRecording = true;
			frameRecords = new IntMap();
			common_haxe_avm1.KeyboardManager.setInputLocked(false);
			common_haxe_avm1.MouseManager.setInputLocked(false);
		}
	}

	public function stop():Void {
		this.inFrame = false;
		this.isRecording = false;
		this.isPlaying = false;
		common_haxe_avm1.KeyboardManager.setInputLocked(false);
		common_haxe_avm1.MouseManager.setInputLocked(false);
	}

	public inline function isPlayingReplay():Bool {
		return this.isPlaying;
	}

	public inline function isRecordingReplay():Bool {
		return this.isRecording;
	}

	public inline function getCurrentFrame():Int {
		return currentFrame;
	}

	// recording: written in the replay. Playing: read from the replay (false for the replays recorded before it)
	// The stirred games also record the phases of the inputs (version 4), the daily game neither.
	public function setRngStir(enabled:Bool):Void {
		if (this.replayData == null) {
			rngStir = enabled;
			phasesEnabled = enabled;
		}
	}

	public inline function hasInputPhases():Bool {
		return phasesEnabled;
	}

	public inline function hasRngStir():Bool {
		return rngStir;
	}

	// hash of the inputs and mouse buttons changed on the current frame, after beginFrame: built from the record of the
	// frame, so the live game and its replay give the same one (the order of the changes in the frame doesn't matter)
	public inline function getFrameSignature():Int {
		return frameSignature;
	}

	// number of frames of the replay being played: -1 if the replay does not say it (older replays)
	public inline function getTotalFrames():Int {
		return totalFrames;
	}

	// last frame with a recorded input or event (the game may go on a bit after it)
	public inline function getLastRecordedFrame():Int {
		return lastRecordedFrame;
	}

	// keys pressed at least once in the replay being played (in the order of the recorded keys)
	public function getReplayKeys():Array<Int> {
		var used = new IntMap<Bool>();
		var order:Array<Int> = [];
		for (record in playRecords) {
			for (input in record.inputs) {
				if (!used.exists(input.keyCode)) {
					used.set(input.keyCode, true);
					order.push(input.keyCode);
				}
			}
		}
		var keys = [for (k in trackedKeyList) if (used.exists(k)) k];
		for (k in order) {
			if (keys.indexOf(k) < 0) {
				keys.push(k);
			}
		}
		return keys;
	}

	// mouse buttons pressed at least once in the replay being played
	public function getReplayMouseButtons():Array<Int> {
		var buttons:Array<Int> = [];
		for (record in playRecords) {
			if (record.mouseButtons != null) {
				for (change in record.mouseButtons) {
					if (buttons.indexOf(change.button) < 0) {
						buttons.push(change.button);
					}
				}
			}
		}
		buttons.sort((a, b) -> a - b);
		return buttons;
	}

	// events of the replay being played with their frame, in order: a game can look ahead (e.g. Hypercube moves the
	// piece in hand from an event to the next one)
	public function getReplayEvents():Array<{frame:Int, event:ReplayEvent}> {
		var list = [];
		for (i in 0...playRecords.length) {
			for (event in playRecords[i].events) {
				list.push({frame: playFrames[i], event: event});
			}
		}
		return list;
	}

	// mouse position of the player in the replay being played (game pixels), null before the first one
	public function getReplayMouse():Null<{x:Int, y:Int}> {
		return hasPlayMouse ? {x: playMouseX, y: playMouseY} : null;
	}

	public function beginFrame():Void {
		if (!this.isRecording && !this.isPlaying) {
			return;
		}

		if (frameEvents.length > 0) {
			frameEvents = [];
		}
		frameSignature = 0;
		inFrame = true;

		if (this.isPlaying) {
			var record = applyFrame(currentFrame);
			if (phasesEnabled) {
				frameSignature = signatureV2(record) ^ carriedEventSig;
				carriedEventSig = eventsSignature(record);
			} else {
				frameSignature = signatureOf(record);
			}
			common_haxe_avm1.KeyboardManager.beginFrame();
			common_haxe_avm1.MouseManager.beginFrame();
			return;
		}

		common_haxe_avm1.KeyboardManager.beginFrame();
		common_haxe_avm1.MouseManager.beginFrame();

		if (this.shouldRecordInputs) {
			captureFrameInputs();
		}

		if (this.shouldRecordMousePosition) {
			captureFrameMousePosition();
		}

		if (hasTrackedMouseButtons) {
			captureFrameMouseButtons();
		}

		if (phasesEnabled) {
			frameSignature = signatureV2(frameRecords.get(currentFrame)) ^ eventsSignature(frameRecords.get(currentFrame - 1));
		} else {
			frameSignature = signatureOf(frameRecords.get(currentFrame));
		}

		if (this.shouldRecordEvents && pendingEvents.length > 0) {
			var record = getOrCreateFrameRecord(currentFrame);
			for (pending in pendingEvents) {
				addEvent(record, pending.event, pending.phase, pending.bytes);
			}
			pendingEvents = [];
		}
	}

	public function endFrame():Void {
		if (!this.isRecording && !this.isPlaying) {
			return;
		}
		inFrame = false;
		currentFrame++;
	}

	// frameIndex: frame of the event (default: the next frame begun). phase: moment of the input that made it (see
	// phaseOf; PHASE_NONE: an event without a moment, a continuous aim for example; default: the last input of the frame)
	public function recordEvent(event:ReplayEvent, ?frameIndex:Int, ?phase:Int):Void {
		if (!this.isRecording || !this.shouldRecordEvents || event == null) {
			return;
		}

		var bytes = encodeEvent(event);
		if (frameIndex != null && Std.int(frameIndex) < currentFrame) {
			phase = PHASE_EXCLUDED;
		} else if (phase == null || phase < 0 || phase > PHASE_NONE) {
			phase = currentInputPhase();
		}

		if (frameIndex == null) {
			pendingEvents.push({event: event, phase: phase, bytes: bytes});
			return;
		}

		var frame = Std.int(frameIndex);
		var record = getOrCreateFrameRecord(frame);
		addEvent(record, event, phase, bytes);
	}

	static function addEvent(record:ReplayFrameRecord, event:ReplayEvent, phase:Int, bytes:Bytes):Void {
		record.events.push(event);
		if (record.eventPhases == null) {
			record.eventPhases = [];
			record.eventBytes = [];
		}
		record.eventPhases.push(phase);
		record.eventBytes.push(bytes);
	}

	// ANTI CHEAT: moment of an input in the frames of the game (Event.timeStamp modulo the 31.25 ms of a frame), in
	// quarters of ms: 0..124. No player can choose it, it is recorded (the replay never reads a clock).
	public static function phaseOf(t:Float):Int {
		if (Math.isNaN(t) || t < 0) {
			return PHASE_NONE;
		}
		var p = Std.int((t % FixedFramerate.STEP) * 4);
		return p < 0 ? 0 : p >= PHASE_NONE ? PHASE_NONE - 1 : p;
	}

	// phase of the last input of the frame being played (outside of a frame: of the last input taken)
	function currentInputPhase():Int {
		if (!inFrame) {
			return phaseOf(common_haxe_avm1.kac.Natives.lastInputTime);
		}
		return phaseOf(Math.max(common_haxe_avm1.MouseManager.getFrameInputTime(), common_haxe_avm1.KeyboardManager.getFrameInputTime()));
	}

	public function recordInput(keyCode:Int, isDown:Bool, ?frameIndex:Int, ?phase:Int):Void {
		if (!this.isRecording || !this.shouldRecordInputs || !shouldTrackKey(keyCode)) {
			return;
		}

		var previous = recordedKeyStates.exists(keyCode);
		if (previous == isDown) {
			return;
		}

		if (isDown) {
			recordedKeyStates.set(keyCode, true);
		} else {
			recordedKeyStates.remove(keyCode);
		}

		var frame = frameIndex == null ? currentFrame : frameIndex;
		var record = getOrCreateFrameRecord(frame);
		record.inputs.push({keyCode: keyCode, isDown: isDown, phase: phase == null ? PHASE_NONE : phase});
	}

	public function consumeEvents():Array<ReplayEvent> {
		if (frameEvents.length == 0) {
			return [];
		}

		var output = frameEvents;
		frameEvents = [];
		return output;
	}

	// bytes of an event in the replay (EVENTS section)
	function encodeEvent(event:ReplayEvent):Bytes {
		var output = new BytesOutput();
		writeEvent(output, event);
		return output.getBytes();
	}

	public function encodeBinaryData():Bytes {
		var output = new BytesOutput();
		output.writeString(MAGIC_HEADER);
		output.writeByte(REPLAY_VERSION);

		var frames = [for (frameIndex in frameRecords.keys()) frameIndex];
		frames.sort((a, b) -> a - b);
		var records = [for (frameIndex in frames) frameRecords.get(frameIndex)];

		// a key or button missing from the init params (none given: every key is recorded) is written as its code
		var keyIndex = indexTable(params.recordedKeys);
		var buttonIndex = indexTable(params.recordedMouseButtons);
		for (record in records) {
			for (input in record.inputs) {
				if (keyIndex != null && !keyIndex.exists(input.keyCode)) {
					keyIndex = null;
				}
			}
			if (record.mouseButtons != null) {
				for (change in record.mouseButtons) {
					if (buttonIndex != null && !buttonIndex.exists(change.button)) {
						buttonIndex = null;
					}
				}
			}
		}

		var flags = 0;
		if (params.recordInputs)
			flags |= FLAG_INPUTS;
		if (params.recordEvents)
			flags |= FLAG_EVENTS;
		if (params.recordMousePosition)
			flags |= FLAG_MOUSE_POSITION;
		if (params.recordedMouseButtons.length > 0)
			flags |= FLAG_MOUSE_BUTTONS;
		if (keyIndex == null)
			flags |= FLAG_KEY_CODES;
		if (buttonIndex == null)
			flags |= FLAG_BUTTON_CODES;
		if (rngStir)
			flags |= FLAG_RNG_STIR;
		if (phasesEnabled)
			flags |= FLAG_INPUT_PHASES;
		output.writeByte(flags);

		writeInitParams(output, flags);
		if ((flags & FLAG_INPUTS) != 0) {
			writeInputRecords(output, frames, records, keyIndex);
		}
		if ((flags & FLAG_EVENTS) != 0) {
			writeEventRecords(output, frames, records);
		}
		if ((flags & FLAG_MOUSE_POSITION) != 0) {
			writeMousePositionRecords(output, frames, records);
		}
		if ((flags & FLAG_MOUSE_BUTTONS) != 0) {
			writeMouseButtonRecords(output, frames, records, buttonIndex);
		}
		if ((flags & FLAG_INPUT_PHASES) != 0) {
			writePhaseRecords(output, records, flags);
		}
		output.writeString(MAGIC_LENGTH);
		writeVarUInt(output, currentFrame);
		return output.getBytes();
	}

	public function encodeReplayString():String {
		if (replayData != null) {
			return null;
		}
		var compressed = externs.Pako.deflate(bytesToUint8Array(encodeBinaryData()), {level: DEFLATE_LEVEL});
		return Base64.encode(uint8ArrayToBytes(compressed));
	}

	// the record of the frame (null: nothing recorded on it)
	private function applyFrame(frameIndex:Int):Null<ReplayFrameRecord> {
		while (playCursor < playFrames.length && playFrames[playCursor] < frameIndex) {
			playCursor++;
		}
		if (playCursor >= playFrames.length || playFrames[playCursor] != frameIndex) {
			return null;
		}
		var record = playRecords[playCursor++];

		if (record.mousePosition != null) {
			playMouseX = record.mousePosition.x;
			playMouseY = record.mousePosition.y;
			hasPlayMouse = true;
			common_haxe_avm1.MouseManager.setPosition(playMouseX, playMouseY);
		}

		if (record.mouseButtons != null) {
			for (change in record.mouseButtons) {
				if (change.isDown) {
					common_haxe_avm1.MouseManager.setButtonDown(change.button);
				} else {
					common_haxe_avm1.MouseManager.setButtonUp(change.button);
				}
			}
		}

		for (input in record.inputs) {
			if (input.isDown) {
				common_haxe_avm1.KeyboardManager.queueReplayKeyDown(input.keyCode);
			} else {
				common_haxe_avm1.KeyboardManager.queueReplayKeyUp(input.keyCode);
			}
		}

		if (record.events.length > 0) {
			if (frameEvents.length == 0) {
				frameEvents = [];
			}
			for (event in record.events) {
				frameEvents.push(event);
			}
		}
		return record;
	}

	static function signatureOf(record:Null<ReplayFrameRecord>):Int {
		if (record == null) {
			return 0;
		}
		var signature = 0;
		for (input in record.inputs) {
			signature ^= hashChange((input.keyCode << 1) | (input.isDown ? 1 : 0));
		}
		if (record.mouseButtons != null) {
			for (change in record.mouseButtons) {
				signature ^= hashChange(0x40000 | (change.button << 1) | (change.isDown ? 1 : 0));
			}
		}
		return signature;
	}

	static inline function hashChange(x:Int):Int {
		x = (x + 1) * 0x2C1B3;
		x ^= x << 13;
		x ^= x >>> 17;
		x ^= x << 5;
		return x;
	}

	// version 4: the changes of the frame with their phase, and the mouse position (games that record it)
	static function signatureV2(record:Null<ReplayFrameRecord>):Int {
		if (record == null) {
			return 0;
		}
		var signature = 0;
		for (input in record.inputs) {
			signature ^= hashPhase(1, (input.keyCode << 1) | (input.isDown ? 1 : 0), phaseOrNone(input.phase));
		}
		if (record.mouseButtons != null) {
			for (change in record.mouseButtons) {
				signature ^= hashPhase(2, (change.button << 1) | (change.isDown ? 1 : 0), phaseOrNone(change.phase));
			}
		}
		if (record.mousePosition != null) {
			signature ^= hashPhase(3, record.mousePosition.x, record.mousePosition.y);
		}
		return signature;
	}

	// version 4: the events of a frame (their bytes in the replay) with their phase
	static function eventsSignature(record:Null<ReplayFrameRecord>):Int {
		if (record == null || record.eventBytes == null) {
			return 0;
		}
		var signature = 0;
		for (i in 0...record.eventBytes.length) {
			var phase = record.eventPhases != null && i < record.eventPhases.length ? record.eventPhases[i] : PHASE_NONE;
			if (phase == PHASE_EXCLUDED) {
				continue;
			}
			signature ^= hashPhase(4, fnv1a(record.eventBytes[i]), phase);
		}
		return signature;
	}

	static inline function phaseOrNone(phase:Null<Int>):Int {
		return phase == null ? PHASE_NONE : phase;
	}

	// 32 bit operations only (Math.imul): the same in every browser
	static inline function imul(a:Int, b:Int):Int {
		return js.Syntax.code("Math.imul({0}, {1})", a, b);
	}

	static function hashPhase(kind:Int, a:Int, b:Int):Int {
		var x = imul(a, 0x2C1B3C6D) ^ imul(b + 1, 0x297A2D39) ^ imul(kind, 0x7FEB352D);
		x ^= x << 13;
		x ^= x >>> 17;
		x ^= x << 5;
		return x;
	}

	static function fnv1a(bytes:Bytes):Int {
		var h = 0x811C9DC5;
		for (i in 0...bytes.length) {
			h = imul(h ^ bytes.get(i), 0x01000193);
		}
		return h;
	}

	private function captureFrameInputs():Void {
		for (change in common_haxe_avm1.KeyboardManager.getFrameKeyChanges()) {
			if (!shouldTrackKey(change.keyCode)) {
				continue;
			}

			recordInput(change.keyCode, change.isDown, currentFrame, phaseOf(change.t));
		}

		for (keyCode in trackedKeyList) {
			var isDown = common_haxe_avm1.KeyboardManager.isDown(keyCode);
			if (recordedKeyStates.exists(keyCode) != isDown) {
				recordInput(keyCode, isDown, currentFrame, PHASE_NONE);
			}
		}
	}

	private function captureFrameMousePosition():Void {
		var mouseX = Std.int(common_haxe_avm1.MouseManager.getX());
		var mouseY = Std.int(common_haxe_avm1.MouseManager.getY());
		if (mouseX < 0) {
			mouseX = 0;
		}
		if (mouseY < 0) {
			mouseY = 0;
		}
		if (hasLastRecordedMouse && mouseX == lastRecordedMouseX && mouseY == lastRecordedMouseY) {
			return;
		}

		var record = getOrCreateFrameRecord(currentFrame);
		record.mousePosition = {x: mouseX, y: mouseY};
		lastRecordedMouseX = mouseX;
		lastRecordedMouseY = mouseY;
		hasLastRecordedMouse = true;
	}

	private function captureFrameMouseButtons():Void {
		var record:ReplayFrameRecord = null;
		for (change in common_haxe_avm1.MouseManager.getFrameButtonChanges()) {
			if (!trackedMouseButtons.exists(change.button)) {
				continue;
			}

			if (record == null) {
				record = getOrCreateFrameRecord(currentFrame);
				if (record.mouseButtons == null) {
					record.mouseButtons = [];
				}
			}
			record.mouseButtons.push({button: change.button, isDown: change.isDown, phase: phaseOf(change.t)});
		}
	}

	private function getOrCreateFrameRecord(frameIndex:Int):ReplayFrameRecord {
		return getOrCreateFrameRecordFromMap(frameRecords, frameIndex);
	}

	private inline function shouldTrackKey(keyCode:Int):Bool {
		return trackAllKeys || trackedKeys.exists(keyCode);
	}

	private function writeInitParams(output:BytesOutput, flags:Int):Void {
		if ((flags & FLAG_INPUTS) != 0) {
			writeVarUInt(output, params.recordedKeys.length);
			for (i in 0...params.recordedKeys.length) {
				writeVarUInt(output, params.recordedKeys[i]);
			}
		}

		if ((flags & FLAG_MOUSE_BUTTONS) != 0) {
			writeVarUInt(output, params.recordedMouseButtons.length);
			for (i in 0...params.recordedMouseButtons.length) {
				writeVarUInt(output, params.recordedMouseButtons[i]);
			}
		}
	}

	// version 3 section of changes: count, frame gaps, then values
	private function writeChanges(output:BytesOutput, frames:Array<Int>, values:Array<Int>):Void {
		writeVarUInt(output, frames.length);
		var previousFrame = 0;
		for (frameIndex in frames) {
			writeVarUInt(output, frameIndex - previousFrame);
			previousFrame = frameIndex;
		}
		for (value in values) {
			writeVarUInt(output, value);
		}
	}

	private function writeInputRecords(output:BytesOutput, frames:Array<Int>, records:Array<ReplayFrameRecord>, keyIndex:IntMap<Int>):Void {
		var changeFrames:Array<Int> = [];
		var values:Array<Int> = [];
		for (i in 0...frames.length) {
			for (input in records[i].inputs) {
				changeFrames.push(frames[i]);
				values.push(((keyIndex != null ? keyIndex.get(input.keyCode) : input.keyCode) << 1) | (input.isDown ? 1 : 0));
			}
		}
		writeChanges(output, changeFrames, values);
	}

	private function writeEventRecords(output:BytesOutput, frames:Array<Int>, records:Array<ReplayFrameRecord>):Void {
		var count = 0;
		for (record in records) {
			if (record.events.length > 0) {
				count++;
			}
		}

		writeVarUInt(output, count);
		var previousFrame = 0;
		for (i in 0...frames.length) {
			var record = records[i];
			if (record.events.length == 0) {
				continue;
			}

			writeVarUInt(output, frames[i] - previousFrame);
			previousFrame = frames[i];

			writeVarUInt(output, record.events.length);
			for (i in 0...record.events.length) {
				if (record.eventBytes != null && i < record.eventBytes.length) {
					output.write(record.eventBytes[i]);
				} else {
					writeEvent(output, record.events[i]);
				}
			}
		}
	}

	private function writeMousePositionRecords(output:BytesOutput, frames:Array<Int>, records:Array<ReplayFrameRecord>):Void {
		var changeFrames:Array<Int> = [];
		var xs:Array<Int> = [];
		var ys:Array<Int> = [];
		for (i in 0...frames.length) {
			if (records[i].mousePosition != null) {
				changeFrames.push(frames[i]);
				xs.push(records[i].mousePosition.x);
				ys.push(records[i].mousePosition.y);
			}
		}

		writeVarUInt(output, changeFrames.length);
		var previousFrame = 0;
		for (frameIndex in changeFrames) {
			writeVarUInt(output, frameIndex - previousFrame);
			previousFrame = frameIndex;
		}
		writeMoves(output, changeFrames, xs);
		writeMoves(output, changeFrames, ys);
	}

	// one coordinate of the mouse: its move, minus the move of the frame before when it moved then too
	private function writeMoves(output:BytesOutput, frames:Array<Int>, values:Array<Int>):Void {
		var previous = 0;
		var previousMove = 0;
		for (i in 0...values.length) {
			var move = values[i] - previous;
			var consecutive = i > 0 && frames[i] - frames[i - 1] == 1;
			writeZigZag(output, consecutive ? move - previousMove : move);
			previousMove = consecutive ? move : 0;
			previous = values[i];
		}
	}

	private function readMoves(input:BytesInput, frames:Array<Int>):Array<Int> {
		var values:Array<Int> = [];
		var previous = 0;
		var previousMove = 0;
		for (i in 0...frames.length) {
			var consecutive = i > 0 && frames[i] - frames[i - 1] == 1;
			var move = readZigZag(input) + (consecutive ? previousMove : 0);
			previousMove = consecutive ? move : 0;
			previous += move;
			values.push(previous);
		}
		return values;
	}

	private function writeMouseButtonRecords(output:BytesOutput, frames:Array<Int>, records:Array<ReplayFrameRecord>, buttonIndex:IntMap<Int>):Void {
		var changeFrames:Array<Int> = [];
		var values:Array<Int> = [];
		for (i in 0...frames.length) {
			if (records[i].mouseButtons != null) {
				for (change in records[i].mouseButtons) {
					changeFrames.push(frames[i]);
					values.push(((buttonIndex != null ? buttonIndex.get(change.button) : change.button) << 1) | (change.isDown ? 1 : 0));
				}
			}
		}
		writeChanges(output, changeFrames, values);
	}

	// version 4: the phases of the input changes, then of the events, then of the mouse button changes (each group in the
	// order of its section: frames in order, then the order of the record)
	private function writePhaseRecords(output:BytesOutput, records:Array<ReplayFrameRecord>, flags:Int):Void {
		var phases:Array<Int> = [];
		if ((flags & FLAG_INPUTS) != 0) {
			for (record in records) {
				for (input in record.inputs) {
					phases.push(phaseOrNone(input.phase));
				}
			}
		}
		if ((flags & FLAG_EVENTS) != 0) {
			for (record in records) {
				for (i in 0...record.events.length) {
					phases.push(record.eventPhases != null && i < record.eventPhases.length ? record.eventPhases[i] : PHASE_NONE);
				}
			}
		}
		if ((flags & FLAG_MOUSE_BUTTONS) != 0) {
			for (record in records) {
				if (record.mouseButtons != null) {
					for (change in record.mouseButtons) {
						phases.push(phaseOrNone(change.phase));
					}
				}
			}
		}
		writeVarUInt(output, phases.length);
		for (phase in phases) {
			output.writeByte(phase);
		}
	}

	private function readPhaseRecords(input:BytesInput, target:IntMap<ReplayFrameRecord>, flags:Int):Void {
		var count = readVarUInt(input);
		var frames = [for (frame in target.keys()) frame];
		frames.sort((a, b) -> a - b);
		var read = 0;
		inline function next():Int {
			if (read >= count) {
				throw "Replay phases missing";
			}
			read++;
			return input.readByte();
		}
		if ((flags & FLAG_INPUTS) != 0) {
			for (frame in frames) {
				for (change in target.get(frame).inputs) {
					change.phase = next();
				}
			}
		}
		if ((flags & FLAG_EVENTS) != 0) {
			for (frame in frames) {
				var record = target.get(frame);
				record.eventPhases = [for (_ in record.events) next()];
			}
		}
		if ((flags & FLAG_MOUSE_BUTTONS) != 0) {
			for (frame in frames) {
				var record = target.get(frame);
				if (record.mouseButtons != null) {
					for (change in record.mouseButtons) {
						change.phase = next();
					}
				}
			}
		}
		if (read != count) {
			throw "Replay phases count mismatch";
		}
	}

	private function decodeBinaryData(data:Bytes):Void {
		var input = new BytesInput(data);
		var magic = input.readString(MAGIC_HEADER.length);
		if (magic != MAGIC_HEADER) {
			throw "Invalid replay data header";
		}

		var version = input.readByte();
		if (version < 1 || version > REPLAY_VERSION) {
			throw "Unsupported replay version " + version;
		}
		var flags = input.readByte();
		exactMath = version >= EXACT_MATH_VERSION;
		rngStir = (flags & FLAG_RNG_STIR) != 0;
		phasesEnabled = version >= 4 && (flags & FLAG_INPUT_PHASES) != 0;

		var target = new IntMap<ReplayFrameRecord>();
		readInitParams(input, flags, version);
		var keys = (flags & FLAG_KEY_CODES) != 0 ? null : params.recordedKeys;
		var buttons = (flags & FLAG_BUTTON_CODES) != 0 ? null : params.recordedMouseButtons;
		if ((flags & FLAG_INPUTS) != 0) {
			if (version >= 3) {
				readChanges(input, target, keys, (record, code, isDown) -> record.inputs.push({keyCode: code, isDown: isDown}));
			} else {
				readInputRecords(input, target);
			}
		}
		if ((flags & FLAG_EVENTS) != 0) {
			readEventRecords(input, target, data);
		}
		if (version >= 2 && (flags & FLAG_MOUSE_POSITION) != 0) {
			if (version >= 3) {
				readMousePositionChanges(input, target);
			} else {
				readMousePositionRecords(input, target);
			}
		}
		if (version >= 2 && (flags & FLAG_MOUSE_BUTTONS) != 0) {
			if (version >= 3) {
				readChanges(input, target, buttons, (record, code, isDown) -> {
					if (record.mouseButtons == null) {
						record.mouseButtons = [];
					}
					record.mouseButtons.push({button: code, isDown: isDown});
				});
			} else {
				readMouseButtonRecords(input, target);
			}
		}
		if (phasesEnabled) {
			readPhaseRecords(input, target, flags);
		}
		totalFrames = -1;
		if (data.length - input.position >= MAGIC_LENGTH.length + 1 && input.readString(MAGIC_LENGTH.length) == MAGIC_LENGTH) {
			totalFrames = readVarUInt(input);
		}

		playFrames = [for (frame in target.keys()) frame];
		playFrames.sort((a, b) -> a - b);
		playRecords = [for (frame in playFrames) target.get(frame)];
		lastRecordedFrame = playFrames.length > 0 ? playFrames[playFrames.length - 1] : 0;
		#if debug
		trace('Decoded replay data: version ' + version + ', ' + data.length + ' bytes, ' + playFrames.length + ' frames with records');
		#end
	}

	private function readInitParams(input:BytesInput, flags:Int, version:Int):Void {
		var recordInputs = (flags & FLAG_INPUTS) != 0;
		var recordEvents = (flags & FLAG_EVENTS) != 0;
		var supportsMouse = version >= 2;
		var recordMousePosition = supportsMouse && (flags & FLAG_MOUSE_POSITION) != 0;
		var recordMouseButtons = supportsMouse && (flags & FLAG_MOUSE_BUTTONS) != 0;

		var keyCount = recordInputs ? readVarUInt(input) : 0;
		var keys = new UInt16Array(keyCount);
		for (i in 0...keyCount) {
			keys[i] = readVarUInt(input);
		}

		var buttonCount = recordMouseButtons ? readVarUInt(input) : 0;
		var buttons = new UInt16Array(buttonCount);
		for (i in 0...buttonCount) {
			buttons[i] = readVarUInt(input);
		}

		this.params = normalizeParams({
			recordedKeys: keys,
			recordInputs: recordInputs,
			recordEvents: recordEvents,
			recordMousePosition: recordMousePosition,
			recordedMouseButtons: buttons
		});

		refreshTrackedKeys();
		refreshTrackedMouseButtons();
		this.shouldRecordInputs = this.params.recordInputs;
		this.shouldRecordEvents = this.params.recordEvents;
		this.shouldRecordMousePosition = this.params.recordMousePosition;
	}

	// version 3 section of key / button changes; table: codes by index (null: the values are the codes)
	private function readChanges(input:BytesInput, target:IntMap<ReplayFrameRecord>, table:UInt16Array,
			add:(ReplayFrameRecord, Int, Bool) -> Void):Void {
		var count = readVarUInt(input);
		var frames = readFrames(input, count);
		for (i in 0...count) {
			var packed = readVarUInt(input);
			var code = packed >> 1;
			if (table != null) {
				if (code >= table.length) {
					throw "Replay index out of range " + code;
				}
				code = table[code];
			}
			add(getOrCreateFrameRecordFromMap(target, frames[i]), code, (packed & 1) == 1);
		}
	}

	private function readFrames(input:BytesInput, count:Int):Array<Int> {
		var frames:Array<Int> = [];
		var frameIndex = 0;
		for (i in 0...count) {
			frameIndex += readVarUInt(input);
			frames.push(frameIndex);
		}
		return frames;
	}

	private function readMousePositionChanges(input:BytesInput, target:IntMap<ReplayFrameRecord>):Void {
		var frames = readFrames(input, readVarUInt(input));
		var xs = readMoves(input, frames);
		var ys = readMoves(input, frames);
		for (i in 0...frames.length) {
			getOrCreateFrameRecordFromMap(target, frames[i]).mousePosition = {x: xs[i], y: ys[i]};
		}
	}

	private function readInputRecords(input:BytesInput, target:IntMap<ReplayFrameRecord>):Void {
		var frameCount = readVarUInt(input);
		var frameIndex = 0;

		for (i in 0...frameCount) {
			frameIndex += readVarUInt(input);
			var inputCount = readVarUInt(input);
			var record = getOrCreateFrameRecordFromMap(target, frameIndex);
			for (j in 0...inputCount) {
				var packed = readVarUInt(input);
				record.inputs.push({
					keyCode: packed >> 1,
					isDown: (packed & 1) == 1
				});
			}
		}
	}

	private function readEventRecords(input:BytesInput, target:IntMap<ReplayFrameRecord>, data:Bytes):Void {
		var frameCount = readVarUInt(input);
		var frameIndex = 0;

		for (i in 0...frameCount) {
			frameIndex += readVarUInt(input);
			var eventCount = readVarUInt(input);
			var record = getOrCreateFrameRecordFromMap(target, frameIndex);
			if (record.eventBytes == null) {
				record.eventBytes = [];
			}
			for (j in 0...eventCount) {
				var start = input.position;
				record.events.push(readEvent(input));
				record.eventBytes.push(data.sub(start, input.position - start));
			}
		}
	}

	private function readMousePositionRecords(input:BytesInput, target:IntMap<ReplayFrameRecord>):Void {
		var frameCount = readVarUInt(input);
		var frameIndex = 0;

		for (i in 0...frameCount) {
			frameIndex += readVarUInt(input);
			var record = getOrCreateFrameRecordFromMap(target, frameIndex);
			record.mousePosition = {
				x: readVarUInt(input),
				y: readVarUInt(input)
			};
		}
	}

	private function readMouseButtonRecords(input:BytesInput, target:IntMap<ReplayFrameRecord>):Void {
		var frameCount = readVarUInt(input);
		var frameIndex = 0;

		for (i in 0...frameCount) {
			frameIndex += readVarUInt(input);
			var buttonCount = readVarUInt(input);
			var record = getOrCreateFrameRecordFromMap(target, frameIndex);
			if (record.mouseButtons == null) {
				record.mouseButtons = [];
			}
			for (j in 0...buttonCount) {
				var packed = readVarUInt(input);
				record.mouseButtons.push({
					button: packed >> 1,
					isDown: (packed & 1) == 1
				});
			}
		}
	}

	private function writeEvent(output:BytesOutput, event:ReplayEvent):Void {
		var k = intFieldOrNull(event, "k");
		var x = intFieldOrNull(event, "x");
		var y = intFieldOrNull(event, "y");
		var canPack = k != null && x != null && y != null && k >= 0 && k < 4 && x >= 0 && x < 8 && y >= 0 && y < 8
			&& Reflect.fields(event).length == 3;

		if (canPack) {
			output.writeByte(EVENT_ENCODING_PACKED_GRID);
			output.writeByte((k << 6) | (x << 3) | y);
			return;
		}

		output.writeByte(EVENT_ENCODING_SERIALIZED);
		writeVarString(output, Serializer.run(event));
	}

	private function readEvent(input:BytesInput):ReplayEvent {
		var encoding = input.readByte();
		switch (encoding) {
			case EVENT_ENCODING_PACKED_GRID:
				var packed = input.readByte();
				return {
					k: (packed >> 6) & 0x3,
					x: (packed >> 3) & 0x7,
					y: packed & 0x7
				};
			case EVENT_ENCODING_SERIALIZED:
				return Unserializer.run(readVarString(input));
			default:
				throw "Unsupported event encoding " + encoding;
		}
	}

	private function getOrCreateFrameRecordFromMap(target:IntMap<ReplayFrameRecord>, frameIndex:Int):ReplayFrameRecord {
		var record = target.get(frameIndex);
		if (record != null) {
			return record;
		}

		record = {
			events: [],
			inputs: []
		};
		target.set(frameIndex, record);
		return record;
	}

	private function writeVarString(output:BytesOutput, value:String):Void {
		var bytes = Bytes.ofString(value);
		writeVarUInt(output, bytes.length);
		output.write(bytes);
	}

	private function readVarString(input:BytesInput):String {
		var length = readVarUInt(input);
		return input.readString(length);
	}

	private function writeVarUInt(output:BytesOutput, value:Int):Void {
		if (value < 0) {
			throw "Replay varint cannot encode negative value";
		}

		var n = value;
		while (n >= 0x80) {
			output.writeByte((n & 0x7F) | 0x80);
			n = n >>> 7;
		}
		output.writeByte(n);
	}

	private function readVarUInt(input:BytesInput):Int {
		var result = 0;
		var shift = 0;

		while (true) {
			var b = input.readByte();
			result |= (b & 0x7F) << shift;
			if ((b & 0x80) == 0) {
				return result;
			}

			shift += 7;
			if (shift > 28) {
				throw "Replay varint is too long";
			}
		}
	}

	// signed numbers: 0, -1, 1, -2, 2... -> 0, 1, 2, 3, 4...
	private inline function writeZigZag(output:BytesOutput, value:Int):Void {
		writeVarUInt(output, value >= 0 ? value << 1 : ((-value) << 1) - 1);
	}

	private inline function readZigZag(input:BytesInput):Int {
		var v = readVarUInt(input);
		return (v & 1) == 0 ? v >>> 1 : -((v + 1) >>> 1);
	}

	private function intFieldOrNull(event:ReplayEvent, field:String):Null<Int> {
		var value:Dynamic = Reflect.field(event, field);
		if (value == null) {
			return null;
		}

		var intValue = Std.int(value);
		if (intValue != value) {
			return null;
		}

		return intValue;
	}

	private function indexTable(list:UInt16Array):IntMap<Int> {
		var table = new IntMap<Int>();
		for (i in 0...list.length) {
			if (!table.exists(list[i])) {
				table.set(list[i], i);
			}
		}
		return table;
	}

	private function refreshTrackedKeys():Void {
		trackedKeys = new IntMap();
		trackedKeyList = [];
		for (i in 0...params.recordedKeys.length) {
			if (!trackedKeys.exists(params.recordedKeys[i])) {
				trackedKeys.set(params.recordedKeys[i], true);
				trackedKeyList.push(params.recordedKeys[i]);
			}
		}
		trackAllKeys = trackedKeyList.length == 0;
	}

	private function refreshTrackedMouseButtons():Void {
		trackedMouseButtons = new IntMap();
		for (i in 0...params.recordedMouseButtons.length) {
			trackedMouseButtons.set(params.recordedMouseButtons[i], true);
		}
		hasTrackedMouseButtons = params.recordedMouseButtons.length > 0;
	}

	private function parseReplayString(?input:String):Bytes {
		if (input == null) {
			return null;
		}

		try {
			var decoded = Base64.decode(input);
			try {
				return uint8ArrayToBytes(externs.Pako.inflate(bytesToUint8Array(decoded)));
			} catch (_:Dynamic) {
				// fail safe, return decoded even if decompression fails (for backward compatibility with uncompressed data)
				return decoded;
			}
		} catch (_:Dynamic) {
			return Bytes.ofString(input);
		}
	}

	private static inline function bytesToUint8Array(data:Bytes):Uint8Array {
		return new Uint8Array(data.getData(), 0, data.length);
	}

	private static inline function uint8ArrayToBytes(data:Uint8Array):Bytes {
		return Bytes.ofData(data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength));
	}

	private function normalizeParams(input:ReplayInitParams):ReplayInitParams {
		if (input == null) {
			return defaultParams();
		}

		return {
			recordedKeys: input.recordedKeys != null ? input.recordedKeys : new UInt16Array(0),
			recordInputs: input.recordInputs != null ? input.recordInputs : true,
			recordEvents: input.recordEvents != null ? input.recordEvents : true,
			recordMousePosition: input.recordMousePosition != null ? input.recordMousePosition : false,
			recordedMouseButtons: input.recordedMouseButtons != null ? input.recordedMouseButtons : new UInt16Array(0)
		};
	}

	private function defaultParams():ReplayInitParams {
		return {
			recordedKeys: new UInt16Array(0),
			recordInputs: true,
			recordEvents: true,
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0)
		};
	}
}
