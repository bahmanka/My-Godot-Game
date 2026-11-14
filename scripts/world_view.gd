extends Node2D
# Draws the world: sky, parallax, biomes, terrain, entities, particles.

var game

const STEP := 14.0
const INK := Color(0.16, 0.17, 0.14)
var _off := Vector2.ZERO

func _draw() -> void:
	var g = game
	if g == null:
		return
	var sw: float = g.screen.x
	var sh: float = g.screen.y
	var gy: float = g.ground_y
	var dist: float = g.distance
	var cam: float = g.cam_y
	var shake_off := Vector2.ZERO
	if g.shake > 0.0:
		shake_off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * g.shake
	var wx: float = g.world_x()

	# --- sky (static) and parallax layers (partial camera follow)
	draw_set_transform(shake_off * 0.3, 0.0, Vector2.ONE)
	draw_texture_rect(g.tex("sky"), Rect2(-30, -30, sw + 60, sh + 60), false)
	_cloud("clouds_a", dist * 0.07, gy - 900.0, cam * 0.62, 0.75, sw)
	_cloud("clouds_b", dist * 0.10, gy - 1300.0, cam * 0.8, 0.7, sw)
	_cloud("clouds_a", dist * 0.04, gy - 560.0, cam * 0.35, 0.9, sw)
	_layer("mtn_far", dist * 0.08, gy - 400.0, cam * 0.18, Color(142.0 / 255.0, 160.0 / 255.0, 172.0 / 255.0, 0.94), sw, sh)
	_cloud("clouds_b", dist * 0.12, gy - 470.0, cam * 0.4, 0.8, sw)
	_layer("mtn_mid", dist * 0.2, gy - 340.0, cam * 0.3, Color(118.0 / 255.0, 128.0 / 255.0, 118.0 / 255.0, 1.0), sw, sh)
	_draw_midhills(dist, gy, sw, sh, cam, wx)

	# --- world space
	_off = shake_off + Vector2(0.0, cam)
	draw_set_transform(_off, 0.0, Vector2.ONE)
	_draw_terrain(dist, gy, sw, sh, cam)
	_draw_bridge(dist, gy, sw)
	_draw_trees(dist, gy, sw)
	_draw_props(dist, gy, sw)
	_draw_wrecks(dist, sw)
	_draw_targets(dist, sw)
	_draw_crates(dist, sw)
	_draw_enemies(dist)
	_draw_bullets(dist)
	_draw_player()
	_draw_bombs(dist)
	_draw_ebullets(dist)
	_draw_particles(dist)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_overlay(sw, sh, wx, gy)

func _cloud(nm: String, offset: float, y: float, cam_shift: float, a: float, sw: float) -> void:
	var t: Texture2D = game.tex(nm)
	var w := float(t.get_width())
	var h := float(t.get_height())
	var x := -fposmod(offset, w)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	while x < sw:
		draw_texture_rect(t, Rect2(x, y + cam_shift, w + 1.0, h), false, Color(1, 1, 1, a))
		x += w

func _layer(nm: String, offset: float, y: float, cam_shift: float, fill: Color, sw: float, sh: float) -> void:
	var t: Texture2D = game.tex(nm)
	var w := float(t.get_width())
	var h := float(t.get_height())
	var x := -fposmod(offset, w)
	while x < sw:
		draw_texture_rect(t, Rect2(x, y + cam_shift, w + 1.0, h), false)
		x += w
	draw_rect(Rect2(0, y + cam_shift + h - 2.0, sw, sh + 900.0), fill)

# ---------------------------------------------------------------- biomes

func _biome_top(wx: float, elev: float) -> Color:
	var wf := Terrain.w_farm(wx)
	var wfo := Terrain.w_forest(wx)
	var wm := Terrain.w_mount(wx)
	var wv := Terrain.w_valley(wx)
	var wb := Terrain.w_base(wx)
	var ws := Terrain.sea_w(wx)
	var col := Color(0.43, 0.48, 0.27)
	var field := int(floor(wx / 170.0)) % 4
	var fcols := [Color(0.62, 0.56, 0.30), Color(0.47, 0.54, 0.28), Color(0.66, 0.52, 0.30), Color(0.52, 0.50, 0.26)]
	col = col.lerp(fcols[field], wf)
	col = col.lerp(Color(0.28, 0.39, 0.21), wfo)
	col = col.lerp(Color(0.63, 0.56, 0.39), wv)
	col = col.lerp(Color(0.41, 0.37, 0.30), wb)
	var rock := Color(0.50, 0.46, 0.40).lerp(Color(0.72, 0.70, 0.66), clampf(elev / 250.0, 0.0, 1.0))
	rock = rock.lerp(Color(0.92, 0.92, 0.90), clampf((elev - 235.0) / 60.0, 0.0, 1.0))
	col = col.lerp(rock, clampf(wm * 1.4, 0.0, 1.0) * clampf(elev / 70.0, 0.0, 1.0))
	var isl := Terrain.island(wx)
	var water := Color(0.36, 0.53, 0.63).lerp(Color(0.46, 0.52, 0.37), smoothstep(4.0, 26.0, isl))
	return col.lerp(water, ws)

func _biome_bot(top: Color) -> Color:
	return Color(top.r * 0.52, top.g * 0.55, top.b * 0.55)

func _draw_midhills(dist: float, gy: float, sw: float, sh: float, cam: float, wx: float) -> void:
	var f := 0.45
	var pts := PackedVector2Array()
	var base := gy - 150.0 + cam * 0.55
	var col := Color(0.38, 0.46, 0.31)
	var wm := Terrain.w_mount(wx)
	var ws := Terrain.sea_w(wx)
	col = col.lerp(Color(0.46, 0.46, 0.44), wm)
	col = col.lerp(Color(0.34, 0.5, 0.6), ws * 0.85)
	col = col.lerp(Color(0.40, 0.36, 0.30), Terrain.w_base(wx))
	col = col.lerp(Color(0.55, 0.50, 0.36), Terrain.w_valley(wx))
	col = Color(col.r, col.g, col.b, 0.92)
	var n := int(sw / 24.0) + 3
	for i in range(n):
		var sx := float(i) * 24.0 - fposmod(dist * f, 24.0)
		var px := dist * f + sx
		var h := 40.0 + 34.0 * sin(px * 0.0031 + 0.7) + 22.0 * sin(px * 0.0083 + 2.1) + 10.0 * sin(px * 0.021)
		pts.append(Vector2(sx, base - h * (1.0 - ws * 0.8)))
	var poly := PackedVector2Array(pts)
	poly.append(Vector2(sw + 30.0, sh + 900.0))
	poly.append(Vector2(-30.0, sh + 900.0))
	draw_colored_polygon(poly, col)
	draw_polyline(pts, Color(0.2, 0.25, 0.2, 0.6), 2.0)
	# little round tree clumps on the ridge
	if ws < 0.7:
		for i in range(0, pts.size(), 2):
			var p: Vector2 = pts[i]
			var r := 5.0 + float(i % 5)
			draw_circle(p + Vector2(0, 2), r, Color(col.r * 0.72, col.g * 0.78, col.b * 0.7, 0.9))

