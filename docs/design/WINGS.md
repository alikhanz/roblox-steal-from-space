# Pet wings: the rules

**Required reading before you make or change a pet's wings**: their shape, how they attach, how they beat, how they glow, how they get into the game. Each rule says how to check it. Every one came from a mistake the user saw. Add each new wing lesson here. The general 3D rules are in [BLENDER_ROBLOX.md](BLENDER_ROBLOX.md), and the low-poly style is in [LOWPOLY.md](LOWPOLY.md) (decisions 118, 119).

## 1. Where things live

| What | Where |
|---|---|
| Wing shapes (5 kinds), dust points | `assets/blender/lowpoly/lowpoly_wings.py` (`WINGS`, `dust`) |
| Rest pose, kit pieces, pools | `assets/blender/lowpoly/lowpoly_dress.py` (`_turn`, `kit`, `POOLS`, `anchors`) |
| Fitting hinges, size and the star to a body | `assets/blender/lowpoly/lowpoly_fit.py` (`fit`, `wing_faults`, `star_faults`) |
| Export (fits every kind) | `assets/blender/lowpoly/export_lowpoly_roblox.py` |
| Unpack (kit pivots, dust points) | `lune/aliens.luau` (`unpackLowpoly`) |
| Putting a pair on a pet, sizes | `src/server/World/OutfitDress.luau` (`WINGS`, `EPIC_WINGS`, the `hingeL`/`hingeR` attachments) |
| Colour, see-through, beat strokes | `src/shared/World/AlienDress.luau` (`colorWings`, `wings`), `src/shared/Config/AlienLooks.luau` (`WING_LIGHT`, `WING_STROKE`, `LEGENDARY_LIGHT`) |
| The beat | `src/client/World/RigMotion.luau` (mover `WING`) |
| Checks | `assets/blender/concepts/lowpoly/lowpoly_wing_check.py`, `lowpoly_fit_preview.py`, `lowpoly_wing_glow.py`; `tests/Config/AlienModels.spec.luau` |

## 2. A wing's geometry

- **Drawing frame.** A wing lies in its own XZ plane, root at the origin, reaching out along +X and up along +Z about one unit, thin along Y. The kit turns it into its rest pose, and the game scales it to the body's span.
- **Two parts a side, no more**: the membrane (paint key `wing`, source `EnergyWing`) and the glowing lines (paint key `wingEdge`, source `TierGlow`). `AlienDress.membraneOf` finds the membrane by a source ending in `Wing`, so keep that suffix. Four parts make a pair.
- **One mesh for both sides.** The left wing is the right one turned 180° about Z (`_turn`). A MeshPart can't be mirrored, and `Pet.put` asserts it.
- **Rest pose** (`lowpoly_dress._turn`): tilted −10° about X, swept `WING_SWEEP` = 38° back about Z.
  - Incident (pre-low-poly): the sweep's sign was flipped, the wings swept forward, and the game's beat looked like flapping forward. Front renders hid it. Check the sign in Studio: the wing's centre must be farther from the face than its hinge.
  - At 22° a wing turned edge-on and read as a line from the side. Far back (35°–70°) it read as pinned back.
  - The range is the user's taste: shift it in the beat, not the mesh.
- **Dust points run along the wing's own outline**, from the tip down (`dust(kind)`); the game strings the beat stroke through them.
  - Butterfly: the forewing outline only (`BUTTERFLY_FORE[3:9]`). A trace jumping to the hindwing cut across the gap.
  - Fairy: the trace snapped to the drawn outline (`fairy_dust`).
  - Check: the stroke hugs the edge in Studio (user, 2026-11-13).
- **Nothing leans over the body.** Every element must lean out from the root. A crystal at 100° (past the vertical) leant over the back and crossed the other wing; the fan is now 14°–80° (`CRYSTAL_SHARDS`).

## 3. The five kinds

| Kind | What it is | Its own rule |
|---|---|---|
| butterfly | swallowtail fore + hind wing, border, veins, eye spots | dust only on the forewing outline |
| angel | feathers on a wing bone, glowing shafts | the most triangles; keep the feather count |
| dragon | bone arm, four finger spars, scalloped membrane, claws | — |
| crystal | a fan of hexagonal crystals with glowing cores | every crystal leans out (≤ 80°) |
| fairy | the user's reference outline (`robo.WING_OUTLINE`) with a glowing edge band | **the first low-poly version** (commit 3aff207): the outline's key points with a faceted membrane fanning from the root (`lowpoly_kit._prism`) and `_frame` for the edge. Not the pre-low-poly veins and cells. Its beat is the same as every wing's. |

