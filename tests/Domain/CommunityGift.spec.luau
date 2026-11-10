--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local CommunityGift = require("../../src/shared/Domain/CommunityGift")
local Test = require("../../lune/lib/Test")
local Tutorial = require("../../src/shared/Domain/Tutorial")
local UpgradeConfig = require("../../src/shared/Config/UpgradeConfig")
local describe, it, expect = Test.describe, Test.it, Test.expect

local GIFT = BigNum.fromNumber(10000)
local COMMUNITY = 1096766348

local function profile(tutorialStep: number, taken: boolean): CommunityGift.Profile
	return { trained = BigNum.fromNumber(50), tutorialStep = tutorialStep, communityGiftTaken = taken }
end

local function trainedOf(data: CommunityGift.Profile): number
	return BigNum.toNumber(data.trained)
end

describe("CommunityGift.isOffered", function()
	it("is offered once the tutorial is done", function()
		expect(CommunityGift.isOffered(profile(Tutorial.DONE, false))).toBe(true)
	end)

	it("waits for the end of the tutorial", function()
		for step = Tutorial.NOT_STARTED, Tutorial.DONE - 1 do
			expect(CommunityGift.isOffered(profile(step, false))).toBe(false)
		end
	end)

	it("is not offered once taken", function()
		expect(CommunityGift.isOffered(profile(Tutorial.DONE, true))).toBe(false)
	end)
end)

describe("CommunityGift.claim", function()
	it("adds the gift to the trained speed and marks it taken", function()
		local data = profile(Tutorial.DONE, false)
		expect(CommunityGift.claim(data, GIFT)).toBe(true)
		expect(trainedOf(data)).toBe(10050)
		expect(data.communityGiftTaken).toBe(true)
	end)

	it("pays once per profile: leaving and joining again pays nothing", function()
		local data = profile(Tutorial.DONE, false)
		expect(CommunityGift.claim(data, GIFT)).toBe(true)
		-- The next join finds the player in the community again (or after rejoining it).
		expect(CommunityGift.claim(data, GIFT)).toBe(false)
		expect(trainedOf(data)).toBe(10050)
	end)

	it("pays a player who joined while away, on their next join", function()
		-- Joined the community outside the game: the profile still has the gift waiting, and the
		-- check at login finds them in it.
		local data = profile(Tutorial.DONE, false)
		expect(CommunityGift.claim(data, GIFT)).toBe(true)
		expect(trainedOf(data)).toBe(10050)
	end)

	it("pays nothing during the tutorial and keeps the gift for later", function()
		local data = profile(Tutorial.TRAINED, false)
		expect(CommunityGift.claim(data, GIFT)).toBe(false)
		expect(trainedOf(data)).toBe(50)
		expect(data.communityGiftTaken).toBe(false)
		data.tutorialStep = Tutorial.DONE
		expect(CommunityGift.claim(data, GIFT)).toBe(true)
	end)
end)

describe("CommunityGift.shown", function()
	it("is the gift itself with the starting jetpack", function()
		expect(BigNum.toNumber(CommunityGift.shown(GIFT, 0, UpgradeConfig.TUNING))).toBe(10000)
	end)

	it("grows with the jetpack's multiplier", function()
		-- Level 9 is the fifth jetpack's first mark: x32.
		expect(BigNum.toNumber(CommunityGift.shown(GIFT, 9, UpgradeConfig.TUNING))).toBe(320000)
	end)
end)

describe("CommunityGift.isMember", function()
	it("finds the community among the player's groups", function()
		local groups = { { Id = 1, Name = "Other" }, { Id = COMMUNITY, Name = "Fly & Steal Space Eggs" } }
		expect(CommunityGift.isMember(groups, COMMUNITY)).toBe(true)
	end)

	it("is false without it", function()
		expect(CommunityGift.isMember({ { Id = 1 } }, COMMUNITY)).toBe(false)
		expect(CommunityGift.isMember({}, COMMUNITY)).toBe(false)
	end)

	it("skips entries that are not groups", function()
		expect(CommunityGift.isMember({ "x", 5, { Id = COMMUNITY } } :: { any }, COMMUNITY)).toBe(true)
	end)
end)
