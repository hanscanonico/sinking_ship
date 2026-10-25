extends GutTest
## The knock-out feed says who went into the sea and whose shove sent them
## (KnockoutFeed), the local seat as "You"; and beside those lines, each bonus that comes
## aboard and each one a seat takes (#313).

const MATCH := preload("res://scenes/match/match.tscn")
const MATCH_DATA := "res://data/match/default.tres"
const COLD := PlayerState.Cause.COLD
const WITH_HER := PlayerState.Cause.WITH_HER
const NAMES := ["You", "Bot 1", "Bot 2", "Bot 3"]


func test_a_line_names_the_shover_and_the_shoved() -> void:
	var names := PackedStringArray(NAMES)
	assert_eq(KnockoutFeed.feed_line(names, 3, 2, 0), "Bot 2 shoved Bot 3 into the sea")
	assert_eq(KnockoutFeed.feed_line(names, 3, -1, 0), "Bot 3 went into the sea")
	assert_eq(KnockoutFeed.feed_line(names, 3, 0, 0), "You shoved Bot 3 into the sea")
	assert_eq(KnockoutFeed.feed_line(names, 0, 1, 0), "Bot 1 shoved you into the sea")
	assert_eq(KnockoutFeed.feed_line(names, 0, -1, 0), "You went into the sea")


## Online the local seat need not be the first, nor named "You" in the names.
func test_you_is_the_own_seat_whatever_its_name() -> void:
	var names := PackedStringArray(["Ann", "Bea", "Cy"])
	assert_eq(KnockoutFeed.feed_line(names, 0, 2, 2), "You shoved Ann into the sea")
	assert_eq(KnockoutFeed.feed_line(names, 2, 1, 2), "Bea shoved you into the sea")
	assert_eq(KnockoutFeed.feed_line(names, 2, -1, 2), "You went into the sea")


## Inside her as she went is no fall into the sea, however dry it stood and whoever
## shoved it last: it went down with her.
func test_a_seat_out_with_her_went_down_with_her() -> void:
	var names := PackedStringArray(NAMES)
	assert_eq(KnockoutFeed.feed_line(names, 0, -1, 0, WITH_HER), "You went down with her")
	assert_eq(KnockoutFeed.feed_line(names, 3, 1, 0, WITH_HER), "Bot 3 went down with her")
	var feed := _feed()
	feed.add([SimEvent.seat_out(20, 2, 4, WITH_HER, -1)])
	assert_eq(_lines(feed), ["Bot 2 went down with her"])


func test_lines_come_from_seat_out_only_and_stand_four_at_most() -> void:
	var feed := _feed()
	feed.add([SimEvent.shove_landed(10, 1, 2), SimEvent.seat_out(20, 2, 4, COLD, 1)])
	assert_eq(_lines(feed), ["Bot 1 shoved Bot 2 into the sea"])
	for seat in [3, 1, 0, 3]:
		feed.add([SimEvent.seat_out(30, seat, 3, COLD, -1)])
	assert_eq(
		_lines(feed),
		[
			"Bot 3 went into the sea",
			"Bot 1 went into the sea",
			"You went into the sea",
			"Bot 3 went into the sea",
		],
		"the oldest pushed off, the newest last"
	)
	feed.clear()
	assert_eq(_lines(feed), [], "a replay sought clears it")


func test_a_line_fades_and_goes() -> void:
	var feed := _feed()
	feed.add([SimEvent.seat_out(20, 2, 4, COLD, -1)])
	var label := feed.get_node("Lines").get_child(0) as Label
	feed._process(KnockoutFeed.LINE_SECONDS - KnockoutFeed.FADE_SECONDS * 0.5)
	assert_almost_eq(label.modulate.a, 0.5, 0.01, "half way through its fade")
	feed._process(KnockoutFeed.FADE_SECONDS)
	assert_eq(_lines(feed), [], "gone once it has stood its time")


## The match feeds it every stepped tick's events, as it does the stats, clears it as
## a replay is sought, and keeps it off the results.
func test_the_match_feeds_it_each_stepped_tick() -> void:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	var config := SimFixtures.config(3)
	config.bot_tier = (load(MATCH_DATA) as MatchRules).bot_tier
	scene.start(config, true)
	var feed: KnockoutFeed = scene.get_node("KnockoutFeed")
	feed.set_process(false)
	var out: Array[SimEvent] = [SimEvent.seat_out(90, 2, 3, COLD, 0)]
	scene._driver.stepped.emit(out)
	assert_eq(_lines(feed), ["You shoved Bot 2 into the sea"], "posted as the tick steps")
	scene._on_sought(0)
	assert_eq(_lines(feed), [], "a seek clears it")
	scene._process(0.0)
	assert_true(feed.visible, "shown while the match goes on")
	var ended: Array[SimEvent] = [
		SimEvent.seat_out(120, 1, 2, COLD, -1), SimEvent.match_ended(120, 0)
	]
	scene._driver.stepped.emit(ended)
	scene._process(0.0)
	assert_false(feed.visible, "not over the results")
	scene.stand_aside()
	scene._process(0.0)
	assert_false(feed.visible, "nor while the match stands aside")


