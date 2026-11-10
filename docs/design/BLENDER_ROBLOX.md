# Blender → Roblox 3D: lessons learned

Agent-facing knowledge base (English on purpose, decision 078); draft of a future skill. Distilled from shipping 720 pets from Blender scripts into Studio (decisions 072–074, prototype `docs/design/prototypes/pet-look/`). Each rule carries the incident that produced it.

## 1. Axes and signs

Directions in our pipeline (measured in Studio):

| | Blender | Roblox (after GLB import) |
|---|---|---|
| Up | +Z | +Y |
| Face (visor, eyes, claws) | −Y | −Z |
| Back (jetpack, tail, wings) | +Y | +Z |
| Pet's left side | −X | +X (import turns the model 180°) |

- **Don't trust L/R names.** Derive the side from the part's actual position (`X > 0`), not from `wingL`/`wingR`: after the 180° turn Blender's left wing sits at +X.
- **Blender yaw:** `Rz(+θ)` turns +X towards +Y (the back). A part mirrored by `side` (−1/+1) sweeps back with `+side·θ`.
- **Roblox yaw:** `CFrame.Angles(0, θ, 0)` with +θ turns +X towards −Z (the face). A part on +X sweeps back with −θ, i.e. `−side·θ`.
- **Blender Euler XYZ** is `R = Rz·Ry·Rx`: Z is applied last, in world axes. "Tilt, then sweep" = `rotation_euler = (tilt, 0, sweep)`.
- **Particle direction** (`EmissionDirection`) is in the attachment's axes. Tilt a jet by rotating its attachment: `CFrame.Angles(−0.29, 0, 0)` leans `Bottom` towards +Z (back).
- **A comment stating a direction is not proof.** Verify every direction constant by measurement: compare hinge, part centre and visor in Studio (`base:PointToObjectSpace`), or assert it in the part check.

Incident: code and comment said "wings swept 38° back", but the rotation sign was flipped, so they swept forward. The game's flap moved them back from that pose, which looked like flapping forward. Front renders hid it; a Studio measurement exposed it (the wing centre was nearer the face than the hinge).

## 2. What reads differently in game than in Blender

- **A solid glowing cone reads as a spike.** Roblox Neon is flat: no gradient, no soft edge. Flames, rays, comet tails and sparks in game are particles (`ParticleEmitter`, `Beam`, `BillboardGui`). In Blender such a part stays a stand-in with **its own material**; the game hides it (`Transparency = 1`) and spawns particles there. Current stand-ins: `Flame`, `FlameCore`, `Tongue`, `Ray`, `RayShort` (`STAND_INS` in `dress.luau`) and `Jet` (jetpack flame → a jet from the nozzle).
- **Two round glowing spots read as eyes.** Rear-facing engine nozzles looked like a second pair of eyes from behind; the engines now fire down. Check any paired round lights from the back.
- **A thin flat part vanishes edge-on.** A wing swept 22° at rest was a line from the side. Too far the other way looks wrong too: a flap of 35°–70° back, then 21°–55°, read as wings pinned back. Current: rest 38° back (geometry), flap 11°–45° (animation offset). The range is a taste call — ask, and shift it in the animation, not the mesh.
- **Glow burns out.** In Blender, strength 2–3 keeps the colour; 8+ is burnt to white by AgX. In Roblox, Neon under Bloom also goes white.
- **See-through and glowing means Glass, not Neon** (Neon gives a white spike). The exporter decides: alpha < 1 or transmission ≥ 0.5 → Glass.
- **Particles don't render behind Glass.** Candle flames inside a dome vanished; they were moved above it.
- **Metal without reflections looks like plastic, and olive in dark space.** Gold and chrome use a `MaterialVariant` (`PetMetal`) under Realistic lighting (decision 076).
- **Procedural Blender materials don't export.** Colour travels as an attribute (`Paint`); textures (lava) as UVs + `SurfaceAppearance`.
- **Roblox reads vertex colours (glTF COLOR_0) as sRGB numbers, not linear.** glTF stores them linear and Blender's exporter converts a `BYTE_COLOR` attribute to linear, so a colour written with `color_srgb` arrives darker and richer than the same `Color3` (a cap baked as 64, 140, 255 showed deep blue next to a light blue ball of that `Color`; Studio, 2026-11-10). To get a colour as it is, write the sRGB numbers into `item.color` (the linear setter): the GLB then holds them unchanged. A check sheet shading the attribute must turn it back to linear (Gamma 2.2) to match the game. `assets/blender/eggs/egg_kit.py` does this; the pets' and zones' bakes still use `color_srgb` (their colours read darker than written).
- **Billboard/particle textures must be white up to the last transparent pixel.** Roblox filters them without premultiplying; black empty pixels leave a dark halo.
- **A Blender material name is a contract with the game.** It decides what is hidden, glass, metal or particles. Rename a material → check `dress.luau`. The whale's porthole was named `Glass` and turned see-through until renamed `Porthole`.

