class_name SeedStreams
extends RefCounted
## Every seeded stream a match uses, derived from (match seed, key) so one stream's
## draws never shift another's (D4): "match" for the spawn shuffle, "sink" for the
## sinking, and a bot's seat number for that bot.


static func derive(match_seed: int, key: Variant) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = str(match_seed, ":", key).hash()
	return rng
