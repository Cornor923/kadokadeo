package chocomouche;

import pixi.filters.extras.GlowFilter;
import mt.bumdum.Phys;
import mt.bumdum.Lib;
import chocomouche.Game.Pos;

enum Status {
	Hidden;
	Marked;
	Discovered;
	Exploded;
}

enum Hide {
	Nothing;
	Bomb;
}

class Slot extends Phys {
	public static var MC_DEFAULT = 9;
	public static var MC_EMPTY = 10;
	public static var MC_MARKED = 11;
	public static var MC_BOMB = 12;

	public static var adjacentDir = [
		{x: -1, y: 0},
		{x: -1, y: -1},
		{x: 0, y: -1},
		{x: 1, y: -1},
		{x: 1, y: 0},
		{x: 1, y: 1},
		{x: 0, y: 1},
		{x: -1, y: 1}
	];

	public var pos:Pos;
	public var state:Status;
	public var hide:Hide;
	public var parsed:Bool;
	public var adjNumber:Int;

	var dm:mt.DepthManager;
	var glow:GlowFilter;

	public var slot:ASprite;

	var partsPool:Array<PooledPart>;

	static inline var PARTS_POOL_SIZE = 7;
	static var activeParts:Int = 0;

	public function new(p:Pos, isBomb:Bool) {
		var mc = Game.me.gdm.empty(Game.DP_SLOT);
		super(mc);
		pos = p;
		state = Hidden;
		hide = if (isBomb) Bomb else Nothing;
		parsed = false;
		mc.getGraphics().beginFill(1, 0);
		mc.getGraphics().moveTo(0, 0);
		mc.getGraphics().lineTo(Cs.SLOT_SIZE, 0);
		mc.getGraphics().lineTo(Cs.SLOT_SIZE, Cs.SLOT_SIZE);
		mc.getGraphics().lineTo(0, Cs.SLOT_SIZE);
		mc.getGraphics().lineTo(0, 0);
		mc.getGraphics().endFill();

		dm = new mt.DepthManager(mc);
		slot = dm.attach("slot", 1);
		slot.anchor.set(0.5, 0.5);
		slot.gotoAndStop(MC_DEFAULT);
		mc._x = Cs.GRID_X + pos.x * Cs.SLOT_SIZE;
		mc._y = Cs.GRID_Y + pos.y * Cs.SLOT_SIZE;

		// (onRollOver = slotOver, onRollOut = slotOut, onPress = imPressed, onRelease = imClicked, onReleaseOutside =
		// imReleased: the mouse is polled, Game.pollMouse; only the hand cursor here)
		mc.interactive = true;
		mc.buttonMode = true;
		common_haxe_avm1.KKApi.registerButton(mc);
		initPartsPool();
		// ### TO CONTINUE
	}

	function initPartsPool() {
		partsPool = [];
		for (i in 0...PARTS_POOL_SIZE) {
			var partMc = Game.me.dm.attach("partSlot", Game.DP_FX);
			partMc._xscale = 170;
			partMc._yscale = 170;
			var part = new PooledPart(partMc);
			part.deactivate();
			partsPool.push(part);
		}
	}

	override public function kill() {
		for (part in partsPool) {
			part.destroy();
		}
		partsPool = [];
		glow = null;
		super.kill();
	}

	public function slotOver() {
		if (Game.me.isLocked() || isDiscovered())
			return;

		if (glow == null) {
			glow = Filt.glow(slot, 6, 3, 0xEAD989, true);
		} else {
			slot.filters = [glow];
		}
	}

	public function slotOut() {
		slot.filters = null;
	}

	public function resetParse() {
		parsed = false;
	}

	public function isBomb():Bool {
		return hide == Bomb /*&& (if (hidden == null || !hidden) true else state == Hidden)*/;
	}

	public function placeBomb() {
		hide = Bomb;
	}

	public function isDiscovered():Bool {
		return state == Discovered;
	}

	function canBeClicked():Bool {
		return isDiscovered() || Game.me.isLocked();
	}

	function getAdjacentBomb():Int {
		var count = 0;

		for (d in adjacentDir) {
			var slot = Game.me.getSlot(pos.x + d.x, pos.y + d.y);
			if (slot == null)
				continue;
			if (slot.isBomb())
				count++;
		}

		return count;
	}

	public function imPressed() {
		if (canBeClicked())
			return;

		slot._xscale = 92;
		slot._yscale = 92;
	}