# ---------------------------------------------------------------- terrain

func _draw_terrain(dist: float, gy: float, sw: float, sh: float, cam: float) -> void:
	var n := int(sw / STEP) + 3
	var pts := PackedVector2Array()
	var prev_x := -STEP
	var pwx := dist - STEP
	var prev_y := Terrain.surface_y(pwx, gy)
	var prev_top := _biome_top(pwx, Terrain.elevation(pwx))
	var bottom := sh + 40.0
	for i in range(n):
		var sx := float(i) * STEP - fposmod(dist, STEP)
		var wx := dist + sx
		var y := Terrain.surface_y(wx, gy)
		var el := Terrain.elevation(wx)
		var sea := Terrain.sea_w(wx)
		var top := _biome_top(wx, el)
		var bt0 := _biome_bot(prev_top)
		var bt1 := _biome_bot(top)
		draw_polygon(PackedVector2Array([Vector2(prev_x, prev_y), Vector2(sx, y), Vector2(sx, bottom), Vector2(prev_x, bottom)]),
			PackedColorArray([prev_top, top, bt1, bt0]))
		var on_c := Terrain.in_runway_c(wx)
		if Terrain.in_runway_a(wx) or Terrain.in_runway_b(wx) or on_c:
			var rc := Color(0.36, 0.35, 0.31) if not on_c else Color(0.47, 0.43, 0.36)
			draw_polygon(PackedVector2Array([Vector2(prev_x, prev_y), Vector2(sx, y), Vector2(sx, y + 22.0), Vector2(prev_x, prev_y + 22.0)]),
				PackedColorArray([rc, rc, rc, rc]))
			if int(floor(wx / 90.0)) % 2 == 0 and not (on_c and int(floor(wx / 90.0)) % 5 == 0):
				draw_rect(Rect2(sx - STEP, y + 9.0, STEP, 4.0), Color(0.85, 0.80, 0.65, 0.9 if not on_c else 0.55))
			if on_c and int(floor(wx / STEP)) % 11 == 0:
				draw_line(Vector2(sx - 6.0, y + 2.0), Vector2(sx + 8.0, y + 18.0), Color(0.2, 0.18, 0.14, 0.7), 1.5)
				draw_line(Vector2(sx + 2.0, y), Vector2(sx + 2.0, y - 7.0), Color(0.35, 0.45, 0.2), 2.0)
		elif sea > 0.5:
			var wv := sin((wx + game.time * 30.0) * 0.05 + float(i))
			if wv > 0.55:
				draw_line(Vector2(sx - 8.0, y + 8.0 + wv * 4.0), Vector2(sx + 6.0, y + 8.0 + wv * 4.0), Color(0.78, 0.88, 0.9, 0.5), 2.0)
			if int(floor(wx / 53.0)) % 7 == 0:
				draw_line(Vector2(sx, y + 26.0), Vector2(sx + 10.0, y + 26.0), Color(1, 1, 1, 0.25), 2.0)
		else:
			if Terrain.w_farm(wx) > 0.5 and y < gy + 4.0:
				if int(floor(wx / STEP)) % 2 == 0:
					draw_line(Vector2(sx - 6.0, y + 12.0), Vector2(sx + 8.0, y + 12.0), Color(0.3, 0.28, 0.15, 0.35), 2.0)
					draw_line(Vector2(sx - 6.0, y + 26.0), Vector2(sx + 8.0, y + 26.0), Color(0.3, 0.28, 0.15, 0.28), 2.0)
			elif el > 120.0 and int(floor(wx / STEP)) % 3 == 0:
				draw_line(Vector2(sx, y + 10.0), Vector2(sx + 9.0, y + 26.0), Color(0.3, 0.28, 0.24, 0.45), 2.0)
				draw_line(Vector2(sx - 4.0, y + 28.0), Vector2(sx + 5.0, y + 44.0), Color(0.3, 0.28, 0.24, 0.35), 2.0)
			elif Terrain.w_base(wx) > 0.5 and int(floor(wx / 260.0)) % 3 == 0 and int(floor(wx / STEP)) % 4 == 0:
				draw_arc(Vector2(sx, y + 3.0), 11.0, PI, TAU, 8, Color(0.15, 0.13, 0.1, 0.7), 3.0)
		pts.append(Vector2(sx, y))
		prev_x = sx
		prev_y = y
		prev_top = top
	draw_polyline(pts, INK, 2.5, true)

func _hash(i: int) -> float:
	var v := sin(float(i) * 12.9898 + 78.233) * 43758.5453
	return v - floor(v)

# ---------------------------------------------------------------- vegetation

func _blob(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r, col)

func _draw_trees(dist: float, gy: float, sw: float) -> void:
	var spacing := 30.0
	var first := int(floor(dist / spacing)) - 1
	var last := int(floor((dist + sw) / spacing)) + 2
	for idx in range(first, last):
		var r := _hash(idx)
		var wx := float(idx) * spacing + r * 20.0
		var f := Terrain.forest_w(wx)
		if f < 0.04 or r > f * 0.9 + 0.06:
			continue
		var sea := Terrain.sea_w(wx)
		var el := Terrain.elevation(wx)
		if sea > 0.1 or Terrain.any_runway(wx):
			continue
		var sx := wx - dist
		var y := Terrain.surface_y(wx, gy)
		var k := _hash(idx + 977)
		var shade := 0.82 + _hash(idx + 31) * 0.36
		var wm := Terrain.w_mount(wx)
		var wb := Terrain.w_base(wx)
		var wfa := Terrain.w_farm(wx)
		var wv := Terrain.w_valley(wx)
		if wb > 0.5:
			_dead_tree(Vector2(sx, y), 16.0 + k * 14.0)
		elif wm > 0.5:
			if el < 190.0:
				_stunted(Vector2(sx, y), 12.0 + k * 10.0, shade)
		elif wv > 0.5:
			_shrub(Vector2(sx, y), 8.0 + k * 8.0, Color(0.45 * shade, 0.45 * shade, 0.26 * shade))
		elif wfa > 0.4 and k < 0.35:
			_poplar(Vector2(sx, y), 22.0 + k * 40.0, shade)
		else:
			var autumn := _hash(idx + 5) < 0.18
			var base := Color(0.20 * shade, 0.34 * shade, 0.16 * shade)
			if autumn:
				base = Color(0.62 * shade, 0.40 * shade, 0.14 * shade)
			_broadleaf(Vector2(sx, y), 16.0 + k * 20.0, base)

