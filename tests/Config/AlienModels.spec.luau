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
		local taken = assert(string.match(looks, "TIER_GROWTH = table%.freeze%({([^}]+)}"), "no TIER_GROWTH")
		expect(numbers(taken)).toEqual(numbers(growth))
		expect(#numbers(taken)).toBe(#AlienConfig.TIER_ORDER)
	end)

	it("bakes the colours the game gives a paint (export_robo_roblox.py against AlienDress)", function()
		local export = fs.readFile("assets/blender/aliens/export_robo_roblox.py")
		local dress = fs.readFile("src/shared/World/AlienDress.luau")
		-- The names of a Lua table literal `local NAME = { A = true, ... }`.
		local function luaNames(name: string): { string }
			local body = assert(string.match(dress, `local {name} = (%b\{\})`), `AlienDress has no {name}`)
			local names = {}
			for key in string.gmatch(body, "(%a+) = true") do
				table.insert(names, key)
			end
			return names
		end
		-- The quoted names in a Python set literal assigned to `name`.
		local function pythonNames(name: string): { [string]: boolean }
			local body = assert(string.match(export, `\n{name} = ([^\n]*%b\{\})`), `export has no {name}`)
			local names = {}
			for key in string.gmatch(body, '"(%a+)"') do
				names[key] = true
			end
			return names
		end
		local kept = pythonNames("SPECIAL_SOURCES")
		for key in pythonNames("KEEP_SOURCES") do
			kept[key] = true
		end
		-- Every material the dressing treats by name keeps its own paint in the export.
		for _, set in { "STAND_INS", "CRYSTALS", "AURAS", "RIBBONS" } do
			for _, key in luaNames(set) do
				expect(kept[key]).toBe(true)
			end
		end
		expect(kept.Galaxy).toBe(true)
		expect(kept.Jet).toBe(true)
		local golds = pythonNames("GOLD_SOURCES")
		local luaGolds = luaNames("GOLDS")
		for _, key in luaGolds do
			expect(golds[key]).toBe(true)
		end
		-- The boosts: plastic and metal.
		expect(string.find(dress, "boost(colour, 1.25, 1.12)", 1, true)).toBeTruthy()
		expect(string.find(export, "boost(rgb, 1.25, 1.12)", 1, true)).toBeTruthy()
		expect(string.find(dress, "boost(colour, 1.15, 1.05)", 1, true)).toBeTruthy()
		expect(string.find(export, "boost(rgb, 1.15, 1.05)", 1, true)).toBeTruthy()
		expect(string.find(dress, "Color3.fromRGB(255, 190, 45)", 1, true)).toBeTruthy()
		expect(string.find(export, "GOLD = (255 / 255, 190 / 255, 45 / 255)", 1, true)).toBeTruthy()
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
		-- The low-poly pets' outfit kit (decision 118) is a file of its own, listed like a kind.
		if manifest._Outfit then
			local roots = roblox.deserializeModel(fs.readFile(`{MODELS_DIR}/_Outfit.rbxm`))
			expect(roots[1]:GetAttribute("ModelHash")).toBe(manifest._Outfit)
			files._Outfit = true
		end
		for kindId in manifest do
			expect(files[kindId]).toBe(true)
		end
	end)

	it("keeps Blender's markers as points: hinges on the body, fairy dust on the wings", function()
		for _, file in fs.readDir(MODELS_DIR) do
			if not string.match(file, "%.rbxm$") then
				continue
			end
			for _, item in roblox.deserializeModel(fs.readFile(`{MODELS_DIR}/{file}`))[1]:GetDescendants() do
				local parent = item.Parent :: any
				if item.ClassName == "MeshPart" then
					-- No marker is left a part (a mesh to download and a part to send).
					expect(string.match(item.Name, "^hinge") or string.match(item.Name, "^dust[LR]")).toBeNil()
				elseif item.ClassName == "Attachment" and string.match(item.Name, "^hinge") then
					-- On a part that never moves, so the point stays where the joint is.
					expect(string.match(parent.Name, "^body_%d+$")).toBeTruthy()
				elseif item.ClassName == "Attachment" and item.Name == "Dust" then
					-- On its wing's membrane, so it flaps with it.
					expect(string.match(parent.Name, "^wing[LR]_%d+$")).toBeTruthy()
					expect(string.match(tostring(parent:GetAttribute("Paint")), "Wing$")).toBeTruthy()
				end
			end
		end
	end)
end)
