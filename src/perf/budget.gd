class_name BudgetPerf
extends RefCounted
## Budget de performance du jeu sur PC (Lead Programmer, 2026-11-18).
##
## Machine de référence : PC de jeu milieu de gamme de 2018 environ (GTX 1060 6 Go ou
## Radeon RX 580, 4 cœurs, 8 Go de RAM), en 1920×1080. Cible : 60 images/s constantes,
## cinématiques comprises. Ces seuils sont vérifiés par les tests (tests/unit/test_budget.gd)
## sur les décors du dépôt, et affichés en jeu par le moniteur (F3).

## Temps d'image maximal (ms) pour 60 i/s.
const IMAGE_MS := 16.6
## Mémoire de textures d'un décor 2.5D (couleur + normales, RGBA8 non compressé), en Mio.
## 256 Mio ≈ 8 calques 4K avec normales ; la machine de référence a 6 Go de VRAM.
const DECOR_TEXTURES_MIO := 256.0
## Côté maximal d'un calque, en pixels (limite de texture sûre sur toutes les cartes).
const CALQUE_COTE_MAX := 8192
## Nombre de calques par décor.
const CALQUES_MAX := 16
## Lumières 2D actives à l'écran : chaque lumière redessine les calques qu'elle touche.
const LUMIERES_MAX := 8
## Appels de dessin 2D par image.
const APPELS_DESSIN_MAX := 1000
## Taille d'un paquet d'épisode (.pck) téléchargé, en Mo.
const EPISODE_PAQUET_MO := 2048.0


## Vérifie un décor construit. Renvoie la liste des dépassements (vide si tout va bien).
static func verifier_decor(decor: Decor25D) -> PackedStringArray:
	var e: PackedStringArray = []
	var mio := decor.memoire_textures() / 1048576.0
	if mio > DECOR_TEXTURES_MIO:
		e.append("%s : %.0f Mio de textures (max %.0f)" % [decor.id_decor, mio, DECOR_TEXTURES_MIO])
	if decor.calques.size() > CALQUES_MAX:
		e.append("%s : %d calques (max %d)" % [decor.id_decor, decor.calques.size(), CALQUES_MAX])
	for c in decor.calques:
		var tex := (c.get_node("Image") as Sprite2D).texture as CanvasTexture
		var t := tex.diffuse_texture
		if t and maxi(t.get_width(), t.get_height()) > CALQUE_COTE_MAX:
			e.append("%s/%s : côté > %d px" % [decor.id_decor, c.name, CALQUE_COTE_MAX])
		if tex.normal_texture and tex.normal_texture.get_size() != t.get_size():
			e.append("%s/%s : normales d'une autre taille que l'image" % [decor.id_decor, c.name])
	return e