func _broadleaf(p: Vector2, s: float, base: Color) -> void:
	draw_line(p + Vector2(0, 2), p + Vector2(0, -s * 0.55), Color(0.26, 0.19, 0.12), maxf(2.0, s * 0.12))
	var dark := Color(base.r * 0.7, base.g * 0.72, base.b * 0.7)
	var light := Color(minf(1.0, base.r * 1.28), minf(1.0, base.g * 1.25), minf(1.0, base.b * 1.2))
	_blob(p + Vector2(-s * 0.28, -s * 0.78), s * 0.42, dark)
	_blob(p + Vector2(s * 0.30, -s * 0.76), s * 0.40, dark)
	_blob(p + Vector2(0.0, -s * 0.98), s * 0.52, base)
	_blob(p + Vector2(-s * 0.12, -s * 1.12), s * 0.3, light)
	draw_arc(p + Vector2(0.0, -s * 0.98), s * 0.52, PI * 1.05, PI * 1.95, 10, Color(0.1, 0.14, 0.08, 0.7), 1.5)

func _poplar(p: Vector2, s: float, shade: float) -> void:
	var col := Color(0.24 * shade, 0.38 * shade, 0.17 * shade)
	var pts := PackedVector2Array()
	for k in range(0, 13):
		var a := TAU * float(k) / 12.0
		pts.append(p + Vector2(cos(a) * s * 0.16, -s * 0.5 + sin(a) * s * 0.5))
	draw_colored_polygon(pts, col)
	draw_line(p + Vector2(0, -s * 0.2), p + Vector2(0, -s * 0.9), Color(col.r * 1.3, col.g * 1.3, col.b * 1.2), 2.0)
	draw_polyline(pts, Color(0.1, 0.14, 0.08, 0.7), 1.2)

func _shrub(p: Vector2, s: float, col: Color) -> void:
	_blob(p + Vector2(-s * 0.4, -s * 0.3), s * 0.5, Color(col.r * 0.8, col.g * 0.8, col.b * 0.8))
	_blob(p + Vector2(s * 0.35, -s * 0.28), s * 0.45, col)
	_blob(p + Vector2(0, -s * 0.5), s * 0.45, Color(col.r * 1.15, col.g * 1.15, col.b * 1.1))

func _stunted(p: Vector2, s: float, shade: float) -> void:
	var col := Color(0.30 * shade, 0.38 * shade, 0.22 * shade)
	draw_line(p, p + Vector2(s * 0.15, -s * 0.7), Color(0.3, 0.22, 0.15), 2.0)
	_blob(p + Vector2(s * 0.1, -s * 0.8), s * 0.34, col)
	_blob(p + Vector2(-s * 0.18, -s * 0.62), s * 0.24, Color(col.r * 0.8, col.g * 0.8, col.b * 0.8))
	_blob(p + Vector2(s * 0.34, -s * 0.6), s * 0.22, Color(col.r * 0.9, col.g * 0.9, col.b * 0.9))

func _dead_tree(p: Vector2, s: float) -> void:
	var c := Color(0.16, 0.13, 0.1)
	draw_line(p, p + Vector2(0, -s), c, 3.0)
	draw_line(p + Vector2(0, -s * 0.6), p + Vector2(s * 0.35, -s * 0.95), c, 2.0)
	draw_line(p + Vector2(0, -s * 0.45), p + Vector2(-s * 0.3, -s * 0.75), c, 2.0)

# ---------------------------------------------------------------- props

func _draw_house(sx: float, y: float, w: float, h: float, roof: Color) -> void:
	draw_rect(Rect2(sx - w * 0.5, y - h, w, h), Color(0.78, 0.72, 0.58))
	draw_colored_polygon(PackedVector2Array([Vector2(sx - w * 0.58, y - h), Vector2(sx, y - h - h * 0.62), Vector2(sx + w * 0.58, y - h)]), roof)
	draw_rect(Rect2(sx - 5.0, y - h * 0.62, 10.0, h * 0.62), Color(0.3, 0.2, 0.14))
	draw_rect(Rect2(sx + w * 0.22, y - h * 0.75, 8.0, 8.0), Color(0.25, 0.3, 0.33))
	draw_rect(Rect2(sx - w * 0.5, y - h, w, h), INK, false, 1.5)
	draw_polyline(PackedVector2Array([Vector2(sx - w * 0.58, y - h), Vector2(sx, y - h - h * 0.62), Vector2(sx + w * 0.58, y - h)]), INK, 1.5)

