extends GutTest
## The knock-out feed says who went into the sea and whose shove sent them
## (KnockoutFeed), the local seat as "You".

const COLD := PlayerState.Cause.COLD
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


func _feed() -> KnockoutFeed:
	var feed := KnockoutFeed.new()
	add_child_autofree(feed)
	feed.set_process(false)
	feed.setup(PackedStringArray(NAMES), 0)
	return feed


func _lines(feed: KnockoutFeed) -> Array[String]:
	var lines: Array[String] = []
	for label: Label in feed.get_node("Lines").get_children():
		lines.append(label.text)
	return lines
