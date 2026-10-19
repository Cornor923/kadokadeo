package kado;

import js.Browser;
import js.html.CanvasElement;
import js.html.Element;
import js.html.KeyboardEvent;
import js.html.PointerEvent;
import pixi.core.display.Container;
import pixi.core.graphics.Graphics;
import pixi.core.sprites.Sprite;
import pixi.core.text.Text;
import pixi.core.textures.Texture;

typedef ReplayHudHost = {
	// go to a frame of the replay (backwards too)
	var seek:Int->Void;
	var setPaused:Bool->Void;
	var setSpeed:Float->Void;
	// one frame forward (1) or back (-1), the replay being paused
	var step:Int->Void;
	// the pointer is over a mark of the progress bar (its index in setMarkers), -1 when it leaves it
	@:optional var markerHover:Int->Void;
}

// a comment of the replay page shown in the game (setComment): its moment ("mm:ss"), its author, its text, the comments
// waiting after it
typedef ReplayHudComment = {
	var time:String;
	var author:String;
	var text:String;
	var more:Int;
}

private typedef HudButton = {
	var id:String;
	var x:Float;
	var w:Float;
	var gfx:Graphics;
}

private typedef KeyCap = {
	var code:Int;
	var x:Float;
	var y:Float;
	var w:Float;
	var label:Text;
	var arrow:Int;
}

// Controls of a replay, over the bottom of the game like a video player, in the colours of KadoKadeo (cyan, orange):
// progress bar (click or drag it to go to any moment, backwards too), play / pause, back to the start, -10 s / +10 s,
// time, speed, keys pressed by the player, keyboard shortcuts. They hide while the replay plays and the pointer stays
// still, and come back when it moves (a thin progress line stays). A click on the game plays / pauses (a tap shows /
// hides the controls on a touch screen). Marks in the bar (setMarkers: the comments of the replay page) show moments of
// the replay, the comment reached is shown on one line above the controls and the keys (setComment); C hides / shows
// them. Nothing is drawn again unless it changed.
class ReplayHud extends Container {
	public static var SPEEDS:Array<Float> = [0.1, 0.25, 0.5, 1, 1.5, 2, 4, 8];

	static inline var W = 600;
	// bottom of the game area, above the score / contract bar (KadoKadeoManager.gameAreaHeight: 600, or 460 for an
	// Arkadeo game; set by the constructor)
	static var BOTTOM = KadoKadeoManager.I(300);
	static inline var PANEL_H = 108;
	static inline var BAR_X0 = 14;
	static inline var BAR_X1 = 586;
	static var BAR_Y = BOTTOM - 42;
	static var ROW_Y = BOTTOM - 18;
	static inline var BUTTON_H = 32;
	// colours of the site (resources/css/app.css), and a dark teal for the backgrounds
	static inline var CYAN = 0x44CCE7;
	static inline var CYAN_LIGHT = 0x82E1F3;
	static inline var ORANGE = 0xFFA400;
	static inline var DARK = 0x0D2D35;
	static inline var HIDE_DELAY_MS = 2600;
	static inline var TIP_DELAY_MS = 400;
	// a seek lasting longer than that shows in the bar the frames already computed
	static inline var SEEK_PROGRESS_DELAY_MS = 150;
	static inline var CAP = 22;
	static inline var CAP_GAP = 3;
	static inline var PREF_KEYS = "kadokadeo.replay.keys";
	static inline var PREF_COMMENTS = "kadokadeo.replay.comments";
	// a comment stays this long on the screen (resources/js/components/runs/comments/Overlay.vue): its mark covers it
	static inline var COMMENT_SECONDS = 3;
	// the narrowest mark, in pixels of the screen
	static inline var MARK_MIN_PX = 3;
	static inline var COMMENT_MARGIN = 10;
	static inline var COMMENT_H = 26;
	static inline var FONT = "Fredoka Bold, Arial, sans-serif";

	var canvas:CanvasElement;
	var replay:ReplayManager;
	var frameMs:Float;
	var host:ReplayHudHost;

	// state given by the manager every picture
	var frame:Float = 0;
	var total:Float = 1;
	var totalKnown:Bool = true;
	var paused:Bool = false;
	var speed:Float = 1;
	var seekTarget:Null<Int> = null;
	var ended:Bool = false;

	// controls
	var controls:Container;
	var shade:Sprite;
	var bar:Graphics;
	var barTip:Container;
	var barTipBg:Graphics;
	var barTipText:Text;
	var timeText:Text;
	var speedText:Text;
	var badge:Container;
	var buttons:Array<HudButton> = [];
	var buttonTip:Container;
	var buttonTipBg:Graphics;
	var buttonTipText:Text;
	var miniBar:Graphics;
	var speedMenu:Container;
	var speedMenuBg:Graphics;
	var speedItems:Array<{speed:Float, text:Text}> = [];
	var help:Container;
	// seek being computed: since when
	var seekSince:Float = -1;

	// marks of the bar (frames), the one under the pointer; their version is in the keys of the drawings
	var markers:Array<Int> = [];
	var hoverMarker:Int = -1;
	var marksVersion:Int = 0;
	// one pixel of the screen in pixels of the game (-1: to measure)
	var pixel:Float = -1;

	// the comment shown (C: hidden with the marks)
	var commentsOn:Bool = true;
	var comment:ReplayHudComment = null;
	var commentKey:String = "";
	var commentBox:Container;
	var commentBg:Graphics;
	var commentTime:Text;
	var commentAuthor:Text;
	var commentText:Text;
	var commentMore:Text;
	var toast:Container;
	var toastBg:Graphics;
	var toastText:Text;
	var toastUntil:Float = 0;

	// keys of the player
	var keysPanel:Container;
	var keysBg:Graphics;
	var keysCaps:Graphics;
	var caps:Array<KeyCap> = [];
	var mouseButtons:Array<Int> = [];
	var mouseIconX:Float = 0;
	var keysW:Float = 0;
	var keysH:Float = 0;
	var keysMask:Int = -1;
	var keysOn:Bool = false;
	var cursorMark:Graphics;
	var cursorKey:String = "";

	// pointer
	var pointerIn:Bool = false;
	var pointerX:Float = 0;
	var pointerY:Float = 0;
	var hoverButton:String = null;
	var hoverSince:Float = 0;
	var hoverBar:Bool = false;
	var dragging:Bool = false;
	var dragPointer:Null<Int> = null;
	var menuOpen:Bool = false;
	var helpOpen:Bool = false;
	var lastActivity:Float = 0;
	var shown:Float = 1;
	var grow:Float = 0;
	var lastMs:Float = 0;
	var cursorStyle:String = "";

