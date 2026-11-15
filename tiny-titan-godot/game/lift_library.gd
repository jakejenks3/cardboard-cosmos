class_name LiftLibrary
extends RefCounted
## The lift library: a catalog of lifts by body part and equipment, joined with
## what the player has actually logged. Pure logic (no scene, no autoload), so
## it runs headless from tests/lift_library_test.gd. The screen is
## ui/screens/journey_lifts.gd.
##
## Entry: {name, part, equip, family, also, tip, keys: [normalized names that
##         count as this lift], own: bool (true = not in the catalog, logged by the player)}
## Stats (per normalized name, see `stats`): {name (as last typed), count, last (date),
##         bestKg, bestReps (reps of the heaviest set), e1rm, bwReps (most reps in a
##         bodyweight set), volumeKg, reps, history: [{date, id, sets}] newest first}
## Row:   an Entry plus "st": merged Stats or null when never done.

const PARTS = [
	{"id": "chest", "name": "Chest"},
	{"id": "back", "name": "Back"},
	{"id": "shoulders", "name": "Shoulders"},
	{"id": "biceps", "name": "Biceps"},
	{"id": "triceps", "name": "Triceps"},
	{"id": "forearms", "name": "Forearms"},
	{"id": "quads", "name": "Quads"},
	{"id": "hamstrings", "name": "Hamstrings"},
	{"id": "glutes", "name": "Glutes"},
	{"id": "calves", "name": "Calves"},
	{"id": "core", "name": "Core"},
	{"id": "full", "name": "Full body"},
	{"id": "other", "name": "Your own"},
]

const EQUIPMENT = [
	{"id": "barbell", "name": "Barbell"},
	{"id": "dumbbell", "name": "Dumbbell"},
	{"id": "cable", "name": "Cable"},
	{"id": "machine", "name": "Machine"},
	{"id": "bodyweight", "name": "Bodyweight"},
	{"id": "kettlebell", "name": "Kettlebell"},
	{"id": "band", "name": "Band"},
	{"id": "other", "name": "Other"},
]

const SORTS = [
	{"value": "part", "label": "Body part"},
	{"value": "name", "label": "A-Z"},
	{"value": "count", "label": "Most done"},
	{"value": "best", "label": "Heaviest"},
	{"value": "recent", "label": "Recent"},
]

const REP_MARKS = [1, 3, 5, 8, 10, 12]

