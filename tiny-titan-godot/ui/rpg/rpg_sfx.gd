class_name RpgSfx
extends RefCounted
## The Realm's own sounds (the user, 2026-11-26: "feels like stuff is missing...
## combinations of animations, sounds and visual effects"). Every attack school
## has its own hit, and so has every thing that happens in a fight (a guard
## that breaks, a heal, a status, a foe going down), a result (stars, loot,
## experience) and the pages (a node learned, a piece upgraded, a chest).
##
##   RpgSfx.play("heal")            # one of SOUNDS
##   RpgSfx.hit("legs", true)       # a school's hit, a crit on top
##
## They are rendered by the game's synthesizer (app/sfx.gd, `play_notes`), so
## Settings' sound switch silences them with everything else. A note is
## [hz, start, seconds, wave, gain, opts] as there. The rule the user set for
## the clicks holds here too ("The sound is really jarring, make it more
## satisfying/clicky/bubbly"): sine and triangle for anything with a pitch,
## low-passed noise for a thud or a whoosh, no bare square or sawtooth, and
## nothing loud. tests/rpg_sfx_test.gd measures all of them.
##
## The autoload is reached through the tree, never by its name, so this file
## compiles in a headless --script test.
##
## A PHONE'S SPEAKER plays next to nothing under about 250 Hz, and the phone is
## where this is played. So a thud is never only a low sine: every hit, block,
## break and drum also has a knock in the middle (a sine falling through 300 to
## 700 Hz), which is what is heard there; the low part is for headphones.

## How far a sound's pitch strays each time it is played (a hit never sounds
## twice the same).
const DRIFT = 0.045

