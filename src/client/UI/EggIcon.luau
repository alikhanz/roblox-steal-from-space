--!strict
-- The icon of a particular egg wherever one is marked or shown: every special egg has its own
-- (the user, 2026-11-13; docs/design/screens/markers.md). The one table of kind to icon: a new
-- special egg adds its kind in Domain/EggKind and its row here.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggKind = require(ReplicatedStorage.Shared.Domain.EggKind)
local Icons = require(script.Parent.Icons)

local ICONS: { [EggKind.Kind]: Icons.Name } = {
	Normal = "Egg",
	Meteor = "MeteorEgg",
	Star = "StarEgg",
}

local EggIcon = {}

function EggIcon.of(kind: EggKind.Kind): Icons.Name
	return ICONS[kind]
end

-- The icon of an egg part (EggModel marks every egg with its variant, and the star egg as lucky).
function EggIcon.ofPart(part: Instance): Icons.Name
	local variant = part:GetAttribute(EggConfig.EGG_VARIANT_ATTRIBUTE)
	local isLucky = part:GetAttribute(EggConfig.EGG_LUCKY_ATTRIBUTE) == true
	return ICONS[EggKind.of(if type(variant) == "string" then variant else nil, isLucky)]
end

-- The icon of the egg `character` carries (the carry service welds it on, tagged), or nil while
-- it has not arrived.
function EggIcon.carriedBy(character: Instance): Icons.Name?
	for _, child in character:GetChildren() do
		if CollectionService:HasTag(child, EggConfig.CARRIED_EGG_TAG) then
			return EggIcon.ofPart(child)
		end
	end
	return nil
end

-- The icon of an egg as the profile keeps it (the incubator).
function EggIcon.ofRecord(egg: { read variant: string?, read luck: number? }): Icons.Name
	return ICONS[EggKind.of(egg.variant, (egg.luck or 0) > 0)]
end

return table.freeze(EggIcon)