	// what was drawn last (redrawn only when it changes)
	var drawnBar:String = "";
	var drawnMini:String = "";
	var drawnButtons:String = "";
	var drawnTime:String = "";

	public function new(canvas:CanvasElement, replay:ReplayManager, frameMs:Float, host:ReplayHudHost) {
		super();
		if (KadoKadeoManager.kkm != null) {
			BOTTOM = Std.int(KadoKadeoManager.kkm.gameAreaHeight());
			BAR_Y = BOTTOM - 42;
			ROW_Y = BOTTOM - 18;
		}
		this.canvas = canvas;
		this.replay = replay;
		this.frameMs = frameMs;
		this.host = host;
		lastActivity = now();
		lastMs = lastActivity;
		keysOn = readPref(PREF_KEYS, false);
		commentsOn = readPref(PREF_COMMENTS, true);

		cursorMark = new Graphics();
		addChild(cursorMark);
		initKeys();

		miniBar = new Graphics();
		addChild(miniBar);

		controls = new Container();
		addChild(controls);
		shade = new Sprite(gradientTexture());
		shade.y = BOTTOM - PANEL_H;
		shade.width = W;
		shade.height = PANEL_H;
		controls.addChild(shade);
		bar = new Graphics();
		controls.addChild(bar);
		initButtons();
		timeText = text("", 14, 0xFFFFFF);
		timeText.anchor.set(0, 0.5);
		timeText.x = 178;
		timeText.y = ROW_Y;
		controls.addChild(timeText);
		initBadge();

		barTip = tipBox();
		barTipBg = cast barTip.getChildAt(0);
		barTipText = cast barTip.getChildAt(1);
		controls.addChild(barTip);
		buttonTip = tipBox();
		buttonTipBg = cast buttonTip.getChildAt(0);
		buttonTipText = cast buttonTip.getChildAt(1);
		controls.addChild(buttonTip);

		initComment();
		initSpeedMenu();
		initHelp();

		canvas.addEventListener("pointerdown", onPointerDown);
		canvas.addEventListener("pointerleave", onPointerLeave);
		Browser.window.addEventListener("pointermove", onPointerMove);
		Browser.window.addEventListener("pointerup", onPointerUp);
		Browser.window.addEventListener("pointercancel", onPointerUp);
		Browser.window.addEventListener("keydown", onKeyDown);
		Browser.window.addEventListener("resize", onResize);
	}

	public function dispose():Void {
		canvas.removeEventListener("pointerdown", onPointerDown);
		canvas.removeEventListener("pointerleave", onPointerLeave);
		Browser.window.removeEventListener("pointermove", onPointerMove);
		Browser.window.removeEventListener("pointerup", onPointerUp);
		Browser.window.removeEventListener("pointercancel", onPointerUp);
		Browser.window.removeEventListener("keydown", onKeyDown);
		Browser.window.removeEventListener("resize", onResize);
		setCursor("");
	}

	// called every picture with the state of the replay
	public function update(frame:Float, total:Float, totalKnown:Bool, paused:Bool, speed:Float, seekTarget:Null<Int>, ended:Bool):Void {
		this.frame = frame;
		this.total = Math.max(1, total);
		this.totalKnown = totalKnown;
		this.paused = paused;
		this.speed = speed;
		var t = now();
		if (seekTarget != null && this.seekTarget == null)
			seekSince = t;
		if (seekTarget == null)
			seekSince = -1;
		this.seekTarget = seekTarget;
		this.ended = ended;

		var dt = Math.min(100, t - lastMs);
		lastMs = t;

		// shown while paused, used or pointed at, hidden a moment after the pointer stopped
		var want = paused
			|| ended
			|| menuOpen
			|| helpOpen
			|| dragging
			|| seekTarget != null
			|| t - lastActivity < HIDE_DELAY_MS
			|| (pointerIn && pointerY >= BOTTOM - PANEL_H && pointerY < BOTTOM);
		shown = approach(shown, want ? 1 : 0, dt / 160);
		controls.alpha = shown;
		controls.visible = shown > 0.01;
		var g = hoverBar || dragging ? 1.0 : 0.0;
		grow = approach(grow, g, dt / 90);

		if (controls.visible) {
			drawBar();
			drawButtons();
			drawTime();
			updateButtonTip(t);
		}
		drawMiniBar();
		updateKeys();
		updateComment(dt, t);
	}

	// BAR

	// marks in the bar at these frames (the comments of the replay page): replaced each time
	public function setMarkers(frames:Array<Int>):Void {
		markers = frames == null ? [] : frames.copy();
		setHoverMarker(-1);
		marksVersion++;
	}

	// the marks are as wide as one frame on the bar, at least one pixel of the screen
	function onResize(_):Void {
		pixel = -1;
		marksVersion++;
	}

	// one pixel of the screen, in pixels of the game (measured again when the window changes size)
	function screenPixel():Float {
		if (pixel > 0)
			return pixel;
		var w = canvas.clientWidth;
		var screen = KadoKadeoManager.kkm != null ? KadoKadeoManager.kkm.screen : null;
		if (w <= 0 || screen == null)
			return 1;
		pixel = screen.width / w;
		return pixel;
	}

	// a mark covers the time its comment stays on the screen, at least MARK_MIN_PX pixels of the screen
	function markWidth(x0:Float, x1:Float):Float {
		return Math.max(MARK_MIN_PX * screenPixel(), (x1 - x0) * COMMENT_SECONDS * 1000 / frameMs / total);
	}

	// the marks from x0 to x1 (pixels of the game), h high around y
	function drawMarks(g:Graphics, x0:Float, x1:Float, y:Float, h:Float, alpha:Float, hovered:Int):Void {
		if (markers.length == 0 || !commentsOn)
			return;
		var w = markWidth(x0, x1);
		for (i in 0...markers.length) {
			var x = x0 + (x1 - x0) * Math.max(0, Math.min(1, markers[i] / total));
			var on = i == hovered;
			g.beginFill(on ? 0xFFFFFF : ORANGE, alpha);
			g.drawRect(Math.min(x, x1 - w), y - (on ? h * 0.5 + 2 : h * 0.5), w, on ? h + 4 : h);
			g.endFill();
		}
	}

	// the mark under the pointer (x: pixels of the game), -1 if none: the one whose middle is the nearest
	function markerAt(x:Float):Int {
		if (!commentsOn)
			return -1;
		var best = -1;
		var w = markWidth(BAR_X0, BAR_X1);
		var reach = Math.max(4, w * 0.5 + 2);
		for (i in 0...markers.length) {
			var d = Math.abs(Math.min(barX(markers[i]), BAR_X1 - w) + w * 0.5 - x);
			if (d <= reach) {
				reach = d;
				best = i;
			}
		}
		return best;
	}

