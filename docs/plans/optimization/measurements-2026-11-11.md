# Optimization measurements (Studio) — Steal from Space

Date: 2026-11-11. Studio: cloud place "placeId 120029163657587" (universe 10774871729), Edit mode at start.
First attempt (earlier the same day) was blocked: Studio was not running and computer-use access was denied. This is the rerun.

## Setup notes
- `rojo serve --port 34872` FAILED in the worktree: `Packages` folder missing (worktree never had `lune run install`; installing would write into the repo, which the brief forbids). Went on WITHOUT Rojo: the place already holds current code (`StarterPlayerScripts.Client.Controllers.CommunityController` exists, `ReplicatedStorage.Packages` exists). Code version in the place = whatever was last synced; assumed ~master.
- computer-use granted on the 2nd request.
- Studio quality: `settings().Rendering.QualityLevel` = Automatic, `UserGameSettings.SavedQualityLevel` = Automatic, GraphicsMode = Automatic. Viewport 2125 x 1176 (client camera). Numbers are from a desktop GPU in Studio — relative differences matter, absolute ms do not map to a phone.
- Stats properties checked against https://create.roblox.com/docs/reference/engine/classes/Stats : all wanted properties exist (InstanceCount and PrimitivesCount are marked deprecated but readable).

## A. Place settings (measured, client and server identical where both read)
Workspace: StreamingEnabled=true, StreamingMinRadius=2048, StreamingTargetRadius=4096, StreamOutBehavior=Default, StreamingIntegrityMode=Default, AuthorityMode=Server, LevelOfDetail(ModelLevelOfDetail)=Automatic, InterpolationThrottling=Default, Gravity=196.2, FallenPartsDestroyHeight=-5000.
Not readable from scripts (n/a): ModelStreamingBehavior, PhysicsSteppingMethod, SignalBehavior.
Lighting: LightingStyle=Realistic, Technology=n/a (not readable), GlobalShadows=true, Brightness=2.5, EnvironmentDiffuseScale=0.5, EnvironmentSpecularScale=0.9, PrioritizeLightingQuality=false, ShadowSoftness=0.5, ClockTime=10, Ambient=(0.243,0.235,0.361), OutdoorAmbient=(0.376,0.345,0.549), FogEnd=100000, ExposureCompensation=0.
Lighting children:
| Name | Class | Props |
|---|---|---|
| ColorGrading | ColorGradingEffect | Enabled, TonemapperPreset=Retro |
| Sky | Sky | Skybox rbxassetid://130145116580162, StarCount=0, CelestialBodiesShown=true, SunAngularSize=14 |
| ZoneTint | ColorCorrectionEffect | Enabled, all neutral (Brightness 0, Contrast 0, Saturation 0, Tint white) — changed per zone at runtime |
| Bloom | BloomEffect | Enabled, Intensity=0 (!), Size=24, Threshold=0.95 |
No Atmosphere, no DepthOfField, no SunRays, no Clouds.
CurrentCamera children: one Highlight `TutorialTarget` (tutorial pointer).
Terrain: Decoration=false, 1059 descendants on client (0 on server — client-built content under Terrain?).

Top-level client workspace: World (6764 desc), GuardianLooks (4379), Terrain (1059), MidnightComet_Rider (player char, 346), PvpEffects (0), Camera.
Server workspace: World (4914 desc), character (328).
World children, descendants client vs server: Station 595 vs 35, CoinBoard 744 vs 16, Guardians 1716 vs 1188, Bays 300 vs 290, Kiosk* 15 vs 9 each, Landmarks 797/797, Nests 1357/1357, Asteroids 816/816, Scrap 192/192, StationBorder 97/97, Island1..8 8 each.
ServerStorage: Aliens 30189 desc, Jetpacks 80, StandTraining 85, others small. ReplicatedStorage: Guardians 740, PvpKit 16, SerpentKit 16, Shared 136, Packages 30.

