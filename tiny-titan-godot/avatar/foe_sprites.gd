class_name FoeSprites
extends RefCounted
## The Realm's foes as pixel art (RPG_PLAN.md 12 and the table of 8.3): hand
## pixelled char-row sprites with TWO frames each, re-coloured per foe.
##
##   FoeSprites.texture("dust_bunny", 0)      # outlined, lit from the top left
##   FoeSprites.size("the_pacer")             # the size of that texture
##
## A look (`LOOKS[foe id]`) is {sprite: key of SHAPES, palette: {char: "#rrggbb"},
## hover: bool}; "." is an empty pixel. Regular foes are 14 to 22 pixels wide,
## elites 20 to 26, bosses 24 to 32; a few shapes are shared by two foes with
## other colours. An id that is not known draws a plain blob, and an id that
## starts with "wk_" (the weekly rival: the main game's bounty monsters) is
## drawn through Art / BossSprites, so the rival looks as it does on the Hero
## tab.
##
## A shape is written once and its second frame is derived from the first, so
## the two never drift apart:
##   rows      the first frame, row by row; or
##   half      its LEFT half only: the right half is the mirror image
##   over      [[row, column, text], ...] written over the first frame (what a
##             mirrored shape has on one side only); "." erases
##   two       the whole second frame, when it is a pose of its own (wings down)
##   alt       {row: text} rows of the second frame that differ (a half-width
##             text in a mirrored shape is mirrored too)
##   alt_over  like `over`, for the second frame only
##   pulse     two letters that change places in the second frame (a glow)
##   cut       rows taken out of the second frame, with empty rows added at the
##             top instead: everything above sinks a pixel while the feet stay
##             (a breath, a squash)
## Both frames always have the same size, so a view never jumps.
##
## Only the game's own look: a lit rim and a shaded underside (Pix.bevel) under
## an outline that leans to the colour it surrounds (Pix.outline_tinted). There
## is no classic branch: none of this existed in the port.

const K = "#1a1026" # = Pix.OUTLINE
const SILHOUETTE = "#0d0a1a"
const SILHOUETTE_EDGE = "#241c40"
## A greyed-out foe (FoeView.set_dim).
const DIM_BRIGHTNESS = 0.5
const _TEX_CACHE_MAX = 512

## The widest and narrowest a sprite may be, by kind (the art test holds them to it).
const WIDTH_REGULAR = [14, 22]
const WIDTH_ELITE = [20, 26]
const WIDTH_BOSS = [24, 32]

