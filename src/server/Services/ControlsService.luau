--!strict
-- The controls window's "Don't show again" (decision 105, docs/design/screens/controls.md): keeps
-- the player's choice in the profile and on the player (`TutorialConfig.CONTROLS_HIDDEN_ATTRIBUTE`)
-- for the client, which then shows no "?" tile and does not open the window on joining. The
-- choice changes nothing in play, so the only check is the active profile (`update`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
}

export type ControlsService = {
	name: string,
	start: () -> (),
	-- The player ticked (true) or cleared (false) "Don't show again".
	setHidden: (player: Player, hidden: boolean) -> (),
}

local ControlsService = {}

function ControlsService.new(dependencies: Dependencies): ControlsService
	local function publish(player: Player)
		local data = dependencies.getData(player)
		if data then
			player:SetAttribute(TutorialConfig.CONTROLS_HIDDEN_ATTRIBUTE, data.controlsHidden)
		end
	end

	local function setHidden(player: Player, hidden: boolean)
		local data = dependencies.getData(player)
		if not data or data.controlsHidden == hidden then
			return
		end
		local written = dependencies.update(player, function(current)
			current.controlsHidden = hidden
		end)
		if written then
			publish(player)
		end
	end

	return {
		name = "ControlsService",
		start = function()
			dependencies.activated.connect(publish)
		end,
		setHidden = setHidden,
	}
end

return table.freeze(ControlsService)
