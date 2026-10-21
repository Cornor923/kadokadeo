package rockfaller;

import pixi.core.Pixi.BlendModes;
import rockfaller.Game.CGroup;

// a cell of the 6 x 6 grid: its stone, maybe a tube (bottom row); selection, rotation and fall
class Slot {
	public static inline var SIZE = 60;
	public static inline var SEL_SCALE = 1.10;

	public var x:Int;
	public var y:Int;
	public var stone:Stone;
	public var exit:Exit;
	public var group:CGroup;
	public var selected:Bool = false;

	// the white glow of a selected stone (Filt.glow(stone.mc, 1.7, 10, 0xFFFFFF) of the original, baked: sprite glow),
	// under every stone
	var glow:ASprite;

	// fall
	public var waitFall:Int = 0;
	public var g:Float = 0;

	// wait before the shine (a diagonal wave: (x + y) * 0.1), null: none
	public var waitShine:Null<Float> = null;

	public function new(px:Int, py:Int) {
		x = px;
		y = py;
		stone = new Stone();
		setDefaultStonePos();
		Game.me.allSlots.push(this);
	}

	public function setExit(e:Exit):Void {
		if (exit != null)
			throw "can't set an exit on " + x + "," + y;
		exit = e;
		e.slot = this;
		e.setPos(x, y);
	}

	public function setDefaultStonePos():Void {
		var p = getStonePos(x, y);
		stone.mc._x = p.x;
		stone.mc._y = p.y;
	}

	public static function getStonePos(sx:Int, sy:Int):{x:Float, y:Float} {
		return {x: Game.STAGE_X + (sx + 0.5) * SIZE, y: Game.STAGE_Y + (sy + 0.5) * SIZE};
	}

	public function setStone(st:Stone, ?recal:Bool = true):Void {
		stone = st;
		if (recal)
			setDefaultStonePos();
	}

	// ------------------------------------------------------------------ selection
	public function select():Void {
		selected = true;
		var mc = stone.mc;
		// over the other stones
		Game.me.layerStones.addChild(mc);
		if (glow == null) {
			glow = new ASprite("glow");
			glow.blendMode = BlendModes.ADD;
		}
		Game.me.layerGlow.addChild(glow);
		syncGlow();
		// (put where the stone is: not slid from where it was last shown)
		glow.updateState();
	}

	// the glow follows the stone (its frame, position, scale of the selection, rotation)
	function syncGlow():Void {
		if (glow == null || glow.parent == null)
			return;
		var mc = stone.mc;
		glow.gotoAndStop(stone.isStone() ? 5 : stone.id + 1);
		glow._x = mc._x;
		glow._y = mc._y;
		glow._xscale = mc._xscale;
		glow._yscale = mc._yscale;
		glow._rotation = mc._rotation;
	}

	public function unselect():Void {
		if (!selected)
			return;
		selected = false;
		stone.mc._rotation = 0;
		if (glow != null && glow.parent != null)
			glow.parent.removeChild(glow);
	}

	public function setShine():Void {
		waitShine = (x + y) * 0.1;
	}

	// the scale of the selection (1 -> 1.10, smoothed), the shine when its wait is over
	public function update():Void {
		if (stone == null)
			return;
		if (waitShine != null) {
			waitShine -= 0.1;
			if (waitShine <= 0) {
				waitShine = null;
				stone.shine();
			}
		}
		var target = selected ? SEL_SCALE : 1.0;
		var cur = stone.mc._xscale / 100;
		if (Math.abs(cur - target) > 0.004)
			cur += (target - cur) * 0.4;
		else
			cur = target;
		stone.mc._xscale = stone.mc._yscale = cur * 100;
		if (selected)
			syncGlow();
	}

	// ------------------------------------------------------------------ rotation: to the next cell, clockwise
	public function rotate(dIdx:Int):Void {
		stone.mc._rotation = 0;
		var nSlot = Game.me.grid[x + Game.DIRS[dIdx][0]][y + Game.DIRS[dIdx][1]];
		var dest = getStonePos(nSlot.x, nSlot.y);
		Game.me.waitingFx++;
		Game.me.tweenTo(stone.mc, dest.x, dest.y, 5, function() Game.me.waitDone());
	}

	// ------------------------------------------------------------------ fall (Slot.fall of the original)
	public function setFall(?wait:Int = 0):Void {
		waitFall = wait;
		g = 1.4;
		Game.me.falls.push(this);
	}

	public function fall():Void {
		if (waitFall > 0) {
			waitFall--;
			return;
		}
		var nPos = getStonePos(x, y);
		var t = Math.min(10.0 + g, nPos.y - stone.mc._y);
		g = Math.min(g * g, 25.0);
		stone.mc._y = stone.mc._y + t;
		if (nPos.y - stone.mc._y < 4) {
			stone.mc._y = nPos.y;
			Game.me.falls.remove(this);
			stone.breakIt();
			Game.me.onStoneLanded();
		}
	}

	// ------------------------------------------------------------------ destroyed / taken by a tube
	public function vanishStone():Void {
		if (stone == null)
			return;
		stone.kill();
		stone = null;
	}

	public function removeStone():Void {
		if (stone == null)
			return;
		stone.kill();
		stone = null;
	}

	public function killGroup():Void {
		group = null;
	}
}