	function setHoverMarker(i:Int):Void {
		if (i == hoverMarker)
			return;
		hoverMarker = i;
		if (host.markerHover != null)
			host.markerHover(i);
	}

	function shownFrame():Float {
		if (dragging)
			return frameAt(pointerX);
		return seekTarget != null ? seekTarget : frame;
	}

	function drawBar():Void {
		var h = 4 + 2 * grow;
		var px = barX(shownFrame());
		// long seek: filled up to the frame computed so far, lighter up to the wanted one
		var fx = seekSince >= 0 && now() - seekSince >= SEEK_PROGRESS_DELAY_MS ? Math.min(px, barX(frame)) : px;
		var hx = hoverBar || dragging ? Math.round(Math.max(BAR_X0, Math.min(BAR_X1, pointerX))) : -1;
		var key = Math.round(px * 2) + "," + Math.round(fx * 2) + "," + hx + "," + Math.round(grow * 20) + "," + marksVersion + ","
			+ hoverMarker + "," + total;
		if (key == drawnBar)
			return;
		drawnBar = key;
		var b = bar;
		b.clear();
		b.beginFill(0xFFFFFF, 0.25);
		b.drawRect(BAR_X0, BAR_Y - h * 0.5, BAR_X1 - BAR_X0, h);
		b.endFill();
		var lit = Math.max(hx, fx < px ? px : -1);
		if (lit > fx) {
			b.beginFill(0xFFFFFF, 0.35);
			b.drawRect(fx, BAR_Y - h * 0.5, lit - fx, h);
			b.endFill();
		}
		b.beginFill(CYAN);
		b.drawRect(BAR_X0, BAR_Y - h * 0.5, fx - BAR_X0, h);
		b.endFill();
		drawMarks(b, BAR_X0, BAR_X1, BAR_Y, h + 4, 0.95, hoverMarker);
		var r = 4 + 3 * grow;
		b.lineStyle(1.5, 0xFFFFFF, 0.9);
		b.beginFill(ORANGE);
		b.drawCircle(px, BAR_Y, r);
		b.endFill();
		b.lineStyle(0);

		barTip.visible = hoverBar || dragging;
		if (barTip.visible)
			showTip(barTip, barTipBg, barTipText, format(frameAt(pointerX)), pointerX, BAR_Y - 30);
	}

	// thin progress line while the controls are hidden
	function drawMiniBar():Void {
		var a = 1 - shown;
		var px = barX(shownFrame());
		var key = a < 0.02 ? "" : Math.round((px - BAR_X0) / (BAR_X1 - BAR_X0) * W * 2) + "," + Math.round(a * 20) + "," + marksVersion + ","
			+ total;
		if (key == drawnMini)
			return;
		drawnMini = key;
		miniBar.clear();
		if (key == "")
			return;
		var p = (px - BAR_X0) / (BAR_X1 - BAR_X0) * W;
		miniBar.beginFill(0xFFFFFF, 0.2 * a);
		miniBar.drawRect(0, BOTTOM - 3, W, 3);
		miniBar.endFill();
		miniBar.beginFill(CYAN, 0.95 * a);
		miniBar.drawRect(0, BOTTOM - 3, p, 3);
		miniBar.endFill();
		drawMarks(miniBar, 0, W, BOTTOM - 1.5, 3, 0.95 * a, -1);
	}

	inline function barX(f:Float):Float {
		return BAR_X0 + (BAR_X1 - BAR_X0) * Math.max(0, Math.min(1, f / total));
	}

	function frameAt(x:Float):Int {
		return Std.int(Math.round(Math.max(0, Math.min(1, (x - BAR_X0) / (BAR_X1 - BAR_X0))) * total));
	}

	function format(f:Float):String {
		var s = Std.int(f * frameMs / 1000);
		var m = Std.int(s / 60);
		s = s % 60;
		return m + ":" + (s < 10 ? "0" : "") + s;
	}

	function drawTime():Void {
		var s = format(shownFrame()) + " / " + format(total) + (totalKnown ? "" : "+");
		if (s != drawnTime) {
			drawnTime = s;
			timeText.text = s;
		}
	}

	// COMMENT

	function initComment():Void {
		commentBox = new Container();
		commentBg = new Graphics();
		commentBox.addChild(commentBg);
		commentTime = text("", 12, ORANGE);
		commentAuthor = text("", 13, 0xFFFFFF);
		commentText = text("", 13, 0xD9F4FA, false);
		commentMore = text("", 12, 0x9FB8BE, false);
		for (t in [commentTime, commentAuthor, commentText, commentMore]) {
			t.anchor.set(0, 0.5);
			t.y = COMMENT_H * 0.5;
			commentBox.addChild(t);
		}
		commentBox.x = COMMENT_MARGIN;
		commentBox.visible = false;
		commentBox.alpha = 0;
		addChild(commentBox);

		toast = tipBox();
		toastBg = cast toast.getChildAt(0);
		toastText = cast toast.getChildAt(1);
		addChild(toast);
	}

	// the comment reached by the replay (null: none), on one line as wide as the game at most
	public function setComment(c:ReplayHudComment):Void {
		var key = c == null ? "" : c.time + "|" + c.author + "|" + c.text + "|" + c.more;
		if (key == commentKey)
			return;
		var fresh = comment == null || c == null || comment.text != c.text || comment.author != c.author;
		commentKey = key;
		comment = c;
		if (c == null)
			return;
		if (fresh)
			commentBox.alpha = 0;
		var pad = 10;
		var gap = 8;
		commentTime.text = c.time;
		commentAuthor.text = c.author;
		commentMore.text = c.more > 0 ? "+" + c.more : "";
		var max = W - COMMENT_MARGIN * 2;
		commentTime.x = pad + 3;
		commentAuthor.x = commentTime.x + commentTime.width + gap;
		commentText.x = commentAuthor.x + commentAuthor.width + gap;
		var room = max - commentText.x - pad - (c.more > 0 ? commentMore.width + gap : 0);
		fit(commentText, c.text, Math.max(0, room));
		var w = Math.min(max, commentText.x + commentText.width + (c.more > 0 ? gap + commentMore.width : 0) + pad);
		commentMore.x = w - pad - commentMore.width;
		commentBg.clear();
		commentBg.beginFill(DARK, 0.88);
		commentBg.drawRoundedRect(0, 0, w, COMMENT_H, 8);
		commentBg.endFill();
		commentBg.beginFill(ORANGE);
		commentBg.drawRoundedRect(0, 0, 4, COMMENT_H, 2);
		commentBg.endFill();
	}