## [name, part, equipment, family, also works, tip, other names...]
const LIFTS = [
	# --- chest ---------------------------------------------------------------
	["Bench Press", "chest", "barbell", "Bench press", "triceps, front delts", "Pinch your shoulder blades, bar to mid-chest, feet planted."],
	["Incline Bench Press", "chest", "barbell", "Bench press", "upper chest, front delts", "Bench at 30 to 45 degrees; bar to the upper chest."],
	["Decline Bench Press", "chest", "barbell", "Bench press", "lower chest, triceps", "Shorter range than flat; keep the bar over the lower chest."],
	["Dumbbell Bench Press", "chest", "dumbbell", "Bench press", "triceps, front delts", "Deeper stretch than the bar; elbows about 45 degrees from your sides.", "dumbbell press", "db bench press", "db bench"],
	["Incline Dumbbell Press", "chest", "dumbbell", "Bench press", "upper chest, front delts", "Press up and slightly in; do not clang the bells.", "incline db press"],
	["Decline Dumbbell Press", "chest", "dumbbell", "Bench press", "lower chest", "Hook your feet; lower under control."],
	["Machine Chest Press", "chest", "machine", "Bench press", "triceps", "Seat so the handles line up with mid-chest.", "chest press"],
	["Smith Machine Bench Press", "chest", "machine", "Bench press", "triceps", "Fixed path: set the bench so the bar meets mid-chest.", "smith bench press", "smith bench"],
	["Dumbbell Fly", "chest", "dumbbell", "Fly", "front delts", "Soft elbows, wide arc, stop when the chest is stretched.", "chest fly", "db fly"],
	["Incline Dumbbell Fly", "chest", "dumbbell", "Fly", "upper chest", "Same arc on a low incline; go lighter than you think."],
	["Cable Fly", "chest", "cable", "Fly", "front delts", "Step forward, hug a barrel, squeeze the hands together.", "cable crossover", "cable crossovers"],
	["Low-to-High Cable Fly", "chest", "cable", "Fly", "upper chest", "Pulleys low; sweep up to eye height."],
	["High-to-Low Cable Fly", "chest", "cable", "Fly", "lower chest", "Pulleys high; sweep down to your hips."],
	["Pec Deck", "chest", "machine", "Fly", "front delts", "Elbows slightly bent; pause where the pads meet.", "machine fly", "pec fly"],
	["Push-up", "chest", "bodyweight", "Push-up", "triceps, core", "Body in one line, chest to the floor, lock out."],
	["Incline Push-up", "chest", "bodyweight", "Push-up", "triceps", "Hands on a bench: easier, good for high reps."],
	["Decline Push-up", "chest", "bodyweight", "Push-up", "upper chest, shoulders", "Feet on a bench: harder, more shoulders."],
	["Dip", "chest", "bodyweight", "Dip", "triceps, front delts", "Lean forward for chest, stay upright for triceps.", "tricep dip", "chest dip"],
	["Weighted Dip", "chest", "bodyweight", "Dip", "triceps, front delts", "Add load with a belt once bodyweight sets get easy."],
	["Dumbbell Pullover", "chest", "dumbbell", "Pullover", "lats, serratus", "Arc one bell behind your head with soft elbows.", "pullover"],
	# --- back ----------------------------------------------------------------
	["Deadlift", "back", "barbell", "Deadlift", "glutes, hamstrings, grip", "Bar over mid-foot, brace, push the floor away."],
	["Sumo Deadlift", "back", "barbell", "Deadlift", "glutes, adductors", "Wide stance, toes out, chest up; spread the floor."],
	["Trap Bar Deadlift", "back", "barbell", "Deadlift", "quads, glutes", "Stand inside the bar; more upright and kinder on the back.", "hex bar deadlift"],
	["Rack Pull", "back", "barbell", "Deadlift", "traps, glutes", "Pull from pins around knee height to overload the top."],
	["Barbell Row", "back", "barbell", "Row", "biceps, rear delts", "Hinge to about 45 degrees; pull the bar to your belly.", "bent over row", "bent-over row"],
	["Pendlay Row", "back", "barbell", "Row", "biceps, lower back", "Flat back, every rep from a dead stop on the floor."],
	["T-Bar Row", "back", "barbell", "Row", "biceps, rear delts", "Chest proud, drive the elbows back.", "t bar row", "landmine row"],
	["Dumbbell Row", "back", "dumbbell", "Row", "biceps, rear delts", "One hand on a bench; pull the bell to your hip.", "one arm row", "single arm row", "db row"],
	["Chest-Supported Row", "back", "dumbbell", "Row", "rear delts, biceps", "Chest on an incline bench: no cheating with the hips.", "chest supported row", "incline row"],
	["Meadows Row", "back", "barbell", "Row", "rear delts, grip", "Staggered stance at a landmine; row with an overhand grip."],
	["Seated Cable Row", "back", "cable", "Row", "biceps, rear delts", "Sit tall, pull to the stomach, let the shoulders stretch forward.", "cable row", "seated row"],
	["Machine Row", "back", "machine", "Row", "biceps", "Chest on the pad; squeeze the shoulder blades."],
	["Inverted Row", "back", "bodyweight", "Row", "biceps, core", "Hang under a bar, body straight, chest to the bar.", "body row", "australian pull-up"],
	["Lat Pulldown", "back", "cable", "Pulldown", "biceps", "Lean back a little; pull the bar to the collarbone."],
	["Close-Grip Lat Pulldown", "back", "cable", "Pulldown", "biceps", "V handle; drive the elbows down to your ribs.", "close grip pulldown", "v-bar pulldown"],
	["Straight-Arm Pulldown", "back", "cable", "Pulldown", "lats, triceps", "Arms nearly straight; sweep the bar to your thighs.", "straight arm pulldown"],
	["Pull-up", "back", "bodyweight", "Pull-up", "biceps, grip", "Overhand grip, start from a dead hang, chin over the bar."],
	["Chin-up", "back", "bodyweight", "Pull-up", "biceps", "Underhand grip: more biceps than a pull-up."],
	["Neutral-Grip Pull-up", "back", "bodyweight", "Pull-up", "biceps, brachialis", "Palms facing each other: easiest on the shoulders.", "neutral grip pull-up", "hammer pull-up"],
	["Weighted Pull-up", "back", "bodyweight", "Pull-up", "biceps, grip", "Belt or a bell between your feet; same strict reps.", "weighted chin-up"],
	["Assisted Pull-up", "back", "machine", "Pull-up", "biceps", "Use the pad or a band; take a little less help each week."],
	["Barbell Shrug", "back", "barbell", "Shrug", "traps, grip", "Straight up to the ears, pause, no rolling.", "shrug", "shrugs"],
	["Dumbbell Shrug", "back", "dumbbell", "Shrug", "traps, grip", "Bells at your sides; shrug up and hold a beat."],
	["Back Extension", "back", "bodyweight", "Extension", "glutes, hamstrings", "Hinge at the hips on the bench; hold a plate to load it.", "hyperextension", "hyperextensions"],
	# --- shoulders -----------------------------------------------------------
	["Overhead Press", "shoulders", "barbell", "Overhead press", "triceps, upper chest", "Squeeze glutes, bar from the collarbone straight overhead.", "military press", "shoulder press"],
	["Push Press", "shoulders", "barbell", "Overhead press", "triceps, legs", "Dip and drive with the legs to start the bar moving."],
	["Seated Dumbbell Press", "shoulders", "dumbbell", "Overhead press", "triceps", "Back supported; press up and slightly in.", "dumbbell shoulder press", "db shoulder press"],
	["Arnold Press", "shoulders", "dumbbell", "Overhead press", "triceps", "Start palms facing you and rotate out as you press."],
	["Machine Shoulder Press", "shoulders", "machine", "Overhead press", "triceps", "Handles at ear height to start."],
	["Landmine Press", "shoulders", "barbell", "Overhead press", "upper chest, core", "Press the bar end up and away; friendly to cranky shoulders."],
	["Kettlebell Press", "shoulders", "kettlebell", "Overhead press", "triceps, core", "Bell in the rack position, press with a tight fist."],
	["Lateral Raise", "shoulders", "dumbbell", "Raise", "side delts", "Lead with the elbows to shoulder height; go light and strict.", "side raise", "lat raise"],
	["Cable Lateral Raise", "shoulders", "cable", "Raise", "side delts", "Cable behind your back: tension all the way up."],
	["Machine Lateral Raise", "shoulders", "machine", "Raise", "side delts", "Elbows on the pads; pause at the top."],
	["Front Raise", "shoulders", "dumbbell", "Raise", "front delts", "Raise to eye height without swinging."],
	["Rear Delt Fly", "shoulders", "dumbbell", "Rear delt", "rear delts, upper back", "Hinge over; sweep the bells out wide, pinkies up.", "reverse fly", "bent over fly"],
	["Reverse Pec Deck", "shoulders", "machine", "Rear delt", "rear delts", "Face the pad; open the arms wide and squeeze.", "rear delt machine"],
	["Face Pull", "shoulders", "cable", "Rear delt", "rear delts, rotator cuff", "Rope to your forehead, elbows high, pull the hands apart."],
	["Band Pull-Apart", "shoulders", "band", "Rear delt", "rear delts, upper back", "Arms straight; stretch the band to your chest.", "pull apart", "pull-apart"],
	["Upright Row", "shoulders", "barbell", "Row", "traps, side delts", "Elbows lead to shoulder height; a wider grip is kinder."],
	["Pike Push-up", "shoulders", "bodyweight", "Push-up", "triceps", "Hips high, head toward the floor between your hands."],
	["Handstand Push-up", "shoulders", "bodyweight", "Push-up", "triceps, core", "Against a wall: head to the floor and press out."],
	# --- biceps --------------------------------------------------------------
	["Bicep Curl", "biceps", "barbell", "Curl", "forearms", "Elbows pinned to your sides; no swinging.", "barbell curl", "biceps curl"],
	["EZ-Bar Curl", "biceps", "barbell", "Curl", "forearms", "The angled grip is easier on the wrists.", "ez bar curl", "ez curl"],
	["Dumbbell Curl", "biceps", "dumbbell", "Curl", "forearms", "Turn the palm up as you lift.", "db curl"],
	["Hammer Curl", "biceps", "dumbbell", "Curl", "brachialis, forearms", "Palms face each other the whole way."],
	["Incline Dumbbell Curl", "biceps", "dumbbell", "Curl", "long head", "Lie back on an incline: a big stretch at the bottom.", "incline curl"],
	["Concentration Curl", "biceps", "dumbbell", "Curl", "peak", "Elbow against your inner thigh; squeeze at the top."],
	["Spider Curl", "biceps", "dumbbell", "Curl", "short head", "Chest on an incline bench, arms hanging straight down."],
	["Zottman Curl", "biceps", "dumbbell", "Curl", "forearms", "Curl palms up, turn over, lower palms down."],
	["Preacher Curl", "biceps", "barbell", "Curl", "brachialis", "Arms on the pad; do not bounce out of the bottom."],
	["Cable Curl", "biceps", "cable", "Curl", "forearms", "Constant tension; keep the elbows still."],
	["Rope Hammer Curl", "biceps", "cable", "Curl", "brachialis, forearms", "Rope on a low pulley; thumbs up."],
	["Bayesian Curl", "biceps", "cable", "Curl", "long head", "Face away from a low pulley; curl from behind your body.", "behind the body cable curl"],
	["Machine Curl", "biceps", "machine", "Curl", "forearms", "Line the elbow up with the pivot."],
	["Band Curl", "biceps", "band", "Curl", "forearms", "Stand on the band; hardest at the top."],
	# --- triceps -------------------------------------------------------------
	["Tricep Pushdown", "triceps", "cable", "Pushdown", "forearms", "Elbows at your sides; lock out and squeeze.", "triceps pushdown", "pushdown", "cable pushdown"],
	["Rope Pushdown", "triceps", "cable", "Pushdown", "lateral head", "Pull the rope apart at the bottom."],
	["Overhead Cable Extension", "triceps", "cable", "Extension", "long head", "Face away, rope behind your head, extend forward.", "overhead rope extension", "overhead tricep extension"],
	["Skull Crusher", "triceps", "barbell", "Extension", "long head", "Lower the bar to your forehead, upper arms still.", "lying tricep extension", "skullcrusher", "skull crushers"],
	["Overhead Dumbbell Extension", "triceps", "dumbbell", "Extension", "long head", "One bell in both hands behind your head.", "dumbbell tricep extension", "french press"],
	["Dumbbell Kickback", "triceps", "dumbbell", "Extension", "lateral head", "Upper arm parallel to the floor; straighten and pause.", "tricep kickback", "kickback"],
	["Close-Grip Bench Press", "triceps", "barbell", "Bench press", "chest, front delts", "Hands shoulder width, elbows tucked.", "close grip bench press", "close grip bench", "cgbp"],
	["Diamond Push-up", "triceps", "bodyweight", "Push-up", "chest", "Thumbs and index fingers make a diamond under your chest."],
	["Bench Dip", "triceps", "bodyweight", "Dip", "chest, shoulders", "Hands on a bench behind you; feet up to make it harder."],
	["Machine Dip", "triceps", "machine", "Dip", "chest", "Seated; press the handles down to lockout.", "seated dip"],
	# --- forearms ------------------------------------------------------------
	["Wrist Curl", "forearms", "barbell", "Wrist", "grip", "Forearms on your thighs, palms up, curl the wrists."],
	["Reverse Wrist Curl", "forearms", "barbell", "Wrist", "extensors", "Same, palms down. Go light."],
	["Reverse Curl", "forearms", "barbell", "Curl", "brachioradialis, biceps", "Overhand grip curl."],
	["Farmer's Carry", "forearms", "dumbbell", "Carry", "traps, core", "Heavy bells, tall posture, short quick steps.", "farmers carry", "farmers walk", "farmer's walk", "farmer carry"],
	["Plate Pinch", "forearms", "other", "Grip", "thumbs", "Pinch two plates smooth side out; hold for time."],
	["Wrist Roller", "forearms", "other", "Wrist", "grip", "Roll the weight up and back down under control."],
	# --- quads ---------------------------------------------------------------
	["Squat", "quads", "barbell", "Squat", "glutes, core", "Brace, sit between your hips, knees track over the toes.", "back squat", "barbell squat"],
	["Front Squat", "quads", "barbell", "Squat", "core, upper back", "Elbows high, bar on the shoulders, stay upright."],
	["Pause Squat", "quads", "barbell", "Squat", "glutes, core", "Hold the bottom for two seconds; no bounce."],
	["Box Squat", "quads", "barbell", "Squat", "glutes, hamstrings", "Sit back to a box, pause, drive up."],
	["Zercher Squat", "quads", "barbell", "Squat", "core, upper back", "Bar in the crook of your elbows."],
	["Goblet Squat", "quads", "dumbbell", "Squat", "glutes, core", "Hold one bell at your chest; elbows inside the knees."],
	["Smith Machine Squat", "quads", "machine", "Squat", "glutes", "Feet a little forward; fixed bar path.", "smith squat"],
	["Hack Squat", "quads", "machine", "Squat", "glutes", "Back flat on the pad; feet low for more quads."],
	["Leg Press", "quads", "machine", "Press", "glutes, hamstrings", "Lower until the knees are near 90 degrees; never lock out hard."],
	["Leg Extension", "quads", "machine", "Extension", "quads only", "Pause at the top; control the way down."],
	["Bulgarian Split Squat", "quads", "dumbbell", "Split squat", "glutes", "Rear foot on a bench; drop straight down.", "rear foot elevated split squat", "bulgarians"],
	["Split Squat", "quads", "dumbbell", "Split squat", "glutes", "Staggered stance, both feet on the floor."],
	["Lunge", "quads", "dumbbell", "Lunge", "glutes", "Step forward, both knees to 90 degrees, push back.", "lunges", "forward lunge"],
	["Reverse Lunge", "quads", "dumbbell", "Lunge", "glutes", "Step back: easier on the knees than stepping forward."],
	["Walking Lunge", "quads", "dumbbell", "Lunge", "glutes", "Keep travelling; long steps for glutes, short for quads.", "walking lunges"],
	["Step-up", "quads", "dumbbell", "Step-up", "glutes", "Drive through the top foot; do not push off the floor.", "step up", "step-ups"],
	["Bodyweight Squat", "quads", "bodyweight", "Squat", "glutes", "Arms forward for balance; full depth.", "air squat", "air squats"],
	["Pistol Squat", "quads", "bodyweight", "Squat", "glutes, balance", "One leg; the other held out in front."],
	["Sissy Squat", "quads", "bodyweight", "Squat", "quads only", "Knees travel far forward, hips stay open; hold a post."],
	# --- hamstrings ----------------------------------------------------------
	["Romanian Deadlift", "hamstrings", "barbell", "Hinge", "glutes, lower back", "Soft knees, hips back, bar slides down the thighs."],
	["Stiff-Leg Deadlift", "hamstrings", "barbell", "Hinge", "lower back, glutes", "Straighter legs than an RDL; from the floor.", "stiff leg deadlift", "straight leg deadlift"],
	["Dumbbell Romanian Deadlift", "hamstrings", "dumbbell", "Hinge", "glutes", "Bells close to your legs; feel the stretch.", "dumbbell rdl", "db rdl"],
	["Single-Leg Romanian Deadlift", "hamstrings", "dumbbell", "Hinge", "glutes, balance", "Hinge on one leg; hips stay square.", "single leg rdl", "single-leg rdl"],
	["Good Morning", "hamstrings", "barbell", "Hinge", "lower back, glutes", "Bar on your back; bow with a flat back."],
	["Lying Leg Curl", "hamstrings", "machine", "Leg curl", "calves", "Hips down on the pad; curl all the way.", "leg curl", "hamstring curl"],
	["Seated Leg Curl", "hamstrings", "machine", "Leg curl", "calves", "Lean forward a little for a bigger stretch."],
	["Nordic Curl", "hamstrings", "bodyweight", "Leg curl", "glutes", "Anchor your feet; lower as slowly as you can.", "nordic hamstring curl", "nordics"],
	["Glute-Ham Raise", "hamstrings", "bodyweight", "Leg curl", "glutes, lower back", "On the GHD: curl yourself up with the hamstrings.", "ghr", "glute ham raise"],
	["Kettlebell Swing", "hamstrings", "kettlebell", "Hinge", "glutes, core", "It is a hinge, not a squat; snap the hips."],
	# --- glutes --------------------------------------------------------------
	["Hip Thrust", "glutes", "barbell", "Thrust", "hamstrings", "Shoulders on a bench, chin tucked, lock out the hips."],
	["Glute Bridge", "glutes", "bodyweight", "Thrust", "hamstrings", "On the floor; squeeze at the top."],
	["Single-Leg Hip Thrust", "glutes", "bodyweight", "Thrust", "hamstrings", "One foot down, the other knee up.", "single leg hip thrust"],
	["Cable Pull-Through", "glutes", "cable", "Hinge", "hamstrings", "Rope between your legs; hinge and stand tall.", "pull through", "pull-through"],
	["Cable Kickback", "glutes", "cable", "Kickback", "hamstrings", "Ankle strap; kick straight back without arching.", "glute kickback"],
	["Hip Abduction", "glutes", "machine", "Abduction", "outer hip", "Lean forward a little; push the knees out.", "abductor machine", "hip abductor"],
	["Hip Adduction", "glutes", "machine", "Adduction", "inner thigh", "Squeeze the pads together; control the way out.", "adductor machine", "hip adductor"],
	["Banded Lateral Walk", "glutes", "band", "Abduction", "outer hip", "Band above the knees; stay low and step sideways.", "band walk", "monster walk"],
	# --- calves --------------------------------------------------------------
	["Calf Raise", "calves", "barbell", "Calf raise", "soleus", "Full stretch at the bottom, pause on your toes.", "standing calf raise", "heel raise", "heel raises", "calf raises"],
	["Seated Calf Raise", "calves", "machine", "Calf raise", "soleus", "Bent knees work the deeper calf muscle."],
	["Leg Press Calf Raise", "calves", "machine", "Calf raise", "soleus", "Toes on the edge of the sled; press through the ball of the foot."],
	["Single-Leg Calf Raise", "calves", "bodyweight", "Calf raise", "balance", "One foot on a step; hold a bell to load it.", "single leg calf raise"],
	["Donkey Calf Raise", "calves", "machine", "Calf raise", "soleus", "Hinged over with the load on your hips."],
	["Tibialis Raise", "calves", "bodyweight", "Shin", "front of the shin", "Back against a wall, heels out; lift your toes.", "tib raise"],
	# --- core ----------------------------------------------------------------
	["Plank", "core", "bodyweight", "Hold", "shoulders, glutes", "One straight line; squeeze everything."],
	["Side Plank", "core", "bodyweight", "Hold", "obliques", "Elbow under the shoulder, hips high."],
	["Crunch", "core", "bodyweight", "Crunch", "upper abs", "Ribs toward hips; the lower back stays down.", "crunches"],
	["Sit-up", "core", "bodyweight", "Crunch", "hip flexors", "Feet anchored; all the way up.", "sit up", "situps", "sit-ups"],
	["Decline Sit-up", "core", "bodyweight", "Crunch", "hip flexors", "On a decline bench; hold a plate to load it."],
	["Cable Crunch", "core", "cable", "Crunch", "abs", "Kneel, rope by your head, curl the spine down."],
	["Machine Crunch", "core", "machine", "Crunch", "abs", "Curl, do not just hinge at the hips.", "ab machine"],
	["Hanging Leg Raise", "core", "bodyweight", "Leg raise", "hip flexors, grip", "From a dead hang, straight legs to the bar height you can control."],
	["Hanging Knee Raise", "core", "bodyweight", "Leg raise", "hip flexors, grip", "Knees to chest; no swinging.", "knee raise", "knee raises"],
	["Lying Leg Raise", "core", "bodyweight", "Leg raise", "hip flexors", "Lower back pressed down; lower the legs slowly.", "leg raise", "leg raises"],
	["Toes-to-Bar", "core", "bodyweight", "Leg raise", "lats, grip", "Hang and bring your toes to touch the bar.", "toes to bar", "t2b"],
	["Ab Wheel Rollout", "core", "other", "Rollout", "lats, shoulders", "Roll out as far as you can without the hips sagging.", "ab wheel", "ab rollout", "rollout"],
	["Russian Twist", "core", "bodyweight", "Rotation", "obliques", "Lean back, feet up, rotate side to side."],
	["Woodchop", "core", "cable", "Rotation", "obliques", "Pull across your body from high to low.", "cable woodchop", "wood chop"],
	["Pallof Press", "core", "cable", "Anti-rotation", "obliques", "Press straight out and do not let the cable turn you."],
	["Dead Bug", "core", "bodyweight", "Anti-extension", "deep abs", "Opposite arm and leg reach away; back stays flat."],
	["Dragon Flag", "core", "bodyweight", "Leg raise", "whole core", "Shoulders on the bench, body rigid, lower slowly."],
	["L-Sit", "core", "bodyweight", "Hold", "hip flexors, triceps", "Support on bars, legs straight out in front.", "l sit"],
	["Suitcase Carry", "core", "dumbbell", "Carry", "obliques, grip", "One heavy bell at your side; do not lean."],
	# --- full body -----------------------------------------------------------
	["Power Clean", "full", "barbell", "Olympic", "hips, traps, legs", "Jump the bar up and catch it on your shoulders in a quarter squat."],
	["Clean", "full", "barbell", "Olympic", "hips, traps, legs", "Like a power clean, caught in a full squat.", "squat clean"],
	["Hang Clean", "full", "barbell", "Olympic", "hips, traps", "Start from above the knees."],
	["Clean and Jerk", "full", "barbell", "Olympic", "everything", "Clean it, then dip and drive it overhead.", "clean & jerk", "c&j"],
	["Snatch", "full", "barbell", "Olympic", "everything", "Wide grip, floor to overhead in one move.", "squat snatch"],
	["Power Snatch", "full", "barbell", "Olympic", "hips, shoulders", "Snatch caught high, above a parallel squat."],
	["Overhead Squat", "full", "barbell", "Squat", "shoulders, core, quads", "Bar locked out overhead with a wide grip; squat under it."],
	["Thruster", "full", "barbell", "Squat", "quads, shoulders", "Front squat straight into a press.", "thrusters"],
	["Dumbbell Snatch", "full", "dumbbell", "Olympic", "hips, shoulders", "One bell from the floor to overhead in one pull.", "db snatch"],
	["Kettlebell Clean", "full", "kettlebell", "Olympic", "hips, grip", "Swing and zip the bell up into the rack position.", "kb clean"],
	["Kettlebell Snatch", "full", "kettlebell", "Olympic", "hips, shoulders", "Swing to overhead and punch through at the top.", "kb snatch"],
	["Turkish Get-up", "full", "kettlebell", "Get-up", "shoulders, core", "From lying to standing with the bell locked out overhead.", "turkish get up", "tgu", "get-up"],
	["Muscle-up", "full", "bodyweight", "Pull-up", "lats, chest, triceps", "Pull high and turn over into a dip.", "muscle up"],
	["Burpee", "full", "bodyweight", "Conditioning", "everything", "Chest to the floor, jump up, repeat.", "burpees"],
	["Sled Push", "full", "other", "Conditioning", "quads, glutes", "Low handles, lean in, drive with short steps.", "prowler", "sled"],
]


