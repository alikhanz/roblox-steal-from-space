# Static code sweep for the performance report (2026-11-11)

Read-only sweep of worktree `compassionate-tereshkova-d9f4d1`. Paths are relative to `src/` unless they say otherwise.
Legend: **[code]** = counted from the code; **[est]** = estimate (assumption stated); **[measure]** = cannot be told from the code, measure in Studio.
Where code and docs disagree, the code is taken.

---

## 1. Pet effects (`shared/World/AlienDress.luau`)

### What `adornLocally` creates on each client (per adorned pet; "plain" floor/shelf pets get nothing, `AlienMotionController.luau:326`)

`adornLocally` (`AlienDress.luau:1219`) clones the whole pet (`model:Clone()`, :1220), builds a twin map by walking both trees (:1222-1232), `ScaleTo` x2 (:1234, :1236), runs `adorn` on the clone, then reparents every new instance onto the real model (:1239-1257), walks the model again for lights (:1258) and again in `feetOf` (:1265, 8 corner transforms per MeshPart), then destroys the clone. `adorn` itself walks the descendants 4 more times (`paintsOf` :1036, `partsOf` :1015, `feetOf` via `rune` :982, `clusters` :1105). **[code]** So adorning one pet = 1 full clone + ~7 full descendant walks + 2 ScaleTo. 30 pets on own island + 7 other islands' pets all go through this at join (AlienMotionController watches every `ALIEN_TAG`, `AlienMotionController.luau:404`) — up to 240 pets at join with 8 full islands **[code: no distance gate before adorning]**.

Always created (every adorned pet) **[code]**:

| Instance | Count | Where | Notes |
|---|---|---|---|
| Part `Fx` (carrier, Transparency 1) | 1 | :1146 | moved every frame as a STATIC mover (it has children, so `RigMotion.moverOf` keeps it, `RigMotion.luau:229`) |
| Part `DustShell` (Transparency 1) | 1 | :1111 | created because Twinkle and Motes always exist |
| Part `Halo` (Transparency 1) | 1 | :984 | carries the rune |
| Attachments `Top`, `Back`, `LightLow` | 3 | :1154,:1156,:1182 | |
| PointLight `CoreLight` | 1 | :1176 | `Shadows = false` (:1181); Range `(8+1.5r)*0.75` at dress scale, rescaled and clamped to 5..16 studs (:1260, `AlienLooks.luau:44-45`); Brightness 0.9+0.15·tier, animated every frame by `AlienMotionController.luau:215-216`; on only at detail 1 (`AlienMotionController.luau:238`) |
| SurfaceGui `Rune` (FixedSize canvas **1024x1024**, Brightness 2) + ImageLabel | 1+1 | :993-1009 | **not** in any detail list: never disabled at distance (`AlienMotionController.luau:153-159` only collects ParticleEmitter/Trail/Beam/BillboardGui) |
| SurfaceGui `Glow` (canvas 256x256) + ImageLabel | 1+1 | :993 | same, never disabled |

By tier / kind **[code]**:

| Thing | Condition | Count | Where |
|---|---|---|---|
| Comet = Part `Wisp` (Ball, Neon, CastShadow false) + 2 Attachments + Trail (`StarTail`, Lifetime 0.55 s) | tier ≥ 3 and not meteor | tier−1 → **2 at t3, 3 at t4** | :1194-1198, :223-262 |
| Fire comet (same, Trail `FireTail`, 0.45 s) | meteor | 2+floor(tier/2) → **2,2,3,3,4** for t0..t4 | :788-791 |
| BillboardGui `Crest` (MaxDistance 300, Size = radius·(1.6+0.25·tier) studs, scale) + 2 ImageLabels with `Sway` | meteor | 1 | :793-796, :166-187 |
| BillboardGui `Medal` (MaxDistance 300) + 2 ImageLabels with `Spin` (4°/s and −7°/s) | tier 4 | 1 | :846-849 |
| Jet flames: 1 nozzle Attachment + 2 end Attachments + 2 Beams (`JetFlame`, `JetCore`, textured, scrolling) | per Blender `Jet` part (kinds with jetpacks, tier 2+ per comment :393) | 2 Beams / nozzle | :405-445 |
| Wing strokes: one Trail between each pair of neighbouring `Dust` points | winged kinds | ~7 per wing → **~14 Trails** (comment says ~8 points a wing, `AlienLooks.luau:144`) | :917-954 |
| `FlameBase` Attachment | `flames` signature | 1 | :594 |
| Attachments `Crest`, `Radiance` | meteor / tier 4 | 1 each | :792, :807 |

The ImageLabels with `Spin`/`Sway` are rotated **every frame** for every pet at detail ≤ 2 (`AlienMotionController.luau:218-221`) → their BillboardGui re-renders every frame.

### Particle emitters, rates and live particles **[code rates; live = Rate × max Lifetime]**

k = 1 + 0.6·tier (1, 1.6, 2.2, 2.8, 3.4). The "cluster" layers (`AlienLooks.FX.CLUSTERS`: Motes, Stardust, Embers, Frost, Twinkle) are moved to the `DustShell`, their Rate ×1/4 and their Size ×4 with a 4x4 flipbook (`AlienDress.luau:1102-1141`, `AlienLooks.luau:86-101`). **Note:** a quarter of the particles at 4× the size is 4× the screen area of the old layers (16× area per particle) — fewer particles, but more overdraw per layer **[est, follows from the numbers]**.

| Emitter | Parent | Rate (after clustering) | Max lifetime | Live (t0 → t4) | MAIN_EFFECTS? |
|---|---|---|---|---|---|
| SoftGlow (big soft sprite, size 0.6r→1.1r) | Fx | 3+tier | 2.4 | 7.2 → 16.8 | **yes** |
| Twinkle (cluster) | DustShell | 2k | 1.4 | 2.8 → 9.5 | no |
| Motes (cluster) | DustShell | 2.5k | 2.5 | 6.3 → 21.3 | no |
| debris: Sparks | Top | 10k | 0.7 | 7 → 23.8 | no |
| ice: Frost (cluster) + Splash | DustShell / Top | 3.5k + 8k | 2.2 / 0.9 | 14.9 → 50.7 | no |
| nebula: Embers (cluster) | DustShell | 5k | 2.0 | 10 → 34 | no |
| horizon: Stardust (cluster) + BigStars | DustShell / Fx | 6k + 2k | 3.0 / 1.2 | 20.4 → 69.4 | no |
| meteor: HeatEmbers | Fx | 35 | 1.4 | +49 | no |
| tier 4: Radiance, RadianceHeart (LockedToPart, radius·2.4–3.2 sprites) | Radiance att | 1, 1 | 3.5, 2.4 | +5.9 | **yes** |
| tier 4: RadianceMotes, GoldGlitter | Radiance / Top | 14, 40 | 3.0, 1.8 | +114 | no |
| sig flames: Flames, FlameCore | FlameBase | 25, 15 | 0.75, 0.45 | +25.5 | **yes** |
| sig lightning: Bolts / BigBolts / ElectricSparks | Fx | 30 / 6 / 40 | 0.12 / 0.1 / 0.3 | +3.6 / +0.6 / +12 | Bolts **yes** |
| sig spout: Spout + Bubbles | Top | 40 + 10 | 0.9 / 2.0 | +56 | no |
| sig bubbles | Top | 14 | 2.5 | +35 | no |
| sig exhausts: Smoke (LightInfluence 1) | Top | 8 | 1.6 | +12.8 | no |
| sig smoke: Wisps | Back | 6 | 2.4 | +14.4 | no |
| sig flakes | Top | 8 | 3.0 | +24 | no |
| sig galaxy | Fx | 30 | 1.6 | +48 | no |

Totals per pet without signature (zone layers + base), live particles, t0 → t4:
- Debris Belt 23 / 35 / 47 / 59 / 71; Ice Rings 31 / 48 / 65 / 82 / 98; Red Nebula 26 / 40 / 54 / 68 / 82; Event Horizon 37 / 57 / 77 / 97 / 117.
- Legendary adds ~120 (so a t4 pet is **~190–240** live particles before its signature; with `galaxy` or `spout` ~240–290). Meteor adds 49 and 2–4 fire trails.
- Emitters per pet: 3 base + 1–2 zone + 0–3 signature + 1 meteor + 4 legendary → **4–13**.
- **[est]** 30 pets on the own island, mixed tiers around tier 2 → ~50–80 live each → ~1 500–2 400 particles and ~150–250 emitters within the near radius; a late-game island of t3/t4 → 3 000–7 000. Pets on other islands are ≥ ~300 studs away (`StationSize` island ring radius 398.5, neighbour gap ≈ 305) so they fall to detail 3 (everything but the rune SurfaceGuis off).
- Detail rules (`AlienLooks.MOTION`): ≤ 70 studs + radius all; ≤ 160 + radius only MAIN_EFFECTS (+ BillboardGuis); beyond: none. Beams and trails are toggled with the same lists (`AlienMotionController.luau:155-156`).

### Server-side dressing (`AlienDress.prepare`, `server/World/AlienModel.luau`) — what replicates **[code]**

- Templates prepared once per kind/variant (`AlienModel.luau:85-109`) and cloned (`:192`): meshes are shared (same MeshId), no per-part `Instance.new` for geometry.
- Per pet the server sends the whole Blender model (avg **~29 MeshParts** per model from the known 20 743 / 720), each with 2 string attributes (`Paint` from the file, `Role` written by `paint`, `AlienDress.luau:300`), plus: Part `Body` (whole bounding box, transparent, `:1079-1087`), `Dust` Attachments on wing membranes (~8 per wing, `:900-913`, winged kinds), a cloned `SurfaceAppearance` (lava) on every `L` part of meteor pets (`:338-340`), 7 model attributes (`AlienModel.luau:201-209`), the `ALIEN_TAG`, and, for floor pets, a ProximityPrompt (`BayService.luau:353-364`). Hidden parts (flame/jet cones, hinge markers, rays/ring, `Transparency = 1`) are still sent. The doc's "73 objects per pet" (`docs/ARCHITECTURE.md:177`) is plausible for an average model + Body + Dust points; not recomputable from code alone **[measure]**.
- `ModelStreamingMode = Atomic` on the template (`AlienModel.luau:104`), inherited by clones.
- `ScaleTo` on every build (`AlienModel.luau:194`).

### Which pet parts cast shadows **[code]**

- `AlienDress.luau:377`: `part.CastShadow = part.Material ~= Enum.Material.Neon` — every visible SmoothPlastic, metal (SmoothPlastic + variant), lava, **Glass** and crystal part casts a shadow. Exceptions set to false: wing membranes (`:898`), Body/Fx/DustShell/Halo/Wisp parts. Parts hidden with `Transparency = 1` keep CastShadow true but do not render.
- `AlienModel.ghost` (`AlienModel.luau:42-48`, CastShadow false) is applied only to the greybox blob, not to real models.
- `Lighting.GlobalShadows = true` (`shared/Config/SkyLooks.luau:34`, applied in `WorldService.luau:689`). So **[est]** ~20 shadow-casting MeshParts per pet × up to 240 pets on the map (each animated every frame near the camera).

---

## 2. RigMotion (`client/World/RigMotion.luau`)

Per pose call (`RigMotion.pose`, :438-595) **[code]**:
- Once per pet: `CFrame.new(rig.centre)`, `c:Inverse()` (:448-449), `eyeOpen`/`jawOpen` x2 (may allocate nothing), worm head turn (3 CFrames).
- Per mover (every part that is visible or has children — **all** of them, STATIC ones included, :470-471; only invisible childless parts are dropped, :229):
  - STATIC: 1 CFrame multiply (`origin * here`, :593).
  - Hinged kinds (ROTOR, WING, JAW, MOUTH, ARM, MAND, LEG, FIN, BUZZ, FLIPPER, FLUKES): `about()` = `CFrame.new(pivot)`, `CFrame.Angles`, two multiplies, `CFrame.new(-pivot)` (:146-148) + `* offset` + `origin *` ≈ 6–7 CFrame values; FIN with joint ≈ 12.
  - ORBIT/RAYS/FLOCK/WISP: 4–6 CFrames. DRONE: 2 Catmull-Rom evaluations (Vector3, no alloc) + 4–8 CFrames.
  - Slime squash (`squashed`, :167-172; `squashedSize` allocates a closure `along` per call, :177).
  - `part.Size` written only when it changed (:589-591): eyes (blink) and squashed slime body parts write Size every frame while squashing/blinking.
  - 2 `table.insert` (parts, frames).
- HALO: inserted with `ground * CFrame.new(...) * CFrame.Angles(...)` (:474-475).
- CFrame is a heap-allocated userdata in Luau (Vector3 is not) **[runtime fact]** → **[est]** ~1–7 CFrame allocations per part per frame; a 30-part pet ≈ 60–150 CFrames + ~12 in `move` (`bob`, `AlienMotionController.luau:208-213`) per frame.
- Per frame in the controller (`AlienMotionController.luau:365-401`): fresh `parts` and `frames` tables every frame (:377-378), grown by insertion (several reallocations for ~30 pets × ~32 parts ≈ 1 000 entries); one `BulkMoveTo(..., FireCFrameChanged)` (:399). Slimes allocate a `squash` table per frame (:205). `PetMotion.detail` allocates a closure `level` per pet per frame (`shared/Domain/PetMotion.luau:105`).
- **Parts moved per pet [est]:** ~25–35 (avg 29 MeshParts minus invisible ones, plus Fx, DustShell, Halo, Wisps). Own island 30 pets near the camera ≈ 900–1 000 CFrames written per frame.
- What is skipped: invisible childless parts (:229), the `Body` label part (`skip`, :376), pets beyond `FAR + radius` (no motion), pets in the middle band move every other frame (`AlienMotionController.luau:392`), pets within `SMOOTH` (35) every frame.
- **No on-screen test**: detail is by distance from the camera only (`AlienMotionController.luau:382-384`); pets behind the camera at 30 studs move every frame. **[code]**
- Allocation per pet per frame **[est]**: ~70–160 CFrame userdata, 1 closure (detail), slimes +1 table +N closures; per frame 2 growing arrays.

