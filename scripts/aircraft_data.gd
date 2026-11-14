class_name AircraftData
extends RefCounted

# Ordered weakest -> strongest (unlock order).
# vmax = top speed in px/s of world scroll. Below 80% of vmax the plane sinks.
const LIST := [
	{"name": "S.E.5a", "fa": "اس.ای.۵ای", "role": "Fighter - balanced all-rounder", "tex": "se5a", "width": 176.0,
	 "vmax": 235.0, "climb": 1.0, "hp": 100.0, "ammo": 10, "bombs": 3, "fuel": 100.0, "fire_cd": 0.36,
	 "stat_speed": 0.5, "stat_armor": 0.5, "stat_fire": 0.45},
	{"name": "I-16", "fa": "ای-۱۶", "role": "Fighter - maneuverable, close combat", "tex": "i16", "width": 162.0,
	 "vmax": 255.0, "climb": 1.2, "hp": 110.0, "ammo": 12, "bombs": 3, "fuel": 100.0, "fire_cd": 0.32,
	 "stat_speed": 0.62, "stat_armor": 0.55, "stat_fire": 0.55},
	{"name": "F2A Buffalo", "fa": "اف۲ای بوفالو", "role": "Fighter - high speed, light armor", "tex": "buffalo", "width": 176.0,
	 "vmax": 285.0, "climb": 1.1, "hp": 95.0, "ammo": 14, "bombs": 4, "fuel": 95.0, "fire_cd": 0.28,
	 "stat_speed": 0.85, "stat_armor": 0.45, "stat_fire": 0.72},
	{"name": "He 111", "fa": "هاینکل ۱۱۱", "role": "Bomber - heavy firepower, low agility", "tex": "he111", "width": 214.0,
	 "vmax": 225.0, "climb": 0.7, "hp": 200.0, "ammo": 16, "bombs": 8, "fuel": 130.0, "fire_cd": 0.3,
	 "stat_speed": 0.4, "stat_armor": 0.95, "stat_fire": 0.9},
]