## Names a catalog row answers to, normalized.
static func _keys_of(row: Array) -> Array:
	var keys = [Xp.normalize_exercise(row[0])]
	for i in range(6, row.size()):
		var k = Xp.normalize_exercise(row[i])
		if not keys.has(k):
			keys.append(k)
	return keys


static func part_name(id: String) -> String:
	for p in PARTS:
		if p.id == id:
			return p.name
	return id


static func equip_name(id: String) -> String:
	for e in EQUIPMENT:
		if e.id == id:
			return e.name
	return id


## The catalog as entries (no history attached).
static func catalog() -> Array:
	var out = []
	for row in LIFTS:
		out.append({"name": row[0], "part": row[1], "equip": row[2], "family": row[3], "also": row[4], "tip": row[5], "keys": _keys_of(row), "own": false})
	return out


## What the player has logged, per normalized exercise name.
static func stats(sessions: Array) -> Dictionary:
	var lifts = sessions.filter(func(x): return x.discipline == "lift")
	TTUtil.stable_sort(lifts, func(a, b): return a.date > b.date or (a.date == b.date and a.createdAt > b.createdAt))
	var out = {}
	for x in lifts:
		for ex in x.get("exercises", []):
			var key = Xp.normalize_exercise(ex.name)
			var done = []
			for one in ex.get("sets", []):
				if int(one.get("reps", 0)) > 0:
					done.append({"reps": int(one.reps), "weightKg": float(one.get("weightKg", 0))})
			if key == "" or done.is_empty():
				continue
			if not out.has(key):
				out[key] = {"name": str(ex.name).strip_edges(), "count": 0, "last": x.date, "bestKg": 0.0, "bestReps": 0, "e1rm": 0.0, "bwReps": 0, "volumeKg": 0.0, "reps": 0, "history": []}
			var st = out[key]
			st.count += 1
			st.history.append({"date": x.date, "id": x.id, "sets": done})
			for one in done:
				st.reps += one.reps
				st.volumeKg += one.reps * one.weightKg
				if one.weightKg > 0.0:
					if one.weightKg > st.bestKg + 1e-9 or (absf(one.weightKg - st.bestKg) <= 1e-9 and one.reps > st.bestReps):
						st.bestKg = one.weightKg
						st.bestReps = one.reps
					st.e1rm = maxf(st.e1rm, Xp.e1rm(one.weightKg, one.reps))
				else:
					st.bwReps = maxi(st.bwReps, one.reps)
	return out