---

## 3. Island (bay)

Builder: `server/World/BayModel.luau`; contents: `server/Services/BayService.luau`. All parts get `scenery` (Anchored, CanTouch/CanQuery false, **CastShadow false**, `BayModel.luau:45-50`) unless noted. Kits are cloned MeshParts (same MeshId, `server/World/MeshKit.luau:35-43`).

### Fixed part of an island (`BayModel.build`, :926-955) **[code]**

| Piece | Instances | Notes |
|---|---|---|
| Zone lines (`buildZoneLines`, :835-886) | **181 Neon Parts** | places' horseshoe: inner arc r=18 → 24 pieces, outer arc r=94 over 300° → ceil(94·5.236/6) = **83** pieces, 2 edges; incubator ring r=15 → 24; trainer ring r=5 → 24; shelf arc → 24 (`MIN_ARC_PIECES = 24`, :34). ×8 islands = **1 448** Neon parts on every client |
| Sign (`buildSign`, :633-670) | 5 Parts (2 Neon edges) | |
| Incubator (`buildIncubator`, :892-924) | 1 disc + kit `Dais` + `DaisLight` (Neon) + invisible `Heater` = 4 | |
| Stand, kit (`buildStand` :481 + `wearTier` :563-602) | invisible platform + up to 5 kit pieces (Body, Glow Neon, Gold, Grate Neon, Pilot Neon) + **15 lamp Parts** = ~21 | greybox: 11 parts |
| Shelf (`buildShelf`, :346-379) | kit Body + Glow (Neon) + 8 invisible Blocks = 10 | greybox: 32 boxes + 8 blocks |
| 3 terminals (`buildTerminal`, :770-832) | per terminal: kit Console + kit Glow (Neon) + Screen Part (Transparency 0.6, **CanQuery true**) + 2 Attachments = 3 parts | greybox: ~14 parts each |
| Contents Folder | 1 | |

≈ **225 parts per island** before contents; ×8 ≈ 1 800 **[code-derived]**.

Island floor and dome are `WorldService.buildDomedPlatform` (see §4): Platform (DiamondPlate, CastShadow default true), Rim (Neon), Dome (ForceField ball, r = 142.5, Transparency 0.75), 4 hull discs (Metal, CastShadow default true), 1 SpawnLocation.

### Contents (`BayService.refresh`, :402-541) **[code]**

| Item | Instances | Notes |
|---|---|---|
| Place (`BayModel.buildPlace`, :123-151) | Model + 2 Parts (Neon ring, Metal pad) | `ModelStreamingMode = Atomic`; tagged `PLACE_TAG`; 3..30 per island (`BayConfig.MAX_PODS = 30`) |
| Alien on a place | pet model (§1) | Atomic |
| Capsule/bud × **12** (`IncubatorShape.POSITIONS`) (`buildCapsule`, :217-239) | kit Body (+ kit Light Neon when bought) + invisible Block = 2–3 parts | all 12 always stand |
| Egg (`server/World/EggModel.luau:94-138`) | invisible box + kit Body + Glow (Neon, non-Common) + CapGold (Legendary) + 1 **Weld per piece** | PointLight (Shadows false) when `glow > 0` (Epic 0.6, Legendary 1) at `INCUBATOR_GLOW_SCALE 0.2` → Range 1.7 / 2.8; meteor egg + `Fire`; lucky egg + `Sparkles` |
| Ready egg | + PointLight Range 8, Brightness 3 (`BayService.luau:290-295`), Shadows default false | + hatch ProximityPrompt |
| Warming egg | + "hatch now" ProximityPrompt (only in a game with a catalog) (:386-400) | |
| Waiting egg | egg as above, up to 24 shown (`BayConfig.WAITING_SHOWN_MAX`) | |
| Shelf alien | small pet model (Plain: no client effects) + pick-up ProximityPrompt while inventory has room | up to 24 niches (8 columns × 3 tiers) |

ProximityPrompts per island **[code]**: 1 per floor alien (≤ 24) + 1 per egg in a slot (≤ 12). All `Style = Custom`, `RequiresLineOfSight = false`, MaxActivationDistance 8. They replicate to every client (owner check is client-side via attribute, `BayService.luau:344`) **[code]**; non-owners' clients still run ProximityPromptService over them **[measure]**.

### What `refresh` destroys and rebuilds, and when **[code]**

- Called after every profile change that touches the bay (hatch, buy, sell, crossbreed, move, egg added) and by the 1 Hz tick **only when the count of ready eggs changed** (`BayService.luau:780-781`).
- Kept and moved: places of unchanged width (`movePlace`, PivotTo + attribute), aliens of the same kind/size (`AlienModel.place`), eggs whose state ("warming"/"ready"/"waiting") is unchanged, capsules whose bought flag is unchanged.
- Destroyed and rebuilt: a place whose width changed (alien added/removed → new width → new model), an alien whose kind or scale changed, an egg whose state changed (warming → ready rebuilds the egg part + prompt + light), a capsule just bought. Destroyed: everything no longer in the profile.
- Every refresh also writes `PodCount` on the bay model, `EggHatchAt` on every kept incubator egg (same value → no change event), 3 incubator attributes, `setCapsuleState` on each bought capsule (Color/Material writes; same values are no-ops), and fires `changed` → `NetService` sends the **whole bay** (`BayChanged`: pods, inventory, floor, incubator, waiting) + `CoinsChanged` (`NetService.luau:204-212`).

### Per-second tick for one player (`BayService.tick`, :754-786) **[code]**

- Every 1 s per player: one `update` (a coroutine created per update, `server/Data/SessionManager.luau:186`), `coinsChanged` → `Remotes.CoinsChanged` to that player (`NetService.luau:224-226`), `incomePaid` → MetricsService sums it in memory.
- No attribute is written by the normal tick. During a solar storm (`hatchRate > 1`) `syncIncubator` writes `EggHatchAt` on every incubator egg of every bay every second (`:742-748`, replicated to all clients) and sends `BayChanged` (whole bay) to the owner every second (`:749`).
- Indirect per-second writes caused by the income: `leaderstats` StringValue and the coin board `Rows` StringValue (§7).

### ModelStreamingMode **[code]**

- `Bay{n}` model: default (not set) — `BayModel.luau:927`.
- Places: Atomic (`:149`). Aliens: Atomic (`AlienModel.luau:104`). Capsules, terminals, stand, shelf: default. Kiosks: Atomic (`KioskModel.luau:80`). Serpent: Persistent (`SerpentModel.luau:66`).
- With StreamingMinRadius 2048 > map, all of these are always streamed in.

---

## 4. World

