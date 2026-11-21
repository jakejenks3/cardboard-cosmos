class_name HeroBody
extends RefCounted
## Procedural pixel-art hero (port of avatar/body.ts). The silhouette is
## computed from the player's levels: lifting widens shoulders and arms,
## climbing grows forearms, cycling grows thighs, running leans the waist and
## builds calves, and the overall hero level scales everything up, so every
## level-up is visible.
##
## Data shapes (Dictionaries with the TS field names):
##   BodyInput: heroLevel, liftLevel, climbLevel, runLevel, rideLevel, skin,
##              hairStyle, hairColor, pose ("idle" | "flex"), frame, blink, happy,
##              look? (-1 | 0 | 1: the eyes glance left / ahead / right; the
##              game's look only, see Pix.classic)
##   Pt:        x, y
##   Arm:       shoulder (Pt), elbow (Pt), wrist (Pt), upperW, foreW,
##              hand {x, y, w, h}, side (-1 | 1)
##   Leg:       x (left-most column of the thigh), thighW, calfX, calfW, top,
##              kneeY, side (-1 | 1)
##   Metrics:   t {bulk, lift, climb, run, ride}, stage, cx, baseline, bob,
##              headW, headH, headTop, headLeft, eyeY, neckW, neckTop, neckH,
##              torsoTop, torsoBottom, torsoH, shoulderW, waistW,
##              torsoW (Callable: y -> width), torsoLeft (Callable: y -> x),
##              armL, armR, legL, legR, legTop, legLen, feetTop, footH,
##              footL {x, w}, footR {x, w}, pose, skin, hair
##   Visuals:   {slot: item visual Dictionary or null} (every slot optional)
##   DrawOptions: visuals, optional noOutline, optional flat (no lighting:
##                for a caller that lights the picture itself)
##
## Two looks (Pix.classic): the original port, checked pixel for pixel against
## the TypeScript renders, and the game's own, which is the same body with a
## bigger-eyed face, lit hair, shaded parts and tinted outlines.

## The original look's canvas (Pix.classic); the game's own hero is
## HeroFigure.W x HeroFigure.H. Use width() / height().
const HERO_W = 48
const HERO_H = 60


## The hero's canvas in the look being drawn.
static func width() -> int:
	return HERO_W if Pix.classic else HeroFigure.W


static func height() -> int:
	return HERO_H if Pix.classic else HeroFigure.H

const SKIN_TONES = ["#f6d7b8", "#e8b98f", "#c98e5f", "#a86b3f", "#7a4a2a", "#4e2e1b"]
const HAIR_COLORS = ["#2b1b12", "#6b3f1f", "#c9842a", "#e9d37a", "#b52e2e", "#4b4b55", "#e8e8ee", "#6a3fb5", "#2e8b57", "#ff7ab6"]
const HAIR_STYLES = ["Short", "Spiky", "Long", "Bun", "Curly", "Buzz", "Mohawk"]
## Facial hair (the game's own look only; profile.facialHair).
const FACIAL_HAIR = ["None", "Stubble", "Mustache", "Beard"]


static func _clamp01(x: float) -> float:
	return maxf(0.0, minf(1.0, x))


static func _lv_t(level) -> float:
	return _clamp01((level - 1) / 35.0)


static func _bulk_t(level) -> float:
	return _clamp01((level - 1) / 50.0)


## Width of the torso on row `y` (always even, between waist and shoulders).
static func _torso_w(y, torso_top: int, torso_h: int, shoulder_w: int, waist_w: int) -> int:
	var t: float = _clamp01(float(y - torso_top) / maxi(1, torso_h - 1))
	var eased: float = pow(t, 1.4)
	var tw: int = TTUtil.jsround(shoulder_w + (waist_w - shoulder_w) * eased)
	if tw % 2 != 0:
		tw += 1
	return maxi(waist_w, mini(shoulder_w, tw))


static func _torso_left(y, cx: int, torso_top: int, torso_h: int, shoulder_w: int, waist_w: int) -> int:
	# The width is always even, so the half is exact.
	return cx - int(_torso_w(y, torso_top, torso_h, shoulder_w, waist_w) / 2.0)


