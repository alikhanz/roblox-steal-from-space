# Exports the adult guardians in the faceted low-poly style (decision 119): the guardians' own
# builders (assets/blender/guardians/adults.py) and export (export_guardians_roblox.py), with
# robo.py's primitives swapped for faceted ones (lowpoly_facets.py). Same layout, colours, roles
# and hinges, so the game (lune run guardians, World/GuardianVisual) takes them unchanged.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/lowpoly/export_guardians_lowpoly.py -- <outdir> [post ...]

import os
import sys

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

lowpoly_facets.apply(robo, robo_kinds, adults)

if __name__ == "__main__":
    guardians.main()
