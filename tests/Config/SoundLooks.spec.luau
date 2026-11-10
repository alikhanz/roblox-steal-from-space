--!strict

local fs = require("@lune/fs")

local OxygenConfig = require("../../src/shared/Config/OxygenConfig")
local SoundLooks = require("../../src/shared/Config/SoundLooks")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- Sounds the game plays that are not synthesised by assets/audio/sfx.py.
local NOT_SYNTHESISED = { Click = true }

describe("SoundLooks", function()
	it("beeps for low oxygen exactly when the HUD warns", function()
		expect(SoundLooks.OXYGEN_BEEP.below).toBe(OxygenConfig.LOW_FRACTION)
	end)

	it("has every sound the synth script makes, and the script makes every sound it lists", function()
		local script = fs.readFile("assets/audio/sfx.py")
		local made: { [string]: boolean } = {}
		for name in string.gmatch(script, '%(%s*"(%u%w+)",%s*"[^"]*",%s*"[^"]*"%)') do
			made[name] = true
			expect(SoundLooks.SOUNDS[name :: any] ~= nil).toBe(true)
		end
		for name in SoundLooks.SOUNDS do
			if not NOT_SYNTHESISED[name] then
				expect(made[name]).toBe(true)
			end
		end
	end)

	it("gives a sound heard in the world a reach beyond its full-volume distance", function()
		for _, sound in SoundLooks.SOUNDS do
			if sound.reach then
				expect(sound.near ~= nil and sound.near < sound.reach).toBe(true)
			end
		end
	end)

	it("plays uploaded assets only, of sounds it knows", function()
		local function isAsset(id: string): boolean
			return string.match(id, "^rbxassetid://%d+$") ~= nil
		end
		for _, sound in SoundLooks.SOUNDS do
			expect(sound.publicId == nil or isAsset(sound.publicId :: string)).toBe(true)
		end
		for _, ids in SoundLooks.GAMES do
			for name, id in ids do
				expect(SoundLooks.SOUNDS[name] ~= nil).toBe(true)
				expect(isAsset(id)).toBe(true)
			end
		end
	end)

	it("finds a game's own asset first, then a public one, else none", function()
		expect(SoundLooks.assetOf(0, "Click")).toBe(SoundLooks.SOUNDS.Click.publicId)
		expect(SoundLooks.assetOf(0, "Delivery")).toBe(nil)
	end)
end)
