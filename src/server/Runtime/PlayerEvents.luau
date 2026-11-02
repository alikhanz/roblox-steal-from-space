--!strict
-- Calls `onAdded` for players already in the server and for every new one, each in its own
-- thread (handlers may yield, e.g. while loading data), and `onRemoving` when a player leaves.

local Players = game:GetService("Players")

local PlayerEvents = {}

function PlayerEvents.observe(onAdded: (Player) -> (), onRemoving: (Player) -> ()): () -> ()
	local addedConnection = Players.PlayerAdded:Connect(onAdded)
	local removingConnection = Players.PlayerRemoving:Connect(function(player: Player)
		onRemoving(player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(onAdded, player)
	end

	return function()
		addedConnection:Disconnect()
		removingConnection:Disconnect()
	end
end

return table.freeze(PlayerEvents)
