class_name ReadingView
extends RefCounted
## Reading (game/reading.gd) on screen: the card on the Hero tab, where one
## tap adds pages (or, with a book being read, the page it stopped on works
## them out: BookView), and the sheet behind it (the book being read, the
## bookshelf of finished books, adding books, the last two weeks, any day's
## pages, the daily goal).

const QUICK = [1, 5, 10, 25]
const DAYS_SHOWN = 14

## The day the sheet is editing (a date key).
static var _date: String = ""
static var _sheet = null
## Set when pages were just added, so the next build can make the number pop.
static var _added_at: int = 0


# ---------------------------------------------------------------------------
# The card on the Hero tab
# ---------------------------------------------------------------------------

## Today's pages in a ring, the reading level, the streak and the quick-add keys.
static func card() -> Control:
	var s = App.state
	var today = App.today
	var goal = Reading.goal(App.settings())
	var pages_today = Reading.pages_on(s, today)
	var lv = Reading.level_of(s)
	var streak = Reading.streak(s)

	var c = Kit.card(8, ReadingView.open, 10)
	c.accent(Pal.READ)
	c.tooltip_text = "Reading. Tap for the bookshelf and other days."

	var top = Kit.hbox(10)
	var ring = Ring.new()
	ring.setup(float(pages_today) / float(maxi(1, goal)), Pal.READ, 52.0, Icons.rect("book", 32))
	top.add_child(Kit.vcenter(ring))

	var main = Kit.vbox(3)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var head = Kit.hbox(6)
	head.add_child(Kit.vcenter(Kit.label("Reading", 15, null, true)))
	head.add_child(Kit.vcenter(Kit.pill("", "LV %d" % int(lv.level), Pal.READ, "", null, 10)))
	if pages_today >= goal:
		head.add_child(Kit.vcenter(Kit.pill("check", "Goal", Pal.GOOD, "", null, 10)))
	main.add_child(head)
	var nums = Kit.hbox(6)
	var big = PixelFont.rect(Xp.fmt_int(pages_today), 3, Pal.READ if pages_today > 0 else Pal.MUTED)
	nums.add_child(Kit.vcenter(big))
	nums.add_child(Kit.vcenter(Kit.muted("of %d pages today" % goal, 12)))
	main.add_child(nums)
	main.add_child(Kit.bar(float(lv.progress), Pal.READ, 4))
	top.add_child(main)

	var fl = Kit.vbox(0)
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var flame = Icons.rect("flame", 32, null if streak > 0 else Pal.LINE)
	if streak > 0:
		Fx.flicker(flame)
		Fx.embers(flame, Pal.ACCENT2, 2)
	fl.add_child(flame)
	var days = PixelFont.rect("%dD" % streak, 2, Pal.ACCENT2 if streak > 0 else Pal.MUTED)
	days.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fl.add_child(days)
	top.add_child(fl)
	c.add(top)

	# A book being read: the page it stopped on works the pages out. Without
	# one, a tap adds pages.
	var now = Books.reading_now(App.books())
	if not now.is_empty():
		c.add(BookView.card_rows(now[0]))
	else:
		var keys = Kit.hbox(6)
		for n in QUICK:
			var b = Kit.button("+%d" % n, "ghost", Callable(), "sm")
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.tooltip_text = "Add %d page%s to today" % [n, "" if n == 1 else "s"]
			b.pressed.connect(ReadingView.add.bind(n, "", b))
			keys.add_child(b)
		c.add(keys)
	Kit.passthrough(top)
	if Time.get_ticks_msec() - _added_at < 400:
		big.ready.connect(Kit.pop.bind(big, 1.25, 0.3), CONNECT_DEFERRED)
	return c


