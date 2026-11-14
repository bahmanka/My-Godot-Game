class_name Terrain
extends RefCounted
# World geometry: everything is a function of world X so drawing, collision
# and target placement always agree.

const RUNWAY_A_END := 1800.0
const RUNWAY_A_ABORT := 2400.0
const RUNWAY_C_START := 18000.0      # abandoned refuel airstrip
const RUNWAY_C_END := 20400.0
const LAND_ANNOUNCE := 33800.0
const RUNWAY_B_START := 35200.0
const RUNWAY_B_END := 38400.0
const WORLD_END := 40500.0

static func band(a0: float, a1: float, b0: float, b1: float, x: float) -> float:
	return smoothstep(a0, a1, x) * (1.0 - smoothstep(b0, b1, x))

static func w_farm(x: float) -> float: return band(1800.0, 3200.0, 6500.0, 8500.0, x)
static func w_forest(x: float) -> float: return band(6500.0, 8200.0, 11000.0, 13000.0, x)
static func w_mount(x: float) -> float: return band(11000.0, 13000.0, 16200.0, 17800.0, x)
static func w_valley(x: float) -> float: return band(16800.0, 18000.0, 20800.0, 22200.0, x)
static func sea_w(x: float) -> float: return band(21000.0, 22800.0, 27000.0, 28400.0, x)
static func w_base(x: float) -> float: return band(27400.0, 29200.0, 32200.0, 33600.0, x)

static func forest_w(x: float) -> float:
	return clampf(w_farm(x) * 0.28 + w_forest(x) + w_mount(x) * 0.55 + w_valley(x) * 0.12 + w_base(x) * 0.3, 0.0, 1.0)

static func hills(x: float) -> float:
	var n := 0.5 + 0.5 * (0.55 * sin(x * 0.0021 + 0.3) + 0.30 * sin(x * 0.0053 + 1.7) + 0.15 * sin(x * 0.0127 + 0.4))
	var m := 1.0 - absf(0.6 * sin(x * 0.0016 + 1.0) + 0.4 * sin(x * 0.0041 + 2.0))
	m = pow(clampf(m, 0.0, 1.0), 1.6)
	var flat_base := 1.0 - 0.88 * band(29500.0, 30000.0, 31800.0, 32300.0, x)
	return w_farm(x) * 38.0 * n + w_forest(x) * (35.0 + 75.0 * n) \
		+ w_mount(x) * (310.0 * m * (0.55 + 0.45 * n) + 40.0 * n) + w_base(x) * 85.0 * n * flat_base

static func island(x: float) -> float:
	return 70.0 * pow(maxf(0.0, sin(x * 0.00107 + 0.8)), 12.0)

static func surface_y(x: float, ground: float) -> float:
	var sw := sea_w(x)
	var up := hills(x) * (1.0 - sw) + island(x) * sw
	return ground + 26.0 * sw - up

static func elevation(x: float) -> float:
	var sw := sea_w(x)
	return hills(x) * (1.0 - sw) + island(x) * sw

static func in_runway_a(x: float) -> bool: return x <= RUNWAY_A_END
static func in_runway_b(x: float) -> bool: return x >= RUNWAY_B_START and x <= RUNWAY_B_END
static func in_runway_c(x: float) -> bool: return x >= RUNWAY_C_START and x <= RUNWAY_C_END
static func any_runway(x: float) -> bool: return in_runway_a(x) or in_runway_b(x) or in_runway_c(x)

# a landing runway lies within 1800 px ahead (or underneath)
static func runway_near(x: float) -> bool:
	return (x > RUNWAY_C_START - 1800.0 and x < RUNWAY_C_END) or (x > RUNWAY_B_START - 1800.0 and x < RUNWAY_B_END)

static func zone_name(x: float) -> String:
	if x < 2000.0: return "AIRFIELD A"
	if x < 6800.0: return "FARMLAND"
	if x < 11500.0: return "FOREST HILLS"
	if x < 16800.0: return "MOUNTAINS"
	if x < 21800.0: return "ABANDONED AIRSTRIP"
	if x < 27600.0: return "COASTAL SEA"
	if x < 33600.0: return "ENEMY BASE"
	return "AIRFIELD B"

static func zone_fa(x: float) -> String:
	if x < 2000.0: return "پایگاه A"
	if x < 6800.0: return "زمین‌های کشاورزی"
	if x < 11500.0: return "تپه‌های جنگلی"
	if x < 16800.0: return "کوهستان"
	if x < 21800.0: return "باند متروکه"
	if x < 27600.0: return "ساحل و دریا"
	if x < 33600.0: return "پایگاه دشمن"
	return "پایگاه B"