const SOUNDS = {
	# ---- the hero's attacks, by school -------------------------------------
	# The swing before a hit lands.
	"swing": [[0, 0.0, 0.13, "noise", 0.08, {"lp": 650, "attack": 0.05}], [320, 0.0, 0.12, "sine", 0.012, {"to": 760, "glide": 0.1, "attack": 0.03}]],
	# Push: a short heavy thud.
	"hit_push": [[150, 0.0, 0.16, "sine", 0.07, {"to": 58, "glide": 0.09, "attack": 0.002}], [0, 0.0, 0.06, "noise", 0.07, {"lp": 900, "attack": 0.001}], [300, 0.0, 0.05, "triangle", 0.03, {"to": 150, "glide": 0.04, "attack": 0.002}], [460, 0.0, 0.1, "sine", 0.09, {"to": 200, "glide": 0.07, "attack": 0.002}]],
	# Pull: a slash, bright air falling.
	"hit_pull": [[0, 0.0, 0.1, "noise", 0.065, {"lp": 2600, "attack": 0.004}], [980, 0.0, 0.11, "sine", 0.035, {"to": 300, "glide": 0.09, "attack": 0.003}], [140, 0.02, 0.1, "sine", 0.05, {"to": 80, "glide": 0.08}], [560, 0.01, 0.08, "sine", 0.05, {"to": 260, "glide": 0.06, "attack": 0.002}]],
	# Legs: a stomp, lower and longer, the ground answering.
	"hit_legs": [[112, 0.0, 0.26, "sine", 0.075, {"to": 40, "glide": 0.17, "attack": 0.002}], [0, 0.0, 0.14, "noise", 0.08, {"lp": 600, "attack": 0.002}], [62, 0.06, 0.24, "sine", 0.025, {"attack": 0.03}], [400, 0.0, 0.14, "sine", 0.095, {"to": 170, "glide": 0.1, "attack": 0.002}], [320, 0.07, 0.12, "triangle", 0.04, {"to": 210, "glide": 0.1}]],
	# Speed: two quick zips.
	"hit_speed": [[1250, 0.0, 0.05, "sine", 0.034, {"to": 2100, "glide": 0.04, "attack": 0.002}], [1500, 0.055, 0.06, "sine", 0.034, {"to": 2400, "glide": 0.045, "attack": 0.002}], [0, 0.0, 0.09, "noise", 0.03, {"lp": 2600, "attack": 0.01}], [170, 0.05, 0.08, "sine", 0.05, {"to": 90, "glide": 0.06}], [520, 0.05, 0.07, "sine", 0.05, {"to": 260, "glide": 0.05, "attack": 0.002}]],
	# Grip: a crunch, two bites.
	"hit_grip": [[0, 0.0, 0.045, "noise", 0.075, {"lp": 1300, "attack": 0.001}], [0, 0.06, 0.07, "noise", 0.075, {"lp": 850, "attack": 0.001}], [230, 0.0, 0.13, "triangle", 0.05, {"to": 120, "glide": 0.11, "attack": 0.002}], [480, 0.0, 0.05, "sine", 0.05, {"to": 300, "glide": 0.04, "attack": 0.002}], [420, 0.06, 0.07, "sine", 0.05, {"to": 230, "glide": 0.05, "attack": 0.002}]],
	# Mind: a bell.
	"hit_mind": [[1047, 0.0, 0.3, "sine", 0.045, {"attack": 0.003}], [1568, 0.03, 0.32, "sine", 0.03, {"attack": 0.003}], [2093, 0.06, 0.26, "sine", 0.014, {"attack": 0.003}], [523, 0.0, 0.14, "sine", 0.035, {"attack": 0.004}]],
	# A plain strike.
	"hit_plain": [[250, 0.0, 0.09, "sine", 0.085, {"to": 120, "glide": 0.06, "attack": 0.002}], [0, 0.0, 0.045, "noise", 0.045, {"lp": 1300, "attack": 0.001}], [520, 0.0, 0.07, "sine", 0.06, {"to": 230, "glide": 0.05, "attack": 0.002}]],
	# On top of a hit.
	"crit": [[1319, 0.0, 0.14, "sine", 0.04, {"attack": 0.002}], [1976, 0.05, 0.3, "sine", 0.04, {"attack": 0.002}], [2637, 0.1, 0.22, "sine", 0.012, {"attack": 0.002}]],
	"weak": [[880, 0.0, 0.08, "triangle", 0.04, {"attack": 0.003}], [1175, 0.07, 0.2, "triangle", 0.045, {"attack": 0.003}]],
	"resist": [[392, 0.0, 0.11, "triangle", 0.05, {"attack": 0.003}], [294, 0.045, 0.16, "triangle", 0.045, {"attack": 0.003}]],
	"miss": [[0, 0.0, 0.18, "noise", 0.05, {"lp": 1000, "attack": 0.07}], [620, 0.0, 0.16, "sine", 0.012, {"to": 300, "glide": 0.14, "attack": 0.03}]],
	# The shield took it all.
	"absorb": [[740, 0.0, 0.2, "sine", 0.035, {"attack": 0.002}], [1110, 0.0, 0.22, "sine", 0.02, {"attack": 0.002}], [0, 0.0, 0.03, "noise", 0.03, {"lp": 1500, "attack": 0.001}]],

	# ---- what happens to a fighter ------------------------------------------
	"heal": [[523, 0.0, 0.16, "sine", 0.04], [659, 0.07, 0.16, "sine", 0.04], [784, 0.14, 0.16, "sine", 0.04], [1047, 0.21, 0.34, "sine", 0.045], [1568, 0.24, 0.3, "sine", 0.012]],
	"buff": [[440, 0.0, 0.14, "triangle", 0.04, {"to": 660, "glide": 0.11}], [880, 0.09, 0.24, "sine", 0.03, {"to": 1320, "glide": 0.12}]],
	"debuff": [[520, 0.0, 0.2, "triangle", 0.04, {"to": 300, "glide": 0.16}], [300, 0.1, 0.24, "sine", 0.03, {"to": 180, "glide": 0.18}]],
	"shield": [[660, 0.0, 0.32, "sine", 0.035, {"attack": 0.02}], [990, 0.0, 0.32, "sine", 0.02, {"attack": 0.02}], [1320, 0.05, 0.28, "sine", 0.014, {"attack": 0.02}]],
	"guard": [[210, 0.0, 0.12, "triangle", 0.06, {"to": 150, "glide": 0.09, "attack": 0.003}], [0, 0.0, 0.05, "noise", 0.04, {"lp": 700, "attack": 0.002}], [520, 0.0, 0.07, "sine", 0.02, {"attack": 0.003}], [430, 0.0, 0.1, "sine", 0.045, {"to": 300, "glide": 0.08, "attack": 0.003}]],
	# A hit that lands on a raised guard.
	"perfect": [[320, 0.0, 0.07, "triangle", 0.06, {"attack": 0.002}], [0, 0.0, 0.035, "noise", 0.04, {"lp": 1500, "attack": 0.001}], [660, 0.03, 0.12, "sine", 0.05, {"attack": 0.003}], [990, 0.08, 0.16, "sine", 0.045, {"attack": 0.003}], [1320, 0.13, 0.24, "sine", 0.035, {"attack": 0.004}]],
	"block": [[300, 0.0, 0.07, "triangle", 0.06, {"attack": 0.002}], [1200, 0.0, 0.07, "sine", 0.022, {"attack": 0.002}], [0, 0.0, 0.035, "noise", 0.045, {"lp": 1500, "attack": 0.001}], [620, 0.0, 0.06, "sine", 0.04, {"to": 400, "glide": 0.05, "attack": 0.002}]],
	# A guard pip knocked off.
	"chip": [[1480, 0.0, 0.06, "sine", 0.026, {"to": 1100, "glide": 0.05, "attack": 0.002}], [0, 0.0, 0.025, "noise", 0.02, {"lp": 2400, "attack": 0.001}]],
	# The guard breaks: glass falling, a low drop under it.
	"break": [[0, 0.0, 0.2, "noise", 0.06, {"lp": 3200, "attack": 0.002}], [1760, 0.0, 0.14, "sine", 0.035, {"attack": 0.002}], [1397, 0.045, 0.14, "sine", 0.035, {"attack": 0.002}], [1047, 0.09, 0.14, "sine", 0.035, {"attack": 0.002}], [784, 0.135, 0.2, "sine", 0.035, {"attack": 0.002}], [125, 0.0, 0.24, "sine", 0.08, {"to": 50, "glide": 0.18, "attack": 0.002}], [420, 0.0, 0.16, "sine", 0.06, {"to": 160, "glide": 0.12, "attack": 0.002}]],
	"recover": [[392, 0.0, 0.1, "triangle", 0.03, {"to": 523, "glide": 0.08}]],
	# A foe goes down: a fall and a puff.
	"ko": [[520, 0.0, 0.34, "sine", 0.06, {"to": 80, "glide": 0.26, "attack": 0.004}], [0, 0.13, 0.24, "noise", 0.045, {"lp": 900, "attack": 0.04}], [0, 0.0, 0.03, "noise", 0.03, {"lp": 1500, "attack": 0.001}]],
	# The hero is hit.
	"hurt": [[135, 0.0, 0.18, "sine", 0.07, {"to": 55, "glide": 0.12, "attack": 0.002}], [0, 0.0, 0.08, "noise", 0.07, {"lp": 800, "attack": 0.001}], [92, 0.02, 0.12, "triangle", 0.025], [430, 0.0, 0.11, "sine", 0.09, {"to": 190, "glide": 0.08, "attack": 0.002}]],
	"hurt_big": [[120, 0.0, 0.3, "sine", 0.13, {"to": 40, "glide": 0.2, "attack": 0.002}], [0, 0.0, 0.16, "noise", 0.09, {"lp": 800, "attack": 0.001}], [84, 0.03, 0.22, "triangle", 0.05], [330, 0.0, 0.12, "sine", 0.03, {"to": 165, "glide": 0.1}], [440, 0.0, 0.16, "sine", 0.085, {"to": 150, "glide": 0.11, "attack": 0.002}], [300, 0.04, 0.14, "triangle", 0.04, {"to": 180, "glide": 0.12}]],
	# The hero goes down.
	"down": [[392, 0.0, 0.26, "triangle", 0.05], [311, 0.2, 0.26, "triangle", 0.05], [233, 0.4, 0.5, "triangle", 0.05], [58, 0.42, 0.5, "sine", 0.025, {"attack": 0.03}], [784, 0.0, 0.2, "sine", 0.012], [622, 0.2, 0.2, "sine", 0.012], [466, 0.4, 0.45, "sine", 0.03]],
	"survive": [[330, 0.0, 0.1, "triangle", 0.05], [494, 0.09, 0.1, "triangle", 0.05], [659, 0.18, 0.3, "triangle", 0.055], [1319, 0.2, 0.3, "sine", 0.015]],
	"burn": [[0, 0.0, 0.1, "noise", 0.04, {"lp": 2600, "attack": 0.02}], [420, 0.0, 0.1, "sine", 0.03, {"to": 620, "glide": 0.08}]],
	"bleed": [[330, 0.0, 0.1, "sine", 0.04, {"to": 190, "glide": 0.08, "attack": 0.003}], [0, 0.0, 0.03, "noise", 0.02, {"lp": 1100, "attack": 0.001}]],
	"stun": [[988, 0.0, 0.08, "sine", 0.03], [784, 0.07, 0.08, "sine", 0.03], [988, 0.14, 0.08, "sine", 0.03], [784, 0.21, 0.16, "sine", 0.03]],
	"interrupt": [[700, 0.0, 0.07, "triangle", 0.045, {"to": 350, "glide": 0.06, "attack": 0.002}], [0, 0.0, 0.04, "noise", 0.04, {"lp": 1600, "attack": 0.001}]],

	# ---- the foes ---------------------------------------------------------
	"foe_act": [[340, 0.0, 0.11, "triangle", 0.04, {"to": 470, "glide": 0.09}]],
	"foe_cast": [[294, 0.0, 0.2, "sine", 0.035, {"to": 392, "glide": 0.16, "attack": 0.03}], [588, 0.04, 0.2, "sine", 0.016, {"to": 784, "glide": 0.16, "attack": 0.03}]],
	"charge": [[220, 0.0, 0.55, "sine", 0.045, {"to": 660, "glide": 0.5, "attack": 0.3}], [440, 0.0, 0.55, "triangle", 0.02, {"to": 1320, "glide": 0.5, "attack": 0.32}]],
	"count": [[660, 0.0, 0.07, "sine", 0.035], [660, 0.16, 0.07, "sine", 0.035]],
	"summon": [[294, 0.0, 0.28, "triangle", 0.05, {"to": 440, "glide": 0.24, "attack": 0.1}], [0, 0.0, 0.24, "noise", 0.03, {"lp": 900, "attack": 0.08}]],
	"phase": [[110, 0.0, 0.7, "sine", 0.03, {"attack": 0.03}], [104, 0.0, 0.7, "sine", 0.025, {"attack": 0.03}], [440, 0.0, 0.55, "triangle", 0.045, {"to": 220, "glide": 0.45}], [0, 0.0, 0.45, "noise", 0.04, {"lp": 700, "attack": 0.02}], [330, 0.0, 0.7, "sine", 0.06, {"attack": 0.03}], [311, 0.0, 0.7, "sine", 0.055, {"attack": 0.03}]],
	"adapt": [[523, 0.0, 0.09, "triangle", 0.035], [415, 0.08, 0.09, "triangle", 0.035], [311, 0.16, 0.2, "triangle", 0.04]],

	# ---- the flow of a fight -------------------------------------------------
	"turn": [[660, 0.0, 0.07, "sine", 0.022], [880, 0.055, 0.12, "sine", 0.024]],
	"energy": [[990, 0.0, 0.06, "sine", 0.016, {"to": 1320, "glide": 0.05}]],
	"gauge_full": [[784, 0.0, 0.12, "sine", 0.035], [1047, 0.08, 0.12, "sine", 0.035], [1319, 0.16, 0.12, "sine", 0.035], [1568, 0.24, 0.34, "sine", 0.04], [392, 0.0, 0.3, "triangle", 0.03]],
	"item": [[300, 0.0, 0.07, "sine", 0.04, {"to": 480, "glide": 0.06}], [360, 0.09, 0.07, "sine", 0.04, {"to": 560, "glide": 0.06}], [880, 0.18, 0.2, "sine", 0.03]],
	"pet": [[1400, 0.0, 0.06, "sine", 0.03, {"to": 1900, "glide": 0.05}], [1600, 0.08, 0.08, "sine", 0.03, {"to": 2200, "glide": 0.06}]],
	"learn_weak": [[784, 0.0, 0.08, "sine", 0.035], [1047, 0.07, 0.08, "sine", 0.035], [1568, 0.14, 0.26, "sine", 0.035]],
	"ult_start": [[196, 0.0, 0.5, "sine", 0.05, {"to": 1568, "glide": 0.46, "attack": 0.22}], [0, 0.0, 0.5, "noise", 0.03, {"lp": 2400, "attack": 0.34}], [98, 0.0, 0.5, "triangle", 0.035, {"attack": 0.1}]],
	"ult_hit": [[92, 0.0, 0.55, "sine", 0.13, {"to": 34, "glide": 0.4, "attack": 0.002}], [0, 0.0, 0.32, "noise", 0.085, {"lp": 1400, "attack": 0.002}], [523, 0.0, 0.5, "sine", 0.028], [784, 0.0, 0.5, "sine", 0.028], [1047, 0.0, 0.5, "sine", 0.026], [1568, 0.02, 0.5, "sine", 0.014], [480, 0.0, 0.3, "sine", 0.085, {"to": 130, "glide": 0.2, "attack": 0.002}], [330, 0.05, 0.3, "triangle", 0.04, {"to": 165, "glide": 0.24}]],
	"wave": [[392, 0.0, 0.11, "triangle", 0.04], [523, 0.1, 0.11, "triangle", 0.04], [659, 0.2, 0.24, "triangle", 0.045]],
	# The fight opens: a drum and a rising call.
	"enter": [[82, 0.0, 0.22, "sine", 0.06, {"to": 48, "glide": 0.16, "attack": 0.002}], [0, 0.0, 0.3, "noise", 0.04, {"lp": 800, "attack": 0.12}], [196, 0.06, 0.13, "triangle", 0.045], [262, 0.17, 0.13, "triangle", 0.045], [392, 0.28, 0.3, "triangle", 0.055], [784, 0.3, 0.3, "sine", 0.014], [380, 0.0, 0.13, "sine", 0.085, {"to": 180, "glide": 0.09, "attack": 0.002}]],
	# A boss steps out: two low drums and a dark hum that beats.
	"boss": [[73, 0.0, 1.0, "sine", 0.035, {"attack": 0.02}], [77.8, 0.0, 1.0, "sine", 0.025, {"attack": 0.02}], [440, 0.25, 0.75, "triangle", 0.04, {"to": 415, "glide": 0.6, "attack": 0.05}], [0, 0.0, 0.3, "noise", 0.05, {"lp": 500, "attack": 0.002}], [0, 0.5, 0.34, "noise", 0.06, {"lp": 500, "attack": 0.002}], [60, 0.5, 0.3, "sine", 0.05, {"to": 38, "glide": 0.2, "attack": 0.002}], [294, 0.0, 0.9, "sine", 0.07, {"attack": 0.03}], [311, 0.0, 0.9, "sine", 0.06, {"attack": 0.03}], [340, 0.0, 0.14, "sine", 0.08, {"to": 160, "glide": 0.1, "attack": 0.002}], [320, 0.5, 0.16, "sine", 0.09, {"to": 150, "glide": 0.11, "attack": 0.002}]],
	"flee": [[700, 0.0, 0.07, "sine", 0.035, {"to": 520, "glide": 0.06}], [560, 0.08, 0.07, "sine", 0.035, {"to": 400, "glide": 0.06}], [430, 0.16, 0.14, "sine", 0.035, {"to": 280, "glide": 0.1}]],
	"victory": [[392, 0.0, 0.13, "triangle", 0.055], [523, 0.11, 0.13, "triangle", 0.055], [659, 0.22, 0.13, "triangle", 0.055], [784, 0.33, 0.2, "triangle", 0.06], [659, 0.56, 0.12, "triangle", 0.05], [1047, 0.68, 0.6, "triangle", 0.065], [131, 0.0, 0.5, "sine", 0.05, {"attack": 0.01}], [196, 0.33, 0.4, "sine", 0.04, {"attack": 0.01}], [262, 0.68, 0.6, "sine", 0.05, {"attack": 0.01}], [1568, 0.7, 0.55, "sine", 0.018], [2093, 0.72, 0.5, "sine", 0.01]],
	"defeat": [[392, 0.0, 0.3, "triangle", 0.05], [349, 0.26, 0.3, "triangle", 0.05], [311, 0.52, 0.3, "triangle", 0.05], [262, 0.78, 0.7, "triangle", 0.055], [65, 0.78, 0.7, "sine", 0.06, {"attack": 0.04}], [262, 0.78, 0.6, "sine", 0.03]],

	# ---- the result ---------------------------------------------------------
	"star": [[1047, 0.0, 0.24, "sine", 0.045, {"attack": 0.002}], [1568, 0.02, 0.24, "sine", 0.02, {"attack": 0.002}], [0, 0.0, 0.03, "noise", 0.03, {"lp": 2000, "attack": 0.001}], [262, 0.0, 0.08, "sine", 0.04, {"to": 160, "glide": 0.06}], [523, 0.0, 0.07, "sine", 0.04, {"to": 330, "glide": 0.05, "attack": 0.002}]],
	"star_miss": [[440, 0.0, 0.1, "triangle", 0.025, {"to": 360, "glide": 0.08}]],
	"ore": [[1319, 0.0, 0.07, "sine", 0.03], [1760, 0.05, 0.16, "sine", 0.03]],
	"count_up": [[880, 0.0, 0.035, "sine", 0.012]],
	"loot": [[523, 0.0, 0.1, "sine", 0.04, {"to": 660, "glide": 0.07}], [784, 0.08, 0.2, "sine", 0.035]],
	"loot_rare": [[523, 0.0, 0.1, "sine", 0.04], [784, 0.08, 0.1, "sine", 0.04], [1047, 0.16, 0.12, "sine", 0.04], [1568, 0.26, 0.4, "sine", 0.035], [262, 0.0, 0.4, "triangle", 0.03]],
	"first_clear": [[523, 0.0, 0.1, "triangle", 0.05], [659, 0.09, 0.1, "triangle", 0.05], [784, 0.18, 0.1, "triangle", 0.05], [1047, 0.27, 0.36, "triangle", 0.055], [1319, 0.3, 0.36, "sine", 0.02]],

	# ---- the pages ---------------------------------------------------------
	"chest": [[0, 0.0, 0.26, "noise", 0.035, {"lp": 520, "attack": 0.1}], [220, 0.0, 0.24, "triangle", 0.03, {"to": 330, "glide": 0.2, "attack": 0.05}], [784, 0.26, 0.1, "sine", 0.035], [1047, 0.32, 0.1, "sine", 0.035], [1319, 0.38, 0.1, "sine", 0.035], [1568, 0.44, 0.34, "sine", 0.04], [330, 0.0, 0.05, "sine", 0.04, {"to": 220, "glide": 0.04, "attack": 0.002}]],
	"learn": [[523, 0.0, 0.22, "sine", 0.04, {"to": 1047, "glide": 0.16}], [784, 0.15, 0.28, "triangle", 0.04], [1568, 0.2, 0.32, "sine", 0.02]],
	"upgrade": [[660, 0.0, 0.06, "triangle", 0.05, {"attack": 0.002}], [0, 0.0, 0.035, "noise", 0.04, {"lp": 2800, "attack": 0.001}], [740, 0.13, 0.06, "triangle", 0.05, {"attack": 0.002}], [0, 0.13, 0.035, "noise", 0.04, {"lp": 2800, "attack": 0.001}], [1320, 0.26, 0.34, "sine", 0.035], [1980, 0.28, 0.3, "sine", 0.012]],
	"equip": [[0, 0.0, 0.05, "noise", 0.04, {"lp": 1400, "attack": 0.002}], [500, 0.0, 0.09, "sine", 0.03, {"to": 720, "glide": 0.07}]],
	"unequip": [[0, 0.0, 0.05, "noise", 0.035, {"lp": 1100, "attack": 0.002}], [640, 0.0, 0.09, "sine", 0.026, {"to": 430, "glide": 0.07}]],
	"socket": [[1175, 0.0, 0.05, "sine", 0.035], [1760, 0.05, 0.22, "sine", 0.035], [0, 0.0, 0.025, "noise", 0.025, {"lp": 2200, "attack": 0.001}]],
	"select": [[500, 0.0, 0.07, "sine", 0.03, {"to": 640, "glide": 0.05}]],
	"buy": [[1319, 0.0, 0.06, "sine", 0.03], [1047, 0.05, 0.06, "sine", 0.03], [1568, 0.1, 0.2, "sine", 0.035]],
	"unlock": [[392, 0.0, 0.14, "triangle", 0.05], [494, 0.12, 0.14, "triangle", 0.05], [587, 0.24, 0.14, "triangle", 0.05], [784, 0.36, 0.5, "triangle", 0.06], [1175, 0.38, 0.5, "sine", 0.02], [98, 0.36, 0.5, "sine", 0.05, {"attack": 0.02}]],
	"level": [[523, 0.0, 0.12, "triangle", 0.055], [659, 0.1, 0.12, "triangle", 0.055], [784, 0.2, 0.12, "triangle", 0.055], [1047, 0.3, 0.16, "triangle", 0.06], [1319, 0.44, 0.5, "triangle", 0.06], [2637, 0.46, 0.4, "sine", 0.012], [131, 0.3, 0.6, "sine", 0.05, {"attack": 0.02}]],
	"stat": [[660, 0.0, 0.05, "sine", 0.02, {"to": 880, "glide": 0.04}]],
}

