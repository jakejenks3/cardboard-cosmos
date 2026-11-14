class_name Chatter
extends RefCounted
## What your companion says when you open the app (port of chatter.ts): one
## contextual nudge, chosen by priority, stable for the day so it does not flicker.
##
## ChatterCtx: {
##   s: PlayerState,
##   today: String (date key),
##   daysSinceLast: int or null (days since the last logged session, null when there are none),
##   trainedToday: bool,
##   claimable: int (quest rewards waiting to be claimed),
##   boss: BossDef (Campaign.boss_at(s.campaign.index)),
##   bossHpLeft: number,
##   nearest: NextGoal or null (optional) }

const _IDLE = [
	"Ready when you are.",
	"Today is a good day to deal some damage.",
	"Small sessions count. All of them.",
	"I believe in you. Also I live here now.",
	"Future you says thanks in advance.",
	"Log it or it did not happen.",
	"One session at a time. That is the whole trick.",
]

const _WEAK_WORDS = {"lift": "lifting", "climb": "climbing", "run": "running", "ride": "cycling"}


static func pet_line(c: Dictionary) -> String:
	var s: Dictionary = c.s
	if s.totals.sessions == 0:
		return "Log your first session and watch what happens."
	if c.claimable > 0:
		return "Psst — %s quest reward%s waiting to be claimed." % [TTUtil.num_str(c.claimable), "" if c.claimable == 1 else "s"]
	var days_since_last = c.get("daysSinceLast")
	var trained_today: bool = TTUtil.truthy(c.get("trainedToday"))
	if days_since_last != null and days_since_last >= 7:
		return "%s days since your last session. No judgment — the door is open." % TTUtil.num_str(days_since_last)
	if days_since_last != null and days_since_last >= 3 and not trained_today:
		return "%s days off. I have been practising my cheering." % TTUtil.num_str(days_since_last)
	if not trained_today and s.streak.goal - s.streak.thisWeek == 1:
		return "One more session and this week’s goal is done!"
	if float(c.bossHpLeft) / c.boss.hp <= 0.25:
		return "%s is nearly down — only %s HP left!" % [c.boss.name, Fmt.fmt_num(c.bossHpLeft, 3)]
	var nearest = c.get("nearest")
	if nearest != null and nearest.ratio >= 0.8:
		return "So close to “%s”. One good session might do it." % nearest.title
	if trained_today:
		return "Weekly goal done. Rest is part of the plan." if s.streak.thisWeek >= s.streak.goal else "Nice work today. I saw everything."
	var weak = c.boss.get("weak")
	if TTUtil.truthy(weak):
		return "%s hates %s. Just saying." % [c.boss.name, _WEAK_WORDS.get(weak, "undefined")]
	return _IDLE[Rng.hash_string(c.today) % _IDLE.size()]