const SHAPES = {
	# The stand-in for an id nobody drew.
	"blob": {
		"rows": [
			"....aaaaaa....",
			"..aaccaaaaaa..",
			".aaccaaaaaaaa.",
			".aaaaaaaaaaab.",
			"aaawkaaawkaaab",
			"aaakkaaakkaaab",
			"aaaaaaaaaaaaab",
			"aaaaakkkkaaaab",
			".aaaaaaaaaabb.",
			".bbaaaaaabbbb.",
			"..bbbbbbbbbb..",
		],
		"cut": [8],
	},

	# --- The Rustyard ---------------------------------------------------------
	# A ball of dust with ears. a fluff, b shade, c light, p pink.
	"bunny": {
		"rows": [
			"..aa......aa..",
			".acpa....apca.",
			".acpa....apca.",
			".aapa....apaa.",
			"..aaaa..aaaa..",
			".aaccaaaaaaaa.",
			"aaccaaaaaaaaba",
			"aacakwaakwaaba",
			"aaaakkaakkaaba",
			"baaaaappaaaabb",
			".baaaaaaaaabb.",
			"..bbaabbaabb..",
			"..bb......bb..",
		],
		"alt": {0: ".aa........aa.", 1: ".acpa....apca.", 2: "..acpa..apca..", 3: "..aapa..apaa..", 7: "aacaaaaaaaaaba"},
		"cut": [10],
	},
	# A rat in profile. a fur, b shade, c belly, p pink.
	"rat": {
		"rows": [
			"....aa............",
			"...appa..aaaaa...p",
			"..aapaaaaaaaaaa..p",
			".aakaaaaaaaaaaaa.p",
			"paaaaaaaaaaaaaaa.p",
			".wacccaaaaaaaaaapp",
			"..accccaaaaaaabp..",
			"...cccccaaaabbb...",
			"...bb.cc...bb.b...",
			"..bb.......bbb....",
		],
		"alt": {
			1: "...appa..aaaaa....",
			2: "..aapaaaaaaaaaa...",
			3: ".aakaaaaaaaaaaaa.p",
			4: "paaaaaaaaaaaaaaapp",
			5: ".wacccaaaaaaaaaap.",
			8: "..bb..cc....bbb...",
			9: "..b.........b.bb..",
		},
	},
	# A weight plate with a face: a rim, a round groove, the bar's hole for a nose. a iron, b shade, c light, r rust, m mouth.
	"plate": {
		"rows": [
			"....cccccccc....",
			"..ccaaaaaaaacc..",
			".caaaabbbbaaaab.",
			".caabbaaaabbaab.",
			"caabaaaaaaaabaab",
			"cabaawkaawkaabab",
			"cabaakkaakkaabab",
			"cabaaaabbaaaabrb",
			"cabaaabkkbaaarrb",
			"cabaaaabbaaaabab",
			"caabammmmmmabaab",
			".aaabbaaaabbaab.",
			".baaaabbbbaaabb.",
			"..bbaaaaaaaabb..",
			"....bbbbbbbb....",
			"...kk......kk...",
		],
		"alt": {5: "cabaakwaakwaabab", 10: "caabaammmmaabaab", 15: "..kk........kk.."},
	},
	# A spring collar: a ring of coiled steel with two red grips to squeeze, and something looking out of the hole.
	# a steel, b coils, c grips, k the hole, w eyes.
	"collar": {
		"rows": [
			"cc............cc",
			"ccc..........ccc",
			".aaa........aaa.",
			"..aaa......aaa..",
			"...aaaaaaaaaa...",
			"..aabaabaabaaa..",
			".aaakkkkkkkkaaa.",
			".abkkwkkkkwkkab.",
			"aabkkwkkkkwkkbaa",
			"abakkkkkkkkkkaba",
			"aabkkkkkkkkkkbaa",
			".aaakkkkkkkkaaa.",
			"..aabaabaabaab..",
			"....bbbbbbbb....",
		],
		"alt": {
			0: "..cc........cc..",
			1: "..ccc......ccc..",
			2: "...aa......aa...",
			3: "...aaa....aaa...",
			7: ".abkkkkkkkkkkab.",
			8: "aabkkkwkkkkwkbaa",
		},
	},
	# A towel hung like a ghost, with mould. a cloth, b fold, g d mould, s stripe.
	"towel": {
		"rows": [
			"....aaaaaa....",
			"..aaaaaaaaaa..",
			".aaaagaaaaaaa.",
			".aaaggaaaaaba.",
			"aaakkaaakkaaba",
			"aaakkaaakkagba",
			"aaaaaaaaaaggba",
			"aagaaakkaaadba",
			"aggaaaaaaaaaba",
			"adgaaaaaaaaaba",
			"aaaabaaaabaaba",
			"ssssbssssbssbs",
			"aaaabaaaabaaba",
			"aa.aaa.aaa.aba",
			"a...a...a...b.",
		],
		"alt": {13: "a.aaa.aaa.aaba", 14: "..a...a...a.b.", 7: "aagaakkkkaadba"},
	},

	# --- The Greenmile --------------------------------------------------------
	# A seed ball of hooks. a husk, b shade, c tips.
	"burr": {
		"rows": [
			"...c..cc..c...",
			"...a..aa..a...",
			"c..aaaaaaaa..c",
			".aaaaaaaaaaaa.",
			"..aaaaaaaaaa..",
			"caaawkaawkaaac",
			"caaakkaakkaaac",
			"..aaaaaaaaaa..",
			".aaaabkkbaaaa.",
			"c.abaaaaaaba.c",
			"...abbbbbba...",
			"..a..b..b..a..",
			"..c..c..c..c..",
		],
		"alt": {
			0: "..c...cc...c..",
			1: "...a..aa..a...",
			2: ".c.aaaaaaaa.c.",
			3: "..aaaaaaaaaa..",
			4: "caaaaaaaaaaaac",
			5: ".aaawkaawkaaa.",
			6: ".aaakkaakkaaa.",
			7: "caaaaaaaaaaaac",
			8: "..aaabkkbaaa..",
			9: ".cabaaaaaabac.",
			11: "...a.b..b.a...",
			12: "..c..c..c..c..",
		},
	},
	# A fox in profile with briars on its back. a fur, b shade, c cream, g briar.
	"fox": {
		"rows": [
			"..a...a.............",
			"..aa.aa.........cc..",
			"..aaaaa........ccac.",
			".aaaaaaa......aaaaa.",
			".akaaaaa..g.g.aaaaa.",
			"naaaaaaaaaagagaaaab.",
			".ccaaaaaaaaaaaaaab..",
			"..cccaaaaaaaaaaab...",
			"...ccaaaaaaaaaab....",
			"...caaaaabaaaab.....",
			"...ab.ab...ab.ab....",
			"...ab.ab...ab.ab....",
			"..bb..bb..bb..bb....",
		],
		"alt": {
			1: "..aa.aa..........cc.",
			2: "..aaaaa.........ccac",
			3: ".aaaaaaa.......aaaaa",
			4: ".akaaaaa..g.g..aaaab",
			5: "naaaaaaaaaagagaaaab.",
			10: "..ab..ab....ab.ab...",
			11: ".ab...ab....ab..ab..",
			12: ".bb..bb.....bb..bb..",
		},
	},
	# A lump of mud with an arm up, holding a ball (o: mud to sling, or a light that mends). a mud, b shade, c wet.
	"mudblob": {
		"rows": [
			"...........oo...",
			"..........owoo..",
			"....aaaa..oooo..",
			"..aaaaaaaa.oo...",
			".aacaaaaaaa.a...",
			".acaaaaaaaaaa...",
			"aaawkaawkaaaa...",
			"aaakkaakkaaab...",
			"aaaaaaaaaaaab...",
			"aaaabkkkbaaab...",
			"aabaaaaaaaabba..",
			"abbaabaaabaabba.",
			"bb.bbbbb.bbb.bbb",
		],
		"alt": {
			0: "................",
			1: "...........oo...",
			2: "....aaaa..owoo..",
			3: "..aaaaaaaaoooo..",
			4: ".aacaaaaaaaoo...",
			9: "aaaabkkkkaaab...",
			11: "abbaaabaabaabba.",
			12: "bbb.bbbb.bb.bbbb",
		},
	},
	# A stag beetle from above. a shell, b shade, c shine, m jaws.
	"beetle": {
		"rows": [
			".mm............mm.",
			"mm..............mm",
			"mm.m..........m.mm",
			".mm.m........m.mm.",
			"..mmm........mmm..",
			"...mmm.aaaa.mmm...",
			"....mmaaaaaamm....",
			"..b..awkaawka..b..",
			".b.caaaabbaaaab.b.",
			".bbcaaaabbaaaabbb.",
			"...caaaabbaaaab...",
			".bbaaaaabbaaaabbb.",
			"b...aaaabbaaab...b",
			".....bbbbbbbb.....",
		],
		"alt": {
			0: "..................",
			1: "...mm........mm...",
			2: "..mm..m....m..mm..",
			3: "..mm.m......m.mm..",
			4: "..mmm........mmm..",
			7: ".b...awkaawka...b.",
			8: "..bcaaaabbaaaabb..",
			11: "..baaaaabbaaaabb..",
			12: ".b..aaaabbaaab..b.",
		},
	},
	# A mile post: a board with a number on a post with a face. a wood, c board.
	"post": {
		"rows": [
			"..cccccccccc..",
			".cccccccccccc.",
			".cccrcrrrcccc.",
			".cccrcrcrcccc.",
			".cccrcrrrcccc.",
			".cccccccccccc.",
			"..bbbbbbbbbb..",
			"....aaaaab....",
			"....akaakb....",
			"....akaakb....",
			"....aaaaab....",
			"....arrrab....",
			"....aaaaab....",
			"....aaaaab....",
			".g..aaaaab..g.",
			"gggbbbbbbbbggg",
		],
		"alt": {2: ".cccccrrrcccc.", 3: ".cccccrcrcccc.", 4: ".cccccrrrcccc.", 8: "....aaaaab....", 14: "g...aaaaab...g"},
	},

	# --- Chalk Cliffs ---------------------------------------------------------
	# A small rock on feet, cut in flat faces: the lit one top left, the dark one right. a stone, b dark face, c lit face.
	"pebble": {
		"rows": [
			".....cccc.......",
			"...cccccaaa.....",
			"..ccccaaaaaab...",
			".cccaaaaaaaabb..",
			".ccaaaaaaaaabbb.",
			"ccaawkaawkaabbb.",
			"caaakkaakkaabbbb",
			"caaaaaaaaaaabbbb",
			"caaaabkkbaaabbbb",
			".aaaaaaaaaabbbb.",
			"..aaaaaaabbbbb..",
			"..kk......kk....",
		],
		"alt": {11: ".kk........kk..."},
		"cut": [9],
	},
	# A bat, wings up then down. a body, b wing, c wing light, e eye.
	"bat": {
		"rows": [
			".......a....a.......",
			"bb.....aa..aa.....bb",
			"bbb....aaaaaa....bbb",
			"bbbbb.aaeaaeaa.bbbbb",
			"bcbbbbaaaaaaaabbbbcb",
			"bcbbbbbaawwaabbbbbcb",
			"bcbbbbbaaaaaabbbbbcb",
			"b.bb.bbbaaaabbb.bb.b",
			"...b..b.aaaa.b..b...",
			".........aa.........",
		],
		"two": [
			".......a....a.......",
			".......aa..aa.......",
			"....b..aaaaaa..b....",
			"..bbbbaaeaaeaabbbb..",
			".bbbbbaaaaaaaabbbbb.",
			"bbcbbbbaawwaabbbbcbb",
			"bbcbbbbaaaaaabbbbcbb",
			"bbb.bbbbaaaabbbb.bbb",
			"bb...b..aaaa..b...bb",
			"b........aa........b",
		],
	},
	# A golem of scree: small head, big shoulders, fists. a stone, d cracks, e eyes.
	"golem": {
		"rows": [
			"......aaaaaa......",
			".....aaaaaaaa.....",
			".....aeeaaeea.....",
			".....aaaaaaab.....",
			"..caaaabbbbaaaac..",
			".caaaaaaaaaaaaaab.",
			"caaadaaaaaaaadaaab",
			"caaabaaadaaaabaaab",
			"caab.aaaadaaa.baab",
			"caab.aaaaaaaa.baab",
			"caab.aadaaaab.baab",
			"aaab.aaaaaaab.baab",
			"aaab..aaa.aaa..aab",
			"bbb...aab.aab..bbb",
			"......aab.aab.....",
			".....aaab.aaab....",
		],
		"alt": {2: ".....aaaaaaaa....."},
		"cut": [9],
	},
	# A wisp of chalk dust. a body, b shade, c bright.
	"wisp": {
		"rows": [
			".......a......",
			"......aa......",
			"......aaa.....",
			".....aaaa.b...",
			"....aaaaaa....",
			"...aaacaaaa...",
			"..aaaccaaaaa..",
			"..aakkaakkaa..",
			".aaakkaakkaab.",
			".aaaaaaaaaaab.",
			".aaaaakkaaaab.",
			"..aaaaaaaaab..",
			"..baaaaaaabb..",
			"b...bbaabb....",
			"......bb...b..",
		],
		"alt": {
			0: "......a.......",
			1: "......aa......",
			2: ".....aaa......",
			3: "...b.aaaa.....",
			13: "....bbaabb...b",
			14: ".b....bb......",
		},
	},
	# A rope that is a cobra: a small head over a wide hood, up out of its own coil, a frayed end for a tail.
	# a rope, b twist, c belly, d belly plates, r tongue.
	"snake": {
		"half": [
			"........aa",
			".......aaa",
			".......aka",
			".......aaa",
			".....aaaak",
			"...aaaaacr",
			"..aabaaccr",
			".aabaaaccc",
			".aabaaaddd",
			"..aabaaccc",
			"...aabaddd",
			".....abacc",
			"......badd",
			"..aaaaaaaa",
			"..abaabaab",
			"aabbbbbbbb",
			"abaabaabaa",
			"aabaabaaba",
			".bbbbbbbbb",
		],
		"over": [[7, 8, "r"], [7, 11, "r"], [11, 19, "c"], [12, 18, "ca"], [13, 18, "ab"], [14, 18, "ab"]],
		"alt": {5: "...aaaaack", 6: "..aabaaccc"},
		"alt_over": [[7, 8, "c"], [7, 11, "c"]],
		"cut": [12],
	},

	# --- The Stacks -----------------------------------------------------------
	# A worm with reading glasses. a body, b rings, c belly, g frames, w lenses.
	"worm": {
		"rows": [
			"..aaaaa.........",
			".aaaaaaa........",
			"gggagggaa.......",
			"gwkggwkga.......",
			"gggagggaa.......",
			".aaaaaaab.......",
			"..akkaaab...aa..",
			"...aaaaab..aaaa.",
			"...caabaaaabaaaa",
			"...caabaaaabaaab",
			"....aabaaaabaab.",
			".....bbbbbbbbb..",
		],
		"alt": {3: "gkwggkwga.......", 6: "..akkaaab....aa.", 7: "...aaaaab...aaaa", 8: "...caabaaaabaaab", 9: "...caabaaaabaab."},
	},
	# A splash of ink. a ink, c shine.
	"blot": {
		"rows": [
			"..a.........a...",
			".....aaaa.......",
			"a..aaaaaaaa...a.",
			"..aacaaaaaaaa...",
			".aaccaaaaaaaaa..",
			".aawwaaawwaaaa.a",
			"aaawkaaawkaaaaa.",
			"aaaaaaaaaaaaaaa.",
			"aaaaakkkaaaaaaa.",
			".aaaaaaaaaaaaa..",
			".aa.aaaaaa.aaa..",
			".a...aa.a...a...",
			".....a......a...",
		],
		"alt": {
			0: ".a...........a..",
			2: "...aaaaaaaa.....",
			5: ".aawwaaawwaaaa..",
			6: "aaakwaaakwaaaaaa",
			11: ".a...aa.a...a...",
			12: ".a...a..a...a...",
		},
	},
	# A book in its jacket, flaps out. a jacket, b shade, c pages, r ribbon.
	"book": {
		"rows": [
			"...aaaaaaaaaa...",
			"..aaaaaaaaaaac..",
			".aaabbbbbbbaacc.",
			"aa.abaaaaabaac.a",
			"aa.aawkawkaaac.a",
			"aa.aakkakkaaac.a",
			"aa.aaaaaaaaaac.a",
			"aa.aaakkkaaaac.a",
			"a..abaaaaabaac.a",
			"a..abbbbbbbaac..",
			"...aaaaaaaaaac..",
			"...aaaarraaaac..",
			"...bbbbrrbbbbd..",
			".......rr.......",
		],
		"alt": {
			2: "..aabbbbbbbaacc.",
			3: ".a.abaaaaabaaca.",
			4: ".a.aawkawkaaaca.",
			5: ".a.aakkakkaaaca.",
			6: ".a.aaaaaaaaaaca.",
			7: ".a.aaakkkaaaaca.",
			8: "...abaaaaabaaca.",
			13: "........rr......",
		},
	},
	# A small knight with shield and sword. a armour, b shade, s t shield, d blade.
	"knight": {
		"rows": [
			"......aaaa....d.",
			".....aaaaaa...d.",
			".....akkkka...d.",
			".....aaaaab...d.",
			"......abbb....d.",
			".ssss.aaaa....d.",
			"sstssaaaaaaa.ttt",
			"sttssaaaaaaaaab.",
			"sstssaaabaab....",
			"sstssaaaaaab....",
			".sss.aaaaaab....",
			"..s...abbab.....",
			"......aa.aa.....",
			"......aa.aa.....",
			".....baa.aab....",
		],
		"cut": [12],
	},
	# A letter with a clock for a seal. a paper, b fold, r stamp, c dial, y rim.
	"letter": {
		"rows": [
			"aaaaaaaaaaaaaaaa",
			"abaaaaaaaaaaaaba",
			"aabakkaaaakkabaa",
			"aaabkwaaaakwbaaa",
			"aaaabyyyyyybaaaa",
			"aaaayccccccyaaaa",
			"arrayccckccyaaaa",
			"arrayccckkcyaaaa",
			"aaaayccccccyaaaa",
			"aaaaayyyyyyaaaaa",
			"bbbbbbbbbbbbbbbb",
			"..bb........bb..",
		],
		"alt": {6: "arrayccccccyaaaa", 7: "arraycckkkcyaaaa", 11: ".bb..........bb."},
	},

	# --- The Ironworks --------------------------------------------------------
	# A mite under a rivet head. a iron, b shade, c dome, o eyes.
	"mite": {
		"rows": [
			"....cccccc....",
			"...ccaaaaaa...",
			"..caaaaaaaab..",
			"..caaaaaaaab..",
			".aaaaaaaaaaaa.",
			"aaaooaaaaooaaa",
			"a.aaaaaaaaaa.a",
			"..abaabbaaba..",
			".a.a.a..a.a.a.",
			"a..a.a..a.a..a",
		],
		"alt": {8: "a..a.a..a.a..a", 9: ".a.a.a..a.a.a."},
	},
	# An imp of slag with a flame on its head. a body, b shade, o y fire.
	"imp": {
		"rows": [
			"...y........y...",
			"..yo...yy...oy..",
			"..oa..yooy..ao..",
			"..aa.aaaaaa.aa..",
			"..aaaaaaaaaaaa..",
			"...aayoaayoaa...",
			"...aaooaaooaa...",
			"...aaaaaaaaaa...",
			"...aawkwkwkaa...",
			"....aaaaaaaa....",
			"..aa.aaoaaa.aa..",
			".aa..aaaoaa..aa.",
			".a...aaaaaa...a.",
			".....aa..aa.....",
			"....baa..aab....",
		],
		"alt": {
			0: "..y..........y..",
			1: "..yo..y..y..oy..",
			2: "..oa..oyyo..ao..",
			10: ".aa..aaoaaa..aa.",
			11: "aa...aaaoaa...aa",
			12: "a....aaaaaa....a",
		},
	},
	# A turtle carrying an anvil. a iron, b shade, c top, t skin, u skin shade.
	"anvil_turtle": {
		"rows": [
			"....cccccccccccccc..",
			"cccccaaaaaaaaaaaaab.",
			".aaaaaaaaaaaaaaaaab.",
			"...aaaaaaaaaaaaaab..",
			".......aaaaaaaab....",
			"......aaaaaaaaab....",
			".ttt.aaaaaaaaaaaab..",
			"twkttuaaaaaaaaaabb..",
			"ttttttuuuuuuuuuuut..",
			".tkktttttttttttttut.",
			"...ttttttttttttttu.t",
			"...tt.tt.....tt.tt..",
			"...uu.uu.....uu.uu..",
		],
		"alt": {7: "tkkttuaaaaaaaaaabb..", 10: "...tttttttttttttuut.", 11: "..tt..tt....tt..tt..", 12: "..uu..uu....uu..uu.."},
	},
	# Bellows: nozzle left, boards and handles right. a wood, l leather, b folds, n nozzle.
	"bellows": {
		"rows": [
			"........aaaaaaaa..",
			"......aaaaaaaaaaaa",
			"....aaalllllllb...",
			"...aalllblllblb...",
			"nnaallwklblwklb...",
			"nnnalllllblllbb...",
			"nnaalllkkklllb....",
			"...aalllblllblb...",
			"....aaalllllllb...",
			"......aaaaaaaaaaaa",
			"........aaaaaaaa..",
		],
		"alt": {
			0: "..................",
			1: "........aaaaaaaa..",
			2: "......aaaaaaaaaaaa",
			3: "...aaalllblllblb..",
			7: "...aaalllblllblb..",
			8: "......aaaaaaaaaaaa",
			9: "........aaaaaaaa..",
			10: "..................",
		},
	},
	# A barbell glowing in the middle. a plates, b shade, c light, o y r molten.
	"barbell": {
		"rows": [
			".aaa..............aaa.",
			"caaab............caaab",
			"caaabca..oooo..cacaaab",
			"caaabca.ooyyoo.cacaaab",
			"caaabcaookyykoocacaaab",
			"caaabcayoyyyyoycacaaab",
			"caaabcaooykkyoocacaaab",
			"caaabcb.oooooo.cbcaaab",
			"caaabcb..oroo..cbcaaab",
			"caaab.....r......caaab",
			"baaab............baaab",
			".bbb..............bbb.",
		],
		"alt": {
			2: "caaabca..oyyo..cacaaab",
			3: "caaabca.oyyyyo.cacaaab",
			5: "caaabcayyyyyyyycacaaab",
			7: "caaabcb.ooyyoo.cbcaaab",
			8: "caaabcb..oooo..cbcaaab",
			9: "caaab......r.....caaab",
			10: "baaab......r.....baaab",
		},
	},

	# --- Mirror Marsh ---------------------------------------------------------
	# A leech, mouth first. a body, b shade, c belly, r w mouth, v stripes.
	"leech": {
		"rows": [
			"..akak..........",
			".awwwaa.........",
			"awrrrwaa........",
			"awrrrwaa........",
			".awwwaava.......",
			"..caaaaavaa.....",
			"...caaavaaavaa..",
			"...ccaaaaavaaaa.",
			"....cccaaaaaavaa",
			".....ccccaaaaaab",
			".......bbbbbbbb.",
		],
		"alt": {
			1: ".aawaaa.........",
			2: "aawrwaaa........",
			3: "aawrwaaa........",
			4: ".aawaaava.......",
			7: "...ccaaaaavaaa..",
			8: "....cccaaaaaava.",
			9: ".....ccccaaaaaaa",
			10: ".......bbbbbbbbb",
		},
	},
	# A frog, front on. a skin, b shade, c belly, y eyes, v spots.
	"frog": {
		"rows": [
			"..aaaa....aaaa..",
			".aykyaa..aaykya.",
			".aykyaaaaaaykya.",
			".aaaaaaaaaaaaaa.",
			"aaavaaaaaaaavaaa",
			"aakkkkkkkkkkkkaa",
			"aaaccccccccccaaa",
			"baaaccccccccaaab",
			"bba.acccccca.abb",
			"bb..aa.cc.aa..bb",
			"bbb.bb....bb.bbb",
		],
		"alt": {1: ".aaaaaa..aaaaaa.", 2: ".aykyaaaaaaykya.", 6: "aaccccccccccccaa"},
		"cut": [7],
	},
	# A wraith of reeds under a cattail. a reed, b shade, c light, h cattail, v eyes.
	"reed": {
		"rows": [
			"......hh......",
			".....hhhh.....",
			".....hhhh.....",
			".....hhhh.....",
			"......aa......",
			"....aaaaaa....",
			"...aavaavaa...",
			"c..aaaaaaaa..c",
			"ca.aaakkaaa.ac",
			".aaaaaaaaaaaa.",
			"..caaaaaaaab..",
			"...caaaaaab...",
			"...caaaaaab...",
			"....caaaab....",
			"....caaaab....",
			"...ca.aa.ab...",
			"...a..aa..b...",
			"......a.......",
		],
		"alt": {
			7: ".c.aaaaaaaa.c.",
			8: ".caaaakkaaaac.",
			9: "..aaaaaaaaaa..",
			15: "..ca..aa..ab..",
			16: "..a...aa...b..",
			17: ".......a......",
		},
	},
	# A standing mirror with a shade in the glass. f g frame, m n glass, s shade, e eyes.
	"mirror": {
		"rows": [
			"....ffffff....",
			"..fffmmmmfff..",
			".ffmnmmmmmmff.",
			"ffmnmmssmmmmfg",
			"fmnmmssssmmmfg",
			"fmmmsessesmmfg",
			"fmmmssssssmmfg",
			"fmmmmssssmmmfg",
			"fmmmsssssssmfg",
			"fmmsssssssssfg",
			"fmmssssssssmfg",
			"ffmssssssssffg",
			".ffmssssssffg.",
			"..fffffffffg..",
			".....ffgg.....",
			".....ffgg.....",
			"...ffffgggg...",
			"..ffffffgggg..",
		],
		"alt": {
			2: ".ffmmmnmmmmff.",
			3: "ffmmmsnsmmmmfg",
			4: "fmmmssssnmmmfg",
			5: "fmmsessessmmfg",
			6: "fmmssssssmmmfg",
			7: "fmmmssssmmmmfg",
			8: "fmmsssssssmmfg",
		},
	},

	# --- Stormspine Ridge -----------------------------------------------------
	# A mote of static. y spark, w core.
	"spark": {
		"rows": [
			"..y...yy...y..",
			"...y..yy..y...",
			"....yyyyyy....",
			"...yywwwwyy...",
			"yy.ywwwwwwy.yy",
			".yyywkwwkwyyy.",
			"...ywkwwkwy...",
			".yyywwwwwwyyy.",
			"yy.ywwkkwwy.yy",
			"...yywwwwyy...",
			"....yyyyyy....",
			"...y..yy..y...",
			"..y...yy...y..",
		],
		"alt": {
			0: "...y..yy..y...",
			1: "..y...yy...y..",
			4: ".yyywwwwwwyyy.",
			5: "yy.ywkwwkwy.yy",
			7: "yy.ywwwwwwy.yy",
			8: ".yyywwkkwwyyy.",
			11: "..y...yy...y..",
			12: "...y..yy..y...",
		},
	},
	# A hawk, wings up then down. a feathers, b shade, c chest, y beak and claws.
	"hawk": {
		"rows": [
			"aa................aa",
			"aaa..............aaa",
			"baaa............aaab",
			".baaa....aa....aaab.",
			".baaaa..aaaa..aaaab.",
			"..baaaaakaakaaaaab..",
			"..bbaaaaayyaaaaabb..",
			"...bbaaaayyaaaabb...",
			"....bbcaaaaaacbb....",
			"......ccaaaacc......",
			"......cccaaccc......",
			".......baaaab.......",
			"......yy.bb.yy......",
			"......y.y..y.y......",
		],
		"two": [
			"....................",
			"....................",
			".........aa.........",
			"........aaaa........",
			"..aaaaaakaakaaaaaa..",
			".aaaaaaaayyaaaaaaaa.",
			"baaaabaaayyaaabaaaab",
			"baab.bbaaaaaabb.baab",
			"bb....bcaaaacb....bb",
			"b.....ccaaaacc.....b",
			"......cccaaccc......",
			".......baaaab.......",
			"......yy.bb.yy......",
			"......y.y..y.y......",
		],
	},
	# A goat in profile, rime on its back. a coat, b shade, h horns, i ice, d hooves.
	"goat": {
		"rows": [
			"...hhhh.............",
			"..hh..hh............",
			".hh.aa.hh...........",
			".h.aaaa.h..iiiii....",
			"..aakaaa.iiaaaaaii..",
			".aaaaaaaaaaaaaaaaaa.",
			"aaaaaaaaaaaaaaaaaaab",
			".bbaaaaaaaaaaaaaaaab",
			"..b.baaaaaaaaaaaaab.",
			"..b..aaaaaaaaaaaaab.",
			".....aabbbbbbbbaab..",
			".....aa.aa...aa.aa..",
			".....aa.aa...aa.aa..",
			".....dd.dd...dd.dd..",
		],
		"alt": {8: ".b..baaaaaaaaaaaaab.", 9: ".b...aaaaaaaaaaaaab."},
		"cut": [11],
	},
	# A war drum with two sticks. a shell, b shade, s skin, y lacing, d sticks.
	"drum": {
		"rows": [
			"dd............dd",
			".dd..........dd.",
			"..dd........dd..",
			"...d.ssssss.d...",
			"..ssssssssssss..",
			".ssssssssssssss.",
			".bssssssssssssb.",
			".ayaaaaaaaaaaya.",
			".aayawkaawkayaa.",
			".aaaykkaakkyaab.",
			".aaayaaaaaayaab.",
			".aayaakkkkaayab.",
			".ayaaaaaaaaaayb.",
			"..bbbbbbbbbbbb..",
			"...bb......bb...",
		],
		"alt": {0: "..............dd", 1: ".............dd.", 2: ".dd.........dd..", 3: "..dd.ssssss.d...", 11: ".aayaaakkaaayab."},
	},
	# An eye in a ring of cloud. c d l cloud, w white, i iris.
	"eye": {
		"rows": [
			"....ll...lll......",
			"..llcclllcccll....",
			".lccccccccccccll..",
			".lcccwwwwwwccccl..",
			"lcccwwwiiwwwccccl.",
			"lccwwwiikiiwwcccc.",
			"cccwwwikkkiwwwcccd",
			"cccwwwiikiiwwwccdd",
			".ccdwwwiiwwwdccdd.",
			".cddddwwwwddddcd..",
			"..dccddddddccdd...",
			"...ddccdddccdd....",
			".....dd...dd......",
		],
		"alt": {
			0: "...ll....lll......",
			4: "lcccwwiiwwwwccccl.",
			5: "lccwwiikiiwwwcccc.",
			6: "cccwwikkkiwwwwcccd",
			7: "cccwwiikiiwwwwccdd",
			8: ".ccdwwiiwwwwdccdd.",
			12: "......dd...dd.....",
		},
	},

	# --- Titan's Rest ---------------------------------------------------------
	# A hooded figure of stone holding a light. a robe, b shade, c light, g trim, o orb, e eyes.
	"acolyte": {
		"rows": [
			".....aaaa.....",
			"....aaaaaa....",
			"...aaaaaaaa...",
			"...aakkkkaa...",
			"..aakekkekaa..",
			"..aakkkkkkab..",
			"..caaakkaaab..",
			".caaaaaaaaaab.",
			".caaggooggaab.",
			".caaaaooaaaab.",
			".caaaaaaaaaab.",
			"..aaabaaabaab.",
			"..aaabaaabaab.",
			".caaabaaabaaab",
			".caaabaaabaaab",
			"ggggggggggggbb",
			".bbbbbbbbbbbb.",
		],
		"alt": {7: ".caaaaooaaaab.", 8: ".caagoooogaab.", 9: ".caaaooooaaab.", 10: ".caaaaooaaaab."},
	},
	# A statue with a halberd. a armour, b shade, c light, g gold, e eyes, d blade.
	"guard": {
		"rows": [
			".d..............",
			"ddd....g..g.....",
			"ddd....gaag.....",
			".b....caaaaa....",
			".b....aeaaea....",
			".b....aaaaaab...",
			".b..ggaabbaagg..",
			".b.gcaaaaaaaaag.",
			"aabcaaaaggaaaaab",
			"aabaaaaaggaaaaab",
			".b.baaaaaaaab.aa",
			".b..aaaaaaaab.aa",
			".b..gggggggg..aa",
			".b..aaab.aaab...",
			".b..aaab.aaab...",
			".b..aaab.aaab...",
			".b.gaaab.aaabg..",
			".b.bbbbb.bbbbb..",
		],
		"alt": {4: ".b....aaaaaa...."},
		"cut": [14],
	},
	# A moth, wings wide then half shut. a wing, b shade, c bands, g eye spots, f body.
	"moth": {
		"rows": [
			"......c......c......",
			".......c....c.......",
			".aaaa...c..c...aaaa.",
			"aaaaaaa.ffff.aaaaaaa",
			"aacggcaafkkfaacggcaa",
			"aacggcaaffffaacggcaa",
			"aaaccaaaffffaaaccaaa",
			".aaaaaaaffffaaaaaaa.",
			"..baaaaaffffaaaaab..",
			".aaaaaab.ff.baaaaaa.",
			".aacaaab.ff.baaacaa.",
			"..aaaab......baaaa..",
			"...bbb........bbb...",
		],
		"two": [
			"......c......c......",
			".......c....c.......",
			"...aaa..c..c..aaa...",
			"..aaaaa.ffff.aaaaa..",
			"..acggcafkkfacggca..",
			"..acggcaffffacggca..",
			"..aaccaaffffaaccaa..",
			"...aaaaaffffaaaaa...",
			"....baaaffffaaab....",
			"...aaaab.ff.baaaa...",
			"...acaab.ff.baaca...",
			"....aab......baa....",
			".....b........b.....",
		],
	},
	# A splinter of the titan with a lit core. a crystal, b shade, c light, g o core.
	"shard": {
		"rows": [
			"......ca......",
			".....ccab.....",
			".....ccab.....",
			"....cccaab....",
			"....ccgaab....",
			"...cccgaaab...",
			".a.ccggaaab.b.",
			"...cckggkab...",
			"..cccggggaab..",
			"..ccaggoaaab..",
			"...caagoaab...",
			"...caaoaaab...",
			"....caoaab....",
			"....caaaab....",
			".b...caab...a.",
			".....caab.....",
			"......ab......",
		],
		"alt": {6: "a..ccggaaab..b", 8: "..ccgggggaab..", 9: "..ccgggoaaab..", 10: "...cagggaab...", 11: "...caagoaab...", 14: "..b..caab..a.."},
	},

	# --- Elites ---------------------------------------------------------------
	# A barbell bent into an arch, standing on its plates. s t u steel, p q plates, r rust, e eyes.
	"bent_bar": {
		"half": [
			"........ssss",
			"......ssuuuu",
			".....suussss",
			"....suusskks",
			"...suussseks",
			"..suuss.ssss",
			"..sus...swkw",
			"..sus...ssss",
			"..sus....ttt",
			"..sus.......",
			"..sus.......",
			"ppppppp.....",
			"qpprppq.....",
			"ppppppp.....",
			"qprpppq.....",
			"..sus.......",
			"..ttt.......",
		],
		"alt": {4: "...suusssees"},
		"cut": [9],
	},
	# A hill with a face, a path and a flag. g h l grass, e d path, t bushes, p r flag.
	"the_hill": {
		"half": [
			"............p",
			"............p",
			"............p",
			".........lllg",
			".......llgggg",
			".....llgggggg",
			"....lggggggge",
			"...lgggkkgggg",
			"..lggggwkggge",
			"..lggggkkgggg",
			".lggtggggggee",
			".lgtttgggkkkk",
			"lggtttggggeeg",
			"lgggtgggggeeg",
			"hgggggggggeee",
			"hhggggghhggee",
			".hhhhhhhhhhdd",
		],
		"over": [[0, 14, "rrrr"], [1, 14, "rrr"]],
		"alt": {8: "..lggggkkggge"},
		"alt_over": [[0, 14, "rrr."], [1, 14, "rrrr"], [2, 14, "r"]],
	},
	# A cliff that leans out, eyes in its shadow. a b c stone, d shadow, e eyes, h i holds, w chalk.
	"overhang": {
		"half": [
			"..cccccccccc",
			".caaaaaaaaaa",
			"caaaaahaaaaa",
			"caawaaaaaiaa",
			"caaaaaaaaaaa",
			"baaaaaaaaaaa",
			".bbbaaaaaaaa",
			"...dbbbbbbbb",
			"....dddddddd",
			"....adeeddkd",
			"....aaddddkk",
			".....aaadwdw",
			".....aaaaaaa",
			"....caaahaaa",
			"....caaaaaaa",
			"...caaaaaiaa",
			"...baaaaaaaa",
			"..bbbbbbbbbb",
		],
		"alt": {9: "....addeedkd"},
		"alt_over": [[5, 3, "."], [6, 3, "w"], [7, 2, "w"]],
	},
	# A card cabinet: label eyes and an open drawer of cards. a b c wood, l labels, g brass, w cards.
	"the_index": {
		"half": [
			".cccccccccc",
			"caaaaaaaaaa",
			"cabbbbbbbba",
			"caballllbaa",
			"cabalkklbaa",
			"cabaaggabaa",
			"cabbbbbbbba",
			"caaaaaaaaaa",
			"cabbbbbbbbb",
			"cabwkwkwkwk",
			"cabkkkkkkkk",
			"cabaaaaaaaa",
			"cabaaaaaagg",
			"cabbbbbbbbb",
			"caaaaaaaaaa",
			"bbbbbbbbbbb",
			".bb........",
		],
		"alt": {4: "caballkkbaa", 9: "cabkwkwkwkw", 10: "cabwkkkkkkk"},
	},
	# A golem that is a press: ram head on a piston. a b c iron, o y heat, s piston.
	"press_golem": {
		"half": [
			".ccccccccccc",
			"caaaaaaaaaaa",
			"caoaoaoaoaoa",
			"baaaaaaaaaaa",
			".bbbbbbbbbbb",
			".........sss",
			".........sss",
			"...ccccccaaa",
			"..caaaaaaaaa",
			"ccaaaaayyaaa",
			"aaabaaayyaaa",
			"aaabaaaaakkk",
			"aaabaaaaayoy",
			"aaabaaaaakkk",
			"aab.baaaaaaa",
			"aab..bbbbbbb",
			"ccc..aaab...",
			"aaa..aaab...",
			"bbb.aaaab...",
		],
		"alt": {12: "aaabaaaaaoyo"},
		"cut": [5],
	},
	# A stump on a tangle of roots. a b c bark, m moss, e eyes, k hollow.
	"knotroot": {
		"half": [
			"..a.........",
			".aa...a.....",
			".aaa.aa.....",
			"..aaaaa.mmmm",
			"...aaaammmmm",
			"...caaaaaaaa",
			"..caabaaaaba",
			"..caaaeeaaaa",
			"..caaaeeabaa",
			"..cabaaaaaak",
			"..caaaaaakkk",
			"..caabaakkkk",
			"..caaaaaakkk",
			".ccaaabaaaaa",
			"caaabaaaabaa",
			"aab.aab.aaba",
			"ab..ab...ab.",
		],
		"alt": {7: "..caaaaaaaaa", 15: "aab.aab.aaba", 16: ".ab.ab...ab."},
		"cut": [12],
	},
	# A giant of stacked stones, a last loose one on its head (it rocks). a b c stone, s snow, e eyes, k cracks.
	"cairn_giant": {
		"half": [
			"........sss",
			".......caaa",
			"......sssss",
			".....saaaaa",
			".....aaeeaa",
			".....baaaaa",
			"......bbbbb",
			"..sssssssss",
			".caaaaaaaaa",
			"caaaakaaaaa",
			"caaaaakaaaa",
			"baaaaaaaaaa",
			".bbbbbbbbbb",
			"ss..saaaaaa",
			"aac.caaaaka",
			"aab.baaaaaa",
			"aab..bbbbbb",
			"bbb..caaab.",
			".....aaaab.",
			"....bbbbbb.",
		],
		"alt_over": [[0, 8, ".ssssss"], [1, 7, ".caaaaaac"]],
		"cut": [15],
	},
	# A gate with a crowned face over its bars. a b c stone, g h gold, e eyes, i bars.
	"the_gatekeeper": {
		"half": [
			"......g..gh",
			"......ggggg",
			"....ccaaaaa",
			"...caaaaaaa",
			"..caaaeekaa",
			"..caaaaaaaa",
			".caaaaggggg",
			".caabbbbbbb",
			".caabkikiki",
			"ccaabkikiki",
			"caaabiiiiii",
			"caaabkikiki",
			"caaabkikiki",
			"caaabiiiiii",
			"caaabkikiki",
			"caaabkikiki",
			"baaabbbbbbb",
			"bbbbbbbbbbb",
		],
		"alt": {4: "..caaakeeaa", 8: ".caabkkkkkk", 9: "ccaabkikiki", 10: "caaabkikiki", 11: "caaabiiiiii", 12: "caaabkikiki", 13: "caaabkikiki", 14: "caaabiiiiii"},
	},

	# --- Bosses ---------------------------------------------------------------
	# Old Iron-Jaw: a locker whose door is a mouth. a b c steel, r o rust, w teeth, e eyes, t tongue, l lock.
	"old_iron_jaw": {
		"half": [
			".ccccccccccc",
			"caaaaaaaaaaa",
			"caaaaaaaaaaa",
			"caakkkkkkkaa",
			"caaaaaaaaaaa",
			"caakeeeekkaa",
			"caaaaaaaaaaa",
			"caakkeekkkaa",
			"caaaaaaaaaaa",
			"caaraaaaaaaa",
			"bbbbbbbbbbbb",
			"cakwwwkwwwkw",
			"cakkwkkkwkkw",
			"cakkkkkkkkkk",
			"cakkkkkktttt",
			"cakkkkkttttt",
			"cakkwkkkwkkw",
			"cakwwwkwwwkw",
			"bbbbbbbbbbbb",
			"caaaaaaaaaaa",
			"caaaaaaaraaa",
			"caaaaaaaoraa",
			"caaaaaaaaaaa",
			"caabbbbbbbaa",
			"caaaaaaaaaaa",
			"baaaaaaaaaaa",
			"bbbbbbbbbbbb",
			".bb.........",
		],
		"over": [[19, 14, "l.l"], [20, 14, "lll"], [21, 14, "lkl"], [20, 15, "l"], [9, 20, "o"], [8, 20, "r"]],
		"alt": {5: "caakkeeeekaa", 7: "caakkkeekkaa"},
		"cut": [13],
	},
	# The Pacer: a wolf of shadow at full stretch, then gathered. a b c body, e eye, s wisps.
	"the_pacer": {
		"rows": [
			".........a..a...................",
			"........aa.aa...................",
			".......aaaaaa................sss",
			".....aaaaaaaa..............ssaas",
			"...aaaeeaaaaaa..........sssaaas.",
			"aaaaaaaaaaaaaaaa....aaaaaaaaas..",
			"aaaaaaaaaaaaaaaaaaaaaaaaaaaaa...",
			".wawaaaaaaaaaaaaaaaaaaaaaaaaa...",
			"..aaa.caaaaaaaaaaaaaaaaaaaaaaa..",
			"......caaaaaaaaaaaaaaaaaaaaaaa..",
			".......caaaaaaaabbbbbaaaaaaaaa..",
			".......ccaaaaab.....baaaaaaaaa..",
			"......aaaaaab.........aaab.aaa..",
			"....aaaab.aab.........aab...aaa.",
			"..aaaab...aab.........aab....aa.",
			".aab......ab...........ab....aab",
			"bb.......bb............bb.....bb",
		],
		"alt": {
			2: ".......aaaaaa...............sss.",
			3: ".....aaaaaaaa.............ssaas.",
			4: "...aaaeeaaaaaa..........sssaaass",
			12: "........aaaaab.......aaaab......",
			13: ".........aaaab......aaab........",
			14: "..........aaab.....aaab.........",
			15: "...........aab....aab...........",
			16: "...........bb.....bb............",
		},
	},
	# Skyhook: a drake, wings spread. a b c hide, m n wing skin, h horns and hooks, e eyes, y belly.
	"skyhook": {
		"half": [
			".h..............",
			"hh.........h....",
			"hca........hh...",
			".caaa.......hcca",
			".aamaaa.....caaa",
			"..ammaaaa..aaeka",
			"..ammmmaaaaaaaaa",
			"..ammmmmmaaaaaaa",
			"...ammmnmmmaakaa",
			"...ammmnmmmmaaww",
			"...ammnmmmnmmaaa",
			"....amnmmmnmmbaa",
			"....amnmmnmmmbyy",
			"....a.nmmnmm.ayy",
			"......n.mn.m.ayy",
			".............ayy",
			"............aayy",
			"...........haaay",
			"..........hh.aaa",
			"..........h..h.a",
		],
		"over": [[18, 22, "aa"], [19, 23, "aaa"], [19, 26, "h"], [18, 27, "h"], [17, 27, "h"], [16, 26, "h"]],
		"alt": {
			0: "................",
			1: "...........h....",
			2: "...........hh...",
			3: "............haaa",
			4: "..aaaa......aaaa",
			5: ".aaammaaa..aaeka",
			6: "haammmmmaaaaaaaa",
			7: "hhammmmmmmaaaaaa",
			8: ".h.ammmnmmmaakaa",
		},
	},
	# The Unread: a hooded wraith with an open book. a b c robe, k hood, e eyes, p q pages, r cover, h hands, d dust.
	"the_unread": {
		"half": [
			".........aaaa",
			".......aaaaaa",
			"......aacaaaa",
			".....aacaaaaa",
			".....aaakkkkk",
			"....aaakkkkkk",
			"....aaakkeekk",
			"....aaakkkekk",
			"....aaaakkkkk",
			"...caaaaakkkk",
			"..caaaaaaaaaa",
			".caaaaaaaaaaa",
			".caaaaaaaaaaa",
			"caaahhrrrrrrr",
			"caaahpppppppq",
			"caaarpqqqqppq",
			"caaarpppppppq",
			".aaarpqqqqqpq",
			".aaaarrrrrrrr",
			".caaaaaaaaaaa",
			"..aaaaaabaaaa",
			"..aaabaaaaaba",
			"..caaaaabaaaa",
			"...aabaaaaaba",
			"...aa.aaabaaa",
			"...a..aa.aaa.",
			"......a...a..",
			"..d......d...",
		],
		"alt": {
			7: "....aaakkeekk",
			24: "...aaa.aabaaa",
			25: "....a.aa..aa.",
			26: ".....a...a...",
			27: "...d......d..",
		},
	},
	# Foreman Slag: a foundry golem in a hard hat. a b c slag, o y r molten, h i hat.
	"foreman_slag": {
		"half": [
			".........hhhhhh",
			"........hhhhhhh",
			".......hhhhhhhh",
			"......iiiiiiiii",
			"........aaaaaaa",
			"........akyyaaa",
			"........aaoyaaa",
			"...ccc..aaaaaaa",
			"..caaaacaakkkkk",
			".caaoaaaaakyoyo",
			"caaaoaaaaakkkkk",
			"caaaaoaaaaaaaaa",
			"caaaaaoaaaaoaaa",
			"caaaabaoaaaoaaa",
			"caaab.aaoaoaaaa",
			"caaab.aaaoaaaaa",
			"caaab.aaaaoaaaa",
			"caaab.baaaaoaaa",
			"aaaab..aaaaaoaa",
			"aoaab..aaaaaaaa",
			"aaoab..baaaaaaa",
			"aaaab...aaaab..",
			"bbbb....aaaab..",
			".y......aaaab..",
			".......aaaaab..",
			".......bbbbbb..",
		],
		"pulse": "oy",
		"alt": {23: "........aaaab..", 24: ".o.....aaaaab.."},
	},
	# The Knot: a ball of two fat vines wound over each other, a loop and loose ends hanging out, eyes in its hollow.
	# a b c teal vine, v u p violet vine, k the dark inside, e eyes. Not typed by hand like the rest: the vines were
	# laid as tubes along curves, back to front (each lit on its upper side, a dark seam where one crosses another),
	# and the two frames kept as rows; the second has the loose ends swung and other eyes open.
	"the_knot": {
		"rows": [
			"...vv..........................",
			".vvvvvv....ccpppppp............",
			"vvvvvvv.cccaapvvvvppppp........",
			"vv...vccaaaabuuuvvvvvvppp......",
			"vv...caaabbbkkuuuuuuuvvvpp.....",
			"vvv.caabbbkkekekkkkkkuuvvpp....",
			".vvcaabbkkcppppppbbkkkkuuvpp...",
			"..ccabkkkcppvvvvvpppccckuuvu...",
			"..cabbkkcakuuuuuvvvvppaakuvvu..",
			".ccabkkcaakkkkkuuuuvvppbkuuvu..",
			".caabkccabbkkkckkkuuvvppkkpvu..",
			".cabkkcabbkkccaabbkkuuvpukpvuu.",
			".cabkcaabkkccaabbkkkkuvvukpvvu.",
			".cabkcabbkkcaabkkkkkkkpvukpvvu.",
			".cabkcabkkcaabkeekkeekpvvupvvu.",
			".babkcabkccabkkkekkkekkpvukuuk.",
			"..bkkaabkcaabkkkkkkkkkkpvukkkka",
			"...ucabbkcabkkkkkkkkkccpvuk..aa",
			"....cabbkcabkkkkkkkcccapvuu..aa",
			"....kbbkccabkcccccccaaauuukaaaa",
			"....kkkucbabkaaaaaaaabb.kkkaaa.",
			"....aa..kbbkbbaaabbbb....kk....",
			"....aa....kkbbbbbb.kk....vv....",
			"....aa.....kk......aa....v.....",
			"....aa.....vv......a....vv.....",
			".....a.....vv...........vv.....",
		],
		"two": [
			"...vv..........................",
			".vvvvvv....ccpppppp............",
			"vvvvvvv.cccaapvvvvppppp........",
			"vv...vccaaaabuuuvvvvvvppp......",
			"vv...caaabbbkkuuuuuuuvvvpp.....",
			"vvv.caabbbkkkkkkkkkkkuuvvpp....",
			".vvcaabbkkcppppppbbkkkkuuvpp...",
			"..ccabkkkcppvvvvvpppccckuuvu...",
			"..cabbkkcakuuuuuvvvvppaakuvvu..",
			".ccabkkcaakekekuuuuvvppbkuuvu..",
			".caabkccabbkkkckkkuuvvppkkpvu..",
			".cabkkcabbkkccaabbkkuuvpukpvuu.",
			".cabkcaabkkccaabbkkkkuvvukpvvu.",
			".cabkcabbkkcaabkkkkkkkpvukpvvu.",
			".cabkcabkkcaabkeekkeekpvvupvvu.",
			".babkcabkccabkkekkkekkkpvukuuk.",
			"..bkkaabkcaabkkkkkkkkkkpvukkkka",
			"...ucabbkcabkkkkkkkkkccpvuk..aa",
			"....cabbkcabkkkkkkkcccapvuu..aa",
			"....kbbkccabkcccccccaaauuukaaaa",
			"....kkkucbabkaaaaaaaabb.kkkaaa.",
			"....aa..kbbkbbaaabbbb....kk....",
			"....aa....kkbbbbbb.kk....vv....",
			"....aa.....kk.....aa.....vv....",
			"....a......vv.....a......vv....",
			"....a.......vv...........vv....",
		],
	},
	# Thunderhead: a storm cloud with a face, bolts under it. c d l w cloud, y eyes and bolts, i rain.
	"thunderhead": {
		"half": [
			"..........llllll",
			"........llwwwwww",
			"....lll.lwwlllll",
			"...lwwwllllllccc",
			"..lwwllllcccllcc",
			".llllllccccccccc",
			".lllcccccccccccc",
			"llcccccccccccccc",
			"lcccccdddccccccc",
			"ccccddkkkdcccccc",
			"ccccdyykkkdccccc",
			"cccddyyykkdccccd",
			"dccccdddddccccdd",
			"ddcccccccccdkkkk",
			".ddccccccccdkyky",
			".dddccccccddkkkk",
			"..ddddcccdddddd.",
			"....dddddd.....d",
			"....yy....i.....",
			"...yy......i....",
			"..yyyy....i.....",
			"....yy..........",
			"...yy.....i.....",
			"...y............",
		],
		"alt": {
			14: ".ddccccccccdkkyk",
			18: "...........i....",
			19: "....yy....i.....",
			20: "...yy......i....",
			21: "..yyyy....i.....",
			22: "....yy..........",
			23: "...yy.....i.....",
		},
	},
	# The Hollow Titan: a cracked colossus, head and shoulders. a b c stone, g h gold, k hollows, e the light inside.
	"the_hollow_titan": {
		"half": [
			".......h...h...h",
			".......g...g...g",
			"......ggg.ggg.gg",
			"......gggggggggg",
			"......ghgghgghgg",
			".....caaaaaaaaaa",
			"....caaaaaaaaaaa",
			"....caaaaaaaaaaa",
			"....cabbbbbbaaaa",
			"....cabkkkkkbaaa",
			"....cabkkkekbaaa",
			"....cabkkkkkbaab",
			"....caabbbbbaaab",
			"....caaaaaaaaaab",
			"....caaaaaaaaabb",
			".....aaaaaaabbbb",
			".....caaaaaaaaaa",
			".....caabkkkkkkk",
			"......aabkkkkkkk",
			"......caabbbbbbb",
			".......caaaaaaaa",
			"........baaaaaaa",
			"..gggg...bbaaaaa",
			".ghhhgggg..aaaaa",
			"gggggggggggaaaaa",
			"caaaaaaaaaggaaaa",
			"caaaaabaaaagaaaa",
			"caaabaaaaaaaaaaa",
			"caaaaaaaabaaaaaa",
			"baaaaaaaaaaaaaaa",
		],
		"over": [
			[5, 22, "k"], [6, 23, "k"], [7, 22, "kk"], [13, 24, "k"], [14, 24, "k"], [15, 25, "kk"], [16, 26, "k"],
			[22, 28, ".."], [23, 28, "...."], [24, 30, ".."], [25, 31, "."],
			[26, 20, "k"], [27, 21, "k"], [28, 21, "kk"],
		],
		"alt_over": [[10, 9, "ee"], [10, 21, "ee"], [9, 10, "e"], [9, 21, "e"], [18, 15, "ee"]],
	},
}

