extends RefCounted
## Books (run with the "year" data, also with --fingers): books pasted in one
## go, the one being read on the Hero tab's reading card, the page it stopped
## on working out the day's pages, a correction, the last page asking whether
## it is finished, the bookshelf, a book's own sheet. Made-up books.
## Prints CHECK lines.

const PASTE = "First Light | A. Writer | Glow Cycle 1 | 541 pages ; Second Light | A. Writer | Glow Cycle 2 | 590 pages ; Moon Book | B. Author | Moon 1 | 561 pages ; The Long Road | A. Writer | Road Saga 4 | 1232 pages | reading, page 249"

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _find(meta: String, root = null, value = null):
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta) and (value == null or str(n.get_meta(meta)) == str(value)):
			return n
	return null


func _sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			top = c
	return top


func _close_sheets() -> void:
	for c in Kit.overlay_root.get_children():
		if c is Sheet:
			c.close()
	await ShotHelper.wait(tree, 0.6)


func _today_pages() -> int:
	return Reading.pages_on(App.state, App.today)


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	await ShotHelper.wait(tree, 0.8)
	# Today's reading starts empty, whatever the demo did.
	App.set_reading(App.today, 0)
	App.update_settings({"weightUnit": "lb"})
	App.go("home")
	await ShotHelper.wait(tree, 0.8)
	check(App.books().is_empty() and _find("book_row") == null and ShotHelper.find_button(main, "+10") != null, "no books: the reading card adds pages with a tap, as before")

	# --- the sheet: paste several books at once ----------------------------------------------------
	ReadingView.open()
	await ShotHelper.wait(tree, 0.8)
	var sh = _sheet()
	check(sh != null and _find("bookshelf", sh) != null and ShotHelper.find_text(sh, "No books yet") != null and _find("book_add", sh) != null, "the reading sheet: an empty bookshelf and a card to add a book")
	ShotHelper.press(_find("book_paste_toggle", sh))
	await ShotHelper.wait(tree, 0.5)
	sh = _sheet()
	var box = _find("book_paste", sh)
	check(box != null, "Add several at once opens a box to paste them into")
	if box != null:
		ShotHelper.type_into(box, PASTE)
		await ShotHelper.frames(tree, 2)
		ShotHelper.press(_find("book_paste_add", sh))
	await ShotHelper.wait(tree, 0.8)
	sh = _sheet()
	check(App.books().size() == 4 and Books.shelf(App.books()).size() == 3 and Books.reading_now(App.books()).size() == 1, "four books: three on the shelf, one being read (%d)" % App.books().size())
	check(_today_pages() == 0, "adding books adds no pages")
	var road = Books.reading_now(App.books())[0]
	var card = _find("book_card", sh, str(road.id))
	check(card != null and ShotHelper.all_text(card).contains("The Long Road") and ShotHelper.all_text(card).contains("p. 249 of 1,232"), "Reading now: the book and where its bookmark is")
	var shelf = _find("bookshelf", sh)
	check(shelf != null and int(shelf.get_meta("bookshelf")) == 3 and ShotHelper.all_text(shelf).contains("3 books") and ShotHelper.all_text(shelf).contains("First Light") and ShotHelper.all_text(shelf).contains("Glow Cycle 2"), "the bookshelf: three books, their titles and series")
	await ShotHelper.snap(tree, "books_1_sheet")
	if sh != null:
		sh._scroll.scroll_vertical = 600
		await ShotHelper.frames(tree, 4)
		await ShotHelper.snap(tree, "books_2_shelf")
	# The same paste again adds nothing.
	check(App.add_books(Books.parse_list(PASTE)) == 0, "pasting the same books again adds none")
	await _close_sheets()

	# --- the Hero card: the page it stopped on ------------------------------------------------------
	App.go("home")
	await ShotHelper.wait(tree, 0.8)
	var row = _find("book_row")
	check(row != null and ShotHelper.all_text(row).contains("The Long Road") and ShotHelper.find_button(main, "+10") == null, "the reading card shows the book being read, with a page box in place of the quick keys")
	var pbox = _find("book_page_box", row)
	var save = _find("book_page_save", row)
	check(pbox != null and save != null and pbox.placeholder_text == "249", "the box says the bookmark: 249")
	if pbox != null:
		ShotHelper.type_into(pbox, "300")
		ShotHelper.press(save)
	await ShotHelper.wait(tree, 0.8)
	check(_today_pages() == 51 and int(Books.find(App.books(), str(road.id)).page) == 300, "stopped on page 300: today's reading is 51 pages (%d)" % _today_pages())
	row = _find("book_row")
	check(row != null and _find("book_today", row) != null and ShotHelper.all_text(row).contains("+51 pages today (from p. 249)"), "and the card says so")
	if row != null:
		ShotHelper.reveal(row)
		await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "books_3_card")
	# Typed again: 290 was the page, not 300.
	pbox = _find("book_page_box", _find("book_row"))
	ShotHelper.type_into(pbox, "290")
	pbox.text_submitted.emit("290")
	await ShotHelper.wait(tree, 0.8)
	check(_today_pages() == 41, "typed again, 290 (Done on the keyboard): a correction, 41 today (%d)" % _today_pages())

	# --- the last page: finished? ------------------------------------------------------------------------
	pbox = _find("book_page_box", _find("book_row"))
	ShotHelper.type_into(pbox, "1232")
	ShotHelper.press(_find("book_page_save", _find("book_row")))
	await ShotHelper.wait(tree, 0.8)
	var yes = ShotHelper.find_button(Kit.overlay_root, "Yes, finished")
	check(yes != null, "its last page: it asks whether the book is finished")
	await ShotHelper.snap(tree, "books_4_finished")
	if yes != null:
		ShotHelper.press(yes)
	await ShotHelper.wait(tree, 0.8)
	road = Books.find(App.books(), str(road.id))
	check(road.status == "finished" and road.finished == App.today and Books.shelf(App.books()).size() == 4, "on the shelf, finished today")
	check(_find("book_row") == null and ShotHelper.find_button(main, "+10") != null, "no book being read: the quick keys are back")
	await ShotHelper.wait(tree, 2.5)

	# --- a book's own sheet ----------------------------------------------------------------------------------
	ReadingView.open()
	await ShotHelper.wait(tree, 0.8)
	var srow = _find("shelf_book", _sheet(), str(road.id))
	check(srow != null, "the finished book is in the shelf's list")
	if srow != null:
		ShotHelper.reveal(srow)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.click(tree, srow)
	await ShotHelper.wait(tree, 0.8)
	var bs = _sheet()
	check(bs != null and _find("book_sheet", bs, str(road.id)) != null and ShotHelper.find_button(bs, "Reading it again") != null, "a tap opens the book: its fields, Reading it again, Remove")
	await ShotHelper.snap(tree, "books_5_book")
	await _close_sheets()

	# --- the add form: a book started by hand ---------------------------------------------------------------
	ReadingView.open()
	await ShotHelper.wait(tree, 0.8)
	sh = _sheet()
	var title = _find("book_add_title", sh)
	if title != null:
		ShotHelper.type_into(title, "Hand Typed")
	await ShotHelper.frames(tree, 2)
	ShotHelper.press(_find("book_add_reading", sh))
	await ShotHelper.wait(tree, 0.8)
	var hand = Books.reading_now(App.books())
	check(hand.size() == 1 and str(hand[0].title) == "Hand Typed" and int(hand[0].page) == 0, "a book typed in and started: being read, from page 0")
	await _close_sheets()
	App.go("home")
	await ShotHelper.wait(tree, 0.6)
	var hrow = _find("book_row")
	if hrow != null:
		ShotHelper.reveal(hrow)
		await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "books_6_hero")
	print("BOOKS WALK: %d failed" % fails)
