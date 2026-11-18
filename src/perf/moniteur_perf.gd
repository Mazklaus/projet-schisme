extends CanvasLayer
## Moniteur de performance (autoload « MoniteurPerf ») : F3 l'affiche ou le masque.
## Montre les compteurs du moteur comparés au budget (BudgetPerf). Rouge = dépassement.

var _label: Label
var _pire_image_ms := 0.0
var _remise := 0.0


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("basculer_perf"):
		visible = not visible


func _process(delta: float) -> void:
	if not visible:
		return
	var image_ms := delta * 1000.0
	_pire_image_ms = maxf(_pire_image_ms, image_ms)
	_remise += delta
	if _remise > 2.0:
		_remise = 0.0
		_pire_image_ms = image_ms
	var appels := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var vram := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	var lignes := [
		"%d i/s" % Engine.get_frames_per_second(),
		"image %.1f ms (pire %.1f / %.1f)" % [image_ms, _pire_image_ms, BudgetPerf.IMAGE_MS],
		"appels de dessin %d / %d" % [appels, BudgetPerf.APPELS_DESSIN_MAX],
		"textures %.0f Mio" % vram,
		"nœuds %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	]
	_label.text = "\n".join(lignes)
	var depasse := _pire_image_ms > BudgetPerf.IMAGE_MS or appels > BudgetPerf.APPELS_DESSIN_MAX
	_label.modulate = Color(1, 0.4, 0.4) if depasse else Color.WHITE
