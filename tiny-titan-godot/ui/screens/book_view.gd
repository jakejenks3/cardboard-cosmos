class_name BookView
extends RefCounted
## Books on screen (game/books.gd): the book being read on the Hero tab's
## reading card (type the page you stopped on, the app works out the pages),
## and in the reading sheet the books being read, the bookshelf of finished
## books, a form to add one and a box to paste several at once; a book's own
## sheet to change or finish it.

## What the add form holds while it is typed (the sheet is rebuilt on changes).
static var _title: String = ""
static var _author: String = ""
static var _pages: String = ""
static var _at: String = ""
static var _paste: String = ""
static var _show_paste: bool = false


# ---------------------------------------------------------------------------
# The book being read
# ---------------------------------------------------------------------------

## "p. 249 of 1,232" (or "p. 249").
static func where_words(b: Dictionary) -> String:
	if int(b.pages) > 0:
		return "p. %s of %s" % [Xp.fmt_int(int(b.page)), Xp.fmt_int(int(b.pages))]
	return "p. %s" % Xp.fmt_int(int(b.page))


## The title and its series as a tag, in a row that cuts the title short when tight.
static func title_row(b: Dictionary, size: int = 13) -> Control:
	var top = Kit.squeeze(6)
	top.add_child(Kit.soft_name(str(b.title), size, null, true, 260.0))
	var sl = Books.series_label(b)
	if sl != "":
		top.add_child(SessionView.variation_tag(sl, 10, true))
	return top


## The progress line: a bar through the book and where the bookmark is.
static func progress_row(b: Dictionary) -> Control:
	var row = Kit.hbox(8)
	if int(b.pages) > 0:
		row.add_child(Kit.vcenter(Kit.bar(Books.progress(b), Pal.READ, 6)))
	var w = Kit.label(where_words(b), 12, Pal.READ, true)
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if int(b.pages) <= 0:
		w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(w)
	return row


## "Stopped on page [   ] Save": typing the page and Done (or Save) works out
## today's pages of the book.
static func page_row(b: Dictionary) -> Control:
	var row = Kit.hbox(6)
	var l = Kit.label("Stopped on page", 12, Pal.MUTED, true)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var box = Kit.input("", str(int(b.page)), true)
	box.custom_minimum_size = Vector2(84, 38)
	box.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.max_length = 5
	box.tooltip_text = "The page you stopped on: the pages since your last one are counted"
	box.set_meta("book_page_box", str(b.id))
	row.add_child(box)
	var save = Kit.button("Save", "primary", Callable(), "sm")
	save.set_meta("book_page_save", str(b.id))
	save.pressed.connect(func(): BookView.save_page(str(b.id), box.text, save))
	box.text_submitted.connect(func(t): BookView.save_page(str(b.id), t, save))
	row.add_child(Kit.vcenter(save))
	return row


## What today's reading of the book was, when there was some.
static func today_line(b: Dictionary):
	var n = Books.pages_on(b, App.today)
	if n <= 0:
		return null
	var l = Kit.clip("+%d page%s today (from p. %s)" % [n, "" if n == 1 else "s", Xp.fmt_int(Books.start_of(b, App.today))], 11, Pal.READ, true)
	l.set_meta("book_today", n)
	return l


## The Hero tab's reading card: the book being read and its page box.
static func card_rows(b: Dictionary) -> Control:
	var v = Kit.vbox(4)
	v.set_meta("book_row", str(b.id))
	v.add_child(title_row(b))
	v.add_child(progress_row(b))
	var tl = today_line(b)
	if tl != null:
		v.add_child(tl)
	v.add_child(page_row(b))
	return v