func _draw_props(dist: float, gy: float, sw: float) -> void:
	var roofs := [Color(0.58, 0.28, 0.2), Color(0.5, 0.3, 0.2), Color(0.45, 0.25, 0.18)]
	# villages and farms
	for hx in [2900.0, 3000.0, 3120.0, 4800.0, 4920.0, 5030.0, 6150.0, 6260.0, 7050.0]:
		var sx: float = hx - dist
		if sx < -80.0 or sx > sw + 80.0:
			continue
		var y := Terrain.surface_y(hx, gy)
		var k := _hash(int(hx))
		_draw_house(sx, y + 2.0, 40.0 + k * 22.0, 26.0 + k * 10.0, roofs[int(k * 3.0) % 3])
		if int(hx) % 2 == 0:
			var ph := fposmod(game.time * 0.3 + k, 1.0)
			draw_circle(Vector2(sx + 8.0 + ph * 12.0, y - 50.0 - ph * 40.0), 5.0 + ph * 7.0, Color(0.8, 0.8, 0.78, (1.0 - ph) * 0.5))
	# windmill
	var wm_x := 5500.0 - dist
	if wm_x > -120.0 and wm_x < sw + 120.0:
		var wy := Terrain.surface_y(5500.0, gy)
		draw_colored_polygon(PackedVector2Array([Vector2(wm_x - 16.0, wy + 2.0), Vector2(wm_x + 16.0, wy + 2.0), Vector2(wm_x + 9.0, wy - 78.0), Vector2(wm_x - 9.0, wy - 78.0)]), Color(0.76, 0.7, 0.58))
		draw_polyline(PackedVector2Array([Vector2(wm_x - 16.0, wy + 2.0), Vector2(wm_x - 9.0, wy - 78.0), Vector2(wm_x + 9.0, wy - 78.0), Vector2(wm_x + 16.0, wy + 2.0)]), INK, 1.5)
		var hub := Vector2(wm_x, wy - 80.0)
		for k in range(4):
			var a: float = game.time * 0.8 + float(k) * PI * 0.5
			var tip := hub + Vector2(cos(a), sin(a)) * 46.0
			draw_line(hub, tip, Color(0.3, 0.24, 0.18), 3.0)
			draw_line(hub + Vector2(cos(a), sin(a)) * 12.0 + Vector2(-sin(a), cos(a)) * 5.0, tip + Vector2(-sin(a), cos(a)) * 5.0, Color(0.88, 0.84, 0.72), 5.0)
		draw_circle(hub, 4.0, INK)
	# haystacks
	for hs in [3800.0, 3860.0, 5650.0]:
		var hsx: float = hs - dist
		if hsx > -40.0 and hsx < sw + 40.0:
			var hy := Terrain.surface_y(hs, gy)
			draw_circle(Vector2(hsx, hy - 6.0), 12.0, Color(0.74, 0.62, 0.28))
			draw_arc(Vector2(hsx, hy - 6.0), 12.0, PI, TAU, 10, INK, 1.5)
	# airfield A and B: tower + hangar + windsock
	for tx in [900.0, 36600.0, 38000.0]:
		var tsx: float = tx - dist
		if tsx < -100.0 or tsx > sw + 100.0:
			continue
		var t: Texture2D = game.tex("tower")
		var h := 150.0
		var w := h * float(t.get_width()) / float(t.get_height())
		draw_texture_rect(t, Rect2(tsx - w * 0.5, gy - h + 4.0, w, h), false)
	var hx2 := 1400.0 - dist
	if hx2 > -300.0 and hx2 < sw + 100.0:
		_hangar(Vector2(hx2 + 75.0, gy + 4.0), 150.0, 78.0, Color(0.45, 0.42, 0.34), false)
	# abandoned airstrip C: rusty tower, wrecked plane, fuel drums, tilted hangar frame, sign
	var ctx := 17700.0 - dist
	if ctx > -120.0 and ctx < sw + 120.0:
		var t2: Texture2D = game.tex("tower")
		var h2 := 130.0
		var w2 := h2 * float(t2.get_width()) / float(t2.get_height())
		draw_texture_rect(t2, Rect2(ctx - w2 * 0.5, gy - h2 + 4.0, w2, h2), false, Color(0.82, 0.62, 0.5))
	var wrx := 19300.0 - dist
	if wrx > -200.0 and wrx < sw + 200.0:
		var ty := Terrain.surface_y(19300.0, gy)
		var tt: Texture2D = game.tex("se5a")
		draw_set_transform(Vector2(wrx, ty - 20.0) + _off, 0.18, Vector2.ONE)
		draw_texture_rect(tt, Rect2(-80.0, -30.0, 160.0, 160.0 * float(tt.get_height()) / float(tt.get_width())), false, Color(0.55, 0.5, 0.45))
		draw_set_transform(_off, 0.0, Vector2.ONE)
	var fdx := 18500.0 - dist
	if fdx > -160.0 and fdx < sw + 160.0:
		var fy := Terrain.surface_y(18500.0, gy)
		for k in range(5):
			var dx := fdx + float(k % 3) * 22.0 - 20.0
			var dy := fy - float(k / 3) * 24.0 - 2.0
			draw_rect(Rect2(dx - 9.0, dy - 22.0, 18.0, 22.0), Color(0.55, 0.22, 0.16))
			draw_rect(Rect2(dx - 9.0, dy - 22.0, 18.0, 22.0), INK, false, 1.5)
			draw_line(Vector2(dx - 9.0, dy - 12.0), Vector2(dx + 9.0, dy - 12.0), Color(0.3, 0.12, 0.1), 2.0)
		# sign
		draw_line(Vector2(fdx + 70.0, fy), Vector2(fdx + 70.0, fy - 54.0), Color(0.3, 0.22, 0.15), 3.0)
		draw_rect(Rect2(fdx + 40.0, fy - 70.0, 62.0, 22.0), Color(0.85, 0.72, 0.25))
		draw_rect(Rect2(fdx + 40.0, fy - 70.0, 62.0, 22.0), INK, false, 1.5)
		var f: Font = ThemeDB.fallback_font
		draw_string(f, Vector2(fdx + 47.0, fy - 54.0), "FUEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
		# floating pin
		var py := gy - 250.0 + sin(game.time * 2.0) * 4.0
		draw_circle(Vector2(fdx + 70.0, py), 17.0, Color(0.85, 0.65, 0.18))
		draw_circle(Vector2(fdx + 70.0, py), 17.0, INK, false, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(fdx + 61.0, py + 12.0), Vector2(fdx + 79.0, py + 12.0), Vector2(fdx + 70.0, py + 30.0)]), Color(0.85, 0.65, 0.18))
		draw_rect(Rect2(fdx + 63.0, py - 7.0, 12.0, 14.0), INK)
		draw_rect(Rect2(fdx + 75.0, py - 5.0, 3.0, 8.0), INK)
	var chx := 19900.0 - dist
	if chx > -160.0 and chx < sw + 160.0:
		var cy := Terrain.surface_y(19900.0, gy)
		draw_line(Vector2(chx - 60.0, cy), Vector2(chx - 60.0, cy - 60.0), Color(0.3, 0.26, 0.2), 4.0)
		draw_line(Vector2(chx - 60.0, cy - 60.0), Vector2(chx + 10.0, cy - 90.0), Color(0.3, 0.26, 0.2), 4.0)
		draw_line(Vector2(chx + 60.0, cy), Vector2(chx + 60.0, cy - 40.0), Color(0.3, 0.26, 0.2), 4.0)
		draw_line(Vector2(chx - 60.0, cy - 30.0), Vector2(chx + 60.0, cy - 40.0), Color(0.3, 0.26, 0.2), 3.0)
	# windsock at A and B
	for wsx in [600.0, 36000.0]:
		var wsc: float = wsx - dist
		if wsc > -40.0 and wsc < sw + 40.0:
			draw_line(Vector2(wsc, gy + 4.0), Vector2(wsc, gy - 60.0), Color(0.3, 0.26, 0.2), 3.0)
			var sway := sin(game.time * 3.0) * 4.0
			draw_colored_polygon(PackedVector2Array([Vector2(wsc, gy - 60.0), Vector2(wsc + 34.0, gy - 56.0 + sway), Vector2(wsc + 34.0, gy - 46.0 + sway), Vector2(wsc, gy - 50.0)]), Color(0.9, 0.55, 0.2))
	# map pin B
	var bx := Terrain.RUNWAY_B_START + 400.0 - dist
	if bx > -60.0 and bx < sw + 60.0:
		var by := gy - 240.0 + sin(game.time * 2.0) * 4.0
		draw_circle(Vector2(bx, by), 17.0, Color(0.64, 0.19, 0.14))
		draw_circle(Vector2(bx, by), 17.0, INK, false, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 9.0, by + 12.0), Vector2(bx + 9.0, by + 12.0), Vector2(bx, by + 30.0)]), Color(0.64, 0.19, 0.14))
		var f2: Font = ThemeDB.fallback_font
		draw_string(f2, Vector2(bx - 6.0, by + 6.0), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.94, 0.9, 0.78))
	# ambient smoke over the enemy base
	for sx_w in [28600.0, 30000.0, 31700.0]:
		var ssx: float = sx_w - dist
		if ssx < -80.0 or ssx > sw + 80.0:
			continue
		var sy := Terrain.surface_y(sx_w, gy)
		for k in range(6):
			var ph := fposmod(game.time * 0.18 + float(k) / 6.0, 1.0)
			draw_circle(Vector2(ssx + sin(ph * 4.0 + float(k)) * 10.0 + ph * 40.0, sy - 8.0 - ph * 190.0), 10.0 + ph * 34.0, Color(0.16, 0.15, 0.14, (1.0 - ph) * 0.5))