## The hit of a school ("plain" for a strike with none).
const HITS = {"push": "hit_push", "pull": "hit_pull", "legs": "hit_legs", "speed": "hit_speed", "grip": "hit_grip", "mind": "hit_mind", "plain": "hit_plain"}

## The music's level (RealmMusic.volume): under the sound effects.
const MUSIC_VOLUME = 1.0
## In a browser every tune played stays in its memory (about 9 MB each, and the engine cannot hand it back),
## so a visit to the page plays at most this many different ones; after that the nearest one already there.
const WEB_TUNES = 5
## Where a fight is, as one of the music's eight regions.
const TUNE_OF_SCENE = {"hunt": 1, "rival": 5, "spire": 7}

static var _sfx = null
static var _music = null
## How many screens want the Realm's music (its tab, a battle); with none it stops.
static var _holders: int = 0
static var battles: int = 0
static var _tunes: Array = []


static func has(name: String) -> bool:
	return SOUNDS.has(name)


static func notes(name: String) -> Array:
	return SOUNDS.get(name, [])


static func _node():
	if _sfx != null and is_instance_valid(_sfx):
		return _sfx
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		_sfx = loop.root.get_node_or_null("Sfx")
	return _sfx


## Play one of SOUNDS, at `pitch` times its own, straying by `drift` each way.
static func play(name: String, pitch: float = 1.0, drift: float = 0.0) -> void:
	if not SOUNDS.has(name):
		return
	var s = _node()
	if s == null:
		return
	var p = pitch
	if drift > 0.0:
		p *= randf_range(1.0 - drift, 1.0 + drift)
	s.play_notes("rpg:" + name, SOUNDS[name], p)


