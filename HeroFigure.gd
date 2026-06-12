class_name HeroFigure

# Dessin du héros de campagne, partagé entre l'écran de création de personnage
# (aperçu) et l'exploration (Overworld.Walker). 100 % vectoriel, animé.
# 3 designs par sexe (peau + coiffure), tunique teintée par la classe choisie.

const SKINS := [Color(0.94, 0.80, 0.62), Color(0.80, 0.60, 0.42), Color(0.55, 0.38, 0.28)]
const HAIRS_F := [Color(0.85, 0.70, 0.30), Color(0.26, 0.18, 0.12), Color(0.62, 0.30, 0.18)]
const HAIRS_M := [Color(0.32, 0.22, 0.14), Color(0.16, 0.13, 0.16), Color(0.70, 0.66, 0.58)]

const DESIGN_COUNT := 3


# Dessine le héros debout sur (0,0), tourné vers la droite (miroir = transform).
static func draw_hero(ci: CanvasItem, gender: String, design: int, tint: Color,
		phase: float, moving: bool) -> void:
	design = clampi(design, 0, DESIGN_COUNT - 1)
	var b := sin(phase) * (1.4 if moving else 0.5)   # rebond de marche
	var sw := sin(phase) * 3.5 if moving else 0.0    # balancement des jambes
	var skin: Color = SKINS[design]
	# Jambes.
	var leg := Color(0.16, 0.14, 0.18)
	ci.draw_line(Vector2(-2.0, -7.0 + b * 0.5), Vector2(-2.0 - sw, 0.0), leg, 3.0)
	ci.draw_line(Vector2(2.0, -7.0 + b * 0.5), Vector2(2.0 + sw, 0.0), leg, 3.0)
	# Cape de voyage (dans le dos, ondule).
	var sway := sin(phase * 0.9) * (1.6 if moving else 0.5)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-3.0, -16.0 + b), Vector2(-6.5, -14.0 + b),
		Vector2(-8.5 - sway, -2.0), Vector2(-3.5, -4.0)]),
		Color(0.50, 0.14, 0.16))
	# Tunique teintée par la classe (assombrie pour rester lisible) + ceinture.
	var tun := Color(tint.r * 0.72, tint.g * 0.72, tint.b * 0.72)
	var shoulder := 4.4 if gender == "f" else 5.2
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-shoulder, -17.0 + b), Vector2(shoulder, -17.0 + b),
		Vector2(6.0, -7.0 + b), Vector2(-6.0, -7.0 + b)]), tun)
	ci.draw_rect(Rect2(-6.0, -9.5 + b, 12.0, 2.2), Color(0.24, 0.18, 0.10))
	# Bras (balancement opposé aux jambes).
	var arm := tun.darkened(0.18)
	ci.draw_line(Vector2(-shoulder - 0.3, -15.0 + b), Vector2(-5.5 + sw * 0.6, -8.5 + b), arm, 2.5)
	ci.draw_line(Vector2(shoulder + 0.3, -15.0 + b), Vector2(5.5 - sw * 0.6, -8.5 + b), arm, 2.5)
	# Tête.
	ci.draw_circle(Vector2(0.0, -21.5 + b), 4.6, skin)
	# Coiffure (sexe + design).
	if gender == "f":
		var hair: Color = HAIRS_F[design]
		match design:
			0:  # longs cheveux dans le dos (quad propre : TL, TR, BR, BL)
				ci.draw_circle(Vector2(-0.8, -23.3 + b), 3.9, hair)
				ci.draw_colored_polygon(PackedVector2Array([
					Vector2(-5.0, -24.8 + b), Vector2(-0.5, -25.6 + b),
					Vector2(-2.6, -10.0 + b + sway * 0.4),
					Vector2(-6.2, -11.5 + b + sway * 0.4)]), hair)
			1:  # queue de cheval haute
				ci.draw_circle(Vector2(-0.8, -23.3 + b), 3.8, hair)
				ci.draw_line(Vector2(-3.4, -24.0 + b), Vector2(-6.8, -15.5 + b + sway * 0.5), hair, 2.8)
				ci.draw_circle(Vector2(-3.4, -24.0 + b), 1.6, hair)
			2:  # carré court
				ci.draw_circle(Vector2(-0.6, -23.2 + b), 4.0, hair)
				ci.draw_rect(Rect2(-5.2, -23.2 + b, 2.8, 6.2), hair)
				ci.draw_rect(Rect2(2.6, -23.2 + b, 2.2, 4.0), hair)
	else:
		var hair: Color = HAIRS_M[design]
		match design:
			0:  # court classique
				ci.draw_circle(Vector2(-0.8, -23.3 + b), 3.6, hair)
			1:  # hirsute + barbe
				ci.draw_circle(Vector2(-0.5, -23.6 + b), 4.2, hair)
				ci.draw_circle(Vector2(-3.2, -22.0 + b), 2.2, hair)
				ci.draw_colored_polygon(PackedVector2Array([
					Vector2(1.2, -19.8 + b), Vector2(4.4, -20.6 + b),
					Vector2(3.2, -16.6 + b)]), hair)
			2:  # bandana (crâne dégagé)
				ci.draw_circle(Vector2(-0.6, -23.0 + b), 3.4, hair)
				ci.draw_rect(Rect2(-4.6, -25.2 + b, 9.2, 2.8), Color(0.55, 0.16, 0.16))
	# Œil (donne le sens du regard).
	ci.draw_circle(Vector2(2.0, -21.3 + b), 0.9, Color(0.12, 0.10, 0.12))