- **A wing kind's id is saved with every alien that wears it** (`outfit.back`, decision 121). Never rename or reuse an id. A new kind is a new id. A kind taken out of the game is drawn anew at load (`AlienOutfit.repair`). The order in the pools is free: it only changes what new aliens draw.
- **Rejected, don't bring back:** opaque wings (user: they covered everything); the solar sail.

## 4. Attaching

- **The hinge sits on the body's real back surface**, not on the hull ellipsoid. `lowpoly_fit.fit` casts from the hull's centre through the hull point (`dress.anchors`) to the outermost surface and sinks the hinge `INSET` = 0.03 under it.
  - Tall, plated or narrow bodies (crabs with a plough, crystal slimes, worms) stand out of their hull, and a hinge on the hull sank the wing half into the body.
- **If a pair still faults, fit in this order** (`fit`):
  1. Lower the hinges down the back, 0–0.4 body radius (`LOWER_STEPS`), each back on the surface.
  2. Push them out from the surface, up to 0.2 radius (`PUSH_LIMIT`).
  3. Shrink the pair, not below 0.6 (`SHRINK_LIMIT`).
  - The first height where the pair fits at full size wins.
  - A wing pushed far off the body hangs in the air, so lowering and shrinking come before a long push.
- **The star behind a legendary moves back until no wing touches it** (`star_faults`), up to 1.2 radius.
- **Each family attaches differently**, so the fit runs per kind. At the last export:
  - slimes push 0.1;
  - crabs push 0.1–0.25;
  - 8 worms shrink to 0.66–0.72, because a full pair hit the crown.
  - The export prints a `FIT <kind>:` line for each kind.
- **The hinge is a point, not a part.** `OutfitDress` adds `hingeL`/`hingeR` attachments on the body at the wing point, and `RigMotion` turns the wing about it.
- **A piece's pivot is where it goes.** A kit Model written by Lune must have `NeedsPivotMigration = false` (`lune/aliens.luau`). Otherwise Studio moves the pivot to a part's centre on insertion, and the wings beat from their middle, crossed over the body. `tests/Config/AlienModels.spec.luau` checks the flag.

## 5. The beat

- **Formula** (`RigMotion`, mover `WING`):
  - `beat = sin(t * 5 + phase)`;
  - `swing = -0.17 + 0.3 * beat`;
  - each wing turns about its hinge by `CFrame.Angles(0, -out * swing, out * 0.12 * beat)`.
  - `out` is the hinge's side: +1 for X > 0. Take it from the position, never from the `wingL`/`wingR` name, because after the 180° turn Blender's left wing sits at +X.
  - The result is 11°–45° back from the rest pose, with a slight lift on the up-beat.
- **Both halves mirror.** The same `beat` and phase on both sides; only `out` flips.
- **This is the beat from before the low-poly pets**, and the user wants it kept. Change the rest pose or the range only with the user, and change both the code and this file.
- **What broke it on 2026-11-13** was the pivot (section 4), not the formula. The butterfly beat in its middle and the fairy wings crossed.

## 6. Collisions: none, in any phase

Across the five beat phases (`BEATS` = −1, −0.5, 0, 0.5, 1), at every size a pair is worn (section 7):

- the two wings don't overlap;
- no wing has more than `SUNK` = 6 % of its points inside the body;
- no wing hits a piece worn with it: horns, crest and feelers at the 0.85 and 0.6 sizes, the crown at 1.0, the halo at every size (`WORN_WITH`);
- no wing hits the legendary star.

The body checked is its visible parts, without the `Flame`/`Jet` stand-ins and without `orbit` parts.

## 7. Sizes

| Who wears it | Kit piece | Size against the slot |
|---|---|---|
| legendary (tier 4) | any of the 5 kinds | 1.0 |
| epic (tier 3) | any of the 5 kinds | 0.85 (`EPIC_WINGS`) |
| rare (tier 2) | `angelSmall`, `butterflySmall` (or a jetpack) | 0.6 |

- The slot's span is `(0.8 + 0.25 * radius) * 2` (`dress.anchors`), times the fit's shrink, stored as the `Scale` attribute of `anchorWingL`/`anchorWingR`.
- The pools are in `lowpoly_dress.POOLS` and `Domain/AlienOutfit`, and the two must match (`tests/Domain/AlienOutfit.spec.luau`).

## 8. Glow and lines