static func _make_arm(side: int, pose: String, stage: int, lift: float, bulk: float, torso_top: int, torso_left0: int, torso_w0: int, upper_arm_w: int, forearm_w: int, hand_w: int, upper_arm_len: int, forearm_len: int) -> Dictionary:
	var aw: int = upper_arm_w
	var half: int = int(floor(aw / 2.0))
	var tl: int = torso_left0
	var t_right: int = tl + torso_w0 - 1
	var sx: int = (tl - aw + half) if side < 0 else (t_right + 1 + half)
	var sy: int = torso_top + half + (1 if stage == 0 else 0)
	var spread: int = TTUtil.jsround(lift * 2 + bulk)
	var elbow: Dictionary
	var wrist: Dictionary
	if pose == "flex":
		elbow = {"x": sx + side * (upper_arm_len - 1), "y": sy + 1}
		wrist = {"x": elbow.x + side, "y": elbow.y - forearm_len}
	else:
		elbow = {"x": sx + side * spread, "y": sy + upper_arm_len}
		wrist = {"x": elbow.x, "y": elbow.y + forearm_len}
	var hw: int = hand_w
	var hand: Dictionary
	if pose == "flex":
		hand = {"x": wrist.x - int(floor(hw / 2.0)), "y": wrist.y - 3, "w": hw, "h": 3}
	else:
		hand = {"x": wrist.x - int(floor(hw / 2.0)), "y": wrist.y + int(floor(forearm_w / 2.0)), "w": hw, "h": 3}
	return {"shoulder": {"x": sx, "y": sy}, "elbow": elbow, "wrist": wrist, "upperW": aw, "foreW": forearm_w, "hand": hand, "side": side}


static func _make_leg(side: int, cx: int, thigh_w: int, calf_w: int, leg_top: int, thigh_len: int) -> Dictionary:
	var x: int = (cx - 1 - thigh_w) if side < 0 else (cx + 1)
	var calf_x: int = x + int(floor((thigh_w - calf_w) / 2.0))
	return {"x": x, "thighW": thigh_w, "calfX": calf_x, "calfW": calf_w, "top": leg_top, "kneeY": leg_top + thigh_len, "side": side}