func _hangar(base: Vector2, w: float, h: float, col: Color, flash: bool) -> void:
	var c := col
	if flash:
		c = Color(minf(1.0, col.r * 1.8), minf(1.0, col.g * 1.8), minf(1.0, col.b * 1.8))
	var pts := PackedVector2Array([Vector2(base.x - w * 0.5, base.y)])
	for k in range(0, 13):
		var a := PI + PI * float(k) / 12.0
		pts.append(Vector2(base.x + cos(a) * w * 0.5, base.y - h * 0.35 + sin(a) * h * 0.65))
	pts.append(Vector2(base.x + w * 0.5, base.y))
	draw_colored_polygon(pts, c)
	for k in range(1, 6):
		var lx := base.x - w * 0.5 + w * float(k) / 6.0
		draw_line(Vector2(lx, base.y), Vector2(lx, base.y - h * 0.9 * sin(PI * float(k) / 6.0) + h * 0.2), Color(c.r * 0.7, c.g * 0.7, c.b * 0.7), 1.5)
	draw_rect(Rect2(base.x - w * 0.22, base.y - h * 0.5, w * 0.44, h * 0.5), Color(0.13, 0.13, 0.12))
	draw_polyline(pts, INK, 2.0)

# ---------------------------------------------------------------- bridge

func _draw_bridge(dist: float, gy: float, sw: float) -> void:
	var x0 := 23900.0
	var x1 := 24700.0
	if dist + sw < x0 or dist > x1:
		return
	var water := Terrain.surface_y((x0 + x1) * 0.5, gy)
	var deck := gy - 38.0
	var stone := Color(0.55, 0.50, 0.42)
	var sx0 := x0 - dist
	var sx1 := x1 - dist
	draw_rect(Rect2(sx0, deck, sx1 - sx0, water - deck + 8.0), stone)
	var span := 100.0
	var n := int((x1 - x0) / span)
	for i in range(n):
		var cx := sx0 + span * (float(i) + 0.5)
		var arc := PackedVector2Array()
		for k in range(0, 17):
			var a := PI + PI * float(k) / 16.0
			arc.append(Vector2(cx + cos(a) * 38.0, water + 8.0 + sin(a) * 40.0))
		draw_colored_polygon(arc, Color(0.30, 0.46, 0.56))
		draw_polyline(arc, INK, 2.0)
	draw_rect(Rect2(sx0, deck - 8.0, sx1 - sx0, 10.0), Color(0.40, 0.38, 0.33))
	draw_line(Vector2(sx0, deck - 8.0), Vector2(sx1, deck - 8.0), INK, 2.5)
	draw_rect(Rect2(sx0, deck, sx1 - sx0, water - deck + 8.0), INK, false, 2.0)

# ---------------------------------------------------------------- targets

func _draw_targets(dist: float, sw: float) -> void:
	for t in game.targets:
		if not t.alive:
			continue
		var sx: float = t.x - dist
		if sx < -200.0 or sx > sw + 200.0:
			continue
		var g_y: float = game.target_ground(t)
		var fl: bool = t.flash > 0.0
		var mod := Color(2.2, 2.2, 2.2) if fl else Color(1, 1, 1)
		match t.kind:
			"aa":
				_sprite("aa", Vector2(sx, g_y + 4.0), 66.0, mod)
			"tower":
				_sprite("tower", Vector2(sx, g_y + 4.0), 100.0, mod)
			"ship":
				_sprite("ship", Vector2(sx, g_y + 10.0 + sin(game.time * 1.6 + t.x) * 2.0), 74.0, mod)
			"truck":
				_truck(Vector2(sx, g_y), fl)
			"hangar":
				_hangar(Vector2(sx, g_y + 2.0), 170.0, 100.0, Color(0.42, 0.44, 0.38), fl)
			"fuel":
				_fuel_tank(Vector2(sx, g_y), fl)
			"parked":
				var tt: Texture2D = game.tex(t.ptex)
				var w := 150.0
				var h := w * float(tt.get_height()) / float(tt.get_width())
				draw_set_transform(Vector2(sx, g_y - h * 0.5 + 6.0) + _off, -0.05, Vector2.ONE)
				draw_texture_rect(tt, Rect2(-w * 0.5, -h * 0.5, w, h), false, mod)
				draw_set_transform(_off, 0.0, Vector2.ONE)
			_:
				_soldier(Vector2(sx, g_y), t, fl)