## foe id -> {sprite, palette, hover}. One entry per foe of RPG_PLAN.md 8.3.
const LOOKS = {
	# --- The Rustyard: rust and steel ------------------------------------------
	"dust_bunny": {"sprite": "bunny", "palette": {"a": "#b9a892", "b": "#8a7966", "c": "#ddd0bc", "p": "#e09a8c", "k": K, "w": "#ffffff"}, "hover": false},
	"rust_rat": {"sprite": "rat", "palette": {"a": "#a85a32", "b": "#6e3519", "c": "#dba77a", "p": "#e8a090", "k": K, "w": "#ffffff"}, "hover": false},
	"squeaky_plate": {"sprite": "plate", "palette": {"a": "#7d8b99", "b": "#515d6a", "c": "#b3bfcc", "r": "#b5522a", "k": K, "w": "#ffffff", "m": "#2a2230"}, "hover": false},
	"loose_collar": {"sprite": "collar", "palette": {"a": "#aab6c2", "b": "#74808e", "c": "#d64545", "k": K, "w": "#ffffff"}, "hover": true},
	"moldy_towel": {"sprite": "towel", "palette": {"a": "#ded6bb", "b": "#aaa188", "g": "#7fa650", "d": "#4d7032", "s": "#c86a3a", "k": K}, "hover": false},
	"bent_bar": {"sprite": "bent_bar", "palette": {"s": "#9aa7b5", "t": "#5d6875", "u": "#d0d8e0", "p": "#6a4a3c", "q": "#44302a", "r": "#b5522a", "k": K, "w": "#ffffff", "e": "#ff5c3a"}, "hover": false},
	"old_iron_jaw": {"sprite": "old_iron_jaw", "palette": {"a": "#7d8b99", "b": "#515d6a", "c": "#b3bfcc", "r": "#b5522a", "o": "#d98048", "k": K, "w": "#f4f0e0", "e": "#ffb02a", "t": "#c8402e", "l": "#e0a53a"}, "hover": false},

	# --- The Greenmile: greens and earth ---------------------------------------
	"burr": {"sprite": "burr", "palette": {"a": "#9a8a42", "b": "#5f5426", "c": "#e0d088", "k": K, "w": "#ffffff"}, "hover": false},
	"briar_fox": {"sprite": "fox", "palette": {"a": "#c9702e", "b": "#8a4418", "c": "#f3e2bc", "g": "#4f9a3a", "n": K, "k": K}, "hover": false},
	"mud_slinger": {"sprite": "mudblob", "palette": {"a": "#8a6a45", "b": "#5c4429", "c": "#b89468", "o": "#4a3422", "k": K, "w": "#ffffff"}, "hover": false},
	"stag_beetle": {"sprite": "beetle", "palette": {"a": "#3f7a3a", "b": "#27502a", "c": "#8fd46a", "m": "#7a5a36", "k": K, "w": "#ffffff"}, "hover": false},
	"mile_marker": {"sprite": "post", "palette": {"a": "#b08a5a", "b": "#7a5a36", "c": "#f3ecd8", "r": "#d64545", "g": "#5fae4b", "k": K}, "hover": false},
	"the_hill": {"sprite": "the_hill", "palette": {"g": "#5fae4b", "h": "#3d7a35", "l": "#8fd46a", "e": "#c8a070", "d": "#7a5a36", "k": K, "w": "#ffffff", "r": "#e0483a", "p": "#e8e0d0", "t": "#2f6a2f"}, "hover": false},
	"the_pacer": {"sprite": "the_pacer", "palette": {"a": "#2f5a44", "b": "#1c3a2c", "c": "#5f9a74", "e": "#c8ff6a", "w": "#ffffff", "s": "#7fcf9a"}, "hover": false},

	# --- Chalk Cliffs: pale stone and sky --------------------------------------
	"pebbling": {"sprite": "pebble", "palette": {"a": "#b9ad94", "b": "#857a64", "c": "#e4dcc8", "k": K, "w": "#ffffff"}, "hover": false},
	"cliff_bat": {"sprite": "bat", "palette": {"a": "#8a94a6", "b": "#5a6478", "c": "#b9c6d8", "e": "#ffe066", "w": "#ffffff"}, "hover": true},
	"scree_golem": {"sprite": "golem", "palette": {"a": "#a79c86", "b": "#74695a", "c": "#d2c8b2", "d": "#4e463a", "e": "#6fc8f0"}, "hover": false},
	"chalk_wisp": {"sprite": "wisp", "palette": {"a": "#eef2f5", "b": "#a9bccb", "c": "#ffffff", "k": "#3a4a5a"}, "hover": true},
	"rope_snake": {"sprite": "snake", "palette": {"a": "#d2ae72", "b": "#8f6c3a", "c": "#f0deb0", "d": "#d9bf8a", "r": "#d64545", "k": K}, "hover": false},
	"overhang": {"sprite": "overhang", "palette": {"a": "#c2b8a2", "b": "#8a8070", "c": "#ece6d6", "d": "#4e483e", "e": "#6fc8f0", "h": "#e05a4a", "i": "#4a9ae0", "w": "#ffffff", "k": "#2a2620"}, "hover": false},
	"skyhook": {"sprite": "skyhook", "palette": {"a": "#7f9ab8", "b": "#566e8a", "c": "#c8dcec", "m": "#ddd6c4", "n": "#a8a08e", "h": "#f6f2e6", "e": "#ffd040", "k": K, "w": "#ffffff", "y": "#f3e7c0"}, "hover": true},

	# --- The Stacks: parchment, ink and candle ---------------------------------
	"bookworm": {"sprite": "worm", "palette": {"a": "#d9c48a", "b": "#a48a4e", "c": "#f3e7b8", "g": "#3a3670", "w": "#e8f0ff", "k": K}, "hover": false},
	"ink_blot": {"sprite": "blot", "palette": {"a": "#3f3b7a", "c": "#7a76c0", "w": "#ffffff", "k": K}, "hover": false},
	"dust_jacket": {"sprite": "book", "palette": {"a": "#d9963a", "b": "#9a6220", "c": "#f3e7c8", "d": "#c2ab7a", "r": "#b8324a", "k": K, "w": "#ffffff"}, "hover": false},
	"paper_knight": {"sprite": "knight", "palette": {"a": "#f1e6c4", "b": "#c2ab7a", "s": "#4a4780", "t": "#ffb347", "d": "#e8f0ff", "k": "#3a3670"}, "hover": false},
	"overdue_notice": {"sprite": "letter", "palette": {"a": "#f1e6c4", "b": "#c2ab7a", "r": "#c8402e", "c": "#ffffff", "y": "#e0a53a", "k": K, "w": "#ffffff"}, "hover": false},
	"the_index": {"sprite": "the_index", "palette": {"a": "#b58a4a", "b": "#7a5a2a", "c": "#d9b070", "l": "#f1e6c4", "k": "#26244e", "g": "#ffb347", "w": "#ffffff"}, "hover": false},
	"the_unread": {"sprite": "the_unread", "palette": {"a": "#3f3b7a", "b": "#2a2852", "c": "#7a76c0", "d": "#c2ab7a", "e": "#ffd24a", "k": "#12101f", "p": "#f1e6c4", "q": "#b8a070", "h": "#d9c9a0", "r": "#8a3a2a"}, "hover": true},

	# --- The Ironworks: black iron and orange -----------------------------------
	"rivet_mite": {"sprite": "mite", "palette": {"a": "#54545f", "b": "#34343e", "c": "#9a9aac", "o": "#ff8a2a"}, "hover": false},
	"slag_imp": {"sprite": "imp", "palette": {"a": "#5a4a58", "b": "#342c3a", "o": "#ff8a2a", "y": "#ffd24a", "k": K, "w": "#ffffff"}, "hover": false},
	"anvil_back": {"sprite": "anvil_turtle", "palette": {"a": "#5a5a68", "b": "#34343e", "c": "#9a9aac", "t": "#c8702a", "u": "#8a4a18", "k": K, "w": "#ffffff"}, "hover": false},
	"bellows": {"sprite": "bellows", "palette": {"a": "#8a5a36", "l": "#d07a2e", "b": "#8a4416", "n": "#5a5a68", "k": K, "w": "#ffffff"}, "hover": false},
	"molten_barbell": {"sprite": "barbell", "palette": {"a": "#4a4a58", "b": "#2e2e38", "c": "#7a7a8c", "o": "#ff8a2a", "y": "#ffe07a", "r": "#c8400f", "k": K}, "hover": false},
	"press_golem": {"sprite": "press_golem", "palette": {"a": "#5a5a68", "b": "#34343e", "c": "#8a8a9c", "o": "#ff8a2a", "y": "#ffd24a", "k": K, "s": "#b8c0cc"}, "hover": false},
	"foreman_slag": {"sprite": "foreman_slag", "palette": {"a": "#4a4654", "b": "#2c2a34", "c": "#74707f", "o": "#ff8a2a", "y": "#ffe07a", "h": "#f0b020", "i": "#b87a10", "k": K}, "hover": false},

	# --- Mirror Marsh: murky teal and violet ------------------------------------
	"leech": {"sprite": "leech", "palette": {"a": "#2f7f78", "b": "#1d524f", "c": "#8fd0c0", "r": "#b8324a", "w": "#ffffff", "v": "#7a5aa8", "k": K}, "hover": false},
	"bog_hopper": {"sprite": "frog", "palette": {"a": "#4fa888", "b": "#2a6a58", "c": "#c8ecc8", "y": "#ffe066", "k": K, "v": "#7a5aa8"}, "hover": false},
	"reed_wraith": {"sprite": "reed", "palette": {"a": "#3f8f80", "b": "#235750", "c": "#8fd0b8", "h": "#6a4a3a", "v": "#d0a0ff", "k": K}, "hover": true},
	"mud_mender": {"sprite": "mudblob", "palette": {"a": "#5a6a60", "b": "#3a4640", "c": "#8a9a8c", "o": "#7ff0c0", "k": K, "w": "#ffffff"}, "hover": false},
	"mirror_shade": {"sprite": "mirror", "palette": {"f": "#8fb8b0", "g": "#4f7a74", "m": "#b9a8e0", "n": "#e6dcfa", "s": "#3a2a5a", "e": "#7ff0e0"}, "hover": false},
	"knotroot": {"sprite": "knotroot", "palette": {"a": "#6a5868", "b": "#3e3040", "c": "#94809a", "m": "#3fa89a", "e": "#d0a0ff", "k": K}, "hover": false},
	"the_knot": {"sprite": "the_knot", "palette": {"a": "#2f7f78", "b": "#1d524f", "c": "#6fc8b8", "v": "#7a5aa8", "u": "#4a3470", "p": "#a98ad0", "e": "#e8ff7a", "k": K}, "hover": false},

	# --- Stormspine Ridge: slate, ice and electric yellow -----------------------
	"static_mote": {"sprite": "spark", "palette": {"y": "#ffe838", "w": "#ffffff", "k": K}, "hover": true},
	"gale_hawk": {"sprite": "hawk", "palette": {"a": "#7a8aa2", "b": "#4a566e", "c": "#d0e2f4", "y": "#ffd040", "k": K}, "hover": true},
	"rime_goat": {"sprite": "goat", "palette": {"a": "#d0dceb", "b": "#8a9ab3", "h": "#5d6b80", "i": "#f2fbff", "k": K, "d": "#3a4558"}, "hover": false},
	"thunder_drum": {"sprite": "drum", "palette": {"a": "#5d6b80", "b": "#3a4558", "s": "#ece4cc", "y": "#ffe838", "d": "#b08a5a", "k": K, "w": "#ffffff"}, "hover": false},
	"storm_eye": {"sprite": "eye", "palette": {"c": "#6a7890", "d": "#3a4558", "l": "#a8b8cc", "w": "#eef8ff", "i": "#ffe838", "k": K}, "hover": true},
	"cairn_giant": {"sprite": "cairn_giant", "palette": {"a": "#93a2ba", "b": "#5d6b84", "c": "#c2d0e2", "s": "#f4fbff", "e": "#ffe838", "k": "#2a3140"}, "hover": false},
	"thunderhead": {"sprite": "thunderhead", "palette": {"c": "#6a7890", "d": "#3a4558", "l": "#a8b8cc", "w": "#eef8ff", "y": "#ffe838", "i": "#8fd0ff", "k": K}, "hover": true},

	# --- Titan's Rest: old gold and deep stone ----------------------------------
	"stone_acolyte": {"sprite": "acolyte", "palette": {"a": "#6d6688", "b": "#4a4460", "c": "#9a94b8", "g": "#c9a23a", "o": "#f0d070", "k": "#1f1b30", "e": "#f0d070"}, "hover": false},
	"echo_knight": {"sprite": "knight", "palette": {"a": "#8fd8e8", "b": "#4a90a8", "s": "#4a4460", "t": "#c9a23a", "d": "#e8fbff", "k": "#1f1b30"}, "hover": false},
	"relic_guard": {"sprite": "guard", "palette": {"a": "#5a5478", "b": "#3a3550", "c": "#8a84a8", "g": "#c9a23a", "e": "#7fe0ff", "d": "#d0d8e8"}, "hover": false},
	"void_moth": {"sprite": "moth", "palette": {"a": "#4a3a70", "b": "#2d2448", "c": "#8a70c0", "g": "#f0d070", "f": "#d0c8e8", "k": K}, "hover": true},
	"titan_shard": {"sprite": "shard", "palette": {"a": "#7a72a0", "b": "#4a4460", "c": "#b0aad0", "g": "#f0d070", "o": "#c9a23a", "k": K}, "hover": true},
	"the_gatekeeper": {"sprite": "the_gatekeeper", "palette": {"a": "#5a5478", "b": "#3a3550", "c": "#8a84a8", "g": "#c9a23a", "h": "#f0d070", "e": "#7fe0ff", "k": K, "i": "#9a9ab0"}, "hover": false},
	"the_hollow_titan": {"sprite": "the_hollow_titan", "palette": {"a": "#6d6688", "b": "#4a4460", "c": "#9a94b8", "g": "#c9a23a", "h": "#f0d070", "e": "#7fe0ff", "k": "#120f1e"}, "hover": false},
}