## 3. Export: what merges into one mesh

- The exporter (`export_robo_roblox.py`) **joins parts by role and look**: one role + one paint code becomes one `MeshPart` named `<role>_<n>`. Otherwise a pet is hundreds of parts. Join by the paint code, not the Blender material: `robo.py` gives many parts their own copy of a material (`Seam.001`, `Seam.002`), and joining by material name left a quarter of all parts as duplicates (38756 parts in 720 pets; 2026-11-10).
- **What stays one part per material** (`KEEP_ROLES`, `KEEP_SOURCES`): parts the game reads one by one — roles whose positions it averages or takes per part (`rotor` spins about its parts' middle, `drone{n}` fly from theirs, `hinge*` markers are the pivot, `halo` pieces turn about themselves, `flame` tongues set the candle flame), and parts that each stand for something (`EyeLight` eyes blink, the slime's `Dome` sets the jelly floor, `Jet`/`Flame`/`Ray` stand-ins emit particles, `…Wing` membranes, lava `Meteor…` with its UVs). On a slime nothing joined spans the jelly floor (what stands above it squashes with the jelly).
- **A MeshPart has one colour and one material**, so joining stops at one part per role and paint: about 45–55 parts a pet. Fewer would need a colour atlas (UVs into a swatch texture, `MeshPart.TextureID`) or hinge markers turned into attributes.
- **Merged parts can't be split in Studio.** The jetpack flame shared material and colour with the tank's band and merged with it, so hiding only the flame was impossible; all kinds had to be re-exported. Rule: anything the game will move, hide or emit from gets **its own role or material** in Blender.
- **Only separate roles move:** `wingL/R`, `rotor`, `drone{n}`, `orbit`, `rays`, `wisp`, `halo`, `ring`. Marker points are tiny parts with roles of their own: `hingeL/R` (wing pivot), `hinge<Part>` (a jaw's, leg's, fin's, head's pivot), `dust{L|R}{n}` (fairy dust). `lune run aliens` turns them into attachments when it unpacks (`markersToPoints`): a hinge point named after its marker on a `body` part, a `Dust` point on the wing's membrane. A marker is a MeshPart all the same — a mesh to download, a part to send: 8654 of the 720 pets' 35379 parts were markers (2026-11-10). Attachments scale with `Model:ScaleTo` and move with their part, so no scale bookkeeping is needed.
- Pet data travels in GLB node names and, after unpacking, in attributes. **String attributes: max 50 characters.**

## 4. Placing parts on the body

- **Never place from centre + radius.** A worm's centre sits towards its tail, a swarm's radius spans its drones, the "top" stands above the head; parts floated or sank.
- **Place on the real surface** (`robo.py`):
  - `_flank(info)` → `snap(point, lift)`: a ray from outside towards the hull centre against the BVH of `hull_obj`;
  - `_crown_spot(info)` → hull top height;
  - `stick(info, point)` → nearest body shell (ray wings, claws).
