package mt.deepnight;
import haxe.macro.Expr;

/*
	USAGE DE BASE : (voir la mÃ©thode statique "demo" pour 2 exemples)
		var cm = new Cinematic();
		cm.create({ INSTRUCTIONS; });
		flash.Lib.current.addEventListener( flash.events.Event.ENTER_FRAME, function(_) cm.update() );
		
	NOTE :
		les mÃ©thodes prÃ©fixÃ©es par "_" ne doivent pas Ãªtre appelÃ©es directement (usage interne)

	EXEMPLE :
		var cm = new Cinematic();
		cm.create({
			player.move(5,5) > end;
			player.say("Je suis arrivÃ© !");
			300;
			player.laugh() > 500;
			ennemy.move(5,5) > end;
			player.die() > 500;
			ennemy.laugh();
			1000;
			gameOver();
		});
		flash.Lib.current.addEventListener( flash.events.Event.ENTER_FRAME, function(_) cm.update() );
		
	SYNTAXE DES INSTRUCTIONS :
		// appel immÃ©diat :
		method();
		
		// appel suivi d'une pause de 500ms :
		method() > 500;
		
		// appel suivi d'un arrÃªt de la lecture, jusqu'Ã  un appel Ã  signal("truc")
		method() > end("truc");

		// appel suivi d'un arrÃªt de la lecture, jusqu'Ã  un appel QUELCONQUE Ã  signal()
		method() > end;
		
		// pause de 500ms
		500;
		
		// Ã©quivalent d'un haxe.Timer.delay(method), avec le support du "skip" en plus.
		750 >> method();
		
		// lance une cinÃ©matique en parallÃ¨le aprÃ¨s 500ms
		500 >> cm.create({
			method();
		});
		
	SIGNAUX :
		Les signaux sont globaux Ã  toutes les cinÃ©matiques. Gare au exÃ©cutions parallÃ¨les.
		IMPORTANT : l'appel Ã  signal() est INSTANTANÃ et ne dure donc pas. En clair, si la cinÃ©matique est sur un "end" au
		moment oÃ¹ signal est appelÃ©, le "end" va se dÃ©bloquer. Mais si signal est appelÃ© avant l'arrivÃ©e au "end",
		Ã§a bloquera indÃ©finiment sur le "end"...
		La mÃ©thode persistantSignal() permet de lancer un signal qui perdurera jusqu'Ã  ce qu'un end correspondant le
		rÃ©cupÃ¨re. Le signal est alors SUPPRIMÃ dÃ¨s qu'il est captÃ©. Notez que ce signal ne disparaÃ®tra jamais si aucun "end"
		ne l'utilise, gare aux effets de bord...
		
	UTILISATION DU SKIP :
		la mÃ©thode skip() permet de vider la liste des commandes en 1 frame. Pendont son exÃ©cution, la variable "turbo"
		vaut true, pour permettre aux mÃ©thodes du jeu de savoir qu'elles doivent se jouer en accÃ©lÃ©rÃ© (rÃ©solution complÃ¨te
		de leur effet en instantanÃ©)
		
*/
		
private typedef CinematicEvent = {
	f : Void->Void,
	t : Float,
	s : Null<String>,
}
		
class Cinematic {
	#if !macro
	
	// Public
	public var turbo(default,null)	: Bool; // vaut true pendant un skip()
	public var onAllComplete		: Null< Void->Void >; // appelÃ© Ã  chaque fois que toutes les cinÃ©matiques sont terminÃ©es
	
	
	
