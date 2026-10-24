class_name ShipSceneIds
extends RefCounted
## The ids a redrawn scene keeps from the one it replaces, so `make ship-scene` over an
## unchanged ship rewrites her file byte for byte, and a data change diffs as only the
## nodes and resources it adds, removes or alters (ShipSceneDraw.save).
##
## Godot re-rolls them on every save: each node's `unique_id`, which no script can read or
## set, and each sub-resource's id. Both are kept in the saved text, so this reads it:
## a node at a path the old scene has takes its `unique_id`, and a sub-resource whose
## content — its type and its lines, its own references already kept — is an old one's
## takes that one's id, every reference to it following. Of two old sub-resources of one
## content, a new one takes the id the node at its path referred to. Anything new keeps
## the id the save gave it, unless that id is already taken here.

## The kinds of section a saved scene is made of, each opening on its header line.
const _KINDS := "gd_scene|gd_resource|ext_resource|sub_resource|node|connection|editable"

static var _section := RegEx.create_from_string("^\\[(%s)[ \\]]" % _KINDS)
static var _attribute := RegEx.create_from_string('(\\w+)=("(?:[^"\\\\]|\\\\.)*"|[^ \\]]+)')
static var _reference := RegEx.create_from_string('SubResource\\("([^"]*)"\\)')


## [param drawn], a scene's text as Godot saved it, with the ids of [param old], the text
## of the scene it replaces, kept; in [param old]'s line endings.
static func kept(old: String, drawn: String) -> String:
	var crlf := old.contains("\r\n")
	var was := _sections(old.replace("\r\n", "\n"))
	var now := _sections(drawn.replace("\r\n", "\n"))
	var renamed := _resources(was, now)
	var taken := {}
	for section: Dictionary in was:
		if section["kind"] == "node":
			taken[section["unique_id"]] = true
	var by_path := {}
	for section: Dictionary in was:
		if section["kind"] == "node":
			by_path[section["path"]] = section["unique_id"]
	var lines := PackedStringArray()
	for section: Dictionary in now:
		var header: String = section["header"]
		if section["kind"] == "node" and section.has("unique_id"):
			var id: String = by_path.get(section["path"], "")
			if id.is_empty():
				id = _fresh_node_id(section["unique_id"], taken)
			header = header.replace("unique_id=%s" % section["unique_id"], "unique_id=%s" % id)
		elif section["kind"] == "sub_resource":
			header = header.replace('id="%s"' % section["id"], 'id="%s"' % renamed[section["id"]])
		if not section["kind"].is_empty():
			lines.append(_references(header, renamed))
		for line: String in section["body"]:
			lines.append(_references(line, renamed))
	var text := "\n".join(lines)
	return text.replace("\n", "\r\n") if crlf else text


## The id each of [param now]'s sub-resources goes by: the old one's of its content in
## [param was], else its own.
static func _resources(was: Array[Dictionary], now: Array[Dictionary]) -> Dictionary:
	var by_content := {}
	var used := {}
	for section: Dictionary in was:
		if section["kind"] == "sub_resource":
			var content := _content(section, {})
			if not by_content.has(content):
				by_content[content] = []
			(by_content[content] as Array).append(section["id"])
			used[section["id"]] = true
	var held_at := _held(was)
	var holders := {}
	for section: Dictionary in now:
		if section["kind"] == "node":
			for id: String in section["holds"]:
				if not holders.has(id):
					holders[id] = []
				(holders[id] as Array).append(section["path"])
	var renamed := {}
	var taken := {}
	for section: Dictionary in now:
		if section["kind"] != "sub_resource":
			continue
		var fresh: String = section["id"]
		var free := PackedStringArray()
		for id: String in by_content.get(_content(section, renamed), []):
			if not taken.has(id):
				free.append(id)
		var id := fresh
		if not free.is_empty():
			id = free[0]
			for path: String in holders.get(fresh, []):
				var held := held_at.get(path, []) as Array
				var both := Array(free).filter(func(old: String) -> bool: return old in held)
				if not both.is_empty():
					id = both[0]
					break
		else:
			while used.has(id) or taken.has(id):
				id = "%s_%s" % [fresh.get_slice("_", 0), str(randi()).sha1_text().left(5)]
		renamed[fresh] = id
		taken[id] = true
	return renamed


## The sub-resources each node of [param sections] refers to, by its path.
static func _held(sections: Array[Dictionary]) -> Dictionary:
	var held := {}
	for section: Dictionary in sections:
		if section["kind"] == "node":
			held[section["path"]] = section["holds"]
	return held


## What [param section] says, but for its own id, with the ids it refers to
## [param renamed].
static func _content(section: Dictionary, renamed: Dictionary) -> String:
	var lines := PackedStringArray([section["type"]])
	for line: String in section["body"]:
		lines.append(_references(line, renamed))
	return "\n".join(lines)


## [param line] with every sub-resource it refers to by its id in [param renamed].
static func _references(line: String, renamed: Dictionary) -> String:
	var found := _reference.search_all(line)
	if found.is_empty():
		return line
	var out := ""
	var at := 0
	for hit: RegExMatch in found:
		var id := hit.get_string(1)
		out += line.substr(at, hit.get_start() - at)
		out += 'SubResource("%s")' % renamed.get(id, id)
		at = hit.get_end()
	return out + line.substr(at)


## A node id [param fresh], or another when it is in [param taken]; taken either way.
static func _fresh_node_id(fresh: String, taken: Dictionary) -> String:
	var id := fresh
	while taken.has(id):
		id = str(randi() % 0x7fffffff + 1)
	taken[id] = true
	return id


## [param text] as its sections, in order: each a header line and the lines below it, the
## first a headless one of whatever comes before any header.
static func _sections(text: String) -> Array[Dictionary]:
	var sections: Array[Dictionary] = [{"kind": "", "header": "", "body": []}]
	for line: String in text.split("\n"):
		var header := _section.search(line)
		if header == null:
			(sections[-1]["body"] as Array).append(line)
			continue
		var section := {"kind": header.get_string(1), "header": line, "body": []}
		var attributes := {}
		for attribute: RegExMatch in _attribute.search_all(line):
			attributes[attribute.get_string(1)] = (
				attribute.get_string(2).trim_prefix('"').trim_suffix('"')
			)
		section["type"] = attributes.get("type", "")
		if attributes.has("id"):
			section["id"] = attributes["id"]
		if attributes.has("unique_id"):
			section["unique_id"] = attributes["unique_id"]
		if section["kind"] == "node":
			var name: String = attributes.get("name", "")
			var parent: String = attributes.get("parent", "")
			if not attributes.has("parent"):
				section["path"] = "."
			elif parent == ".":
				section["path"] = name
			else:
				section["path"] = parent + "/" + name
		sections.append(section)
	for section: Dictionary in sections:
		if section["kind"] == "node":
			var holds := []
			for line: String in section["body"]:
				for hit: RegExMatch in _reference.search_all(line):
					holds.append(hit.get_string(1))
			section["holds"] = holds
	return sections
