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
local Oxygen = require("../../src/shared/Domain/Oxygen")
local OxygenConfig = require("../../src/shared/Config/OxygenConfig")
local SerpentConfig = require("../../src/shared/Config/SerpentConfig")
local ServerConfig = require("../../src/shared/Config/ServerConfig")
local Speed = require("../../src/shared/Domain/Speed")
local SpeedConfig = require("../../src/shared/Config/SpeedConfig")
local StationSize = require("../../src/shared/Config/StationSize")
local StormConfig = require("../../src/shared/Config/StormConfig")
local Strings = require("../../src/shared/Locale/Strings")
local Test = require("../../lune/lib/Test")
local WorldConfig = require("../../src/shared/Config/WorldConfig")
local ZoneConfig = require("../../src/shared/Config/ZoneConfig")
local describe, it, expect = Test.describe, Test.it, Test.expect
local fs = require("@lune/fs")

describe("AlienConfig", function()
	it("grows the last guardian's aliens about five times the first's (decisions 068, 083)", function()
		local first = AlienConfig.ALIENS[AlienConfig.GRADES[1].aliens.Common]
		local last = AlienConfig.GRADES[#AlienConfig.GRADES]
		expect(first.scale).toBe(1)
		-- With a model about 3 studs across at scale 1, the last legendary stands about 30 wide
		-- (decision 083: thirty from all over the map fit on an island).
		expect(AlienConfig.ALIENS[last.aliens.Common].scale).toBeCloseTo(5.2, 0.2)
		expect(AlienConfig.ALIENS[last.aliens.Legendary].scale).toBeCloseTo(9.3, 0.3)
		-- Bigger with every guardian and every tier; a variant stands as big as the usual one.
		for index = 2, #AlienConfig.GRADES do
			local here = AlienConfig.ALIENS[AlienConfig.GRADES[index].aliens.Common].scale
			local before = AlienConfig.ALIENS[AlienConfig.GRADES[index - 1].aliens.Common].scale
			expect(here > before).toBe(true)
		end
		local grade = AlienConfig.GRADES[5]
		for position = 2, #AlienConfig.TIER_ORDER do
			local tier = AlienConfig.TIER_ORDER[position]
			local lower = AlienConfig.TIER_ORDER[position - 1]
			expect(AlienConfig.ALIENS[grade.aliens[tier]].scale > AlienConfig.ALIENS[grade.aliens[lower]].scale).toBe(
				true
			)
		end
		local meteorRare = grade.variants.Meteor[grade.kinds[1]].Rare
		expect(AlienConfig.ALIENS[meteorRare].scale).toBe(AlienConfig.ALIENS[grade.aliens.Rare].scale)
	end)

	it("has one grade per guardian post with its kinds, an alien per kind and tier", function()
		expect(#AlienConfig.GRADES).toBe(#GuardianConfig.POSTS)
		expect(#AlienConfig.GRADES).toBe(ZoneConfig.POST_COUNT)
		-- Ids are part of the save format.
		expect(AlienConfig.GRADES[1].aliens.Common).toBe("DebrisBelt1.slimeWarden.Common")
		expect(AlienConfig.GRADES[7].aliens.Rare).toBe("IceRings1.iceWorm.Rare")
		expect(AlienConfig.GRADES[2].variants.Normal.droneRay.Epic).toBe("DebrisBelt2.droneRay.Epic")
		expect(AlienConfig.GRADES[24].aliens.Legendary).toBe("EventHorizon6.spaceWhale.Legendary")
		for _, grade in AlienConfig.GRADES do
			expect(grade.zone).toBe((ZoneConfig.zoneOfPost(grade.index)))
			expect(#grade.kinds >= 1).toBe(true)
			expect(grade.aliens).toBe(grade.variants.Normal[grade.kinds[1]])
			for position, kindId in grade.kinds do
				local kind = AlienConfig.KINDS[kindId]
				expect(kind.grade).toBe(grade.index)
				expect(kind.position).toBe(position)
				expect(grade.kindEntries[position].id).toBe(kindId)
				expect(grade.kindEntries[position].weight).toBe(kind.weight)
				expect(kind.weight > 0).toBe(true)
				for _, tier in AlienConfig.TIER_ORDER do
					local alien = AlienConfig.ALIENS[grade.variants.Normal[kindId][tier]]
					expect(alien).toBeTruthy()
					expect(alien.grade).toBe(grade.index)
					expect(alien.kind).toBe(kindId)
					expect(alien.tier).toBe(tier)
					-- Kinds of a guardian earn the same: they are for the collection (decision 075).
					expect(BigNum.equals(alien.income, AlienConfig.ALIENS[grade.aliens[tier]].income)).toBe(true)
				end
			end
		end
	end)

	it("hatches the guardian's own kind most often, the rare one seldom (decision 075)", function()
		local chances = Loot.chances(AlienConfig.GRADES[1].kindEntries)
		expect(chances.slimeWarden).toBeCloseTo(0.6)
		expect(chances.patrolSwarm).toBeCloseTo(0.3)
		expect(chances.patrolRay).toBeCloseTo(0.1)
	end)

	it("names every kind; a main kind by its guardian's name", function()
		local count = 0
		for kindId, kind in AlienConfig.KINDS do
			count += 1
			expect(kind.id).toBe(kindId)
			expect((Strings :: { [string]: any })[kind.nameKey]).toBeTruthy()
			if kind.position == 1 then
				expect(kind.nameKey).toBe(GuardianConfig.POSTS[kind.grade].nameKey)
			end
		end
		local listed = 0
		for _, grade in AlienConfig.GRADES do
			listed += #grade.kinds
		end
		expect(count).toBe(listed)
	end)

	it("lists the kinds as the models do, post by post (robo_kinds.py)", function()
		local source = fs.readFile("assets/blender/aliens/robo_kinds.py")
		local posts = assert(string.match(source, "\nPOSTS = %[(.-)\n%]"), "robo_kinds.py has no POSTS")
		local modelled: { string } = {}
		for kindId, family in string.gmatch(posts, '%("(%w+)", "[^"]+", "(%a+)"') do
			table.insert(modelled, `{kindId}/{family}`)
		end
		local listed: { string } = {}
		for _, grade in AlienConfig.GRADES do
			for _, kindId in grade.kinds do
				table.insert(listed, `{kindId}/{AlienConfig.KINDS[kindId].family}`)
			end
		end
		expect(listed).toEqual(modelled)
	end)

	it("has a meteor alien for every usual one, earning twice as much", function()
		expect(AlienConfig.GRADES[7].variants.Meteor.iceWorm.Rare).toBe("IceRings1.iceWorm.Rare.Meteor")
		for _, grade in AlienConfig.GRADES do
			for _, kindId in grade.kinds do
				for _, tier in AlienConfig.TIER_ORDER do
					local usual = AlienConfig.ALIENS[grade.variants.Normal[kindId][tier]]
					local meteor = AlienConfig.ALIENS[grade.variants.Meteor[kindId][tier]]
					expect(meteor.variant).toBe("Meteor")
					expect(meteor.grade).toBe(usual.grade)
					expect(meteor.kind).toBe(kindId)
					expect(meteor.tier).toBe(tier)
					local factor = AlienConfig.VARIANTS.Meteor.incomeFactor
					expect(BigNum.toNumber(meteor.income) / BigNum.toNumber(usual.income)).toBeCloseTo(factor)
				end
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
	end)

	it("lists the tiers as the egg rarities, which hatch into the tier of their name", function()
		expect(AlienConfig.TIER_ORDER).toEqual(EggConfig.RARITY_ORDER :: { any })
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

	it("hatches rarer eggs slower and heavier, the rarest in 2 to 4 hours", function()
		for position = 2, #EggConfig.RARITY_ORDER do
			local lower = EggConfig.RARITIES[EggConfig.RARITY_ORDER[position - 1]]
			local higher = EggConfig.RARITIES[EggConfig.RARITY_ORDER[position]]
			expect(lower.hatchSeconds.max < higher.hatchSeconds.max).toBe(true)
			expect(lower.weight < higher.weight).toBe(true)
		end
		local rarest = EggConfig.RARITIES[EggConfig.RARITY_ORDER[#EggConfig.RARITY_ORDER]]
		expect(rarest.hatchSeconds).toEqual({ min = 2 * 60 * 60, max = 4 * 60 * 60 })
	end)

	-- The ladder the user approved (decision 113), percent: Common, Uncommon, Rare, Epic, Legendary.
	local LADDER: { [string]: { [string]: { number } } } = {
		Common = { Small = { 87.5, 12.5, 0, 0, 0 }, Medium = { 75, 25, 0, 0, 0 }, Large = { 50, 50, 0, 0, 0 } },
		Uncommon = { Small = { 30, 60, 10, 0, 0 }, Medium = { 20, 60, 20, 0, 0 }, Large = { 10, 50, 40, 0, 0 } },
		Rare = { Small = { 0, 30, 62.5, 7.5, 0 }, Medium = { 0, 20, 65, 15, 0 }, Large = { 0, 10, 60, 30, 0 } },
		Epic = { Small = { 0, 0, 22.5, 72.5, 5 }, Medium = { 0, 0, 15, 75, 10 }, Large = { 0, 0, 7.5, 72.5, 20 } },
		Legendary = { Small = { 0, 0, 0, 30, 70 }, Medium = { 0, 0, 0, 20, 80 }, Large = { 0, 0, 0, 10, 90 } },
	}

	it("hatches every egg by the ladder", function()
		for _, rarity in EggConfig.RARITY_ORDER do
			for size, percents in LADDER[rarity] do
				local chances = Loot.chances(EggConfig.hatchEntries(rarity, size :: EggConfig.SizeId))
				for position, tier in AlienConfig.TIER_ORDER do
					expect((chances[tier] or 0) * 100).toBeCloseTo(percents[position], 1e-6)
				end
			end
		end
	end)

	it("hatches a lucky egg (the star egg) as a large one", function()
		expect(EggConfig.oddsSize("Small", 1)).toBe("Large")
		expect(EggConfig.oddsSize("Small", 0)).toBe("Small")
		expect(EggConfig.oddsSize("Medium", nil)).toBe("Medium")
		expect(EggConfig.hatchEntries("Epic", "Small", SerpentConfig.STAR_EGG_LUCK)).toEqual(
			EggConfig.hatchEntries("Epic", "Large")
		)
	end)

	it("fills a fresh server with eggs no rarer than its cap, which still grows in zones", function()
		expect(EggConfig.RARITIES[EggConfig.FIRST_FILL_MAX_RARITY]).toBeTruthy()
		for _, id in ZoneConfig.ZONE_ORDER do
			local chances = Loot.chances(Loot.capped(ZoneConfig.ZONES[id].rarityLoot, EggConfig.FIRST_FILL_MAX_RARITY))
			expect(chances.Epic).toBeNil()
			expect(chances.Legendary).toBeNil()
			expect(chances[EggConfig.FIRST_FILL_MAX_RARITY] > 0).toBe(true)
		end
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

	it("keeps epic eggs out of the nearest zone and legendary ones in the far two", function()
		local near = Loot.chances(ZoneConfig.ZONES.DebrisBelt.rarityLoot)
		expect(near.Epic).toBeNil()
		expect(near.Legendary).toBeNil()
		expect(Loot.chances(ZoneConfig.ZONES.IceRings.rarityLoot).Legendary).toBeNil()
		expect(Loot.chances(ZoneConfig.ZONES.EventHorizon.rarityLoot).Legendary).toBeCloseTo(0.015, 1e-9)
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
		expect(BayConfig.CROSSBREED_COUNT <= BayConfig.SHELF_SLOTS).toBe(true)
		expect(BayConfig.SELL_MANY_MAX >= BayConfig.MAX_PODS + BayConfig.SHELF_SLOTS).toBe(true)
	end)

	it("crossbreeds a tier one up by the approved chances, the top tier staying on top", function()
		expect(BayConfig.CROSSBREED_UP_CHANCE).toEqual({
			Common = 0.43,
			Uncommon = 0.39,
			Rare = 0.33,
			Epic = 0.27,
			Legendary = 0,
		} :: any)
	end)
end)

describe("IndexConfig", function()
	it("holds every alien of the registry in exactly one set, by grade and variant", function()
		local seen: { [string]: boolean } = {}
		expect(#IndexConfig.SETS).toBe(#AlienConfig.GRADES * #AlienConfig.VARIANT_ORDER)
		for _, set in IndexConfig.SETS do
			expect(IndexConfig.SETS_BY_ID[set.id]).toBe(set)
			expect(set.id).toBe(AlienIndex.setId(set.grade, set.variant))
			expect(#set.aliens).toBe(#AlienConfig.GRADES[set.grade].kinds * #AlienConfig.TIER_ORDER)
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

	it("rings the islands around the station dome, apart and inside the border (decision 068)", function()
		local ring = StationSize.ISLAND_RING_RADIUS
		local dome = StationSize.ISLAND_DOME_RADIUS
		expect(StationSize.ISLAND_COUNT).toBe(ServerConfig.MAX_PLAYERS)
		expect(StationSize.ISLAND_DOME_RADIUS > StationSize.ISLAND_RADIUS).toBe(true)
		-- Neighbouring island domes do not touch.
		local neighbours = 2 * ring * math.sin(math.pi / StationSize.ISLAND_COUNT)
		expect(neighbours > 2 * dome).toBe(true)
		-- Nor does an island's dome touch the central one.
		expect(ring - dome > StationSize.DOME_RADIUS).toBe(true)
		-- The whole ring is inside the border, where guardians stop.
		expect(ring + dome < StationSize.BORDER_RADIUS).toBe(true)
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

describe("OxygenConfig", function()
	-- What a catch by guardian `post` takes from a thief with `stat` (Prey.catchShare).
	local function catchShare(stat: BigNum.BigNum, recommended: BigNum.BigNum): number
		local weakDecades = SpeedConfig.CHALLENGE_WEAK_DECADES
		return Oxygen.catchShare(
			Speed.challenge(stat, recommended, SpeedConfig.CHASE, weakDecades),
			Speed.standing(stat, recommended, SpeedConfig.CHASE, weakDecades),
			OxygenConfig.CATCH_SHARES
		)
	end

	it("takes more for a harder hunter, a part of the tank and never all of it (decision 112)", function()
		local shares = OxygenConfig.CATCH_SHARES
		expect(shares.weak > 0).toBe(true)
		expect(shares.weak < shares.fair).toBe(true)
		expect(shares.fair < shares.strong).toBe(true)
		expect(shares.strong < shares.tooStrong).toBe(true)
		expect(shares.tooStrong < 1).toBe(true)
		-- What one skull catch leaves never survives a second: re-grabbing the knocked-out egg
		-- under such a guardian ends in suffocation (the user: no carrying eggs far past you).
		expect(1 - shares.tooStrong < shares.tooStrong).toBe(true)
	end)

	it("a starting player loses most of the tank to the far guardians, little to the first", function()
		local start = SpeedConfig.STARTING_SPEED
		local posts = GuardianConfig.POSTS
		expect(catchShare(start, posts[1].recommended)).toBeCloseTo(OxygenConfig.CATCH_SHARES.fair)
		for index = 2, #posts do
			expect(catchShare(start, posts[index].recommended)).toBe(OxygenConfig.CATCH_SHARES.tooStrong)
		end
	end)

	it("a player at a guardian's recommended stat loses a tenth to it and less to the ones behind", function()
		local posts = GuardianConfig.POSTS
		for index = 2, #posts do
			local stat = posts[index].recommended
			expect(catchShare(stat, posts[index].recommended)).toBeCloseTo(OxygenConfig.CATCH_SHARES.fair)
			expect(catchShare(stat, posts[index - 1].recommended) < OxygenConfig.CATCH_SHARES.fair).toBe(true)
		end
	end)
end)

describe("SerpentConfig", function()
	it("measures every zone's serpent by that zone's power post", function()
		for _, zone in SerpentConfig.ZONES do
			local post = GuardianConfig.POSTS[ZoneConfig.postIndex(zone, SerpentConfig.POWER_POST)]
			expect(SerpentConfig.recommendedIn(zone)).toBe(post.recommended)
			expect(SerpentConfig.powerIn(zone)).toBe(post.speed)
		end
	end)

	it("comes out only in zones past the Debris Belt, all of them within its bounds", function()
		expect(table.find(SerpentConfig.ZONES, "DebrisBelt" :: ZoneConfig.ZoneId)).toBeNil()
		expect(#SerpentConfig.ZONES).toBe(#ZoneConfig.ZONE_ORDER - 1)
		for _, zone in SerpentConfig.ZONES do
			local ring = ZoneConfig.ZONES[zone]
			expect(ring.ringMin > SerpentConfig.INNER_RADIUS).toBe(true)
			expect(ring.ringMax <= SerpentConfig.OUTER_RADIUS).toBe(true)
		end
	end)

	it("lives past the station border, clear of every dome, out to the map's edge", function()
		local islandDomes = StationSize.ISLAND_RING_RADIUS + StationSize.ISLAND_DOME_RADIUS
		expect(SerpentConfig.INNER_RADIUS > StationSize.BORDER_RADIUS).toBe(true)
		expect(SerpentConfig.INNER_RADIUS > islandDomes).toBe(true)
		expect(SerpentConfig.INNER_RADIUS > StationSize.DOME_RADIUS).toBe(true)
		expect(SerpentConfig.OUTER_RADIUS).toBe(ZoneConfig.ZONES.EventHorizon.ringMax)
		-- Room for its sharpest turn on each side of where its waypoints may lie.
		local width = SerpentConfig.OUTER_RADIUS - SerpentConfig.INNER_RADIUS
		expect(width > SerpentConfig.ROUTE.turnRadius * 8).toBe(true)
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

	it("makes its egg lucky and epic or better", function()
		expect(SerpentConfig.STAR_EGG_LUCK > 0).toBe(true)
		expect(SerpentConfig.STAR_EGG_MIN_RARITY).toBe("Epic")
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
		for tier = 1, #MonetizationConfig.DOUBLE_TIER_LIMITS + 1 do
			expect(MonetizationConfig.productIdOf(catalog, "CollectDouble", tier)).toBeTruthy()
		end
		expect(catalog.passes.DoubleTraining).toBeTruthy()
		expect(catalog.passes.NightShift).toBeTruthy()
	end)

	it("lists in the shop every pass and training pack the game sells", function()
		local catalog = assert(MonetizationConfig.catalogFor(10774871729))
		for pass in catalog.passes do
			expect(table.find(MonetizationConfig.PASS_ORDER, pass)).toBeTruthy()
		end
		for _, product in catalog.products do
			if product.kind == "Training" then
				expect(table.find(MonetizationConfig.TRAINING_PACK_SECONDS, product.seconds :: number)).toBeTruthy()
			end
		end
		-- The shop names them: 1 hour, 8 hours, a day (StoreController.TRAINING_TITLES).
		expect(MonetizationConfig.TRAINING_PACK_SECONDS[1]).toBe(3600)
		expect(MonetizationConfig.TRAINING_PACK_SECONDS[2]).toBe(8 * 3600)
		expect(MonetizationConfig.TRAINING_PACK_SECONDS[3]).toBe(24 * 3600)
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

	it("prices collect x2 from a small time away to the biggest one", function()
		expect(MonetizationConfig.doubleTierOf(BigNum.fromNumber(500))).toBe(1)
		expect(MonetizationConfig.doubleTierOf(BigNum.fromNumber(2.5e7))).toBe(3)
		expect(MonetizationConfig.doubleTierOf(BigNum.fromNumber(5e12))).toBe(
			#MonetizationConfig.DOUBLE_TIER_LIMITS + 1
		)
		expect(BigNum.toNumber(assert(MonetizationConfig.doubleLimitOf(1)))).toBe(1e6)
		expect(MonetizationConfig.doubleLimitOf(#MonetizationConfig.DOUBLE_TIER_LIMITS + 1)).toBeNil()
		local limits = MonetizationConfig.DOUBLE_TIER_LIMITS
		for tier = 2, #limits do
			expect(limits[tier] > limits[tier - 1]).toBe(true)
		end
	end)

	it("covers every bought slot with a tier", function()
		expect(MonetizationConfig.SLOT_TIER_LAST[#MonetizationConfig.SLOT_TIER_LAST]).toBe(
			BayConfig.MAX_INCUBATOR_SLOTS
		)
	end)
end)