	#if (!CinematicDebug && !js) // (demo: flash.Lib.current)
	/****************************************************/
	public static function demo() {
		var cm = new Cinematic();
		
		var foo;
		cm.create({
			trace("1") > 1000; // attendre 1000ms aprÃ¨s le trace
			
			trace("2"); // trace sans dÃ©lai
			
			1000; // attendre 1000ms
			
			function test() {
				trace("3");
				cm.signal("mySignal");
			}
			1000 >> test(); // lancement de test() en parallÃ¨le dans 1000ms
			end("mySignal"); // attente d'un appel quelconque Ã  signal()
			
			function test() {
				trace("4");
				cm.signal();
			}
			1000 >> test(); // lancement de test() en parallÃ¨le dans 1000ms
			end; // attente d'un appel quelconque Ã  signal()
			
			1000;
			
			if( true ) {
				trace("5 true") > 500;
				trace("6 true") > 500;
			}
			else {
				trace("5 false") > 500;
				trace("6 false") > 500;
			}
			
			foo = 1;
			switch( foo ) {
				case 0 : trace("switch 0") > 500;
				case 1 : trace("switch 1") > 500 ;
				case 2 : trace("switch 2") > 500;
			}
			trace("after switch") > 500;
			
			for( i in 0...3 )
				trace("loop "+i) > 500;
			trace("after loop") > 500;
		});
		flash.Lib.current.addEventListener( flash.events.Event.ENTER_FRAME, function(_) cm.update() );
	}
	/****************************************************/
	#end
	
	
	
	
	// Private
	var queues			: Array< Array<CinematicEvent> >;
	//var lastTime		: Float;
	var curQueue		: Array<CinematicEvent>;
	var persistSignals	: Map<String, Bool>;
	//var time			: Float;
	var fps				: Int;
	#end
	
	
	public function new(?fps=30) {
		#if !macro
		this.fps = fps;
		turbo = false;
		queues = new Array();
		//time = 0;
		//lastTime = Date.now().getTime();
		persistSignals = new Map();
		#end
	}
	
	static function error( ?msg="", p : Position ) {
		#if macro
		haxe.macro.Context.error("Macro error: "+msg,p);
		#end
	}
		
	static function funName(e:Expr) {
		switch(e.expr) {
			case EConst(c) :
				switch(c) {
					case CIdent(v) : return v;
					default :
				}
			default :
		}
		return null;
	}
	
	macro public function create(ethis:Expr, block:Expr) : Expr {
		var r = __rchain(ethis, block);
		r = macro {
			$ethis.__beginNewQueue();
			$r;
		}
		#if CinematicDebug
		trace( tink.macro.tools.Printer.print(r) );
		#end
		return r;
	}
	
	macro public function chainToLast(ethis:Expr, block:Expr) : Expr {
		var r = __rchain(ethis, block);
		r = macro {
			if( $ethis.isEmpty() )
				$ethis.__beginNewQueue();
			$r;
		}
		return r;
	}
	
