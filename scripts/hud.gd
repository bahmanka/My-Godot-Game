extends Node2D
# HUD, touch controls, menus (English main language, Persian subtitles).

var game
var fa_font: Font

const INK := Color(0.16, 0.17, 0.14)
const PAPER_DARK := Color(0.66, 0.58, 0.43)
const RED := Color(0.64, 0.19, 0.14)
const METAL := Color(0.22, 0.23, 0.21)
const CREAM := Color(0.92, 0.87, 0.72)
const AMBER := Color(0.95, 0.7, 0.3)

func _ready() -> void:
	fa_font = load("res://assets/Vazirmatn-Regular.ttf")

func _draw() -> void:
	var g = game
	if g == null:
		return
	var st: int = g.state
	if st == 0:
		_draw_menu()
		return
	if st == 1:
		_draw_upgrades()
		return
	_draw_hud()
	_draw_controls()
	_draw_banners()
	if st == 3:
		_overlay("PAUSED", "توقف", "Tap to resume", "برای ادامه لمس کن")
	elif st == 4:
		_draw_end(true)
	elif st == 5:
		_draw_end(false)

# ---------------------------------------------------------------- helpers

func _font() -> Font:
	return ThemeDB.fallback_font

func _text(s: String, pos: Vector2, size: int, col: Color) -> void:
	draw_string(_font(), pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _ctext(s: String, center: Vector2, size: int, col: Color) -> void:
	var w := _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font(), Vector2(center.x - w * 0.5, center.y + size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _cfa(s: String, center: Vector2, size: int, col: Color) -> void:
	if s == "" or fa_font == null:
		return
	var w := fa_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(fa_font, Vector2(center.x - w * 0.5, center.y + size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _pill(r: Rect2, col: Color) -> void:
	var rad := r.size.y * 0.5
	draw_rect(Rect2(r.position.x + rad, r.position.y, r.size.x - rad * 2.0, r.size.y), col)
	draw_circle(Vector2(r.position.x + rad, r.position.y + rad), rad, col)
	draw_circle(Vector2(r.position.x + r.size.x - rad, r.position.y + rad), rad, col)

func _panel(r: Rect2, col: Color, border: Color) -> void:
	draw_rect(r, col)
	draw_rect(r, border, false, 2.0)

func _bomb_icon(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c, 5.0 * s, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4.5, 0) * s, c + Vector2(4.5, 0) * s, c + Vector2(0, -11) * s]), col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 10) * s, c + Vector2(5, 10) * s, c + Vector2(0, 3) * s]), col)

func _bullet_icon(c: Vector2, s: float, col: Color) -> void:
	draw_rect(Rect2(c.x - 4.0 * s, c.y - 4.0 * s, 8.0 * s, 12.0 * s), col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -4) * s, c + Vector2(4, -4) * s, c + Vector2(0, -12) * s]), col)

func _can_icon(c: Vector2, s: float, col: Color) -> void:
	draw_rect(Rect2(c.x - 6.0 * s, c.y - 7.0 * s, 12.0 * s, 15.0 * s), col)
	draw_rect(Rect2(c.x - 1.0 * s, c.y - 11.0 * s, 8.0 * s, 4.0 * s), col)
	draw_rect(Rect2(c.x - 3.0 * s, c.y - 2.0 * s, 6.0 * s, 4.0 * s), Color(0.1, 0.11, 0.1))

func _lock_icon(c: Vector2, s: float, col: Color) -> void:
	draw_rect(Rect2(c.x - 14.0 * s, c.y - 2.0 * s, 28.0 * s, 22.0 * s), col)
	draw_arc(c + Vector2(0, -2.0 * s), 10.0 * s, PI, TAU, 14, col, 4.0 * s)
	draw_line(c + Vector2(-10.0 * s, -2.0 * s), c + Vector2(-10.0 * s, 2.0 * s), col, 4.0 * s)
	draw_line(c + Vector2(10.0 * s, -2.0 * s), c + Vector2(10.0 * s, 2.0 * s), col, 4.0 * s)
	draw_circle(c + Vector2(0, 9.0 * s), 3.5 * s, INK)