	public function areCommentsShown():Bool {
		return commentsOn;
	}

	function toggleComments():Void {
		commentsOn = !commentsOn;
		writePref(PREF_COMMENTS, commentsOn);
		marksVersion++;
		setHoverMarker(-1);
		showTip(toast, toastBg, toastText, commentsOn ? "Commentaires affichés" : "Commentaires masqués", W * 0.5, 40);
		toastUntil = now() + 1200;
	}

	// above the controls when they show, and above the keys of the player when they are shown
	function updateComment(dt:Float, t:Float):Void {
		if (toast.visible && t > toastUntil)
			toast.visible = false;
		var on = commentsOn && comment != null;
		commentBox.visible = on;
		if (!on)
			return;
		commentBox.alpha = approach(commentBox.alpha, 1, dt / 150);
		var bottom = BOTTOM - 8 - (PANEL_H - 22) * shown;
		if (keysOn && hasKeys())
			bottom = BOTTOM - 14 - keysH - (PANEL_H - 22) * shown - 6;
		commentBox.y = Math.round(bottom - 6 - COMMENT_H);
	}

	// s in t, cut with "…" to fit in max pixels
	static function fit(t:Text, s:String, max:Float):Void {
		t.text = s;
		if (t.width <= max)
			return;
		var lo = 0;
		var hi = s.length;
		while (lo < hi) {
			var mid = (lo + hi + 1) >> 1;
			t.text = s.substr(0, mid) + "…";
			if (t.width <= max)
				lo = mid;
			else
				hi = mid - 1;
		}
		// not in the middle of an emoji (a pair of UTF-16 units)
		var code = lo > 0 ? s.charCodeAt(lo - 1) : null;
		if (code != null && code >= 0xD800 && code <= 0xDBFF)
			lo--;
		t.text = s.substr(0, lo) + "…";
	}

	// BUTTONS

	function initButtons():Void {
		for (b in [
			{id: "restart", x: 26.0, w: 32.0},
			{id: "back", x: 62.0, w: 34.0},
			{id: "play", x: 102.0, w: 40.0},
			{id: "forward", x: 142.0, w: 34.0},
			{id: "keys", x: 478.0, w: 34.0},
			{id: "speed", x: 526.0, w: 50.0},
			{id: "help", x: 572.0, w: 30.0}
		]) {
			var gfx = new Graphics();
			gfx.x = b.x;
			gfx.y = ROW_Y;
			controls.addChild(gfx);
			buttons.push({
				id: b.id,
				x: b.x,
				w: b.w,
				gfx: gfx
			});
		}
		var q = text("?", 13, 0xFFFFFF);
		q.anchor.set(0.5, 0.5);
		q.x = 572;
		q.y = ROW_Y + 0.5;
		controls.addChild(q);
		speedText = text("1×", 13, 0xFFFFFF);
		speedText.anchor.set(0.5, 0.5);
		speedText.x = 526;
		speedText.y = ROW_Y;
		controls.addChild(speedText);
	}

	function drawButtons():Void {
		var key = (ended ? "e" : paused ? "p" : "r")
			+ (keysOn ? "k" : "")
			+ (menuOpen ? "m" : "")
			+ (helpOpen ? "h" : "")
			+ hoverButton
			+ speed;
		if (key == drawnButtons)
			return;
		drawnButtons = key;
		for (b in buttons) {
			var g = b.gfx;
			g.clear();
			var hot = b.id == hoverButton || (b.id == "speed" && menuOpen) || (b.id == "help" && helpOpen);
			if (hot) {
				g.beginFill(0xFFFFFF, 0.16);
				g.drawRoundedRect(-b.w * 0.5, -BUTTON_H * 0.5, b.w, BUTTON_H, 8);
				g.endFill();
			}
			switch (b.id) {
				case "play":
					if (ended)
						drawReplayIcon(g, 1);
					else if (paused)
						drawPlayIcon(g, 1);
					else
						drawPauseIcon(g, 1);
				case "restart":
					g.beginFill(0xFFFFFF);
					g.drawRect(-7, -7, 3, 14);
					g.drawPolygon([7, -7, 7, 7, -3, 0]);
					g.endFill();
				case "back":
					g.beginFill(0xFFFFFF);
					g.drawPolygon([0, -7, 0, 7, -9, 0]);
					g.drawPolygon([9, -7, 9, 7, 0, 0]);
					g.endFill();
				case "forward":
					g.beginFill(0xFFFFFF);
					g.drawPolygon([-9, -7, -9, 7, 0, 0]);
					g.drawPolygon([0, -7, 0, 7, 9, 0]);
					g.endFill();
				case "keys":
					// small keyboard, underlined in cyan when the keys of the player are shown
					g.lineStyle(2, 0xFFFFFF, 1);
					g.drawRoundedRect(-10, -7, 20, 13, 3);
					g.lineStyle(0);
					g.beginFill(0xFFFFFF);
					for (i in 0...4)
						g.drawRect(-7 + i * 4, -4, 2, 2);
					for (i in 0...3)
						g.drawRect(-5 + i * 4, -1, 2, 2);
					g.drawRect(-4, 2, 8, 2);
					g.endFill();
					if (keysOn) {
						g.beginFill(CYAN);
						g.drawRect(-10, 10, 20, 3);
						g.endFill();
					}
				case "speed":
					// orange when the speed is not the normal one
					g.lineStyle(1.5, speed != 1 ? ORANGE : 0xFFFFFF, speed != 1 ? 1 : 0.7);
					if (speed != 1)
						g.beginFill(ORANGE);
					g.drawRoundedRect(-20, -10, 40, 20, 10);
					if (speed != 1)
						g.endFill();
				case "help":
					g.lineStyle(2, 0xFFFFFF, 1);
					g.drawCircle(0, 0, 9);
					g.lineStyle(0);
			}
		}
		speedText.text = speedLabel(speed);
	}

	function drawPlayIcon(g:Graphics, s:Float):Void {
		g.beginFill(0xFFFFFF);
		g.drawPolygon([-6 * s, -9 * s, -6 * s, 9 * s, 9 * s, 0]);
		g.endFill();
	}

	function drawPauseIcon(g:Graphics, s:Float):Void {
		g.beginFill(0xFFFFFF);
		g.drawRect(-7 * s, -8 * s, 5 * s, 16 * s);
		g.drawRect(2 * s, -8 * s, 5 * s, 16 * s);
		g.endFill();
	}

