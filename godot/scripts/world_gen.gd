## Данные мира: высоты рельефа и цвета, запечённые tools/bake_world.mjs,
## плюс расстановка растительности. Всё статическое — доступно из любого скрипта.
class_name WorldGen
extends RefCounted

const WORLD := 900.0
const HALF := WORLD / 2.0
const WATER := 0.0
const TOWN_Y := 4.0
const TOWN_WALL := 34.0
const TOWN_NAME := "Камнеград"
const FORGE_POS := Vector2(20.0, -19.3)   # вход в кузницу (модель на месте огорода, дверью на юг)
const ALCHEMIST_POS := Vector2(-21.0, 5.4)   # лавка алхимика в Камнеграде (дверью к поперечной улице)
const ALCHEMIST_YAW := PI

static var seg := 0
static var step := 0.0
static var heights := PackedFloat32Array()
static var colors := PackedByteArray()
static var props := {}
static var sites: Array = []

static func load_data() -> void:
	var bytes := FileAccess.get_file_as_bytes("res://data/world.bin")
	seg = bytes.decode_s32(0)
	var n := (seg + 1) * (seg + 1)
	step = WORLD / seg
	heights = bytes.slice(4, 4 + n * 4).to_float32_array()
	colors = bytes.slice(4 + n * 4, 4 + n * 4 + n * 3)
	props = JSON.parse_string(FileAccess.get_file_as_string("res://data/props.json"))
	sites = props["sites"]

static func town_dist(x: float, z: float) -> float:
	return maxf(absf(x), absf(z))

## Высота земли в точке (билинейная интерполяция по сетке)
static func ground_at(x: float, z: float) -> float:
	var fx := clampf((x + HALF) / step, 0.0, seg - 0.001)
	var fz := clampf((z + HALF) / step, 0.0, seg - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var n := seg + 1
	var k := j * n + i
	return lerpf(lerpf(heights[k], heights[k + 1], tx), lerpf(heights[k + n], heights[k + n + 1], tx), tz)

static func normal_y_at(x: float, z: float) -> float:
	var dx := (ground_at(x + 1.0, z) - ground_at(x - 1.0, z)) / 2.0
	var dz := (ground_at(x, z + 1.0) - ground_at(x, z - 1.0)) / 2.0
	return 1.0 / sqrt(1.0 + dx * dx + dz * dz)

static func hex(h: int) -> Color:
	return Color8((h >> 16) & 255, (h >> 8) & 255, h & 255)
