package opalus2;

import haxe.io.UInt16Array;
import mt.bumdum.Sprite;
import common_haxe_avm1.KKApi;
import common_haxe_avm1.MouseManager;
import mt.bumdum.Lib;
import mt.DepthManager;
import mt.Timer;
import pixi.core.math.shapes.Rectangle;
import pixi.core.text.Text;

class GridElem extends ASprite {
	public var flDead:Bool;
}

class CounterSprite extends ASprite {
	public var field:Text;
	public var a:Float;
	public var ta:Float;
}

@:expose('GameOpalus2')
class Game implements kado.GameInterface {
	public static var DP_FRUIT = 2;
	public static var DP_PART = 3;

	public static var BLAST_TIME = 6;
	public static var FALL_WAIT = 20;
	public static var HAND_SPEED_COEF = 0.3;
	public static var CULL_MARGIN = 8;
	public static var CULL_RANGE = 1.6;
	public static var CULL_BOOST = 5;
	public static var PANEL_OFFSET_X = -30;
	public static var PANEL_OFFSET_Y = -30;

	public static var FL_ENLIGHT = true;

	public var step:Int;
	public var turn:Int;
	public var bonus:Int;
	public var timer:Float;
	public var glowDec:Float;

	public var zlim:{
		xmin:Float,
		xmax:Float,
		ymin:Float,
		ymax:Float
	};

	public var zone:Array<{x:Int, y:Int}>;
	public var zoneMap:Array<Array<Bool>>;
	public var sel:Array<Array<{x:Int, y:Int}>>;
	public var dList:Array<{x:Int, y:Int}>;
	public var selectableMap:Array<Array<Bool>>;

	public var dm:DepthManager;
	public var gdm:DepthManager;

	var stats:{
		l:Array<Array<Int>>, // [colorType, colorCount, fallenCount] for each turn
		f:Array<Array<Int>>, // fallenCount per color for each turn: [[fallenCount1, fallenCount2, ...], [fallenCount1, fallenCount2, ...], ...]
		mm:Array<Int>, // min/max uncovered balls [xmin, ymin, xmax, ymax]
	};

