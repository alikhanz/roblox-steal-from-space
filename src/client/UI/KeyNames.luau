--!strict
-- The key bound to a flight input action, worded for the player: "LMB", "Space", "Shift", a
-- letter, a gamepad button without its "Button" prefix ("R2"). Read from the bindings the input
-- itself uses (FlightInputs.boundKey), so a hint never disagrees with what the key does. The HUD's
-- action row and the controls window both show keys through it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)
local Text = require(ReplicatedStorage.Shared.Locale.Text)

-- Keys whose name is not what a player calls them.
local KEY_WORDS: { [string]: Text.Key } = {
	MouseLeftButton = "key.mouseLeft.hint",
	LeftShift = "key.shift.hint",
	Space = "key.space.hint",
}

local KeyNames = {}

-- How a player calls `key`.
function KeyNames.word(locale: Text.Locale, key: Enum.KeyCode): string
	local word = KEY_WORDS[key.Name]
	if word then
		return Text.get(locale, word)
	end
	return (string.gsub(key.Name, "^Button", ""))
end

-- The key bound to `actionName` for `input`, worded; empty when there is none (no touch key, or
-- the player's input context has not arrived yet).
function KeyNames.forAction(player: Player, locale: Text.Locale, actionName: string, input: Enum.PreferredInput): string
	local context = player:FindFirstChild(FlightInputs.CONTEXT_NAME)
	local key = if context then FlightInputs.boundKey(context, actionName, input) else nil
	return if key then KeyNames.word(locale, key) else ""
end

return table.freeze(KeyNames)
