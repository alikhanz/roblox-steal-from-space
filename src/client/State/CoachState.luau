--!strict
-- The hint after the tutorial the server shows now (decision 106, CoachService): the tutorial's
-- panel words it and leads to it, the bay window lights its tile and its ready trios for it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(script.Parent.Parent.Net.Remotes)
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Tip = Remotes.CoachTip

export type CoachState = {
	name: string,
	start: () -> (),
	-- The tip now, or nil (reactive).
	tip: () -> Tip?,
}

local CoachState = {}

function CoachState.new(): CoachState
	local tip = Vide.source(nil :: Tip?)
	local readTip = tip :: () -> Tip?

	return {
		name = "CoachState",
		start = function()
			Remotes.CoachChanged.SetCallback(function(next: Tip?)
				tip(next)
			end)
		end,
		tip = readTip,
	}
end

return table.freeze(CoachState)
