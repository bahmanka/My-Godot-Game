extends Node2D
# Skyward: Operation Northern Wind - prototype v4
# Game logic. Drawing lives in world_view.gd and hud.gd.

enum State { MENU, UPGRADE, PLAYING, PAUSED, WON, LOST }

const GROUND_MARGIN := 120.0
const ROTATE_FRAC := 0.72          # takeoff speed as a fraction of vmax
const STALL_FRAC := 0.8            # below this the plane starts to sink
const GROUND_ACCEL := 85.0
const SOFT_LANDING_VY := 150.0
const CRASH_VY := 250.0
const CEILING := 950.0             # px of altitude where climbing power reaches zero
const SAVE_PATH := "user://skyward_save.cfg"
const UPGRADE_MAX := 5

var state: int = State.MENU
var screen := Vector2(1280, 720)
var ground_y := 600.0
var time := 0.0

# progress (saved)
var unlocked := 1
var credits := 0
var upg := {"ammo": 0, "bombs": 0, "fuel": 0, "armor": 0}

# flight state
var distance := 0.0
var speed := 0.0
var player := Vector2(345, 560)
var vy := 0.0
var cam_y := 0.0
var on_ground := true
var landed_mode := 0         # 0 none, 1 final landing roll, 2 refuel strip
var braking := false
var refuel_t := 0.0
var refueled := false
var lift_grace := 0.0
var health := 100.0
var fuel := 100.0
var ammo := 0
var bombs_left := 0
var plane_idx := 0
var plane: Dictionary = AircraftData.LIST[0]
var score := 0
var targets_down := 0
var targets_total := 0
var checkpoint := 0
var cp_score := 0
var cp_down := 0
var fail_reason := ""
var fail_fa := ""
var message := ""
var message_fa := ""
var message_t := 0.0
var zone_name := ""
var zone_fa := ""
var zone_t := 0.0
var shake := 0.0
var hit_flash := 0.0
var shoot_cd := 0.0
var burst_left := 0
var burst_t := 0.0
var muzzle_t := 0.0
var bomb_req := 0
var bomb_cd := 0.0
var fuel_warned := 0
var landing_announced := false
var earned := 0
var new_unlock := false

var targets: Array = []
var enemies: Array = []
var bullets: Array = []
var ebullets: Array = []
var bombs: Array = []
var parts: Array = []
var crates: Array = []
var wrecks: Array = []
var triggers: Array = []

# input (filled by _gather_input, or set directly by tests)
var in_up := false
var in_down := false
var in_left := false
var in_right := false
var in_fire := false
var touches := {}
var touch_dir := Vector2.ZERO

var test_mode := false
var rng := RandomNumberGenerator.new()
var _tex_cache := {}
var world_view: Node2D
var hud_view: Node2D

func _ready() -> void:
	world_view = preload("res://scripts/world_view.gd").new()
	hud_view = preload("res://scripts/hud.gd").new()
	world_view.set("game", self)
	hud_view.set("game", self)
	add_child(world_view)
	add_child(hud_view)
	get_tree().root.size_changed.connect(_on_resize)
	_on_resize()
	load_save()
	reset_game()

func _on_resize() -> void:
	screen = get_viewport_rect().size
	ground_y = screen.y - GROUND_MARGIN

func tex(n: String) -> Texture2D:
	if not _tex_cache.has(n):
		_tex_cache[n] = load("res://assets/%s.png" % n)
	return _tex_cache[n]

# ---------------------------------------------------------------- save / upgrades

func load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	unlocked = clampi(int(cf.get_value("p", "unlocked", 1)), 1, AircraftData.LIST.size())
	credits = int(cf.get_value("p", "credits", 0))
	for k in upg:
		upg[k] = clampi(int(cf.get_value("u", k, 0)), 0, UPGRADE_MAX)

func save_game() -> void:
	if test_mode:
		return
	var cf := ConfigFile.new()
	cf.set_value("p", "unlocked", unlocked)
	cf.set_value("p", "credits", credits)
	for k in upg:
		cf.set_value("u", k, upg[k])
	cf.save(SAVE_PATH)

func upgrade_cost(key: String) -> int:
	return 300 * (int(upg[key]) + 1)

func buy_upgrade(key: String) -> void:
	if int(upg[key]) >= UPGRADE_MAX:
		return
	var c := upgrade_cost(key)
	if credits >= c:
		credits -= c
		upg[key] += 1
		save_game()

func ammo_cap() -> int: return int(plane.ammo) + int(upg.ammo) * 2
func bomb_cap() -> int: return int(plane.bombs) + int(upg.bombs)
func fuel_cap() -> float: return float(plane.fuel) * (1.0 + 0.12 * float(upg.fuel))
func hp_cap() -> float: return float(plane.hp) * (1.0 + 0.12 * float(upg.armor))

# ---------------------------------------------------------------- setup

func _wheel_off() -> float:
	return plane.width * 0.19

func reset_game(from_checkpoint: bool = false) -> void:
	plane = AircraftData.LIST[plane_idx]
	player = Vector2(screen.x * 0.27, ground_y - _wheel_off())
	distance = 0.0
	speed = 0.0
	vy = 0.0
	cam_y = 0.0
	on_ground = true
	landed_mode = 0
	braking = false
	refuel_t = 0.0
	lift_grace = 0.0
	health = hp_cap()
	fuel = fuel_cap()
	ammo = ammo_cap()
	bombs_left = bomb_cap()
	score = 0
	targets_down = 0
	fail_reason = ""
	message = ""
	message_t = 0.0
	zone_name = ""
	shake = 0.0
	hit_flash = 0.0
	shoot_cd = 0.0
	burst_left = 0
	muzzle_t = 0.0
	bomb_req = 0
	bomb_cd = 0.0
	fuel_warned = 0
	landing_announced = false
	refueled = false
	earned = 0
	new_unlock = false
	enemies.clear()
	bullets.clear()
	ebullets.clear()
	bombs.clear()
	parts.clear()
	wrecks.clear()
	touches.clear()
	touch_dir = Vector2.ZERO
	_build_world()
	if from_checkpoint and checkpoint == 1:
		var start_x := Terrain.RUNWAY_C_START + 250.0
		distance = start_x - player.x
		player.y = surf(start_x) - _wheel_off()
		score = cp_score
		targets_down = cp_down
		refueled = true
		for t in targets:
			if t.x < start_x + 400.0:
				t.alive = false
		for tr in triggers:
			if tr.x < start_x + 400.0:
				tr.done = true
		for c in crates:
			if c.x < start_x:
				c.taken = true
		say("Back at the airstrip - take off when ready", "از باند متروکه دوباره شروع کن", 3.0)
	else:
		checkpoint = 0
		cp_score = 0
		cp_down = 0