static func body_metrics(i: Dictionary) -> Dictionary:
	if not Pix.classic:
		return HeroFigure.metrics(i)
	var bulk: float = _bulk_t(i.heroLevel)
	var lift: float = _lv_t(i.liftLevel)
	var climb: float = _lv_t(i.climbLevel)
	var run: float = _lv_t(i.runLevel)
	var ride: float = _lv_t(i.rideLevel)
	var stage: int = Xp.stage_for_level(i.heroLevel)
	var cx: int = int(HERO_W / 2.0)
	var baseline: int = HERO_H - 3 # bottom row of the feet is baseline - 1
	var frame: int = int(i.frame)
	var pose: String = i.pose
	var bob: int = 0
	if pose == "idle":
		bob = 0 if frame % 4 < 2 else 1
	elif not Pix.classic:
		# A flex is held, then pumped: the whole upper body dips every other frame.
		bob = frame % 2

	var foot_h: int = 3
	var leg_len: int = 12 + TTUtil.jsround(bulk * 3)
	var torso_h: int = 12 + TTUtil.jsround(bulk * 3)
	var neck_h: int = 2
	var head_w: int = 12
	var head_h: int = 11
	var neck_w: int = 2 + TTUtil.jsround(bulk * 2)
	var shoulder_w: int = 10 + TTUtil.jsround(lift * 8 + bulk * 4)
	if shoulder_w % 2 != 0:
		shoulder_w += 1
	var waist_w: int = maxi(6, 8 + TTUtil.jsround(bulk * 3) - TTUtil.jsround(run * 2))
	if waist_w % 2 != 0:
		waist_w += 1
	waist_w = mini(waist_w, shoulder_w)
	var upper_arm_w: int = 2 + TTUtil.jsround(lift * 2.5 + bulk * 1.5)
	var forearm_w: int = maxi(2, mini(upper_arm_w + 1, 2 + TTUtil.jsround(climb * 3 + bulk * 0.5)))
	var hand_w: int = maxi(2, mini(forearm_w, 4))
	var upper_arm_len: int = 7 + TTUtil.jsround(bulk)
	var forearm_len: int = 6 + TTUtil.jsround(bulk)
	var thigh_w: int = 3 + TTUtil.jsround(ride * 3 + bulk * 1.5)
	var calf_w: int = mini(thigh_w, 2 + TTUtil.jsround(run * 1.5 + ride * 1.5))

	var feet_top: int = baseline - foot_h
	var leg_top: int = feet_top - leg_len
	var torso_bottom: int = leg_top - 1 + bob
	var torso_top: int = torso_bottom - torso_h + 1
	var neck_top: int = torso_top - neck_h
	var hunch: int = 1 if stage == 0 else 0
	var head_top: int = neck_top - head_h + hunch
	var head_left: int = cx - int(head_w / 2.0)
	var eye_y: int = head_top + 5

	# The lambdas capture plain ints (by value), never the metrics Dictionary:
	# that would be a reference cycle.
	var torso_w_fn: Callable = func(y): return HeroBody._torso_w(y, torso_top, torso_h, shoulder_w, waist_w)
	var torso_left_fn: Callable = func(y): return HeroBody._torso_left(y, cx, torso_top, torso_h, shoulder_w, waist_w)

	var torso_left0: int = _torso_left(torso_top, cx, torso_top, torso_h, shoulder_w, waist_w)
	var torso_w0: int = _torso_w(torso_top, torso_top, torso_h, shoulder_w, waist_w)
	var arm_l: Dictionary = _make_arm(-1, pose, stage, lift, bulk, torso_top, torso_left0, torso_w0, upper_arm_w, forearm_w, hand_w, upper_arm_len, forearm_len)
	var arm_r: Dictionary = _make_arm(1, pose, stage, lift, bulk, torso_top, torso_left0, torso_w0, upper_arm_w, forearm_w, hand_w, upper_arm_len, forearm_len)

	var thigh_len: int = TTUtil.jsround(leg_len * 0.5)
	var leg_l: Dictionary = _make_leg(-1, cx, thigh_w, calf_w, leg_top, thigh_len)
	var leg_r: Dictionary = _make_leg(1, cx, thigh_w, calf_w, leg_top, thigh_len)

	return {
		"t": {"bulk": bulk, "lift": lift, "climb": climb, "run": run, "ride": ride},
		"stage": stage,
		"cx": cx,
		"baseline": baseline,
		"bob": bob,
		"headW": head_w,
		"headH": head_h,
		"headTop": head_top,
		"headLeft": head_left,
		"eyeY": eye_y,
		"neckW": neck_w,
		"neckTop": neck_top,
		"neckH": neck_h,
		"torsoTop": torso_top,
		"torsoBottom": torso_bottom,
		"torsoH": torso_h,
		"shoulderW": shoulder_w,
		"waistW": waist_w,
		"torsoW": torso_w_fn,
		"torsoLeft": torso_left_fn,
		"armL": arm_l,
		"armR": arm_r,
		"legL": leg_l,
		"legR": leg_r,
		"legTop": leg_top,
		"legLen": leg_len,
		"feetTop": feet_top,
		"footH": foot_h,
		"footL": {"x": leg_l.x - 1, "w": thigh_w + 1},
		"footR": {"x": leg_r.x, "w": thigh_w + 1},
		"pose": pose,
		"skin": SKIN_TONES[int(i.skin) % SKIN_TONES.size()],
		"hair": HAIR_COLORS[int(i.hairColor) % HAIR_COLORS.size()],
	}


static func draw_arm_skin(p: Pix, a: Dictionary, color: String) -> void:
	p.limb(a.shoulder.x, a.shoulder.y, a.elbow.x, a.elbow.y, a.upperW, color)
	p.limb(a.elbow.x, a.elbow.y, a.wrist.x, a.wrist.y, a.foreW, color)


