package flushee;

import common_haxe_avm1.KKApi;
import common_haxe_avm1.MouseManager;
import haxe.io.UInt16Array;
import kado.KadoKadeoManager;
import kado.Seed;
import mt.DepthManager;
import mt.Timer;

@:expose('GameFlushee')
class Game implements kado.GameInterface {
	public var dmanager:DepthManager;

	var pcount:ASprite;
	var gems:Array<Array<Gem>>;
	var cur:Gem;
	var next_cur:Gem;
	var tokens:Int;
	var ngems:Int;
	var cur_side:Bool;

	public var moves:Array<Gem>;

	var lock:Bool;
	var wait_fall:Bool;
	var turn:Int;
	var tottokens:Int;
	var combo_score:Int;
	var scores:Array<Int>;
	var turns:Array<Int>;
	var groups:Array<Array<Gem>>;

	public var parts:Array<Particule>;

	var stats:{n:Int, s:Array<Int>, t:Array<Int>};

	var start_timer:Float;
	var isReplayMode:Bool;
	var hoverSide:Bool;
	var hoverY:Int;
	// replay: its events with their frame, and the next one to apply
	var replayEvents:Array<{frame:Int, event:Dynamic}>;
	var replayCursor:Int;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		isReplayMode = isReplay;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: new UInt16Array(0),
			recordInputs: false,
			recordEvents: true,
		});
		replayEvents = isReplay ? KadoKadeoManager.kkm.replay.getReplayEvents() : [];
		replayCursor = 0;

		dmanager = new DepthManager(root);
		dmanager.attach("bg", 0);
		start_timer = 1;
		var pf = dmanager.attach("plateforme", Cs.PLAN_INTERF);
		var hs = dmanager.attach("herbShade", 0);
		pcount = dmanager.attach("playCount", Cs.PLAN_INTERF);
		pcount._x = KadoKadeoManager.I(70); // 150
		pcount._y = KadoKadeoManager.I(10); // 280
		pf._x = Cs.POSX;
		pf._y = Cs.YFALAISE;
		hs._x = Cs.POSX;
		hs._y = Cs.YFALAISE;
		tottokens = 0;
		tokens = Cs.NTOKENS;
		ngems = Cs.NGEMS;
		lock = true;
		scores = new Array();
		turns = new Array();
		moves = new Array();
		parts = new Array();
		updateTokens();
		initLevel();
		hoverSide = true;
		hoverY = 0;
		setCur(new Gem(this, randId(), -1, 0));
	}

	function randId():Int {
		return Seed.random(Cs.NGEMS - 1);
	}

	function randSpecial(oldid:Int):Int {
		var id:Int;
		if (Seed.random(10) == 0) {
			if (Seed.random(10) == 0)
				return Cs.ID_TOKENS;
			return Cs.ID_BONUS;
		}
		do {
			id = Seed.random(Cs.NGEMS);
		} while (id == oldid);
		return id;
	}

	function setCur(g:Gem):Void {
		cur = g;
		cur.group = null;
		cur.py = g.mc._y;
		cur_side = (cur.mc._x < KadoKadeoManager.I(150));
	}

	function makeGroupsRec(b:Gem, x:Int, y:Int, g:Array<Gem>):Void {
		var id = b.id;
		b.group = g;
		g.push(b);
		if (x - 1 >= 0) {
			b = gems[x - 1][y];
			if (b != null && b.id == id && b.group == null)
				makeGroupsRec(b, x - 1, y, g);
		}
		if (x + 1 < Cs.LVL_WIDTH) {
			b = gems[x + 1][y];
			if (b != null && b.id == id && b.group == null)
				makeGroupsRec(b, x + 1, y, g);
		}
		if (y - 1 >= 0) {
			b = gems[x][y - 1];
			if (b != null && b.id == id && b.group == null)
				makeGroupsRec(b, x, y - 1, g);
		}
		if (y + 1 < Cs.LVL_HEIGHT) {
			b = gems[x][y + 1];
			if (b != null && b.id == id && b.group == null)
				makeGroupsRec(b, x, y + 1, g);
		}
	}

	function makeGroups():Bool {
		for (x in 0...Cs.LVL_WIDTH)
			for (y in 0...Cs.LVL_HEIGHT)
				if (gems[x][y] != null)
					gems[x][y].group = null;
		groups = new Array();
		var exists = false;
		for (x in 0...Cs.LVL_WIDTH)
			for (y in 0...Cs.LVL_HEIGHT) {
				var g = gems[x][y];
				if (g != null && g.group == null) {
					var grp = new Array();
					makeGroupsRec(g, x, y, grp);
					if (grp.length == 1)
						g.group = null;
					else
						groups.push(grp);
					exists = true;
				}
			}
		return exists;
	}

	function initLevel():Void {
		gems = new Array();
		for (x in 0...Cs.LVL_WIDTH) {
			gems[x] = new Array();
			for (y in 0...Cs.LVL_HEIGHT)
				gems[x][y] = new Gem(this, randId(), x, y);
		}
		var cont = true;
		while (cont) {
			makeGroups();
			cont = false;
			for (g in groups) {
				if (g.length > Cs.NEXPLS - 1 && g[0].id < Cs.ID_BONUS) {
					cont = true;
					var b = g[Seed.random(g.length)];
					b.setId(randSpecial(b.id));
				}
			}
		}
	}

	function onClick(side:Bool, y:Int):Void {
		if (lock || wait_fall)
			return;
		cur.x = side ? -1 : Cs.LVL_WIDTH;
		cur.y = y;
		cur.setPos(cur.x, cur.y);
		if (side) {
			next_cur = gems[Cs.LVL_WIDTH - 1][cur.y];
			next_cur.move(Cs.LVL_WIDTH, cur.y);
			var x = Cs.LVL_WIDTH - 1;
			while (x > 0) {
				var g = gems[x - 1][cur.y];
				gems[x][cur.y] = g;
				g.move(x, cur.y);
				x--;
			}
			gems[0][cur.y] = cur;
			cur.move(0, cur.y);
		} else {
			next_cur = gems[0][cur.y];
			next_cur.move(-1, cur.y);
			var x = 0;
			while (x < Cs.LVL_WIDTH - 1) {
				var g = gems[x + 1][cur.y];
				gems[x][cur.y] = g;
				g.move(x, cur.y);
				x++;
			}
			gems[Cs.LVL_WIDTH - 1][cur.y] = cur;
			cur.move(Cs.LVL_WIDTH - 1, cur.y);
		}
		dmanager.over(next_cur.mc);
		cur = null;
		combo_score = 0;
		lock = true;
		wait_fall = true;
		turn = 1;
		tokens = KKApi.cadd(tokens, Cs.MINUS_ONE);
		tottokens++;
		updateTokens();
	}

	function applyHover(side:Bool, y:Int):Void {
		hoverSide = side;
		hoverY = y;
	}

	function applyReplayEvent(event:Dynamic):Void {
		if (event == null)
			return;

		var kind:Null<Int> = Reflect.field(event, "k");
		var side:Null<Bool> = Reflect.field(event, "side");
		var y:Null<Int> = Reflect.field(event, "y");
		if (kind == null || side == null || y == null)
			return;

		switch (kind) {
			case 0:
				applyHover(side, y);
			case 1:
				onClick(side, y);
			case _:
		}
	}

	// replay: the live game applies a hover / click at once, where it reads the mouse (recordHover, recordClick), and
	// the manager records it on the next frame (recordEvent without a frame). Applied at the same point of the frame
	// before the one it is recorded on, not at the start of that one (consumeEvents): the gems of the step moved
	// meanwhile, a click did not drop the token at the same moment, the replay gave another score.
	function applyReplayEventsOfStep():Void {
		var frame = KadoKadeoManager.kkm.replay.getCurrentFrame() + 1;
		while (replayCursor < replayEvents.length && replayEvents[replayCursor].frame <= frame) {
			applyReplayEvent(replayEvents[replayCursor].event);
			replayCursor++;
		}
	}

	function recordHover(side:Bool, y:Int):Void {
		if (isReplayMode || side == hoverSide && y == hoverY)
			return;
		KadoKadeoManager.kkm.replay.recordEvent({k: 0, side: side, y: y});
		applyHover(side, y);
	}

	function recordClick(side:Bool, y:Int):Void {
		if (isReplayMode)
			return;
		KadoKadeoManager.kkm.replay.recordEvent({k: 1, side: side, y: y});
		onClick(side, y);
	}

	function updateTokens():Void {
		pcount.gotoAndStop(KKApi.val(tokens) + 1);
	}

	function explode():Bool {
		var expl = false;
		makeGroups();
		for (g in groups) {
			if (g.length > Cs.NEXPLS - 1 && g[0].id < Cs.ID_BONUS) {
				expl = true;
				for (b in g) {
					gems[b.x][b.y] = null;
					b.explode();
				}
				var s = KKApi.val(Cs.CMULT) * (g.length - 1) * turn;
				combo_score += s;
				KadoKadeoManager.kkm.addScore(KKApi.const(s));
			}
		}
		turn++;
		return expl;
	}

	function gravity():Bool {
		var grav = false;
		for (x in 0...Cs.LVL_WIDTH) {
			var space = false;
			var y = Cs.LVL_HEIGHT - 1;
			while (y >= 0) {
				var b = gems[x][y];
				if (b == null)
					space = true;
				else if (space) {
					grav = true;
					gems[x][y + 1] = b;
					gems[x][y] = null;
					b.gravity();
				}
				y--;
			}
		}
		return grav;
	}

	function fills():Bool {
		var generated = new Array();
		for (x in 0...Cs.LVL_WIDTH) {
			var first = null;
			var y = Cs.LVL_HEIGHT - 1;
			while (y >= 0) {
				if (gems[x][y] == null) {
					if (first == null)
						first = y + 1;
					var g = new Gem(this, randId(), x, y - first);
					generated.push(g);
					g.fall(y);
					gems[x][y] = g;
				}
				y--;
			}
		}

		if (generated.length == 0)
			return false;

		generated = shuffle(generated);

		var fl = true;
		while (fl) {
			fl = false;
			makeGroups();
			for (g in generated) {
				if (g.group != null && g.group.length > Cs.NEXPLS - 1 && g.id < Cs.ID_BONUS) {
					g.group.splice(0, 100);
					g.setId(randSpecial(g.id));
					fl = true;
				}
			}
		}
		return true;
	}

	function shuffle<T>(list:Array<T>):Array<T> {
		var i = list.length;
		while (i > 1) {
			i--;
			var j = Seed.random(i + 1);
			var tmp = list[i];
			list[i] = list[j];
			list[j] = tmp;
		}
		return list;
	}

	function nextMove():Void {
		if (next_cur != null) {
			setCur(next_cur);
			next_cur = null;
		}

		if (gravity())
			return;

		if (explode())
			return;

		if (fills())
			return;

		scores.push(combo_score);
		turns.push(turn);

		if (KKApi.val(tokens) == 0 && (cur.id == null || cur.id < Cs.ID_BONUS)) {
			dmanager.getMC().cursor = "default";
			stats = {n: tottokens, s: scores, t: turns};
			KadoKadeoManager.kkm.gameOver(stats);
			return;
		}

		lock = false;
	}

	function attachGloup(n:Int):Void {
		var mc = dmanager.attach("bloub", Cs.PLAN_INTERF);
		mc._x = (cur.x > 0) ? (KadoKadeoManager.I(16) + Cs.POSX - Cs.CELL_SIZE) : KadoKadeoManager.I(300 - 45 + 25);
		mc._y = KadoKadeoManager.I(300);
		mc.play();
		mc.removeOnFrame = 63;

		var b = dmanager.attach("bonus" + n, Cs.PLAN_INTERF);
		b.play();
		var compt = 20;
		b.onFrame.set(7, function() {
			compt = 20;
		});
		b.onFrame.set(9, function() {
			compt--;
			if (compt > 0) {
				b.gotoAndPlay(8);
			}
		});
		b.removeOnFrame = 16;
		b._x = Cs.POSX;
		b._y = Cs.YFALAISE - KadoKadeoManager.I(6);
	}

	public function update(delta:Float):Void {
		if (start_timer > 0) {
			start_timer -= Timer.deltaT;
			if (start_timer <= 0)
				lock = false;
		}

		var i = 0;
		while (i < moves.length) {
			var m = moves[i];
			if (!m.update()) {
				m.px = m.mc._x;
				m.py = m.mc._y;
				moves.splice(i--, 1);
				if (moves.length == 0)
					nextMove();
			}
			i++;
		}

		i = 0;
		while (i < parts.length) {
			if (!parts[i].update())
				parts.splice(i--, 1);
			i++;
		}

		var side = (MouseManager.getX() < KadoKadeoManager.I(150));
		var cy = Std.int(Math.max(Math.min((MouseManager.getY() - Cs.POSY) / Cs.CELL_SIZE, Cs.LVL_HEIGHT - 1), 0));
		if (isReplayMode)
			applyReplayEventsOfStep();
		recordHover(side, cy);

		side = hoverSide;
		cy = hoverY;
		if (MouseManager.isButtonJustPressed(MouseManager.BUTTON_LEFT))
			recordClick(side, cy);

		if (cur == null)
			return;

		var ty:Float;
		if (side != cur_side || KKApi.val(tokens) == 0 || cur.id >= Cs.ID_BONUS)
			ty = KadoKadeoManager.I(350);
		else
			ty = Cs.POSY + Cs.CELL_SIZE * cy;

		var p = Math.pow(0.7, Timer.tmod);
		cur.x = side ? -1 : Cs.LVL_WIDTH;
		cur.y = cy;
		cur.py = cur.py * p + ty * (1 - p);

		if (Math.abs(cur.py - ty) < KadoKadeoManager.I(2) || (ty == KadoKadeoManager.I(350) && cur.py > KadoKadeoManager.I(300))) {
			cur.py = ty;
			wait_fall = false;
			if (cur.id == Cs.ID_BONUS) {
				attachGloup(1);
				tokens = KKApi.cadd(tokens, Cs.SMALL_BONUS);
				KadoKadeoManager.kkm.addScore(Cs.C1000);
				updateTokens();
				cur.setId(randId());
			} else if (cur.id == Cs.ID_TOKENS) {
				attachGloup(2);
				tokens = KKApi.cadd(tokens, Cs.BIG_BONUS);
				if (KKApi.val(tokens) > KKApi.val(Cs.NTOKENS))
					tokens = Cs.NTOKENS;
				updateTokens();
				cur.setId(randId());
			} else {
				if (side != cur_side) {
					cur_side = side;
					cur.setPos(cur.x, null);
				}
			}
		}
		cur.mc._y = cur.py;
	}

	public function destroy():Void {}
}
