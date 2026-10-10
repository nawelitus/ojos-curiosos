extends "res://tools/testing/harness.gd"

const Ui := preload("res://scripts/ui.gd")
const GameSkin := preload("res://scripts/game_skin.gd")

## Minimum contrast for body text and for large text (WCAG AA).
const TEXT_CONTRAST := 4.5
const LARGE_CONTRAST := 3.0


func run() -> void:
	check_near(Ui.contrast(Color.BLACK, Color.WHITE), 21.0, "black on white is the maximum contrast", 0.01)
	check_near(Ui.contrast(Color.WHITE, Color.WHITE), 1.0, "a colour against itself has no contrast", 0.01)

	var names := {}
	for skin_id in Ui.SKIN_IDS:
		var skin: GameSkin = Ui.load_skin(skin_id)
		check(skin != null, "skin '%s' loads" % skin_id)
		if skin == null:
			continue
		check(skin.id == skin_id and not skin.display_name.is_empty(), "'%s' has its id and a name" % skin_id)
		names[skin.display_name] = true
		_readable(skin, "text on the top of the background", skin.text, skin.background_top, TEXT_CONTRAST)
		_readable(skin, "text on the bottom of the background", skin.text, skin.background_bottom, TEXT_CONTRAST)
		_readable(skin, "muted text on the background", skin.muted, skin.background_top, LARGE_CONTRAST)
		_readable(skin, "text on panels", skin.panel_text, skin.panel, TEXT_CONTRAST)
		_readable(skin, "muted text on panels", skin.panel_muted, skin.panel, LARGE_CONTRAST)
		_readable(skin, "accent headline on panels", skin.accent, skin.panel, LARGE_CONTRAST)
		for button: Array in [["primary", skin.primary], ["accent", skin.accent], ["neutral", skin.neutral]]:
			_readable(skin, "label on %s buttons" % button[0], skin.button_text, button[1], LARGE_CONTRAST)
		_readable(skin, "lit stars against empty ones", skin.star, skin.star_empty, 1.3)
		check(skin.corner_radius > 0 and skin.button_depth > 0 and skin.font_scale >= 1.0,
				"'%s' has sane shapes and type size" % skin_id)
	check(names.size() == Ui.SKIN_IDS.size(), "every skin has a different name")
	check(Ui.load_skin("nope") == null and Ui.load_skin("../project") == null, "unknown skin ids are refused")

	Ui.use_skin("dark")
	check(Ui.skin.id == "dark", "use_skin switches the active skin")
	check(Ui.next_skin_id() == "kids", "skins cycle in order")
	Ui.use_skin("kids")
	check(Ui.next_skin_id() == "light", "and wrap around")
	check(Ui.font_size(100) == 112, "the kids skin enlarges type")
	Ui.use_skin("nope")
	check(Ui.skin.id == Ui.DEFAULT_SKIN, "an unknown id falls back to the default skin")
	check(Ui.build_theme().default_font != null, "the theme carries the game font")
	check(Ui.format_time(75.9) == "1:15" and Ui.format_time(-3.0) == "0:00", "times are shown as m:ss")


func _readable(skin: GameSkin, what: String, ink: Color, paper: Color, minimum: float) -> void:
	var ratio := Ui.contrast(ink, paper)
	check(ratio >= minimum, "%s: %s is readable (%.1f, needs %.1f)" % [skin.id, what, ratio, minimum])
