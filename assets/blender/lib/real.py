# Materials and helpers for a more realistic, space-themed look (user, 2026-11-08: "too cartoony,
# more realistic and closer to space"). Procedural shader nodes for the concept renders; for the
# game the chosen look is baked to textures (Roblox SurfaceAppearance takes colour, normal,
# roughness and metalness maps).

import bpy


def _principled(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    return mat, nodes, mat.node_tree.links, nodes.get("Principled BSDF")


def _noise_ramp(nodes, links, scale, detail, colors, positions=None):
    """A noise texture through a colour ramp; returns the ramp's colour output."""
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = detail
    ramp = nodes.new("ShaderNodeValToRGB")
    elements = ramp.color_ramp.elements
    positions = positions or [i / (len(colors) - 1) for i in range(len(colors))]
    while len(elements) < len(colors):
        elements.new(0.5)
    for element, color, position in zip(elements, colors, positions):
        element.position = position
        element.color = (*color, 1.0)
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    return noise, ramp.outputs["Color"]


def _bump(nodes, links, bsdf, scale, strength):
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 8
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


def jelly(name, color, glow=0.0):
    """Translucent living jelly: light passes through, a soft sheen, a faint inner glow."""
    mat, nodes, links, bsdf = _principled(name)
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.12
    bsdf.inputs["Transmission Weight"].default_value = 0.65
    bsdf.inputs["IOR"].default_value = 1.33
    bsdf.inputs["Subsurface Weight"].default_value = 0.3
    bsdf.inputs["Coat Weight"].default_value = 0.5
    if glow > 0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = glow
    _bump(nodes, links, bsdf, 6.0, 0.15)
    mat.diffuse_color = (*color, 1.0)
    return mat


def chitin(name, color, dark, metallic=0.25):
    """An alien carapace: mottled colour, a hard lacquered shine, a rough relief."""
    mat, nodes, links, bsdf = _principled(name)
    _, colour = _noise_ramp(nodes, links, 4.0, 6, [dark, color, color], [0.3, 0.6, 1.0])
    links.new(colour, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.32
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Coat Weight"].default_value = 0.8
    bsdf.inputs["Coat Roughness"].default_value = 0.12
    _bump(nodes, links, bsdf, 14.0, 0.35)
    mat.diffuse_color = (*color, 1.0)
    return mat


def crystal(name, color, glow=0.0):
    """Clear faceted crystal: refracts, sharp highlights, a cold glow from within."""
    mat, nodes, links, bsdf = _principled(name)
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.02
    bsdf.inputs["Transmission Weight"].default_value = 1.0
    bsdf.inputs["IOR"].default_value = 1.5
    if glow > 0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = glow
    mat.diffuse_color = (*color, 1.0)
    return mat


def glow(name, color, strength=4.0):
    mat, nodes, links, bsdf = _principled(name)
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
    bsdf.inputs["Emission Strength"].default_value = strength
    mat.diffuse_color = (*color, 1.0)
    return mat


def gloss(name, color, roughness=0.06, metallic=0.0):
    """A wet dark eye or a polished part."""
    mat, nodes, links, bsdf = _principled(name)
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Coat Weight"].default_value = 1.0
    mat.diffuse_color = (*color, 1.0)
    return mat


def nebula(name, deep, mid, bright, star_strength=6.0):
    """Made of space: a swirl of nebula colours with stars glinting in it."""
    mat, nodes, links, bsdf = _principled(name)
    _, colour = _noise_ramp(nodes, links, 2.5, 10, [deep, mid, bright], [0.35, 0.55, 0.8])
    links.new(colour, bsdf.inputs["Base Color"])
    links.new(colour, bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 0.6
    bsdf.inputs["Roughness"].default_value = 0.25
    bsdf.inputs["Coat Weight"].default_value = 0.6
    # Stars: the brightest specks of a fine noise, added as their own glow.
    stars = nodes.new("ShaderNodeTexNoise")
    stars.inputs["Scale"].default_value = 70.0
    stars.inputs["Detail"].default_value = 2
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.72
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.76
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    links.new(stars.outputs["Fac"], ramp.inputs["Fac"])
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Strength"].default_value = star_strength
    links.new(ramp.outputs["Color"], emission.inputs["Color"])
    add = nodes.new("ShaderNodeAddShader")
    output = nodes.get("Material Output")
    links.new(bsdf.outputs["BSDF"], add.inputs[0])
    links.new(emission.outputs["Emission"], add.inputs[1])
    links.new(add.outputs["Shader"], output.inputs["Surface"])
    mat.diffuse_color = (*mid, 1.0)
    return mat


def armor(name, color):
    """Biomechanical plating: painted metal, worn edges, fine panel relief."""
    mat, nodes, links, bsdf = _principled(name)
    _, colour = _noise_ramp(nodes, links, 9.0, 4, [tuple(c * 0.6 for c in color), color], [0.45, 0.6])
    links.new(colour, bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 0.85
    bsdf.inputs["Roughness"].default_value = 0.3
    _bump(nodes, links, bsdf, 30.0, 0.12)
    mat.diffuse_color = (*color, 1.0)
    return mat


def shape(obj, subdivisions=2, displace=0.0, scale=1.5, flat=False):
    """Smooths a primitive and roughens it into an organic form with noise."""
    if subdivisions:
        mod = obj.modifiers.new("Subdivision", "SUBSURF")
        mod.levels = mod.render_levels = subdivisions
    if displace:
        texture = bpy.data.textures.new(obj.name + "Noise", "CLOUDS")
        texture.noise_scale = scale
        mod = obj.modifiers.new("Displace", "DISPLACE")
        mod.texture = texture
        mod.strength = displace
        mod.mid_level = 0.5
    for poly in obj.data.polygons:
        poly.use_smooth = not flat
    return obj


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj
