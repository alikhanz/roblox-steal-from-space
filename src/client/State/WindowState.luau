--!strict
-- Which window is open: one at a time. Opening a window (the bay, the quests, the index, the
-- daily gift, the jetpack shop, the Robux shop) closes the one that was open, so they never pile up on screen. Each
-- window controller holds a slot that reads and writes like a Vide source of its open flag.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

-- A window's open flag: called with nothing it reads (reactively), with a value it opens or
-- closes the window.
export type Slot = (open: boolean?) -> boolean

export type WindowState = {
	name: string,
	start: () -> (),
	slot: (id: string) -> Slot,
}

local WindowState = {}

function WindowState.new(): WindowState
	local open = Vide.source(nil :: string?)
	local read = open :: () -> string?

	return {
		name = "WindowState",
		start = function() end,
		slot = function(id: string): Slot
			return function(value: boolean?): boolean
				if value == true then
					open(id)
				elseif value == false and read() == id then
					open(nil)
				end
				return read() == id
			end
		end,
	}
end

return table.freeze(WindowState)
