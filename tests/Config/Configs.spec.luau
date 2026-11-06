--!strict
-- Cross-references between configs (CONVENTIONS, economy: checked automatically).

local AlienConfig = require("../../src/shared/Config/AlienConfig")
local AlienIndex = require("../../src/shared/Domain/AlienIndex")
local BayConfig = require("../../src/shared/Config/BayConfig")
local BigNum = require("../../src/shared/Domain/BigNum")
local EggConfig = require("../../src/shared/Config/EggConfig")
local EventConfig = require("../../src/shared/Config/EventConfig")
local GuardianConfig = require("../../src/shared/Config/GuardianConfig")
local IndexConfig = require("../../src/shared/Config/IndexConfig")
local Loot = require("../../src/shared/Domain/Loot")
local MeteorConfig = require("../../src/shared/Config/MeteorConfig")
local MeteorShower = require("../../src/shared/Domain/MeteorShower")
local MonetizationConfig = require("../../src/shared/Config/MonetizationConfig")
local SerpentConfig = require("../../src/shared/Config/SerpentConfig")
local Speed = require("../../src/shared/Domain/Speed")
local SpeedConfig = require("../../src/shared/Config/SpeedConfig")
local StationSize = require("../../src/shared/Config/StationSize")
local StormConfig = require("../../src/shared/Config/StormConfig")
local Strings = require("../../src/shared/Locale/Strings")
local Test = require("../../lune/lib/Test")
local WorldConfig = require("../../src/shared/Config/WorldConfig")
local ZoneConfig = require("../../src/shared/Config/ZoneConfig")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("AlienConfig", function()
	it("has one grade per guardian post with an alien per tier", function()
		expect(#AlienConfig.GRADES).toBe(#GuardianConfig.POSTS)
		expect(#AlienConfig.GRADES).toBe(ZoneConfig.POST_COUNT)
		-- Ids are part of the save format.
		expect(AlienConfig.GRADES[1].aliens.Common).toBe("DebrisBelt1.Common")
		expect(AlienConfig.GRADES[7].aliens.Rare).toBe("IceRings1.Rare")
		expect(AlienConfig.GRADES[24].aliens.Legendary).toBe("EventHorizon6.Legendary")
		for _, grade in AlienConfig.GRADES do
			expect(grade.zone).toBe((ZoneConfig.zoneOfPost(grade.index)))
			for _, tier in AlienConfig.TIER_ORDER do
				local alien = AlienConfig.ALIENS[grade.aliens[tier]]
				expect(alien).toBeTruthy()
				expect(alien.grade).toBe(grade.index)
				expect(alien.tier).toBe(tier)
			end
		end
	end)

	it("has a meteor alien for every usual one, earning twice as much", function()
		expect(AlienConfig.GRADES[7].variants.Meteor.Rare).toBe("IceRings1.Rare.Meteor")
		for _, grade in AlienConfig.GRADES do
			expect(grade.variants.Normal).toBe(grade.aliens)
			for _, tier in AlienConfig.TIER_ORDER do
				local usual = AlienConfig.ALIENS[grade.variants.Normal[tier]]
				local meteor = AlienConfig.ALIENS[grade.variants.Meteor[tier]]
				expect(meteor.variant).toBe("Meteor")
				expect(meteor.grade).toBe(usual.grade)
				expect(meteor.tier).toBe(tier)
				local factor = AlienConfig.VARIANTS.Meteor.incomeFactor
				expect(BigNum.toNumber(meteor.income) / BigNum.toNumber(usual.income)).toBeCloseTo(factor)
			end
		end
	end)

	it("earns more up the tiers and up the grades", function()
		for index, grade in AlienConfig.GRADES do
			local previous: BigNum.BigNum? = nil
			for _, tier in AlienConfig.TIER_ORDER do
				local income = AlienConfig.ALIENS[grade.aliens[tier]].income
				if previous then
					expect(BigNum.lessThan(previous, income)).toBe(true)
				end
				previous = income
			end
			if index > 1 then
				local lower = AlienConfig.ALIENS[AlienConfig.GRADES[index - 1].aliens.Common].income
				local higher = AlienConfig.ALIENS[grade.aliens.Common].income
				expect(BigNum.lessThan(lower, higher)).toBe(true)
			end
		end
	end)

	it("names every tier with an existing string", function()
		for _, tier in AlienConfig.TIER_ORDER do
			expect((Strings :: { [string]: any })[AlienConfig.TIERS[tier].nameKey]).toBeTruthy()
		end
		expect(Loot.chances(AlienConfig.HATCH_ENTRIES).Common > 0.5).toBe(true)
	end)
end)

describe("EggConfig", function()
	it("names every rarity and keeps the typical size", function()
		for _, rarity in EggConfig.RARITY_ORDER do
			expect(EggConfig.RARITIES[rarity]).toBeTruthy()
			expect((Strings :: { [string]: any })[EggConfig.RARITIES[rarity].nameKey]).toBeTruthy()
		end
		expect(EggConfig.SIZES[EggConfig.TYPICAL_SIZE]).toBeTruthy()
	end)

	it("hatches rarer eggs slower, heavier and luckier, the rarest within 5 hours", function()
		for position = 2, #EggConfig.RARITY_ORDER do
			local lower = EggConfig.RARITIES[EggConfig.RARITY_ORDER[position - 1]]
			local higher = EggConfig.RARITIES[EggConfig.RARITY_ORDER[position]]
			expect(lower.hatchSeconds.max < higher.hatchSeconds.max).toBe(true)
			expect(lower.weight < higher.weight).toBe(true)
			expect(lower.luck < higher.luck).toBe(true)
		end
		local rarest = EggConfig.RARITIES[EggConfig.RARITY_ORDER[#EggConfig.RARITY_ORDER]]
		expect(rarest.hatchSeconds.max <= 5 * 60 * 60).toBe(true)
	end)
end)

describe("ZoneConfig", function()
	it("lays the zones out from the station to the edge of the map", function()
		local previousMax = 0
		for _, id in ZoneConfig.ZONE_ORDER do
			local zone = ZoneConfig.ZONES[id]
			expect(zone.ringMin > previousMax).toBe(true)
			expect(zone.ringMax > zone.ringMin).toBe(true)
			expect(zone.ringMax < WorldConfig.BOUNDARY_RADIUS).toBe(true)
			expect(zone.nestCount >= zone.postCount).toBe(true)
			expect((Strings :: { [string]: any })[zone.nameKey]).toBeTruthy()
			previousMax = zone.ringMax
		end
	end)

	it("grows eggs only of rarities and sizes that exist, rarer farther out", function()
		local previousRare = -1
		for _, id in ZoneConfig.ZONE_ORDER do
			local zone = ZoneConfig.ZONES[id]
			for _, entry in zone.rarityLoot do
				expect(EggConfig.RARITIES[entry.id]).toBeTruthy()
			end
			for _, entry in zone.sizeLoot do
				expect(EggConfig.SIZES[entry.id]).toBeTruthy()
			end
			local rareOrBetter = 1 - Loot.chances(zone.rarityLoot).Common
			expect(rareOrBetter > previousRare).toBe(true)
			previousRare = rareOrBetter
		end
	end)

	it("maps global posts to zones and back", function()
		expect({ ZoneConfig.zoneOfPost(1) }).toEqual({ "DebrisBelt", 1 })
		expect({ ZoneConfig.zoneOfPost(6) }).toEqual({ "DebrisBelt", 6 })
		expect({ ZoneConfig.zoneOfPost(7) }).toEqual({ "IceRings", 1 })
		expect({ ZoneConfig.zoneOfPost(24) }).toEqual({ "EventHorizon", 6 })
		expect(ZoneConfig.postIndex("RedNebula", 2)).toBe(14)
		expect(function()
			ZoneConfig.zoneOfPost(25)
		end).toThrow("out of range")
	end)

	it("finds the zone at a distance from the station, the nearest between rings", function()
		local belt = ZoneConfig.ZONES.DebrisBelt
		local ice = ZoneConfig.ZONES.IceRings
		local horizon = ZoneConfig.ZONES.EventHorizon
		expect(ZoneConfig.zoneAtDistance(belt.ringMin - 1)).toBe(nil)
		expect(ZoneConfig.zoneAtDistance((belt.ringMin + belt.ringMax) / 2)).toBe("DebrisBelt")
		expect(ZoneConfig.zoneAtDistance(belt.ringMax + 1)).toBe("DebrisBelt")
		expect(ZoneConfig.zoneAtDistance(ice.ringMin - 1)).toBe("IceRings")
		expect(ZoneConfig.zoneAtDistance(horizon.ringMax + 100)).toBe("EventHorizon")
	end)
end)

describe("GuardianConfig", function()
	it("recommends the starting speed over the first guardian", function()
		expect(BigNum.toNumber(GuardianConfig.POSTS[1].recommended)).toBeCloseTo(
			BigNum.toNumber(SpeedConfig.STARTING_SPEED),
			1e-9
		)
	end)

	it("grows the recommendation by ever smaller steps and flies level with it", function()
		local posts = GuardianConfig.POSTS
		expect(posts[1].recommended).toEqual(GuardianConfig.FIRST_RECOMMENDED)
		local previousStep = math.huge
		for index = 2, #posts do
			local step = BigNum.toNumber(posts[index].recommended) / BigNum.toNumber(posts[index - 1].recommended)
			expect(step < previousStep).toBe(true)
			expect(step > 2 and step <= GuardianConfig.RECOMMENDED_GROWTH_START).toBe(true)
			previousStep = step
		end
		for index, post in posts do
			expect(post.index).toBe(index)
			expect(post.zone).toBe((ZoneConfig.zoneOfPost(index)))
			expect(GuardianConfig.POSTS_BY_ID[post.id]).toBe(post)
			expect((Strings :: { [string]: any })[post.nameKey]).toBeTruthy()
			-- A thief at the recommended speed with a typical egg matches the guardian exactly.
			local withEgg = Speed.withEgg(post.recommended, GuardianConfig.TYPICAL_WEIGHT)
			expect(BigNum.toNumber(withEgg)).toBeCloseTo(BigNum.toNumber(post.speed), 1e-9)
		end
	end)

	it("puts the last guardian near a trillion", function()
		local last = GuardianConfig.POSTS[#GuardianConfig.POSTS].recommended
		expect(BigNum.toNumber(last) > 5e11 and BigNum.toNumber(last) < 2e12).toBe(true)
	end)
end)

describe("BayConfig", function()
	it("keeps the starting pods within the maximum", function()
		expect(BayConfig.STARTING_PODS <= BayConfig.MAX_PODS).toBe(true)
		expect(BayConfig.CROSSBREED_COUNT <= BayConfig.INVENTORY_SLOTS).toBe(true)
	end)
end)

describe("IndexConfig", function()
	it("holds every alien of the registry in exactly one set, by grade and variant", function()
		local seen: { [string]: boolean } = {}
		expect(#IndexConfig.SETS).toBe(#AlienConfig.GRADES * #AlienConfig.VARIANT_ORDER)
		for _, set in IndexConfig.SETS do
			expect(IndexConfig.SETS_BY_ID[set.id]).toBe(set)
			expect(set.id).toBe(AlienIndex.setId(set.grade, set.variant))
			expect(#set.aliens).toBe(#AlienConfig.TIER_ORDER)
			for _, alienId in set.aliens do
				local alien = AlienConfig.ALIENS[alienId]
				expect(alien.grade).toBe(set.grade)
				expect(alien.variant).toBe(set.variant)
				expect(seen[alienId]).toBeNil()
				seen[alienId] = true
			end
		end
		for alienId in AlienConfig.ALIENS do
			expect(seen[alienId]).toBe(true)
		end
	end)

	it("keeps the usual sets named by their grade, as saved before variants", function()
		expect(IndexConfig.SETS_BY_ID["3"].variant).toBe("Normal")
		expect(IndexConfig.SETS_BY_ID["3.Meteor"].variant).toBe("Meteor")
	end)

	it("pays every tier", function()
		for _, tier in AlienConfig.TIER_ORDER do
			expect(IndexConfig.REWARD_MINUTES[tier] > 0).toBe(true)
		end
	end)
end)

describe("StationSize", function()
	it("grows outward in a chain: platform, dome, border, zones, edge of the map", function()
		expect(StationSize.DOME_RADIUS > StationSize.PLATFORM_RADIUS).toBe(true)
		expect(StationSize.BORDER_RADIUS > StationSize.DOME_RADIUS).toBe(true)
		local first = ZoneConfig.ZONES[ZoneConfig.ZONE_ORDER[1]]
		expect(first.ringMin > StationSize.BORDER_RADIUS).toBe(true)
		expect(WorldConfig.INNER_RADIUS > StationSize.BORDER_RADIUS).toBe(true)
		expect(WorldConfig.BOUNDARY_RADIUS > WorldConfig.OUTER_RADIUS).toBe(true)
	end)

	it("puts the storm's edge on the station border, where guardians stop", function()
		expect(StormConfig.RANGE_RADIUS).toBe(StationSize.BORDER_RADIUS)
	end)
end)

describe("EventConfig", function()
	it("fits an event that comes after another into that one's quiet spell", function()
		for _, event in EventConfig.EVENTS do
			local after = event.after
			if after then
				local before = EventConfig.EVENTS[after]
				local quiet = before.schedule.gapMin - before.schedule.warningSeconds
				expect(event.schedule.warningSeconds + event.schedule.activeSeconds < quiet).toBe(true)
			end
		end
	end)

	it("lists every event in the banner order once", function()
		local listed: { [string]: boolean } = {}
		for _, id in EventConfig.ORDER do
			expect(listed[id]).toBeNil()
			listed[id] = true
		end
		for id in EventConfig.EVENTS do
			expect(listed[id]).toBe(true)
		end
	end)
end)

describe("MeteorConfig", function()
	it("lets the last meteor of a full shower fall with half the shower left to grab it", function()
		local last = MeteorShower.fallTimes(MeteorConfig.MAX_EGGS, MeteorConfig)
		expect(last[#last] <= EventConfig.EVENTS.Meteor.schedule.activeSeconds / 2).toBe(true)
	end)
end)

describe("SerpentConfig", function()
	it("comes out only in zones past the Debris Belt, all of them within its bounds", function()
		expect(SerpentConfig.HUNT_RADIUS > StationSize.BORDER_RADIUS).toBe(true)
		expect(table.find(SerpentConfig.ZONES, "DebrisBelt" :: ZoneConfig.ZoneId)).toBeNil()
		expect(#SerpentConfig.ZONES).toBe(#ZoneConfig.ZONE_ORDER - 1)
		for _, zone in SerpentConfig.ZONES do
			local ring = ZoneConfig.ZONES[zone]
			expect(ring.ringMin > SerpentConfig.HUNT_RADIUS).toBe(true)
			expect(ring.ringMax <= SerpentConfig.OUTER_RADIUS).toBe(true)
		end
	end)

	it("flees a little slower than a player with its stat flies", function()
		for _, zone in SerpentConfig.ZONES do
			local playerSpeed = Speed.flightSpeed(SerpentConfig.powerIn(zone), SpeedConfig.FLIGHT)
			expect(SerpentConfig.fleeSpeedIn(zone) < playerSpeed).toBe(true)
			expect(SerpentConfig.fleeSpeedIn(zone) > SerpentConfig.ROAM_SPEED).toBe(true)
		end
	end)

	it("takes a few hits and guards its egg like a guardian", function()
		expect(SerpentConfig.HITS_TO_DROP > 1).toBe(true)
		expect(SerpentConfig.BRAIN.aggroDelaySeconds).toBe(GuardianConfig.BRAIN.aggroDelaySeconds)
	end)

	it("is as strong as the middle guardian of the zone it came out in", function()
		for _, zone in SerpentConfig.ZONES do
			local post = GuardianConfig.POSTS[ZoneConfig.postIndex(zone, SerpentConfig.POWER_POST)]
			expect(BigNum.equals(SerpentConfig.powerIn(zone), post.speed)).toBe(true)
		end
	end)

	it("guards its egg as fast as a guardian with its stat would chase", function()
		local post = GuardianConfig.POSTS[ZoneConfig.postIndex("RedNebula", SerpentConfig.POWER_POST)]
		local weight = GuardianConfig.TYPICAL_WEIGHT
		local loaded = Speed.withEgg(post.recommended, weight)
		local power = SerpentConfig.powerIn("RedNebula")
		expect(Speed.chaseSpeed(100, power, loaded, SpeedConfig.CHASE)).toBeCloseTo(100)
		-- Weaker than that, the serpent is faster.
		local weaker = Speed.withEgg(BigNum.div(post.recommended, BigNum.fromNumber(10)), weight)
		expect(Speed.chaseSpeed(100, power, weaker, SpeedConfig.CHASE) > 100).toBe(true)
	end)

	it("adds its luck on top of an egg's own", function()
		local own = EggConfig.luckOf("Rare", "Large")
		expect(own).toBe(EggConfig.RARITIES.Rare.luck + EggConfig.SIZES.Large.luck)
		expect(EggConfig.luckOf("Rare", "Large", SerpentConfig.STAR_EGG_LUCK)).toBe(own + SerpentConfig.STAR_EGG_LUCK)
	end)
end)

describe("MonetizationConfig", function()
	it("has every tier of every product in the Dev game", function()
		local catalog = assert(MonetizationConfig.catalogFor(10774871729))
		for tier = 1, MonetizationConfig.READY_NOW_TIERS do
			expect(MonetizationConfig.productIdOf(catalog, "ReadyNow", tier)).toBeTruthy()
		end
		for tier = 1, #MonetizationConfig.SLOT_TIER_LAST do
			expect(MonetizationConfig.productIdOf(catalog, "IncubatorSlot", tier)).toBeTruthy()
		end
		for _, hours in { 1, 8, 24 } do
			expect(MonetizationConfig.productIdOf(catalog, "Training", nil, hours * 3600)).toBeTruthy()
		end
		expect(MonetizationConfig.productIdOf(catalog, "CollectDouble")).toBeTruthy()
		expect(catalog.passes.DoubleTraining).toBeTruthy()
		expect(catalog.passes.NightShift).toBeTruthy()
	end)

	it("turns purchases off in an unknown game", function()
		expect(MonetizationConfig.catalogFor(0)).toBeNil()
	end)

	it("prices ready now from the first zone's common egg to the last zone's legendary", function()
		expect(MonetizationConfig.readyNowTierOf(1, "Common")).toBe(1)
		expect(MonetizationConfig.readyNowTierOf(ZoneConfig.POST_COUNT, "Legendary")).toBe(
			MonetizationConfig.READY_NOW_TIERS
		)
		expect(MonetizationConfig.readyNowTierOf(ZoneConfig.POSTS_PER_ZONE + 1, "Rare")).toBe(4)
	end)

	it("covers every bought slot with a tier", function()
		expect(MonetizationConfig.SLOT_TIER_LAST[#MonetizationConfig.SLOT_TIER_LAST]).toBe(
			BayConfig.MAX_INCUBATOR_SLOTS
		)
	end)
end)
