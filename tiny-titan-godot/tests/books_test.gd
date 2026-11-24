extends SceneTree
## Unit test for game/books.gd and the App commands that keep books: the page
## math (the page typed works out the day's pages, a correction corrects),
## the list typed or pasted, the shelf, and that a save keeps and merges them.
## Made-up books.
##   godot --headless --path . --script res://tests/books_test.gd
## Prints BOOKS: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _init() -> void:
	_run()


func _run() -> void:
	# --- the page math ---------------------------------------------------------------------------
	var b = Books.new_book("The Long Road", "A. Writer", "Road Saga", 4, 1200, "reading", 249, 1000)
	ok(b.page == 249 and b.log.is_empty() and Books.start_of(b, "2026-11-23") == 249 and Books.pages_on(b, "2026-11-23") == 0, "a book started today at page 249: nothing read yet")
	var r = Books.set_page(b, 300, "2026-11-23")
	ok(int(r.delta) == 51 and int(r.pages) == 51 and r.book.page == 300 and r.book.log["2026-11-23"] == [249, 300] and b.page == 249, "stopped on page 300: 51 pages today, the bookmark at 300 (the book passed in is left as it was)", r)
	var r2 = Books.set_page(r.book, 340, "2026-11-23")
	ok(int(r2.delta) == 40 and int(r2.pages) == 91 and r2.book.log["2026-11-23"] == [249, 340], "on again the same day, to 340: 40 more, 91 today", r2)
	var r3 = Books.set_page(r2.book, 330, "2026-11-23")
	ok(int(r3.delta) == -10 and int(r3.pages) == 81, "typed 330 to correct it: 10 fewer, 81 today", r3)
	var r4 = Books.set_page(r3.book, 400, "2026-11-24")
	ok(int(r4.delta) == 70 and r4.book.log["2026-11-24"] == [330, 400] and Books.pages_on(r4.book, "2026-11-23") == 81, "the next day starts where the last one ended: 70", r4.book.log)
	var r5 = Books.set_page(r4.book, 200, "2026-11-25")
	ok(int(r5.delta) == 0 and int(r5.pages) == 0 and r5.book.page == 200, "a page before the bookmark (a slip, or reading back): no pages, the bookmark moves", r5)
	ok(is_equal_approx(Books.progress(r4.book), 400.0 / 1200.0) and is_equal_approx(Books.progress(Books.new_book("No Length")), 0.0), "how far through it is (nothing without a length)")
	ok(Books.series_label(b) == "Road Saga 4" and Books.series_label(Books.new_book("Alone")) == "", "its series and number")

	# --- typed or pasted -------------------------------------------------------------------------
	var text = "First Light | A. Writer | Glow Cycle 1 | 541 pages ; Second Light | A. Writer | Glow Cycle 2 | 1,087 pages ; Moon Book | B. Author | Moon 1 | 561 pp ; The Long Road | A. Writer | Road Saga 4 | 1232 pages | reading, page 249"
	var items = Books.parse_list(text)
	ok(items.size() == 4, "four books, split by ;", items.size())
	ok(items[0] == {"title": "First Light", "author": "A. Writer", "series": "Glow Cycle", "num": 1, "pages": 541, "status": "finished", "page": 0}, "title, author, series and its number, pages; finished unless it says otherwise", items[0])
	ok(items[1].pages == 1087 and items[2].pages == 561 and items[2].series == "Moon", "pages with a comma, pp", [items[1], items[2]])
	ok(items[3].status == "reading" and items[3].page == 249 and items[3].pages == 1232 and items[3].num == 4, "the one being read, on page 249", items[3])
	var lines = Books.parse_list("Just A Title\nAnother | Some One\n\n  ;  | nothing")
	ok(lines.size() == 2 and lines[0].title == "Just A Title" and lines[0].author == "" and lines[1].author == "Some One", "lines work too; only the title is needed; empty ones are left out", lines)
	ok(Books.parse_list("Book | Writer | now on page 12")[0].page == 12 and Books.parse_list("Book | current")[0].status == "reading" and Books.parse_list("Book | p. 30")[0].page == 30, "other ways to say the page")

	# --- the shelf ----------------------------------------------------------------------------------
	var shelf_list = [
		Books.new_book("C", "", "", 0, 300, "finished", 0, 3, "2026-11-20"),
		Books.new_book("A", "", "Saga", 1, 1000, "finished", 0, 1),
		Books.new_book("B", "", "Saga", 2, 700, "finished", 0, 2),
		Books.new_book("D", "", "", 0, 0, "reading", 10, 4),
	]
	ok(Books.shelf(shelf_list).map(func(x): return str(x.title)) == ["A", "B", "C"] and Books.shelf_pages(shelf_list) == 2000, "the shelf: books read before first in the order added, then by the day finished; their pages added up", Books.shelf(shelf_list).map(func(x): return str(x.title)))
	var sa = Books.spine(shelf_list[1])
	var sb = Books.spine(shelf_list[2])
	var sc = Books.spine(shelf_list[0])
	ok(int(sa.w) > int(sc.w) and int(sa.w) <= Books.SPINE_MAX and int(sc.w) >= Books.SPINE_MIN and sa.color.h == sb.color.h, "a longer book has a thicker spine; a series keeps its colour", [sa, sb, sc])
	ok(Books.reading_now(shelf_list).map(func(x): return str(x.title)) == ["D"], "the book being read")

	# --- kept by a save, merged ----------------------------------------------------------------------
	var raw = [r4.book, {"id": "x", "title": "   "}, {"title": "no id"}, "not a book", {"id": "y", "title": "Fine", "status": "lost", "pages": "300", "log": {"2026-11-01": [1, 20], "bad": [1]}}]
	var parsed = Books.parse(JSON.parse_string(JSON.stringify(raw)))
	ok(parsed.size() == 2 and parsed[0].log["2026-11-23"] == [249, 330] and parsed[0].page == 400 and parsed[1].status == "reading" and parsed[1].pages == 300 and parsed[1].log.keys() == ["2026-11-01"], "the saved list read back: through JSON, wrong ones left out", parsed)
	await process_frame
	var app = root.get_node_or_null("App")
	ok(app != null, "the App")
	if app != null:
		var saved = app.empty_saved()
		saved["books"] = [r4.book]
		var back = app.parse_saved(JSON.parse_string(JSON.stringify(saved)))
		ok(back.books.size() == 1 and back.books[0].title == "The Long Road" and back.books[0].log.size() == 2, "a save keeps its books", back.books)
		ok(app.empty_saved().books.is_empty() and SaveMerge.RECORD_LISTS.has("books"), "a new save has none; two copies of a save merge them book by book")
		_app_part(app)
	print("BOOKS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)


func _app_part(app) -> void:
	# A fresh, throwaway save (TINY_TITAN_DATA is a scratch folder).
	app.replace_all(app.empty_saved())
	var n = app.add_books(Books.parse_list("First Light | A. Writer | Glow Cycle 1 | 541 pages ; The Long Road | A. Writer | Road Saga 4 | 1232 pages | reading, page 249"))
	ok(n == 2 and app.books().size() == 2, "two books added")
	ok(app.add_books(Books.parse_list("first light | a. writer ; New One")) == 1, "the same book again is left out (any case); a new one is added")
	var road = Books.reading_now(app.books())[0]
	ok(str(road.title) == "The Long Road" and int(road.page) == 249, "the one being read")
	ok(app.reading().is_empty() and Reading.pages_on(app.state, app.today) == 0, "adding books adds no pages")
	var r = app.set_book_page(str(road.id), 300)
	ok(int(r.delta) == 51 and int(r.day) == 51 and Reading.pages_on(app.state, app.today) == 51, "stopped on page 300: today's reading is 51 pages", r)
	app.add_reading(10)
	var r2 = app.set_book_page(str(road.id), 320)
	ok(int(r2.delta) == 20 and int(r2.day) == 81 and Reading.pages_on(app.state, app.today) == 81, "pages added by hand stay: 51 + 10 + 20", r2)
	var r3 = app.set_book_page(str(road.id), 310)
	ok(int(r3.delta) == -10 and Reading.pages_on(app.state, app.today) == 71, "a correction takes the difference back", r3)
	var on_disk = JSON.parse_string(FileAccess.get_file_as_string(app.DATA_DIR + "save.json"))
	ok(on_disk is Dictionary and on_disk.books.size() == 3 and on_disk.books.any(func(x): return x.title == "The Long Road" and int(x.page) == 310), "the books are in the save file")
	app.set_book_finished(str(road.id), true)
	road = Books.find(app.books(), str(road.id))
	ok(road.status == "finished" and road.finished == app.today and Books.reading_now(app.books()).is_empty() and Books.shelf(app.books()).back().id == road.id, "finished: on the shelf, last")
	app.update_book(str(road.id), {"pages": 1248, "title": "  "})
	road = Books.find(app.books(), str(road.id))
	ok(int(road.pages) == 1248 and road.title == "The Long Road", "its length changed; an empty title is not taken")
	app.remove_book(str(road.id))
	ok(Books.find(app.books(), str(road.id)) == null and Reading.pages_on(app.state, app.today) == 71, "removed: the pages it added stay")