## Add pages to a day ("" = today) with sparks and a line saying what it paid.
static func add(n: int, date: String = "", from = null) -> void:
	var day = App.today if date == "" else date
	var before = Reading.pages_on(App.state, day)
	var xp_before = Reading.day_xp(before)
	if from is Control and is_instance_valid(from):
		Kit.burst(from, Pal.READ, 14)
	_added_at = Time.get_ticks_msec()
	var now = App.add_reading(n, day)
	var got = now - before
	if got == 0:
		return
	Sfx.claim()
	var xp = Reading.day_xp(now) - xp_before
	# What it paid rises from the key: no toast to wait out between taps.
	if from is Control and is_instance_valid(from):
		Kit.floater(from, "%s%d PAGE%s" % ["+" if got > 0 else "", got, "" if absi(got) == 1 else "S"], Pal.READ)
		if xp > 0:
			Kit.floater(from, "+%d XP" % xp, Pal.ACCENT, 0.18)
	elif got != 0:
		App.toast("%s%d page%s%s" % ["+" if got > 0 else "", got, "" if absi(got) == 1 else "s", ("  ·  +%d XP" % xp) if xp > 0 else ""], "good", "book")
	if got > 0 and xp == 0 and now > Reading.DAILY_XP_PAGES and before <= Reading.DAILY_XP_PAGES:
		App.toast("That is the day's reading XP: pages past %d still count for your level" % Reading.DAILY_XP_PAGES, "info", "book")


# ---------------------------------------------------------------------------
# The sheet
# ---------------------------------------------------------------------------

static func open() -> void:
	if _sheet != null and is_instance_valid(_sheet):
		return
	_date = App.today
	var sheet = Kit.sheet("Reading")
	_sheet = sheet
	_fill(sheet.box)
	if not App.changed.is_connected(ReadingView._refresh):
		App.changed.connect(ReadingView._refresh)
	sheet.closed.connect(ReadingView._closed)
	sheet.open()


static func _closed() -> void:
	_sheet = null
	if App.changed.is_connected(ReadingView._refresh):
		App.changed.disconnect(ReadingView._refresh)


static func _refresh() -> void:
	if _sheet == null or not is_instance_valid(_sheet):
		_closed()
		return
	Kit.clear(_sheet.box)
	_fill(_sheet.box)


static func _pick_day(date: String) -> void:
	if date > App.today:
		return
	_date = date
	Sfx.tick()
	_refresh()


static func _set_goal(n: int) -> void:
	App.update_settings({"readingGoal": clampi(n, 1, 500)})


static func _set_exact(text: String, date: String) -> void:
	var t = text.strip_edges()
	if not t.is_valid_int():
		return
	App.set_reading(date, int(t))