## B. Census (client, ~10 s after Play, 1 player, new profile = 0 pets, no bench; whole world streamed in: client World parts 3696 ≈ server 3720 incl. character)
Columns: inst = descendants; parts = BaseParts; mesh = MeshParts; umesh = unique MeshIds; cast = CastShadow=true; semi = 0<Transparency<1; neon/glass/ff = material counts; unanch = unanchored; light = enabled/total/withShadows; pe = enabled/total; bb = enabled/total BillboardGui; sg = SurfaceGui; RF/CF = RenderFidelity/CollisionFidelity of MeshParts.
| Folder | inst | parts | mesh | umesh | cast | semi | neon | glass | ff | unanch | light | pe | beam | bb | sg | other |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| World.Asteroids | 816 | 816 | 816 | 13 | 700 | 193 | 34 | 153 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | RF Auto 816; CF Hull 629, Box 187 |
| World.Nests | 1357 | 1001 | 605 | 13 | 660 | 0 | 205 | 0 | 0 | 209 | 15/15/0 | 0 | 0 | 0 | 0 | CF Hull 132, Default 209, Box 264 |
| World.Landmarks | 797 | 797 | 720 | 2 | 0 | 76 | 1 | 0 | 75 | 0 | 0 | 0 | 0 | 0 | 0 | CF Hull 720 |
| World.Guardians (bodies) | 1716 | 396 | 0 | 0 | 0 | 0 | 264 | 0 | 0 | 396 | 0 | 0 | 0 | 132/132 | 0 | 132 models; server has 1188 inst (client adds 528: BillboardGuis etc.) |
| World.Bays (Bay1 only) | 300 | 261 | 28 | 13 | 0 | 3 | 194 | 0 | 0 | 0 | 0 | 0 | 3 | 0 | 2 | ZoneLines folder = 181 Neon parts; StandLamp 15 |
| World.Station | 595 | 34 | 15 | 5 | 14 | 1 | 3 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 16 | 16 RingBanner SurfaceGuis (server: 35 inst) |
| World.CoinBoard | 744 | 12 | 4 | 3 | 2 | 1 | 4 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 4 | server: 16 inst |
| World.StationBorder | 97 | 97 | 0 | 0 | 0 | 1 | 96 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | |
| World.Scrap | 192 | 192 | 0 | 0 | 0 | 0 | 32 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | |
| World.Kiosk* (x4, each) | 15 | 6 | 4 | 4 | 1 | 1 | 1 | 0 | 0 | 0 | 1/1/0 | 0 | 0 | 0 | 3 | 1 ProximityPrompt each |
| World.Island1..8 (each) | 8 | 8 | 0 | 0 | 5 | 1 | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | Dome ForceField 285³ T0.75; Rim Neon; Platform+4 Hull CastShadow |
| World TOTAL | 6764 | 3696 | 2204 | 50 | 1420 | 288 | 845 | 153 | 86 | 605 | 19/19/0 | 0 | 3 | 132/132 | 34 | CF Hull 1490, Default 215, Box 499 |
| ws.GuardianLooks | 4379 | 3425 | 3293 | 617 | 0 | 529 | 755 | 529 | 0 | 0 | 0 | 0/66 | 0 | 0 | 0 | RF Auto 3293, CF Box 3293 |
| ws.Terrain (client-only children) | 1059 | 0 | | | | | | | | | | | 1 | 73/132 | 0 | 132 BillboardGui + 134 Attachment + 264 Frame/UICorner/UIGradient each (guardian labels?) |
| Jetpack (one player, `Character.Jetpack`, Starter) | 31 | 7 | 3 | | 2 | | | | | | 1 PointLight | 0 | 6 | | | 4 Parts, 10 Attachments, 7 WeldConstraints |
| Character (MidnightComet_Rider) | 346 | 23 | 18 | 18 | 18 | 0 | 3 | 0 | 0 | 23 | 0/1 | 0 | 6 | 0 | 0 | Jetpack model 31 desc; 9 Sounds; RF Precise 15 |
| WORKSPACE TOTAL (client) | 12555 | 7145 | 5515 | 685 | 1439 | 817 | 1603 | 682 | 86 | 628 | 19/20/0 | 0/66 | 10 | 205/264 | 34 | |
| WORKSPACE TOTAL (server) | 5246 | 3720 | 2222 | — | 1439 | | | | | 628 | 19 | 0 | | 0 | 0 | |
| RS.Guardians | 740 | 626 | 626 | 617 | 626 | 0 | 0 | 0 | 0 | | | | | | | templates |
| RS.SerpentKit / PvpKit | 16 / 16 | 16 / 16 | 16/16 | 16/15 | 16/0 | | | | | | | | | | | |
| SoundService | 76 | | | | | | | | | | | | | | | 72 Sounds |
Client-only (not on server): GuardianLooks (4379 inst, 3425 parts), Terrain labels (1059), Station SurfaceGui content (+560), CoinBoard content (+728), guardian bodies' extras (+528), Bays (+10).
Unique assets on client (workspace+RS+PlayerGui+SoundService+Lighting+PlayerScripts): meshes 714, textures/images 44 (3 builtin), sounds 44 (8 builtin), animations 30.

PlayerGui: 2996 descendants total.
| Gui | desc | enabled | top-level visible/hidden |
|---|---|---|---|
| ShopUi | 603 | on | 0/1 |
| IndexUi | 526 | on | 0/1 |
| Hud | 395 | on | 2/2 |
| BayUi | 358 | on | 1/2 |
| QuestUi | 295 | on | 0/1 |
| StoreUi | 272 | on | 0/1 |
| LoginGiftUi | 252 | on | 0/1 |
| CommunityUi | 67 | on | 0/1 |
| TerminalScreen x3 (SurfaceGui) | 43/35/35 | on | |
| EventBanner | 32 | on | 1/1 |
| GrabPrompt (BillboardGui) | 25 | off | |
| Bench | 12 | on | |
| EventPin* x3, HomeBeacon, TutorialPin | 5 each | off (TutorialPin on) | |

SurfaceGuis (all SizingMode=PixelsPerStud):
| Name | count | PixelsPerStud | MaxDistance | desc each |
|---|---|---|---|---|
| RingBanner (Station Screen1-8 + InnerScreen1-8) | 16 | 18 | 800 | 34 |
| CoinBoard (Panel) | 4 | 20 | 1000 | 181 |
| KioskSign (Badge/Holo/Plate) | 12 | 40 | 300 | 1 |
| TerminalScreen (in PlayerGui) | 3 | 100 | 80 | 35-43 |
| OwnerBoard Front/Back | 2 | 50 | 120 | 2 |

Distance bands of client BaseParts from the player (player on own island at (339,3,-2)); bands 0-250 / 250-500 / 500-1000 / 1000-2000 / 2000-4096 / >4096:
| Category | counts |
|---|---|
| guardians (looks + bodies) | 0 / 33 / 586 / 1632 / 1570 / 0 |
| asteroids | 0 / 2 / 39 / 226 / 549 / 0 |
| nests | 0 / 7 / 117 / 369 / 508 / 0 |
| landmarks | 0 / 0 / 52 / 688 / 57 / 0 |
| scrap | 0 / 11 / 117 / 64 / 0 / 0 |
| islands/bays | 269 / 18 / 38 / 0 / 0 / 0 |
| station | 2 / 100 / 65 / 0 / 0 / 0 |
| character | 23 / 0 ... |
| pets | 0 (no pets yet) |

