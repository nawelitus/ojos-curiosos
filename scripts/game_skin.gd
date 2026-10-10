extends Resource
## A visual style of the interface. Skins change colours, shapes and type size;
## the scenario illustrations are the same in every skin.
## (Named GameSkin because "Skin" is a native Godot class.)

@export var id: String = ""
@export var display_name: String = ""

@export_group("Background")
@export var background_top: Color = Color.WHITE
@export var background_bottom: Color = Color.WHITE
## Soft shapes floating over the background gradient.
@export var decoration: Color = Color(1, 1, 1, 0.25)
## Text placed directly on the background.
@export var text: Color = Color.BLACK
@export var muted: Color = Color.GRAY

@export_group("Panels")
@export var panel: Color = Color.WHITE
@export var panel_text: Color = Color.BLACK
@export var panel_muted: Color = Color.GRAY

@export_group("Accents")
@export var primary: Color = Color.BLUE
@export var accent: Color = Color.RED
@export var success: Color = Color.GREEN
@export var neutral: Color = Color.GRAY
## Text on primary, accent, success and neutral buttons.
@export var button_text: Color = Color.WHITE
@export var star: Color = Color.YELLOW
@export var star_empty: Color = Color.LIGHT_GRAY

@export_group("Shapes")
@export var corner_radius: int = 28
## Height of the darker lower edge that makes buttons look raised.
@export var button_depth: int = 8
@export var font_scale: float = 1.0
@export var font_weight: int = 600