	function drawReplayIcon(g:Graphics, s:Float):Void {
		g.lineStyle(2.5 * s, 0xFFFFFF, 1);
		g.arc(0, 0, 8 * s, -Math.PI * 0.35, Math.PI * 1.45);
		g.lineStyle(0);
		g.beginFill(0xFFFFFF);
		var ax = Math.cos(-Math.PI * 0.35) * 8 * s;
		var ay = Math.sin(-Math.PI * 0.35) * 8 * s;
		g.drawPolygon([ax - 5 * s, ay - 3 * s, ax + 4 * s, ay - 4 * s, ax + 1 * s, ay + 5 * s]);
		g.endFill();
	}

	function buttonAt(x:Float, y:Float):String {
		if (y < ROW_Y - BUTTON_H * 0.5 || y > ROW_Y + BUTTON_H * 0.5)
			return null;
		for (b in buttons)
			if (Math.abs(x - b.x) <= b.w * 0.5)
				return b.id;
		return null;
	}

	function pressButton(id:String):Void {
		switch (id) {
			case "play":
				togglePlay();
			case "restart":
				host.seek(0);
			case "back":
				jump(-10);
			case "forward":
				jump(10);
			case "keys":
				toggleKeys();
			case "speed":
				menuOpen = !menuOpen;
				helpOpen = false;
				help.visible = false;
				speedMenu.visible = menuOpen;
				if (menuOpen)
					drawSpeedMenu();
			case "help":
				toggleHelp();
		}
		drawnButtons = "";
	}

	function buttonTipText_(id:String):String {
		return switch (id) {
			case "play": ended ? "Revoir (K)" : paused ? "Lecture (K)" : "Pause (K)";
			case "restart": "Revoir depuis le début (Début)";
			case "back": "Reculer de 10 s (J)";
			case "forward": "Avancer de 10 s (L)";
			case "keys": (keysOn ? "Masquer" : "Afficher") + " les touches et la souris du joueur (I)";
			case "speed": "Vitesse (< >)";
			case "help": "Raccourcis clavier (H)";
			default: null;
		}
	}

	function updateButtonTip(t:Float):Void {
		var show = hoverButton != null && !menuOpen && !dragging && t - hoverSince >= TIP_DELAY_MS;
		if (!show) {
			buttonTip.visible = false;
			return;
		}
		if (!buttonTip.visible) {
			for (b in buttons)
				if (b.id == hoverButton)
					showTip(buttonTip, buttonTipBg, buttonTipText, buttonTipText_(b.id), b.x, ROW_Y - 44);
		}
	}

	function initBadge():Void {
		badge = new Container();
		var label = text("REPLAY", 12, 0xFFFFFF);
		label.anchor.set(0.5, 0.5);
		var icon:Sprite = null;
		try {
			icon = Sprite.from("kado_icon.png");
		} catch (_:Dynamic) {}
		var iconW = icon != null && icon.texture.width > 1 ? 14.0 : 0.0;
		var w = label.width + 16 + (iconW > 0 ? iconW + 4 : 0);
		var bg = new Graphics();
		bg.beginFill(ORANGE, 0.95);
		bg.drawRoundedRect(-w * 0.5, -10, w, 20, 10);
		bg.endFill();
		badge.addChild(bg);
		if (iconW > 0) {
			icon.anchor.set(0.5, 0.5);
			icon.width = iconW;
			icon.height = iconW;
			icon.x = -w * 0.5 + 6 + iconW * 0.5;
			badge.addChild(icon);
			label.x = iconW * 0.5 + 2;
		}
		label.y = 1;
		badge.addChild(label);
		badge.x = 448 - w * 0.5 - 6;
		badge.y = ROW_Y;
		controls.addChild(badge);
	}

	// SPEED MENU

	function initSpeedMenu():Void {
		speedMenu = new Container();
		speedMenuBg = new Graphics();
		speedMenu.addChild(speedMenuBg);
		var title = text("Vitesse", 12, CYAN_LIGHT);
		title.x = 12;
		title.y = 8;
		speedMenu.addChild(title);
		for (i in 0...SPEEDS.length) {
			var s = SPEEDS[i];
			var t = text(s == 1 ? "Normale" : speedLabel(s), 14, 0xFFFFFF);
			t.anchor.set(0, 0.5);
			t.x = 30;
			t.y = 40 + i * 26;
			speedMenu.addChild(t);
			speedItems.push({speed: s, text: t});
		}
		speedMenu.visible = false;
		addChild(speedMenu);
	}

	inline function menuW():Float
		return 124;

	inline function menuH():Float
		return 28 + SPEEDS.length * 26;

	function menuX():Float
		return W - 8 - menuW();

	function menuY():Float
		return BOTTOM - PANEL_H + 8 - menuH();

	function drawSpeedMenu():Void {
		speedMenu.x = menuX();
		speedMenu.y = menuY();
		var g = speedMenuBg;
		g.clear();
		g.beginFill(DARK, 0.92);
		g.drawRoundedRect(0, 0, menuW(), menuH(), 10);
		g.endFill();
		var hover = menuItemAt(pointerX, pointerY);
		for (i in 0...speedItems.length) {
			var it = speedItems[i];
			var y = it.text.y;
			if (hover == i) {
				g.beginFill(0xFFFFFF, 0.12);
				g.drawRect(0, y - 13, menuW(), 26);
				g.endFill();
			}
			if (it.speed == speed) {
				g.lineStyle(2, CYAN, 1);
				g.moveTo(11, y);
				g.lineTo(15, y + 4);
				g.lineTo(22, y - 5);
				g.lineStyle(0);
			}
		}
	}

	function menuItemAt(x:Float, y:Float):Int {
		if (!menuOpen)
			return -1;
		var lx = x - menuX();
		var ly = y - menuY();
		if (lx < 0 || lx > menuW())
			return -1;
		for (i in 0...speedItems.length)
			if (Math.abs(ly - speedItems[i].text.y) <= 13)
				return i;
		return -1;
	}

	function inMenu(x:Float, y:Float):Bool {
		return menuOpen && x >= menuX() && x <= menuX() + menuW() && y >= menuY() && y <= menuY() + menuH();
	}

	function changeSpeed(dir:Int):Void {
		var i = 0;
		for (j in 0...SPEEDS.length)
			if (Math.abs(SPEEDS[j] - speed) < 1e-6)
				i = j;
		i = Std.int(Math.max(0, Math.min(SPEEDS.length - 1, i + dir)));
		setSpeed(SPEEDS[i]);
	}