static func _fill(box: VBoxContainer) -> void:
	var s = App.state
	var today = App.today
	var goal = Reading.goal(App.settings())
	var lv = Reading.level_of(s)
	var total = Reading.pages(s)

	# --- the numbers: pages, streak, level --------------------------------------
	var tiles = Kit.grid(3, 8)
	tiles.add_child(_tile("book", Xp.fmt_int(total), "pages read", Pal.READ))
	tiles.add_child(_tile("flame" if Reading.streak(s) > 0 else "ember", str(Reading.streak(s)), "day streak (best %d)" % Reading.best_streak(s), Pal.ACCENT2))
	tiles.add_child(_tile("star", str(int(lv.level)), "reading level", Pal.ACCENT))
	box.add_child(tiles)
	var lrow = Kit.hbox(8)
	lrow.add_child(Kit.vcenter(Kit.muted("Lv %d" % int(lv.level), 11)))
	lrow.add_child(Kit.bar(float(lv.progress), Pal.READ, 8))
	lrow.add_child(Kit.vcenter(Kit.muted("%d pages to Lv %d" % [int(lv.toNext) - int(lv.into), int(lv.level) + 1], 11)))
	box.add_child(lrow)

	# --- the books: the one being read, the shelf, adding one ---------------------
	var reading_books = Books.reading_now(App.books())
	if not reading_books.is_empty():
		box.add_child(Kit.section_title("Reading now"))
		for b in reading_books:
			box.add_child(BookView.reading_card(b))
	box.add_child(BookView.shelf_card())
	box.add_child(BookView.add_card())

	# --- one day: its pages and the keys that change them --------------------------
	var day_card = Kit.card(8, Callable(), 10)
	day_card.accent(Pal.READ)
	var nav = Kit.hbox(6)
	nav.add_child(Kit.icon_button("chevron_left", ReadingView._pick_day.bind(Dates.add_days(_date, -1)), "The day before", 34))
	var when = Dates.relative_day(_date, today)
	var dl = Kit.label("%s  ·  %s" % [when, Dates.format_date(_date, {"weekday": "short", "month": "short", "day": "numeric"})] if when != Dates.format_date(_date) else Dates.format_date(_date, {"weekday": "short", "month": "short", "day": "numeric"}), 14, null, true)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(dl)
	var next = Kit.icon_button("chevron_right", ReadingView._pick_day.bind(Dates.add_days(_date, 1)), "The day after", 34)
	next.disabled = _date >= today
	nav.add_child(next)
	day_card.add(nav)
	var on_day = Reading.pages_on(s, _date)
	var num = Kit.hbox(8)
	num.alignment = BoxContainer.ALIGNMENT_CENTER
	num.add_child(Kit.vcenter(PixelFont.rect(Xp.fmt_int(on_day), 5, Pal.READ if on_day > 0 else Pal.MUTED)))
	var cap = Kit.vbox(0)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.add_child(Kit.label("pages", 14, null, true))
	cap.add_child(Kit.muted("+%d XP" % Reading.day_xp(on_day), 11))
	num.add_child(cap)
	day_card.add(num)
	var keys = Kit.hbox(6)
	var minus = Kit.button("-1", "ghost", Callable(), "sm")
	minus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minus.disabled = on_day <= 0
	minus.pressed.connect(ReadingView.add.bind(-1, _date, minus))
	keys.add_child(minus)
	for n in QUICK:
		var b = Kit.button("+%d" % n, "primary" if n == 10 else "ghost", Callable(), "sm")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(ReadingView.add.bind(n, _date, b))
		keys.add_child(b)
	day_card.add(keys)
	var exact = Kit.hbox(8)
	exact.add_child(Kit.vcenter(Kit.muted("Or type the day's pages:", 12)))
	var field = Kit.input("", str(on_day), true)
	field.custom_minimum_size = Vector2(72, 34)
	field.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	field.max_length = 4
	field.text_submitted.connect(ReadingView._set_exact.bind(_date))
	exact.add_child(field)
	var set_b = Kit.button("Set", "ghost", Callable(), "sm")
	set_b.pressed.connect(func(): ReadingView._set_exact(field.text, _date))
	exact.add_child(set_b)
	day_card.add(exact)
	box.add_child(day_card)

	# --- the last two weeks ----------------------------------------------------------
	box.add_child(Kit.section_title("Last two weeks"))
	var bars = DayBars.new()
	bars.setup(s, today, _date, goal)
	bars.picked.connect(ReadingView._pick_day)
	box.add_child(bars)

	# --- the daily goal ----------------------------------------------------------------
	var grow = Kit.hbox(8)
	var gl = Kit.vbox(0)
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gl.add_child(Kit.label("Daily goal", 14, null, true))
	gl.add_child(Kit.muted("%d XP a page for the first %d pages of a day" % [Reading.XP_PER_PAGE, Reading.DAILY_XP_PAGES], 11))
	grow.add_child(gl)
	var less = Kit.button("-5", "ghost", ReadingView._set_goal.bind(goal - 5), "sm")
	less.disabled = goal <= 5
	grow.add_child(Kit.vcenter(less))
	grow.add_child(Kit.vcenter(PixelFont.rect(str(goal), 3, Pal.READ)))
	grow.add_child(Kit.vcenter(Kit.button("+5", "ghost", ReadingView._set_goal.bind(goal + 5 if goal >= 5 else 5), "sm")))
	box.add_child(grow)