## Sampler and views
Sampler (client, kept in `_G.M` across calls; full source at the end of this file): 45 settle frames, then 180 frames on `RenderStepped:Wait()`; averages (and max where written a/b) of Stats properties. All Stats time properties are in seconds; shown here in ms.
Format: `dt` = RenderStepped delta avg/max; `ft` FrameTime avg/max; `cpu` RenderCPUFrameTime; `gpu` RenderGPUFrameTime; `hb` HeartbeatTime; `phys` PhysicsStepTime; `draw` SceneDrawcallCount avg/max; `tri` SceneTriangleCount; `shDraw/shTri` shadows; `ui2d/ui3d` drawcalls/triangles; `prim` PrimitivesCount; `moving` MovingPrimitivesCount; `inst` InstanceCount (whole Studio process incl. Edit DM — not useful); `rx/physRx` DataReceiveKbps / PhysicsReceiveKbps; `mem` GetTotalMemoryUsageMb.
IMPORTANT caveats (measured): Studio renders capped at 60 fps (dt ≈ 16.66 ms in every view), so FrameTime is vsync-bound — compare `cpu`/`gpu`. Client `DataReceiveKbps` and `PhysicsReceiveKbps` read 0.0 in Studio Play (same process), so G cannot be measured with Stats. Memory (`GetTotalMemoryUsageMb` ≈ 4950 MB and every `GetMemoryUsageMbForTag`) returns the SAME numbers from the Client and the Server data model = the whole Studio process, not one client.
Views (positions from the live game):
- V1: player's default camera (CameraType Custom) on own island; character at (339, 3, -2), Island1 platform centre (398.5, -2, 0).
- V2: fixed, ~40 studs from the pet places (defined in D).
- V3: fixed at the station platform edge (50, 6, 0), eye height, looking at (0, 22, 0): coin board (62×62×62 box at the centre, y 4–66) and kiosks (radius 36). The board occupies the platform centre, so the camera cannot stand at the exact centre.
- V4: fixed at (0, 400, 0), looking +X and 30° down.
- V5: fixed 60 studs from the guardian nearest radius 3000 (guardian at (-1138, -175, -2756), r≈2987) toward the station, +20 up, looking at (0,0,0).
- V6 (section K), V2/V120/V250 (section D).
Measurement note: after Studio was unfocused (15 fps), draw counts stayed low for several seconds after refocus (V4 293 instead of 864). The sampler was changed to settle until SceneDrawcallCount is unchanged for 60 frames (cap 600) before sampling; all rows from E3 on use it. Earlier fixed-view rows were re-checked and matched (V1 678, V3 699, V4 864).

## C. Baseline frames (measured, no bench, 0 pets)
| View | cpu ms avg/max | gpu ms avg/max | hb ms | phys ms | draw | tri | shDraw | shTri | ui2d draw | moving prims |
|---|---|---|---|---|---|---|---|---|---|---|
| V1 | 3.88 / 5.31 | 4.15 / 6.44 | 0.17 | 2.92 | 866 | 249k | 34 | 35k | 82 | 105 |
| V3 | 3.80 / 5.34 | 3.93 / 6.15 | 0.20 | 2.61 | 700 | 203k | 33 | 18k | 82 | 105 |
| V4 | 3.67 / 8.53 | 4.19 / 7.65 | 0.23 | 2.83 | 864 | 282k | 13 | 10k | 82 | 105 |
| V5 | 4.44 / 5.41 | 2.15 / 4.98 | 0.19 | 2.59 | 1507 | 665k | 0 | 0 | 83 | 154 |
PrimitivesCount 7803 in all views. FrameTime avg 16.66–16.69 ms everywhere (vsync cap).
Re-run a few minutes later (with auto-quality reading `Stats.FrameRateManager.AverageQualityLevel` = Q): V3 cpu 3.45 gpu 1.70 draw 700 tri 203k shDraw 31 (Q 16.8); V4 cpu 3.35 gpu 1.50 draw 864 tri 282k shDraw 12 (Q 16.8, repeat identical); V5 cpu 4.48 gpu 1.49 draw 1507 tri 665k shDraw 0 (Q 16.9). Fixed views reproduce draw/tri exactly; GPU ms varies run to run (desktop GPU clocking: 4.2 → 1.5 ms for the same V4) — compare only within one call (A/B/A).
V1 is NOT stable across calls (player camera angle after MCP resets): 866 draws at first, later 678 draws / 193k tri / shDraw 27 (Q 16.6, three repeats identical).
Extra findings: Studio quality is auto (`FrameRateManager.AutoQuality` = true, AverageQualityLevel 16.4–17.2 out of 21, AverageSwitches 34) — the measuring machine renders near-max quality, a phone will be far lower. `Stats.RenderBreakdown` items did not update (stale), not used.
Throttling trap: when Studio lost window focus, it rendered at 15 fps (dt 66.7 ms) and draw counts dropped (V6 36 draws instead of 111). Fixed by clicking Studio's title bar; those samples were discarded and repeated. Every sample row carries `dt` so a throttled sample is visible.

Memory by tag (process-wide, see caveat): LuaHeap 845, Internal 2207, Script 281, Instances 128.5, BaseParts 104.8, GraphicsTexture 87.9, Gui 42.7, Signals 20.5, GraphicsParticles 15.3, Sounds 14.2, GraphicsParts 13.2, GraphicsMeshParts 10.1, Animation 6.6, GraphicsTextureCharacter 3.9, GraphicsSpatialHash 1.7, others 0. Total 4950 MB.

## K. Transparent haze and big see-through parts (measured)
Red Nebula haze: `World.Landmarks.Haze#` = 75 Parts, ForceField, Transparency 0.88, sizes 203–445 studs (sphere), centre radius 1877–2370 from the station centre, CastShadow false.
V6: camera at (2001, 25.8, -914) (r = 2200, height of the haze nearest r=2200), looking along the ring tangent. Camera is inside 1 haze ball, 6 hazes within 600 studs.
| V6 | cpu | gpu | draw | tri |
|---|---|---|---|---|
| shown | 2.38 | 0.57 | 111 | 51k |
| hazes Transparency=1 | 2.39 | 0.25 | 88 | 41k |
| restored | 2.39 | 0.51 | 115 | 52k |
Big see-through parts in workspace (max dimension > 100 studs and 0<T<1 or ForceField/Glass): 87 = 75 Haze (ForceField T0.88) + 9 Dome (8 island domes 285 studs + station dome 180, ForceField T0.75) + Boundary (ForceField T0.90, Size 2048³) + StationBorder Shell (ForceField T0.93, 1162) + BlackHoleRim (Neon T0.50, 450).
| View | cpu | gpu | draw | tri | shDraw |
|---|---|---|---|---|---|
| V4 all shown | 3.40 | 1.49 | 864 | 282k | 12 |
| V4 all 87 hidden (T=1) | 3.35 | 1.17 | 805 | 253k | 12 |
| V4 only the 12 non-haze hidden | 3.32 | 1.30 | 853 | 275k | 12 |
| V4 restored | 3.35 | 1.46 | 864 | 282k | 12 |
| V1 8+1 domes hidden | 3.40 | 1.73 | 676 | 192k | 27 |
| V1 shown | 3.90 | 1.79 | 678 | 193k | 27 |
So at V4: hazes ≈ 48 draws / 22k tri, other 12 big shells ≈ 11 draws / 7k tri; GPU −0.3 ms with all hidden (desktop GPU).

