extends RefCounted
## The list of scenario themes, in unlock order, parsed from data/catalog.json.
## A theme (for example "Playa") groups one or more variants; each variant is a
## scenario data file with its own illustration. Pure logic.
##
## File format 1:
##   format
##   themes [ { id, title, variants: [scenario id, ...] } ]

const FORMAT := 1

## Array of { "id": String, "title": String, "variants": Array[String] }
var themes: Array[Dictionary] = []


func theme_ids() -> Array[String]:
	var ids: Array[String] = []
	for theme in themes:
		ids.append(theme["id"])
	return ids


func find_theme(theme_id: String) -> Dictionary:
	for theme in themes:
		if theme["id"] == theme_id:
			return theme
	return {}


## Variant to play this time. Returns "" for an unknown theme.
func pick_variant(theme_id: String, rng: RandomNumberGenerator) -> String:
	var theme := find_theme(theme_id)
	if theme.is_empty():
		return ""
	var variants: Array[String] = theme["variants"]
	return variants[rng.randi_range(0, variants.size() - 1)]


static func from_dict(data: Variant, errors: Array[String]) -> RefCounted:
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("themes")) != TYPE_ARRAY:
		errors.append("catalog must be an object with a themes array")
		return null
	var format: Variant = data.get("format")
	if (typeof(format) != TYPE_INT and typeof(format) != TYPE_FLOAT) or int(format) != FORMAT:
		errors.append("unsupported catalog format: %s" % str(format))
		return null

	var catalog: RefCounted = new()
	var seen := {}
	for index in (data["themes"] as Array).size():
		var entry: Variant = data["themes"][index]
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("theme %d must be an object" % index)
			continue
		var theme_id: Variant = entry.get("id")
		var title: Variant = entry.get("title")
		var raw_variants: Variant = entry.get("variants")
		if typeof(theme_id) != TYPE_STRING or theme_id.is_empty() or seen.has(theme_id):
			errors.append("theme %d needs a unique id" % index)
			continue
		if typeof(title) != TYPE_STRING or title.is_empty():
			errors.append("theme '%s' has no title" % theme_id)
			continue
		var variants: Array[String] = []
		if typeof(raw_variants) == TYPE_ARRAY:
			for variant: Variant in raw_variants:
				if typeof(variant) == TYPE_STRING and variant.is_valid_filename() and not variants.has(variant):
					variants.append(variant)
		if variants.is_empty():
			errors.append("theme '%s' needs at least one variant" % theme_id)
			continue
		seen[theme_id] = true
		catalog.themes.append({"id": theme_id, "title": title, "variants": variants})
	if catalog.themes.is_empty() and errors.is_empty():
		errors.append("catalog has no themes")
	return catalog if errors.is_empty() else null
