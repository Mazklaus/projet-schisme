class_name PostSoleil
extends CanvasLayer
## Soleil peint d'un plan (« cle » de type soleil, Ullanor) : halo additif autour du point et rais
## par flou radial des zones claires depuis le soleil, à rais_force × 0,45, comme l'assemblage de la
## DA (tranche-verticale/assembler.py). Passe d'image sous l'interface (calque 1).

const SHADER := """
shader_type canvas_item;
uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;
uniform vec2 soleil = vec2(0.6, 0.52);
uniform vec4 couleur : source_color = vec4(1.0, 0.91, 0.69, 1.0);
uniform float rais = 1.0;
uniform float halo = 1.0;
uniform float aspect = 1.7778;
uniform float seuil = 0.6;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 base = textureLod(ecran, uv, 0.0).rgb;
	float acc = 0.0;
	for (int i = 0; i < 24; i++) {
		float s = 1.0 - float(i) * 0.022;
		vec2 p = soleil + (uv - soleil) * s;
		vec3 c = textureLod(ecran, p, 1.0).rgb;
		float l = (c.r + c.g + c.b) / 3.0;
		acc += clamp((l - seuil) / (1.0 - seuil), 0.0, 1.0);
	}
	vec2 d = (uv - soleil) * vec2(aspect, 1.0);
	float r = length(d);
	float h = exp(-r * r / 0.003) * 0.7 + exp(-r / 0.3) * 0.4;
	vec3 ajout = couleur.rgb * (acc / 24.0 * rais * 0.45 + h * halo);
	COLOR = vec4(base + ajout, 1.0);
}
"""

static var _shader: Shader
var decor: Node2D
var position_px := Vector2.ZERO
var _rect: ColorRect


func _init() -> void:
	name = "PostSoleil"
	layer = 1
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	_rect.material = m
	add_child(_rect)
	visible = false


## Règle la passe sur le décor affiché : visible seulement si sa clé est un soleil peint.
func suivre(d: Node2D) -> void:
	decor = d
	var cle: Dictionary = d.get_meta("cle", {}) if d else {}
	visible = String(cle.get("type", "")).contains("soleil") and typeof(cle.get("position_px")) == TYPE_ARRAY
	if not visible:
		return
	position_px = Vector2(cle.position_px[0], cle.position_px[1])
	var m := _rect.material as ShaderMaterial
	m.set_shader_parameter("couleur", Color(String(cle.get("couleur", "#FFE8B0"))))
	m.set_shader_parameter("rais", float(d.get_meta("rais_force", 1.0)))


func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(decor) or not decor.is_visible_in_tree():
		if visible and not (is_instance_valid(decor) and decor.is_visible_in_tree()):
			visible = false
		return
	var vp := get_viewport()
	var taille := vp.get_visible_rect().size
	# Le soleil est peint dans le ciel (calque 00_, parallaxe propre) : on suit ce calque.
	var repere: Node2D = decor
	for c in decor.get("calques") if decor.get("calques") != null else []:
		if String(c.name).begins_with("Calque_00_"):
			repere = c
			break
	var ecran := repere.get_global_transform_with_canvas() * position_px
	var m := _rect.material as ShaderMaterial
	m.set_shader_parameter("soleil", ecran / taille)
	m.set_shader_parameter("aspect", taille.x / taille.y)

