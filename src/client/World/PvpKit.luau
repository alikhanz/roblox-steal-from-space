--!strict
-- The PvP abilities' kit of meshes on this client (ReplicatedStorage.PvpKit, inserted into the
-- place by hand; assets/blender/pvp/pvp_kit.py; brief docs/design/screens/pvp-abilities.md):
-- copies of its pieces, each with where it sits from its group's speck. Groups: the hook
-- (HookOrigin: the point its claws close on, the shaft behind it along +Z, HookBack where the
-- cable meets it), the wrist launcher (LauncherOrigin: the hand, Muzzle ahead along -Z), the
-- bomb (BombOrigin: its centre) and a flat ring of radius 1 (RingOrigin).
--
-- Insertion turns the whole kit about Y. Offsets from a speck don't mind that, and the kit's own
-- front is measured once (HookBack must lie behind HookOrigin, +Z), so no direction is assumed.
-- Without the kit in the place, every piece is a greybox Part of the same size and spot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PvpLooks = require(ReplicatedStorage.Shared.Config.PvpLooks)

export type PieceName =
	"HookBody"
	| "HookGlow"
	| "ClawsOpen"
	| "ClawsClosed"
	| "LauncherBody"
	| "LauncherGlow"
	| "BombBody"
	| "BombGlow"
	| "BombLight"
	| "Ring"

export type PointName = "HookBack" | "Muzzle"

-- A copy to place: the part and where it sits from its group's speck.
export type Piece = {
	part: BasePart,
	offset: CFrame,
}

type Spot = { origin: string, offset: CFrame? }

local SPECKS: { [PieceName | PointName]: string } = {
	HookBody = "HookOrigin",
	HookGlow = "HookOrigin",
	ClawsOpen = "HookOrigin",
	ClawsClosed = "HookOrigin",
	HookBack = "HookOrigin",
	LauncherBody = "LauncherOrigin",
	LauncherGlow = "LauncherOrigin",
	Muzzle = "LauncherOrigin",
	BombBody = "BombOrigin",
	BombGlow = "BombOrigin",
	BombLight = "BombOrigin",
	Ring = "RingOrigin",
}

-- The greybox: shape, size and spot of each piece, as the kit has them (pvp_kit.py). Cylinders
-- lie along their X axis, so a turned spot points them where the piece points.
type Greybox = { shape: Enum.PartType, size: Vector3, offset: CFrame }
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)
local FLAT = CFrame.Angles(0, 0, math.pi / 2)
local GREYBOX: { [PieceName]: Greybox } = {
	HookBody = {
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(2.2, 0.4, 0.4),
		offset = CFrame.new(0, 0, 1.6) * ALONG_Z,
	},
	HookGlow = {
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.2, 0.6, 0.6),
		offset = CFrame.new(0, 0, 0.75) * ALONG_Z,
	},
	ClawsOpen = { shape = Enum.PartType.Ball, size = Vector3.one * 1.2, offset = CFrame.new() },
	ClawsClosed = { shape = Enum.PartType.Ball, size = Vector3.one * 0.8, offset = CFrame.new() },
	LauncherBody = {
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1, 0.7, 0.7),
		offset = CFrame.new(0, 0, -0.1) * ALONG_Z,
	},
	LauncherGlow = {
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.15, 0.8, 0.8),
		offset = CFrame.new(0, 0, -0.65) * ALONG_Z,
	},
	BombBody = { shape = Enum.PartType.Ball, size = Vector3.one * 2.2, offset = CFrame.new() },
	BombGlow = { shape = Enum.PartType.Cylinder, size = Vector3.new(0.15, 2.3, 2.3), offset = FLAT },
	BombLight = { shape = Enum.PartType.Ball, size = Vector3.one * 0.45, offset = CFrame.new(0, 0.55, -0.85) },
	Ring = { shape = Enum.PartType.Cylinder, size = Vector3.new(0.09, 2.09, 2.09), offset = FLAT },
}
local GREYBOX_POINTS: { [PointName]: CFrame } = {
	HookBack = CFrame.new(0, 0, 2.6),
	Muzzle = CFrame.new(0, 0, -0.75),
}
-- The kit's ring: radius 1 round its Y axis.
local RING_RADIUS = 1