All world geometry is built once at server start by `server/Services/WorldService.luau:720-741`. Kits: `ZoneKit` has **15 piece types** (`server/World/ZoneKit.luau`); every rock, ice chunk, nest rock, rim, cradle and ring is a clone of one of them (shared MeshId). `StationKit` likewise. No per-part unique meshes are created in code. **[code]**

| Builder | Parts | Class / material / shape | Transparent | Neon | CastShadow |
|---|---|---|---|---|---|
| Asteroids (`buildAsteroids` :351, `buildFieldRock` :290) | **700** rocks + crystals bunches (Ice Rings and Red Nebula "crystals" kinds, weight 2/9 each) + rings (Event Horizon, weight 1/9) → **[est] ~800** | ZoneKit MeshParts (Slate, Snow, Ice, Glacier, CrackedLava, Basalt, Glass) | Ice rocks 0.15 (weight 3/9 in Ice), Horizon loose crystals Glass 0.2 (2/10), crystal bunches Glass 0.2–0.25 | rings | **rocks: not set → kit default (true)**; also `CanCollide = true` and `CanQuery = true` for all but loose crystals (:316-317) |
| Scrap (`buildScrap` :366) | 160 + 32 lights = **192** | Parts (DiamondPlate, Metal), lights are Neon balls | – | 32 | false (scenery) |
| Nests (`buildNest` :441, 132 nests) | 5 each = **660** | kit NestRock MeshPart, pillar + pad cylinders, kit Rim (Neon) and Cradle MeshParts | – | 132 rims | **rock, pillar, pad: not set → true**; rim/cradle not set → true; rock/pillar/pad CanCollide+CanQuery true |
| Nest eggs (`NestService.placeEgg`, `EggModel.build`) | 2–4 parts + 1–3 Welds each → **[est] ~400 parts** | box + kit Body/Glow/CapGold | box Transparency 1 | Glow | egg parts false (`EggKit.luau:48`) |
| Craters (meteor shower, temporary) | 5 each + PointLight (Range 24, Brightness 2, Shadows default false) (`WorldService.luau:510-525`, `MeteorLooks.luau:20-21`) | | | | |
| Landmarks: ice band (`:572-601`) | **720** | ZoneKit IceChunk MeshParts, Ice | – | – | false |
| Landmarks: haze (`:603-625`) | **75** | Ball Parts **200–450 studs**, ForceField | **0.88** | – | false |
| Landmarks: black hole | 2 | Ball r=225 Neon (Transparency 0.5) + Ball r=200 | rim 0.5 | 1 | false |
| Boundary (`:663-678`) | 1 | Part 2048³ + SpecialMesh sphere scaled to BOUNDARY_RADIUS (= last ring + 200) | ForceField 0.9 | – | false |
| Station border (`buildBorder` :113-152) | 1 shell (Ball r ≈ 581, ForceField 0.93) + **96 Neon ring segments** | | shell | 96 | false |
| Islands (`buildIslands` :237, `buildDomedPlatform` :156) | 8 × (Platform, Rim, Dome, 4 Hull steps, SpawnLocation) = **64** | Dome: Ball r=142.5 ForceField | Dome 0.75 | 8 rims | **Platform and Hull not set → true** |
| Station (`server/World/StationModel.luau`) | platform, rim, dome, hull + hull glow (kit), 8 ring segments (kit), **16 screens**, ring glow, 4 pylons ≈ **33** | | dome ForceField | rim, glows | platform, hull, ring segments, pylons **true** (explicit, `:66`, `:89`, `:133`, `:191`) |
| Kiosks (`server/World/KioskModel.luau`, 4) | ~7 parts each (pearl, dark, glow Neon, holo (transparent), badge, plate) + Attachment + **ProximityPrompt** + **PointLight** (Range 12, Brightness 1, Shadows false, `KioskModel.luau:133-137`) ≈ 28 | | holo | 4 | per `settle` args |
| Coin board (`server/World/LeaderboardModel.luau`) | dais, pillar, pearl, glow, 4 panels + frames, 2 coin models (2 parts each) ≈ 15 | | hologram coin | glows | gold coin true, rest false |

Totals **[est]**: ~3 900 world parts + ~1 800 island fixed parts + contents (pets ≈ 30 parts each → up to ~7 000 for 240 pets) ≈ **12 000+ BaseParts on every client**, all streamed in.

Lights in the world **[code]** — none with `Shadows = true` anywhere in `src/` (grep). Server-made: 4 kiosk PointLights (R 12), nest eggs Epic/Legendary PointLights (R 8.4 / 14, Brightness 1.2 / 2), incubator Epic/Legendary eggs (R 1.7 / 2.8), ready eggs (R 8, B 3), craters (R 24), serpent head (R 40, B 3, `SerpentLooks.luau:17-18`), greybox aliens. Client-made: 1 per adorned pet (R 5–16, on only at detail 1). No SurfaceLights/SpotLights found in `src/` **[code, grep]**.

Particles in the world (server): meteor eggs' `Fire`, lucky eggs' `Sparkles` only. Everything else is client-side (§1, §10).

Big transparent surfaces that the camera can be inside or look through **[code]**: 9 domes (ForceField), border shell, boundary sphere, **75 haze balls 200–450 studs** (ForceField 0.88) through the whole Red Nebula, black-hole rim (Neon 0.5, r 225). On a phone each layer of ForceField/transparent sphere in view is a full-screen blended pass **[est; measure the Red Nebula]**.

**Unknown from code [measure]:** whether the ZoneKit source MeshParts in the place have `CastShadow` off (the asteroids, nest rocks and rims inherit it: `WorldService.buildFieldRock` and `nestPart` never set it), their `CollisionFidelity` and `RenderFidelity`, and their triangle counts.

---

## 5. World-space UI on one client (8 players, 30 pets per island)