func _sprite(nm: String, base: Vector2, h: float, mod: Color) -> void:
	var tx: Texture2D = game.tex(nm)
	var w := h * float(tx.get_width()) / float(tx.get_height())
	draw_texture_rect(tx, Rect2(base.x - w * 0.5, base.y - h, w, h), false, mod)

func _truck(base: Vector2, fl: bool) -> void:
	var body := Color(0.33, 0.36, 0.25)
	var cab := Color(0.28, 0.31, 0.22)
	if fl:
		body = Color(0.8, 0.8, 0.7)
		cab = Color(0.8, 0.8, 0.7)
	draw_rect(Rect2(base.x - 37.0, base.y - 32.0, 46.0, 24.0), body)
	for k in range(1, 4):
		draw_line(Vector2(base.x - 37.0 + 11.0 * float(k), base.y - 32.0), Vector2(base.x - 37.0 + 11.0 * float(k), base.y - 8.0), Color(0, 0, 0, 0.3), 1.5)
	draw_rect(Rect2(base.x + 11.0, base.y - 26.0, 24.0, 18.0), cab)
	draw_rect(Rect2(base.x + 22.0, base.y - 24.0, 11.0, 8.0), Color(0.55, 0.65, 0.7))
	draw_rect(Rect2(base.x - 37.0, base.y - 32.0, 46.0, 24.0), INK, false, 1.5)
	draw_rect(Rect2(base.x + 11.0, base.y - 26.0, 24.0, 18.0), INK, false, 1.5)
	for wxo in [-26.0, -8.0, 24.0]:
		draw_circle(Vector2(base.x + wxo, base.y - 6.0), 7.0, Color(0.1, 0.1, 0.09))
		draw_circle(Vector2(base.x + wxo, base.y - 6.0), 3.0, Color(0.5, 0.48, 0.42))

func _fuel_tank(base: Vector2, fl: bool) -> void:
	var c := Color(0.62, 0.62, 0.58)
	if fl:
		c = Color(1, 1, 0.95)
	draw_rect(Rect2(base.x - 24.0, base.y - 56.0, 48.0, 56.0), c)
	draw_circle(Vector2(base.x, base.y - 56.0), 24.0, c)
	draw_rect(Rect2(base.x - 24.0, base.y - 38.0, 48.0, 8.0), Color(0.64, 0.19, 0.14))
	draw_rect(Rect2(base.x - 24.0, base.y - 18.0, 48.0, 4.0), Color(0.4, 0.4, 0.37))
	draw_line(Vector2(base.x - 24.0, base.y - 56.0), Vector2(base.x - 24.0, base.y), INK, 2.0)
	draw_line(Vector2(base.x + 24.0, base.y - 56.0), Vector2(base.x + 24.0, base.y), INK, 2.0)
	draw_arc(Vector2(base.x, base.y - 56.0), 24.0, PI, TAU, 12, INK, 2.0)
	draw_line(Vector2(base.x - 24.0, base.y), Vector2(base.x + 24.0, base.y), INK, 2.0)

func _soldier(base: Vector2, t: Dictionary, fl: bool) -> void:
	var col := Color(0.34, 0.36, 0.28)
	if fl:
		col = Color(0.95, 0.95, 0.85)
	draw_line(base + Vector2(-2, 0), base + Vector2(-3, -12), Color(0.2, 0.2, 0.17), 3.0)
	draw_line(base + Vector2(2, 0), base + Vector2(3, -12), Color(0.2, 0.2, 0.17), 3.0)
	draw_rect(Rect2(base.x - 5.0, base.y - 24.0, 10.0, 13.0), col)
	draw_circle(base + Vector2(0, -28.0), 4.2, Color(0.75, 0.6, 0.48))
	draw_arc(base + Vector2(0, -29.0), 5.0, PI, TAU, 8, Color(0.25, 0.27, 0.22), 3.0)
	# rifle aimed at the plane
	var gx: float = game.world_x() - t.x
	var gyy: float = game.player.y - (base.y - 20.0)
	var ang := atan2(gyy, gx)
	draw_line(base + Vector2(0, -20.0), base + Vector2(0, -20.0) + Vector2(cos(ang), sin(ang)) * 17.0, Color(0.12, 0.1, 0.08), 2.5)

func _draw_wrecks(dist: float, sw: float) -> void:
	for w in game.wrecks:
		var sx: float = w.x - dist
		if sx < -140.0 or sx > sw + 140.0 or w.kind == "soldier":
			continue
		var y := Terrain.surface_y(w.x, game.ground_y)
		if game.state == 4 and false:
			continue
		draw_rect(Rect2(sx - 24.0, y - 6.0, 48.0, 9.0), Color(0.1, 0.1, 0.09, 0.85))
		var big := 1.0
		if w.kind == "fuel" or w.kind == "hangar":
			big = 1.6
		for k in range(6):
			var ph := fposmod(game.time * 0.32 + float(k) / 6.0, 1.0)
			var r := (10.0 + ph * 26.0) * big
			var a := (1.0 - ph) * 0.65
			draw_circle(Vector2(sx + sin(ph * 5.0 + float(k)) * 8.0 + ph * 16.0, y - 10.0 - ph * 150.0 * big), r, Color(0.12, 0.12, 0.11, a))
		var fk := fposmod(game.time * 3.0 + w.x, 1.0)
		draw_circle(Vector2(sx, y - 10.0), 9.0 + fk * 3.0, Color(1.0, 0.55, 0.15, 0.55))