func _build_world() -> void:
	rng.seed = 1914
	targets.clear()
	crates.clear()
	triggers.clear()
	# farmland
	_add_soldiers(3100.0, 3)
	_add_target("truck", 4000.0, 50.0)
	_add_target("truck", 4140.0, 50.0)
	_add_target("truck", 4700.0, 45.0)
	_add_soldiers(5200.0, 3)
	_add_target("aa", 6000.0)
	_add_target("truck", 6300.0, 40.0)
	# forest hills
	_add_target("aa", 7600.0)
	_add_soldiers(8400.0, 4)
	_add_target("tower", 9400.0)
	_add_target("aa", 10200.0)
	_add_soldiers(10800.0, 2)
	# mountains
	_add_target("aa", 12200.0)
	_add_target("aa", 13600.0)
	_add_soldiers(14200.0, 3)
	_add_target("aa", 15200.0)
	_add_target("tower", 16000.0)
	# sea and bridge (trucks sit on the bridge deck)
	_add_target("ship", 22900.0)
	var b1 := _add_target("truck", 24150.0, 0.0)
	b1.deck = true
	var b2 := _add_target("truck", 24420.0, 0.0)
	b2.deck = true
	_add_target("ship", 25700.0)
	_add_target("ship", 26700.0)
	# enemy base
	_add_soldiers(28300.0, 3)
	_add_target("tower", 28500.0)
	_add_target("aa", 28000.0)
	_add_target("aa", 28700.0)
	_add_target("fuel", 29000.0)
	_add_target("fuel", 29260.0)
	_add_target("aa", 29600.0)
	var p1 := _add_target("parked", 29900.0)
	p1.ptex = "buffalo"
	_add_target("hangar", 30350.0)
	var p2 := _add_target("parked", 30800.0)
	p2.ptex = "i16"
	_add_target("aa", 30950.0)
	_add_target("hangar", 31250.0)
	_add_soldiers(29800.0, 3)
	_add_soldiers(31500.0, 3)
	_add_target("aa", 31650.0)
	_add_target("tower", 32000.0)
	_add_target("aa", 32250.0)
	_add_target("truck", 28900.0, 45.0)
	targets_total = 0
	for t in targets:
		if t.kind != "soldier":
			targets_total += 1
	for cx in [5000.0, 9800.0, 26200.0]:
		crates.append({"x": cx, "y": -1.0, "taken": false})
	for tr in [[4500.0, ["fighter"]], [8800.0, ["fighter"]], [12500.0, ["fighter", "fighter"]],
			[15000.0, ["fighter"]], [22300.0, ["fighter", "fighter"]], [24800.0, ["bomber"]],
			[28100.0, ["fighter", "bomber"]], [30200.0, ["ace"]], [32000.0, ["fighter"]]]:
		triggers.append({"x": tr[0], "kinds": tr[1], "done": false})

func _add_target(kind: String, x: float, vx: float = 0.0) -> Dictionary:
	var info := target_info(kind)
	var t := {"kind": kind, "x": x, "hp": info.hp, "maxhp": info.hp, "alive": true, "vx": vx,
		"fire_t": rng.randf_range(1.0, 3.0), "flash": 0.0, "deck": false, "ptex": "buffalo"}
	targets.append(t)
	return t

func _add_soldiers(x: float, n: int) -> void:
	for i in range(n):
		_add_target("soldier", x + float(i) * 24.0 + rng.randf_range(-6.0, 6.0))

func target_info(kind: String) -> Dictionary:
	match kind:
		"aa": return {"w": 60.0, "h": 66.0, "hp": 3.0, "score": 100, "tex": "aa"}
		"tower": return {"w": 46.0, "h": 100.0, "hp": 3.0, "score": 80, "tex": "tower"}
		"ship": return {"w": 170.0, "h": 74.0, "hp": 6.0, "score": 150, "tex": "ship"}
		"truck": return {"w": 74.0, "h": 38.0, "hp": 3.0, "score": 60, "tex": ""}
		"hangar": return {"w": 170.0, "h": 100.0, "hp": 9.0, "score": 250, "tex": ""}
		"fuel": return {"w": 56.0, "h": 66.0, "hp": 3.0, "score": 120, "tex": ""}
		"parked": return {"w": 150.0, "h": 56.0, "hp": 2.0, "score": 120, "tex": "buffalo"}
	return {"w": 16.0, "h": 30.0, "hp": 1.0, "score": 15, "tex": ""}

# ---------------------------------------------------------------- helpers

func world_x() -> float:
	return distance + player.x

func surf(x: float) -> float:
	return Terrain.surface_y(x, ground_y)

func target_ground(t: Dictionary) -> float:
	if t.deck:
		return ground_y - 38.0
	return surf(t.x)

func target_rect(t: Dictionary) -> Rect2:
	var info := target_info(t.kind)
	var g := target_ground(t)
	return Rect2(t.x - info.w * 0.5, g - info.h, info.w, info.h)

func say(en: String, fa: String = "", secs: float = 2.5) -> void:
	message = en
	message_fa = fa
	message_t = secs

func progress() -> float:
	return clampf(world_x() / Terrain.RUNWAY_B_START, 0.0, 1.0)

func objective() -> Array:
	var wx := world_x()
	if on_ground and landed_mode == 0 and wx < Terrain.RUNWAY_A_END + 600.0 and checkpoint == 0:
		return ["Take off and reach point B", "بلند شو و به نقطه B برس"]
	if not refueled and fuel < fuel_cap() * 0.4 and wx < Terrain.RUNWAY_C_END:
		return ["Land at the abandoned airstrip to refuel", "برای سوخت‌گیری در باند متروکه فرود بیا"]
	if wx < 27600.0:
		return ["Fly to the enemy base", "به سمت پایگاه دشمن پرواز کن"]
	if wx < Terrain.LAND_ANNOUNCE:
		return ["Destroy the enemy airfield", "پایگاه دشمن را نابود کن"]
	return ["Land at point B", "در نقطه B فرود بیا"]

