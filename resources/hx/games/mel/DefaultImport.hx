package mel;

// DefaultImport.hx of the original: the types shared by the game

enum NMY_TYPE {
	NT_HANDLE;
	NT_BAD_HANDLE;
	NT_SWARM;

	NT_TORCH;
	NT_BLADE;

	NT_MASSIVE;
}

enum CharPowers {
	CP_DOUBLE_JUMP;
	CP_WALL_STICK;
	CP_SUPER_JUMP;

	CP_KICK;
	CP_CANCEL;
}

typedef RectI = {x:Int, y:Int, width:Int, height:Int};

enum LD_PATTERN {
	LDPage(p:Int);
	LDGen(nb:Int);
}

enum Restager {
	RandPlatform(seed:Int);
	FixedPlatform(cx:Int, cy:Int);
	Fixed;
}
