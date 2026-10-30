extends SceneTree

## The night is April 1890, the mine was lost on 14 October 1885.
##
## Every date the game prints is checked here against one canon: a document in
## the room cannot be dated after the night it is read on, and no relative
## interval can point at the wrong event. The point is not pedantry — a
## quarantine notice from 1889, in a room where the mine closed in 1885, tells
## the player the mine was still working four years after it flooded, and the
## whole premise of the empty depot stops making sense.
##
## Historical reviews, bibliographic dates (Pope 1891 and friends) and research
## notes are deliberately NOT covered: those are real publication years, not
## things that hang on this office's wall.
##
##   godot --headless --audio-driver Dummy --path . --script tests/office/chronology_test.gd

var _assertions: int = 0

const NIGHT_YEAR: int = 1890
const NIGHT_MONTH: String = "APRIL"
const DISASTER_YEAR: int = 1885
const DISASTER_MONTH_DAY: String = "14 OCTOBER"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Chronology Test Suite ---")
	if not _canon_in_design_doc(): return
	if not _night_is_april_1890(): return
	if not _documents_never_postdate_the_night(): return
	if not _quarantine_precedes_the_disaster(): return
	if not _relative_intervals_agree(): return
	print("--- All Chronology Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _canon_in_design_doc() -> bool:
	var gdd := FileAccess.get_file_as_string("res://docs/design/DEAD_WIRE_GDD_v1.0.md")
	if not _a(not gdd.is_empty(), "The GDD is readable"): return false
	if not _a(gdd.contains("April %d" % NIGHT_YEAR), "The GDD sets the night in April %d" % NIGHT_YEAR): return false
	if not _a(gdd.contains("October 14, %d" % DISASTER_YEAR),
			"The GDD dates the disaster to October 14, %d" % DISASTER_YEAR): return false
	return true

func _night_is_april_1890() -> bool:
	var duty := (load("res://scripts/telegraph/ui/duty_sheet.gd") as GDScript).new() as DutySheet
	if not _a(duty != null, "The duty sheet instantiates"): return false
	var header: String = duty.HEADER
	if not _a(header.contains("%s %d" % [NIGHT_MONTH, NIGHT_YEAR]),
			"The duty sheet header is dated %s %d" % [NIGHT_MONTH, NIGHT_YEAR]): return false
	duty.free()

	var ledger := (load("res://scripts/telegraph/ui/dispatch_ledger.gd") as GDScript).new() as DispatchLedger
	if not _a(ledger != null, "The ledger instantiates"): return false
	if not _a(DispatchLedger.LEDGER_TEXT.contains("%s %d" % [NIGHT_MONTH, NIGHT_YEAR]),
			"The dispatch ledger is dated %s %d" % [NIGHT_MONTH, NIGHT_YEAR]): return false
	if not _a(DispatchLedger.NIGHT_ENTRIES_DATE == "%s %d" % [NIGHT_MONTH, NIGHT_YEAR],
			"The night-entries header matches the sheet"): return false
	ledger.free()

	var dawn := (load("res://scripts/office/dawn_evidence.gd") as GDScript).new() as DawnEvidence
	if not _a(dawn != null, "The handover instantiates"): return false
	if not _a(dawn._build_document(DawnEvidence.VARIANT_LAPSED).contains("%s %d" % [NIGHT_MONTH, NIGHT_YEAR]),
			"The morning handover is dated %s %d" % [NIGHT_MONTH, NIGHT_YEAR]): return false
	dawn.free()

	var intro := FileAccess.get_file_as_string("res://scenes/ui/intro_card.tscn")
	if not _a(intro.contains("%s %d" % [NIGHT_MONTH, NIGHT_YEAR]),
			"The title card is dated %s %d" % [NIGHT_MONTH, NIGHT_YEAR]): return false
	var menu := FileAccess.get_file_as_string("res://scenes/ui/main_menu.tscn")
	if not _a(menu.contains("%s %d" % [NIGHT_MONTH, NIGHT_YEAR]),
			"The main menu is dated %s %d" % [NIGHT_MONTH, NIGHT_YEAR]): return false
	return true

## Nothing printed in the room may be dated after the night it is read on.
func _documents_never_postdate_the_night() -> bool:
	var books := (load("res://scripts/office/bookshelf_inspect.gd") as GDScript).new() as BookshelfInspect
	if not _a(books != null, "The bookshelf instantiates"): return false
	var shelf: String = books.SHELF_TEXT
	books.free()
	var years := _years_in(shelf)
	if not _a(not years.is_empty(), "The shelf prints at least one date to check (%s)" % str(years)): return false
	var latest := 0
	for year in years:
		latest = maxi(latest, year)
	if not _a(latest <= NIGHT_YEAR,
			"No bound volume on the shelf is newer than the night (%d)" % latest): return false
	# A general order cannot be bound before it is issued, so the bound year
	# also has to be a real date, not a placeholder.
	if not _a(latest >= DISASTER_YEAR,
			"The newest shelf date is not before the mine closed (%d)" % latest): return false

	var ledger_text := DispatchLedger.LEDGER_TEXT
	for year in _years_in(ledger_text):
		if not _a(year <= NIGHT_YEAR,
				"The dispatch ledger never cites a year after the night (%d)" % year): return false
	
	var map := FileAccess.get_file_as_string("res://scenes/office/m1_office.tscn")
	for year in _years_in(map):
		if not _a(year <= NIGHT_YEAR,
				"The division map is not revised after the night (%d)" % year): return false
	return true

## The quarantine is the episode that came BEFORE the mine was lost — the same
## season, four years earlier — and the notice is still on the shelf because
## nobody withdrew it. Same year as the flood, earlier month: June, not October.
func _quarantine_precedes_the_disaster() -> bool:
	var books := (load("res://scripts/office/bookshelf_inspect.gd") as GDScript).new() as BookshelfInspect
	var shelf: String = books.SHELF_TEXT
	books.free()
	var marker := shelf.find("QUARANTINE")
	if not _a(marker >= 0, "The shelf carries the quarantine notice"): return false
	var window := shelf.substr(marker, 60)
	var years := _years_in(window)
	if not _a(years.size() == 1, "The quarantine notice names one year (%s)" % str(years)): return false
	if not _a(window.contains("JUNE"), "The quarantine is the June episode"): return false
	# June 1885 is four months before the flood and four years before this
	# watch. The notice may share the disaster's year; it may not follow it.
	if not _a(years[0] <= DISASTER_YEAR,
			"The quarantine is not later than the mine closing (%d <= %d)" % [years[0], DISASTER_YEAR]): return false
	if not _a(years[0] < NIGHT_YEAR,
			"The quarantine is years before this watch (%d < %d)" % [years[0], NIGHT_YEAR]): return false
	# And the cutting is the other side of the flood, so the shelf reads in
	# order rather than as one undated pile.
	var cutting := shelf.find("NEWSPAPER CUTTING")
	if not _a(cutting > marker, "The newspaper cutting follows the quarantine notice"): return false
	var cutting_years := _years_in(shelf.substr(cutting, 60))
	if not _a(cutting_years.size() == 1 and cutting_years[0] == DISASTER_YEAR,
			"The cutting is dated to the flood itself (%s)" % str(cutting_years)): return false
	return true

## The four-and-a-half years between the flood and this watch: October 1885 to
## April 1890. The month is what makes it "four and a half" rather than five, so
## the interval is measured in months, not in a subtraction of years.
func _relative_intervals_agree() -> bool:
	var months := (NIGHT_YEAR - DISASTER_YEAR) * 12 + (4 - 10)
	if not _a(months == 54, "The return is fifty-four months after the flood, got %d" % months): return false
	var years := float(months) / 12.0
	if not _a(years > 4.0 and years < 5.0,
			"The return is four and a half years later, not five (%.2f)" % years): return false
	var gdd := FileAccess.get_file_as_string("res://docs/design/DEAD_WIRE_GDD_v1.0.md")
	if not _a(not gdd.contains("1889 disaster"), "The GDD no longer calls it the 1889 disaster"): return false
	return true

## Every four-digit year that looks like a calendar year in a block of print.
func _years_in(text: String) -> Array[int]:
	var found: Array[int] = []
	var regex := RegEx.new()
	regex.compile("(?<![0-9])(18[5-9][0-9]|19[0-2][0-9])(?![0-9])")
	for match in regex.search_all(text):
		var year := int(match.get_string())
		if not found.has(year):
			found.append(year)
	return found

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