static func _tile(icon: String, value: String, caption: String, color: Color) -> Control:
	var c = Kit.card(2, Callable(), 8)
	var ic = Icons.rect(icon, 32)
	c.add(ic)
	var v = Kit.big_number(value, color, 100, 3)
	c.add(v)
	var l = Kit.muted_para(caption, 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add(l)
	return c


# ---------------------------------------------------------------------------
# The bookshelf: one pixel book per hundred pages
# ---------------------------------------------------------------------------

class Shelf:
	extends Control
	## Books stand on planks, left to right; a new plank starts when one is full.
	## The book being read lies open at the end, as filled as it is read.
	## A book is a spine of Books.spine: {"w", "h", "color"}.

	const PXS = 3
	const BOOK_COLORS = ["#e2574c", "#3d9bff", "#23c29b", "#ffb21f", "#a66bff", "#f272b8", "#8fd14f", "#ff8a3d", "#5ad1e6", "#c9a36b"]
	const ROW_H = 20
	const MAX_ROWS = 3

	var _spines: Array = []
	var _part: float = 0.0
	var _open: bool = true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(120, ROW_H * PXS)

	func setup(spines: Array, part: float, open_book: bool = true) -> void:
		_spines = spines
		_part = clampf(part, 0.0, 1.0)
		_open = open_book
		resized.connect(_fit)
		_fit()

	## Width and height of book number `i`, in art pixels: the same book always looks the same.
	static func shape(i: int) -> Vector2i:
		var h = Rng.hash_string("book:%d" % i)
		return Vector2i(3 + (h % 3), 11 + ((h >> 4) % 5))

	func _cols() -> int:
		return maxi(8, int(floor(size.x / float(PXS))))

	## Which plank each book stands on: [[index, x], ...] per row.
	func _rows() -> Array:
		var rows = [[]]
		var x = 1
		var cols = _cols()
		# The open book at the end needs 12 art pixels of the last plank.
		for i in range(_spines.size()):
			var w = int(_spines[i].w) + 1
			if x + w > cols - 1:
				rows.append([])
				x = 1
			rows[rows.size() - 1].append([i, x])
			x += w
		if not _open:
			return rows
		if x + 13 > cols - 1:
			rows.append([])
			x = 1
		rows[rows.size() - 1].append([-1, x])
		return rows

	func _fit() -> void:
		var n = mini(MAX_ROWS, _rows().size())
		custom_minimum_size.y = n * ROW_H * PXS
		queue_redraw()

	func _cell(x: int, y: int, w: int, h: int, c: Color) -> void:
		draw_rect(Rect2(x * PXS, y * PXS, w * PXS, h * PXS), c)

	func _draw() -> void:
		var rows = _rows()
		# Only the newest planks are shown when there are more than fit.
		var first = maxi(0, rows.size() - MAX_ROWS)
		var cols = _cols()
		var wood = Color("8a5a2b")
		for r in range(first, rows.size()):
			var base = (r - first + 1) * ROW_H - 3
			# the plank
			_cell(0, base, cols, 2, wood)
			_cell(0, base, cols, 1, wood.lightened(0.25))
			_cell(0, base + 2, cols, 1, Pal.OUTLINE)
			for b in rows[r]:
				var i = int(b[0])
				var x = int(b[1])
				if i < 0:
					_open_book(x, base)
					continue
				var sz = Vector2i(int(_spines[i].w), int(_spines[i].h))
				var col: Color = _spines[i].color
				var top = base - sz.y
				_cell(x, top, sz.x, sz.y, col)
				_cell(x, top, 1, sz.y, col.lightened(0.3))
				_cell(x + sz.x - 1, top, 1, sz.y, col.darkened(0.3))
				# a band across the spine
				_cell(x, top + 2, sz.x, 1, col.lightened(0.55))
				_cell(x, top + sz.y - 3, sz.x, 1, col.darkened(0.35))
				_cell(x, top - 1, sz.x, 1, Pal.OUTLINE)
				_cell(x + sz.x, top, 1, sz.y, Pal.OUTLINE)

	## The book being read: open, its left page as full of lines as it is read.
	func _open_book(x: int, base: int) -> void:
		var paper = Color("fff6dc")
		var ink = Color("b9a57a")
		var cover = Pal.READ_DARK
		_cell(x, base - 7, 12, 7, cover)
		_cell(x + 1, base - 8, 5, 7, paper)
		_cell(x + 6, base - 8, 5, 7, paper.darkened(0.08))
		_cell(x + 6, base - 8, 1, 7, ink)
		var lines = int(round(_part * 10.0))
		for k in range(lines):
			var page_x = (x + 2) if k < 5 else (x + 7)
			_cell(page_x, base - 7 + (k % 5), 3, 1, ink)


# ---------------------------------------------------------------------------
# The last two weeks as bars
# ---------------------------------------------------------------------------

class DayBars:
	extends Control
	## One bar per day, as tall as the pages read; the goal is a dashed line.
	## A click picks that day.

	signal picked(date)

	const H = 96.0
	const PXS = 2.0

	var _days: Array = []
	var _picked: String = ""
	var _goal: int = 10
	var _today: String = ""

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(200, H)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func setup(s: Dictionary, today: String, picked_date: String, goal: int) -> void:
		_today = today
		_picked = picked_date
		_goal = maxi(1, goal)
		_days = []
		for i in range(ReadingView.DAYS_SHOWN - 1, -1, -1):
			var d = Dates.add_days(today, -i)
			_days.append({"date": d, "pages": Reading.pages_on(s, d)})
		queue_redraw()

	func _col_w() -> float:
		return floor(size.x / float(maxi(1, _days.size())) / PXS) * PXS

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var i = int(floor(event.position.x / maxf(1.0, _col_w())))
			if i >= 0 and i < _days.size():
				accept_event()
				picked.emit(str(_days[i].date))

	func _draw() -> void:
		if _days.is_empty():
			return
		var cw = _col_w()
		var label_h = 16.0
		var plot_h = H - label_h - 6.0
		var top = 0
		for d in _days:
			top = maxi(top, int(d.pages))
		var scale_to = float(maxi(top, int(ceil(float(_goal) * 1.3))))
		var base_y = plot_h + 2.0
		draw_rect(Rect2(0, 0, cw * _days.size(), base_y + 2.0), Pal.WELL)
		for i in range(_days.size()):
			var d = _days[i]
			var x = float(i) * cw
			var is_pick = str(d.date) == _picked
			if is_pick:
				draw_rect(Rect2(x, 0, cw, base_y + 2.0), Pal.with_alpha(Pal.READ, 0.14))
			var h = floor(plot_h * float(d.pages) / scale_to / PXS) * PXS
			if int(d.pages) > 0:
				h = maxf(h, PXS * 2.0)
				var col = Pal.READ if int(d.pages) >= _goal else Pal.READ_DARK
				var bx = x + PXS * 2.0
				var bw = cw - PXS * 4.0
				draw_rect(Rect2(bx - PXS, base_y - h, bw + PXS * 2.0, h), Pal.OUTLINE)
				draw_rect(Rect2(bx, base_y - h + PXS, bw, h - PXS), col)
				draw_rect(Rect2(bx, base_y - h + PXS, PXS, h - PXS), col.lightened(0.35))
				draw_rect(Rect2(bx + bw - PXS, base_y - h + PXS, PXS, h - PXS), col.darkened(0.25))
			var wd = ["M", "T", "W", "T", "F", "S", "S"][Dates.weekday_index(str(d.date))]
			var tc = Pal.ACCENT if str(d.date) == _today else (Pal.TEXT if is_pick else Pal.MUTED)
			draw_string(ThemeDB.fallback_font, Vector2(x, H - 3.0), wd, HORIZONTAL_ALIGNMENT_CENTER, cw, 11, tc)
		# The goal: a dashed line across.
		var gy = floor((base_y - plot_h * float(_goal) / scale_to) / PXS) * PXS
		var gx = 0.0
		while gx < cw * _days.size():
			draw_rect(Rect2(gx, gy, PXS * 3.0, PXS), Pal.with_alpha(Pal.GOOD, 0.8))
			gx += PXS * 6.0
