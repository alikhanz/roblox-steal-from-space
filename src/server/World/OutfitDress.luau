--!strict
-- Puts a low-poly pet's outfit (its record's, decisions 118, 121; Domain/AlienOutfit) on its body: each piece is a
-- model of the kit (ServerStorage.Aliens._Outfit, lune/aliens.luau) cloned onto the body's point for
-- its slot (attachments `anchor<Slot>`, their Scale) and painted in the tier's colours. Its parts join
-- the pet as if Blender had made them (`<role>_<n>`, a Paint code), so AlienDress paints them and the
-- client moves them like any pet's: wings flap on their hinge, shards and rings orbit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)

local OutfitDress = {}

local OUTFIT_ATTRIBUTE = AlienLooks.OUTFIT_PART_ATTRIBUTE

local GOLD_BODY = "S255,190,45,0,0.35,Gold"
local GOLD = "255,200,70"
local FIRE = "255,173,80"
-- The paint sources whose colour is the tier's (the kit is exported in tier 2's blue).
local TIER_SOURCES = {
	TierBody = true,
	TierGlow = true,
	TierGlass = true,
	TierDeep = true,
	TierLight = true,
	EnergyWing = true,
	Jet = true,
}
-- The tier's darker and lighter tones (a wing's bones and its top feathers), from its colour.
local DEEP, LIGHT = 0.45, 0.5
-- Back pieces: the kit's piece, and its size against the wing span of its slot.
local WINGS: { [string]: { piece: string, size: number } } = {
	butterfly = { piece = "wingButterfly", size = 1 },
	angel = { piece = "wingAngel", size = 1 },
	dragon = { piece = "wingDragon", size = 1 },
	crystal = { piece = "wingCrystal", size = 1 },
	fairy = { piece = "wingFairy", size = 1 },
	angelSmall = { piece = "wingAngel", size = 0.6 },
	butterflySmall = { piece = "wingButterfly", size = 0.6 },
}
-- An epic's wings a little smaller than a legendary's (robo.py).
local EPIC_WINGS = 0.85
-- A piece's slot on the body (head pieces sit on the head, the crown where the crown goes).
local SLOT_OF: { [string]: string } = {
	horns = "Head",
	crest = "Head",
	feelers = "Head",
	crown = "Crown",
	halo = "Halo",
	shards = "Aura",
	rings = "Rings",
	star = "Star",
	jetpack = "Pack",
}
-- Little planets circling an Event Horizon pet from rare up (robo.py, flair_horizon).
local PLANET_ANGLES = { 2.0, 4.6, 7.2 }

type Point = { at: Vector3, scale: number, holder: BasePart }

-- `code` repainted for the tier: the tier's colour, gold on a legendary, fire on a meteor.
local function repaint(code: string, tier: number, meteor: boolean, tierColor: string): string
	local letter, transparency, reflectance, source = string.match(code, "^(%a)%d+,%d+,%d+,([%d%.]+),([%d%.]+),(%a*)$")
	if not letter or not source or not TIER_SOURCES[source] then
		return code
	end
	if tier == 4 and not meteor and source == "TierBody" then
		return GOLD_BODY
	end
	local colour = if meteor then FIRE elseif tier == 4 then GOLD else tierColor
	if source == "TierDeep" or source == "TierLight" then
		local r, g, b = string.match(colour, "(%d+),(%d+),(%d+)")
		local parts = {}
		for _, value in { tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0 } do
			local tone = if source == "TierDeep" then value * DEEP else value + (255 - value) * LIGHT
			table.insert(parts, tostring(math.round(tone)))
		end
		colour = table.concat(parts, ",")
	end
	return `{letter}{colour},{transparency},{reflectance},{source}`
end

local function pointsOf(model: Model): { [string]: Point }
	local points: { [string]: Point } = {}
	for _, item in model:GetDescendants() do
		local slot = if item:IsA("Attachment") then string.match(item.Name, "^anchor(%a+)$") else nil
		local holder = item.Parent
		if slot and holder and holder:IsA("BasePart") then
			points[slot] = {
				at = (item :: Attachment).WorldPosition,
				scale = tonumber(item:GetAttribute("Scale")) or 1,
				holder = holder,
			}
		end
	end
	return points
end

-- Dresses `model` (a low-poly pet at its own size, its Outfit attribute set) in `picks`, from `kit`.
function OutfitDress.dress(model: Model, kit: Instance, picks: { [string]: string? }, tier: number, meteor: boolean)
	local points = pointsOf(model)
	local turn = model:GetPivot().Rotation
	local tierColor = tostring(model:GetAttribute("TierColor") or "137,203,255")
	-- Parts of a pet go by name (AlienDress keys their paints by it): the pieces' get numbers past
	-- the body's.
	local serial = 1000

	local function place(pieceName: string, at: Vector3, scale: number, role: string?): { MeshPart }
		local source = kit:FindFirstChild(pieceName)
		if not (source and source:IsA("Model")) then
			warn(`[OutfitDress] No outfit piece {pieceName} in the place's kit; the pet goes without it`)
			return {}
		end
		local piece = source:Clone()
		piece:ScaleTo(scale)
		piece:PivotTo(CFrame.new(at) * turn)
		local parts: { MeshPart } = {}
		for _, part in piece:GetChildren() do
			if not part:IsA("MeshPart") then
				continue
			end
			serial += 1
			local ownRole = string.match(part.Name, "^(.-)_%d+$") or part.Name
			part.Name = `{role or ownRole}_{serial}`
			local code = part:GetAttribute("Paint")
			if type(code) == "string" then
				part:SetAttribute("Paint", repaint(code, tier, meteor, tierColor))
			end
			-- Worn, not the body: the client sizes the body's own light without it (AlienDress).
			part:SetAttribute(OUTFIT_ATTRIBUTE, true)
			part.Parent = model
			table.insert(parts, part)
		end
		piece:Destroy()
		return parts
	end

	local function onSlot(piece: string?)
		local slot = if piece then SLOT_OF[piece] else nil
		local point = if slot then points[slot] else nil
		if piece and point then
			place(piece, point.at, point.scale)
		end
	end

	onSlot(picks.head)
	onSlot(picks.aura)
	local back = picks.back
	if back == "jetpack" then
		onSlot(back)
	elseif back and WINGS[back] then
		local wing = WINGS[back]
		local size = wing.size * (if tier == 3 then EPIC_WINGS else 1)
		for _, side in { "L", "R" } do
			local point = points["Wing" .. side]
			if point then
				place(wing.piece .. side, point.at, point.scale * size)
				-- The hinge the wing flaps on (World/RigMotion reads `hingeL`, `hingeR`).
				local hinge = Instance.new("Attachment")
				hinge.Name = "hinge" .. side
				hinge.Parent = point.holder
				hinge.WorldPosition = point.at
			end
		end
	end
	local orbit = points.Orbit
	if model:GetAttribute("Zone") == "horizon" and tier >= 2 and orbit then
		for index = 1, tier - 1 do
			local angle = PLANET_ANGLES[index]
			local offset = turn
				* Vector3.new(math.cos(angle) * orbit.scale * 1.35, 0, math.sin(angle) * orbit.scale * 0.8)
			place("planet", orbit.at + offset, 1)
		end
	end
end

return table.freeze(OutfitDress)