	var glow:Array<ASprite>;
	var fList:Array<Part>;
	var bg:ASprite;
	var bgHoleFilter:Dynamic;
	var map:ASprite;
	var panel:CounterSprite;
	var hoverColor:Int;
	var isReplayMode:Bool;
	var hoveredCell:{x:Int, y:Int};
	var cullX:Float;
	var cullY:Float;
	var cullW:Float;
	var cullH:Float;
	var cullTargetX:Float;
	var cullTargetY:Float;
	var cullTargetW:Float;
	var cullTargetH:Float;
	var grid:Array<Array<GridElem>>;
	var bgHoleX:Float;
	var bgHoleY:Float;
	var bgHoleW:Float;
	var bgHoleH:Float;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		isReplayMode = isReplay;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: new UInt16Array(0),
			recordInputs: false,
			recordEvents: true,
		});

		Cs.init();
		Cs.game = this;

		gdm = new DepthManager(root);
		map = gdm.attach("mcWallpaper", 1);
		map.anchor.set(0, 0);
		map._x = 0;
		map._y = 0;

		// Filt.glow(map, KadoKadeoManager.I(30), 1.5, 0x397BFC);

		dm = new DepthManager(map);
		bg = gdm.attach("mcBg", 0);
		bg.anchor.set(0, 0);
		bg._x = 0;
		bg._y = 0;
		initBgHoleShader();
		bgHoleX = 1 / 0;
		bgHoleY = 1 / 0;
		bgHoleW = 0;
		bgHoleH = 0;

		fList = new Array();
		glow = new Array();
		zone = new Array();

		glowDec = 0;
		hoverColor = -1;
		hoveredCell = null;
		stats = {
			l: [],
			f: [],
			mm: [7, 7, 7, 7],
		};

		initGrid();
		turn = Cs.TURN;

		zlim = {
			xmin: 99,
			ymin: 99,
			xmax: -99,
			ymax: -99
		};

		var mid = Std.int(Cs.GRID_MAX * 0.5);

		var zm = 0;
		var x = mid - zm;
		while (x <= mid + zm) {
			var y = mid - zm;
			while (y <= mid + zm) {
				free(x, y);
				y++;
			}
			x++;
		}

		panel = cast gdm.attach("mcCounter", 4);
		panel.field = panel.initTextField("field", {
			font: "Arial",
			size: 40,
			color: 0xFFFFFF,
			align: "center",
			y: -KadoKadeoManager.I(10),
		});
		panel.field.text = Std.string(KKApi.val(turn));
		panel.a = -2.8;
		panel.ta = panel.a;

		cullX = (mid + 0.5) * Cs.SIZE;
		cullY = (mid + 0.5) * Cs.SIZE;
		cullW = Cs.SIZE;
		cullH = Cs.SIZE;
		cullTargetX = cullX;
		cullTargetY = cullY;
		cullTargetW = cullW;
		cullTargetH = cullH;
		recomputeCullTarget();
		cullX = cullTargetX;
		cullY = cullTargetY;
		cullW = cullTargetW;
		cullH = cullTargetH;
		updatePanelPosition();

		// Replaced GPU mask with logical culling.

		// (map.onPress / onMouseMove / onRollOut: the mouse is polled, see applyInputEvents; only the hand cursor here)
		map.interactive = true;
		map.useHandCursor = true;
		KKApi.registerButton(map);
		updateLogicalCulling();
		updateBgHole();

		initStep(0);
	}

	public function initGrid() {
		grid = new Array();
		zoneMap = new Array();
		selectableMap = new Array();
		for (x in 0...Cs.GRID_MAX) {
			grid[x] = new Array();
			zoneMap[x] = new Array();
			selectableMap[x] = new Array();
			for (y in 0...Cs.GRID_MAX) {
				var mc:GridElem = cast dm.attach("mcFruit", DP_FRUIT);
				mc._x = (x + 0.5) * Cs.SIZE;
				mc._y = (y + 0.5) * Cs.SIZE;
				mc.flDead = false;
				grid[x][y] = mc;
				zoneMap[x][y] = false;
				selectableMap[x][y] = false;
				var id = getRandomId();
				mc.gotoAndStop(id + 1);
				mc._visible = false;
				// mc.cacheAsBitmap = true;

				/*
					var bmp = new flash.display.BitmapData(Cs.SIZE,Cs.SIZE,true,0x00000000);
					var base = dm.attach("mcFruit",0)
					var m = new flash.geom.Matrix()
					m.tx = Cs.SIZE*0.5
					m.ty = Cs.SIZE*0.5
					bmp.draw(base,m, null, null, null, null )
					mc.attachBitmap(bmp,1)
				 */
			}
		}
	}

	public function initStep(s:Int) {
		step = s;

		switch (step) {
			case 0: // CHOICE
				initSel();
				updateMinMax();

			case 1: // DESTROY
				timer = Cs.TIME_EXPLODE;

			case 2: // ISOLATE

				if (dList.length == 0) {
					initStep(0);
				} else {
					timer = Cs.TIME_FALL;
					dList = getIsolateList();
					for (pos in dList) {
						var mc = grid[pos.x][pos.y];
						var p = new Part(gdm.attach("mcFruit", 8));
						p.x = mc._x;
						p.y = mc._y;
						p.weight = KadoKadeoManager.S(0.4) + Seed.randVfx() * KadoKadeoManager.S(0.4);
						p.root.gotoAndStop(mc._currentframe);
						free(pos.x, pos.y);
						fList.push(p);
						stats.f[stats.f.length - 1][mc._currentframe - 1]++;
					}
					stats.l[stats.l.length - 1][2] = fList.length;
				}

			case 9: // ENDGAME
				timer = 4;
				cullTargetW = 0;
				cullTargetH = 0;
				updateMinMax();
		}
	}

	// the hover and the presses on the map, called by KadoKadeoManager before the stir of the frame: the live game polls
	// the mouse and records them, the replay applies them at the same moment (the replays recorded until 2026-10: the
	// callbacks of the map, in MouseManager.beginFrame)
	public function applyInputEvents() {
		if (isReplayMode) {
			for (event in KadoKadeoManager.kkm.replay.consumeEvents()) {
				applyReplayEvent(event);
			}
			return;
		}
		onMapMove();
		if (MouseManager.isButtonJustPressed(MouseManager.BUTTON_LEFT)) {
			onMapPress();
		}
	}

	public function update(delta:Float) {

		timer -= Timer.tmod;
		switch (step) {
			case 1: // DESTROY
				var prc = (1 - timer / Cs.TIME_EXPLODE) * 100;
				var list = new Array();

				for (p in dList) {
					var mc = grid[p.x][p.y];
					if (prc < 100) {
						Col.setPercentColor(mc, prc, 0xFFFFFF);
						mc._xscale = 100 - prc;
						mc._yscale = 100 - prc;
					} else {
						addChain(p.x, p.y, list);
						var ball = grid[p.x][p.y];
						blast(ball);
						KadoKadeoManager.kkm.addScore(KKApi.cadd(Cs.SCORE_BALL, bonus));
						stats.l[stats.l.length - 1][1]++;
						free(p.x, p.y);
					}
				}
				if (timer <= 0) {
					recomputeCullTarget();
					if (list.length > 0) {
						dList = list;
						bonus = KKApi.cadd(Cs.SCORE_BONUS, bonus);
						trace('bonus');
						initStep(1);
					} else {
						initStep(2);
					}
				}

			case 2: // ISOLATE
				/*
					var prc = (timer/Cs.TIME_FALL)*100
					for( var i=0; i<dList.length; i++ ){
						var p = dList[i];
						var mc = grid[p.x][p.y]
						if(prc>0){
							mc._xscale = prc
							mc._yscale = prc
						}else{
							var ball = grid[p.x][p.y]
							blast(ball)
							//KadoKadeoManager.kkm.addScore(Cs.SCORE[ball._currentframe-1])
							free(p.x,p.y)
						}
					}
				 */

				if (timer < 0) {
					if (KKApi.val(turn) > 0) {
						initStep(0);
					} else {
						initStep(9);
					}
				}
			case 9:
				if (timer < 0 && fList.length == 0) {
					KadoKadeoManager.kkm.gameOver(stats);
					initStep(10);
				}
		}

		// SPRITES
		Sprite.updateAll();
		updateCullState();
		updatePanelPosition();
		updateBgHole();
		updateLogicalCulling();

		// FALL
		var i = 0;
		while (i < fList.length) {
			var p = fList[i];
			if (p.y > Cs.mch + Cs.SIZE) {
				p.kill();
				fList.splice(i--, 1);
				KadoKadeoManager.kkm.addScore(Cs.SCORE_FALL);
			}
			i++;
		}

		// GLOW
		glowDec = (glowDec + 47) % 628;
		var prc = 50 + Math.cos(glowDec / 100) * 30;
		for (mc in glow) {
			Col.setPercentColor(mc, prc, 0xFFFFFF);
		}
	}

	public function updateMinMax():Void {
		for (x in 0...Cs.GRID_MAX) {
			for (y in 0...Cs.GRID_MAX) {
				// [xmin, ymin, xmax, ymax]

				if (grid[x][y] == null) {
					if (x < stats.mm[0]) {
						stats.mm[0] = x;
					}

					if (y < stats.mm[1]) {
						stats.mm[1] = y;
					}

					if (x > stats.mm[2]) {
						stats.mm[2] = x;
					}

					if (y > stats.mm[3]) {
						stats.mm[3] = y;
					}
				}
			}
		}
	}

	public function initSel() {
		var colorMax = Cs.PROB.length;
		var centerEmpty = getCenterEmptyMap();
		var x = 0;
		while (x < Cs.GRID_MAX) {
			var y = 0;
			while (y < Cs.GRID_MAX) {
				selectableMap[x][y] = false;
				y++;
			}
			x++;
		}

		sel = new Array();
		for (i in 0...colorMax) {
			sel[i] = new Array();
		}
		for (x in 0...Cs.GRID_MAX) {
			for (y in 0...Cs.GRID_MAX) {
				if (grid[x][y] == null) {
					continue;
				}
				var hasVoidNeighbor = false;
				for (d in Cs.DIR) {
					var nx = d[0] + x;
					var ny = d[1] + y;
					if (nx >= 0 && ny >= 0 && nx < Cs.GRID_MAX && ny < Cs.GRID_MAX && centerEmpty[nx][ny] == true) {
						hasVoidNeighbor = true;
						break;
					}
				}
				if (hasVoidNeighbor) {
					selectableMap[x][y] = true;
					var mc = grid[x][y];
					var id = mc._currentframe - 1;
					sel[id].push({x: x, y: y});
				}
			}
		}

		hoverColor = -1;
		delight(-1);
	}

	public function selectFromCell(x:Int, y:Int) {
		if (x < 0 || y < 0 || x >= Cs.GRID_MAX || y >= Cs.GRID_MAX) {
			return;
		}
		if (!selectableMap[x][y]) {
			return;
		}
		var mc = grid[x][y];
		if (mc == null) {
			return;
		}
		select(mc._currentframe - 1);
	}

	public function emptySel() {
		delight(-1);
		hoverColor = -1;
		hoveredCell = null;
		var x = 0;
		while (x < Cs.GRID_MAX) {
			var y = 0;
			while (y < Cs.GRID_MAX) {
				selectableMap[x][y] = false;
				y++;
			}
			x++;
		}
		sel = new Array();
	}

	public function select(id) {
		dList = sel[id].copy();
		for (p in dList) {
			grid[p.x][p.y].flDead = true;
		}
		stats.l.push([id, 0, 0]);
		stats.f.push([0, 0, 0, 0, 0, 0, 0]);
		emptySel();
		turn = KKApi.cadd(turn, Cs.DEC_TURN);
		panel.field.text = Std.string(KKApi.val(turn));
		bonus = KKApi.const(0);
		initStep(1);
	}

	public function enlight(id) {
		var list = sel[id];
		for (p in list) {
			var mc = grid[p.x][p.y];
			glow.push(mc);
		}
	}

	public function delight(id) {
		for (mc in glow) {
			Col.setPercentColor(mc, 0, 0xFFFFFF);
		}
		glow = [];
	}

	public function getMouseCell():{x:Int, y:Int} {
		var mx = map._xmouse;
		var my = map._ymouse;
		var cx = Std.int(Math.floor(mx / Cs.SIZE));
		var cy = Std.int(Math.floor(my / Cs.SIZE));
		if (cx < 0 || cy < 0 || cx >= Cs.GRID_MAX || cy >= Cs.GRID_MAX) {
			return null;
		}
		if (!isCellVisibleByBlob(cx, cy, 0)) {
			return null;
		}
		return {x: cx, y: cy};
	}

	function recomputeCullTarget():Void {
		var o = zlim;
		var targetW = ((o.xmax - o.xmin) + CULL_RANGE) * Cs.SIZE;
		var targetH = ((o.ymax - o.ymin) + CULL_RANGE) * Cs.SIZE;

		cullTargetX = (((o.xmin + o.xmax) * 0.5) + 0.5) * Cs.SIZE;
		cullTargetY = (((o.ymin + o.ymax) * 0.5) + 0.5) * Cs.SIZE;

		var boost = CULL_BOOST;
		for (p in zone) {
			var px = p.x * Cs.SIZE;
			var py = p.y * Cs.SIZE;
			var dxp = px - cullTargetX;
			var dyp = py - cullTargetY;
			var dist = Math.sqrt(dxp * dxp + dyp * dyp);
			var a = Math.atan2(dyp, dxp);

			var dx = Math.cos(a) * targetW * 0.5;
			var dy = Math.sin(a) * targetH * 0.5;
			var lim = Math.sqrt(dx * dx + dy * dy);
			while (dist > lim - CULL_RANGE * Cs.SIZE) {
				targetW += Math.abs(Math.cos(a) * boost);
				targetH += Math.abs(Math.sin(a) * boost);
				dx = Math.cos(a) * targetW * 0.5;
				dy = Math.sin(a) * targetH * 0.5;
				lim = Math.sqrt(dx * dx + dy * dy);
			}
		}

		cullTargetW = targetW;
		cullTargetH = targetH;
	}

	function updateCullState():Void {
		var moveLerp = 0.1 * Timer.tmod;
		if (moveLerp > 1)
			moveLerp = 1;
		cullX += (cullTargetX - cullX) * moveLerp;
		cullY += (cullTargetY - cullY) * moveLerp;

		var sizeLerp = 0.18 * Timer.tmod;
		if (sizeLerp > 1)
			sizeLerp = 1;
		cullW += (cullTargetW - cullW) * sizeLerp;
		cullH += (cullTargetH - cullH) * sizeLerp;

		if (cullW < 0)
			cullW = 0;
		if (cullH < 0)
			cullH = 0;
	}

	function updatePanelPosition():Void {
		if (panel == null) {
			return;
		}
		var rayX = cullW * 0.5;
		var rayY = cullH * 0.5;
		var bpx = cullX + Math.cos(panel.ta) * rayX;
		var bpy = cullY + Math.sin(panel.ta) * rayY;
		var m = KadoKadeoManager.I(16);

		var rec = 1 / 0;
		var nnta = panel.ta;
		for (i in 0...2) {
			var sens = i * 2 - 1;
			var nta = panel.ta;
			var px = bpx;
			var py = bpy;
			var tr = 0;
			while (px < m || px > Cs.mcw - m || py < m || py > Cs.mch - m) {
				nta += 0.0314 * sens;
				px = cullX + Math.cos(nta) * rayX;
				py = cullY + Math.sin(nta) * rayY;
				if (tr++ > 200)
					break;
			}
			if (tr < rec) {
				rec = tr;
				nnta = nta;
			}
		}
		if (rec < 200)
			panel.ta = nnta;

		var da = Num.hMod(panel.ta - panel.a, 3.14);
		panel.a += da * 0.2 * Timer.tmod;

		panel._x = cullX + Math.cos(panel.a) * rayX + PANEL_OFFSET_X;
		panel._y = cullY + Math.sin(panel.a) * rayY + PANEL_OFFSET_Y;

		var prc = (cullW + cullH) * 0.5;
		if (prc < 50) {
			panel._xscale = prc * 2;
			panel._yscale = prc * 2;
		} else {
			panel._xscale = 100;
			panel._yscale = 100;
		}
	}

	inline function isWorldPosVisibleByCull(wx:Float, wy:Float, extraMargin:Float):Bool {
		if (cullW <= 0 || cullH <= 0) {
			return true;
		}

		var radiusX = cullW * 0.5 + extraMargin;
		var radiusY = cullH * 0.5 + extraMargin;
		if (radiusX <= 0 || radiusY <= 0) {
			return false;
		}

		var dx = wx - cullX;
		var dy = wy - cullY;
		var nx = dx / radiusX;
		var ny = dy / radiusY;
		return nx * nx + ny * ny <= 1;
	}

	inline function isCellVisibleByBlob(cx:Int, cy:Int, extraMargin:Float):Bool {
		return isWorldPosVisibleByCull((cx + 0.5) * Cs.SIZE, (cy + 0.5) * Cs.SIZE, extraMargin);
	}

	function updateLogicalCulling():Void {
		var margin = KadoKadeoManager.I(CULL_MARGIN);
		for (x in 0...Cs.GRID_MAX) {
			for (y in 0...Cs.GRID_MAX) {
				var mc = grid[x][y];
				if (mc == null) {
					continue;
				}
				var visible = isCellVisibleByBlob(x, y, margin);
				if (mc._visible != visible) {
					mc._visible = visible;
				}
			}
		}

		var partMargin = margin + Cs.SIZE;
		for (p in fList) {
			if (p != null && p.root != null) {
				var visible = isWorldPosVisibleByCull(p.x, p.y, partMargin);
				if (p.root._visible != visible) {
					p.root._visible = visible;
				}
			}
		}
	}

	function updateBgHole():Void {
		if (bgHoleFilter == null) {
			return;
		}

		var x = cullX;
		var y = cullY;
		var w = cullW;
		var h = cullH;

		if (Math.abs(x - bgHoleX) < 0.1 && Math.abs(y - bgHoleY) < 0.1 && Math.abs(w - bgHoleW) < 0.1 && Math.abs(h - bgHoleH) < 0.1) {
			return;
		}

		bgHoleX = x;
		bgHoleY = y;
		bgHoleW = w;
		bgHoleH = h;

		var uniforms:Dynamic = Reflect.field(bgHoleFilter, "uniforms");
		var centerPx:Array<Float> = cast Reflect.field(uniforms, "uCenterPx");
		var radiiPx:Array<Float> = cast Reflect.field(uniforms, "uRadiiPx");
		var resolution = getRendererResolution();
		var framebufferH = getRendererFramebufferHeight();
		centerPx[0] = x * resolution;
		centerPx[1] = y * resolution;
		radiiPx[0] = w * 0.5 * resolution;
		radiiPx[1] = h * 0.5 * resolution;
		Reflect.setField(uniforms, "uScreenH", framebufferH);
	}

	function initBgHoleShader():Void {
		var resolution = getRendererResolution();
		var framebufferH = getRendererFramebufferHeight();
		var fragment = "precision mediump float;\n"
			+ "varying vec2 vTextureCoord;\n"
			+ "uniform sampler2D uSampler;\n"
			+ "uniform vec2 uCenterPx;\n"
			+ "uniform vec2 uRadiiPx;\n"
			+ "uniform float uScreenH;\n"
			+ "uniform float uSoftness;\n"
			+ "void main(void){\n"
			+ "  vec4 color = texture2D(uSampler, vTextureCoord);\n"
			+ "  vec2 pos = vec2(gl_FragCoord.x, uScreenH - gl_FragCoord.y);\n"
			+ "  vec2 rp = max(uRadiiPx, vec2(0.0001));\n"
			+ "  vec2 p = (pos - uCenterPx) / rp;\n"
			+ "  float d = length(p);\n"
			+ "  float alphaMul = 1.0 - smoothstep(1.0 - uSoftness, 1.0, d);\n"
			+ "  gl_FragColor = vec4(color.rgb * alphaMul, color.a * alphaMul);\n"
			+ "}";

		var uniforms:Dynamic = {
			uCenterPx: [Cs.mcw * 0.5 * resolution, Cs.mch * 0.5 * resolution],
			uRadiiPx: [Cs.mcw * 0.25 * resolution, Cs.mch * 0.25 * resolution],
			uScreenH: framebufferH,
			uSoftness: 0.1
		};
		var pixiFilter = Reflect.field(untyped PIXI, "Filter");
		bgHoleFilter = Type.createInstance(pixiFilter, [null, fragment, uniforms]);
		map.filters = [cast bgHoleFilter];
		map.filterArea = new Rectangle(0, 0, Cs.mcw, Cs.mch);
	}

	function getRendererResolution():Float {
		var renderer:Dynamic = Reflect.field(KadoKadeoManager.kkm, "renderer");
		if (renderer != null) {
			var res:Dynamic = Reflect.field(renderer, "resolution");
			if (res != null) {
				var r:Float = res;
				if (r > 0)
					return r;
			}
		}
		return 1.0;
	}

	function getRendererFramebufferHeight():Float {
		var renderer:Dynamic = Reflect.field(KadoKadeoManager.kkm, "renderer");
		if (renderer != null) {
			var h:Dynamic = Reflect.field(renderer, "height");
			if (h != null) {
				var fh:Float = h;
				if (fh > 0)
					return fh;
			}
		}
		return Cs.mch * getRendererResolution();
	}

	public function getCenterEmptyMap():Array<Array<Bool>> {
		var centerEmpty = new Array();
		for (x in 0...Cs.GRID_MAX) {
			centerEmpty[x] = new Array();
		}

		var queueX = new Array<Int>();
		var queueY = new Array<Int>();
		var qh = 0;

		function addCenterEmpty(x:Int, y:Int) {
			if (x < 0 || y < 0 || x >= Cs.GRID_MAX || y >= Cs.GRID_MAX) {
				return;
			}
			if (centerEmpty[x][y] == true || grid[x][y] != null) {
				return;
			}
			centerEmpty[x][y] = true;
			queueX.push(x);
			queueY.push(y);
		}

		var mid = Std.int(Cs.GRID_MAX * 0.5);
		addCenterEmpty(mid, mid);
		while (qh < queueX.length) {
			var cx = queueX[qh];
			var cy = queueY[qh];
			qh++;
			for (d in Cs.DIR) {
				addCenterEmpty(cx + d[0], cy + d[1]);
			}
		}

		return centerEmpty;
	}

	// the hover of a cell (onMouseMove / onRollOut of the map in Flash): each frame, from the mouse polled
	public function onMapMove() {
		if (isReplayMode) {
			return;
		}
		var pos = getMouseCell();
		if (hoveredCell == null && pos == null) {
			return;
		}
		if (hoveredCell != null && pos != null && hoveredCell.x == pos.x && hoveredCell.y == pos.y) {
			return;
		}
		updateHoverFromCell(pos, true);
	}

	public function updateHoverFromCell(pos:{x:Int, y:Int}, ?recordEvent:Bool = false) {
		if (step != 0) {
			if (hoverColor != -1) {
				delight(hoverColor);
				hoverColor = -1;
			}
			hoveredCell = null;
			return;
		}

		var id = -1;
		if (pos != null && selectableMap[pos.x][pos.y]) {
			var mc = grid[pos.x][pos.y];
			if (mc != null) {
				id = mc._currentframe - 1;
			}
		}

		if (recordEvent && id != -1 && pos != null) {
			if (hoveredCell == null || hoveredCell.x != pos.x || hoveredCell.y != pos.y) {
				// (on the frame being played: the replay applies it there, see applyInputEvents)
				KadoKadeoManager.kkm.replay.recordEvent({k: 0, x: pos.x, y: pos.y}, KadoKadeoManager.kkm.replay.getCurrentFrame());
			}
		}

		hoveredCell = (id != -1 && pos != null) ? {x: pos.x, y: pos.y} : null;

		if (id == hoverColor) {
			return;
		}

		if (hoverColor != -1) {
			delight(hoverColor);
		}
		hoverColor = id;
		if (hoverColor != -1) {
			enlight(hoverColor);
		}
	}

	public function onMapPress() {
		if (step != 0) {
			return;
		}
		var pos = getMouseCell();
		if (pos != null) {
			if (!isReplayMode) {
				KadoKadeoManager.kkm.replay.recordEvent({k: 2, x: pos.x, y: pos.y}, KadoKadeoManager.kkm.replay.getCurrentFrame());
			}
			selectFromCell(pos.x, pos.y);
		}
	}

	public function applyReplayEvent(event:Dynamic) {
		if (event == null) {
			return;
		}

		var kind:Int = Reflect.field(event, "k");
		var x:Null<Int> = Reflect.field(event, "x");
		var y:Null<Int> = Reflect.field(event, "y");
		if (kind == null || x == null || y == null) {
			return;
		}

		switch (kind) {
			case 0:
				updateHoverFromCell({x: x, y: y}, false);
			case 1:
			case 2:
				updateHoverFromCell({x: x, y: y}, false);
				selectFromCell(x, y);
			default:
		}
	}

	//
	public function addChain(x, y, list) {
		var base = grid[x][y];
		for (d in Cs.DIR) {
			var nx = x + d[0];
			var ny = y + d[1];
			if (nx >= 0 && ny >= 0 && nx < Cs.GRID_MAX && ny < Cs.GRID_MAX) {
				var mc = grid[nx][ny];
				if (mc != null && base != null && mc._currentframe == base._currentframe && !mc.flDead) {
					list.push({x: nx, y: ny});
					mc.flDead = true;
				}
			}
		}
	}

	public function free(x, y) {
		if (zoneMap[x][y]) {
			return;
		}
		zoneMap[x][y] = true;
		zone.push({x: x, y: y});
		zlim.xmin = Math.min(zlim.xmin, x);
		zlim.ymin = Math.min(zlim.ymin, y);
		zlim.xmax = Math.max(zlim.xmax, x);
		zlim.ymax = Math.max(zlim.ymax, y);
		if (grid[x][y] != null) {
			grid[x][y].removeMovieClip();
			grid[x][y] = null;
		}
	}

	public function getRandomId() {
		var rnd = Seed.random(Cs.PROB_SUM);
		var sum = 0;
		for (i in 0...Cs.PROB.length) {
			sum += Cs.PROB[i];
			if (sum >= rnd)
				return i;
		}
		trace("RANDOM ID ERROR");
		return null;
	}

	//
	public function eat(base) {
		/*
			var max = Math.min( 50/dList.length, 12 )
			for( var i=0; i<max; i++ ){
				var p = new Part(dm.attach("partRotSpark",DP_PART))
				var a  = Math.random()*6.28
				var sp = 2+Math.random()*3
				var ca = Math.cos(a);
				var sa = Math.sin(a);
				var ray = Cs.SIZE*0.4
				p.x = base._x + ca*ray
				p.y = base._y + sa*ray
				p.vx = ca*sp;
				p.vy = sa*sp;
				p.vr = (Math.random()*2-1)*30
				p.timer = 10+Math.random()*10
				p.frict = 0.92
				downcast(p.root).sub._x = Math.random()*10
			}
		 */
	}

	public function blast(base:GridElem) {
		if (base == null) {
			return;
		}
		var max = Std.int(Math.min(60 / dList.length, 12));
		for (i in 0...max) {
			var partB = dm.attach("partRotSpark" + base._currentframe, DP_PART);
			// partB.loop = true;
			partB.play();
			var p = new Part(partB);
			var a = Seed.randVfx() * 6.28;
			var sp = 2 + Seed.randVfx() * 3;
			p.vx = Math.cos(a) * sp;
			p.vy = Math.sin(a) * sp;
			p.vr = (Seed.randVfx() * 2 - 1) * 30;
			p.timer = 10 + Seed.randVfx() * 10;
			p.frict = 0.92;
			var dist = Seed.randVfx() * KadoKadeoManager.I(10);
			partB._x = dist;
			// p.root.sub._x = dist;
			var na = Seed.randVfx() * 6.28;
			p.root._rotation = na / 0.0174;
			p.x = base._x - Math.cos(na) * dist;
			p.y = base._y - Math.sin(na) * dist;
		}
	}

	//
	public function getIsolateList() {
		var safe = new Array();
		for (x in 0...Cs.GRID_MAX) {
			safe[x] = new Array();
		}

		var queueX = new Array<Int>();
		var queueY = new Array<Int>();
		var qh = 0;

		function addSafe(x:Int, y:Int) {
			if (x < 0 || y < 0 || x >= Cs.GRID_MAX || y >= Cs.GRID_MAX) {
				return;
			}
			if (safe[x][y] == true || grid[x][y] == null) {
				return;
			}
			safe[x][y] = true;
			queueX.push(x);
			queueY.push(y);
		}

		for (x in 0...Cs.GRID_MAX) {
			addSafe(x, 0);
			addSafe(x, Cs.GRID_MAX - 1);
		}
		for (y in 1...Cs.GRID_MAX - 1) {
			addSafe(0, y);
			addSafe(Cs.GRID_MAX - 1, y);
		}

		while (qh < queueX.length) {
			var cx = queueX[qh];
			var cy = queueY[qh];
			qh++;
			for (d in Cs.DIR) {
				addSafe(cx + d[0], cy + d[1]);
			}
		}

		var list = [];
		for (x in 1...Cs.GRID_MAX - 1) {
			for (y in 1...Cs.GRID_MAX - 1) {
				if (grid[x][y] != null && safe[x][y] != true)
					list.push({x: x, y: y});
			}
		}

		return list;
	}

	public function destroy():Void {
		Cs.reset();
	}
}