func fuel_frac() -> float:
	return clampf(fuel / fuel_cap(), 0.0, 1.0)

# ---------------------------------------------------------------- particles

func _p(kind: String, x: float, y: float, vx: float, vy_: float, life: float, size: float, col: Color,
		grav: float = 0.0, drag: float = 0.0, rot: float = 0.0, vr: float = 0.0) -> void:
	if parts.size() > 650:
		parts.remove_at(0)
	parts.append({"kind": kind, "x": x, "y": y, "vx": vx, "vy": vy_, "life": life, "t": 0.0, "size": size,
		"col": col, "grav": grav, "drag": drag, "rot": rot, "vr": vr, "tr": 0.0})

func fx_text(txt: String, x: float, y: float, col: Color = Color(0.96, 0.88, 0.6)) -> void:
	parts.append({"kind": "text", "x": x, "y": y, "vx": 0.0, "vy": -46.0, "life": 1.3, "t": 0.0, "size": 20.0,
		"col": col, "grav": 0.0, "drag": 0.0, "rot": 0.0, "vr": 0.0, "tr": 0.0, "txt": txt})

func fx_hit_air(x: float, y: float) -> void:
	for i in range(9):
		var a := rng.randf_range(0.0, TAU)
		var s := rng.randf_range(120.0, 380.0)
		_p("spark", x, y, cos(a) * s, sin(a) * s, rng.randf_range(0.15, 0.35), 1.0, Color(1.0, 0.9, 0.55), 500.0, 1.5)
	for i in range(3):
		_p("debris", x, y, rng.randf_range(-160.0, 160.0), rng.randf_range(-200.0, -20.0), rng.randf_range(0.5, 0.9),
			rng.randf_range(2.5, 4.5), Color(0.36, 0.36, 0.33), 600.0, 0.5, 0.0, rng.randf_range(-12.0, 12.0))
	_p("flash", x, y, 0.0, 0.0, 0.09, 16.0, Color(1.0, 0.95, 0.7))
	_p("smoke", x, y, 30.0, -20.0, 0.7, 9.0, Color(0.16, 0.15, 0.14))

func fx_hit_ground(x: float, y: float) -> void:
	for i in range(4):
		_p("dirt", x, y, rng.randf_range(-90.0, 90.0), rng.randf_range(-200.0, -60.0), rng.randf_range(0.4, 0.8),
			rng.randf_range(2.0, 3.5), Color(0.38, 0.30, 0.2), 700.0, 0.3, 0.0, rng.randf_range(-10.0, 10.0))
	_p("dust", x, y, rng.randf_range(-30.0, 30.0), -30.0, 0.6, 12.0, Color(0.55, 0.48, 0.38))

func fx_bomb(x: float, y: float, power: float = 1.0) -> void:
	_p("flash", x, y - 10.0, 0.0, 0.0, 0.2, 80.0 * power, Color(1.0, 0.9, 0.6))
	_p("ring", x, y, 0.0, 0.0, 0.5, 120.0 * power, Color(1.0, 0.85, 0.5))
	for i in range(7):
		_p("fire", x + rng.randf_range(-30.0, 30.0) * power, y - rng.randf_range(0.0, 30.0), rng.randf_range(-60.0, 60.0),
			rng.randf_range(-170.0, -50.0), rng.randf_range(0.5, 0.9), rng.randf_range(22.0, 40.0) * power, Color(1.0, 0.7, 0.2))
	for i in range(int(16.0 * power)):
		var a := rng.randf_range(PI * 1.1, PI * 1.9)
		var s := rng.randf_range(120.0, 420.0)
		_p("dirt", x, y, cos(a) * s, sin(a) * s, rng.randf_range(0.7, 1.3), rng.randf_range(3.0, 7.0),
			Color(0.36, 0.28, 0.19), 700.0, 0.3, 0.0, rng.randf_range(-12.0, 12.0))
	for i in range(8):
		_p("dust", x + rng.randf_range(-40.0, 40.0), y - rng.randf_range(0.0, 12.0), rng.randf_range(-90.0, 90.0),
			rng.randf_range(-60.0, -10.0), rng.randf_range(0.9, 1.6), rng.randf_range(26.0, 46.0) * power, Color(0.55, 0.48, 0.38))
	for i in range(5):
		_p("smoke", x + rng.randf_range(-30.0, 30.0), y - rng.randf_range(10.0, 40.0), rng.randf_range(-20.0, 30.0),
			rng.randf_range(-90.0, -40.0), rng.randf_range(1.4, 2.4), rng.randf_range(24.0, 38.0) * power, Color(0.12, 0.11, 0.1))
	shake = maxf(shake, 6.0 * power)

func fx_air_blast(x: float, y: float, power: float = 1.0) -> void:
	_p("flash", x, y, 0.0, 0.0, 0.18, 70.0 * power, Color(1.0, 0.92, 0.65))
	_p("ring", x, y, 0.0, 0.0, 0.45, 100.0 * power, Color(1.0, 0.8, 0.45))
	for i in range(6):
		_p("fire", x + rng.randf_range(-24.0, 24.0) * power, y + rng.randf_range(-18.0, 18.0) * power,
			rng.randf_range(-70.0, 70.0), rng.randf_range(-80.0, 20.0), rng.randf_range(0.5, 0.9), rng.randf_range(20.0, 36.0) * power, Color(1.0, 0.65, 0.2))
	for i in range(5):
		_p("smoke", x + rng.randf_range(-20.0, 20.0), y + rng.randf_range(-10.0, 10.0), rng.randf_range(-30.0, 30.0),
			rng.randf_range(-70.0, -20.0), rng.randf_range(1.4, 2.4), rng.randf_range(22.0, 34.0) * power, Color(0.12, 0.11, 0.1))
	for i in range(10):
		var a := rng.randf_range(0.0, TAU)
		var s := rng.randf_range(100.0, 380.0)
		_p("debris", x, y, cos(a) * s, sin(a) * s, rng.randf_range(0.8, 1.5), rng.randf_range(2.5, 5.0),
			Color(0.3, 0.3, 0.28) if i % 2 == 0 else Color(0.9, 0.5, 0.2), 500.0, 0.3, 0.0, rng.randf_range(-12.0, 12.0))
	shake = maxf(shake, 4.0 * power)