## What an id nobody drew looks like.
const DEFAULT_LOOK = {"sprite": "blob", "palette": {"a": "#8a84a8", "b": "#5a5478", "c": "#b8b2d0", "k": K, "w": "#ffffff"}, "hover": false}

static var _frames = {} # shape id -> [rows of frame 0, rows of frame 1]
static var _tex = {} # "id|frame|silhouette|dim" -> ImageTexture


## True for a foe with a look of its own (the weekly rival's monsters too).
static func has(foe_id: String) -> bool:
	if LOOKS.has(foe_id) or EXTRA_LOOKS.has(foe_id):
		return true
	return is_rival(foe_id) and BossSprites.boss_looks().has(foe_id)


## True for an id drawn by the main game (the weekly rival: a bounty monster).
static func is_rival(foe_id: String) -> bool:
	return foe_id.begins_with("wk_")


## Looks of foes that are not in the catalog (RpgFoes): the Ore Mole a battle brings along.
const EXTRA_LOOKS = {
	"ore_mole": {"sprite": "rat", "palette": {"a": "#e8b93a", "b": "#a8741c", "c": "#fff0a8", "p": "#f2c9a0", "k": K, "w": "#ffffff"}, "hover": false},
}

## The look of a foe: {sprite, palette, hover}. An unknown id gets the plain blob.
static func look(foe_id: String) -> Dictionary:
	if EXTRA_LOOKS.has(foe_id):
		return EXTRA_LOOKS[foe_id]
	return LOOKS.get(foe_id, DEFAULT_LOOK)


