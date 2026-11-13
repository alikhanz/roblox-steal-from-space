# A check of the low-poly pets' wings (decision 118): every wing kind of the outfit kit on every
# kind's body, at every size it is worn, through the game's beat (lowpoly_fit.py), on the points the
# export gives the body (`fit`) and, for comparison, on the plain hull points (`dress.anchors`).
# A line per kind and wing kind with what goes wrong in any phase (cross: the two wings run into
# each other; body: a share of the wing's points inside the body; a piece's name: the wing runs
# into it), then a summary by family and wing kind.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/concepts/lowpoly/lowpoly_wing_check.py -- [family,family… | all]

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
for folder in ("lib", "aliens", "lowpoly"):
    sys.path.insert(0, os.path.join(HERE, "..", "..", folder))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import lowpoly_dress as dress  # noqa: E402
import lowpoly_fit as fitting  # noqa: E402
import lowpoly_kit as kit  # noqa: E402
import lowpoly_pets as pets  # noqa: E402
import lowpoly_wings as wingkit  # noqa: E402
import robo  # noqa: E402
import robo_kinds  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
FAMILIES = ARGS[0].split(",") if ARGS else ["all"]
STYLE = "faceted"


def describe(faults):
    by_kind = {}
    for kind, size, fault in faults:
        by_kind.setdefault(kind, set()).add(fault if not fault.startswith("body") else "body")
    return by_kind


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    library = kit.Library(STYLE)
    holder = kit.Pet(library, bpy.context.scene.collection)
    ctx = pets.Context(holder, robo.theme("debris")["colours"], 2, False, STYLE)
    geometry = fitting.kit_geometry(ctx)
    kinds = [k for k in robo_kinds.KINDS if "all" in FAMILIES or k[2] in FAMILIES]
    before, after = {}, {}
    for kind in kinds:
        kind_id, family = kind[0], kind[2]
        collection = bpy.data.collections.new(kind_id)
        bpy.context.scene.collection.children.link(collection)
        pet = pets.build(kind, 2, STYLE, library, False, collection, body_only=True)
        bpy.context.view_layer.update()
        body = fitting.Body(pet.objects)
        notes = []
        for label, points, store in (("hull", dress.anchors(pet.info), before),
                                     ("fit", fitting.fit(pet.info, pet.objects, geometry, notes.append), after)):
            faults, worst = fitting.wing_faults(points, body, geometry)
            star = fitting.star_faults(points, geometry)
            found = describe(faults)
            for wing in star:
                found.setdefault(wing, set()).add("star")
            for wing in wingkit.WINGS:
                problems = sorted(found.get(wing, ()))
                print(f"WING {label:4} {family:6} {kind_id:16} {wing:9} {', '.join(problems) or 'ok'}")
                if problems:
                    store.setdefault((family, wing), set()).update(problems)
                    store.setdefault((family, wing, "kinds"), set()).add(kind_id)
            print(f"FIT {family:6} {kind_id:16} worst sunk {worst:.2f}; {notes[-1] if notes else ''}")
        for obj in list(collection.objects):
            bpy.data.objects.remove(obj)
    for label, store in (("hull", before), ("fit", after)):
        for key in sorted(k for k in store if len(k) == 2):
            print(f"SUMMARY {label:4} {key[0]:6} {key[1]:9} {len(store[key + ('kinds',)]):2d} kinds: {', '.join(sorted(store[key]))}")
    print("SUMMARY done")


if __name__ == "__main__":
    main()
