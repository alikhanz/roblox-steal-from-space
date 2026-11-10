--!strict
-- Draws everyone's harpoon shots and gravity bombs on this client (brief
-- docs/design/screens/pvp-abilities.md): the server sends what happened (PvpService through
-- NetService: HarpoonShot, BombThrown, BombExploded) and this draws it, nearer than
-- PvpLooks.DRAW_DISTANCE to the camera (World/HarpoonVisual, World/BombVisual). Client-only parts
-- in workspace[PvpLooks.EFFECTS_FOLDER_NAME], stepped together once a frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BombVisual = require(script.Parent.Parent.World.BombVisual)
local HarpoonVisual = require(script.Parent.Parent.World.HarpoonVisual)
local PvpLooks = require(ReplicatedStorage.Shared.Config.PvpLooks)
local Remotes = require(script.Parent.Parent.Net.Remotes)

export type PvpEffectsController = {
	name: string,
	start: () -> (),
}

type Effect = { step: (deltaTime: number) -> boolean }

local PvpEffectsController = {}

local function isNear(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= PvpLooks.DRAW_DISTANCE
end

function PvpEffectsController.new(): PvpEffectsController
	local effects: { Effect } = {}
	local bombs: { [number]: BombVisual.Effect } = {}

	local function step(deltaTime: number)
		for index = #effects, 1, -1 do
			if not effects[index].step(deltaTime) then
				table.remove(effects, index)
			end
		end
	end

	local function start()
		local folder = Instance.new("Folder")
		folder.Name = PvpLooks.EFFECTS_FOLDER_NAME
		folder.Parent = workspace

		Remotes.HarpoonShot.SetCallback(function(shot)
			if not isNear(shot.target) then
				return
			end
			local effect = HarpoonVisual.new(shot, folder)
			if effect then
				table.insert(effects, effect)
			end
		end)
		Remotes.BombThrown.SetCallback(function(throw)
			-- Drawn if it starts or could end near: it flies at most `fuse` seconds.
			local ending = throw.start + throw.velocity * throw.fuse
			if not isNear(throw.start) and not isNear(ending) then
				return
			end
			local effect = BombVisual.thrown(throw, folder)
			bombs[throw.id] = effect
			table.insert(effects, effect)
		end)
		Remotes.BombExploded.SetCallback(function(blast)
			local bomb = bombs[blast.id]
			bombs[blast.id] = nil
			if bomb then
				bomb.explode(blast.center)
			elseif isNear(blast.center) then
				table.insert(effects, BombVisual.blast(blast.center, folder))
			end
		end)
		RunService.RenderStepped:Connect(step)
	end

	return {
		name = "PvpEffectsController",
		start = start,
	}
end

return table.freeze(PvpEffectsController)
