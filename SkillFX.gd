extends Node2D

# Effet visuel d'attaque / de compétence. Instancié par Battle, s'anime via un
# tween (progression 0→1) puis se libère tout seul. Cosmétique uniquement : il
# n'altère jamais l'état du combat.
#
# Utilisation :
#   var fx := SKILL_FX.new()
#   fx.setup("projectile", from_local, to_local, color)
#   grid.add_child(fx)
#
# Les positions sont en coordonnées LOCALES à la grille (grid.cell_to_local()).

var kind := "projectile"
var from_pos := Vector2.ZERO
var to_pos := Vector2.ZERO
var fx_color := Color.WHITE
var radius_px := 32.0     # rayon visé pour nova / explosion
var _t := 0.0             # progression d'animation (0..1), pilote _draw


func setup(k: String, fpos: Vector2, tpos: Vector2, col: Color, rad_px := 32.0) -> void:
	kind = k
	from_pos = fpos
	to_pos = tpos
	fx_color = col
	radius_px = rad_px


func _ready() -> void:
	z_index = 90
	var dur := 0.28
	match kind:
		"beam":
			dur = 0.32
		"nova", "explosion":
			dur = 0.42
		"slash":
			dur = 0.22
		"buff", "debuff":
			dur = 0.5
		"teleport":
			dur = 0.3
	var tw := create_tween()
	tw.tween_method(_set_t, 0.0, 1.0, dur)
	tw.tween_callback(queue_free)


func _set_t(v: float) -> void:
	_t = v
	queue_redraw()


func _draw() -> void:
	match kind:
		"projectile":
			_draw_projectile()
		"beam":
			_draw_beam()
		"nova":
			_draw_nova()
		"explosion":
			_draw_explosion()
		"slash":
			_draw_slash()
		"buff":
			_draw_aura(from_pos, false)
		"debuff":
			_draw_aura(to_pos, true)
		"teleport":
			_draw_teleport()


# Flèche / projectile qui file de la source vers la cible, avec pointe + traînée.
func _draw_projectile() -> void:
	var p := from_pos.lerp(to_pos, minf(_t, 1.0))
	var dir := to_pos - from_pos
	dir = dir.normalized() if dir.length() > 1.0 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	# Traînée
	draw_line(p - dir * 22.0, p, Color(fx_color, 0.45), 3.0)
	# Corps
	draw_line(p - dir * 12.0, p, fx_color, 3.0)
	# Pointe
	draw_colored_polygon(PackedVector2Array([
		p + dir * 7.0, p - dir * 4.0 + perp * 4.0, p - dir * 4.0 - perp * 4.0]), fx_color)
	# Flash d'impact en fin de course
	if _t > 0.82:
		var k := (_t - 0.82) / 0.18
		draw_circle(to_pos, 16.0 * k, Color(fx_color, 0.5 * (1.0 - k)))


# Trait d'énergie (tir perforant) : ligne pleine qui s'estompe.
func _draw_beam() -> void:
	var a := 1.0 - _t
	draw_line(from_pos, to_pos, Color(fx_color, a), 5.0 * a + 1.0)
	draw_line(from_pos, to_pos, Color(1, 1, 1, a * 0.6), 2.0)
	draw_circle(to_pos, 9.0, Color(fx_color, a))


# Anneau qui se propage (gel, déflagration de zone).
func _draw_nova() -> void:
	var a := 1.0 - _t
	var r := maxf(3.0, radius_px * _t)
	draw_arc(to_pos, r, 0.0, TAU, 48, Color(fx_color, a), 4.0)
	draw_arc(to_pos, r * 0.6, 0.0, TAU, 40, Color(fx_color, a * 0.6), 3.0)


# Explosion pleine qui grossit et s'estompe.
func _draw_explosion() -> void:
	var a := (1.0 - _t) * 0.7
	var r := maxf(3.0, radius_px * (0.4 + 0.6 * _t))
	draw_circle(to_pos, r, Color(fx_color, a))
	draw_arc(to_pos, r, 0.0, TAU, 48, Color(1, 1, 1, a), 2.0)


# Arc de lame qui balaie devant la cible (coup de mêlée).
func _draw_slash() -> void:
	var a := 1.0 - _t
	var dir := to_pos - from_pos
	var base := dir.angle() if dir.length() > 1.0 else 0.0
	var start := base - 0.9 + _t * 0.6
	draw_arc(to_pos, 28.0, start, start + 1.6, 18, Color(fx_color, a), 5.0)
	draw_arc(to_pos, 22.0, start, start + 1.6, 18, Color(1, 1, 1, a * 0.7), 2.0)


# Halo montant sur une unité (buff = doré/clair, debuff = sombre/violacé).
func _draw_aura(center: Vector2, downward: bool) -> void:
	var a := 1.0 - _t
	var rise := -18.0 * _t if not downward else 18.0 * _t
	var r := 26.0 + 8.0 * sin(_t * PI)
	draw_arc(center + Vector2(0, rise), r, 0.0, TAU, 40, Color(fx_color, a), 3.0)
	# Quelques éclats
	for i in 6:
		var ang := TAU * i / 6.0 + _t * 2.0
		var pt := center + Vector2(cos(ang), sin(ang)) * r + Vector2(0, rise)
		draw_circle(pt, 3.0 * a, Color(fx_color, a))


# Téléportation : la source s'efface, la destination apparaît.
func _draw_teleport() -> void:
	var a := 1.0 - _t
	draw_circle(from_pos, 20.0 * (1.0 - _t), Color(fx_color, a * 0.55))
	draw_circle(to_pos, 20.0 * _t, Color(fx_color, a))
	draw_arc(to_pos, 24.0 * _t, 0.0, TAU, 32, Color(1, 1, 1, a), 2.0)