## L. Ring banner and coin board SurfaceGuis at V3 (measured)
16 `RingBanner` SurfaceGuis (PixelsPerStud 18, MaxDistance 800, 34 desc each), 4 CoinBoard SurfaceGuis (PPS 20, MaxDistance 1000, 181 desc each).
| V3 | cpu | gpu | draw | tri |
|---|---|---|---|---|
| all on (a) | 3.47 | 1.74 | 700 | 203k |
| RingBanner ×16 Enabled=false | 3.39 | 1.72 | 680 | 204k |
| on again (b) | 3.45 | 1.72 | 699 | 203k |
| CoinBoard ×4 Enabled=false | 3.43 | 1.66 | 696 | 203k |
| both off | 3.37 | 1.65 | 680 | 203k |
| on again (c) | 3.46 | 1.74 | 700 | 203k |
UI3D drawcall/triangle counters stay 0 with SurfaceGuis on screen (SurfaceGui draws appear in SceneDrawcallCount). Banners ≈ 20 draws; board ≈ 4 draws; cpu differences ≤ 0.1 ms (within noise). Script cost of the banner tween not separable here.
`Stats.PerformanceStats` (client, at that moment): CPU 12.2 ms, GPU 2.67 ms, NetworkReceived 2.92 KB/s, NetworkSent 4.88 KB/s, Ping 0.8 ms, Memory 5.0 GB.

## M. Far world — asteroids (measured)
`World.Asteroids` (816 MeshParts, 13 unique meshes, 700 CastShadow) parented to ReplicatedStorage on the client, then back.
| | V4 cpu | V4 gpu | V4 draw | V4 tri | V1 cpu | V1 gpu | V1 draw | V1 tri | V1 shDraw |
|---|---|---|---|---|---|---|---|---|---|
| shown | 3.34 | 1.53 | 864 | 282k | 3.40 | 1.76 | 678 | 193k | 28 |
| asteroids away | 3.17 | 1.41 | 777 | 171k | 3.26 | 1.73 | 627 | 142k | 28 |
| restored | 3.33 | 1.50 | 864 | 282k | 3.50 | 1.81 | 678 | 193k | 28 |
Asteroids ≈ 87 draws / 111k tri at V4, 51 draws / 51k tri at V1; no change in shadow draws. `PrimitivesCount` did not change (7803) — that counter does not follow client reparenting.

## E. Guardians (measured)
E1. Client: 132 guardian bodies in `World.Guardians` (each 3 Parts, unanchored; server: Model + 3 Part + LinearVelocity + AlignOrientation + Attachment + 2 WeldConstraint; client adds BillboardGui label etc., 1716 vs 1188 inst). 132 look models in `workspace.GuardianLooks`: 3293 MeshParts + 132 Parts + 756 Attachments + 66 ParticleEmitters (all disabled); 617 unique MeshIds; all CastShadow=false; 529 Glass + 529 semi-transparent parts; 755 Neon; RenderFidelity Automatic, CollisionFidelity Box.
Parts per look model: 17×39, 18×13, 19×6, 22×5, 26×7, 28×5, 30×4, 32×11, 33×5, 34×4, 35×9, 36×9, 38×15 (models × count) — average ≈ 25 MeshParts.
Distance from the player (on own island): looks / bodies within 300 / 1000 / 2000 studs = 0 / 17 / 67 (both). All 132 exist on the client at once (whole map streamed).
E2. `workspace.GuardianLooks` parented to ReplicatedStorage on the client, then back (restored: 132 children, parent Workspace).
| View | state | cpu | gpu | draw | tri | shDraw | moving prims |
|---|---|---|---|---|---|---|---|
| V1 | shown | 3.40 | 1.73 | 678 | 193k | 28 | 105 |
| V1 | looks away | 3.22 | 1.68 | 234 | 190k | 32 | 105 |
| V4 | shown | 3.38 | 1.48 | 864 | 282k | 12 | 105 |
| V4 | looks away | 3.06 | 1.42 | 216 | 231k | 12 | 105 |
| V5 | shown | 4.45 | 1.50 | 1507 | 665k | 0 | 154 |
| V5 | looks away | 3.85 | 1.44 | 450 | 605k | 0 | 105 |
| V5 | restored | 4.66 | 1.27 | 1507 | 665k | 0 | 154 |
Guardian looks = 444 draws at V1 (65 % of the scene draws), 648 at V4 (75 %), 1057 at V5 (70 %); triangles only 3k / 51k / 60k. Render CPU −0.2 / −0.3 / −0.6 ms (desktop).
E3. Bench guardians (fired via `Remotes.BenchGuardians.Fire("Bench")` from client execute_luau — `require` of the client `Remotes` module DOES work from the MCP client thread; a computer-use click on the button was interrupted, so remotes were used instead). Looks 132 → 174 (42 within 300 studs: 889 parts, 28 emitters, 0 enabled). Server bodies unchanged at 132 (bench guardians have no server body).
| | cpu | gpu | draw | tri | shDraw | prim | moving prims |
|---|---|---|---|---|---|---|---|
| V1 bench on | 4.42 | 1.79 | 746 | 283k | 28 | 8818 | 994 |
| V1 after "Off" | 3.41 | 1.79 | 678 | 193k | 28 | 7803 | 105 |
| V4 bench on | 4.12 | 1.41 | 1130 | 389k | 12 | 8818 | 105 |
| V4 no bench (same session) | 3.37 | 1.42 | 864 | 282k | 12 | 7803 | 105 |
42 benched guardians: +1015 primitives, +889 client MovingPrimitives at V1 (bench guardians are animated client-side), render CPU +1.0 ms at V1.
## F. Server (measured, Play running, 1 player, no bench, 5 s on Heartbeat = 301 frames)
- Server-side `Stats.HeartbeatTime` and `PhysicsStepTime` read 0.000 in Studio, `PerformanceStats` CPU/GPU/Network = empty/N/A — server frame time NOT measurable this way in Studio.
- PrimitivesCount 25244 (server DM; client 7803 — server number likely includes more than workspace, not explained), MovingPrimitivesCount 23 (the character), InstanceCount 89492 (process), ContactsCount 0.
- DataSendKbps 0.586 avg / 0.778 max; DataReceiveKbps 0; PhysicsSend/Receive 0.
- Guardians: 132 bodies, all State="Sleep". Each body = Body Part + 2 Eye Parts (unanchored, welded), LinearVelocity (Enabled, MaxForce 1e6, VectorVelocity ≈ (0, -0.002, -0.0017)), AlignOrientation, Attachment. Over 5 s: 0 of 132 moved (max displacement 0, max rotation 0), 0 with |AssemblyLinearVelocity| > 0.05. No jitter seen while asleep.
- Unanchored: 628 parts in 265 assemblies = 132 guardians + 132 nest eggs (unanchored parts welded to an Anchored root `Egg`, so not simulated) + 1 character.