static func _draw_legs_skin(p: Pix, m: Dictionary) -> void:
	for leg in [m.legL, m.legR]:
		p.rect(leg.x, leg.top, leg.thighW, leg.kneeY - leg.top, m.skin)
		p.rect(leg.calfX, leg.kneeY, leg.calfW, m.feetTop - leg.kneeY, m.skin)
		# calf bump on the outside
		if leg.calfW >= 3 and m.t.run + m.t.ride > 0.5:
			var bx: int = (leg.calfX - 1) if leg.side < 0 else (leg.calfX + leg.calfW)
			p.rect(bx, leg.kneeY + 1, 1, 3, m.skin)


static func _draw_torso_skin(p: Pix, m: Dictionary) -> void:
	for y in range(m.torsoTop, m.torsoBottom + 1):
		p.hline(m.torsoLeft.call(y), y, m.torsoW.call(y), m.skin)
	var tl: int = m.torsoLeft.call(m.torsoTop)
	var tw: int = m.torsoW.call(m.torsoTop)
	if m.t.lift > 0.3:
		# Deltoid caps
		p.set_px(tl - 1, m.torsoTop + 1, m.skin)
		p.set_px(tl + tw, m.torsoTop + 1, m.skin)
	else:
		# soften shoulders when scrawny
		p.set_px(tl, m.torsoTop, null)
		p.set_px(tl + tw - 1, m.torsoTop, null)


static func _draw_definition(p: Pix, m: Dictionary) -> void:
	var dark: String = Pix.shade(m.skin, 0.78)
	# pecs
	if m.t.lift > 0.45 or m.t.bulk > 0.5:
		var y: int = m.torsoTop + 4
		p.hline(m.cx - 4, y, 3, dark)
		p.hline(m.cx + 1, y, 3, dark)
	# abs
	if m.t.run > 0.3 and m.t.bulk > 0.25:
		var y0: int = m.torsoTop + 6
		for r in range(3):
			var y: int = y0 + r * 2
			if y >= m.torsoBottom - 1:
				break
			p.set_px(m.cx - 2, y, dark)
			p.set_px(m.cx + 1, y, dark)
		p.vline(m.cx - 1, y0, mini(6, m.torsoBottom - y0 - 1), Pix.mix(m.skin, dark, 0.5))


static func _draw_arm_definition(p: Pix, m: Dictionary) -> void:
	var hi: String = Pix.shade(m.skin, 1.18)
	for a in [m.armL, m.armR]:
		if a.upperW >= 4:
			# bicep highlight
			var mx: int = TTUtil.jsround((a.shoulder.x + a.elbow.x) / 2.0) - int(floor(a.upperW / 2.0))
			var my: int = (a.shoulder.y - 1) if m.pose == "flex" else (TTUtil.jsround((a.shoulder.y + a.elbow.y) / 2.0) - 1)
			p.set_px(mx + (0 if a.side < 0 else a.upperW - 1), my, hi)
			if m.pose == "flex":
				p.rect(mx + 1, a.shoulder.y - int(floor(a.upperW / 2.0)) - 1, 2, 1, m.skin)
		if a.foreW >= 4:
			var fx: int = a.wrist.x - int(floor(a.foreW / 2.0))
			var fy: int = TTUtil.jsround((a.elbow.y + a.wrist.y) / 2.0)
			p.set_px(fx + (0 if a.side < 0 else a.foreW - 1), fy, hi)