local PvpKit = {}

local measured: { [string]: Spot }? = nil
local isGreybox = false

local function mesh(kit: Instance, name: string): BasePart?
	local part = kit:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

-- Reads the kit once: every piece's and point's offset from its speck, turned so the kit's front
-- is -Z. False (with one warning) when the place has no complete kit.
local function measure(): boolean
	if measured then
		return true
	end
	if isGreybox then
		return false
	end
	local kit = ReplicatedStorage:FindFirstChild(PvpLooks.KIT_FOLDER_NAME)
	local spots: { [string]: Spot } = {}
	local hookOrigin = kit and mesh(kit, "HookOrigin")
	local hookBack = kit and mesh(kit, "HookBack")
	if not kit or not hookOrigin or not hookBack then
		isGreybox = true
		warn(
			`[PvpKit] No complete ReplicatedStorage.{PvpLooks.KIT_FOLDER_NAME}; the harpoon and the bomb stand in greybox`
		)
		return false
	end
	-- Turn about Y that puts the hook's back behind it (+Z).
	local back = hookOrigin.CFrame:PointToObjectSpace(hookBack.Position)
	local front = CFrame.Angles(0, -math.atan2(back.X, back.Z), 0)
	for name, origin in SPECKS do
		local speck = mesh(kit, origin)
		local part = mesh(kit, name)
		if not speck or not part then
			isGreybox = true
			warn(`[PvpKit] ReplicatedStorage.{PvpLooks.KIT_FOLDER_NAME} lacks {name} or {origin}; greybox`)
			return false
		end
		spots[name] = { origin = origin, offset = front * speck.CFrame:ToObjectSpace(part.CFrame) }
	end
	measured = spots
	return true
end

local function ghost(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

-- A fresh copy of the piece `name`, parented to `parent`, and where it sits from its speck.
-- `glow`: the colour of a Neon piece (nil: a body piece, coloured by its vertices).
function PvpKit.piece(name: PieceName, parent: Instance, glow: Color3?): Piece
	local part: BasePart
	local offset: CFrame
	if measure() then
		local kit = ReplicatedStorage:FindFirstChild(PvpLooks.KIT_FOLDER_NAME) :: Instance
		part = (mesh(kit, name) :: BasePart):Clone()
		offset = (measured :: { [string]: Spot })[name].offset :: CFrame
	else
		local look = GREYBOX[name]
		local greybox = Instance.new("Part")
		greybox.Shape = look.shape
		greybox.Size = look.size
		greybox.Color = Color3.fromRGB(200, 205, 220)
		greybox.Material = Enum.Material.SmoothPlastic
		part = greybox
		offset = look.offset
	end
	ghost(part)
	if glow then
		part.Material = Enum.Material.Neon
		part.Color = glow
	end
	part.Name = name
	part.Parent = parent
	return { part = part, offset = offset }
end

-- Where the point `name` sits from its group's speck.
function PvpKit.point(name: PointName): CFrame
	if measure() then
		return (measured :: { [string]: Spot })[name].offset :: CFrame
	end
	return GREYBOX_POINTS[name]
end

-- Sizes a ring piece to `radius` (of its middle line) and `thickness` across its plane, studs.
function PvpKit.sizeRing(ring: Piece, radius: number, thickness: number)
	local part = ring.part
	if part:IsA("MeshPart") then
		local source = part.MeshSize
		local scale = radius / RING_RADIUS
		part.Size = Vector3.new(source.X * scale, thickness, source.Z * scale)
	else
		part.Size = Vector3.new(thickness, radius * 2, radius * 2)
	end
end

return table.freeze(PvpKit)