| Gui | Kind | Count on a client | MaxDistance | AlwaysOnTop | Size / PPS | Changes |
|---|---|---|---|---|---|---|
| Pet rune + glow (`AlienDress.luau:993-1009`) | SurfaceGui (FixedSize) | **2 per adorned pet → up to 480** | none (unlimited) | no | canvas **1024²** + 256², Brightness 2 | static image, but the Halo part turns every frame for near pets (`RigMotion.luau:472-476`); **never disabled by detail** |
| Meteor crest / legendary medal (`AlienDress.luau:166-187`) | BillboardGui + 2 ImageLabels | 1 per meteor or t4 pet | 300 | no | radius·(1.6..2.8) studs, scale | **Rotation written every frame** (`AlienMotionController.luau:218-221`) at detail ≤ 2 |
| Pet income chip (`BayViewController.luau:382-406`, `UI/WorldChip.luau`) | BillboardGui (pill, UICorner, UIStroke, list layout, IconText) | 1 per pet on every island: **≤ 240** + shelf pets ≤ 24 per island (**≤ 192**) | 35 + 2·height; shelf 12 | **yes** | 220×32 px | static |
| Incubator egg chip (`BayViewController.luau:410-436`) | BillboardGui | ≤ 12 per island → **≤ 96** | 35 | yes | 220×32 | **text every 1 s** (`:469-481` ticks *all* views on all islands, regardless of distance) |
| Waiting egg chip (`:438-451`) | BillboardGui | ≤ 24 per island → **≤ 192** | 35 | yes | | static |
| Owner board (`:163-188`) | SurfaceGui ×2 (front/back) | **16** | 120 | no | PPS 50 on a 14×3 board → 700×150 px, **TextScaled** | static |
| Terminal screens (`UI/TerminalScreen.luau`) | SurfaceGui + client Beam | **24** (3 per island) | 80 | no | PPS 100 on 6×4 studs → 600×400 px | value text and button state change on events; the owner's 3 buttons re-evaluate `canAfford` on every `CoinsChanged` (1 Hz); a value change plays a 0.8 s tween (`:103-117`) |
| Guardian name (`GuardianViewController.luau:147-163`, `UI/GuardianLabel.luau`) | BillboardGui | **132** | 500 / 750 / 950 / 1150 by zone (`ZoneLooks.luau:202-207`) | **yes** | 240×32 | colour re-evaluated whenever the speed source changes (4 Hz while training, `TrainingService` tick) |
| Nest egg beacon (`EggBeaconController.luau:95-120`) | BillboardGui (2 Frames, UICorner, **UIGradient** each) | **132** (enabled only for Uncommon+ eggs present) | 500 | no | width studs × height 22–85 studs ×2 | on nest attribute change only |
| Ring banner (`UI/RingBanner.luau`, `KioskController.luau:146-159`) | SurfaceGui, ClipsDescendants, 8 items each (ImageLabel + **TextScaled** label) | **16** (8 outer + 8 inner screens, `StationModel.luau:152-168`) | **800** (seen from every island) | no | PPS 18 on 33.4×10.9 studs → ~601×196 px | **endless linear Position tween on every screen** (`RingBanner.luau:86-92`, repeat −1) → all 16 redraw every frame while in range |
| Kiosk plate / badge / hologram (`UI/KioskSign.luau`) | SurfaceGui | 3 per kiosk → **12** | 300 | no | PPS 40; plate TextScaled | hologram icon: **endless bob tween** (`KioskSign.luau:81-83`, repeat −1, reverses) on 4 kiosks |
| Coin board (`UI/CoinBoard.luau`, `CoinBoardController.luau:130-150`) | SurfaceGui, 2 faces (Near 10 rows, Far 3 rows) | **4** panels | **1000** | no | PPS 20 on 36×26 studs → 720×520 px; names/titles `scaled = true` (TextScaled) | **rows replaced whenever the server's `Rows` JSON changes — every second while a top-10 player on this server earns** (§7); every row of all 4 panels re-evaluates |
| Training pop (`TrainingViewController.luau:39-66`) | BillboardGui + TextLabel + 2 tweens | new one **4×/s** while the local player trains, each lives 1.1 s (~4–5 alive), not pooled | none | yes | 160×36 | tweened |
| Newbie chip (`NewbieViewController.luau:52`) | BillboardGui (WorldChip) | ≤ 7 (other players under protection) | 150 | yes | | static |
| Grab prompt / custom ProximityPrompt views (`GrabPromptController`, `PromptViewController`) | BillboardGui | 1 + 1 per prompt currently shown | ∞ / per prompt | yes | 300×64 | progress ring while holding |

Totals **[code-derived, upper bounds]**: BillboardGuis ≈ 132 + 132 + 240 + 192 + 96 + 192 + meteor/legendary boards + ~10 ≈ **~1 000**; SurfaceGuis ≈ 480 (runes) + 24 + 16 + 16 + 12 + 4 ≈ **~550**. Everything is in the world at all times (streaming covers the map); MaxDistance culls the drawing but not the instances.

Every-frame redraws **[code]**: 16 ring banners (in range 800), 4 kiosk holograms (300), every meteor/legendary pet's crest/medal (2 rotating images each, within FAR), the 2 coin-board coins turned by `PivotTo` every frame (`CoinBoardController.luau:80-89`, with a `GetChildren()` allocation each frame).

---

## 6. Screen UI and Vide

**All windows are built at client start, hidden**, not on first open **[code]**: each controller's `start` calls `Vide.mount` into PlayerGui (`BayWindowController.luau:393,690-693`, `IndexController.luau:304,368-370`, `ShopController.luau:164,255-257`, `StoreController.luau:232,261-267`, `QuestController.luau:195,246-248`, `LoginGiftController.luau:112,152-154`, `CommunityController.luau:113,146-153`) and the window frame is `Visible = props.visible` (`UI/NeonWindow.luau:121`, `UI/Window.luau:59`). Nothing uses `Vide.show`/`switch` to defer building a window body (grep). Lists use `Vide.indexes`, so their rows exist as soon as the data does.

Per hidden window **[est; measure `#ScreenGui:GetDescendants()` per window in Studio]**:
- `NeonWindow` frame: veil, window with UICorner + UIGradient + UIStroke + size constraints + UIScale, header with a **CanvasGroup** tint (2 frames with UIGradient, `NeonWindow.luau:54-75`), close button, coins pill (ResourcePill uses `TextService:GetTextBoundsAsync`), footer — ~40 instances. One CanvasGroup per window × 7 windows.
- BayWindow: an `AlienRow` (12 `create` calls each, `UI/AlienRow.luau`) per pod (3–30) and per inventory alien (≤ 10), an `EggCell` per incubator slot (≤ 12), footer picks → **[est] 600–1 000 instances** for a full bay.
- IndexWindow: **not** 720 cells — only the picked guardian's set: 3 kind rows × 5 cells (`IndexWindow.luau:592-628`, `IndexController.luau:130-156`) plus guardian and zone tabs → **[est] 300–400 instances**.
- ShopWindow: one row per jetpack level (`ShopController.luau:118-141`) → **[est] 300–500**.
- QuestWindow: 3 cards; LoginGiftWindow: 7 tiles; StoreWindow; CommunityWindow → **[est] 150–300 each**.
- HUD (`HudController.luau:414`): always visible.
→ **[est] ~2 500–3 500 GuiObjects** under PlayerGui at start, of which ~2 000 hidden.

**AlienPicture sheets are loaded at start, contrary to the comment** (`UI/AlienPicture.luau:79-97`, "not at the game's start"): `preload()` runs the first time *any* `AlienPicture` is constructed, and the hidden Index window (its picked set exists from the start, `IndexController.luau:87`) and Bay window construct them during their eager mount → `PreloadAsync` of **all 24 sheets** in the first seconds. A sheet is 5 tiers × 128 px wide and one 128 px row per kind (`AlienIcons.luau:18`; 3 kinds → 640×384 px) → **[est] ~1 MB RGBA each, ~24 MB decoded** if all stay resident.