## D. Pets — 30-pet bench (fired via `Remotes.Bench.Fire(true)` from client execute_luau)
30 Models tagged `Alien` (BayConfig.ALIEN_TAG) appeared in `World.Bays.Bay1.Contents` within ~0.3 s; census taken 5 s later. Pet pivots span x 371–456, z −61…61, y 1.7–13 (centre (413.8, 7.3, 0)); island centre (398.5, 0).
Census of the 30 pets on the CLIENT (descendants of the tagged models):
- 3312 instances (per pet 45–190); 1096 BaseParts = 919 MeshParts + 177 Parts; 673 unique MeshIds among 919 MeshParts; RenderFidelity Automatic 919; CollisionFidelity Box 919.
- CastShadow=true: 477 parts. Semi-transparent 165, Neon 489, Glass 119.
- PointLight 30 (9 enabled at measurement time, sum of enabled Range 82.7, 0 with Shadows).
- ParticleEmitter 191 (90 enabled, sum Rate 671/s, estimated live particles Rate×Lifetime.Max = 1140 — estimate).
- Trail 337 (113 enabled), Beam 100 (100 enabled), Attachment 882.
- BillboardGui 47 (47 enabled), SurfaceGui 60 (60 enabled), SurfaceAppearance 25; UI objects: 154 ImageLabel, 90 Frame, 90 UIStroke, 60 TextLabel, 60 UICorner, 60 UIListLayout, 30 UIPadding.
- SurfaceGuis = exactly 2 per pet: `Rune` (SizingMode FixedSize, CanvasSize 1024×1024) and `Glow` (FixedSize, CanvasSize 256×256), Face Top, LightInfluence 0, MaxDistance 0 (= no distance limit), Enabled, 1 child each; PixelsPerStud reads 24–119 (ignored in FixedSize mode).
SERVER for the same 30 pets: 1484 instances = 919 MeshParts + 30 Parts + 510 Attachments + 25 SurfaceAppearance. So the client adds 1828 instances inside the pets (all effects, lights, guis, +147 Parts, +372 Attachments).
Totals: client `World.Bays` 300 → 3723 descendants; server 290 → 1885. Client PlayerGui 2996 → 3830 descendants (+834 with the bench) — the growth is in `BayUi` (358 → 1198, the bay window's pet list, window hidden); TerminalScreen 113 total.

V2 = fixed camera at (496, 20, 0) looking at (413.8, 5, 0): 40 studs beyond the outermost pets (x 456), inside the island dome, all 30 pets in view.
Frames with the bench (measured):
| View | cpu | gpu | draw | tri | shDraw | shTri | moving prims | prim |
|---|---|---|---|---|---|---|---|---|
| V1 no bench (same session, before) | 3.41 | 1.79 | 678 | 193k | 28 | 33k | 105 | 7803 |
| V1 bench | 5.32 | 3.40 | 1722 | 1231k | 995 | 477k | 1071 | 8953 |
| V2 bench | 5.98 | 4.38 | 1965 | 1381k | 997 | 454k | 1071 | 8953 |
30 pets at V1: +1044 scene draws, +1038k scene tri, +967 shadow draws, +444k shadow tri, render CPU +1.9 ms, GPU +1.6 ms (desktop); +1150 primitives, +966 moving primitives.

Experiments at V2 (each A/B/A in one call; Q 18.1–18.6):
| Exp | state | cpu | gpu | draw | tri | shDraw | shTri |
|---|---|---|---|---|---|---|---|
| D1 | bench | 5.98 | 4.38 | 1965 | 1381k | 997 | 454k |
| D1 | 477 pet parts CastShadow=false | 6.01 | 2.71 | 1964 | 1382k | 26 | 19k |
| D1 | restored | 6.01 | 4.40 | 1965 | 1381k | 995 | 452k |
| D2 | bench | 6.22 | 4.61 | 2033 | 1384k | 997 | 453k |
| D2 | Lighting.GlobalShadows=false | 5.52 | 2.41 | 2034 | 1384k | 0 | 0 |
| D2 | restored | 6.22 | 4.62 | 2034 | 1384k | 997 | 455k |
| D3 | 30 pet PointLights off (13 were on at V2) | 6.23 | 4.53 | 2034 | 1384k | 997 | 452k |
| D3 | restored | 6.29 | 4.61 | 2032 | 1384k | 997 | 455k |
| D4 | bench | 6.29 | 4.54 | 2034 | 1384k | 996 | 453k |
| D4 | all pet ParticleEmitter/Trail/Beam Enabled=false | 5.21 | 3.56 | 1612 | 1375k | 997 | 455k |
| D4 | restored (Enabled set back by script) | 6.30 | 4.61 | 2033 | 1385k | 997 | 453k |
| D5 | 60 pet SurfaceGuis (Rune+Glow) Enabled=false | 6.18 | 4.60 | 1973 | 1383k | 995 | 452k |
| D5 | restored | 6.29 | 4.65 | 2035 | 1384k | 996 | 454k |
Shares at V2 (measured differences): pet shadows ≈ 970 shadow draws / 435k shadow tri, GPU −1.7 ms, CPU ≈ 0 (D1); all shadows off: GPU −2.2 ms, CPU −0.7 ms (D2); pet lights ≈ 0 (D3); pet effects ≈ 421 draws, CPU −1.1 ms, GPU −1.0 ms (D4); pet SurfaceGuis ≈ 61 draws (≈ 2 per pet), CPU −0.1 ms, GPU ≈ 0 (D5).
Note: the number of enabled pet effects depends on the camera (AlienMotionController detail levels): at V2 enabled pe 120 / trail 197 / beam 100 / light 13 / SurfaceGui 60 (census earlier from the player camera: pe 90, trail 113, light 9).

D6 — distance (same session, bench on; camera on the +X line through the pets' centre, looking at it):
| View | distance to pets centre | cpu | gpu | draw | tri | shDraw | shTri | moving prims | enabled pe/trail/beam/light/sg |
|---|---|---|---|---|---|---|---|---|---|
| V2 | ~85 (40 to nearest) | 6.24 | 4.65 | 2034 | 1384k | 995 | 452k | 1071 | 120/197/100/13/60 |
| V120 | 120 (+25 up) | 5.73 | 3.86 | 1868 | 1383k | 834 | 330k | 1071 | 65/85/100/2/60 |
| V250 | 250 (+45 up, outside the dome) | 4.44 | 1.55 | 1642 | 1110k | 26 | 21k | 171 | 0/0/0/0/60 |
At 250 studs pets stop moving (moving prims 1071 → 171) and all effects are off, but still 1642 draws / 1110k tri; SurfaceGuis stay enabled (MaxDistance 0). The same three views without pets are in section I.

## G. Network at rest (client, measured from `Stats.PerformanceStats.NetworkReceived/Sent` and `Stats.Network.ServerStatsItem`, 20 polls × 0.5 s at V1)
`Stats.DataReceiveKbps` / `PhysicsReceiveKbps` read 0 on the client in Studio, so these other counters were used (units KB/s as shown by the Dev Console).
| State | NetworkReceived avg / max KB/s | NetworkSent avg KB/s | Received packets/s | ISR packets/s | totalBytesReceived delta B/s |
|---|---|---|---|---|---|
| no bench, no event | 3.10 / 3.50 | 4.82 | 87.5 (instant) | 40.8 (instant) | — |
| 30-pet bench on | 3.37 / 3.93 | 4.89 | 89.7 | 39.3 | 8368 |
| no bench, Star Serpent event active (+4 meteor craters) | 5.90 / 6.31 | 4.79 | 86.5 | 39.2 | 11335 |
Other client network facts: Received Stream Data CurrentRadius 4098, NumReplicationFoci 1, Received ISR packet size ≈ 72 B, Send kBps ≈ 4.7, Data Ping ≈ 34 ms (local), Studio session totals 9.35 MB received / 12.4 MB sent in 940 s.

## H. Script profiler (measured afterwards in a fresh Play session, after the coordinator confirmed computer-use access)
Setup: new Play, 30-pet bench via `Remotes.Bench.Fire(true)`, player's default camera on own island (pets in view, effects up), F9 → ScriptProfiler, ~10.6 s recordings (session duration 00:00:10.6). Values are the profiler's "Total" column in ms over the whole recording (divide by ~10.6 for ms/s, by ~636 frames for ms/frame at 60 fps). Read from screen zooms; small digits may be off by one.
Client (callgraph): root 1391.1 ms total = RenderStepped 1124.9 → Main → `step` (AlienMotionController.step) 919.1 [WorldRoot:BulkMoveTo 491.8 self, `move` 405.9, `detail` 7.8, `glide` 2.9, Camera.CFrame 1.5], `update` 79.7, another `step` 68.4, anonymous 36.5 / 9.4, `step` 6.3, `update` 3.4; Heartbeat 130.5; RunService.BindToRenderStep 60.3; delayedThreads 17.6; callCallback 13.2; WaitingScripts 8.8; StatsReceived 7.1; OnClientEvent 5.7; Changed 5.1; PreAnimation 4.7; Move 3.8; deferredThreads 3.3; CFrameChanged 3.1; Stepped 3.0.
Client top functions (Functions view, Total ms): Main 1204.1, step 919.1, WorldRoot.BulkMoveTo 491.8, move 405.9, pose 365.3, BasePart.Size ~13x (digits hidden), update 79.6, step 68.4, step 67.4, target ~37.8, PlayerScriptsLoader ~55.8, nestOf 51.9, (CorePackages) SchedulerHostConfig.default 47.7, ReactFiberWorkLoop 47.6, update 41.9, Instance.GetAttribute 37.4, `PlayerScripts.Client.Controllers.Co…Controller:80` 36.5, PVInstance.PivotTo 36.5, (CorePackages) Rodux Store 30.7.
→ AlienMotionController.step ≈ 919 ms / 10.6 s ≈ 87 ms/s ≈ 1.4 ms per frame on this desktop CPU, of which BulkMoveTo ≈ 0.77 ms/frame and move/pose ≈ 0.64 ms/frame.
Server (10.6 s, same bench): root 55.3 ms total = callCallback 29.5 + Heartbeat 25.8. Top functions: Main 32.2, step 21.7, tick 15.6, tickGuardians 15.6, RunAnimate.Server 11.5, character Animate:1296 ~11.5, stepAnimate ~11.5, step 10.5, updateToolAnimations 7.5, stopToolAnimations 7.5, ServerAuthorityServer 7.5, PlayerModule.ControlModule:296 7.5, BasePart.Position 6.3, ProcessInputs 5.9, Instance.GetAttribute 4.2, Remotes 3.0, SendEvents <native> 3.0, match 3.0, Instance.GetAttributes 3.0. Server script time ≈ 5.2 ms/s total (one player).
Teardown of this session: bench cleared (0 tagged), Play stopped (console closed with the session), camera never rebound in this session, place not saved.

## I. Pet motion's share (LAST pet experiment; not undone until "/bench clear")
At V2 with the bench, then `CollectionService:RemoveTag(pet, "Alien")` on the client for all 30 pets (models stay; effects stay enabled: pe 120 / trail 197 / beam 100; BillboardGuis inside pets 47 → 17; SurfaceGuis 60 stay).
| V2 | cpu | gpu | draw | tri | shDraw | shTri | moving prims |
|---|---|---|---|---|---|---|---|
| tagged (moving) | 6.41 | 4.58 | 2034 | 1384k | 998 | 455k | 1142 |
| untagged (static) | 5.11 | 2.78 | 1810 | 1382k | 19 | 18k | 176 |
| untagged, repeat | 5.12 | 2.81 | 1810 | 1382k | 19 | 18k | 176 |
Pet motion share at V2 ≈ render CPU 1.3 ms, GPU 1.8 ms, 224 scene draws (incl. 30 chip BillboardGuis gone), 979 shadow draws / 437k shadow tri. Static pets keep almost no shadow draw cost (19 shadow draws) although their 477 parts still have CastShadow=true.
Then `Remotes.Bench.Fire(false)` (bench cleared: Bays back to 300 desc) and the same views without any pet. CAVEAT: by then a meteor shower had left 4 craters (+4 guardians/looks, 136 total) and the Star Serpent event was active (`workspace.SerpentBody` 103 desc), so the no-pet rows include them (prim 8011, moving 176 vs 7803/105 earlier).
| View, no pets | cpu | gpu | draw | tri | shDraw |
|---|---|---|---|---|---|
| V2 | 3.99 | 1.95 | 850 | 339k | 19 |
| V120 | 4.01 | 1.96 | 883 | 347k | 19 |
| V250 | 4.07 | 1.82 | 955 | 360k | 23 |
| V1 | 3.96 | 1.95 | 803 | 313k | 37 |
So the 30 pets' cost by distance (bench row − no-pet row, measured): V2 +1184 draws / +1045k tri / +976 shadow draws / cpu +2.25 ms / gpu +2.7 ms; V120 +985 draws / +1036k tri / +815 shadow draws / cpu +1.7 / gpu +1.9; V250 +687 draws / +750k tri / +3 shadow draws / cpu +0.4 / gpu −0.3.

## J. Start of a session (measured, Studio asset cache warm → lower bound)
The MCP Client data model becomes reachable only after the client has loaded: in both restarts the first poll already had the whole world (workspace 12564–12565 descendants), the character and `PlayerGui.Hud`.
- Restart 1 (first restart after ~25 min of Play): first poll — ContentProvider.RequestQueueSize 128 (peak observed), GraphicsTexture 98.1 MB, GraphicsMeshParts 2.5 MB, PlayerGui 2996 desc; queue 128 for ~1.0 s, first 0 at +1.5 s, stayed 0 for 30 s; workspace descendants constant 12565; total memory 4877–4887 MB. ~35 s later (client `time()` = 46 s): GraphicsTexture 98.1, GraphicsMeshParts 10.2, PlayerGui 2996, queue 0.
- Restart 2: first poll at client `time()` = 7.43 s: queue 0 (peak 0 over 8 s), character yes, HUD yes, workspace 12564, GraphicsTexture 98.1, GraphicsMeshParts 10.2, PlayerGui 2996.
So in Studio the client is fully loaded (world, character, HUD) within ≤ 7.4 s of the client DM's start (bound set by when MCP could attach; earlier steps not observable). Seconds-to-character/HUD and queue drain before that cannot be measured from MCP. Asset counts that a cold phone must fetch: 714 unique meshes, 44 textures/images, 44 sounds, 30 animations (section B) + pets' 673 unique meshes when a bay holds 30 pets.


## Teardown (done)
- Camera given back with the RenderStep binding (CameraType Custom + CameraSubject = Humanoid) at the end of every sampling call.
- 30-pet bench cleared (Remotes.Bench.Fire(false)), guardian bench cleared (Remotes.BenchGuardians.Fire("Off"), looks back to 132). All client-local changes were undone in-call (CastShadow, GlobalShadows, lights, effects, SurfaceGuis, Transparency, folder parents) except I (pet tags), which ended with the bench clear and the Play stop.
- Play stopped (Studio state: Edit, only the Edit data model). rojo was never running (failed at start); nothing listens on port 34872 (checked). The place was NOT saved (no Ctrl+S, no save_place). No repository file was edited; no git command was run.

## Not measured / limits
- H (ScriptProfiler): done later with computer-use (section H); values read from screen.
- Server frame time: server-side Stats Heartbeat/Physics read 0 in Studio.
- Client DataReceiveKbps/PhysicsReceiveKbps: 0 in Studio; G uses PerformanceStats/Network items instead.
- Memory: process-wide (Studio), same numbers from Client and Server DMs.
- J: the MCP client thread attaches only after loading (≥ 7.4 s), so the start timeline before that is not visible; Studio's asset cache is warm.
- All ms are a desktop GPU/CPU at auto-quality ≈ 17–19 of 21, 2125×1176, vsync 60 fps.

## Snippets
### Sampler (client; stored in _G.M once, reused across calls — _G persists between MCP execute_luau calls on the client)
```lua
-- ===== SAMPLER (client) =====
local RS = game:GetService("RunService")
local S = game:GetService("Stats")
local lp = game.Players.LocalPlayer
local PROPS = {"FrameTime","RenderCPUFrameTime","RenderGPUFrameTime","HeartbeatTime","PhysicsStepTime","SceneDrawcallCount","SceneTriangleCount","ShadowsDrawcallCount","ShadowsTriangleCount","UI2DDrawcallCount","UI2DTriangleCount","UI3DDrawcallCount","UI3DTriangleCount","PrimitivesCount","MovingPrimitivesCount","InstanceCount","ContactsCount","DataReceiveKbps","PhysicsReceiveKbps"}
local function sample(frames)
	local sum, mx = {}, {}
	local dts, dtm = 0, 0
	for _ = 1, frames do
		local dt = RS.RenderStepped:Wait()
		dts += dt
		dtm = math.max(dtm, dt)
		for _, p in PROPS do
			local v = S[p]
			sum[p] = (sum[p] or 0) + v
			mx[p] = math.max(mx[p] or -math.huge, v)
		end
	end
	local a = {}
	for _, p in PROPS do a[p] = sum[p] / frames end
	return string.format(
		"dt=%.2f/%.2fms ft=%.2f/%.2f cpu=%.2f/%.2f gpu=%.2f/%.2f hb=%.2f phys=%.2f | draw=%.0f/%d tri=%.0fk | shDraw=%.0f shTri=%.0fk | ui2d=%.0f/%.0fk ui3d=%.0f/%.0fk | prim=%.0f moving=%.0f inst=%.0f contacts=%.0f | rx=%.1f physRx=%.1f | mem=%.0fMB",
		dts / frames * 1000, dtm * 1000, a.FrameTime * 1000, mx.FrameTime * 1000, a.RenderCPUFrameTime * 1000, mx.RenderCPUFrameTime * 1000,
		a.RenderGPUFrameTime * 1000, mx.RenderGPUFrameTime * 1000, a.HeartbeatTime * 1000, a.PhysicsStepTime * 1000,
		a.SceneDrawcallCount, mx.SceneDrawcallCount, a.SceneTriangleCount / 1000, a.ShadowsDrawcallCount, a.ShadowsTriangleCount / 1000,
		a.UI2DDrawcallCount, a.UI2DTriangleCount / 1000, a.UI3DDrawcallCount, a.UI3DTriangleCount / 1000,
		a.PrimitivesCount, a.MovingPrimitivesCount, a.InstanceCount, a.ContactsCount, a.DataReceiveKbps, a.PhysicsReceiveKbps,
		S:GetTotalMemoryUsageMb()
	)
end
local function bindCam(cf)
	RS:BindToRenderStep("MeasureCam", Enum.RenderPriority.Last.Value, function()
		local c = workspace.CurrentCamera
		c.CameraType = Enum.CameraType.Scriptable
		c.CFrame = cf
	end)
end
local function unbindCam()
	pcall(function() RS:UnbindFromRenderStep("MeasureCam") end)
end
local function restoreCam()
	unbindCam()
	RS:BindToRenderStep("RestoreCam", Enum.RenderPriority.Last.Value, function()
		local c = workspace.CurrentCamera
		c.CameraType = Enum.CameraType.Custom
		local h = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
		if h then c.CameraSubject = h end
	end)
	for _ = 1, 10 do RS.RenderStepped:Wait() end
	pcall(function() RS:UnbindFromRenderStep("RestoreCam") end)
end
-- run(view): view = CFrame or nil (player camera). Settles 45 frames, samples 180.
local function run(cf)
	if cf then bindCam(cf) else restoreCam() end
	for _ = 1, 45 do RS.RenderStepped:Wait() end
	local r = sample(180)
	return r
end
-- views from the live game
local function views()
	local V = {}
	local W = workspace.World
	-- the coin board fills the platform centre (62x62 studs, y 4-66), so V3 stands at the platform edge, eye height
	V.V3 = CFrame.lookAt(Vector3.new(50, 6, 0), Vector3.new(0, 22, 0))
	local d = math.rad(30)
	V.V4 = CFrame.lookAt(Vector3.new(0, 400, 0), Vector3.new(0, 400, 0) + Vector3.new(math.cos(d), -math.sin(d), 0))
	local best, bd = nil, math.huge
	for _, g in W.Guardians:GetChildren() do
		local r = g:GetPivot().Position.Magnitude
		if math.abs(r - 3000) < bd then bd = math.abs(r - 3000) best = g end
	end
	local gp = best:GetPivot().Position
	local toC = (-gp * Vector3.new(1, 0, 1)).Unit
	V.V5 = CFrame.lookAt(gp + toC * 60 + Vector3.new(0, 20, 0), Vector3.zero)
	V.V5guardian = gp
	return V
end
-- ===== END SAMPLER =====

_G.M = {sample = sample, run = run, restoreCam = restoreCam, views = views, bindCam = bindCam, unbindCam = unbindCam}
```
Later additions to _G.M (same session):
```lua
local S = game:GetService("Stats")
local RS = game:GetService("RunService")
local M = _G.M
M.sample0 = M.sample0 or M.sample
M.sample = function(n) return M.sample0(n) .. " | Q=" .. S.FrameRateManager.AverageQualityLevel:GetValueString() end
M.run = function(cf)
	if cf then M.bindCam(cf) else M.restoreCam() end
	for _ = 1, 45 do RS.RenderStepped:Wait() end
	local last, same = S.SceneDrawcallCount, 0
	for i = 1, 600 do RS.RenderStepped:Wait() local d = S.SceneDrawcallCount if d == last then same += 1 else same = 0 last = d end if same >= 60 then break end end
	return M.sample(180)
end
_G.V2 = CFrame.lookAt(Vector3.new(496, 20, 0), Vector3.new(413.8, 5, 0))
local c = Vector3.new(413.8, 5, 0)
_G.V120 = CFrame.lookAt(c + Vector3.new(120, 25, 0), c)
_G.V250 = CFrame.lookAt(c + Vector3.new(250, 45, 0), c)
-- V6
local camPos = Vector3.new(2001.26, 25.76, -913.77)
local V6 = CFrame.lookAt(camPos, camPos + Vector3.yAxis:Cross((camPos * Vector3.new(1,0,1)).Unit) * 100)
```
### Experiment pattern (example D1; others identical with a different toggle)
```lua
local M, CS = _G.M, game:GetService("CollectionService")
local o = {}
o.before = M.run(_G.V2)
local old = {}
for _, a in CS:GetTagged("Alien") do for _, d in a:GetDescendants() do if d:IsA("BasePart") and d.CastShadow then old[d] = true d.CastShadow = false end end end
o.after = M.run(_G.V2)
for p in old do p.CastShadow = true end
o.restored = M.run(_G.V2)
M.restoreCam()
return o
```
Toggles used: D2 Lighting.GlobalShadows=false; D3 pet PointLight.Enabled=false; D4 pet ParticleEmitter/Trail/Beam Enabled=false; D5 pet SurfaceGui.Enabled=false; E2 workspace.GuardianLooks.Parent = ReplicatedStorage; M World.Asteroids.Parent = ReplicatedStorage; K Haze/big parts Transparency = 1; L RingBanner/CoinBoard SurfaceGui Enabled=false; I CS:RemoveTag(pet, "Alien").
Benches: local R = require(game.Players.LocalPlayer.PlayerScripts.Client.Net.Remotes); R.Bench.Fire(true/false); R.BenchGuardians.Fire("Bench"/"Off").
### Network (G)
```lua
local S = game:GetService("Stats")
local item = S.Network.ServerStatsItem
local recv, sent = S.PerformanceStats.NetworkReceived, S.PerformanceStats.NetworkSent
-- 20 polls x 0.5 s: recv:GetValue(), sent:GetValue(), item["Received Packets"]:GetValue(), item["Received ISR Packets"]:GetValue(), item.Stats.totalBytesReceived:GetValue() delta
```
### Census function (B) — counts per root: see the session; key lines
```lua
for _, d in root:GetDescendants() do
	-- BasePart: CastShadow, 0<Transparency<1, Material Neon/Glass/ForceField, Anchored; MeshPart: MeshId set, RenderFidelity, CollisionFidelity
	-- Light (Enabled, Shadows), ParticleEmitter (Enabled, Rate, Rate*Lifetime.Max), Beam, Trail, BillboardGui (Enabled), SurfaceGui, Highlight, Decal, ProximityPrompt, Sound
end
```