## Several names for one lift ("calf raise", "heel raise") read as one history.
static func merge_stats(keys: Array, all: Dictionary):
	var found = []
	for k in keys:
		if all.has(k):
			found.append(all[k])
	if found.is_empty():
		return null
	if found.size() == 1:
		return found[0]
	var m = {"name": "", "count": 0, "last": "", "bestKg": 0.0, "bestReps": 0, "e1rm": 0.0, "bwReps": 0, "volumeKg": 0.0, "reps": 0, "history": []}
	for st in found:
		m.count += st.count
		m.reps += st.reps
		m.volumeKg += st.volumeKg
		m.e1rm = maxf(m.e1rm, st.e1rm)
		m.bwReps = maxi(m.bwReps, st.bwReps)
		if st.bestKg > m.bestKg + 1e-9 or (absf(st.bestKg - m.bestKg) <= 1e-9 and st.bestReps > m.bestReps):
			m.bestKg = st.bestKg
			m.bestReps = st.bestReps
		if str(st.last) > str(m.last):
			m.last = st.last
			m.name = st.name
		m.history.append_array(st.history)
	TTUtil.stable_sort(m.history, func(a, b): return a.date > b.date)
	return m


## A guess at the body part of a lift the catalog does not know, from its name.
static func guess_part(key: String) -> String:
	var rules = [
		["curl", "biceps"], ["tricep", "triceps"], ["pushdown", "triceps"], ["calf", "calves"], ["squat", "quads"],
		["lunge", "quads"], ["deadlift", "back"], ["row", "back"], ["pulldown", "back"], ["pull-up", "back"],
		["bench", "chest"], ["fly", "chest"], ["push-up", "chest"], ["press", "shoulders"], ["raise", "shoulders"],
		["thrust", "glutes"], ["bridge", "glutes"], ["crunch", "core"], ["plank", "core"], ["twist", "core"],
	]
	for r in rules:
		if key.contains(r[0]):
			return r[1]
	return "other"


