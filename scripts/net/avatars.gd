extends RefCounted
## The eight identities a player can take in a room: a colour and an animal
## name. There is no free text anywhere in the LAN game; this closed list is
## what players see of each other.

const NAMES: Array[String] = ["Zorro", "Pulpo", "Rana", "Gato", "León", "Búho", "Panda", "Koala"]
const COLORS: Array[Color] = [
	Color("e8590c"), Color("7048e8"), Color("2f9e44"), Color("e0a000"),
	Color("c2255c"), Color("1c7ed6"), Color("495057"), Color("0ca678"),
]


static func count() -> int:
	return NAMES.size()


static func name_of(avatar: int) -> String:
	return NAMES[clampi(avatar, 0, NAMES.size() - 1)]


static func color_of(avatar: int) -> Color:
	return COLORS[clampi(avatar, 0, COLORS.size() - 1)]


static func initial_of(avatar: int) -> String:
	return name_of(avatar).substr(0, 1)