- **A part may look attached only because a neighbour passes through it.** The wing hinge was an offset from the centre and hung behind flat rays and worm heads; the forward-swept wing cut through the body, so the check counted it attached. Swept back, it floated. Root every part on the hull (`snap`, slightly sunk).
- **Part check:** `check_robo_parts.py` (~6 min for all kinds) reports floating groups, parts hidden inside another, and parts cutting others. By-design floaters are excluded via `LOOSE_*`/`SOFT_*`. Run after every shape change and `diff` against the last report: anything new means breakage. Wing intersections are not checked (`SOFT_GROUPS`) — inspect them visually.
- **Inspect from every side and through the whole motion:** front, side, back (artefacts hide at the back), every tier and the meteor variant. Moving parts at the extremes of their motion, not only at rest.

## 5. Getting models into Roblox

1. **Export:**
   ```
   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python assets/blender/aliens/export_robo_roblox.py -- out/robo_pack --pack [kind ...]
   ```
   Blender is not on Git Bash's PATH — run it by full path from PowerShell. System Python is a Microsoft Store stub; use Blender's Python only.
2. **Upload:** Open Cloud `POST /assets/v1/assets` (Model, GLB file), then poll `GET /assets/v1/operations/{id}` until `done`. On `Unknown Error`, upload again.
3. **Insert:** MCP `insert_asset` into `ServerStorage.RoboPackIn`. On "Failed to load package asset: Request Failed", re-upload the GLB (new asset) and insert that. An inserted model is a package: remove its `PackageLink`.
   - **Insertion turns the model about Y** to face the camera (the jetpacks' row came in 46° off, 2026-11-10). Never read directions from world positions as if the pack were axis-aligned: recover the turn from something known (the row of origin markers, `assets/blender/jetpacks/prepare_in_studio.luau`) and undo it with the pivot.
   - **A marker can lose its place on import:** 4 of the jetpacks' 32 nozzle markers (identical tiny tetrahedra) landed on the model's origin (2026-11-10). Check markers against the origin after insertion; the jetpacks' script restores a lost nozzle as its mirror-symmetric pair.
4. **Into the repo and the game:** see 5a.

(The prototype gallery unpacked and dressed in Studio with `PetUnpack`/`PetDress` modules; the game does it in code now — 5a.)

## 5a. Into the game

The game keeps **bare models in the repo** and **dresses them in code**.

- **Bare models:** `assets/aliens/<kind>.rbxm`, a Folder `<kind>` with its ten pets `<kind>-<variant>` (variants `0`–`4`, `m0`–`m4`). A pet holds only what Blender made: MeshParts named `<role>_<n>` with a `Paint` attribute, the pet's data in attributes (`Zone`, `Family`, `Tier`, `Meteor`, `Signature`, `Glow`, `Core`, `TierColor`, `Shell`), the points Blender's markers became (hinge attachments on the body, the wings' `Dust` points).
- **Dressing** — `src/shared/World/AlienDress.luau`, in two halves. The server prepares a pet (`prepare`: paint, metal, lava skin, wing colours, dust points, the `Body` box) and `World/AlienModel.luau` clones it per kind and variant; each client adds the effects (`adornLocally`: particles, light, comets, rune, medal, crest) on a local copy at the dressing scale and moves them onto the model. Effects were half of a pet's instances and the heaviest (1776 emitters for 30 pets), so they never cross the network. A floor alien (`Plain` attribute) gets no effects and no motion. A change in looks is a code change: no re-export, no re-upload.
- **Getting a kind in:**
  1. Export, upload, insert (steps 1–3 of section 5). The pack lands in `ServerStorage.RoboPackIn`.
  2. Select `RoboPackIn` → right click → Save / Export → **Save to File** → `out/RoboPackIn.rbxm`.
  3. `lune run aliens out/RoboPackIn.rbxm` — unpacks each pack (a Model `pack-<kind>` or `<kind>`; a Folder of unpacked pets works too, dressed ones are stripped), writes `assets/aliens/<kind>.rbxm`, the fingerprints in `src/server/World/AlienModels.json` and the bundle `out/Aliens.rbxm` (every kind). Output is byte-for-byte stable.
  4. **Into the place by hand:** delete `ServerStorage.Aliens`, select `ServerStorage`, **File → Import Roblox Model** → `out/Aliens.rbxm`. For one kind: delete its folder in `Aliens`, select `Aliens`, import `assets/aliens/<kind>.rbxm`. The file dialog takes one file at a time (a typed list of names is cut off). Save the place.
  5. In Studio the server warns at start about kinds missing from the place or out of date (`ModelHash` attribute against `AlienModels.json`). A kind without a model stands as the greybox ball.
- **Not through Rojo:** live sync drops the meshes of MeshParts (`MeshContent` empty; [rojo#1221](https://github.com/rojo-rbx/rojo/issues/1221), open in 7.7.1). `rojo build` would be fine; live sync is not.
- **No collision data:** the script sets `CollisionFidelity = Box` and clears `PhysicalConfigData` — the hull data was ~90% of the files (55 MB → 4.7 MB for 72 kinds). Pets collide with nothing.
- **A game server can't set texture maps:** `SurfaceAppearance.ColorMap`, `MaterialVariant` maps → "lacking capability Plugin". They are made in `default.project.json` (Rojo's plugin can write them): `MaterialService.PetMetal`, `ServerStorage.AlienSkins.Lava`; the dressing uses the variant by name and clones the skin. A `Content` property in a project file: `{"Content": {"Uri": "rbxassetid://…"}}`.
- **Size:** Blender grows a pet with its tier (`GROWTH` in `robo.py`); the game divides it out (`AlienLooks.MODELS.TIER_GROWTH`, a test keeps them equal) and applies its own growth (`alien.scale`, decision 068). Dressing is made at `DRESS_SCALE` 3.3 (where it was tuned), then the pet is scaled; particles and pictures scale with it, light range doesn't (set again, clamped).
- **Facing:** a pet faces its pivot's −Z (look vector). `AlienModel.build` puts the lowest visible point on the frame's origin, facing the frame's look vector.
- **`Model.Scale` survives Lune** (property `Scale`), so `ScaleTo` stays absolute after the round trip.

## 6. Studio gotchas

- **Meshes download from Roblox servers and hit limits** — see 6a.
- **Streaming under Server Authority** delivers a model piecemeal. For display set `ModelStreamingMode = Atomic` and rebuild client motion on `DescendantAdded`.
- **`ServerStorage` edits made during Play are lost.** Edit models in Edit mode, then save the place (click the Studio title bar, Ctrl+S via computer-use).
- **Particles render in Edit mode** — effects can be reviewed without Play.
- **Snapshots:** `screen_capture` needs `camera_position`, `look_at_position` and `capture_id`. Review sheet: `_G.PetSheet(kind)` — variants 2, 3, 4, m4 × turns 0°, 90°, 180°.
- **The MCP thread lacks `Network` capability.** Our modules can't be called from `execute_luau` in Play — use the `DevCommands` mailbox.
- **`model:ScaleTo(k)` is absolute:** re-dressing doesn't grow the model.
- **Kit pieces welded to a holder part: give the pieces `RootPriority = -127`.** Out of the workspace no joint moves anything: a script that sets the holder's `CFrame` before parenting leaves the pieces where they were built. On entering, the solver lines the assembly up on its root, and if a piece is chosen the holder jumps to the pieces instead. A carried egg ended up welded to its thief 700–2300 studs away and swung round as they turned (2026-11-10). Moving the pieces on the holder's `CFrame` signal does not help: signals are deferred and run after the parts have joined. Anchored holders (a nest, a capsule) are never affected: they are the root.
- **A fixed Beam (`FaceCamera = false`) spreads its width along its attachments' `SecondaryAxis`** (measured in Studio, 2026-11-10; the docs don't say). With default attachments on a vertical beam that axis lies along the beam, and the beam is invisible from everywhere. Set the attachments' `WorldCFrame` with `CFrame.fromMatrix(at, axis, widthDirection)`. A camera-facing beam is no fix for a flat fan of light: seen from above it lies across whatever it lights (the terminals' beam, decision 086).

## 6a. Mesh loading limits

An inserted model stores only mesh references (`MeshId`). Studio downloads each mesh separately from `assetdelivery.roblox.com`; meshes of an uploaded model can't be served from local disk.

**Symptoms:**
- parts of pets invisible, or half a pet, while Explorer shows every part;
- Output: `HttpError: Timedout` and `MeshContentProvider failed to process … because 'could not fetch'`;
- `ContentProvider.RequestQueueSize` stops shrinking.

**Measured:**
- After ~20 kinds in a row (~12k meshes; a kind's pack is ~500 parts) requests start timing out and the queue stalls. Not VPN-related (it was off).
- **Studio caches failures:** a mesh that failed once won't load again until Studio restarts. Re-inserting or Play doesn't help.
- Fresh assets load slower than cached ones: after re-uploading every kind, Studio downloads everything again.

**Check:**
```lua
-- How many meshes of a folder are not loaded yet (Edit or Play).
local CP = game:GetService("ContentProvider")
local waiting, failed = 0, 0
for _, p in folder:GetDescendants() do
	if p:IsA("MeshPart") then
		local s = CP:GetAssetFetchStatus(p.MeshId)
		if s == Enum.AssetFetchStatus.Failure or s == Enum.AssetFetchStatus.TimedOut then failed += 1
		elseif s ~= Enum.AssetFetchStatus.Success then waiting += 1 end
	end
end
print(waiting, failed, CP.RequestQueueSize)
```
`failed > 0`, or `waiting` with a frozen queue, means restart Studio.

**What helps:**
- **Insert kinds in batches with 45–60 s pauses**; wait for `waiting = 0` before the next.
- **Restart Studio** when failures appear. Save the place first, close Studio (`Stop-Process`, after confirming nothing is unsaved) and relaunch:
  ```
  Start-Process "$env:LOCALAPPDATA\Roblox\Versions\<version>\RobloxStudioBeta.exe" -ArgumentList '-task','EditPlace','-placeId','120029163657587','-universeId','10774871729'
  ```
  After a restart Studio has a new id (`list_roblox_studios`) and the Rojo plugin is disconnected — press Connect.
- **`ContentProvider:PreloadAsync`** on the client for all new meshes at once; without it, swapping many models leaves some meshes unloaded (seen in the gallery).
- **Show one kind at a time** (the gallery), not all 720: it is both the review and a game-like load (up to 30 pets per island).
- **Don't re-upload needlessly:** if a change can be made in dressing (`dress.luau`: particles, colours, materials), make it there — the meshes stay the same, already cached. Re-export only for geometry or part-split changes.

## 7. From roblox-brain

Cross-checked with [roblox-brain](https://github.com/TabooHarmony/roblox-brain) `roblox-building` and `roblox-animation-vfx` (they don't cover Blender or mesh import; only what applies to us):

- **PBR differs by device and graphics quality.** Check metal, glass and lava on low graphics and on a phone, not only in Studio.
- **Layered transparency costs more than emitter counts suggest** (effect layers, lights, animated textures). Up to 30 pets × 8 islands. Measure particle budgets on a phone-class device (MicroProfiler, Developer Console) with several pets on screen.
- **Cut secondary effect layers first** (sparks, twinkle), the primary cue (jet, tier glow) last. Drop extra layers under reduced motion.
- **Emit from an attachment, not the part centre**, for a precise origin (nozzle, wing tip).
- **Particle textures are neutral (white) on transparency**; colour via `Color`, and verify the final colour sequence in game.
- **Decorative meshes need no collision:** `CanCollide`/`CanQuery`/`CanTouch = false` (pets already do), otherwise `CollisionFidelity = Box`.
- **Read the model back after insertion** (count meshes, `SurfaceAppearance`, attachments, emitters) instead of trusting the insert: that is how unloaded meshes and missing jets are caught.
- **Inserting an asset permanently grants the experience access to it** — insert only our own assets.

## 8. Workflow

1. Change the Blender script. The script is the source of truth; a direct Studio fix is temporary and is mirrored in code the same day.
2. Part check + `diff` against the last report.
3. Renders: front, side, back.
4. **One kind first:** export, upload, Studio, snapshots from all sides. Only then all 72 — a full re-export takes tens of minutes and hits the limits.
5. Moving parts: check the whole motion (gallery in Play).
6. `lune run check`, commit.
