--!strict

local EggConfig = require("../../src/shared/Config/EggConfig")
local Radar = require("../../src/shared/Domain/Radar")
local RadarConfig = require("../../src/shared/Config/RadarConfig")
local Test = require("../../lune/lib/Test")
local roblox = require("@lune/roblox")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- @lune/roblox typedefs do not declare datatypes; the global Vector3 type describes it.
local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)

local function loose(id: string, rarity: string, distance: number, isOwn: boolean?): Radar.Loose
	return { id = id, rarity = rarity, distance = distance, isOwn = isOwn == true }
end

local function ids(eggs: { Radar.Loose }): string
	local list = {}
	for _, egg in eggs do
		table.insert(list, egg.id)
	end
	return table.concat(list, ",")
end

describe("Radar.kindOf", function()
	it("marks empty hands as a plain player", function()
		expect(Radar.kindOf(nil)).toBe("Player")
	end)

	it("marks common and uncommon eggs as a thief", function()
		expect(Radar.kindOf("Common")).toBe("Thief")
		expect(Radar.kindOf("Uncommon")).toBe("Thief")
	end)

	it("shows rare and rarer to the whole server", function()
		expect(Radar.kindOf("Rare")).toBe("HotThief")
		expect(Radar.kindOf("Epic")).toBe("HotThief")
		expect(Radar.kindOf("Legendary")).toBe("HotThief")
	end)

	it("treats an unknown rarity as empty hands", function()
		expect(Radar.kindOf("Mythic")).toBe("Player")
	end)
end)

describe("Radar.isFarEnough", function()
	it("hides only a player right next to you", function()
		expect(Radar.isFarEnough(RadarConfig.PLAYER_MIN_DISTANCE - 1)).toBe(false)
		expect(Radar.isFarEnough(RadarConfig.PLAYER_MIN_DISTANCE)).toBe(true)
	end)

	it("marks players a little way off, where Roblox's name used to show", function()
		expect(Radar.isFarEnough(40)).toBe(true)
	end)
end)

describe("Radar.fade", function()
	it("leaves near players clear and fades far ones up to the cap", function()
		expect(Radar.fade("Player", RadarConfig.FADE_NEAR)).toBe(0)
		expect(Radar.fade("Player", RadarConfig.FADE_FAR * 3)).toBe(RadarConfig.FADE_MAX)
		local middle = Radar.fade("Player", (RadarConfig.FADE_NEAR + RadarConfig.FADE_FAR) / 2)
		expect(math.abs(middle - RadarConfig.FADE_MAX / 2) < 1e-9).toBe(true)
	end)

	it("never fades a thief", function()
		expect(Radar.fade("HotThief", RadarConfig.FADE_FAR * 3)).toBe(0)
	end)
end)

describe("Radar.shouldPublish", function()
	it("publishes the first position and moves past the step", function()
		local here = Vector3.new(10, 0, 0)
		expect(Radar.shouldPublish(nil, here)).toBe(true)
		expect(Radar.shouldPublish(here, here + Vector3.new(RadarConfig.PUBLISH_STEP / 2, 0, 0))).toBe(false)
		expect(Radar.shouldPublish(here, here + Vector3.new(0, RadarConfig.PUBLISH_STEP, 0))).toBe(true)
	end)
end)

describe("Radar.announcement", function()
	it("announces picking up an epic or legendary egg", function()
		expect(Radar.announcement(nil, "Epic")).toBe("radar.epicCarried.toast")
		expect(Radar.announcement(nil, "Legendary")).toBe("radar.legendaryCarried.toast")
	end)

	it("says nothing of lesser eggs, of dropping one, or of no change", function()
		expect(Radar.announcement(nil, "Rare")).toBe(nil)
		expect(Radar.announcement("Legendary", nil)).toBe(nil)
		expect(Radar.announcement("Epic", "Epic")).toBe(nil)
	end)

	it("has a string for every announced rarity", function()
		for rarity in RadarConfig.ANNOUNCED do
			expect(EggConfig.RARITIES[rarity] ~= nil).toBe(true)
		end
	end)
end)

describe("Radar.pickLoose", function()
	it("puts your own drop first, then the rarest, then the nearest", function()
		local picked = Radar.pickLoose({
			loose("near", "Common", 100),
			loose("rare", "Rare", 900),
			loose("own", "Common", 1500, true),
			loose("far", "Common", 400),
		})
		expect(ids(picked)).toBe("own,rare,near,far")
	end)

	it("leaves out eggs within the grab button's range", function()
		local picked = Radar.pickLoose({ loose("close", "Legendary", RadarConfig.LOOSE_MIN_DISTANCE - 1) })
		expect(#picked).toBe(0)
	end)

	it("shows at most the cap", function()
		local eggs = {}
		for index = 1, RadarConfig.LOOSE_CAP + 3 do
			table.insert(eggs, loose(`e{index}`, "Common", 100 + index))
		end
		expect(#Radar.pickLoose(eggs)).toBe(RadarConfig.LOOSE_CAP)
	end)
end)

describe("Radar.isLooseOnEdge", function()
	it("keeps a near, a rare or your own egg at the screen edge, not a far common one", function()
		expect(Radar.isLooseOnEdge(loose("a", "Common", RadarConfig.LOOSE_EDGE_RANGE))).toBe(true)
		expect(Radar.isLooseOnEdge(loose("b", "Rare", 3000))).toBe(true)
		expect(Radar.isLooseOnEdge(loose("c", "Common", 3000, true))).toBe(true)
		expect(Radar.isLooseOnEdge(loose("d", "Uncommon", 3000))).toBe(false)
	end)
end)

describe("Radar.timeLeft", function()
	it("runs from all to none over the loose egg's time", function()
		expect(Radar.timeLeft(100, 100)).toBe(1)
		expect(Radar.timeLeft(100, 100 + EggConfig.LOOSE_SECONDS / 2)).toBe(0.5)
		expect(Radar.timeLeft(100, 100 + EggConfig.LOOSE_SECONDS * 2)).toBe(0)
	end)
end)
