extends "res://tools/testing/harness.gd"

const CreditsScreen := preload("res://scripts/credits_screen.gd")


func run() -> void:
	root.size = Vector2i(720, 1280)
	var font_text := CreditsScreen.font_license()
	check(font_text.contains("SIL Open Font License"), "the typeface licence text is available")
	check(font_text.contains("Fredoka"), "and names the typeface")
	var engine_text := CreditsScreen.engine_license()
	check(engine_text.contains("MIT") or engine_text.contains("Permission is hereby granted"),
			"the engine licence text is available")

	var credits: CreditsScreen = CreditsScreen.new()
	root.add_child(credits)
	await process_frame
	await process_frame
	check(credits.find_child("Card_Ilustraciones", true, false) != null, "the credits explain the illustrations")
	var body: Label = credits.find_child("Card_Ilustraciones", true, false).find_child("Body", true, false)
	check(body.text.contains("inteligencia artificial"), "and say they are AI-generated")
	check(credits.find_child("Card_Tipografía", true, false) != null, "the typeface is credited")
	check(credits.find_child("Card_Motordejuego", true, false) != null, "and the engine")
	check(credits.find_child("Card_Derechos", true, false) != null, "with the rights line")

	var card := credits.find_child("Card_Tipografía", true, false)
	var licence: Label = card.find_child("LicenseText", true, false)
	var toggle: Button = card.find_child("LicenseButton", true, false)
	check(licence != null and not licence.visible, "licence texts start hidden")
	toggle.pressed.emit()
	check(licence.visible and toggle.text == "Ocultar la licencia", "the button shows the licence")
	toggle.pressed.emit()
	check(not licence.visible, "and hides it again")

	var asked := {"back": 0}
	credits.back_pressed.connect(func() -> void: asked["back"] += 1)
	(credits.find_child("BackButton", true, false) as Button).pressed.emit()
	check(asked["back"] == 1, "the back button leaves the screen")