	function setSpeed(s:Float):Void {
		speed = s;
		host.setSpeed(s);
		drawnButtons = "";
		if (menuOpen)
			drawSpeedMenu();
	}

	static function speedLabel(s:Float):String {
		return StringTools.replace(Std.string(s), ".", ",") + "×";
	}

	// HELP

	function initHelp():Void {
		help = new Container();
		var rows = [
			["Espace ou K", "Lecture / pause"],
			["← / →", "Reculer / avancer de 5 s"],
			["J / L", "Reculer / avancer de 10 s"],
			[", / .", "Image précédente / suivante"],
			["< / >", "Ralentir / accélérer"],
			["0 à 9", "Aller de 0 à 90 %"],
			["Début / Fin", "Début / fin du replay"],
			["I", "Touches du joueur"],
			["C", "Commentaires"],
			["H", "Cette aide"],
		];
		var w = 380;
		var h = 70 + rows.length * 23 + 24;
		var bg = new Graphics();
		bg.beginFill(DARK, 0.94);
		bg.drawRoundedRect(0, 0, w, h, 14);
		bg.endFill();
		help.addChild(bg);
		var title = text("Raccourcis clavier", 17, 0xFFFFFF);
		title.x = 20;
		title.y = 16;
		help.addChild(title);
		for (i in 0...rows.length) {
			var y = 56 + i * 23;
			var k = text(rows[i][0], 13, CYAN_LIGHT);
			k.anchor.set(1, 0);
			k.x = 130;
			k.y = y;
			help.addChild(k);
			var d = text(rows[i][1], 13, 0xCCCCCC, false);
			d.x = 146;
			d.y = y;
			help.addChild(d);
		}
		var foot = text("Clic sur le jeu : lecture / pause", 12, 0x999999, false);
		foot.x = 20;
		foot.y = h - 30;
		help.addChild(foot);
		help.x = Std.int((W - w) * 0.5);
		help.y = Std.int((BOTTOM - PANEL_H - h) * 0.5 + 10);
		help.visible = false;
		addChild(help);
	}

	function toggleHelp():Void {
		helpOpen = !helpOpen;
		help.visible = helpOpen;
		menuOpen = false;
		speedMenu.visible = false;
		drawnButtons = "";
	}

	// KEYS OF THE PLAYER

	function initKeys():Void {
		keysPanel = new Container();
		keysBg = new Graphics();
		keysPanel.addChild(keysBg);
		keysCaps = new Graphics();
		keysPanel.addChild(keysCaps);
		var keys = replay.getReplayKeys();
		mouseButtons = replay.getReplayMouseButtons();
		var arrows = [for (k in keys) if (k >= 37 && k <= 40) k].length > 0;
		var x = 0.0;
		var row = CAP + CAP_GAP;
		if (arrows) {
			// the arrows always shown together, like on a keyboard
			addCap(38, row, 0, CAP, 0);
			addCap(37, 0, row, CAP, 3);
			addCap(40, row, row, CAP, 2);
			addCap(39, row * 2, row, CAP, 1);
			x = row * 3 + 6;
		}
		var others = [for (k in keys) if (k < 37 || k > 40) k];
		var top = others.length > 4 && arrows ? others.length - 4 : 0;
		var x0 = x;
		var xTop = x0;
		for (i in 0...others.length) {
			var label = text(keyLabel(others[i]), 11, 0xFFFFFF);
			label.anchor.set(0.5, 0.5);
			var w = Math.max(CAP, label.width + 12);
			if (i < top) {
				addCap(others[i], xTop, 0, w, -1, label);
				xTop += w + CAP_GAP;
			} else {
				addCap(others[i], x, arrows ? row : 0, w, -1, label);
				x += w + CAP_GAP;
			}
		}
		x = Math.max(x, xTop);
		if (mouseButtons.length > 0) {
			mouseIconX = x + (x > 0 ? 3 : 0);
			x = mouseIconX + 20;
		}
		keysW = x;
		keysH = arrows || top > 0 ? row + CAP : CAP;
		if (mouseButtons.length > 0)
			keysH = Math.max(keysH, 28);
		keysBg.beginFill(DARK, 0.4);
		keysBg.drawRoundedRect(-6, -6, keysW + 12, keysH + 12, 8);
		keysBg.endFill();
		keysPanel.x = 10;
		keysPanel.visible = false;
		addChild(keysPanel);
	}

	function addCap(code:Int, x:Float, y:Float, w:Float, arrow:Int, ?label:Text):Void {
		if (label != null) {
			label.x = x + w * 0.5;
			label.y = y + CAP * 0.5;
			keysPanel.addChild(label);
		}
		caps.push({
			code: code,
			x: x,
			y: y,
			w: w,
			label: label,
			arrow: arrow
		});
	}

	function hasKeys():Bool {
		return caps.length > 0 || mouseButtons.length > 0;
	}

	function updateKeys():Void {
		var on = keysOn && hasKeys();
		keysPanel.visible = on;
		if (on) {
			// above the controls when they show
			keysPanel.y = Math.round(BOTTOM - 14 - keysH - (PANEL_H - 22) * shown);
			var mask = 0;
			for (i in 0...caps.length)
				if (common_haxe_avm1.KeyboardManager.isDown(caps[i].code))
					mask |= 1 << i;
			for (i in 0...mouseButtons.length)
				if (common_haxe_avm1.MouseManager.isButtonDown(mouseButtons[i]))
					mask |= 1 << (caps.length + i);
			if (mask != keysMask) {
				keysMask = mask;
				drawCaps(mask);
			}
		}
		drawCursorMark(on);
	}