Reactive work while hidden **[code]**:
- On `CoinsChanged` (1 Hz while any pet earns): `BigNum.format(coins)` in the HUD and the header of every window that shows coins (Bay, Index, Shop, Store, Quests, LoginGift, Community), BayWindow's two affordability checks (`BayWindowController.luau:555,565`), Shop `canBuy`/`saving`/`savingShare` (`ShopController.luau:84-157`), the owner's 3 terminal buttons (`BayViewController.luau:92-94`). ≈ 12–15 `BigNum.format` + ~6 comparisons per second — cheap.
- On the speed source (`State/SpeedState.luau`; changes **4×/s while training**, since `TrainingService` republishes the attributes every 0.25 s): HUD speed text + goal (`HudController.luau:374,471,515`), Shop `card()` (a plain function re-run by each consumer, `ShopController.luau:96-115`), and **132 guardian label colours** (`GuardianViewController.luau:150-161`).
- On the oxygen attribute (every simulation step in space or while refilling): HUD oxygen bar (known).
- `IndexController.setView` is a plain function, not a `derive`: each of the 5 `props.set()` consumers in IndexWindow recomputes the whole set view (zone sets, 15 cell records, text lookups, `Pace.reward` when a set is ready) when `index`/`upgrades`/`bay` change; not per second.
- Timers inside windows tick only while open (Bay `:753`, Quests `:267`, LoginGift pulse `:204`).

Costly UI features **[code, call sites]**: UIStroke/textStroke/glass helpers — StoreWindow 11, IndexWindow 11, ShopWindow 9, Layout 9, QuestWindow 7, LoginGiftWindow 6 (per row where in a list). CanvasGroup: NeonWindow (1 per window). TextScaled: owner boards, ring banners (8 labels × 16 screens = 128), kiosk plates, coin board names. UIGradient: NeonWindow ×3, egg beacons ×2 each (264), terminal screens.

---

## 7. Server periodic work and replication

One Heartbeat drives `Scheduler` (`Main.server.luau:51-52`). Jobs **[code]**:

| Job | Rate | Per tick | Replicated writes |
|---|---|---|---|
| `BayService.tick` (`BayService.luau:754`) | 1 Hz | per player: `update` (coroutine), income, `CoinsChanged` remote to owner, `refresh` only if the ready-egg count changed | none normally; **storm: `EggHatchAt` on every incubator egg of every bay every second + the whole `BayChanged` to each owner every second** (`:742-749`) |
| `OfflineService.mark` (`OfflineService.luau:116-130`) | 1 Hz | per player: `update` (lastSeenAt, playSeconds) | none |
| `LeaderboardService.refresh` (`LeaderboardService.luau:179-193`) | 1 Hz | per player whose `coinsEarned` changed: `leaderstats.●` StringValue = `BigNum.format(...)` (replicates only when the string changes); then `publish()` | **`Rows` StringValue on the coin board**: JSON of up to 10 rows (`{userId,name,coins{mantissa,exponent}}`, ~70–90 B each → **~0.7–0.9 KB**), re-encoded each second something changed and **sent to all 8 clients whenever it differs** — every second while any top-10 player on this server earns (live players show exact `earned`, `:114`) |
| Leaderboard write | 300 s | OrderedDataStore `SetAsync` per changed player | – |
| Leaderboard read | 120 s | `GetSortedAsync(false, 10)` + `UserService:GetUserInfosByUserIdsAsync` for unknown names | `Rows` |
| `TrainingService.tick` (`TrainingService.luau:83-102`) | **4 Hz** | per training player: `update`, `publishSpeed` | **Player attrs `SpeedMantissa` (every tick), `SpeedExponent` (rarely), character attr `FlightSpeed` (every tick)** (`SpeedService.luau:47-55`) → all clients; `Trained` remote to owner 4 Hz; quest progress → `QuestsChanged` ≤ 1 Hz (`QuestService.luau:172-179,275`) |
| `QuestService.sendUnsent` | 1 Hz | `QuestsChanged` to players with progress | – |
| `QuestService.checkDay`, `LoginGiftService.checkDay` | 5 s | compare UTC day | – |
| `TutorialService` speed check (`:137`) | 1 Hz | per tutorial player | – |
| `DomeFlightService` (`:49`) | 1 Hz | per player not yet learned | `DomeFlightLearned` once |
| `ActivityService.sample` | 1 Hz | per player | none |
| `MetricsService.watchLeftStation` | 1 Hz | per player in space | none |
| `MetricsService` flush | 300 s (30 s in Studio) | all pending events at once | – |
| `EventService.tick` (`EventService.luau:150-167`) | 4 Hz | per event | `Phase`, `EndsAt`, `Zone`, `Position` on the event folder **only on a phase change** |
| `SerpentService.tick` (`SerpentService.luau:345-366`) | **15 Hz** during a hunt | steer the head (`LinearVelocity.VectorVelocity`), every 0.25 s `movePlace` + `setFollow` | **`Position` attr of the Serpent event folder at 4 Hz** (`EventService.luau:232`), `Follow.Value`; head = 1 Part + 2 eye Parts + PointLight (R 40) + movers (`SerpentModel.luau:60-89`); body is client-only |
| `NestService.tick` (`NestService.luau:182-189`) | 10 Hz | 132 `shouldGrow` checks | nest attrs only when an egg grows or goes |
| `PvpService.tick` (`PvpService.luau:469-480`) | 15 Hz | per player: newbie seconds, ability input edges | **`NewbieSeconds` player attr every second** for the first 20 min of play (only when the whole second changes, `:458-466`) |
| `PvpService.watchLunges` | every PostSimulation | per player; cone test only while lunging | – |
| `SpaceService` PostSimulation (`SpaceService.luau:193-195`) | every frame | 8 oxygen checks | – |
| `SpaceService.floatWhenDead` | Heartbeat per dead body in space | `PivotTo` of the anchored body every frame until respawn (`:101-109`) | all its parts' CFrames |
| `GuardianService.tick` (15 Hz), `CarryService.postSimulation` | known | | |
| `StormService` (event) | every 5 min 15 s | **`LoadCharacterAsync` for every player in space at once** (`StormService.luau:41`) → new characters and jetpacks | `FlightRangeLimit` on workspace |
| `MeteorService` | during a shower | a meteor every 3 s; a crater = 5 parts + egg + guardian | `MeteorTarget` |

### Character attributes written by `SpaceSimulation.step` (`shared/Simulation/SpaceSimulation.luau:459-507`) **[code]**

Every simulation step for every character on the server (and predicted on each client for its own). Writes are change-guarded except `HitAngle`, so what replicates is what changes:

| Attribute | Changes every step when |
|---|---|
| **`Oxygen`** (`breathe`, :380-389) | **in space (drain 1/s → a new float every step), and under a dome while refilling (25/s, ≤ ~7 s)** — continuously for every flying player |
| `JumpReleasedFor` (:154-158) | 0.05 s after releasing jump |
| `JumpTapWindow` (:159-163) | 0.4 s after a tap |
| `HitAngle` (`tumbleAngle`, :181-192, unguarded) | every step of a 1.2 s stun |
| `StrikeLunge`, `StrikeCooldown` (:217-218) | lunge 0.25 s, then **1.5 s of cooldown after every strike** |
| `GrabProgress` (:450-452) | while grabbing an egg |
| `InSpace`, `SlowMode`, `SlowModeHeld`, `JetpackOn`, `JumpHeld`, `GrabEngaged`, `GrabPressed`, `GrabTarget`, `Stand`, `StrikeAim` | edges only |

