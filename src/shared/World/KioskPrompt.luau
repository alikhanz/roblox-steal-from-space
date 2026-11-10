--!strict
-- Finds a station kiosk's prompt (decision 087): it hangs on an attachment at the kiosk's counter
-- (ShopConfig.PROMPT_POINT_NAME), somewhere inside the kiosk model.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)

local WAIT_SECONDS = 10
local WAIT_STEP = 0.25

local KioskPrompt = {}

-- The prompt in `model`, waiting up to a few seconds for it to arrive; nil if it never does.
-- Yields: call from a spawned thread.
function KioskPrompt.find(model: Instance): ProximityPrompt?
	local waited = 0
	while true do
		local point = model:FindFirstChild(ShopConfig.PROMPT_POINT_NAME, true)
		local prompt = point and point:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			return prompt
		end
		if waited >= WAIT_SECONDS or not model.Parent then
			return nil
		end
		task.wait(WAIT_STEP)
		waited += WAIT_STEP
	end
end

-- Where `prompt` stands in the world.
function KioskPrompt.position(prompt: ProximityPrompt): Vector3?
	local parent = prompt.Parent
	if parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("BasePart") then
		return parent.Position
	end
	return nil
end

return table.freeze(KioskPrompt)