func _draw_crates(dist: float, sw: float) -> void:
	for c in game.crates:
		if c.taken:
			continue
		var sx: float = c.x - dist
		if sx < -60.0 or sx > sw + 60.0:
			continue
		var y: float = c.y + sin(game.time * 1.8 + c.x) * 8.0
		draw_arc(Vector2(sx, y - 34.0), 26.0, PI, TAU, 16, Color(0.85, 0.78, 0.6), 4.0)
		draw_line(Vector2(sx - 26.0, y - 34.0), Vector2(sx - 10.0, y - 8.0), INK, 1.5)
		draw_line(Vector2(sx + 26.0, y - 34.0), Vector2(sx + 10.0, y - 8.0), INK, 1.5)
		draw_rect(Rect2(sx - 14.0, y - 8.0, 28.0, 22.0), Color(0.45, 0.36, 0.22))
		draw_rect(Rect2(sx - 14.0, y - 8.0, 28.0, 22.0), INK, false, 2.0)
		draw_line(Vector2(sx - 14.0, y + 3.0), Vector2(sx + 14.0, y + 3.0), Color(0.64, 0.19, 0.14), 3.0)

# ---------------------------------------------------------------- aircraft

func _plane(tex_name: String, pos: Vector2, width: float, flip: bool, rot: float, mod: Color = Color(1, 1, 1)) -> void:
	var t: Texture2D = game.tex(tex_name)
	var h := width * float(t.get_height()) / float(t.get_width())
	draw_set_transform(pos + _off, rot, Vector2(-1.0 if flip else 1.0, 1.0))
	draw_texture_rect(t, Rect2(-width * 0.5, -h * 0.5, width, h), false, mod)
	draw_set_transform(_off, 0.0, Vector2.ONE)

func _draw_player() -> void:
	var g = game
	if g.state == 5:
		return
	var rot: float = clampf(g.vy / 520.0, -0.32, 0.32)
	if g.on_ground:
		rot = 0.0
	var pos: Vector2 = g.player
	_plane(g.plane.tex, pos, g.plane.width, false, rot)
	if g.speed > 20.0 and not g.on_ground or (g.on_ground and g.speed > 20.0):
		var nose: Vector2 = pos + Vector2(float(g.plane.width) * 0.47, -2.0).rotated(rot)
		draw_arc(nose, 20.0, -1.2 + rot, 1.2 + rot, 12, Color(0.9, 0.88, 0.8, 0.28), 3.0)
	if g.muzzle_t > 0.0:
		var k: float = g.muzzle_t / 0.07
		var nose2: Vector2 = pos + Vector2(float(g.plane.width) * 0.5 + 6.0, -4.0).rotated(rot)
		# glow reflected on the fuselage and cowling
		draw_circle(pos + Vector2(float(g.plane.width) * 0.28, -4.0).rotated(rot), 40.0, Color(1.0, 0.8, 0.4, 0.14 * k))
		draw_circle(pos + Vector2(float(g.plane.width) * 0.4, -4.0).rotated(rot), 24.0, Color(1.0, 0.85, 0.5, 0.22 * k))
		# muzzle flash star
		var star := PackedVector2Array()
		for i in range(10):
			var a := rot + TAU * float(i) / 10.0
			var r := 18.0 if i % 2 == 0 else 6.0
			star.append(nose2 + Vector2(cos(a), sin(a)) * r * (0.7 + 0.5 * k))
		draw_colored_polygon(star, Color(1.0, 0.9, 0.55, 0.95 * k))
		draw_circle(nose2, 5.0, Color(1, 1, 0.9, k))
	if g.hit_flash > 0.0:
		draw_circle(pos, 46.0, Color(0.7, 0.2, 0.1, g.hit_flash * 0.25))

func _draw_enemies(dist: float) -> void:
	for e in game.enemies:
		var sx: float = e.x - dist
		var rot: float = -clampf(e.pvy / 400.0, -0.3, 0.3)
		var mod := Color(2.2, 2.2, 2.2) if e.flash > 0.0 else Color(1, 1, 1)
		_plane(e.tex, Vector2(sx, e.y), e.w, true, rot, mod)

# ---------------------------------------------------------------- projectiles

func _tracer(head: Vector2, dir: Vector2, len: float, core: Color, glow: Color, w: float) -> void:
	var n := Vector2(-dir.y, dir.x)
	var tail := head - dir * len
	var tc := Color(core.r, core.g, core.b, 0.0)
	draw_polygon(PackedVector2Array([head + n * w, head - n * w, tail - n * w * 0.3, tail + n * w * 0.3]),
		PackedColorArray([core, core, tc, tc]))
	draw_circle(head, w * 3.2, glow)
	draw_circle(head, w * 1.4, Color(1.0, 0.98, 0.85))

func _draw_bullets(dist: float) -> void:
	# drawn BEFORE the plane so tracers appear to leave from behind the aircraft
	for b in game.bullets:
		var head := Vector2(b.x - dist, b.y)
		var dir := Vector2(b.vx - game.speed, b.vy).normalized()
		var len := 30.0 * minf(1.0, b.age * 14.0)
		_tracer(head, dir, len, Color(1.0, 0.78, 0.28), Color(1.0, 0.6, 0.2, 0.28), 1.8)

func _draw_ebullets(dist: float) -> void:
	for b in game.ebullets:
		var head := Vector2(b.x - dist, b.y)
		var dir := Vector2(b.vx, b.vy).normalized()
		match b.kind:
			"flak":
				draw_circle(head, 7.0, Color(0.14, 0.12, 0.1))
				draw_circle(head, 7.0, Color(1.0, 0.5, 0.2, 0.5), false, 2.0)
				draw_line(head, head - dir * 22.0, Color(0.3, 0.26, 0.22, 0.7), 3.0)
			"rifle":
				_tracer(head, dir, 14.0, Color(1.0, 0.9, 0.5), Color(1.0, 0.8, 0.3, 0.18), 1.0)
			_:
				_tracer(head, dir, 24.0, Color(1.0, 0.45, 0.2), Color(1.0, 0.3, 0.1, 0.25), 1.6)