# splits a sprite into flying, burning pieces
func fx_break(tex_name: String, x: float, y: float, w: float, flip: bool, vx_: float, vy_: float, cols: int = 3, rows: int = 2, rot: float = 0.0) -> void:
	var t := tex(tex_name)
	var tw := float(t.get_width())
	var th := float(t.get_height())
	var h := w * th / tw
	var pw := w / float(cols)
	var ph := h / float(rows)
	for r in range(rows):
		for c in range(cols):
			var cx := (float(c) - float(cols - 1) * 0.5) * pw
			var cy := (float(r) - float(rows - 1) * 0.5) * ph
			if flip:
				cx = -cx
			var d := Vector2(cx, cy)
			var vel := Vector2(vx_, vy_) * 0.4 + d.normalized() * rng.randf_range(80.0, 240.0) + Vector2(0.0, -rng.randf_range(40.0, 160.0))
			parts.append({"kind": "frag", "tex": tex_name, "src": Rect2(float(c) * tw / float(cols), float(r) * th / float(rows), tw / float(cols), th / float(rows)),
				"pw": pw, "ph": ph, "flip": flip, "x": x + cx, "y": y + cy, "vx": vel.x, "vy": vel.y,
				"life": rng.randf_range(1.6, 2.6), "t": 0.0, "grav": 520.0, "drag": 0.2, "rot": rot, "vr": rng.randf_range(-6.0, 6.0),
				"tr": 0.0, "size": 1.0, "col": Color(1, 1, 1)})

func _update_particles(dt: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var p: Dictionary = parts[i]
		p.t += dt
		if p.t >= p.life:
			parts.remove_at(i)
			continue
		p.vy += p.grav * dt
		p.vx *= maxf(0.0, 1.0 - p.drag * dt)
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.rot += p.vr * dt
		if p.kind == "frag":
			p.tr -= dt
			if p.tr <= 0.0:
				p.tr = 0.06
				_p("smoke", p.x, p.y, rng.randf_range(-15.0, 15.0), -25.0, 0.8, 8.0, Color(0.13, 0.12, 0.11))
				if p.t < 1.0:
					_p("fire", p.x, p.y, 0.0, -20.0, 0.3, 8.0, Color(1.0, 0.65, 0.2))
			var s := surf(p.x)
			if p.y > s:
				p.y = s
				p.vy = -p.vy * 0.25
				p.vx *= 0.5
				p.vr *= 0.5

# ---------------------------------------------------------------- input

func dpad_center() -> Vector2: return Vector2(150.0, screen.y - 150.0)
func fire_center() -> Vector2: return Vector2(screen.x - 120.0, screen.y - 130.0)
func bomb_center() -> Vector2: return Vector2(screen.x - 258.0, screen.y - 92.0)
func pause_center() -> Vector2: return Vector2(screen.x - 52.0, screen.y - 262.0)
func menu_left() -> Rect2: return Rect2(screen.x * 0.5 - 300.0, screen.y * 0.5 - 60.0, 70.0, 90.0)
func menu_right() -> Rect2: return Rect2(screen.x * 0.5 + 230.0, screen.y * 0.5 - 60.0, 70.0, 90.0)
func menu_start() -> Rect2: return Rect2(screen.x * 0.5 - 250.0, screen.y * 0.5 + 170.0, 270.0, 56.0)
func menu_upgrade() -> Rect2: return Rect2(screen.x * 0.5 + 40.0, screen.y * 0.5 + 170.0, 210.0, 56.0)
func upg_row(i: int) -> Rect2: return Rect2(screen.x * 0.5 - 300.0, screen.y * 0.5 - 150.0 + float(i) * 70.0, 600.0, 60.0)
func upg_back() -> Rect2: return Rect2(screen.x * 0.5 - 100.0, screen.y * 0.5 + 150.0, 200.0, 50.0)
func ov_retry() -> Rect2: return Rect2(screen.x * 0.5 - 240.0, screen.y * 0.64, 220.0, 54.0)
func ov_hangar() -> Rect2: return Rect2(screen.x * 0.5 + 20.0, screen.y * 0.64, 220.0, 54.0)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event.keycode)

func _key(code: int) -> void:
	match state:
		State.MENU:
			if code == KEY_LEFT or code == KEY_A:
				_cycle_plane(-1)
			elif code == KEY_RIGHT or code == KEY_D:
				_cycle_plane(1)
			elif code == KEY_ENTER or code == KEY_SPACE:
				start_game()
			elif code == KEY_U:
				state = State.UPGRADE
		State.UPGRADE:
			if code == KEY_ESCAPE or code == KEY_ENTER:
				state = State.MENU
			elif code >= KEY_1 and code <= KEY_4:
				buy_upgrade(["ammo", "bombs", "fuel", "armor"][code - KEY_1])
		State.PLAYING:
			if code == KEY_P or code == KEY_ESCAPE:
				state = State.PAUSED
			elif code == KEY_B or code == KEY_CTRL:
				bomb_req += 1
		State.PAUSED:
			if code == KEY_P or code == KEY_ESCAPE or code == KEY_ENTER:
				state = State.PLAYING
		State.WON:
			if code == KEY_ENTER or code == KEY_SPACE:
				to_menu()
		State.LOST:
			if code == KEY_ENTER or code == KEY_SPACE:
				start_game(true)
			elif code == KEY_ESCAPE:
				to_menu()

func to_menu() -> void:
	state = State.MENU
	checkpoint = 0
	reset_game()

func _cycle_plane(d: int) -> void:
	plane_idx = (plane_idx + d + AircraftData.LIST.size()) % AircraftData.LIST.size()
	plane = AircraftData.LIST[plane_idx]

func start_game(from_checkpoint: bool = false) -> void:
	if plane_idx >= unlocked:
		return
	reset_game(from_checkpoint)
	state = State.PLAYING
	if not from_checkpoint:
		say("Full throttle - hold UP at takeoff speed", "گاز کامل - در سرعت برخاست دکمه‌ی بالا را نگه دار", 3.5)

