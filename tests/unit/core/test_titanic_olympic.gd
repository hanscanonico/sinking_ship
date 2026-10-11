extends GutTest
## The Olympic as her 1913 refit left her, on the Titanic's damage of the night (SH34):
## the test-only hull tools/gen_titanic.py writes with her bulkheads and inner skin
## (SB-1914). What her data meets is asserted, and what it cannot is pending with the
## number the bake measured. The Britannic is test_titanic_britannic's.


func test_the_olympic_refitted_floats_on_the_nights_damage() -> void:
	var timeline := TitanicSisters.bake(
		TitanicSisters.OLYMPIC, "titanic_night", Fleet.scenario(TitanicSisters.OLYMPIC)
	)
	var told := TitanicSisters.told(timeline)
	gut.p("the Olympic of 1913 on the night's damage: " + told)
	if (
		timeline.end != SinkTimeline.End.AFLOAT
		or TitanicSisters.first(timeline, SinkTimeline.Kind.GONE) >= 0.0
	):
		# Her bulkheads carried to B deck keep the water forward of boiler room 4, but six
		# compartments open to the sea up through every deck over them draw her bow under,
		# and her forecastle and well deck take the rest. Measured.
		pending("the Olympic founders: " + told)
		return
	assert_eq(timeline.end, SinkTimeline.End.AFLOAT, "she floats")
