class_name WarningChips
extends RefCounted
## What the sinking's chips over the crosshair say (FirstPersonHud): one for every
## telegraph running — a lurch, a deck giving way, a funnel straining at its stays. A
## lurch's chip tells the player to brace, by its key, only where a press would: a
## watcher, a seat out of the match and a replay's viewer have nothing to brace.


## The chips [param pose] has up at [param tick], the lurch's naming [param brace_key]
## (lurch_words).
static func words(pose: ShipPose, tick: int, brace_key: String) -> PackedStringArray:
	var warnings := PackedStringArray()
	if pose.lurch_warning != 0.0:
		warnings.append(lurch_words(pose.lurch_warning, brace_key))
	for going: StringName in pose.collapsing:
		var deck := Language.named(String(going)).to_upper()
		warnings.append(Language.t("THE %s IS GOING") % deck)
	for fall: FunnelFall in pose.falls:
		if tick < fall.falls_at:
			warnings.append(straining_words(fall.fitting.name))
	return warnings


## The chip for a lurch telegraphed to starboard ([param warning] over 0) or to port:
## with the key to brace on, [param brace_key], or — for "" — the lurch alone, the
## catalog's line up to its dash.
static func lurch_words(warning: float, brace_key: String) -> String:
	var lurch := "LURCH TO STARBOARD — BRACE (%s)"
	if warning < 0.0:
		lurch = "LURCH TO PORT — BRACE (%s)"
	if brace_key.is_empty():
		return Language.t(lurch).get_slice(" — ", 0)
	return Language.t(lurch) % brace_key


## The chip for the funnel fitting [param named] straining at its stays: one of her
## funnels by its number when she has several (funnel_4: FUNNEL 4), else by what it is.
static func straining_words(named: StringName) -> String:
	var words := String(named).replace("_", " ")
	var said := Language.numbered(words).to_upper()
	if words.get_slice(" ", words.get_slice_count(" ") - 1).is_valid_int():
		return Language.t("%s IS STRAINING") % said
	return Language.t("THE %s IS STRAINING") % said