## Every lift to show: the catalog plus anything the player logged that it does
## not know, each with "st" (merged stats, or null when never done).
static func rows(sessions: Array) -> Array:
	var all = stats(sessions)
	var out = []
	var claimed = {}
	for e in catalog():
		for k in e.keys:
			claimed[k] = true
		e["st"] = merge_stats(e.keys, all)
		out.append(e)
	for key in all:
		if claimed.has(key):
			continue
		var st = all[key]
		out.append({"name": st.name, "part": guess_part(key), "equip": "other", "family": "Your own", "also": "", "tip": "One of your own lifts: not in the library, so it has no notes.", "keys": [key], "own": true, "st": st})
	return out


static func _part_index(id: String) -> int:
	for i in range(PARTS.size()):
		if PARTS[i].id == id:
			return i
	return PARTS.size()


static func _equip_index(id: String) -> int:
	for i in range(EQUIPMENT.size()):
		if EQUIPMENT[i].id == id:
			return i
	return EQUIPMENT.size()


static func _matches(e: Dictionary, words: Array) -> bool:
	var hay = " ".join(PackedStringArray([str(e.name), " ".join(PackedStringArray(e.keys)), part_name(e.part), equip_name(e.equip), str(e.family), str(e.also)])).to_lower()
	for w in words:
		if not hay.contains(w):
			return false
	return true


