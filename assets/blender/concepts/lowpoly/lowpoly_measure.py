# Concept (low-poly pets): measures today's robot pets as the game gets them. Builds each pet the
# way export_robo_roblox.py does (robo.DETAIL 0.8, effect stand-ins dropped, parts joined by role and
# look) and reports, per pet: triangles, MeshParts (each one a mesh of its own today), and where the
# triangles go (body, visor and eyes, wings, crown, pack...). Writes a JSON for the comparison sheet.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/concepts/lowpoly/lowpoly_measure.py -- <out.json> [kind:variant ... | --all]
# All 720 take about 40 minutes.

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ALIENS = os.path.join(HERE, "..", "..", "aliens")
sys.path.insert(0, os.path.join(HERE, "..", "..", "lib"))
sys.path.insert(0, ALIENS)
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import export_robo_roblox as export  # noqa: E402  (sets robo.DETAIL = 0.8 as the game's export does)
import robo  # noqa: E402
import robo_kinds  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "out/lowpoly/current.json"
SPECS = ARGS[1:] or ["slimeWarden:0", "slimeWarden:3", "slimeWarden:4", "crabDrone:0", "crabDrone:3", "crabDrone:4",
                     "spaceWhale:0", "spaceWhale:3", "spaceWhale:4"]

# Every builder the pet is made of, so each object knows which piece of the outfit made it. The
# innermost wrapper wins (a crown's spikes are "crown", not "build").
PIECES = {
    "visor": "visor and eyes", "details": "hull details", "beacon": "beacon (tier 1-3)", "pack": "jetpack and armour (tier 2+)",
    "wings": "wings (tier 3+)", "crown": "crown (tier 4)", "sunburst": "sunburst stand-in (tier 4)", "tier_ring": "tier ring",
    "meteor_fire": "meteor fire", "orbit": "orbit (fx)", "motes": "motes (fx)",
}
for zone, function in list(robo.FLAIR.items()):
    PIECES["flair_" + zone] = "zone flair"


def wrap(module, name, label):
    original = getattr(module, name)

    def run(*args, **kwargs):
        before = set(bpy.data.objects)
        result = original(*args, **kwargs)
        for obj in set(bpy.data.objects) - before:
            if "piece" not in obj:
                obj["piece"] = label
        return result

    run.__name__ = original.__name__
    setattr(module, name, run)
    return run


for name, label in PIECES.items():
    wrap(robo, name, label)
robo.FLAIR = {zone: getattr(robo, "flair_" + zone) for zone in robo.FLAIR}
# The signature parts are named in the kind's list, so wrap them there.
for index, kind in enumerate(robo_kinds.KINDS):
    signature = [wrap(robo_kinds, part.__name__, "signature: " + part.__name__) if not hasattr(part, "_wrapped") else part for part in kind[6]]
    for part in signature:
        part._wrapped = True
    robo_kinds.KINDS[index] = (*kind[:6], signature, *kind[7:])


def triangles(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def measure(kind, variant):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    meteor = variant.startswith("m")
    tier = int(variant.lstrip("m"))
    robo_kinds.build(kind, tier, 0.0, 0.0, meteor)
    # The family's own shell is whatever no outfit piece claimed.
    for obj in bpy.data.objects:
        if "piece" not in obj:
            obj["piece"] = "body: " + obj.data.materials[0].name.split(".")[0] if getattr(obj.data, "materials", None) and obj.data.materials[0] else "body"
    pieces = {obj.name: obj["piece"] for obj in bpy.data.objects}
    # Effect stand-ins never reach the game (export drops role "fx").
    for obj in list(bpy.data.objects):
        if obj.get("role") == "fx":
            bpy.data.objects.remove(obj)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.convert(target="MESH")
    by_piece = {}
    for obj in bpy.context.view_layer.objects:
        if obj.type != "MESH":
            continue
        piece = pieces.get(obj.name, obj.get("piece", "body"))
        # Group the body by what it is: dome and jelly, shell, the rest.
        if piece.startswith("body: "):
            source = piece[6:]
            piece = {"Dome": "body: glass dome", "Core": "body: core / jelly", "EyeLight": "visor and eyes", "Visor": "visor and eyes",
                     "Porthole": "visor and eyes", "Rim": "visor and eyes"}.get(source, "body: shell and trim")
        if obj.name.startswith(("hinge",)) or obj.get("role", "").startswith(("hinge", "dust")):
            piece = "markers (hinges, dust)"
        by_piece[piece] = by_piece.get(piece, 0) + triangles(obj)
    parts = export.join_by_role()
    meshes = [obj for obj in bpy.context.view_layer.objects if obj.type == "MESH" and obj.name in parts]
    total = sum(triangles(obj) for obj in meshes)
    markers = sum(1 for obj in meshes if obj.name.startswith(("hinge", "dust")))
    biggest = sorted(((triangles(obj), obj.name) for obj in meshes), reverse=True)[:6]
    return {"kind": kind[0], "family": kind[2], "zone": kind[3], "variant": variant, "tier": tier, "meteor": meteor,
            "triangles": total, "meshParts": len(meshes), "markerParts": markers,
            "byPiece": dict(sorted(by_piece.items(), key=lambda item: -item[1])), "biggestParts": biggest}


def main():
    kinds = {kind[0]: kind for kind in robo_kinds.KINDS}
    results = []
    specs = SPECS
    if specs == ["--all"]:
        specs = [f"{kind[0]}:{variant}" for kind in robo_kinds.KINDS for variant in export.PACK_VARIANTS]
    for spec in specs:
        kind_id, variant = spec.split(":")
        result = measure(kinds[kind_id], variant)
        results.append(result)
        print(f"MEASURE {spec}: {result['triangles']} tris, {result['meshParts']} MeshParts ({result['markerParts']} markers)")
        for piece, count in result["byPiece"].items():
            print(f"    {count:7d}  {piece}")
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as file:
        json.dump(results, file, ensure_ascii=False, indent=1)
    print("Wrote", OUT)


if __name__ == "__main__":
    main()