## The face of the game's look: two-by-two eyes with a catch-light that can
## glance sideways, brows that get more determined as the hero grows, a small
## nose, a real smile.
static func _draw_head_lit(p: Pix, m: Dictionary, i: Dictionary) -> void:
	var skin: String = m.skin
	var x: int = m.headLeft
	var y: int = m.headTop
	var shade: String = Pix.shade(skin, 0.86)
	p.round_rect(x, y, m.headW, m.headH, skin, 2)
	# ears: the far one in shade
	p.rect(x - 1, y + 5, 1, 2, skin)
	p.rect(x + m.headW, y + 5, 1, 2, shade)
	# the far cheek and the jaw under it are turned from the light
	p.vline(x + m.headW - 1, y + 2, m.headH - 4, shade)
	p.vline(x + m.headW - 2, y + m.headH - 3, 2, shade)
	p.hline(m.cx + 1, y + m.headH - 1, 3, shade)
	# eyes
	var look: int = int(i.get("look", 0))
	var eye: String = Pix.OUTLINE
	var lx: int = m.cx - 4 + look
	var rx: int = m.cx + 2 + look
	var ey: int = m.eyeY
	if i.blink:
		p.hline(lx, ey + 1, 2, eye)
		p.hline(rx, ey + 1, 2, eye)
	else:
		p.rect(lx, ey, 2, 2, eye)
		p.rect(rx, ey, 2, 2, eye)
		var glint: int = 1 if look > 0 else 0
		p.set_px(lx + glint, ey, "#ffffff")
		p.set_px(rx + glint, ey, "#ffffff")
	# brows: the colour of the hair, settled into the skin
	var brow: String = Pix.mix(Pix.shade(skin, 0.5), m.hair, 0.45)
	if m.stage == 0:
		p.set_px(m.cx - 3, ey - 2, brow)
		p.set_px(m.cx + 2, ey - 2, brow)
	elif m.stage >= 3:
		p.set_px(m.cx - 4, ey - 2, brow)
		p.set_px(m.cx - 3, ey - 1, brow)
		p.set_px(m.cx + 3, ey - 2, brow)
		p.set_px(m.cx + 2, ey - 1, brow)
	else:
		p.hline(m.cx - 4, ey - 2, 2, brow)
		p.hline(m.cx + 2, ey - 2, 2, brow)
	# On dark skin dark eyes need something to sit on: a lighter lid under each.
	if int(i.skin) % SKIN_TONES.size() >= 3 and not i.blink:
		var lid: String = Pix.shade(skin, 1.22)
		p.hline(lx, ey + 2, 2, lid)
		p.hline(rx, ey + 2, 2, lid)
	# mouth
	var mouth: String = Pix.shade(skin, 0.55)
	var my: int = y + 8
	if i.happy:
		p.set_px(m.cx - 2, my, mouth)
		p.set_px(m.cx + 1, my, mouth)
		p.hline(m.cx - 1, my + 1, 2, mouth)
		var blush: String = Pix.mix(skin, "#ff5a6e", 0.42)
		p.set_px(x + 1, my - 1, blush)
		p.set_px(x + m.headW - 2, my - 1, blush)
	elif m.stage == 0:
		p.hline(m.cx - 1, my + 1, 2, mouth)
	else:
		p.hline(m.cx - 1, my + 1, 2, mouth)
		if m.stage >= 2:
			p.set_px(m.cx + 1, my, mouth)


static func _draw_head(p: Pix, m: Dictionary, i: Dictionary) -> void:
	if not Pix.classic:
		_draw_head_lit(p, m, i)
		return
	p.round_rect(m.headLeft, m.headTop, m.headW, m.headH, m.skin, 2)
	# ears
	p.rect(m.headLeft - 1, m.headTop + 5, 1, 2, m.skin)
	p.rect(m.headLeft + m.headW, m.headTop + 5, 1, 2, m.skin)
	# cheek shade
	var cheek: String = Pix.shade(m.skin, 0.88)
	p.vline(m.headLeft + m.headW - 1, m.headTop + 2, m.headH - 4, cheek)
	# eyes
	var eye: String = Pix.OUTLINE
	var lx: int = m.cx - 3
	var rx: int = m.cx + 2
	if i.blink:
		p.set_px(lx, m.eyeY + 1, eye)
		p.set_px(rx, m.eyeY + 1, eye)
	else:
		p.rect(lx, m.eyeY, 1, 2, eye)
		p.rect(rx, m.eyeY, 1, 2, eye)
		p.set_px(lx, m.eyeY, "#ffffff")
		p.set_px(rx, m.eyeY, "#ffffff")
		p.set_px(lx, m.eyeY + 1, eye)
		p.set_px(rx, m.eyeY + 1, eye)
	# brows
	if m.stage == 0:
		p.set_px(lx + 1, m.eyeY - 2, Pix.shade(m.skin, 0.7))
		p.set_px(rx - 1, m.eyeY - 2, Pix.shade(m.skin, 0.7))
	elif m.stage >= 3:
		p.set_px(lx, m.eyeY - 2, Pix.shade(m.skin, 0.6))
		p.set_px(lx + 1, m.eyeY - 1, Pix.shade(m.skin, 0.6))
		p.set_px(rx, m.eyeY - 2, Pix.shade(m.skin, 0.6))
		p.set_px(rx - 1, m.eyeY - 1, Pix.shade(m.skin, 0.6))
	# mouth
	var mouth: String = Pix.shade(m.skin, 0.6)
	var my: int = m.headTop + 8
	if i.happy:
		p.hline(m.cx - 1, my + 1, 2, mouth)
		p.set_px(m.cx - 2, my, mouth)
		p.set_px(m.cx + 1, my, mouth)
		p.set_px(m.cx - 3, my, "#ff9aa2")
		p.set_px(m.cx + 2, my, "#ff9aa2")
	elif m.stage == 0:
		p.hline(m.cx - 1, my + 1, 2, mouth)
	else:
		p.hline(m.cx - 1, my, 2, mouth)
		if m.stage >= 2:
			p.set_px(m.cx + 1, my - 1, mouth)