## Save the page typed for a book: today's pages move by what the bookmark
## moved, with the pages and the XP rising from the key; at the book's last
## page it asks whether it is finished.
static func save_page(id: String, text: String, from = null) -> void:
	var t = text.strip_edges().replace(",", "")
	if not t.is_valid_int() or int(t) < 0:
		Sfx.error()
		App.toast("Type the page you stopped on", "bad", "book")
		return
	var b = Books.find(App.books(), id)
	if b == null:
		return
	var page = int(t)
	var title = str(b.title)
	var length = int(b.pages)
	var xp_before = Reading.day_xp(Reading.pages_on(App.state, App.today))
	var at_from = from is Control and is_instance_valid(from)
	var r = App.set_book_page(id, page)
	var got = int(r.get("delta", 0))
	if at_from:
		Kit.burst(from, Pal.READ, 14)
	if got != 0:
		Sfx.claim()
		var xp = Reading.day_xp(int(r.day)) - xp_before
		var words = "%s%d PAGE%s" % ["+" if got > 0 else "", got, "" if absi(got) == 1 else "S"]
		if at_from:
			Kit.floater(from, words, Pal.READ)
			if xp > 0:
				Kit.floater(from, "+%d XP" % xp, Pal.ACCENT, 0.18)
		else:
			App.toast(words.capitalize(), "good", "book")
	else:
		Sfx.tick()
		App.toast("Bookmark at page %s" % Xp.fmt_int(page), "info", "book")
	if length > 0 and page >= length:
		Kit.confirm("Finished %s?" % title, "That is its last page. Put it on your bookshelf?", "Yes, finished", BookView.finish.bind(id), false)


## Put a book on the shelf, with a fanfare.
static func finish(id: String) -> void:
	var b = Books.find(App.books(), id)
	if b == null:
		return
	App.set_book_finished(id, true)
	Sfx.level_up()
	App.toast("On the shelf: %s" % str(b.title), "good", "book")


# ---------------------------------------------------------------------------
# The reading sheet's parts
# ---------------------------------------------------------------------------

## A book being read, in the sheet: everything of the Hero card's row, and
## keys to finish it or change it.
static func reading_card(b: Dictionary) -> Control:
	var c = Kit.card(6, Callable(), 10)
	c.accent(Pal.READ)
	c.set_meta("book_card", str(b.id))
	var head = Kit.hbox(6)
	var t = title_row(b, 14)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var edit = Kit.icon_button("edit", BookView.open_book.bind(str(b.id)), "Change this book", 32)
	head.add_child(Kit.vcenter(edit))
	c.add(head)
	if str(b.author) != "":
		c.add(Kit.clip(str(b.author), 11, Pal.MUTED))
	c.add(progress_row(b))
	var tl = today_line(b)
	if tl != null:
		c.add(tl)
	c.add(page_row(b))
	var fin = Kit.button("Finished it", "good", BookView.finish.bind(str(b.id)), "sm", "check")
	fin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fin.set_meta("book_finish", str(b.id))
	c.add(fin)
	return c


## The bookshelf: the finished books standing on planks, the one being read
## open at the end, and their titles under it (a tap opens a book).
static func shelf_card() -> Control:
	var books = App.books()
	var done = Books.shelf(books)
	var now = Books.reading_now(books)
	var c = Kit.card(6, Callable(), 10)
	c.accent(Pal.READ_DARK)
	c.set_meta("bookshelf", done.size())
	var head = Kit.hbox(6)
	head.add_child(Kit.vcenter(Kit.clip("Bookshelf", 14, null, true)))
	var said = "No books yet"
	if not done.is_empty():
		var pages = Books.shelf_pages(books)
		said = "%d book%s%s" % [done.size(), "" if done.size() == 1 else "s", (" · %s pages" % Xp.fmt_int(pages)) if pages > 0 else ""]
	var sl = Kit.clip(said, 11, Pal.MUTED)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(Kit.vcenter(sl))
	c.add(head)
	var shelf = ReadingView.Shelf.new()
	shelf.setup(done.map(func(b): return Books.spine(b)), Books.progress(now[0]) if not now.is_empty() else 0.0, not now.is_empty())
	c.add(shelf)
	if done.is_empty():
		c.add(Kit.para("Finish a book, or add the ones you have read, and it stands here.", 11, Pal.MUTED))
		return c
	# The titles, newest first.
	var list = Kit.vbox(4)
	var rev = done.duplicate()
	rev.reverse()
	for b in rev:
		list.add_child(_shelf_row(b))
	c.add(list)
	return c