func _bomb_shape(c: Vector2, ang: float) -> void:
	draw_set_transform(c + _off, ang, Vector2.ONE)
	# tail fins
	draw_colored_polygon(PackedVector2Array([Vector2(-10, 3), Vector2(-19, 10), Vector2(-21, 10), Vector2(-16, 3)]), Color(0.27, 0.28, 0.24))
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -3), Vector2(-19, -10), Vector2(-21, -10), Vector2(-16, -3)]), Color(0.27, 0.28, 0.24))
	draw_colored_polygon(PackedVector2Array([Vector2(-9, 3.5), Vector2(-18, 2), Vector2(-18, -2), Vector2(-9, -3.5)]), Color(0.36, 0.37, 0.33))
	# body
	var top := [Vector2(14, 0), Vector2(12, 3), Vector2(8, 5.6), Vector2(1, 7.0), Vector2(-6, 6.2), Vector2(-10, 3.6)]
	var body := PackedVector2Array()
	for p in top:
		body.append(p)
	for i in range(top.size() - 1, -1, -1):
		body.append(Vector2(top[i].x, -top[i].y))
	draw_colored_polygon(body, Color(0.30, 0.34, 0.22))
	draw_rect(Rect2(3.0, -6.6, 3.0, 13.2), Color(0.82, 0.7, 0.24))
	draw_line(Vector2(-6, -4.5), Vector2(10, -4.2), Color(0.55, 0.6, 0.4, 0.8), 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(14, 0), Vector2(12, 3), Vector2(10.5, 0), Vector2(12, -3)]), Color(0.18, 0.18, 0.15))
	draw_polyline(body, INK, 1.4, true)
	draw_set_transform(_off, 0.0, Vector2.ONE)

func _draw_bombs(dist: float) -> void:
	for bm in game.bombs:
		var rel_vx: float = bm.vx - game.speed
		var ang := atan2(bm.vy, rel_vx)
		_bomb_shape(Vector2(bm.x - dist, bm.y), ang)

# ---------------------------------------------------------------- particles

func _draw_particles(dist: float) -> void:
	for p in game.parts:
		var sx: float = p.x - dist
		if sx < -120.0 or sx > game.screen.x + 120.0:
			continue
		var pos := Vector2(sx, p.y)
		var k: float = p.t / p.life
		var col: Color = p.col
		match p.kind:
			"spark":
				var v := Vector2(p.vx, p.vy)
				draw_line(pos, pos - v * 0.03, Color(col.r, col.g, col.b, 1.0 - k), 2.0)
			"debris", "dirt":
				draw_set_transform(pos + _off, p.rot, Vector2.ONE)
				draw_rect(Rect2(-p.size * 0.5, -p.size * 0.35, p.size, p.size * 0.7), Color(col.r, col.g, col.b, minf(1.0, (1.0 - k) * 1.6)))
				draw_set_transform(_off, 0.0, Vector2.ONE)
			"dust":
				draw_circle(pos, p.size * (0.5 + k), Color(col.r, col.g, col.b, (1.0 - k) * 0.42))
			"fire":
				var fc := col.lerp(Color(0.75, 0.2, 0.08), k)
				draw_circle(pos, p.size * (1.0 - 0.4 * k), Color(fc.r, fc.g, fc.b, (1.0 - k) * 0.9))
			"smoke":
				draw_circle(pos, p.size * (0.6 + 1.2 * k), Color(col.r, col.g, col.b, (1.0 - k) * 0.45))
			"ring":
				draw_arc(pos, p.size * k, 0.0, TAU, 28, Color(col.r, col.g, col.b, (1.0 - k) * 0.8), 3.0)
			"flash":
				var a := (1.0 - k) * (1.0 - k)
				draw_circle(pos, p.size * (0.6 + 0.5 * k), Color(col.r, col.g, col.b, a))
			"frag":
				var tt: Texture2D = game.tex(p.tex)
				draw_set_transform(pos + _off, p.rot, Vector2(-1.0 if p.flip else 1.0, 1.0))
				draw_texture_rect_region(tt, Rect2(-p.pw * 0.5, -p.ph * 0.5, p.pw, p.ph), p.src, Color(1, 1, 1, minf(1.0, (1.0 - k) * 2.5)))
				draw_set_transform(_off, 0.0, Vector2.ONE)
			"text":
				var f: Font = ThemeDB.fallback_font
				draw_string(f, pos, p.txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(col.r, col.g, col.b, 1.0 - k * k))

# ---------------------------------------------------------------- overlay

func _draw_overlay(sw: float, sh: float, wx: float, gy: float) -> void:
	# biome colour grading
	var tint := Color(0, 0, 0, 0)
	var parts := [
		[Terrain.w_farm(wx), Color(1.0, 0.92, 0.7, 0.07)],
		[Terrain.w_forest(wx), Color(0.7, 0.95, 0.7, 0.06)],
		[Terrain.w_mount(wx), Color(0.75, 0.88, 1.0, 0.08)],
		[Terrain.w_valley(wx), Color(1.0, 0.8, 0.5, 0.1)],
		[Terrain.sea_w(wx), Color(0.7, 0.92, 1.0, 0.07)],
		[Terrain.w_base(wx), Color(0.9, 0.5, 0.35, 0.16)],
	]
	for p in parts:
		var w: float = p[0]
		if w > 0.01:
			var c: Color = p[1]
			draw_rect(Rect2(0, 0, sw, sh), Color(c.r, c.g, c.b, c.a * w))
	# thin air: sky deepens and the world gets cooler
	var alt: float = maxf(0.0, gy - game.player.y)
	var thin := clampf(alt / 1000.0, 0.0, 1.0)
	if thin > 0.01:
		var d := Color(0.05, 0.1, 0.25, 0.32 * thin)
		var z := Color(0.05, 0.1, 0.25, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(sw, 0), Vector2(sw, sh * 0.7), Vector2(0, sh * 0.7)]), PackedColorArray([d, d, z, z]))
	# paper grain, sepia tint, vignette
	draw_texture_rect(game.tex("paper"), Rect2(0, 0, sw, sh), true, Color(1, 1, 1, 0.14))
	draw_rect(Rect2(0, 0, sw, sh), Color(0.72, 0.58, 0.38, 0.07))
	var dk := Color(0.05, 0.04, 0.03, 0.4)
	var zz := Color(0.05, 0.04, 0.03, 0.0)
	var m := 110.0
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(sw, 0), Vector2(sw, m), Vector2(0, m)]), PackedColorArray([dk, dk, zz, zz]))
	draw_polygon(PackedVector2Array([Vector2(0, sh - m), Vector2(sw, sh - m), Vector2(sw, sh), Vector2(0, sh)]), PackedColorArray([zz, zz, dk, dk]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(m, 0), Vector2(m, sh), Vector2(0, sh)]), PackedColorArray([dk, zz, zz, dk]))
	draw_polygon(PackedVector2Array([Vector2(sw - m, 0), Vector2(sw, 0), Vector2(sw, sh), Vector2(sw - m, sh)]), PackedColorArray([zz, dk, dk, zz]))
