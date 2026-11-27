"""Passes supplémentaires pour les sprites en pied, sans toucher aux scripts de CA1.

    <python bpy> passes_blender.py <script_ca1.py> <arguments du script…>

Lance le script de rendu de CA1 (astartes_pied.py, soldat_pied.py…) tel quel et, à chaque rendu
couleur qu'il écrit (<nom>_rgb.png), rend dans la même scène, au même cadrage :
  - <nom>_albedo.png : albédo × occlusion, sans lampe, sous un ciel blanc uniforme (seules les
    Light2D du jeu éclairent ; contrat Gameplay 27/11) ;
  - <nom>_nmonde.png : normale monde (n·0,5+0,5, 16 bits, Raw), convertie en espace caméra
    OpenGL Y+ par preparer_sprite.py (le VectorTransform vers la caméra de Blender 5 sans GPU
    renvoie une valeur constante).
"""
import os
import runpy
import sys

import bpy

script = sys.argv[1]
sys.argv = [script] + sys.argv[2:]

_rendu = bpy.ops.render.render
_mat_normale = None


def mat_normale():
    global _mat_normale
    if _mat_normale is None:
        m = bpy.data.materials.new("tools_normale_monde")
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        g = nt.nodes.new("ShaderNodeNewGeometry")
        vm = nt.nodes.new("ShaderNodeVectorMath")
        vm.operation = "MULTIPLY_ADD"
        vm.inputs[1].default_value = (0.5, 0.5, 0.5)
        vm.inputs[2].default_value = (0.5, 0.5, 0.5)
        e = nt.nodes.new("ShaderNodeEmission")
        o = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(g.outputs["Normal"], vm.inputs[0])
        nt.links.new(vm.outputs[0], e.inputs[0])
        nt.links.new(e.outputs[0], o.inputs[0])
        _mat_normale = m
    return _mat_normale


def passes(sc, base):
    vl = sc.view_layers[0]
    chemin, vt, spp, ov = sc.render.filepath, sc.view_settings.view_transform, sc.cycles.samples, vl.material_override
    # albédo × occlusion : lampes coupées, ciel blanc uniforme
    lampes = [o for o in sc.objects if o.type == "LIGHT" and not o.hide_render]
    for o in lampes:
        o.hide_render = True
    w = sc.world
    fond = w.node_tree.nodes.get("Background") if w and w.use_nodes else None
    sauve = (tuple(fond.inputs[0].default_value), fond.inputs[1].default_value) if fond else None
    if fond:
        fond.inputs[0].default_value = (1, 1, 1, 1)
        fond.inputs[1].default_value = 1.0
    sc.view_settings.view_transform = "Standard"
    sc.render.filepath = base + "_albedo.png"
    _rendu(write_still=True)
    for o in lampes:
        o.hide_render = False
    if fond:
        fond.inputs[0].default_value, fond.inputs[1].default_value = sauve
    # normale monde
    vl.material_override = mat_normale()
    sc.view_settings.view_transform = "Raw"
    sc.cycles.samples = 8
    sc.render.filepath = base + "_nmonde.png"
    _rendu(write_still=True)
    sc.render.filepath, sc.view_settings.view_transform, sc.cycles.samples, vl.material_override = chemin, vt, spp, ov


def rendu(*args, **kw):
    r = _rendu(*args, **kw)
    sc = bpy.context.scene
    f = bpy.path.abspath(sc.render.filepath)
    if kw.get("write_still") and f.endswith("_rgb.png") and sc.view_layers[0].material_override is None:
        passes(sc, f[:-len("_rgb.png")])
    return r


class _SousModuleRendu:
    """bpy.ops.render recréé à chaque accès : on pose un remplaçant dans le module bpy.ops."""
    def __init__(self, vrai):
        self._vrai = vrai

    def __getattr__(self, nom):
        return rendu if nom == "render" else getattr(self._vrai, nom)


import bpy.ops  # noqa: E402
bpy.ops.__dict__["render"] = _SousModuleRendu(bpy.ops.render)
runpy.run_path(script, run_name="__main__")