## A bonus coming aboard is posted beside the knock-outs (#313), in its kind's colour: its
## kind's title and the room its bonus spot lies in, named as her layout names it — two
## rooms of one name each by that name.
func test_a_bonus_coming_aboard_names_its_kind_and_its_room() -> void:
	var layout := SimFixtures.below_decks(4)
	var rooms: Array[StringName] = [&"hold", &"engine room", &"stokehold", &"engine room"]
	for room in rooms.size():
		layout.rooms[room].name = rooms[room]
	# The spots listed the other way round: a line names the room its spot lies in, not
	# the room listed where the spot is.
	layout.bonus_spots.reverse()
	var kinds: Array[BonusKind] = [SimFixtures.plain_kind(), SimFixtures.double_life()]
	var feed := _feed(layout, SimFixtures.bonus_rules(1.0, 45.0, 0.0, 2, kinds))
	for spot in 4:
		feed.add([SimEvent.bonus_came(600 + spot, 1, spot)])
	assert_eq(
		_lines(feed),
		[
			"Double life: engine room",
			"Double life: stokehold",
			"Double life: engine room",
			"Double life: hold",
		]
	)
	var mark := SimFixtures.double_life().mark
	assert_eq(_colours(feed), [mark, mark, mark, mark], "in its kind's colour")


## A seat taking a bonus is posted beside the knock-outs (#313), the kind it took by its
## title, in its colour, and the local seat as "You". A bonus lost to the sea, and a Double
## life spent, are no lines of the feed.
func test_a_bonus_taken_names_who_took_which() -> void:
	var plain := SimFixtures.plain_kind()
	plain.mark = Color.AQUAMARINE
	var kinds: Array[BonusKind] = [SimFixtures.double_life(), plain]
	var rules := SimFixtures.bonus_rules(1.0, 45.0, 0.0, 2, kinds)
	var feed := _feed()
	# Online the local seat need not be the first, nor named "You".
	feed.setup(PackedStringArray(["Ann", "Bea", "Cy", "Di"]), 2, SimFixtures.below_decks(), rules)
	feed.add([SimEvent.bonus_taken(700, 3, 1, 0), SimEvent.bonus_lost(710, 0, 0)])
	feed.add([SimEvent.double_life_spent(720, 3, 0), SimEvent.bonus_taken(730, 2, 0, 0)])
	assert_eq(_lines(feed), ["Di took Plain", "You took Double life"])
	assert_eq(_colours(feed), [Color.AQUAMARINE, kinds[0].mark], "each in its kind's colour")


## The match hands the feed her layout and the bonus rules it plays (#313): a bonus coming
## aboard is posted as the tick steps.
func test_the_match_feeds_it_the_bonuses_it_plays() -> void:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	var config := SimFixtures.config(3, SimFixtures.calm_until(600.0), 1, SimFixtures.below_decks())
	config.bot_tier = (load(MATCH_DATA) as MatchRules).bot_tier
	config.bonus_rules = SimFixtures.bonus_rules(600.0)
	scene.start(config, true)
	var feed: KnockoutFeed = scene.get_node("KnockoutFeed")
	feed.set_process(false)
	var came: Array[SimEvent] = [SimEvent.bonus_came(90, 0, 0)]
	scene._driver.stepped.emit(came)
	assert_eq(_lines(feed), ["Double life: hold"])


func _feed(layout: ShipLayout = null, bonus_rules: BonusRules = null) -> KnockoutFeed:
	var feed := KnockoutFeed.new()
	add_child_autofree(feed)
	feed.set_process(false)
	feed.setup(PackedStringArray(NAMES), 0, layout, bonus_rules)
	return feed


func _lines(feed: KnockoutFeed) -> Array[String]:
	var lines: Array[String] = []
	for label: Label in feed.get_node("Lines").get_children():
		lines.append(label.text)
	return lines


## The colour each line standing is written in, in _lines' order.
func _colours(feed: KnockoutFeed) -> Array[Color]:
	var colours: Array[Color] = []
	for label: Label in feed.get_node("Lines").get_children():
		colours.append(label.get_theme_color(&"font_color"))
	return colours