## A hit of that school lands on a foe.
## `step`: which hit of one action this is (0 the first): each one rings a little higher, so a move that
## hits three times is heard climbing.
static func hit(school: String, crit: bool = false, weak: bool = false, resist: bool = false, step: int = 0) -> void:
	play(str(HITS.get(school, "hit_plain")), (0.86 if resist else 1.0) * (1.0 + 0.07 * float(clampi(step, 0, 6))), DRIFT)
	if crit:
		play("crit")
	elif weak:
		play("weak")
	elif resist:
		play("resist")


## The n-th star of a result (0, 1, 2): each a step higher.
static func star(n: int) -> void:
	play("star", [1.0, 1.122, 1.26][clampi(n, 0, 2)])


# =============================================================================
# Music (app/realm_music.gd). It plays while the Realm's tab or a battle is on
# screen, follows Settings' sound switch and has a switch of its own
# (settings.realmMusic, on unless turned off; the key is on the Realm's banner).
# =============================================================================

static func _app():
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		return loop.root.get_node_or_null("App")
	return null


## The music's node (made the first time it is asked for), or null where the game is not running.
static func music():
	if _music != null and is_instance_valid(_music):
		return _music
	var s = _node()
	if s == null:
		return null
	_music = RealmMusic.new()
	_music.name = "RealmMusic"
	_music.volume = MUSIC_VOLUME
	s.add_child(_music)
	return _music