	function drawCaps(mask:Int):Void {
		var g = keysCaps;
		g.clear();
		for (i in 0...caps.length) {
			var c = caps[i];
			var down = (mask & (1 << i)) != 0;
			g.lineStyle(1, down ? CYAN : 0xFFFFFF, down ? 1 : 0.35);
			g.beginFill(down ? CYAN : DARK, down ? 1 : 0.55);
			g.drawRoundedRect(c.x, c.y, c.w, CAP, 4);
			g.endFill();
			g.lineStyle(0);
			if (c.arrow >= 0) {
				var cx = c.x + c.w * 0.5;
				var cy = c.y + CAP * 0.5;
				var a = c.arrow * Math.PI * 0.5;
				var pts:Array<Float> = [];
				for (p in [[0.0, -5.0], [5.0, 3.0], [-5.0, 3.0]]) {
					pts.push(cx + p[0] * Math.cos(a) - p[1] * Math.sin(a));
					pts.push(cy + p[0] * Math.sin(a) + p[1] * Math.cos(a));
				}
				g.beginFill(0xFFFFFF, down ? 1 : 0.8);
				g.drawPolygon(pts);
				g.endFill();
			}
			if (c.label != null)
				c.label.alpha = down ? 1 : 0.85;
		}
		if (mouseButtons.length > 0) {
			// mouse: left and right halves light up with their button
			var x = mouseIconX;
			var left = mouseButtons.indexOf(0);
			var right = mouseButtons.indexOf(2);
			var leftDown = left >= 0 && (mask & (1 << (caps.length + left))) != 0;
			var rightDown = right >= 0 && (mask & (1 << (caps.length + right))) != 0;
			var y = keysH - 28;
			g.lineStyle(1.5, 0xFFFFFF, 0.8);
			g.beginFill(DARK, 0.55);
			g.drawRoundedRect(x, y, 20, 28, 9);
			g.endFill();
			g.lineStyle(0);
			if (leftDown) {
				g.beginFill(CYAN);
				g.drawRoundedRect(x + 1.5, y + 1.5, 8, 11, 4);
				g.endFill();
			}
			if (rightDown) {
				g.beginFill(CYAN);
				g.drawRoundedRect(x + 10.5, y + 1.5, 8, 11, 4);
				g.endFill();
			}
			g.lineStyle(1, 0xFFFFFF, 0.8);
			g.moveTo(x + 10, y);
			g.lineTo(x + 10, y + 13);
			g.moveTo(x, y + 13);
			g.lineTo(x + 20, y + 13);
			g.lineStyle(0);
		}
	}

	// where the player's mouse is, when the replay recorded it
	function drawCursorMark(on:Bool):Void {
		var m = on ? replay.getReplayMouse() : null;
		var down = m != null && mouseButtons.length > 0 && common_haxe_avm1.MouseManager.isButtonDown(mouseButtons[0]);
		var key = m == null ? "" : m.x + "," + m.y + (down ? "d" : "");
		if (key == cursorKey)
			return;
		cursorKey = key;
		var g = cursorMark;
		g.clear();
		if (m == null)
			return;
		// arrow pointer, orange while the button is down
		var x = m.x;
		var y = m.y;
		if (down) {
			g.lineStyle(2, ORANGE, 0.9);
			g.drawCircle(x, y, 10);
		}
		g.lineStyle(1.5, 0x000000, 0.9);
		g.beginFill(down ? ORANGE : 0xFFFFFF, 0.95);
		g.drawPolygon([
			x, y, x, y + 17, x + 4.5, y + 13, x + 7.5, y + 19.5, x + 10.5, y + 18, x + 7.5, y + 11.5, x + 12.5, y + 11.5
		]);
		g.endFill();
		g.lineStyle(0);
	}

	function toggleKeys():Void {
		keysOn = !keysOn;
		keysMask = -1;
		writePref(PREF_KEYS, keysOn);
		drawnButtons = "";
	}

	static function keyLabel(code:Int):String {
		return switch (code) {
			case 32: "Espace";
			case 13: "Entrée";
			case 16: "Maj";
			case 17: "Ctrl";
			case 18: "Alt";
			case 27: "Échap";
			case 9: "Tab";
			case 8: "Retour";
			case 46: "Suppr";
			default:
				if ((code >= 65 && code <= 90) || (code >= 48 && code <= 57)) String.fromCharCode(code); else if (code >= 96 && code <= 105) "Pavé "
					+ (code - 96); else if (code >= 112 && code <= 123) "F" + (code - 111); else "#" + code;
		}
	}

	// ACTIONS

	function togglePlay():Void {
		if (ended) {
			host.seek(0);
			host.setPaused(false);
			return;
		}
		host.setPaused(!paused);
		paused = !paused;
		drawnButtons = "";
	}

	function jump(seconds:Float):Void {
		var from = seekTarget != null ? seekTarget : frame;
		var f = Std.int(Math.round(Math.max(0, Math.min(total, from + seconds * 1000 / frameMs))));
		host.seek(f);
	}

	// POINTER

	function toGame(e:PointerEvent):{x:Float, y:Float} {
		var r = canvas.getBoundingClientRect();
		if (r.width <= 0 || r.height <= 0)
			return null;
		var screen = KadoKadeoManager.kkm.screen;
		return {
			x: (e.clientX - r.left) * screen.width / r.width,
			y: (e.clientY - r.top) * screen.height / r.height
		};
	}

	inline function onBar(x:Float, y:Float):Bool {
		return y >= BAR_Y - 11 && y <= BAR_Y + 11 && x >= BAR_X0 - 6 && x <= BAR_X1 + 6;
	}

	function onPointerDown(e:PointerEvent):Void {
		if (parent == null)
			return;
		var p = toGame(e);
		if (p == null || p.x < 0 || p.x > W || p.y < 0 || p.y >= BOTTOM)
			return;
		var touch = e.pointerType == "touch";
		e.preventDefault();
		e.stopImmediatePropagation();
		pointerX = p.x;
		pointerY = p.y;
		var t = now();
		// a tap on hidden controls only shows them
		if (touch && shown < 0.5 && !helpOpen) {
			lastActivity = t;
			return;
		}
		lastActivity = t;
		if (helpOpen) {
			toggleHelp();
			return;
		}
		if (menuOpen) {
			var i = menuItemAt(p.x, p.y);
			if (i >= 0)
				setSpeed(speedItems[i].speed);
			menuOpen = false;
			speedMenu.visible = false;
			drawnButtons = "";
			if (i >= 0 || buttonAt(p.x, p.y) == "speed")
				return;
		}
		var id = buttonAt(p.x, p.y);
		if (id != null) {
			pressButton(id);
			return;
		}
		if (onBar(p.x, p.y)) {
			dragging = true;
			dragPointer = e.pointerId;
			try {
				canvas.setPointerCapture(e.pointerId);
			} catch (_:Dynamic) {}
			return;
		}
		if (p.y >= BOTTOM - PANEL_H + 30)
			return;
		if (touch) {
			// a tap on the game shows / hides the controls
			if (shown > 0.5 && !paused)
				lastActivity = -HIDE_DELAY_MS;
			return;
		}
		if (!ended)
			togglePlay();
	}