func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	if not pressed:
		touches.erase(idx)
		if not touches.values().has("dpad"):
			touch_dir = Vector2.ZERO
		return
	match state:
		State.MENU:
			if menu_left().has_point(pos): _cycle_plane(-1)
			elif menu_right().has_point(pos): _cycle_plane(1)
			elif menu_start().has_point(pos): start_game()
			elif menu_upgrade().has_point(pos): state = State.UPGRADE
		State.UPGRADE:
			for i in range(4):
				if upg_row(i).has_point(pos):
					buy_upgrade(["ammo", "bombs", "fuel", "armor"][i])
			if upg_back().has_point(pos):
				state = State.MENU
		State.PAUSED:
			state = State.PLAYING
		State.WON:
			to_menu()
		State.LOST:
			if ov_retry().has_point(pos): start_game(true)
			elif ov_hangar().has_point(pos): to_menu()
		State.PLAYING:
			if pos.distance_to(pause_center()) < 40.0:
				state = State.PAUSED
			elif pos.distance_to(fire_center()) < 80.0:
				touches[idx] = "fire"
			elif pos.distance_to(bomb_center()) < 60.0:
				touches[idx] = "bomb"
				bomb_req += 1
			elif pos.distance_to(dpad_center()) < 135.0:
				touches[idx] = "dpad"
				_drag(idx, pos)

func _drag(idx: int, pos: Vector2) -> void:
	if touches.has(idx) and touches[idx] == "dpad":
		touch_dir = ((pos - dpad_center()) / 70.0).limit_length(1.0)

func _gather_input() -> void:
	in_up = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or touch_dir.y < -0.3
	in_down = Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or touch_dir.y > 0.3
	in_left = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or touch_dir.x < -0.4
	in_right = Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or touch_dir.x > 0.4
	in_fire = Input.is_key_pressed(KEY_SPACE) or touches.values().has("fire")

# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	time += delta
	if state == State.PLAYING and not test_mode:
		_gather_input()
		step(minf(delta, 0.05))
	elif state == State.WON or state == State.LOST:
		_update_particles(minf(delta, 0.05))
	world_view.queue_redraw()
	hud_view.queue_redraw()

func step(dt: float) -> void:
	player.x = screen.x * 0.27
	shoot_cd = maxf(0.0, shoot_cd - dt)
	bomb_cd = maxf(0.0, bomb_cd - dt)
	lift_grace = maxf(0.0, lift_grace - dt)
	message_t = maxf(0.0, message_t - dt)
	zone_t = maxf(0.0, zone_t - dt)
	muzzle_t = maxf(0.0, muzzle_t - dt)
	shake = maxf(0.0, shake - dt * 14.0)
	hit_flash = maxf(0.0, hit_flash - dt * 3.0)

	_update_flight(dt)
	if state != State.PLAYING:
		return
	var cam_target := maxf(0.0, screen.y * 0.36 - player.y)
	cam_y = lerpf(cam_y, cam_target, 1.0 - exp(-4.0 * dt))
	_update_zone()
	_update_weapons(dt)
	_update_triggers()
	_update_enemies(dt)
	_update_targets(dt)
	_update_crates()
	_update_particles(dt)
	_damage_smoke(dt)
	if health <= 0.0 and state == State.PLAYING:
		_lose("SHOT DOWN", "سرنگون شدی")

func _update_zone() -> void:
	var z := Terrain.zone_name(world_x())
	if z != zone_name:
		zone_name = z
		zone_fa = Terrain.zone_fa(world_x())
		zone_t = 3.0

func _lose(reason: String, fa: String = "") -> void:
	if state != State.PLAYING:
		return
	state = State.LOST
	fail_reason = reason
	fail_fa = fa
	fx_break(plane.tex, world_x(), player.y, plane.width, false, speed, vy)
	fx_air_blast(world_x(), player.y, 1.5)
	shake = 10.0
	earned = score / 2
	credits += earned
	save_game()

func _win() -> void:
	state = State.WON
	say("MISSION COMPLETE", "مأموریت موفق", 4.0)
	earned = score + 500
	credits += earned
	new_unlock = unlocked < AircraftData.LIST.size() and plane_idx == unlocked - 1
	if new_unlock:
		unlocked += 1
	save_game()

# ---------------------------------------------------------------- flight

func _update_flight(dt: float) -> void:
	var vmax: float = plane.vmax
	var rot_v := vmax * ROTATE_FRAC
	var wx := world_x()
	var off := _wheel_off()
	var fuel_out := fuel <= 0.0

	# --- fuel
	if not on_ground:
		fuel = maxf(0.0, fuel - (0.5 + 0.4 * speed / vmax) * dt * (1.1 if plane.tex == "buffalo" else 1.0))
		var f := fuel_frac()
		if f < 0.25 and fuel_warned < 1:
			fuel_warned = 1
			say("LOW FUEL", "سوخت کم است", 2.5)
		if f < 0.1 and fuel_warned < 2:
			fuel_warned = 2
			say("FUEL CRITICAL", "سوخت بحرانی", 2.5)

	# --- speed
	var target := vmax * 0.9
	var accel := 50.0
	if on_ground:
		accel = GROUND_ACCEL
		if braking or landed_mode != 0:
			target = 0.0
			accel = 60.0
	else:
		var assist := Terrain.runway_near(wx) or wx > Terrain.LAND_ANNOUNCE
		if fuel_out:
			target = 0.0
			accel = 25.0
		elif in_left:
			target = vmax * 0.45
			accel = 90.0
		elif in_right:
			target = vmax
			accel = 70.0
		elif assist and (surf(wx) - (player.y + off)) < 280.0:
			target = vmax * 0.66
			accel = 30.0
	speed = move_toward(speed, target, accel * dt)
	distance += speed * dt
	wx = world_x()

	# --- ground roll
	if on_ground:
		player.y = surf(wx) - off
		vy = 0.0
		if landed_mode == 1:
			if speed < 6.0:
				_win()
			return
		if landed_mode == 2:
			_refuel_tick(dt)
			return
		if speed >= rot_v:
			if in_up:
				on_ground = false
				vy = -60.0
				lift_grace = 0.6
				say("AIRBORNE", "در هوا", 1.2)
		elif in_up and speed > 20.0:
			say("TOO SLOW - wait for speed", "سرعت کم است", 0.8)
		if on_ground and wx > Terrain.RUNWAY_A_ABORT and checkpoint == 0:
			_lose("RAN OUT OF RUNWAY", "باند تمام شد")
		elif on_ground and checkpoint == 1 and wx > Terrain.RUNWAY_C_END + 500.0:
			_lose("RAN OUT OF RUNWAY", "باند تمام شد")
		return

	# --- airborne control
	var lift := clampf((speed - vmax * 0.5) / (vmax * (STALL_FRAC - 0.5)), 0.0, 1.0)
	var alt := ground_y - player.y
	var alt_factor := pow(clampf(1.0 - alt / CEILING, 0.0, 1.0), 0.6)
	var climb: float = plane.climb
	var vmax_up := (60.0 + speed * 0.55) * climb * lift * alt_factor
	var vmax_down := 130.0 + (speed / vmax) * 90.0
	var target_vy := 0.0
	if in_up:
		target_vy = -vmax_up
	elif in_down:
		target_vy = vmax_down
	target_vy += (1.0 - lift) * 170.0
	if alt > CEILING:
		target_vy += (alt - CEILING) * 0.6
	vy = move_toward(vy, target_vy, 520.0 * dt)
	player.y += vy * dt
	if lift < 1.0 and message_t <= 0.0:
		if fuel_out:
			say("ENGINE OUT - no fuel", "موتور از کار افتاد", 1.0)
		else:
			say("TOO SLOW - plane is sinking", "سرعت کم است - افت ارتفاع", 0.8)
	elif alt > CEILING * 0.82 and in_up and message_t <= 0.0:
		say("THIN AIR - engine losing power", "هوا رقیق است - توان موتور کم می‌شود", 1.0)

	# --- terrain contact
	wx = world_x()
	var s := surf(wx)
	if player.y + off >= s:
		_touch_ground(wx, s, off)

	if state == State.PLAYING:
		var ahead := surf(wx + 280.0)
		if ahead < player.y + off + 18.0 and message_t <= 0.0 and not Terrain.any_runway(wx + 280.0):
			say("PULL UP!", "بالا بکش!", 0.6)
		if wx > Terrain.LAND_ANNOUNCE and not landing_announced:
			landing_announced = true
			say("AIRFIELD B AHEAD - slow down and descend", "پایگاه B در پیش است - سرعت را کم کن و پایین بیا", 4.0)
		if wx > Terrain.WORLD_END:
			_lose("OVERSHOT THE RUNWAY", "از باند رد شدی")

