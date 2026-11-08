--!strict
-- Keeps Roblox's automatic translation off our interface (decision 071): every text a player
-- reads is already worded in their language by Locale/Text (Strings.luau, through
-- Text.localeOf). Roblox machine-translates GUI text with AutoLocalize on (the default) for
-- players who turned automatic translations on, and assumes the text is in the game's source
-- language, so it could garble our Russian or retranslate our English. AutoLocalize on a root
-- GUI (ScreenGui, BillboardGui, SurfaceGui) covers its descendants, so this switches it off on
-- every such root as it appears: under PlayerGui and in the world. One place, so a new screen
-- cannot forget it.

local Players = game:GetService("Players")

local PLAYER_GUI_WAIT_TIMEOUT = 30

export type AutoLocalizeGuard = {
	name: string,
	start: () -> (),
}

local AutoLocalizeGuard = {}

local function guard(instance: Instance)
	if instance:IsA("LayerCollector") and instance.AutoLocalize then
		instance.AutoLocalize = false
	end
end

local function watch(root: Instance)
	for _, descendant in root:GetDescendants() do
		guard(descendant)
	end
	root.DescendantAdded:Connect(guard)
end

function AutoLocalizeGuard.new(): AutoLocalizeGuard
	local function start()
		watch(workspace)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		if not playerGui then
			warn("[AutoLocalizeGuard] PlayerGui did not appear; our GUIs keep Roblox's auto-translation")
			return
		end
		watch(playerGui)
	end

	return {
		name = "AutoLocalizeGuard",
		start = start,
	}
end

return table.freeze(AutoLocalizeGuard)