static func _shelf_row(b: Dictionary) -> Control:
	var row = Kit.card(0, BookView.open_book.bind(str(b.id)), 6)
	row.set_meta("shelf_book", str(b.id))
	row.tooltip_text = str(b.title)
	var h = Kit.hbox(8)
	var sw = ColorRect.new()
	sw.color = Books.spine(b).color
	sw.custom_minimum_size = Vector2(8, 22)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sw)
	var v = Kit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.soft_name(str(b.title), 13, null, true, 260.0))
	var bits = []
	if Books.series_label(b) != "":
		bits.append(Books.series_label(b))
	if str(b.author) != "":
		bits.append(str(b.author))
	if int(b.pages) > 0:
		bits.append("%s pages" % Xp.fmt_int(int(b.pages)))
	if str(b.finished) != "":
		bits.append(Dates.format_date(str(b.finished), {"month": "short", "day": "numeric", "year": "numeric"}))
	v.add_child(Kit.clip(" · ".join(PackedStringArray(bits)), 11, Pal.MUTED))
	h.add_child(v)
	Kit.passthrough(h)
	row.add(h)
	return row


## Add a book: its title, author and length, where you are in it, and whether
## you are reading it or read it before. And a box for several at once.
static func add_card() -> Control:
	var c = Kit.card(6, Callable(), 10)
	c.set_meta("book_add", true)
	c.add(Kit.clip("Add a book", 14, null, true))
	var t = Kit.input(_title, "Title")
	t.set_meta("book_add_title", true)
	t.text_changed.connect(func(x): BookView._title = x)
	c.add(t)
	var a = Kit.input(_author, "Author (optional)")
	a.text_changed.connect(func(x): BookView._author = x)
	c.add(a)
	var nums = Kit.hbox(8)
	var p = Kit.input(_pages, "Pages in it", true)
	p.text_changed.connect(func(x): BookView._pages = x)
	nums.add_child(p)
	var at = Kit.input(_at, "On page (0)", true)
	at.text_changed.connect(func(x): BookView._at = x)
	nums.add_child(at)
	c.add(nums)
	var keys = Kit.hbox(8)
	var start = Kit.button("Start reading", "primary", BookView._add_one.bind("reading"), "sm", "book")
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.set_meta("book_add_reading", true)
	keys.add_child(start)
	var read = Kit.button("Already read", "secondary", BookView._add_one.bind("finished"), "sm", "check")
	read.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	read.set_meta("book_add_finished", true)
	keys.add_child(read)
	c.add(keys)
	var more = LogWidgets.mini_chip(("▾ " if _show_paste else "+ ") + "Add several at once", _show_paste, BookView._toggle_paste)
	more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	more.set_meta("book_paste_toggle", true)
	c.add(more)
	if _show_paste:
		c.add(Kit.para("One book after another, split by ;  as  Title | Author | Series 1 | 541 pages. Add | reading, page 249 to the one you are on.", 11, Pal.MUTED))
		var box = Kit.input(_paste, "Paste your books here")
		box.select_all_on_focus = false
		box.set_meta("book_paste", true)
		box.text_changed.connect(func(x): BookView._paste = x)
		c.add(box)
		var go = Kit.button("Add these books", "primary", BookView._add_pasted, "sm")
		go.set_meta("book_paste_add", true)
		c.add(go)
	return c


static func _toggle_paste() -> void:
	Sfx.tick()
	_show_paste = not _show_paste
	App.changed.emit()


