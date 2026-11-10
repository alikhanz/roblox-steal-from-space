--!strict
-- The interface's sounds (docs/design/screens/buttons.md): a soft click for every press that went
-- through, a chime for a purchase, a pop for a hatch. Roblox's own UI sounds from the Creator
-- Store (creator: Roblox), free for any experience. Played on this client only.

local SoundService = game:GetService("SoundService")

export type Name = "Click" | "Buy" | "Hatch"

local SOUNDS: { [Name]: { id: string, volume: number } } = {
	-- Roblox_UI_Small_Click
	Click = { id = "rbxassetid://15675032796", volume = 0.35 },
	-- Roblox_UI_Tonal_Stinger
	Buy = { id = "rbxassetid://15675043410", volume = 0.55 },
	-- Roblox_UI_Cute_Pop
	Hatch = { id = "rbxassetid://15675055424", volume = 0.6 },
}

local made: { [Name]: Sound } = {}

local Sounds = {}

function Sounds.play(name: Name)
	local sound = made[name]
	if not sound then
		local spec = SOUNDS[name]
		sound = Instance.new("Sound")
		sound.Name = `Ui{name}`
		sound.SoundId = spec.id
		sound.Volume = spec.volume
		sound.Parent = SoundService
		made[name] = sound
	end
	SoundService:PlayLocalSound(sound)
end

return table.freeze(Sounds)