static func _mirror(text: String) -> String:
	var out = ""
	for i in range(text.length() - 1, -1, -1):
		out += text[i]
	return out


## `rows` with every [row, column, text] of `marks` written over it ("." erases).
static func _written(rows: Array, marks: Array) -> Array:
	var out = rows.duplicate()
	for m in marks:
		var r = int(m[0])
		var at = int(m[1])
		var text = str(m[2])
		if r < 0 or r >= out.size():
			continue
		var row = str(out[r])
		if at < 0 or at + text.length() > row.length():
			continue
		out[r] = row.substr(0, at) + text + row.substr(at + text.length())
	return out


## Both frames of a shape, as rows of one width: [frame 0, frame 1].
static func frames(shape_id: String) -> Array:
	var hit = _frames.get(shape_id)
	if hit != null:
		return hit
	var shape = SHAPES.get(shape_id, SHAPES["blob"])
	var halved = shape.has("half")
	var base = []
	if halved:
		for r in shape.half:
			base.append(str(r) + _mirror(str(r)))
	else:
		for r in shape.rows:
			base.append(str(r))
	var w = 0
	for r in base:
		w = maxi(w, str(r).length())
	for i in range(base.size()):
		base[i] = str(base[i]).rpad(w, ".")
	base = _written(base, shape.get("over", []))
	var two = []
	if shape.has("two"):
		for r in shape.two:
			two.append(str(r).rpad(w, "."))
		# A second pose is never shorter or taller than the first.
		while two.size() < base.size():
			two.push_front(".".repeat(w))
		two = two.slice(0, base.size())
	else:
		two = base.duplicate()
		var alt = shape.get("alt", {})
		for key in alt:
			var at = int(key)
			if at < 0 or at >= two.size():
				continue
			var row = str(alt[key])
			if halved and row.length() * 2 == w:
				row = row + _mirror(row)
			two[at] = row.rpad(w, ".").substr(0, w)
		two = _written(two, shape.get("alt_over", []))
		var pulse = str(shape.get("pulse", ""))
		if pulse.length() == 2:
			for i in range(two.size()):
				var swapped = ""
				for ch in str(two[i]):
					swapped += pulse[1] if ch == pulse[0] else (pulse[0] if ch == pulse[1] else ch)
				two[i] = swapped
		var cut = shape.get("cut", []).duplicate()
		cut.sort()
		cut.reverse()
		for at in cut:
			if int(at) >= 0 and int(at) < two.size():
				two.remove_at(int(at))
				two.push_front(".".repeat(w))
	hit = [base, two]
	_frames[shape_id] = hit
	return hit