func _touch_ground(wx: float, s: float, off: float) -> void:
	player.y = s - off
	if lift_grace > 0.0:
		vy = minf(vy, 0.0)
		return
	var on_b := Terrain.in_runway_b(wx)
	var on_c := Terrain.in_runway_c(wx)
	var on_a := Terrain.in_runway_a(wx)
	if not (on_a or on_b or on_c):
		if Terrain.sea_w(wx) > 0.5:
			_lose("SPLASHDOWN", "سقوط در دریا")
		else:
			_lose("CRASHED INTO THE TERRAIN", "برخورد با زمین")
		return
	var too_fast: bool = speed > float(plane.vmax) * 0.88
	if vy > CRASH_VY:
		_lose("CRASHED ON LANDING", "فرود سخت و سقوط")
	elif vy > SOFT_LANDING_VY or too_fast:
		health -= 40.0
		hit_flash = 1.0
		shake = 8.0
		vy = -120.0
		lift_grace = 0.5
		fx_hit_ground(wx, s)
		fx_bomb(wx, s, 0.5)
		say("HARD LANDING - slow down, descend gently", "فرود سخت - سرعت را کم کن", 2.0)
		if health <= 0.0:
			_lose("CRASHED ON LANDING", "فرود سخت و سقوط")
	else:
		on_ground = true
		vy = 0.0
		if on_b:
			landed_mode = 1
			score += 300
			say("TOUCHDOWN - braking", "فرود موفق", 2.0)
		elif on_c:
			landed_mode = 2
			refuel_t = 0.0
			checkpoint = 1
			cp_score = score
			cp_down = targets_down
			say("TOUCHDOWN - refueling", "فرود موفق - سوخت‌گیری", 2.0)
		else:
			say("Back on the runway", "دوباره روی باند", 1.5)

func _refuel_tick(dt: float) -> void:
	if speed > 5.0:
		return
	refuel_t += dt
	fuel = minf(fuel_cap(), fuel + 38.0 * dt)
	health = minf(hp_cap(), health + 14.0 * dt)
	if int(refuel_t * 2.0) != int((refuel_t - dt) * 2.0):
		if ammo < ammo_cap(): ammo += 1
		if bombs_left < bomb_cap() and int(refuel_t * 2.0) % 2 == 0: bombs_left += 1
	if refuel_t > 2.2 and fuel >= fuel_cap() - 0.5 and ammo >= ammo_cap() and bombs_left >= bomb_cap():
		landed_mode = 0
		braking = false
		refueled = true
		fuel_warned = 0
		say("READY - hold UP at takeoff speed", "آماده - برای برخاستن دکمه‌ی بالا را نگه دار", 3.5)

# ---------------------------------------------------------------- weapons