Also each step while flying: `LinearVelocity.VectorVelocity`, `AlignOrientation.CFrame`, `MaxForce/MaxTorque`, and `humanoid:ChangeState(Physics)` **every step** (:270).
**[est]** 8 players in space → 8 `Oxygen` floats changing at the simulation rate, each replicated to 8 clients. Whether Server Authority folds these into the character snapshot or sends attribute changes **[measure: network stats with 8 flying players]**. Obvious one-line cause: `Oxygen` is written unquantised although it is only drawn as a bar.

---

## 8. Data and analytics

### ProfileStore (`ServerPackages/_Index/lm-loleris_profilestore@1.0.3/profilestore/ProfileStore.luau`)
- Defaults, nothing overridden (no `SetConstant` in `src/`): `AUTO_SAVE_PERIOD = 300` s (:170), `LOAD_REPEAT_PERIOD 10`, `FIRST_LOAD_REPEAT 5`, `SESSION_STEAL 40`, `ASSUME_DEAD 630`, `START_SESSION_TIMEOUT 120`. Store `PlayerData`, key `Player_<id>` (`DataService.luau:19,52`). Load timeout 30 s cancels the start (`DataService.luau:20`, `ProfileStoreAdapter.luau:26`).
- Per session: `StartSessionAsync` = 1 `UpdateAsync` (more on a session conflict: after 5 s, then every 10 s, steal at 40 s) + `MessagingService:SubscribeAsync("PS_<session>")` (:1340); auto-save = 1 `UpdateAsync` per profile per 300 s, spread over the period (:2121); `EndSession` = 1 `UpdateAsync` + unsubscribe; conflicts publish via `MessagingService:PublishAsync`.
- `SessionManager.update` creates a coroutine per call (`SessionManager.luau:183-193`) — ~16/s server-wide from the 1 Hz ticks, +4/s per trainee.
- Robux receipts: `waitUntilSaved` → `profile:Save()` → 1 extra `UpdateAsync` per purchase, retried every 10 s until confirmed (`SessionManager.luau:196-218`).

### Requests per minute, full server of 8 **[code-derived]**

| Request | Steady / min | 8 joins in a minute | Shutdown | Limit / min (8 players) |
|---|---|---|---|---|
| DataStore `UpdateAsync` (ProfileStore) | 8 per 5 min = **1.6** | +8 | +8 (EndSession) | 60 + 40×8 = **380** |
| MessagingService subscribe | 0 | 8 | 8 unsubscribes | (subscriptions 5 + 2×players = 21) |
| OrderedDataStore `SetAsync` (`RankStore.luau:33`) | ≤ 8 per 5 min = **1.6** | 0 | ≤ 8 (one per leaving player with a changed score, `LeaderboardService.luau:199-205`) | 30 + 5×8 = **70** |
| OrderedDataStore `GetSortedAsync` | **0.5** | 0 (+1 at server start) | 0 | 5 + 2×8 = **21** |
| `UserService:GetUserInfosByUserIdsAsync` | ≤ 0.5 (unknown names only) | 0 | 0 | |
| `MarketplaceService:UserOwnsGamePassAsync` | 0 | **2 per join** (2 passes; retries every 5 s) = 16 | 0 | |
| `GroupService:GetGroupsAsync` | 0 | 1 per join after the tutorial, community game only (`CommunityService.luau:82`), up to 3 tries | 0 | |
| Client `MarketplaceService:GetProductInfoAsync` | per client: all ~25 ids on join (`PurchaseState.luau:93-108`), again on opening the store/bay/egg prompt at most every 30 s | | | client throttle **[measure]** |

All well inside the limits. `fetchPrices` clones the price table once per id (`PurchaseState.luau:102-104`) — harmless at 25.

### Analytics (`server/Services/MetricsService.luau`)
- Summed per player, flushed every **300 s** (`:36`) and on leave: economy keys (AlienIncome, Trainer, Quest, LoginGift, Robux, Index, Community …) and counted events (`Ability|kind|result`, `EggLost|reason|zone`, `GuardianCatch|post`, `AlienFound|tier|zone`, `EventSeen|event`, `QuestDone|kind`, `SerpentHit` …). **[est]** 5–20 events per player per flush → **40–160 events in one Heartbeat every 5 minutes** for 8 players (all players are flushed in the same tick, `:395-399`).
- Sent at once: theft funnel (3 `LogFunnelStepEvent` per stolen egg, `:341-367`), `LogEconomyEvent` per coin trade (every buy and **every sell**, `:315-323`), offline settlement (2), onboarding steps, progression, tutorial steps.
- Limit per docs (`docs/ARCHITECTURE.md:131`): 120 + 20 × CCU = **280/min** at 8. Steady **[est]** < 10/min outside flushes; flush burst ≤ 160; worst case: sells limited only by `NetConfig.COMMAND_LIMIT = 5`/s per player → a full-bay sell-off is 30–60 events in ~10 s per player; 8 doing it at once could pass 280 in a minute **[est, unlikely]**. Shutdown flushes everyone at once (≤ 160). Docs and code agree.

---

## 9. Loading path

**Server, per joining player [code]:**
1. `PlayerAdded`: `SpaceService.onPlayerAdded` (`SpaceService.luau:167-181`) creates the `FlightInputs` context, sets the station spawn; `BayService.reserve` (`BayService.luau:562-579`) takes an island and sets `RespawnLocation` (it starts after SpaceService, `Main.server.luau:414-447`, so it wins). `LeaderboardService` adds `leaderstats`. `DataService` starts the ProfileStore session (yields).
2. `CharacterAutoLoads` is never touched (grep) → default true: **the character spawns at once, before the profile loads**, on the reserved island (floor and dome only; the bay is not built yet). `SpaceService.equip` waits for parts (`:46`), adds flight constraints, `JetpackModel.attach` at level 0 until the profile arrives (`JetpackService` swaps it on activation).
3. Profile active (`DataService.luau:82-85`) → `activated`: `BayService.assign` builds the whole bay (`BayModel.build`, ~225 parts) + `refresh` (places, aliens via `AlienModel.build` clone + ScaleTo each, capsules, eggs); `NetService.sendSnapshot`; `SpeedService.publish`; `PurchaseService` pass checks (async); quests, login gift, community; `OfflineService` settlement last (`Main.server.luau:443-444`).