static func _draw_hair(p: Pix, m: Dictionary, i: Dictionary, hat_covers_top: bool) -> void:
	var c: String = m.hair
	var dark: String = Pix.shade(c, 0.75)
	var style: int = int(i.hairStyle) % HAIR_STYLES.size()
	var x: int = m.headLeft
	var y: int = m.headTop
	if style == 5:
		# buzz
		if not hat_covers_top:
			p.round_rect(x, y, m.headW, 3, Pix.mix(m.skin, c, 0.55), 1)
		return
	if style == 2:
		# long: sides down past the shoulders
		p.rect(x - 1, y + 2, 2, m.headH + 2, c)
		p.rect(x + m.headW - 1, y + 2, 2, m.headH + 2, c)
		p.rect(x - 1, y + m.headH + 2, 2, 2, dark)
		p.rect(x + m.headW - 1, y + m.headH + 2, 2, 2, dark)
	if hat_covers_top:
		# only sideburns / fringe peek out
		p.rect(x, y + 2, 1, 3, c)
		p.rect(x + m.headW - 1, y + 2, 1, 3, c)
		return
	# base cap
	p.round_rect(x, y - 1, m.headW, 4, c, 1)
	p.rect(x, y + 2, 1, 3, c)
	p.rect(x + m.headW - 1, y + 2, 1, 3, c)
	# fringe
	p.set_px(x + 3, y + 3, c)
	p.set_px(x + 8, y + 3, c)
	if not Pix.classic and style != 6:
		# where the light catches the crown, and the far side falling away
		var hi: String = Pix.shade(c, 1.28)
		p.hline(x + 2, y, 3, hi)
		p.set_px(x + 5, y + 1, hi)
		p.rect(x + m.headW - 2, y, 2, 2, dark)
		p.set_px(x + m.headW - 1, y + 3, dark)
		p.set_px(x + m.headW - 1, y + 4, dark)
	match style:
		1: # spiky
			p.set_px(x + 1, y - 2, c)
			p.set_px(x + 4, y - 2, c)
			p.set_px(x + 7, y - 2, c)
			p.set_px(x + 10, y - 2, c)
			p.set_px(x + 2, y - 3, c)
			p.set_px(x + 6, y - 3, c)
			p.set_px(x + 9, y - 3, c)
		3: # bun
			p.round_rect(x + 4, y - 4, 4, 3, c, 1)
			p.set_px(x + 5, y - 3, dark)
		4: # curly
			for k in range(0, m.headW, 2):
				p.set_px(x + k, y - 2, c)
			for k in range(1, m.headW, 2):
				p.set_px(x + k, y - 3, c)
			p.rect(x - 1, y, 1, 4, c)
			p.rect(x + m.headW, y, 1, 4, c)
		6: # mohawk
			p.rect(x, y - 1, m.headW, 4, null)
			p.rect(x, y + 2, 1, 2, Pix.mix(m.skin, c, 0.5))
			p.rect(x + m.headW - 1, y + 2, 1, 2, Pix.mix(m.skin, c, 0.5))
			p.rect(x + 5, y - 4, 2, 5, c)
			p.set_px(x + 4, y - 2, c)
			p.set_px(x + 7, y - 2, c)


