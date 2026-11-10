# Checks the adult guardians for misplaced parts, without Studio, with the pets' check
# (check_robo_parts.py): parts floating in the air, parts hidden whole inside another, signature
# parts cutting each other or the face. Each guardian is built as the export does.
#
# Run headless from the repo root:
#   blender --background --factory-startup --python assets/blender/guardians/check_guardian_parts.py -- <out.tsv> [post ...]
# Writes one line per finding: post, problem, part, other part. Diff it against the last report:
# anything new means breakage.

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "aliens"))
sys.path.insert(0, HERE)

import adults  # noqa: E402
import bpy  # noqa: E402
import check_robo_parts as check  # noqa: E402
import export_guardians_roblox as export  # noqa: E402  (the export's detail)
import robo_kinds  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "check_guardian_parts.tsv"
ONLY = set(ARGS[1:])

# A guardian's hunters fly round it apart from its body.
check.LOOSE_ROLES = check.LOOSE_ROLES | {"hunters"}
# Its glowing throat sits in the open mouth, behind the teeth.
check.LOOSE_MATERIALS = check.LOOSE_MATERIALS + ("Maw",)
check.FACE_MATERIALS = check.FACE_MATERIALS + ("GuardianEye",)
check.CLEAR_MATERIALS = check.CLEAR_MATERIALS + ("Shard",)

for family, (make, pet_scale, growth) in list(adults.FAMILIES.items()):
    adults.FAMILIES[family] = (check._labelled(make, "body"), pet_scale, growth)
for name, part in list(adults.ADULT_SIGNATURES.items()):
    adults.ADULT_SIGNATURES[name] = check._labelled(part, "sig:" + name)
for name, part in list(adults.PET_SIZE_OVERRIDES.items()):
    adults.PET_SIZE_OVERRIDES[name] = check._labelled(part, "sig:" + name)


def main():
    rows = []
    for kind in robo_kinds.KINDS:
        post = export.post_id(kind)
        if kind[8] != 0 or (ONLY and post not in ONLY):
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        signature = [check._labelled(part, "sig:" + part.__name__) for part in kind[6]]
        # Labelled copies keep the names the adult build looks its own versions up by.
        for labelled, part in zip(signature, kind[6]):
            labelled.__name__ = part.__name__
        adults.build((*kind[:6], signature, *kind[7:]), 0.0, 0.0, growth=1.0)
        for problem, part, other in sorted(set(check.findings())):
            rows.append(f"{post}\t{problem}\t{part}\t{other}")
        print("Checked", post, flush=True)
    with open(OUT, "w", encoding="utf-8") as file:
        file.write("\n".join(rows) + "\n")
    print("Findings", len(rows), "->", OUT)


main()