**Client [code]:**
- No `ReplicatedFirst` in `default.project.json` → **no custom loading screen**.
- `Main.client.luau`: ~50 controllers/states; `Lifecycle.run` (`shared/Runtime/Lifecycle.luau`) runs every `init` (must not yield), then `task.spawn(start)` for each.
- `ProfileState.start` fires `RequestSnapshot` (`ProfileState.luau:172`); the HUD shows a placeholder until `loaded` (`HudController.luau:471,481`).
- `WaitForChild` on the path: `PlayerGui` (30 s) in ~12 controllers; bay parts (`BayViewController.luau:142,193,251`, 10 s); coin board `Rows`/`Coins`; event folder (`EventController.luau:371`); serpent folder and `workspace.World` (`SerpentController.luau:170-178`); kiosk parts; `Head` for newbie chips; `FlightInputs` context (`Input/TouchBindings.luau:15`).
- `PreloadAsync`: **sounds** — 36 names in `SoundLooks` (`SoundLooks.luau:10-46`) × `READY_COPIES = 2` (`:245`) → **72 Sound instances, all at start**, in a background task (`UiSoundController.luau:33` → `SoundPlayer.luau:274-291`); **24 alien icon sheets** (§6, triggered by the hidden windows); **each pet's meshes** (`AlienMotionController.luau:352-359`, one call per pet, up to 240); **each guardian's meshes** as its look is built (`GuardianVisual.luau:176`, known: all 132 at join); the serpent kit during a hunt (`SerpentVisual.luau:276`).
- Synchronous work in the first frames **[code]**: building ~7 windows + HUD (§6); `AlienDress.adornLocally` for **every non-plain pet on every island** (§1: clone + ~7 descendant walks + 2 `ScaleTo` + ~15–60 new instances each; up to 240 pets, one `task.defer` each, `AlienMotionController.luau:320-360` — deferred threads all run in the same resumption point) then `RigMotion.read`; guardian looks for 132 bodies (known); 132 guardian labels, 132 beacons, ~1 000 world BillboardGuis (§5); a thread per label in `BayViewController.label`.
- Sent to every client at join **[code]**: `ReplicatedStorage.Shared` = **128 modules, 535 KB source** (`Locale/Strings.luau` 44.6 KB, `World/AlienDress.luau` 49 KB); `Packages` (Vide) 29 files, 59 KB; `StarterPlayerScripts.Client` = **100 modules, 692 KB source** (heavily commented; Roblox ships bytecode); the `Events` folder; hand-inserted kits `ReplicatedStorage.Guardians` (24 models, 626 parts, 617 unique meshes — known), `SerpentKit`, `PvpKit` (16 MeshParts). Then the whole world (§4: ~3 900 world + ~1 800 island parts + up to 240 pets × ~29 MeshParts) because `StreamingMinRadius 2048` covers the map **[measure: time to first frame, memory, and whether the join waits for the min radius]**.

---

## 10. Other client per-frame / frequent work **[code]**

| Where | Finding |
|---|---|
| `AlienMotionController.luau:377-378` | fresh `parts`/`frames` arrays every frame (§2) |
| `CoinBoardController.luau:80-89` | RenderStepped forever: `folder:GetChildren()` (new table) + 2 `PivotTo` every frame |
| `CoinBoardController.luau:113-121` | Heartbeat forever (distance check every 0.5 s) |
| `BayViewController.luau:469-481` | Heartbeat forever; once a second iterates **all** views of all islands and re-formats the countdown of every incubator egg on the server (≤ 96), visible or not |
| `BayViewController.luau:113-120` | `remove()` scans every view with `IsDescendantOf` on each removal (O(views) ≈ 600) |
| `TrainingViewController.luau:39-66` | a BillboardGui + TextLabel + 2 Tweens created 4×/s while training, destroyed by `task.delay` — not pooled |
| `FeedbackController.luau:45-80` | hatch burst: new Part + ParticleEmitter + PointLight + Tween per hatch (rare) |
| `HarpoonVisual.luau:68-118`, `BombVisual.luau:53-152` | new Model/Attachments/Beam/Trail per shot/throw, destroyed after; `HarpoonVisual.luau:55` scans `GetTagged(LOOSE_EGG_TAG)` per shot (rare) |
| `EggEffectsController.luau:35-71` | a Trail per loose egg; Trail + ParticleEmitter per carried egg (go with the egg) |
| `SerpentVisual.luau:298-333` | per frame during a hunt: 2 closures, ~18 segments' CFrames into a reused table, one BulkMoveTo — fine |
| `AimController.luau:30-37` | BindToRenderStep forever: 3 `FindFirstChild` + `binding:Fire` each frame (engine dedups) |
| `HitEffectsController.luau:25-43` | BindToRenderStep forever; one `GetAttribute` per frame when not stunned |
| `UI/Press.luau:77-86`, `UI/FlightButtons.luau:186-191` | RenderStepped/Heartbeat only while a press animates; disconnected after |
| `UI/GuidePath.luau:50-125` | one Beam + one Highlight (AlwaysOnTop) during the tutorial |
| `UI/RingBanner.luau:86-92`, `UI/KioskSign.luau:81-83` | endless tweens (never stopped; their screens never go away) |
| `EggBeaconController.luau:126-136`, `GuardianViewController.luau:118-127` | connections disconnected on removal — fine |
| `NewbieViewController.luau:84-92` | per-player connections never disconnected (they go with the Player instance) |
| `AlienMotionController.luau:304-316`, `CoinBoardController.luau:129-137` | instance-keyed tables cleared on removal — fine |

No `GetDescendants` inside per-frame code in these files. `ScreenPin.luau` has no per-frame hook of its own.

---

## 11. Jetpacks and characters

- `JetpackModel.attach` (`server/Character/JetpackModel.luau:258-292`) on every `CharacterAdded` (`SpaceService.luau:143,176`): clones `ServerStorage.Jetpacks.Jetpack<n>` (part count lives in the place **[measure]**), `ScaleTo`, moves its parts into a Model with **one WeldConstraint per part**, + 2 grips (Grip + Neon Button, 2 WeldConstraints) + 2 hose **Beams with 8 segments** (`:241-253`, `LightInfluence 1`) + 4 Attachments. Greybox fallback: plate + 2×(tank, cap, stripe, nozzle) = 9 parts.
- Shadows: template parts named `Shell` and `Metal` cast shadows (`JetpackLooks.luau:334-347`); Glow/Glass do not; greybox parts do not (`decor`, `:50`).
- Lights: none on the server model; flames/beams/lights are client-side (`JetpackEffectsController`, known).
- Rebuilt on every respawn and on a level change across a model boundary (`JetpackModel.update`, `:296-306`); the storm respawns everyone in space at once (§7).
- Per client with 8 players: 8 jetpack models (template parts + 4 grip parts each) + 16 hose Beams.
- Humanoid: `BreakJointsOnDeath = false` (`SpaceService.luau:137`); only `Jumping` is toggled (`SpaceSimulation.luau:274,332`); no other `SetStateEnabled` (grep) — Swimming, Climbing, Seated, Ragdoll, FallingDown, GettingUp etc. stay enabled; `ChangeState(Physics)` every step in flight (`:270`). 3 Animation instances per character (`SpaceService.luau:145-165`).
- Avatars: nothing in code limits accessories, layered clothing or body scale (no `HumanoidDescription` handling, no avatar settings in `default.project.json`) → avatar cost is whatever Game Settings → Avatar allows **[check Game Settings]**.