## Filter and sort rows. opts = {"q": search text, "part": id or "", "equip": id or "",
## "show": "all" | "mine" | "new", "sort": one of SORTS}.
static func query(all_rows: Array, opts: Dictionary) -> Array:
	var words = []
	for w in str(opts.get("q", "")).to_lower().split(" ", false):
		words.append(w)
	var part = str(opts.get("part", ""))
	var equip = str(opts.get("equip", ""))
	var show = str(opts.get("show", "all"))
	var out = []
	for e in all_rows:
		if part != "" and e.part != part:
			continue
		if equip != "" and e.equip != equip:
			continue
		if show == "mine" and e.st == null:
			continue
		if show == "new" and e.st != null:
			continue
		if not words.is_empty() and not _matches(e, words):
			continue
		out.append(e)
	var by_name = func(a, b): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0
	TTUtil.stable_sort(out, by_name)
	match str(opts.get("sort", "part")):
		"part":
			TTUtil.stable_sort(out, func(a, b):
				var pa = _part_index(a.part)
				var pb = _part_index(b.part)
				if pa != pb:
					return pa < pb
				if str(a.family) != str(b.family):
					return str(a.family) < str(b.family)
				return _equip_index(a.equip) < _equip_index(b.equip))
		"count":
			TTUtil.stable_sort(out, func(a, b): return (int(a.st.count) if a.st != null else 0) > (int(b.st.count) if b.st != null else 0))
		"best":
			TTUtil.stable_sort(out, func(a, b): return (float(a.st.bestKg) if a.st != null else -1.0) > (float(b.st.bestKg) if b.st != null else -1.0))
		"recent":
			TTUtil.stable_sort(out, func(a, b): return (str(a.st.last) if a.st != null else "") > (str(b.st.last) if b.st != null else ""))
	return out


## The heaviest weight lifted for at least 1, 3, 5, 8, 10 and 12 reps:
## [{"reps": r, "kg": weight}] for the marks that have one.
static func rep_bests(st: Dictionary) -> Array:
	var out = []
	for r in REP_MARKS:
		var best = 0.0
		for h in st.history:
			for one in h.sets:
				if one.reps >= r and one.weightKg > best:
					best = one.weightKg
		if best > 0.0:
			out.append({"reps": r, "kg": best})
	return out


## Other lifts of the same family (the variations to try), same body part first.
static func variations(e: Dictionary, all_rows: Array) -> Array:
	var out = []
	for o in all_rows:
		if o.name != e.name and not o.own and o.family == e.family and (o.part == e.part or e.family == "Bench press" or e.family == "Squat" or e.family == "Curl"):
			out.append(o)
	TTUtil.stable_sort(out, func(a, b): return (0 if a.part == e.part else 1) < (0 if b.part == e.part else 1))
	return out