	function onPointerMove(e:PointerEvent):Void {
		if (parent == null)
			return;
		var p = toGame(e);
		if (p == null)
			return;
		var inside = p.x >= 0 && p.x <= W && p.y >= 0 && p.y < BOTTOM;
		if (dragging) {
			if (e.pointerId == dragPointer) {
				pointerX = Math.max(BAR_X0, Math.min(BAR_X1, p.x));
				setHoverMarker(markerAt(pointerX));
			}
			return;
		}
		if (e.pointerType == "touch")
			return;
		pointerIn = inside;
		if (!inside) {
			setHover(null, false);
			return;
		}
		if (p.x != pointerX || p.y != pointerY)
			lastActivity = now();
		pointerX = p.x;
		pointerY = p.y;
		setHover(buttonAt(p.x, p.y), onBar(p.x, p.y));
		if (menuOpen)
			drawSpeedMenu();
	}

	function onPointerLeave(e:PointerEvent):Void {
		if (dragging)
			return;
		pointerIn = false;
		setHover(null, false);
		// the controls go away soon after the pointer left the game
		lastActivity = Math.min(lastActivity, now() - HIDE_DELAY_MS + 400);
	}

	function onPointerUp(e:PointerEvent):Void {
		if (!dragging || e.pointerId != dragPointer)
			return;
		dragging = false;
		dragPointer = null;
		var p = toGame(e);
		if (p != null)
			pointerX = Math.max(BAR_X0, Math.min(BAR_X1, p.x));
		lastActivity = now();
		hoverBar = e.pointerType != "touch" && p != null && onBar(p.x, p.y);
		// on a mark: exactly at its frame
		var mark = markerAt(pointerX);
		host.seek(mark >= 0 ? markers[mark] : frameAt(pointerX));
		if (!hoverBar)
			setHoverMarker(-1);
	}

	function setHover(button:String, bar:Bool):Void {
		if (button != hoverButton) {
			hoverButton = button;
			hoverSince = now();
			buttonTip.visible = false;
		}
		hoverBar = bar;
		setHoverMarker(bar && controls.visible ? markerAt(pointerX) : -1);
		setCursor(button != null || bar || inMenu(pointerX, pointerY) ? "pointer" : "");
	}

	function setCursor(c:String):Void {
		if (c != cursorStyle) {
			cursorStyle = c;
			canvas.style.cursor = c;
		}
	}

	// KEYBOARD

	function onKeyDown(e:KeyboardEvent):Void {
		if (parent == null || e.ctrlKey || e.metaKey || e.altKey || isTyping(e))
			return;
		var sec = 1000 / frameMs;
		var handled = true;
		switch (e.key) {
			case " " | "k" | "K" | "p" | "P":
				togglePlay();
			case "ArrowLeft":
				jump(-5);
			case "ArrowRight":
				jump(5);
			case "j" | "J":
				jump(-10);
			case "l" | "L":
				jump(10);
			case "Home":
				host.seek(0);
			case "End":
				host.seek(Std.int(total));
			case ",":
				host.step(-1);
			case ".":
				host.step(1);
			case "<":
				changeSpeed(-1);
			case ">":
				changeSpeed(1);
			case "i" | "I":
				toggleKeys();
			case "c" | "C":
				toggleComments();
			case "h" | "H" | "?":
				toggleHelp();
			case "Escape":
				handled = menuOpen || helpOpen;
				menuOpen = false;
				speedMenu.visible = false;
				if (helpOpen)
					toggleHelp();
				drawnButtons = "";
			default:
				handled = false;
				// 0..9: from 0 to 90 % (main keyboard, whatever the layout, and keypad)
				var c = e.code;
				if (c != null && (c.length == 6 && c.substr(0, 5) == "Digit" || c.length == 7 && c.substr(0, 6) == "Numpad")) {
					var n = Std.parseInt(c.substr(c.length - 1));
					if (n != null) {
						host.seek(Std.int(Math.round(total * n / 10)));
						handled = true;
					}
				}
		}
		if (!handled)
			return;
		e.preventDefault();
		lastActivity = now();
	}

	// a key typed in a field of the page is not for the replay
	static function isTyping(e:KeyboardEvent):Bool {
		var el:Element = cast e.target;
		if (el == null || el.tagName == null)
			return false;
		var tag = el.tagName.toUpperCase();
		return tag == "INPUT" || tag == "TEXTAREA" || tag == "SELECT" || el.isContentEditable;
	}

	// TOOLS

	function tipBox():Container {
		var c = new Container();
		c.addChild(new Graphics());
		var t = text("", 13, 0xFFFFFF);
		t.anchor.set(0.5, 0);
		c.addChild(t);
		c.visible = false;
		return c;
	}

	function showTip(box:Container, bg:Graphics, label:Text, s:String, x:Float, y:Float):Void {
		if (label.text != s)
			label.text = s;
		var w = label.width + 16;
		var h = label.height + 6;
		x = Math.max(w * 0.5 + 4, Math.min(W - w * 0.5 - 4, x));
		bg.clear();
		bg.beginFill(DARK, 0.92);
		bg.drawRoundedRect(-w * 0.5, 0, w, h, 6);
		bg.endFill();
		label.y = 3;
		box.x = Math.round(x);
		box.y = Math.round(y - h * 0.5);
		box.visible = true;
	}

	static function text(s:String, size:Int, color:Int, ?bold:Bool = true):Text {
		// Fredoka Bold is bold itself; the other texts stay lighter by their colour
		var t = new Text(s, {
			fill: color,
			fontFamily: FONT,
			fontSize: size
		});
		// Match the high-DPI renderer before measuring labels for the layout.
		t.resolution = KadoKadeoManager.kkm.renderer.resolution;
		return t;
	}

	// dark teal, transparent at the top: behind the controls
	static function gradientTexture():Texture {
		var c:CanvasElement = Browser.document.createCanvasElement();
		c.width = 1;
		c.height = 64;
		var ctx = c.getContext2d();
		var g = ctx.createLinearGradient(0, 0, 0, 64);
		g.addColorStop(0, "rgba(6,30,37,0)");
		g.addColorStop(0.55, "rgba(6,30,37,0.38)");
		g.addColorStop(1, "rgba(6,30,37,0.72)");
		ctx.fillStyle = g;
		ctx.fillRect(0, 0, 1, 64);
		return Texture.from(c);
	}

	static inline function approach(v:Float, target:Float, step:Float):Float {
		return v < target ? Math.min(target, v + step) : Math.max(target, v - step);
	}

	static inline function now():Float {
		return Browser.window.performance.now();
	}

	static function readPref(key:String, byDefault:Bool):Bool {
		try {
			var value = Browser.window.localStorage.getItem(key);
			return value == null ? byDefault : value == "1";
		} catch (_:Dynamic) {
			return byDefault;
		}
	}

	static function writePref(key:String, on:Bool):Void {
		try {
			Browser.window.localStorage.setItem(key, on ? "1" : "0");
		} catch (_:Dynamic) {}
	}
}
