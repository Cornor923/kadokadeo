package mel;

// the French texts of the original (texts.fr.xml, the raw content of each <t>: mt.data.Texts)
class Text {
	public static var ALL:Map<String, String> = [
		"well_done" => "Bien ouej!",
		"jump" => "SAUTE !",
		"lvl_1" => "yo mel. le courrier de la resistance urge grav ! GO !",
		"lvl_1&dbl" => "YES Des gravipompes ! DBL SAUT DEBLOQUE !",
		"lvl_2&dbl" => "utilise le dbl saut pour monter !",
		"lvl_6&super" => "yop, charge tes sauts avec la touche bas",
		"lvl_8&grab" => "On t'a ramené des grips. Accroche toi bien !",
		"lvl_10&kick" => "en vol tu peux dasher vers un ennemi sur bas ! ",
		"lvl_11&cancel" => "bas annule ton double saut, utile pour te rattraper",
		"lvl_2" => "gg, on va voir si tu t'en sors en corsant un peu.",
		"lvl_4" => "bon ce parcours pique un peu, fait nous rever.",
		"lvl_5" => "t' assure grave, voila un vrai terrain, GO !",
		"for_real" => "premier vrai contrat fais attention aux Bulx ",
		"lvl_16" => "ils preparent un sale coup méfie toi",
		"lvl_18" => "parait que les bulx t'ont cherché partout bien ouej",
		"lvl_19" => "...contrat sur ta tete ... pulpz arrivent ! FUIT ",
		"lvl_20" => "on est foutu... sauve toi avec les plans de Black$ter.",
		"sms_kdo" => "*spam* on vous surveille.\r\n\t|*spam* Black$ter protège vos foyers.\r\n\t|*spam* La pensée est notre ennemi.\r\n\t|*spam* Le corps n'a besoin que de muscle.\r\n\t|*spam* l'autre vous menace.\r\n\t|*spam* consommer c'est vivre.\r\n\t|*spam* Black$ter vous nourrit.\r\n\t|*spam* Des points, encore des points.\r\n\t|*spam* Point KDO.Point KDO.Point KDO.\r\n\t|*spam* Ces Points KDO vous sont offerts pas cervelex.\r\n\t|*spam* Cervelex vous aide a reflechir.\r\n\t|*spam* Consommez plus consommez mieux.\r\n\t|*spam* La nouvelle gamme bio sKrill, oh oui miam miam.\r\n\t|*spam* Ne contient que des graisses non trans.\r\n\t|*spam* Offre spéciale : Pour un kdo acheté, un offert.\r\n\t|*spam* La répétition, c'est la santé.\r\n\t|*spam* S'exercer vous améliore.\r\n\t|*spam* Dénoncer pour gagner.\r\n\t|*spam* Vivre pour avancer.\r\n\t|*spam* Nous vous offrons la vie.\r\n\t|*spam* Le message des 16 est clair. Vivons ! \r\n\t",
		"sms_flash" => "flash : la $p nous a déclaré la guerre !\r\n\t|flash : la $p nous a déclaré la guerre !\r\n\t|flash : la $p est notre alliée depuis toujours !\r\n\t|flash : la Chine est notre alliée depuis toujours !\r\n\t|flash : DesCity ville fleurie.\r\n\t|flash : La résistance n'a aucun espoir.\r\n\t|flash : $n a été arrété pour contrefaçon mentale.\r\n\t|flash : $n vous ment.\r\n\t|flash : Les pulpz sont la pour votre sécurité.\r\n\t|flash : démenti officiel. Les Bulx ne mangent pas les rêves.\r\n\t|flash : DesCity est le dernier paradis.\r\n\t|flash : La population remercie Black$ter.\r\n\t|flash : Sortez toujours avec vos puces d'identité.\r\n\t|flash : Demain est un nouveau jour !\r\n\t|flash : La qualité de l'air est Bonne.\r\n\t|flash : Bienvenue en république exemplaire !\r\n\t|flash : $n est en fuite !\r\n\t|flash : $n a été condamné à mort !\r\n\t|flash : ce message est un mensonge rebelle !\r\n\t|flash : la rebellion a tort.\r\n\t|flash : la rebellion a perdu sa dernière bataille.\r\n\t|flash : Tordre le temps n'y changera rien.\r\n\t|flash : Les pulpz feront une inspection au bloc B49.\r\n\t|flash : Les arguments de la rebellion jugé non conformes.\r\n\t|Les 16 nous regardent et veillent sur nous.\r\n\t",
		"var_p" => "Nouvelle Chine,Russinia,Franicie,Mericine",
		"var_n" => "Paul Jenning,Richard Cognis,Kin von chan,Peternine,Organa Rinaldo,James Norray,Melpomène K.",
		"txt_cp0" => "Gravi pompes.\r\n\tPour faire des doubles sauts de folie (touche SAUT ). \r\n\t|- Permet de tuer certains ennemis.\r\n\t|- Empêche les grips de fonctionner",
		"txt_cp1" => "Mag Grips.\r\n\tPour s'accrocher où tu veux, quand tu veux. \r\n\t|- Permettent de s'accrocher sur les plateformes pour une durée limitée.",
		"txt_cp2" => "Chargeur A Nitro.\r\n\tFait péter tes pompes ! \r\n\t|- Permet de se baisser pour concentrer un saut. \r\n\t|- Permet de freiner brutalement",
		"txt_cp3" => "Quantizeur.\r\n\tLa vitesse ne te manquera plus jamais.\r\n\t|- Permet d'effectuer des tâcles dévastateurs sur certains ennemis (touche BAS ).",
		"txt_cp4" => "Disjoncteur A réaction. \r\n\tSans maîtrise la vitesse sert à queud.\r\n\t|- Permet d'interrompre les doubles sauts pour reprendre le contrôle (touche BAS ).",
		"take_that_bonus" => "Yes, Du matos, prend le !",
		"dbl_jump_kills" => "FUME LES AVEC LE DOUBLE SAUT.",
		"bonusTxt_0" => "DBL",
		"bonusTxt_1" => "GRP",
		"bonusTxt_2" => "CHG",
		"bonusTxt_3" => "TCL",
		"bonusTxt_4" => "CTRL",
		"bonusTxtHit_0" => "DOUBLE|SAUT",
		"bonusTxtHit_1" => "ACCROCHAGE",
		"bonusTxtHit_2" => "SAUT|CHARGE",
		"bonusTxtHit_3" => "SAUT|TELEPORTE",
		"bonusTxtHit_4" => "ANNULATION",
		"flee_0" => "PULPZ!",
		"flee_1" => "Les Pulpz sont là FUIT!",
	];