## Is the music switched on (its own switch, and the game's sound)?
static func music_on() -> bool:
	var s = _node()
	if s == null or not bool(s.enabled):
		return false
	var app = _app()
	if app == null:
		return true
	return bool(app.saved.settings.get("realmMusic", true))


static func set_music(on: bool) -> void:
	var app = _app()
	if app != null:
		app.update_settings({"realmMusic": on})
	var m = music()
	if m != null:
		m.enabled = music_on()


static func region_of_scene(scene: String) -> int:
	var i = RpgDefs.REGIONS.find(scene)
	if i >= 0:
		return i
	return int(TUNE_OF_SCENE.get(scene, 0))


static func _pick(theme: String, region: int) -> Array:
	var th = theme
	var rg = region
	if OS.has_feature("web"):
		if th == "result" or th == "map":
			th = "hub"
		if th == "hub":
			rg = 0
		var key = [th, rg]
		if not _tunes.has(key):
			if _tunes.size() >= WEB_TUNES:
				for k in _tunes:
					if str(k[0]) == th:
						return k
				return ["hub", 0]
			_tunes.append(key)
	return [th, rg]


## Play a tune: "hub", "result", "battle" / "boss" with a region 0..7. Nothing happens where the music is off.
static func tune(theme: String, region: int = 0) -> void:
	var m = music()
	if m == null:
		return
	m.enabled = music_on()
	if not m.enabled:
		return
	var k = _pick(theme, region)
	m.play(str(k[0]), int(k[1]))


## Render a tune ahead (a stage's sheet is open: the fight is a tap away).
static func tune_ready(theme: String, region: int = 0) -> void:
	var m = music()
	if m == null or not music_on():
		return
	var k = _pick(theme, region)
	m.prepare(str(k[0]), int(k[1]))


## A screen that wants the music comes (+1) or goes (-1). When the last one has gone the music fades out.
static func hold(n: int, battle: bool = false) -> void:
	_holders = maxi(0, _holders + n)
	if battle:
		battles = maxi(0, battles + n)
		if n < 0 and _holders > 0 and battles == 0:
			tune("hub")
	if _holders > 0:
		return
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		loop.create_timer(0.35).timeout.connect(_quiet_if_alone)


static func _quiet_if_alone() -> void:
	if _holders <= 0 and _music != null and is_instance_valid(_music):
		_music.stop(0.7)


static func buzz(n: int = 1) -> void:
	var s = _node()
	if s != null:
		s.buzz(n)
