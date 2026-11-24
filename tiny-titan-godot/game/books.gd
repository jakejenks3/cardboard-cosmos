class_name Books
extends RefCounted
## Books: the shelf of finished books and the book being read, with its
## bookmark (the user, 2026-11-23: "create a bookshelf with my finished books.
## And to not have to figure out the number of pages each day, just putting
## the page number I finished on when I do read and have the app do the math").
##
## STORED: saved.books = [{"id", "title", "author", "series", "num" (its number
## in the series, 0 none), "pages" (the book's length, 0 unknown), "status"
## ("reading" | "finished"), "finished" (the day it was finished, "" unknown),
## "page" (the bookmark: the last page reached), "log" ({day: [from, to]}: the
## page a day's reading started on and the page it ended on), "at" (added, ms)}].
## Nothing in the rules reads it.
##
## THE PAGE MATH (set_page): the page typed is where the reading stopped. A
## day's pages of a book are `to - from`, `from` being the bookmark as the day
## began (the page it stood on before the first entry of the day). Typing the
## page again the same day replaces that day's end, so a correction is a
## correction, not more pages. What changes goes into the day's reading
## (App.add_reading): XP, the level, the streak work as for any pages.
##
## Books added as finished (read before the game) add no pages to the log:
## they are on the shelf, their pages are only said.

const STATUSES = ["reading", "finished"]
const MAX_TITLE = 120
## A page number no book has.
const MAX_PAGE = 20000
## A book's spine on the shelf (art pixels): narrowest and widest, by its length.
const SPINE_MIN = 3
const SPINE_MAX = 6
## Series colours (a series keeps its colour; its books are lighter or darker).
const COLORS = ["#e2574c", "#3d9bff", "#23c29b", "#ffb21f", "#a66bff", "#f272b8", "#8fd14f", "#ff8a3d", "#5ad1e6", "#c9a36b"]


static func clean(text) -> String:
	return str(text).replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().left(MAX_TITLE)


static func _int(v, fallback: int = 0) -> int:
	if v is int or v is float:
		return int(v)
	if v is String and v.strip_edges().is_valid_int():
		return int(v.strip_edges())
	return fallback


## A new book. `page`: the bookmark (0 = not started).
static func new_book(title: String, author: String = "", series: String = "", num: int = 0, pages: int = 0, status: String = "reading", page: int = 0, now_ms: int = 0, finished: String = "") -> Dictionary:
	return {"id": Rng.uid("bk"), "title": clean(title), "author": clean(author), "series": clean(series), "num": clampi(num, 0, 999),
		"pages": clampi(pages, 0, MAX_PAGE), "status": status if STATUSES.has(status) else "reading", "finished": finished,
		"page": clampi(page, 0, MAX_PAGE), "log": {}, "at": now_ms}


## The saved list, cleaned (anything that is not a book with a title is left out).
static func parse(raw) -> Array:
	var out = []
	if not (raw is Array):
		return out
	for b in raw:
		if not (b is Dictionary) or not (b.get("id") is String) or clean(b.get("title", "")) == "":
			continue
		var log = {}
		if b.get("log") is Dictionary:
			for d in b.log:
				var span = b.log[d]
				if span is Array and span.size() == 2 and str(d).length() == 10:
					log[str(d)] = [_int(span[0]), _int(span[1])]
		out.append({"id": str(b.id), "title": clean(b.title), "author": clean(b.get("author", "")), "series": clean(b.get("series", "")),
			"num": clampi(_int(b.get("num", 0)), 0, 999), "pages": clampi(_int(b.get("pages", 0)), 0, MAX_PAGE),
			"status": str(b.get("status", "reading")) if STATUSES.has(str(b.get("status", ""))) else "reading",
			"finished": str(b.get("finished", "")), "page": clampi(_int(b.get("page", 0)), 0, MAX_PAGE), "log": log, "at": _int(b.get("at", 0))})
	return out


## A key that says two books are the same one (title and author, any case).
static func key(title: String, author: String = "") -> String:
	return (clean(title) + "|" + clean(author)).to_lower().replace(" ", "")


static func find(books: Array, id: String):
	for b in books:
		if str(b.id) == id:
			return b
	return null


## "Road Saga 4", "Road Saga" (no number), or "".
static func series_label(b: Dictionary) -> String:
	if str(b.series) == "":
		return ""
	return str(b.series) + ((" %d" % int(b.num)) if int(b.num) > 0 else "")


## 0..1 through the book (0 when its length is not known).
static func progress(b: Dictionary) -> float:
	if int(b.pages) <= 0:
		return 0.0
	return clampf(float(b.page) / float(b.pages), 0.0, 1.0)


## The pages of a book read on a day.
static func pages_on(b: Dictionary, day: String) -> int:
	var span = b.log.get(day)
	return maxi(0, int(span[1]) - int(span[0])) if span is Array else 0