func _update_weapons(dt: float) -> void:
	var wx := world_x()
	var rot := clampf(vy / 520.0, -0.32, 0.32)
	if not on_ground:
		if in_fire and burst_left == 0 and shoot_cd <= 0.0:
			if ammo > 0:
				ammo -= 1
				burst_left = 3
				burst_t = 0.0
				shoot_cd = plane.fire_cd + 0.2
			else:
				say("OUT OF AMMO", "مهمات تمام شد", 1.0)
				shoot_cd = 0.6
		if burst_left > 0:
			burst_t -= dt
			if burst_t <= 0.0:
				burst_left -= 1
				burst_t = 0.065
				var ang := rot + rng.randf_range(-0.012, 0.012)
				bullets.append({"x": wx + plane.width * 0.2, "y": player.y - 3.0 + sin(rot) * plane.width * 0.2,
					"vx": speed + 760.0 * cos(ang), "vy": 760.0 * sin(ang), "life": 1.0, "age": 0.0})
				muzzle_t = 0.07
	while bomb_req > 0:
		bomb_req -= 1
		if on_ground:
			continue
		if bombs_left > 0:
			bombs_left -= 1
			bombs.append({"x": wx - 6.0 + float(bombs.size() % 3) * 3.0, "y": player.y + 24.0, "vx": speed * 0.95, "vy": 30.0})
		else:
			say("NO BOMBS LEFT", "بمبی نمانده", 1.0)

	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b.x += b.vx * dt
		b.y += b.vy * dt
		b.life -= dt
		b.age += dt
		var dead: bool = b.life <= 0.0 or b.x - distance > screen.x + 60.0
		if not dead and b.y >= surf(b.x) - 2.0:
			fx_hit_ground(b.x, b.y)
			dead = true
		if not dead:
			for e in enemies:
				if absf(b.x - e.x) < e.w * 0.45 and absf(b.y - e.y) < 24.0:
					e.hp -= 1.0
					e.flash = 0.12
					fx_hit_air(b.x, b.y)
					dead = true
					break
		if not dead:
			for t in targets:
				if not t.alive:
					continue
				if target_rect(t).grow(2.0).has_point(Vector2(b.x, b.y)):
					t.hp -= 1.0
					t.flash = 0.12
					if t.kind == "soldier":
						fx_hit_ground(b.x, b.y)
					else:
						fx_hit_air(b.x, b.y)
					dead = true
					if t.hp <= 0.0:
						_kill_target(t)
					break
		if dead:
			bullets.remove_at(i)

	for i in range(bombs.size() - 1, -1, -1):
		var bm: Dictionary = bombs[i]
		bm.x += bm.vx * dt
		bm.vy += 480.0 * dt
		bm.y += bm.vy * dt
		var hit := false
		var air := false
		var s := surf(bm.x)
		if bm.y >= s - 4.0:
			hit = true
		else:
			for e in enemies:
				if absf(bm.x - e.x) < e.w * 0.5 + 18.0 and absf(bm.y - e.y) < 38.0:
					hit = true
					air = true
					break
			if not hit:
				for t in targets:
					if t.alive and t.kind != "soldier" and target_rect(t).grow(6.0).has_point(Vector2(bm.x, bm.y)):
						hit = true
						break
		if hit:
			_explode_bomb(bm.x, minf(bm.y, s), air)
			bombs.remove_at(i)

func _explode_bomb(x: float, y: float, air: bool) -> void:
	if air:
		fx_air_blast(x, y, 1.3)
	else:
		fx_bomb(x, y)
	for e in enemies:
		var d := Vector2(x, y).distance_to(Vector2(e.x, e.y))
		if d < 70.0:
			e.hp -= 10.0
		elif d < 130.0:
			e.hp -= 5.0
		if d < 130.0:
			e.flash = 0.15
	_blast_targets(x, y, 70.0, 130.0)

func _blast_targets(x: float, y: float, r1: float, r2: float) -> void:
	for t in targets:
		if not t.alive:
			continue
		var c := target_rect(t).get_center()
		var d := Vector2(x, y).distance_to(c)
		if t.kind == "soldier":
			if d < r2 + 20.0:
				t.hp = 0.0
		elif d < r1:
			t.hp -= 8.0
		elif d < r2:
			t.hp -= 4.0
		if t.hp <= 0.0:
			_kill_target(t)

func _kill_target(t: Dictionary) -> void:
	if not t.alive:
		return
	t.alive = false
	var info := target_info(t.kind)
	var r := target_rect(t)
	var c := r.get_center()
	if t.kind != "soldier":
		targets_down += 1
	score += int(info.score)
	fx_text("+%d" % int(info.score), t.x, r.position.y - 10.0)
	match t.kind:
		"soldier":
			fx_hit_ground(t.x, r.end.y)
			_p("dust", t.x, r.end.y - 8.0, 0.0, -20.0, 0.7, 14.0, Color(0.5, 0.44, 0.34))
		"aa", "tower", "ship", "parked":
			var tn: String = info.tex
			if t.kind == "parked":
				tn = t.ptex
			var w: float = r.size.x
			if t.kind == "tower":
				w = r.size.y * float(tex("tower").get_width()) / float(tex("tower").get_height())
			var cols := 3
			var rows := 2
			if t.kind == "tower":
				cols = 2
				rows = 3
			fx_break(tn, c.x, c.y, w, false, 0.0, 0.0, cols, rows)
			fx_air_blast(c.x, c.y, 1.0)
			wrecks.append({"x": t.x, "kind": t.kind})
		"fuel":
			fx_bomb(c.x, c.y + 20.0, 1.3)
			fx_air_blast(c.x, c.y, 1.5)
			_blast_targets(c.x, c.y, 120.0, 190.0)
			wrecks.append({"x": t.x, "kind": t.kind})
		"hangar":
			fx_bomb(c.x, c.y + 30.0, 1.8)
			for k in range(6):
				_p("debris", c.x + rng.randf_range(-60.0, 60.0), c.y, rng.randf_range(-200.0, 200.0), rng.randf_range(-320.0, -80.0),
					rng.randf_range(1.0, 1.8), rng.randf_range(5.0, 11.0), Color(0.45, 0.4, 0.32), 600.0, 0.2, 0.0, rng.randf_range(-8.0, 8.0))
			wrecks.append({"x": t.x, "kind": t.kind})
		_:
			fx_bomb(c.x, c.y + 14.0, 0.9)
			wrecks.append({"x": t.x, "kind": t.kind})
	shake = maxf(shake, 5.0)

# ---------------------------------------------------------------- enemies

func _update_triggers() -> void:
	var wx := world_x()
	for tr in triggers:
		if not tr.done and wx >= tr.x:
			tr.done = true
			var n := 0
			for k in tr.kinds:
				_spawn_enemy(k, n)
				n += 1

func _spawn_enemy(kind: String, n: int) -> void:
	var pool := []
	for p in AircraftData.LIST:
		if p.tex != plane.tex and p.tex != "he111":
			pool.append(p.tex)
	var tex_name: String = pool[rng.randi() % pool.size()]
	var hp := 4.0
	var w := 140.0
	var rel := 230.0
	if kind == "bomber":
		tex_name = "he111"
		hp = 9.0
		w = 190.0
		rel = 150.0
	elif kind == "ace":
		tex_name = "buffalo"
		hp = 14.0
		w = 160.0
		rel = 190.0
	var sx := distance + screen.x + 160.0 + float(n) * 260.0
	var by := player.y + rng.randf_range(-150.0, 60.0)
	by = minf(by, surf(sx) - 130.0)
	enemies.append({"tex": tex_name, "x": sx, "base_y": by, "y": by, "vx": speed - rel, "hp": hp, "maxhp": hp, "w": w,
		"t": 0.0, "ph": rng.randf_range(0.0, 6.28), "fire_t": rng.randf_range(0.8, 1.6), "flash": 0.0,
		"kind": kind, "amp": 90.0 if kind == "ace" else 45.0, "tr": 0.0, "pvy": 0.0})
	if kind == "ace":
		say("ENEMY ACE!", "خلبان زبده دشمن!", 2.5)

