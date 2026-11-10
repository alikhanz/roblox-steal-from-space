--!strict
-- The row of menu tiles in the HUD (docs/design/screens/hud.md): which windows have a tile, in
-- what order, with which key. Each window controller adds its own tile (what a press does, its
-- badge, whether it shows); the HUD draws the row and this module answers the keys, so the
-- order and the keys live in one place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Vide = require(ReplicatedStorage.Packages.Vide)

export type Slot = "Bay" | "Store" | "Quests" | "Index" | "Gift" | "Community"

-- Left to right. A tile that can disappear goes last, so the row never has a gap (the gift
-- waits for the first delivery; the community gift comes after the tutorial and goes for good).
local SLOTS: { { slot: Slot, key: Enum.KeyCode } } = {
	{ slot = "Bay", key = Enum.KeyCode.B },
	{ slot = "Store", key = Enum.KeyCode.M },
	{ slot = "Quests", key = Enum.KeyCode.J },
	{ slot = "Index", key = Enum.KeyCode.N },
	{ slot = "Gift", key = Enum.KeyCode.L },
	{ slot = "Community", key = Enum.KeyCode.K },
}

export type Tile = {
	slot: Slot,
	-- Opens the window, or closes it when it is open.
	onPress: () -> (),
	-- Something waits inside: a count on the tile, hidden at 0.
	badge: (() -> number)?,
	-- Shown unless this says otherwise.
	visible: (() -> boolean)?,
}

export type MenuState = {
	name: string,
	start: () -> (),
	add: (tile: Tile) -> (),
	-- The slots left to right, with their keys.
	slots: () -> { { slot: Slot, key: Enum.KeyCode } },
	-- The tile a window added to `slot` (reactive), or nil before it is added.
	tile: (slot: Slot) -> Tile?,
}

local MenuState = {}

local function isShown(tile: Tile?): boolean
	return tile ~= nil and (tile.visible == nil or tile.visible())
end

function MenuState.new(): MenuState
	local tiles = Vide.source({} :: { [Slot]: Tile })

	local function tile(slot: Slot): Tile?
		return tiles()[slot]
	end

	local function start()
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end
			for _, entry in SLOTS do
				local found = tile(entry.slot)
				if input.KeyCode == entry.key and found and isShown(found) then
					found.onPress()
					return
				end
			end
		end)
	end

	return {
		name = "MenuState",
		start = start,
		add = function(new: Tile)
			local current = table.clone(Vide.untrack(tiles))
			assert(current[new.slot] == nil, `menu slot {new.slot} is taken`)
			current[new.slot] = new
			tiles(current)
		end,
		slots = function()
			return SLOTS
		end,
		tile = tile,
	}
end

-- True when `tile` is added and not hidden (reactive).
MenuState.isShown = isShown

return table.freeze(MenuState)