## Darken the right-most pixel of every horizontal run: cheap pixel-art lighting.
static func _shade_runs(p: Pix) -> void:
	var pw: int = p.w
	for y in range(p.h):
		var row: int = y * pw
		var x: int = 0
		while x < pw:
			var c: int = p.data[row + x]
			if c == 0:
				x += 1
				continue
			var run: int = 1
			while x + run < pw and p.data[row + x + run] == c:
				run += 1
			if run >= 3:
				p.set_px(x + run - 1, y, Pix.shade(Pix.raw_to_hex(c), 0.82))
			x += run


## Draws the hero into `p` (a HERO_W x HERO_H buffer) and returns its Metrics.
## `opts` is {visuals, noOutline?}; noOutline skips the outline (used when
## compositing into a scene that outlines later).
static func draw_hero(p: Pix, i: Dictionary, opts: Dictionary) -> Dictionary:
	if not Pix.classic:
		return _draw_figure(p, i, opts)
	var m: Dictionary = body_metrics(i)
	var v: Dictionary = opts.visuals
	var frame: int = int(i.frame)

	var back = v.get("back")
	if back != null:
		Equipment.draw_back_item(p, back, m, frame)

	_draw_legs_skin(p, m)
	var legs = v.get("legs")
	if legs != null:
		Equipment.draw_leg_garment(p, legs, m)
	var body = v.get("body")
	if body != null and body.kind == "singlet":
		Equipment.draw_leg_garment(p, {"kind": "shorts", "color": body.color}, m)

	_draw_torso_skin(p, m)
	draw_arm_skin(p, m.armL, m.skin)
	draw_arm_skin(p, m.armR, m.skin)
	# hands (skin)
	for a in [m.armL, m.armR]:
		p.rect(a.hand.x, a.hand.y, a.hand.w, a.hand.h, m.skin)

	if body != null:
		Equipment.draw_body_garment(p, body, m)
	else:
		_draw_definition(p, m)
	_draw_arm_definition(p, m)

	var hands = v.get("hands")
	if hands != null:
		Equipment.draw_hands(p, hands, m)
	var accessory = v.get("accessory")
	if accessory != null:
		Equipment.draw_accessory(p, accessory, m, frame)

	Equipment.draw_feet(p, v.get("feet"), m, frame)

	# neck
	p.rect(m.cx - int(floor(m.neckW / 2.0)), m.neckTop, m.neckW, m.neckH + 1, m.skin)
	if not Pix.classic:
		# the shadow the chin throws on it
		p.hline(m.cx - int(floor(m.neckW / 2.0)), m.neckTop + (1 if m.stage == 0 else 0), m.neckW, Pix.shade(m.skin, 0.78))
	if accessory != null:
		Equipment.draw_accessory_over(p, accessory, m, frame)

	_draw_head(p, m, i)
	var hat = v.get("head")
	var covers_top: bool = hat != null and ["beanie", "cap", "helmet", "bandana", "wizard", "viking"].has(hat.kind) and not (hat.kind == "cap" and hat.get("visor", false))
	_draw_hair(p, m, i, covers_top)
	if hat != null:
		Equipment.draw_head_item(p, hat, m)
	var face = v.get("face")
	if face != null:
		Equipment.draw_face_item(p, face, m)

	if Pix.classic:
		_shade_runs(p)
		if not opts.get("noOutline", false):
			p.outline(Pix.OUTLINE)
	else:
		if not opts.get("flat", false):
			p.light()
		if not opts.get("noOutline", false):
			p.outline_tinted(Pix.OUTLINE)
	var aura = v.get("aura")
	if aura != null and aura.kind == "aura":
		Equipment.draw_aura(p, aura.style, m, frame)
	return m