	public static var well_done(get, never):String;

	static inline function get_well_done()
		return ALL.get("well_done");

	public static var jump(get, never):String;

	static inline function get_jump()
		return ALL.get("jump");

	public static var lvl_1(get, never):String;

	static inline function get_lvl_1()
		return ALL.get("lvl_1");

	public static var lvl_2(get, never):String;

	static inline function get_lvl_2()
		return ALL.get("lvl_2");

	public static var lvl_4(get, never):String;

	static inline function get_lvl_4()
		return ALL.get("lvl_4");

	public static var lvl_5(get, never):String;

	static inline function get_lvl_5()
		return ALL.get("lvl_5");

	public static var for_real(get, never):String;

	static inline function get_for_real()
		return ALL.get("for_real");

	public static var lvl_16(get, never):String;

	static inline function get_lvl_16()
		return ALL.get("lvl_16");

	public static var lvl_18(get, never):String;

	static inline function get_lvl_18()
		return ALL.get("lvl_18");

	public static var lvl_19(get, never):String;

	static inline function get_lvl_19()
		return ALL.get("lvl_19");

	public static var lvl_20(get, never):String;

	static inline function get_lvl_20()
		return ALL.get("lvl_20");

	public static var sms_kdo(get, never):String;

	static inline function get_sms_kdo()
		return ALL.get("sms_kdo");

	public static var sms_flash(get, never):String;

	static inline function get_sms_flash()
		return ALL.get("sms_flash");

	public static var var_p(get, never):String;

	static inline function get_var_p()
		return ALL.get("var_p");

	public static var var_n(get, never):String;

	static inline function get_var_n()
		return ALL.get("var_n");

	public static var txt_cp0(get, never):String;

	static inline function get_txt_cp0()
		return ALL.get("txt_cp0");

	public static var txt_cp1(get, never):String;

	static inline function get_txt_cp1()
		return ALL.get("txt_cp1");

	public static var txt_cp2(get, never):String;

	static inline function get_txt_cp2()
		return ALL.get("txt_cp2");

	public static var txt_cp3(get, never):String;

	static inline function get_txt_cp3()
		return ALL.get("txt_cp3");

	public static var txt_cp4(get, never):String;

	static inline function get_txt_cp4()
		return ALL.get("txt_cp4");

	public static var take_that_bonus(get, never):String;

	static inline function get_take_that_bonus()
		return ALL.get("take_that_bonus");

	public static var dbl_jump_kills(get, never):String;

	static inline function get_dbl_jump_kills()
		return ALL.get("dbl_jump_kills");

	public static var bonusTxt_0(get, never):String;

	static inline function get_bonusTxt_0()
		return ALL.get("bonusTxt_0");

	public static var bonusTxt_1(get, never):String;

	static inline function get_bonusTxt_1()
		return ALL.get("bonusTxt_1");

	public static var bonusTxt_2(get, never):String;

	static inline function get_bonusTxt_2()
		return ALL.get("bonusTxt_2");

	public static var bonusTxt_3(get, never):String;

	static inline function get_bonusTxt_3()
		return ALL.get("bonusTxt_3");

	public static var bonusTxt_4(get, never):String;

	static inline function get_bonusTxt_4()
		return ALL.get("bonusTxt_4");

	public static var bonusTxtHit_0(get, never):String;

	static inline function get_bonusTxtHit_0()
		return ALL.get("bonusTxtHit_0");

	public static var bonusTxtHit_1(get, never):String;

	static inline function get_bonusTxtHit_1()
		return ALL.get("bonusTxtHit_1");

	public static var bonusTxtHit_2(get, never):String;

	static inline function get_bonusTxtHit_2()
		return ALL.get("bonusTxtHit_2");

	public static var bonusTxtHit_3(get, never):String;

	static inline function get_bonusTxtHit_3()
		return ALL.get("bonusTxtHit_3");

	public static var bonusTxtHit_4(get, never):String;

	static inline function get_bonusTxtHit_4()
		return ALL.get("bonusTxtHit_4");

	public static var flee_0(get, never):String;

	static inline function get_flee_0()
		return ALL.get("flee_0");

	public static var flee_1(get, never):String;

	static inline function get_flee_1()
		return ALL.get("flee_1");

	public static function resolve(id:String):String {
		return ALL.exists(id) ? ALL.get(id) : "#" + id + "#";
	}
}