## The char rows of one frame of a foe (not for a rival: the main game draws those).
static func rows(foe_id: String, frame: int = 0) -> Array:
	return frames(str(look(foe_id).sprite))[absi(frame) % 2]


## The size of buffer() / texture(): the sprite and a pixel of outline all round.
static func size(foe_id: String) -> Vector2i:
	if is_rival(foe_id):
		return Art.boss_size(foe_id)
	var first = rows(foe_id, 0)
	return Vector2i(str(first[0]).length() + 2, first.size() + 2)


## True for a foe that floats above the ground.
static func hovers(foe_id: String) -> bool:
	if is_rival(foe_id):
		return Art.boss_hovers(foe_id)
	return bool(look(foe_id).get("hover", false))


## One frame without its outline, in the buffer buffer() uses (so the outer
## pixel all round is empty). `silhouette`: every pixel one dark colour.
static func plain(foe_id: String, frame: int = 0, silhouette: bool = false) -> Pix:
	var lk = look(foe_id)
	var sz = size(foe_id)
	var buf = Pix.new(sz.x, sz.y)
	var palette = lk.palette
	if silhouette:
		palette = {}
		for key in lk.palette:
			palette[key] = SILHOUETTE
	buf.sprite(1, 1, rows(foe_id, frame), palette)
	return buf