- **The membrane is barely there**: SmoothPlastic, transparency `WING_LIGHT.membrane` = 0.8, no shadow.
- **Only the lines glow**:
  - Neon at `WING_LIGHT.lineTransparency` = 0.25. The user asked to dim them "a little", 2026-11-13.
  - See-through glowing parts are never plain Neon: a Neon part at transparency 0 burns white under Bloom.
- **The beat stroke**: a `Trail` between neighbouring dust points.
  - `WING_STROKE` for most tiers: 0.3 s, transparency 0.45, brightness 1.2.
  - `LEGENDARY_LIGHT` for gold wings: transparency 0.7, brightness 0.5. At 0.45 the gold strokes burnt to a white wall (2026-11-12).
- **Line area budget.** `lowpoly_wing_glow.py` prints each kind's line area per wing.
  - Accepted values: butterfly 2.69, angel 2.18, dragon 1.37, crystal 0.54, fairy 0.74.
  - A new or changed wing stays at or under the butterfly's 2.7.
  - Thinner lines are fine. Wider ones need the user.
- **A legendary's glow is sized by its body, never by the whole pet.**
  - The radiance and the medal of rays (`AlienDress.legendaryGlow`) use the body box without wings, outfit or orbits (`bodyBox`; outfit parts carry `OutfitPart`), times `LEGENDARY_LIGHT.bodyRadius` = 0.95.
  - Why: sized by the whole pet, the same glow stood round a body half as wide, and the wings' span pushed it further. A bench of legendaries became a white blot (user, 2026-11-13).
  - Measured on a legendary crab: radiance 8.7–11.6 → 5.8–7.7, medal 10.1 → 6.7.
- **Judge brightness in Studio, live, on a bench of several legendaries**, not on one pet and not in a Blender render.

## 9. Budget

- **Faces per wing**: butterfly 244, angel 531, dragon 140, crystal 198, fairy 147 (the export's `PIECE` lines). A pair is twice that, in 4 parts. Keep a new kind under the angel's.
- **One mesh per kit piece for the whole game**: every pet wearing a kind shares its MeshIds, and the size comes from `Model:ScaleTo`.

## 10. Checking a change

1. **Blender.** Run:

   ```
   blender --background --factory-startup --python assets/blender/concepts/lowpoly/lowpoly_wing_check.py -- all
   ```

   - It prints `WING hull …` (before the fit) and `WING fit …` (after) for every kind and wing kind, then a summary.
   - **After the fit there must be no `SUMMARY fit` line.** Any line there names a family, wing kind and fault: cross, body, a piece's name, or star.
   - Runs in ~2 minutes.
2. **Picture.** `lowpoly_fit_preview.py -- <outdir> <kind> …` renders a kind with each wing kind at both ends of the beat, with the crown and the star.
3. **Glow.** `lowpoly_wing_glow.py`: line areas within section 8.
4. **Export** (section 11). The export's `FIT` lines must say `faults left 0`.
5. **Studio, in Play.**
   - The **«/gallery pets»** button (bench column): each press shows the next page of one family.
   - Take a shot of one winged pet of each family from behind and above.
   - Check that the hinges sit on the back and the halves mirror.
   - Check that the stroke follows the edge (it shows only in motion).
6. **The user watches the beat live.** Don't send stills of motion as proof.

## 11. Getting it into the game

1. Export both packs; the kit rides with the slimes:

   ```
   blender … export_lowpoly_roblox.py -- out/lowpoly/pack-slime-kit.glb slime kit
   blender … export_lowpoly_roblox.py -- out/lowpoly/pack-rest.glb crab,worm,ray,swarm,whale
   ```

2. Upload each as a Model via Open Cloud (`POST /assets/v1/assets`) and insert it into `ServerStorage`.
3. Save each to a file by mouse: Explorer → right click → Save / Export → Save to File, as `out/PackSlimeIn.rbxm` and `out/PackRestIn.rbxm`.
4. Run `lune run aliens` on each. It writes `assets/aliens/*.rbxm`, `_Outfit.rbxm`, `AlienModels.json` and `out/Aliens.rbxm`.
5. In the place, move the old `ServerStorage.Aliens` aside, then File → Import Roblox Model `out/Aliens.rbxm` into `ServerStorage`.
6. Run `lune run check`, commit, and save the Dev place.
7. **Prod** needs `Use` on every new mesh for universe 10775754016 ([ASSETS.md](../ASSETS.md)). Grant it only on the user's word «в прод».