# ---------------------------------------------------------------- HUD

func _draw_hud() -> void:
	var g = game
	var sw: float = g.screen.x
	var icon: Texture2D = g.tex(g.plane.tex)
	# health
	_pill(Rect2(16, 14, 250, 28), Color(0.1, 0.11, 0.1, 0.8))
	var iw := 44.0
	var ih := iw * float(icon.get_height()) / float(icon.get_width())
	draw_texture_rect(icon, Rect2(24, 28.0 - ih * 0.5, iw, ih), false)
	var frac := clampf(g.health / g.hp_cap(), 0.0, 1.0)
	_bar(Rect2(76, 22, 180, 12), frac, true)
	# fuel
	_pill(Rect2(16, 48, 250, 26), Color(0.1, 0.11, 0.1, 0.8))
	var ff: float = g.fuel_frac()
	var fcol := AMBER
	if ff < 0.25 and int(g.time * 3.0) % 2 == 0:
		fcol = Color(0.9, 0.2, 0.15)
	_can_icon(Vector2(36, 61), 1.0, fcol)
	var br := Rect2(76, 55, 180, 11)
	draw_rect(br, Color(0.25, 0.22, 0.18))
	draw_rect(Rect2(br.position, Vector2(br.size.x * ff, br.size.y)), fcol)
	draw_rect(br, Color(0.7, 0.65, 0.5), false, 1.5)
	# bombs and ammo
	_bomb_icon(Vector2(30, 98), 1.0, CREAM)
	_text("%d/%d" % [g.bombs_left, g.bomb_cap()], Vector2(44, 104), 18, CREAM)
	_bullet_icon(Vector2(112, 96), 1.0, CREAM)
	_text("%d/%d" % [g.ammo, g.ammo_cap()], Vector2(126, 104), 18, CREAM)
	# speed bar with the 80% stall line
	var vmax: float = g.plane.vmax
	var sr := Rect2(76, 118, 180, 10)
	draw_rect(sr, Color(0.25, 0.22, 0.18))
	var sf := clampf(g.speed / vmax, 0.0, 1.0)
	var scol := Color(0.55, 0.72, 0.3) if sf >= 0.8 else Color(0.85, 0.35, 0.2)
	draw_rect(Rect2(sr.position, Vector2(sr.size.x * sf, sr.size.y)), scol)
	draw_rect(sr, Color(0.7, 0.65, 0.5), false, 1.5)
	var mx := sr.position.x + sr.size.x * 0.8
	draw_line(Vector2(mx, sr.position.y - 4.0), Vector2(mx, sr.end.y + 4.0), CREAM, 2.0)
	_text("SPD", Vector2(24, 128), 13, CREAM)
	var alt := int(maxf(0.0, g.ground_y - g.player.y) * 3.0)
	_text("ALT %04d m   %d km/h" % [alt, int(g.speed * 1.6)], Vector2(20, 150), 13, CREAM)
	_text("SCORE %d" % g.score, Vector2(20, 168), 13, CREAM)

	# objective banner (bilingual)
	var ob: Array = g.objective()
	var ow := _font().get_string_size(ob[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 40.0
	var orct := Rect2(sw * 0.5 - ow * 0.5 - 60.0, 12, ow, 50)
	_panel(orct, Color(0.1, 0.11, 0.1, 0.78), Color(0.7, 0.65, 0.5, 0.6))
	_ctext(ob[0], orct.get_center() + Vector2(0, -9), 16, CREAM)
	_cfa(ob[1], orct.get_center() + Vector2(0, 12), 13, Color(0.8, 0.75, 0.6))
	# distance to the airstrip when fuel is getting low
	if not g.refueled and g.fuel_frac() < 0.55 and g.world_x() < Terrain.RUNWAY_C_START:
		var d := int((Terrain.RUNWAY_C_START - g.world_x()) * 0.5)
		var pr := Rect2(orct.position.x, 66, orct.size.x, 26)
		_panel(pr, Color(0.35, 0.28, 0.08, 0.8), AMBER)
		_ctext("AIRSTRIP  %d m" % d, pr.get_center(), 15, AMBER)
	_draw_minimap()

func _bar(r: Rect2, frac: float, health: bool) -> void:
	draw_rect(r, Color(0.25, 0.22, 0.18))
	var fw := r.size.x * frac
	if fw > 1.0:
		var c_left := Color(0.75, 0.15, 0.1)
		var c_right := Color(0.9, 0.7, 0.2).lerp(Color(0.5, 0.7, 0.25), clampf((frac - 0.5) * 2.0, 0.0, 1.0))
		draw_polygon(PackedVector2Array([r.position, r.position + Vector2(fw, 0), r.position + Vector2(fw, r.size.y), r.position + Vector2(0, r.size.y)]),
			PackedColorArray([c_left, c_right, c_right, c_left]))
	draw_rect(r, Color(0.7, 0.65, 0.5), false, 1.5)

func _draw_minimap() -> void:
	var g = game
	var sw: float = g.screen.x
	var r := Rect2(sw - 270.0, 12.0, 256.0, 128.0)
	draw_rect(r, Color(0.85, 0.78, 0.62, 0.92))
	draw_rect(r, PAPER_DARK, false, 2.0)
	_text("MISSION 01", Vector2(r.position.x + 10, r.position.y + 20), 14, INK)
	_text("AIRFIELD ATTACK", Vector2(r.position.x + 10, r.position.y + 38), 12, INK)
	_text(Terrain.zone_name(g.world_x()), Vector2(r.position.x + 10, r.position.y + 54), 11, RED)
	var a := Vector2(r.position.x + 28, r.position.y + 100)
	var b := Vector2(r.position.x + r.size.x - 28, r.position.y + 84)
	var ctrl := Vector2(r.position.x + 128, r.position.y + 62)
	var prev := a
	for i in range(1, 31):
		var t := float(i) / 30.0
		var p := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
		if i % 2 == 0:
			draw_line(prev, p, INK, 2.0)
		prev = p
	for pt in [a, b]:
		draw_circle(pt, 9.0, RED)
		draw_circle(pt, 9.0, INK, false, 1.5)
	_ctext("A", a, 12, CREAM)
	_ctext("B", b, 12, CREAM)
	# refuel airstrip marker
	var tc := (Terrain.RUNWAY_C_START + 1200.0) / Terrain.RUNWAY_B_START
	var cp := a.lerp(ctrl, tc).lerp(ctrl.lerp(b, tc), tc)
	var done: bool = g.refueled
	draw_circle(cp, 8.0, Color(0.5, 0.5, 0.45) if done else AMBER)
	draw_circle(cp, 8.0, INK, false, 1.5)
	_can_icon(cp, 0.55, INK)
	if not done:
		_text("REFUEL", cp + Vector2(-20, -14), 10, INK)
	var t2: float = g.progress()
	var pp := a.lerp(ctrl, t2).lerp(ctrl.lerp(b, t2), t2)
	draw_circle(pp, 5.0, INK)
	draw_circle(pp, 3.0, CREAM)

# ---------------------------------------------------------------- controls

func _round_button(c: Vector2, r: float, active: bool) -> void:
	draw_circle(c, r, Color(0.2, 0.21, 0.19, 0.88 if active else 0.6))
	draw_arc(c, r, 0.0, TAU, 40, Color(0.78, 0.74, 0.62, 0.9), 3.0)
	draw_arc(c, r - 7.0, 0.0, TAU, 40, Color(0.5, 0.47, 0.4, 0.7), 1.5)

func _draw_controls() -> void:
	var g = game
	var dc: Vector2 = g.dpad_center()
	_round_button(dc, 100.0, g.touches.values().has("dpad"))
	var arrows := {"u": Vector2(0, -1), "d": Vector2(0, 1), "l": Vector2(-1, 0), "r": Vector2(1, 0)}
	for k in arrows:
		var d: Vector2 = arrows[k]
		var n := Vector2(-d.y, d.x)
		var tip := dc + d * 74.0
		var on: bool = (k == "u" and g.in_up) or (k == "d" and g.in_down) or (k == "l" and g.in_left) or (k == "r" and g.in_right)
		var col := CREAM if on else Color(0.6, 0.57, 0.48, 0.85)
		draw_colored_polygon(PackedVector2Array([tip, dc + d * 46.0 + n * 16.0, dc + d * 46.0 - n * 16.0]), col)
	_ctext("-", dc + Vector2(-30, 0), 22, Color(0.8, 0.75, 0.6, 0.9))
	_ctext("+", dc + Vector2(30, 0), 22, Color(0.8, 0.75, 0.6, 0.9))
	draw_circle(dc + g.touch_dir * 30.0, 18.0, Color(0.55, 0.52, 0.45, 0.6))
	_text("SPEED", dc + Vector2(-24, 38), 10, Color(0.8, 0.75, 0.6, 0.8))

	var fc: Vector2 = g.fire_center()
	_round_button(fc, 64.0, g.in_fire)
	_bullet_icon(fc, 2.4, CREAM)
	var bc: Vector2 = g.bomb_center()
	_round_button(bc, 46.0, g.bomb_cd > 0.0 or g.touches.values().has("bomb"))
	_bomb_icon(bc, 1.7, CREAM)
	var pc: Vector2 = g.pause_center()
	_round_button(pc, 26.0, false)
	draw_rect(Rect2(pc.x - 8.0, pc.y - 9.0, 5.0, 18.0), CREAM)
	draw_rect(Rect2(pc.x + 3.0, pc.y - 9.0, 5.0, 18.0), CREAM)

func _draw_banners() -> void:
	var g = game
	var sw: float = g.screen.x
	var sh: float = g.screen.y
	if g.zone_t > 0.0 and g.zone_name != "":
		var a := clampf(g.zone_t, 0.0, 1.0)
		_ctext(g.zone_name, Vector2(sw * 0.5, sh * 0.2), 34, Color(CREAM.r, CREAM.g, CREAM.b, a))
		_cfa(g.zone_fa, Vector2(sw * 0.5, sh * 0.2 + 36.0), 22, Color(0.85, 0.8, 0.65, a))
	if g.message_t > 0.0 and g.message != "":
		var a2 := clampf(g.message_t * 2.0, 0.0, 1.0)
		var w := maxf(_font().get_string_size(g.message, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x, 200.0)
		var c := Vector2(sw * 0.5, sh * 0.33)
		draw_rect(Rect2(c.x - w * 0.5 - 18.0, c.y - 22.0, w + 36.0, 66.0 if g.message_fa != "" else 44.0), Color(0.08, 0.08, 0.07, 0.6 * a2))
		_ctext(g.message, c + Vector2(0, 2), 24, Color(CREAM.r, CREAM.g, CREAM.b, a2))
		_cfa(g.message_fa, c + Vector2(0, 32), 18, Color(0.85, 0.8, 0.65, a2))
	if g.on_ground and g.landed_mode == 0:
		var rot_v: float = g.plane.vmax * g.ROTATE_FRAC
		if g.speed >= rot_v:
			if int(g.time * 3.0) % 2 == 0:
				_ctext("HOLD  UP  TO TAKE OFF", Vector2(sw * 0.5, sh * 0.46), 30, AMBER)
				_cfa("دکمه‌ی بالا را نگه دار", Vector2(sw * 0.5, sh * 0.46 + 34.0), 20, AMBER)
		else:
			var pct := clampf(g.speed / rot_v, 0.0, 1.0)
			var r := Rect2(sw * 0.5 - 130.0, sh * 0.46, 260.0, 12.0)
			draw_rect(r, Color(0.2, 0.2, 0.18, 0.8))
			draw_rect(Rect2(r.position, Vector2(r.size.x * pct, r.size.y)), RED)
			draw_rect(r, CREAM, false, 1.5)
			_ctext("TAKEOFF SPEED", Vector2(sw * 0.5, sh * 0.46 - 16.0), 16, INK)
	if g.on_ground and g.landed_mode == 2:
		var pr := Rect2(sw * 0.5 - 150.0, sh * 0.46, 300.0, 40.0)
		_panel(pr, Color(0.1, 0.11, 0.1, 0.78), AMBER)
		_ctext("REFUELING / REARMING", pr.get_center() + Vector2(0, -7), 16, AMBER)
		_cfa("سوخت‌گیری و تسلیح", pr.get_center() + Vector2(0, 13), 13, AMBER)

# ---------------------------------------------------------------- overlays

func _overlay(title: String, title_fa: String, sub: String, sub_fa: String) -> void:
	var g = game
	var sw: float = g.screen.x
	var sh: float = g.screen.y
	draw_rect(Rect2(0, 0, sw, sh), Color(0.06, 0.06, 0.05, 0.72))
	_ctext(title, Vector2(sw * 0.5, sh * 0.42), 42, CREAM)
	_cfa(title_fa, Vector2(sw * 0.5, sh * 0.42 + 46.0), 26, Color(0.85, 0.8, 0.65))
	_ctext(sub, Vector2(sw * 0.5, sh * 0.58), 20, Color(0.84, 0.78, 0.62))
	_cfa(sub_fa, Vector2(sw * 0.5, sh * 0.58 + 30.0), 16, Color(0.8, 0.75, 0.6))

func _draw_end(won: bool) -> void:
	var g = game
	var sw: float = g.screen.x
	var sh: float = g.screen.y
	draw_rect(Rect2(0, 0, sw, sh), Color(0.06, 0.06, 0.05, 0.72))
	if won:
		_ctext("MISSION COMPLETE", Vector2(sw * 0.5, sh * 0.26), 44, CREAM)
		_cfa("مأموریت موفق", Vector2(sw * 0.5, sh * 0.26 + 44.0), 26, Color(0.85, 0.8, 0.65))
	else:
		_ctext(g.fail_reason, Vector2(sw * 0.5, sh * 0.26), 40, CREAM)
		_cfa(g.fail_fa, Vector2(sw * 0.5, sh * 0.26 + 44.0), 26, Color(0.85, 0.8, 0.65))
	_ctext("Score %d     Targets %d / %d     Credits +%d" % [g.score, g.targets_down, g.targets_total, g.earned], Vector2(sw * 0.5, sh * 0.46), 20, Color(0.84, 0.78, 0.62))
	_cfa("امتیاز و اعتبار برای ارتقای هواپیما", Vector2(sw * 0.5, sh * 0.46 + 28.0), 15, Color(0.8, 0.75, 0.6))
	if won:
		if g.new_unlock:
			var nm: String = AircraftData.LIST[g.unlocked - 1].name
			_ctext("NEW AIRCRAFT UNLOCKED: %s" % nm, Vector2(sw * 0.5, sh * 0.58), 24, AMBER)
			_cfa("هواپیمای جدید باز شد", Vector2(sw * 0.5, sh * 0.58 + 30.0), 18, AMBER)
		_ctext("Tap to return to the hangar", Vector2(sw * 0.5, sh * 0.72), 20, Color(0.84, 0.78, 0.62))
	else:
		var rr: Rect2 = g.ov_retry()
		var hr: Rect2 = g.ov_hangar()
		_pill(rr, METAL)
		_pill(hr, METAL)
		_ctext("RETRY" if g.checkpoint == 0 else "RETRY FROM AIRSTRIP", rr.get_center() + Vector2(0, -6), 17, CREAM)
		_cfa("تلاش دوباره", rr.get_center() + Vector2(0, 14), 13, CREAM)
		_ctext("HANGAR", hr.get_center() + Vector2(0, -6), 17, CREAM)
		_cfa("آشیانه", hr.get_center() + Vector2(0, 14), 13, CREAM)

# ---------------------------------------------------------------- menu

func _draw_menu() -> void:
	var g = game
	var sw: float = g.screen.x
	var sh: float = g.screen.y
	draw_rect(Rect2(0, 0, sw, sh), Color(0.06, 0.06, 0.05, 0.35))
	var p := Rect2(sw * 0.5 - 340.0, sh * 0.5 - 270.0, 680.0, 540.0)
	draw_rect(p, Color(0.84, 0.77, 0.61, 0.96))
	draw_rect(p, PAPER_DARK, false, 3.0)
	_ctext("SKYWARD", Vector2(sw * 0.5, p.position.y + 36.0), 44, INK)
	_ctext("Operation Northern Wind  -  Airfield Attack", Vector2(sw * 0.5, p.position.y + 76.0), 17, RED)
	_cfa("عملیات باد شمالی - حمله به پایگاه هوایی", Vector2(sw * 0.5, p.position.y + 100.0), 14, Color(0.4, 0.2, 0.15))
	_text("CREDITS %d" % g.credits, Vector2(p.position.x + 18.0, p.position.y + 26.0), 14, INK)
	var data: Dictionary = g.plane
	var locked: bool = g.plane_idx >= g.unlocked
	var t: Texture2D = g.tex(data.tex)
	var w := 300.0
	var h := w * float(t.get_height()) / float(t.get_width())
	var c := Vector2(sw * 0.5, sh * 0.5 - 30.0)
	draw_texture_rect(t, Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), false, Color(0.22, 0.22, 0.22) if locked else Color(1, 1, 1))
	if locked:
		_lock_icon(c, 2.0, Color(0.85, 0.75, 0.5))
	var lr: Rect2 = g.menu_left()
	var rr: Rect2 = g.menu_right()
	draw_colored_polygon(PackedVector2Array([Vector2(lr.position.x + 10, lr.get_center().y), Vector2(lr.end.x - 10, lr.position.y + 10), Vector2(lr.end.x - 10, lr.end.y - 10)]), METAL)
	draw_colored_polygon(PackedVector2Array([Vector2(rr.end.x - 10, rr.get_center().y), Vector2(rr.position.x + 10, rr.position.y + 10), Vector2(rr.position.x + 10, rr.end.y - 10)]), METAL)
	_ctext(data.name, Vector2(sw * 0.5, sh * 0.5 + 40.0), 26, INK)
	_cfa(data.fa, Vector2(sw * 0.5, sh * 0.5 + 66.0), 15, Color(0.3, 0.28, 0.22))
	if locked:
		_ctext("LOCKED - complete a mission to unlock", Vector2(sw * 0.5, sh * 0.5 + 94.0), 15, RED)
		_cfa("قفل است - با تکمیل مأموریت باز می‌شود", Vector2(sw * 0.5, sh * 0.5 + 114.0), 13, RED)
	else:
		_ctext(data.role, Vector2(sw * 0.5, sh * 0.5 + 88.0), 14, Color(0.3, 0.28, 0.22))
		var stats := [["SPEED", data.stat_speed], ["ARMOR", data.stat_armor], ["FIREPOWER", data.stat_fire]]
		for i in range(3):
			var x0 := sw * 0.5 - 250.0 + float(i) * 170.0
			var y := sh * 0.5 + 106.0
			_text(stats[i][0], Vector2(x0, y + 2.0), 11, INK)
			var br := Rect2(x0, y + 8.0, 150.0, 8.0)
			draw_rect(br, Color(0.55, 0.5, 0.38))
			draw_rect(Rect2(br.position, Vector2(br.size.x * float(stats[i][1]), br.size.y)), RED)
	# unlock pips
	for i in range(AircraftData.LIST.size()):
		var pc := Vector2(sw * 0.5 - 30.0 + float(i) * 20.0, sh * 0.5 + 138.0)
		draw_circle(pc, 5.0, RED if i == g.plane_idx else (METAL if i < g.unlocked else Color(0.6, 0.55, 0.42)))
	var sr: Rect2 = g.menu_start()
	_pill(sr, METAL if not locked else Color(0.35, 0.33, 0.28))
	_ctext("START MISSION", sr.get_center() + Vector2(0, -6), 20, CREAM if not locked else Color(0.6, 0.56, 0.46))
	_cfa("شروع مأموریت", sr.get_center() + Vector2(0, 15), 13, CREAM if not locked else Color(0.6, 0.56, 0.46))
	var ur: Rect2 = g.menu_upgrade()
	_pill(ur, Color(0.5, 0.26, 0.16))
	_ctext("UPGRADES", ur.get_center() + Vector2(0, -6), 18, CREAM)
	_cfa("ارتقا", ur.get_center() + Vector2(0, 15), 13, CREAM)
	_ctext("Arrows/WASD: climb/dive, slow/fast    Space: guns    B: bomb    P: pause", Vector2(sw * 0.5, p.end.y - 20.0), 12, Color(0.3, 0.28, 0.22))

func _draw_upgrades() -> void:
	var g = game
	var sw: float = g.screen.x
	var sh: float = g.screen.y
	draw_rect(Rect2(0, 0, sw, sh), Color(0.06, 0.06, 0.05, 0.55))
	var p := Rect2(sw * 0.5 - 340.0, sh * 0.5 - 270.0, 680.0, 540.0)
	draw_rect(p, Color(0.84, 0.77, 0.61, 0.97))
	draw_rect(p, PAPER_DARK, false, 3.0)
	_ctext("UPGRADES", Vector2(sw * 0.5, p.position.y + 36.0), 34, INK)
	_cfa("ارتقای تجهیزات", Vector2(sw * 0.5, p.position.y + 66.0), 18, Color(0.3, 0.28, 0.22))
	_ctext("CREDITS  %d" % g.credits, Vector2(sw * 0.5, p.position.y + 96.0), 20, RED)
	var keys := ["ammo", "bombs", "fuel", "armor"]
	var names := ["Extra ammo  (+2 bursts)", "Extra bombs  (+1)", "Bigger fuel tank  (+12%)", "Armor plating  (+12% hull)"]
	var fas := ["مهمات بیشتر", "بمب بیشتر", "مخزن سوخت بزرگ‌تر", "زره قوی‌تر"]
	for i in range(4):
		var r: Rect2 = g.upg_row(i)
		r.position.y += 40.0
		draw_rect(r, Color(0.78, 0.7, 0.54))
		draw_rect(r, PAPER_DARK, false, 2.0)
		_text(names[i], Vector2(r.position.x + 14.0, r.position.y + 25.0), 17, INK)
		_cfa(fas[i], Vector2(r.position.x + 110.0, r.position.y + 47.0), 13, Color(0.3, 0.28, 0.22))
		var lvl: int = g.upg[keys[i]]
		for k in range(5):
			draw_circle(Vector2(r.position.x + 360.0 + float(k) * 22.0, r.position.y + 30.0), 7.0, RED if k < lvl else Color(0.6, 0.55, 0.42))
		var cost: int = g.upgrade_cost(keys[i])
		var txt := "MAX" if lvl >= 5 else "%d" % cost
		var can: bool = lvl < 5 and g.credits >= cost
		_text("[%d] %s" % [i + 1, txt], Vector2(r.end.x - 110.0, r.position.y + 36.0), 18, Color(0.2, 0.45, 0.2) if can else Color(0.4, 0.2, 0.15))
	var br: Rect2 = g.upg_back()
	br.position.y += 40.0
	_pill(br, METAL)
	_ctext("BACK", br.get_center() + Vector2(0, -6), 18, CREAM)
	_cfa("بازگشت", br.get_center() + Vector2(0, 14), 13, CREAM)
