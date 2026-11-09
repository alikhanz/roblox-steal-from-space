--!strict
-- The pets' models in the repo (assets/aliens, lune/aliens.luau) against the registry and the
-- Blender scripts.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local AlienConfig = require("../../src/shared/Config/AlienConfig")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local MODELS_DIR = "assets/aliens"
local MANIFEST = "src/server/World/AlienModels.json"
local VARIANTS = { "0", "1", "2", "3", "4", "m0", "m1", "m2", "m3", "m4" }

-- The numbers of a Luau or Python list literal, in order.
local function numbers(list: string): { number }
	local result: { number } = {}
	for number in string.gmatch(list, "[%d%.]+") do
		table.insert(result, assert(tonumber(number)))
	end
	return result
end

describe("Alien models", function()
	it("takes out the tier growth Blender gives the pets (robo.py GROWTH)", function()
		local blender = fs.readFile("assets/blender/aliens/robo.py")
		local looks = fs.readFile("src/shared/Config/AlienLooks.luau")
		local growth = assert(string.match(blender, "\nGROWTH = %[([^%]]+)%]"), "robo.py has no GROWTH")
		local taken = assert(string.match(looks, "TIER_GROWTH = table%.freeze%(%{([^}]+)%}"), "no TIER_GROWTH")
		expect(numbers(taken)).toEqual(numbers(growth))
		expect(#numbers(taken)).toBe(#AlienConfig.TIER_ORDER)
	end)

	it("keeps a file per known kind, listed with its fingerprint, each with its ten pets", function()
		local manifest = serde.decode("json", fs.readFile(MANIFEST)) :: { [string]: string }
		local files: { [string]: boolean } = {}
		for _, file in fs.readDir(MODELS_DIR) do
			local kindId = string.match(file, "^(%w+)%.rbxm$")
			if not kindId then
				continue
			end
			files[kindId] = true
			expect(AlienConfig.KINDS[kindId]).toBeTruthy()
			local roots = roblox.deserializeModel(fs.readFile(`{MODELS_DIR}/{file}`))
			expect(#roots).toBe(1)
			local folder = roots[1]
			expect(folder.Name).toBe(kindId)
			expect(folder:GetAttribute("ModelHash")).toBe(manifest[kindId])
			for _, variant in VARIANTS do
				local pet = folder:FindFirstChild(`{kindId}-{variant}`)
				expect(pet).toBeTruthy()
				expect((pet :: any):GetAttribute("Zone")).toBeTruthy()
			end
		end
		for kindId in manifest do
			expect(files[kindId]).toBe(true)
		end
	end)
end)
