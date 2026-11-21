class_name Language
extends RefCounted
## The language the game speaks: English, as the code writes it, or one of the catalogs
## under locale/ — French and Spanish. The English text is the key: a Control's own
## text is looked up as it is drawn, and whatever the code composes or draws itself
## asks t() for its pattern and fills it in after. Nothing is loaded until use(), so a
## test that never calls it reads English whatever the machine speaks. Presentation
## only: no rule, transcript or log is translated.

## The language the code is written in: the one with no catalog.
const SOURCE := "en"
## The languages on offer, each by its code and under its own name.
const NAMES := {"en": "English", "fr": "Français", "es": "Español"}
const DIR := "res://locale"
## The context a noun is asked for under when a sentence needs its article with it:
## "the lifebuoy" is "la bouée".
const WITH_ARTICLE: StringName = &"the"

## The language in use; SOURCE until use() picks another.
static var _current := SOURCE
static var _loaded := false


## The codes of the languages on offer, in the order the settings list them.
static func locales() -> Array[String]:
	var codes: Array[String] = []
	codes.assign(NAMES.keys())
	return codes


## The catalog of [param locale] as a file: gettext, keyed by the English.
static func catalog_path(locale: String) -> String:
	return "%s/%s.po" % [DIR, locale]


## [param text] in the language in use, under [param context] when the catalogs tell
## two uses of it apart; itself in English, and where no catalog has it.
static func t(text: String, context: StringName = &"") -> String:
	if text.is_empty():
		return ""
	return String(TranslationServer.translate(text, context))


## The language on offer that [param wanted] names — a code as a system gives it,
## fr_CA or es-MX — else SOURCE.
static func pick(wanted: String) -> String:
	var code := wanted.replace("-", "_").get_slice("_", 0).to_lower()
	return code if NAMES.has(code) else SOURCE


## The language a run speaks: [param run]'s when the command line named one, else the
## one [param saved] by the player, else the system's.
static func chosen(run: String, saved: String) -> String:
	if not run.is_empty():
		return pick(run)
	return pick(saved) if not saved.is_empty() else of_system()


## The system's language where it is on offer, else SOURCE — and SOURCE with no
## display, so a headless run reads the same on every machine.
static func of_system() -> String:
	if DisplayServer.get_name() == "headless":
		return SOURCE
	return pick(OS.get_locale_language())


## Speaks [param locale] from here on, as pick() reads it: every Control on screen
## words itself again.
static func use(locale: String) -> void:
	if not _loaded:
		_loaded = true
		for code: String in NAMES:
			if code != SOURCE:
				TranslationServer.add_translation(load(catalog_path(code)) as Translation)
	_current = pick(locale)
	TranslationServer.set_locale(_current)


## The code of the language in use.
static func current() -> String:
	return _current


## [param place] as a ranking says it: 1st, 2nd, 3rd; 1er, 2e; 1.º, 2.º.
static func ordinal(place: int) -> String:
	match _current:
		"fr":
			return "1er" if place == 1 else "%de" % place
		"es":
			return "%d.º" % place
	var suffix := "th"
	if place % 100 < 11 or place % 100 > 13:
		suffix = ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][place % 10]
	return "%d%s" % [place, suffix]


## A name out of the data — a ship, a room, a deck — as a heading: in English each
## word capitalised, as the data's own words read; in another language its
## translation, the first letter a capital. A name the catalog has not whole is put
## together from its parts between commas ("grand staircase, B deck"), and stays
## English unless every part is known.
static func titled(words: String) -> String:
	var said := named(words)
	if said == words or said.is_empty():
		return words.capitalize()
	return said[0].to_upper() + said.substr(1)


## [param noun] with its article, for a sentence that takes one ("grab the %s"): the
## catalog's own under WITH_ARTICLE, else the noun as it is, English supplying "the".
static func with_article(noun: String) -> String:
	return t(noun, WITH_ARTICLE)


## [param words] ending in a number ("funnel 4") with the words before it translated;
## the whole translated otherwise.
static func numbered(words: String) -> String:
	var last := words.get_slice(" ", words.get_slice_count(" ") - 1)
	if not last.is_valid_int() or last == words:
		return t(words)
	return "%s %s" % [t(words.trim_suffix(" " + last)), last]


## A name out of the data in the words of the language in use, as titled() finds
## them, its letters as they stand.
static func named(words: String) -> String:
	var whole := t(words)
	if whole != words or not words.contains(", "):
		return whole
	var parts := PackedStringArray()
	for part: String in words.split(", "):
		var said := t(part)
		if said == part:
			return words
		parts.append(said)
	return ", ".join(parts)