	public function imReleased() {
		if (canBeClicked())
			return;

		slotOut();
		slot._xscale = 100;
		slot._yscale = 100;
	}

	public function imClicked() {
		if (canBeClicked())
			return;

		Game.me.stats.c[Game.me.stats.c.length - 1]++;
		Game.me.recordSlotClick(pos);

		imReleased();

		/*	if (Key.isDown(Key.CONTROL))
				markMe() ;
			else
				show() ; */

		switch (state) {
			case Hidden:
				markMe();
			case Marked:
				show();
			case Discovered:
			case Exploded:
		}
	}

	public function markMe() {
		if (state == Hidden) {
			state = Marked;
			slot.gotoAndStop(MC_MARKED);
		}
		/*else if (state == Marked) {
			state = Hidden ;
			slot.gotoAndStop(MC_DEFAULT) ;
		}*/
	}

	public function discoverBomb() {
		state = Discovered;
		launchParts();
		slot.gotoAndStop(if (isBomb()) MC_BOMB else MC_EMPTY);
	}

	public function discover():Bool {
		state = Discovered;
		var n = getAdjacentBomb();
		Game.me.stats.d[Game.me.stats.d.length - 1].push(n);
		slot.gotoAndStop(if (n == 0) MC_EMPTY else n);
		if (n > 0)
			launchParts();

		if (hide == Nothing)
			Game.me.left--;

		return n == 0;
	}

	function show() {
		var bomb = false;

		if (Game.me.left == 100) // first click : have to initialize board
			Game.me.prepareLevel(pos);

		switch (hide) {
			case Nothing:
				if (discover())
					discoverZone(true);
			case Bomb:
				discoverBomb();
				bomb = true;
				Game.me.explode(pos);
				Game.me.stats.d[Game.me.stats.d.length - 1].push(-1);
		}
		Game.me.resetTime(bomb);
	}

	// PARSING
	public function discoverZone(?isFirst:Bool) {
		if (parsed)
			return;
		parsed = true;

		for (d in adjacentDir) {
			var slot = Game.me.getSlot(pos.x + d.x, pos.y + d.y);
			if (slot == null || slot.isDiscovered() || slot.isBomb())
				continue;
			if (slot.discover())
				slot.discoverZone();
		}

		if (isFirst != null && isFirst) {
			Game.me.resetParsing();
			Game.me.checkLevel();
		}
	}

	// ### PARTS
	function launchParts() {
		var nb = 4 + Seed.randomVfx(4);
		var px = x;
		var py = y;

		for (i in 0...nb) {
			if (activeParts > 40 && i > 3)
				break;

			var s = getFreePart();
			if (s == null)
				break;

			var dx = (Seed.randVfx() * 2 - 1) * 18;
			var dy = (Seed.randVfx() * 2 - 1) * 18;

			s.activate();
			s.root.gotoAndStop(Seed.randomVfx(4) + 1);
			s.x = px + dx;
			s.y = py + dy;
			// s.weight = 0.1 ;
			s.alpha = 95;
			s.frict = 0.90;
			s.vx = dx;
			s.vy = dy;
			s.vr = (Seed.randVfx() * 2 - 1) * 20;
			s.fadeType = 3;
			s.timer = 15 + Seed.randomVfx(6);
		}
	}

	function getFreePart():PooledPart {
		for (part in partsPool) {
			if (!part.active)
				return part;
		}
		return null;
	}

	public static function onPartActivated() {
		activeParts++;
	}

	public static function onPartDeactivated() {
		if (activeParts > 0)
			activeParts--;
	}
}

private class PooledPart extends Phys {
	public var active:Bool;

	public function new(mc:ASprite) {
		super(mc);
		active = false;
	}

	override public function update() {
		if (!active)
			return;
		super.update();
	}

	public function activate() {
		if (active)
			return;
		active = true;
		root._visible = true;
		root._alpha = 100;
		root._xscale = 170;
		root._yscale = 170;
		Slot.onPartActivated();
		root.updateState();
	}

	public function deactivate() {
		if (!active) {
			root._visible = false;
			return;
		}
		active = false;
		vx = 0;
		vy = 0;
		vr = 0;
		timer = null;
		root._visible = false;
		Slot.onPartDeactivated();
	}

	override public function kill() {
		deactivate();
	}

	public function destroy() {
		deactivate();
		super.kill();
	}
}
