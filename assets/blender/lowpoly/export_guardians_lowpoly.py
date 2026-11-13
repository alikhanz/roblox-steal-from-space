# Exports the adult guardians in the faceted low-poly style (decision 119): the guardians' own
# builders (assets/blender/guardians/adults.py) and export (export_guardians_roblox.py), with
# robo.py's primitives swapped for faceted ones (lowpoly_facets.py). Same layout, colours, roles
# and hinges, so the game (lune run guardians, World/GuardianVisual) takes them unchanged.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/lowpoly/export_guardians_lowpoly.py -- <outdir> [post ...] [--merge=class|paint|split]

import os
import sys

# How a role's baked parts join (--merge=split|paint|class; export_robo_roblox.MERGE): "class" by
# default (step B of the 2026-11-13 merge: a role's plastic in one part, Neon, glass, eyes and the
# dome apart); "paint" for step A (no shine lost), "split" for the guardians as they shipped.
MERGE = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--merge=")), "class")
sys.argv = [a for a in sys.argv if not a.startswith("--merge=")]

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "aliens"))
sys.path.insert(0, os.path.join(HERE, "..", "guardians"))
sys.path.insert(0, HERE)

import adults  # noqa: E402
import export_guardians_roblox as guardians  # noqa: E402
import lowpoly_facets  # noqa: E402
import robo  # noqa: E402
import robo_kinds  # noqa: E402

import export_robo_roblox  # noqa: E402

lowpoly_facets.apply(robo, robo_kinds, adults)
export_robo_roblox.MERGE = MERGE

if __name__ == "__main__":
    guardians.main()