## The game's own hero (HeroFigure): a shaded body, clothes that follow it
## (FigureGear), the rest of the gear from Equipment, then light on that gear
## only (what the figure painted is lit already) and the outline.
static func _draw_figure(p: Pix, i: Dictionary, opts: Dictionary) -> Dictionary:
	var m: Dictionary = HeroFigure.metrics(i)
	var v: Dictionary = opts.visuals
	var frame: int = int(i.frame)
	# own[k]: pixel k was last painted by the figure itself (skin, its clothes,
	# face, hair), so the lighting pass at the end leaves it alone.
	var own: PackedByteArray = PackedByteArray()
	own.resize(p.data.size())
	var back = v.get("back")
	if back != null and not FigureGear.back_behind(p, back, m):
		Equipment.draw_back_item(p, back, m, frame)
	var before: PackedInt32Array = p.data.duplicate()
	HeroFigure.draw_body(p, m)
	var legs = v.get("legs")
	var body = v.get("body")
	if legs != null:
		if not FigureGear.leg_garment(p, legs, m):
			_mark(own, before, p)
			Equipment.draw_leg_garment(p, legs, m)
			before = p.data.duplicate()
	elif body != null and body.kind == "singlet":
		FigureGear.leg_garment(p, {"kind": "shorts", "color": body.color}, m)
	else:
		# Nothing on the legs: plain gym shorts.
		HeroFigure.paint_cloth(p, m, HeroFigure.shorts_region(m), HeroFigure.PLAIN_SHORTS)
	if body != null and not FigureGear.body_garment(p, body, m):
		_mark(own, before, p)
		Equipment.draw_body_garment(p, body, m)
		before = p.data.duplicate()
	if back != null:
		FigureGear.back_front(p, back, m)
	var feet = v.get("feet")
	if feet != null and not FigureGear.feet(p, feet, m, frame):
		_mark(own, before, p)
		Equipment.draw_feet(p, feet, m, frame)
		before = p.data.duplicate()
	var hands = v.get("hands")
	if hands != null and not FigureGear.hands(p, hands, m):
		_mark(own, before, p)
		Equipment.draw_hands(p, hands, m)
		before = p.data.duplicate()
	_mark(own, before, p)
	var accessory = v.get("accessory")
	if accessory != null:
		Equipment.draw_accessory(p, accessory, m, frame)
		Equipment.draw_accessory_over(p, accessory, m, frame)
	_unmark(own, before, p)
	before = p.data.duplicate()
	HeroFigure.draw_face(p, m, i)
	var hat = v.get("head")
	var covers_top: bool = hat != null and ["beanie", "cap", "helmet", "bandana", "wizard", "viking"].has(hat.kind) and not (hat.kind == "cap" and hat.get("visor", false))
	HeroFigure.draw_hair(p, m, i, covers_top)
	_mark(own, before, p)
	before = p.data.duplicate()
	if hat != null:
		Equipment.draw_head_item(p, hat, m)
	var face = v.get("face")
	if face != null:
		Equipment.draw_face_item(p, face, m)
	_unmark(own, before, p)
	if not opts.get("flat", false):
		var keep: PackedInt32Array = p.data.duplicate()
		p.light()
		for k in range(own.size()):
			if own[k] == 1:
				p.data[k] = keep[k]
	if not opts.get("noOutline", false):
		p.outline_tinted(Pix.OUTLINE)
	var aura = v.get("aura")
	if aura != null and aura.kind == "aura":
		Equipment.draw_aura(p, aura.style, m, frame)
	return m


## Pixels that changed since `before` were painted by the figure.
static func _mark(own: PackedByteArray, before: PackedInt32Array, p: Pix) -> void:
	for k in range(own.size()):
		if p.data[k] != before[k]:
			own[k] = 1


## Pixels that changed since `before` were painted by gear (to be lit).
static func _unmark(own: PackedByteArray, before: PackedInt32Array, p: Pix) -> void:
	for k in range(own.size()):
		if p.data[k] != before[k]:
			own[k] = 0