## One frame of a foe in a tight, outlined buffer. `silhouette` draws a foe
## that has not been met as a dark shape.
static func buffer(foe_id: String, frame: int = 0, silhouette: bool = false) -> Pix:
	if is_rival(foe_id):
		return Art.boss_pix(foe_id, silhouette)
	var buf = plain(foe_id, frame, silhouette)
	if silhouette:
		buf.outline(SILHOUETTE_EDGE)
		return buf
	buf.bevel()
	buf.outline_tinted(Pix.OUTLINE)
	return buf


## The texture of one frame (cached). `dim` greys it out (a foe that is down).
static func texture(foe_id: String, frame: int = 0, silhouette: bool = false, dim: bool = false) -> ImageTexture:
	if is_rival(foe_id):
		return Art.boss_texture(foe_id, silhouette, dim)
	var key = "%s|%d|%s|%s" % [foe_id, absi(frame) % 2, str(silhouette), str(dim)]
	var tex = _tex.get(key)
	if tex == null:
		var p = buffer(foe_id, frame, silhouette)
		if dim:
			p = p.dimmed(DIM_BRIGHTNESS)
		tex = p.to_texture()
		if _tex.size() >= _TEX_CACHE_MAX:
			_tex.clear()
		_tex[key] = tex
	return tex


## Forget every cached texture and frame (tests).
static func clear_cache() -> void:
	_tex.clear()
	_frames.clear()