func _enemy_score(e: Dictionary) -> int:
	if e.kind == "ace": return 600
	if e.kind == "bomber": return 250
	return 120

func _update_enemies(dt: float) -> void:
	var wx := world_x()
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		e.t += dt
		e.flash = maxf(0.0, e.flash - dt)
		e.x += e.vx * dt
		var prev_y: float = e.y
		e.y = e.base_y + sin(e.t * 1.4 + e.ph) * e.amp
		e.y = minf(e.y, surf(e.x) - 60.0)
		e.pvy = (e.y - prev_y) / maxf(dt, 0.001)
		e.fire_t -= dt
		var sx: float = e.x - distance
		if e.fire_t <= 0.0 and sx < screen.x - 60.0 and sx > player.x + 120.0:
			e.fire_t = rng.randf_range(1.3, 2.2) * (0.7 if e.kind == "ace" else 1.0)
			_enemy_shoot(e)
		if e.hp < e.maxhp * 0.5:
			e.tr -= dt
			if e.tr <= 0.0:
				e.tr = 0.07
				_p("smoke", e.x + 40.0, e.y, 20.0, -20.0, 0.9, 10.0, Color(0.13, 0.12, 0.11))
		if e.hp <= 0.0:
			_kill_enemy(e)
			enemies.remove_at(i)
			continue
		if absf(e.x - wx) < e.w * 0.5 + 40.0 and absf(e.y - player.y) < 36.0 and not on_ground:
			health -= 22.0
			hit_flash = 1.0
			shake = 8.0
			e.hp = 0.0
			continue
		if sx < -320.0:
			enemies.remove_at(i)

	for i in range(ebullets.size() - 1, -1, -1):
		var b: Dictionary = ebullets[i]
		b.x += b.vx * dt
		b.y += b.vy * dt
		b.life -= dt
		var dead: bool = b.life <= 0.0
		if not dead and absf(b.x - wx) < 52.0 and absf(b.y - player.y) < 22.0 and not on_ground:
			health -= b.dmg
			hit_flash = 1.0
			shake = maxf(shake, 3.0)
			fx_hit_air(b.x, b.y)
			dead = true
		if not dead and b.y >= surf(b.x):
			dead = true
		if dead:
			ebullets.remove_at(i)

func _kill_enemy(e: Dictionary) -> void:
	var pts := _enemy_score(e)
	score += pts
	fx_text("+%d" % pts, e.x, e.y - 40.0)
	fx_break(e.tex, e.x, e.y, e.w, true, e.vx - speed, e.pvy)
	fx_air_blast(e.x, e.y, 1.3 if e.kind != "fighter" else 1.0)

func _enemy_shoot(e: Dictionary) -> void:
	var from := Vector2(e.x - 60.0, e.y)
	var to := Vector2(world_x(), player.y)
	var dir := (to - from).normalized()
	var n := 3 if e.kind != "fighter" else 2
	for k in range(n):
		var d := dir.rotated(rng.randf_range(-0.08, 0.08))
		ebullets.append({"x": from.x + float(k) * 12.0, "y": from.y, "vx": d.x * 340.0, "vy": d.y * 340.0, "life": 2.4, "dmg": 5.0, "kind": "air"})

func _update_targets(dt: float) -> void:
	var wx := world_x()
	for t in targets:
		if not t.alive:
			continue
		t.flash = maxf(0.0, t.flash - dt)
		if t.vx != 0.0:
			t.x += t.vx * dt
		var sx: float = t.x - distance
		if sx < -120.0 or sx > screen.x + 120.0:
			continue
		t.fire_t -= dt
		if t.fire_t > 0.0 or on_ground:
			continue
		var from := Vector2(t.x, target_ground(t) - 36.0)
		if t.kind == "aa" or t.kind == "ship":
			t.fire_t = rng.randf_range(2.6, 3.8)
			var lead := Vector2(wx + speed * 0.35, player.y)
			var d := (lead - from).normalized().rotated(rng.randf_range(-0.14, 0.14))
			ebullets.append({"x": from.x, "y": from.y, "vx": d.x * 300.0, "vy": d.y * 300.0, "life": 2.6, "dmg": 8.0, "kind": "flak"})
			_p("flash", from.x, from.y, 0.0, 0.0, 0.1, 14.0, Color(1.0, 0.85, 0.5))
		elif t.kind == "soldier":
			t.fire_t = rng.randf_range(1.2, 2.6)
			from = Vector2(t.x, target_ground(t) - 24.0)
			if sx > player.x - 100.0 and absf(player.y - from.y) < 520.0:
				var d2 := (Vector2(wx + speed * 0.2, player.y) - from).normalized().rotated(rng.randf_range(-0.12, 0.12))
				ebullets.append({"x": from.x, "y": from.y, "vx": d2.x * 420.0, "vy": d2.y * 420.0, "life": 1.8, "dmg": 2.5, "kind": "rifle"})
				_p("spark", from.x, from.y, d2.x * 80.0, d2.y * 80.0, 0.1, 1.0, Color(1.0, 0.9, 0.5))

func _update_crates() -> void:
	var wx := world_x()
	for c in crates:
		if c.taken:
			continue
		if c.y < 0.0:
			c.y = ground_y - 300.0
		if absf(c.x - wx) < 60.0 and absf(c.y - player.y) < 60.0 and not on_ground:
			c.taken = true
			ammo = mini(ammo_cap(), ammo + 3)
			bombs_left = mini(bomb_cap(), bombs_left + 1)
			health = minf(hp_cap(), health + 15.0)
			say("SUPPLY CRATE: ammo, bomb, repairs", "جعبه‌ی تدارکات: مهمات، بمب، تعمیر", 2.0)

func _damage_smoke(dt: float) -> void:
	if health < hp_cap() * 0.5 and not on_ground and rng.randf() < dt * (6.0 if health > hp_cap() * 0.25 else 14.0):
		_p("smoke", world_x() - 40.0, player.y + 4.0, -30.0, -24.0, 1.4, 12.0, Color(0.13, 0.12, 0.11))