static func _add_one(status: String) -> void:
	if Books.clean(_title) == "":
		Sfx.error()
		App.toast("Type the book's title first", "bad", "book")
		return
	var pages = int(_pages) if _pages.strip_edges().is_valid_int() else 0
	var at = int(_at) if _at.strip_edges().is_valid_int() else 0
	var n = App.add_books([{"title": _title, "author": _author, "pages": pages, "status": status, "page": at if status == "reading" else 0}])
	if n == 0:
		App.toast("%s is on your list already" % Books.clean(_title), "info", "book")
		return
	Sfx.claim()
	App.toast(("Reading: %s" if status == "reading" else "On the shelf: %s") % Books.clean(_title), "good", "book")
	_title = ""
	_author = ""
	_pages = ""
	_at = ""
	App.changed.emit()


static func _add_pasted() -> void:
	var items = Books.parse_list(_paste)
	if items.is_empty():
		Sfx.error()
		App.toast("No books in that: Title | Author | 500 pages ; next book", "bad", "book")
		return
	var n = App.add_books(items)
	Sfx.claim()
	var skipped = items.size() - n
	App.toast("Added %d book%s%s" % [n, "" if n == 1 else "s", (", %d already there" % skipped) if skipped > 0 else ""], "good", "book")
	_paste = ""
	_show_paste = false
	App.changed.emit()


# ---------------------------------------------------------------------------
# A book's own sheet
# ---------------------------------------------------------------------------

static func open_book(id: String) -> void:
	var b = Books.find(App.books(), id)
	if b == null:
		return
	Sfx.tap()
	var sh = Kit.sheet(str(b.title))
	sh.box.set_meta("book_sheet", id)
	var fields = {}
	var add_field = func(label: String, key: String, value: String, numeric: bool):
		var e = Kit.input(value, label, numeric)
		fields[key] = e
		sh.box.add_child(Kit.field(label, e))
	add_field.call("Title", "title", str(b.title), false)
	add_field.call("Author", "author", str(b.author), false)
	var srow = Kit.hbox(8)
	var se = Kit.input(str(b.series), "Series")
	var ne = Kit.input(str(int(b.num)) if int(b.num) > 0 else "", "No.", true)
	ne.custom_minimum_size.x = 72
	ne.size_flags_horizontal = Control.SIZE_SHRINK_END
	fields["series"] = se
	fields["num"] = ne
	srow.add_child(se)
	srow.add_child(ne)
	sh.box.add_child(Kit.field("Series and its number", srow))
	add_field.call("Pages in it (your copy)", "pages", str(int(b.pages)) if int(b.pages) > 0 else "", true)
	if str(b.status) == "reading":
		add_field.call("Bookmark: the page you are on (moves no pages)", "page", str(int(b.page)), true)
	var save = Kit.button("Save changes", "primary", func():
		var f = {}
		for k in ["title", "author", "series"]:
			f[k] = fields[k].text
		for k in ["num", "pages", "page"]:
			if fields.has(k):
				var tx = str(fields[k].text).strip_edges().replace(",", "")
				f[k] = int(tx) if tx.is_valid_int() else 0
		App.update_book(id, f)
		Sfx.claim()
		App.toast("Saved", "good", "book")
		sh.close(), "lg")
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.set_meta("book_save", id)
	sh.box.add_child(save)
	var row = Kit.hbox(8)
	if str(b.status) == "reading":
		var fin = Kit.button("Finished it", "good", func():
			sh.close()
			BookView.finish(id), "md", "check")
		fin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(fin)
	else:
		var again = Kit.button("Reading it again", "secondary", func():
			App.set_book_finished(id, false)
			Sfx.tick()
			sh.close(), "md", "book")
		again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(again)
	var rm = Kit.button("Remove", "ghost", func():
		Kit.confirm("Remove %s?" % str(b.title), "It comes off your list. Pages you logged with it stay in your reading.", "Remove", func():
			App.remove_book(id)
			sh.close()), "md", "trash")
	rm.set_meta("book_remove", id)
	row.add_child(rm)
	sh.box.add_child(row)
	sh.open()