## The page a day's reading of the book started on: the end of the last day
## before it, else where the bookmark stood when nothing was read yet.
static func start_of(b: Dictionary, day: String) -> int:
	var span = b.log.get(day)
	if span is Array:
		return int(span[0])
	return int(b.page)


## The book with the bookmark at `page` on `day`: {"book" (a new copy),
## "delta" (what the day's pages of it changed by; negative for a correction
## downwards), "pages" (the day's pages of it now)}.
static func set_page(b: Dictionary, page: int, day: String) -> Dictionary:
	var out = b.duplicate(true)
	var p = clampi(page, 0, MAX_PAGE)
	var from = start_of(b, day)
	var before = pages_on(b, day)
	out.log[day] = [from, p]
	out.page = p
	var now = pages_on(out, day)
	return {"book": out, "delta": now - before, "pages": now}


## The books being read, the one read last first.
static func reading_now(books: Array) -> Array:
	var out = books.filter(func(b): return str(b.status) == "reading")
	out.sort_custom(func(a, b):
		var la = _last_day(a)
		var lb = _last_day(b)
		if la != lb:
			return la > lb
		return int(a.at) > int(b.at))
	return out


static func _last_day(b: Dictionary) -> String:
	var last = ""
	for d in b.log:
		if str(d) > last:
			last = str(d)
	return last


## The finished books in shelf order: the ones read before the game first (in
## the order they were added), then by the day they were finished.
static func shelf(books: Array) -> Array:
	var out = books.filter(func(b): return str(b.status) == "finished")
	out.sort_custom(func(a, b):
		if str(a.finished) != str(b.finished):
			return str(a.finished) < str(b.finished)
		return int(a.at) < int(b.at))
	return out


## The pages of the finished books (the ones whose length is known).
static func shelf_pages(books: Array) -> int:
	var n = 0
	for b in shelf(books):
		n += int(b.pages)
	return n


## A book's spine: {"w", "h" (art pixels), "color"}: thicker for a longer
## book, the colour of its series (lighter for a later book of it).
static func spine(b: Dictionary) -> Dictionary:
	var pages = int(b.pages) if int(b.pages) > 0 else 400
	var w = clampi(SPINE_MIN + int(floor((pages - 300) / 250.0)), SPINE_MIN, SPINE_MAX)
	var group = str(b.series) if str(b.series) != "" else str(b.title)
	var base = Color(COLORS[Rng.hash_string("series:" + group.to_lower()) % COLORS.size()])
	var shade = (int(b.num) % 4) * 0.08 if int(b.num) > 0 else 0.0
	var h = 12 + Rng.hash_string("tall:" + str(b.title).to_lower()) % 4
	return {"w": w, "h": h, "color": base.lightened(shade)}


## Books typed or pasted as text, one per line or separated by ";":
##   Title | Author | Series 2 | 541 pages
##   Title | Author | Series 4 | 1232 pages | reading, page 249
## Only the title is needed. A book is finished unless it says "reading" or
## a page ("page 249"). Returns [{"title", "author", "series", "num", "pages",
## "status", "page"}].
static func parse_list(text: String) -> Array:
	var out = []
	var items = text.replace("\r", "\n").replace(";", "\n").split("\n", false)
	var pages_rx = RegEx.create_from_string("^(\\d[\\d,]*)\\s*(?:pages?|pp?\\.?)$")
	var page_rx = RegEx.create_from_string("(?:^|\\b)(?:on\\s+)?(?:page|p\\.?)\\s*(\\d[\\d,]*)\\b")
	var series_rx = RegEx.create_from_string("^(.*?\\D)\\s*(?:#|book\\s+|vol\\.?\\s*)?(\\d{1,3})$")
	for item in items:
		var fields = Array(item.split("|")).map(func(f): return clean(f))
		if fields.is_empty() or str(fields[0]) == "":
			continue
		var one = {"title": str(fields[0]), "author": "", "series": "", "num": 0, "pages": 0, "status": "finished", "page": 0}
		for f in fields.slice(1):
			var low = str(f).to_lower()
			if low == "":
				continue
			var m = pages_rx.search(low)
			if m != null:
				one.pages = int(m.get_string(1).replace(",", ""))
				continue
			var pm = page_rx.search(low)
			if pm != null or low.begins_with("reading") or low == "now" or low.begins_with("current"):
				one.status = "reading"
				if pm != null:
					one.page = int(pm.get_string(1).replace(",", ""))
				continue
			if low == "finished" or low == "read" or low == "done":
				one.status = "finished"
				continue
			var sm = series_rx.search(str(f))
			if sm != null and str(one.series) == "":
				one.series = clean(sm.get_string(1))
				one.num = int(sm.get_string(2))
				continue
			if str(one.author) == "":
				one.author = str(f)
			elif str(one.series) == "":
				one.series = str(f)
		out.append(one)
	return out