	static function __rchain(ethis:Expr, block:Expr) {
		switch( block.expr ) {
		case EBlock(el):
			var exprs = [];
			
			for( e in el ) {
				var preDelay = null;
				var postDelay = macro 0;
				var signal = null;
				
				var topLevel = false;
				
				function parseSpecialExpr(de:Expr, strict:Bool) {
					switch(de.expr) {
						case ECall(f,params) : // END avec nom du signal
							if( funName(f)=="end" ) {
								signal = params[0];
								return macro null;
							}
							else if( strict )
								error("unsupported expression", de.pos);
						case EConst(c) :
							switch(c) {
								case CIdent(v) : // END gÃ©nÃ©ral
									if( v=="end" ) {
										signal = macro "";
										return macro null;
									}
									else
										error("unexpected CIdent "+v, de.pos);
										
								case CInt(v) : // DÃ©lai
									postDelay = de;
									
								default :
									error("unexpected EConst "+c, de.pos);
							}
						default :
							if( strict )
								error("unsupported expression", de.pos);
					}
					return de;
				}
				
				function parseChainedMethod(ce:Expr, ?level=0) {
					switch(ce.expr) {
						case ECall(_), EConst(_) :
							
						case EBlock(list) :
							ce = __rchain(ethis, ce);
							
						case EWhile(cond, b, classic) :
							topLevel = true;
							var mb = __rchain(ethis, b);
							if( classic )
								return macro while($cond) $mb;
							else
								return macro do {$mb;} while($cond);
							
						case EVars(_) :
							error("forbidden variable assignation (using new variable declaration WITHIN a cinematic will lead to unexpected results)", ce.pos);
						//case EVars(_), EUnop(_), EThrow(_) :
						case EUnop(_), EThrow(_) :
							topLevel = true;
							
						case EFunction(name, f) :
							topLevel = true;
							f.expr = __rchain(ethis, f.expr);
							
						case EFor(it, b) :
							topLevel = true;
							b = __rchain(ethis, b);
							return macro for($it) $b;
							
						case ESwitch(es, cases, d) :
							topLevel = true;
							for( c in cases )
								c.expr = __rchain(ethis, c.expr);
							if( d!=null )
								d = __rchain(ethis, d);
							ce.expr = ESwitch(es, cases, d);
							
						case EIf(econd, eif, eelse) : // condition
							topLevel = true;
							var mif = __rchain(ethis, eif);
							if( eelse==null ) {
								return macro if($econd) {$mif;}
							}
							else {
								var melse = __rchain(ethis, eelse);
								return macro if($econd) {$mif;} else {$melse;}
							}
							
						case EBinop(op,e1,e2):
							//trace(op);
							//if( op==OpAssign )
								//error("assignation is not supported here", e.pos);
							if( level>0 )
								error("cannot combine multiple operators > or >>", e2.pos);
							if( op == OpGt ) { // opÃ©rateur ">"
								topLevel = true;
								return __rchain( ethis,  macro {$e1; $e2;} );
							}
							if( op == OpShr ) { // opÃ©rateur ">>"
								preDelay = e1;
								switch(e2.expr) {
									case ECall(_) :
									default : error("Only function calls are supported here", e2.pos);
								}
								return parseChainedMethod(e2);
							}
							
						default:
							error(Std.string(ce.expr).split("(")[0]+" is not supported in chain", ce.pos);
					}
					return ce;
				}
				
				e = parseSpecialExpr(e, false);
				e = parseChainedMethod(e);
				if( topLevel )
					exprs.push(e);
				else
					if( preDelay!=null )
						exprs.push( macro {
							$ethis.__add( function() {
								$ethis.__addParallel( function() { $e; }, $preDelay);
							}, 0);
						});
					else
						if( signal!=null )
							exprs.push(macro $ethis.__add( function() { $e; }, $postDelay, $signal ));
						else
							exprs.push(macro $ethis.__add( function() { $e; }, $postDelay ));
							
			}
			
			return {expr: EBlock(exprs), pos: block.pos}; // (Haxe 4: no $[] reification)
		default:
			return __rchain(ethis, macro {$block;});
		}
	}
	
	
	#if !macro
	
	public function signal(?s:String) {
		for( q in queues )
			if( q.length>0 && (q[0].s==s || q[0].s=="") )
				runEvent( q.splice(0,1)[0] );
	}
	
	public function persistantSignal(s:String) {
		persistSignals.set(s, true);
		signal(s);
	}
	
	public function __addParallel(cb:Void->Void, t:Int, ?signal:String) {
		queues.push( [{f:cb, t:fps*t/1000, s:null }] );
	}
	
	public function __add(cb:Void->Void, t:Int, ?signal:String) {
		curQueue.push({f:cb, t:fps*t/1000, s:signal});
	}
	
	public function __beginNewQueue() {
		queues.push( new Array() );
		curQueue = queues[queues.length-1];
	}
	
	public inline function isEmpty() {
		return queues.length==0;
	}
	
	function runEvent(e:CinematicEvent) {
		if( e.s!=null )
			persistSignals.remove(e.s);
		e.f();
	}
	
	public function skip(/*?timeSkip=50*/) {
		turbo = true;
		while( queues.length>0 ) {
			//lastTime = Date.now().getTime()-timeSkip;
			update();
		}
		turbo = false;
	}
	
	public function update() {
		//time++;
		//var delta = time-lastTime;
		//var t = Date.now().getTime();
		//var delta = t - lastTime;
		
		var i = 0;
		while( i<queues.length ) {
			var q = queues[i];
			if( q.length>0 ) {
				q[0].t --;
				while( q.length>0 && q[0].t<=0 && ( turbo || q[0].s==null || persistSignals.get(q[0].s) ) )
					runEvent( q.splice(0,1)[0] );
			}
			if( q.length==0 ) {
				queues.splice(i,1);
				if( isEmpty() && onAllComplete!=null )
					onAllComplete();
			}
			else
				i++;
		}
		if( curQueue!=null && curQueue.length==0 )
			curQueue = null;
			
		//lastTime = t;
	}
	
	#end
}
