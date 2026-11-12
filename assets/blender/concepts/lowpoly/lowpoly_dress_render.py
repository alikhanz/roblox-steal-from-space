# Concept (low-poly pets): renders the rolled-outfit sheets in the faceted style.
#   kinds - one tier (epic) on six kinds: today (the same fairy wings on all) and rolled;
#   rolls - eight rolls of one kind and tier, seeds 1..8 as they fall;
#   tiers - three rolls of one kind in each tier.
# Writes <outdir>/cells/dress-*.png and <outdir>/dress.json (the picks and counts of each cell).
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/concepts/lowpoly/lowpoly_dress_render.py -- <outdir>

import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import lowpoly_render as render  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "out/lowpoly"
render.OUT = OUT
render.FAR = 72
STYLE = "faceted"
KINDS = ["slimeWarden", "acidSlime", "crabDrone", "violetCrab", "blimpWhale", "spaceWhale"]
ROLL_KIND, ROLL_TIER = "crabDrone", 3
TIER_KIND = "spaceWhale"


def seeds_showing_every_wing():
    """A seed per kind so the six kinds show all four wing types (picked to show the library; the
    rolls sheet shows seeds as they fall)."""
    import lowpoly_dress as dress

    chosen, used = [], []
    seed = 1
    for _ in KINDS:
        while True:
            picks = dress.roll(seed, 3)
            fresh = picks["back"] not in used or len(set(used)) == len(dress.WINGS)
            if fresh and (not chosen or picks["aura"] != dress.roll(chosen[-1], 3)["aura"] or picks["head"] != dress.roll(chosen[-1], 3)["head"]):
                break
            seed += 1
        chosen.append(seed)
        used.append(picks["back"])
        seed += 1
    return chosen


def main():
    import lowpoly_dress as dress
    import lowpoly_kit as kit
    import lowpoly_pets as pets

    cells = []
    for kind_id in KINDS:
        render.today(kind_id, "3")
        shutil.copyfile(os.path.join(OUT, "cells", f"{kind_id}-3-today-near.png"), os.path.join(OUT, "cells", f"dress-today-{kind_id}-near.png"))
        shutil.copyfile(os.path.join(OUT, "cells", f"{kind_id}-3-today-far.png"), os.path.join(OUT, "cells", f"dress-today-{kind_id}-far.png"))
        cells.append({"sheet": "kinds", "row": "today", "kind": kind_id, "tier": 3, "name": f"dress-today-{kind_id}"})

    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit._MATERIALS.clear()
    render.stage(0)
    library = kit.Library(STYLE)
    plan = []
    for kind_id, seed in zip(KINDS, seeds_showing_every_wing()):
        plan.append(("kinds", "rolled", kind_id, 3, seed))
    for seed in range(1, 9):
        plan.append(("rolls", "rolled", ROLL_KIND, ROLL_TIER, seed))
    for tier in range(5):
        for seed in (1, 2, 3):
            plan.append(("tiers", f"tier{tier}", TIER_KIND, tier, seed))
    built = []
    for sheet, row, kind_id, tier, seed in plan:
        collection = bpy.data.collections.new(f"{sheet}-{kind_id}-{tier}-{seed}")
        bpy.context.scene.collection.children.link(collection)
        picks = dress.roll(seed, tier)
        pet = pets.build(pets.kind(kind_id), tier, STYLE, library, False, collection, dress.dresser(picks))
        stats = pet.stats()
        name = f"dress-{sheet}-{kind_id}-{tier}-{seed}"
        built.append((collection, tier, name))
        cells.append({"sheet": sheet, "row": row, "kind": kind_id, "tier": tier, "seed": seed, "name": name,
                      "picks": {slot: dress.LABELS[piece] for slot, piece in picks.items()},
                      "triangles": stats["triangles"], "parts": stats["parts"], "meshes": len(stats["meshes"])})
        collection.hide_render = True
    for collection, tier, name in built:
        collection.hide_render = False
        render.frame(tier)
        render.shoot(name)
        collection.hide_render = True
    library_meshes = {}
    for key, mesh in library.meshes.items():
        mesh.calc_loop_triangles()
        library_meshes[key] = len(mesh.loop_triangles)
    with open(os.path.join(OUT, "dress.json"), "w", encoding="utf-8") as file:
        json.dump({"cells": cells, "library": library_meshes, "pools": {str(t): p for t, p in dress.POOLS.items()}}, file, ensure_ascii=False, indent=1)
    print("DRESS LIBRARY", len(library_meshes), library_meshes)


if __name__ == "__main__":
    main()
