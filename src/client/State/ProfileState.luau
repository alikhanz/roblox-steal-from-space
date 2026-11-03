--!strict
-- The client's copy of its own profile, as Vide sources the UI reads. Filled only by the
-- server (a snapshot, then the section that changed); nothing here writes back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

export type Alien = { uid: number, id: string }
export type Pod = { alien: Alien? }
export type Egg = { uid: number, rarity: string, size: string, grade: number, hatchAt: number }
export type Bay = { pods: { Pod }, inventory: { Alien }, floor: { Alien }, incubator: { Egg } }
export type Location = "Pod" | "Inventory" | "Floor"
export type Notice =
	"NoProfile"
	| "UnknownAlien"
	| "InventoryFull"
	| "NotEnoughCoins"
	| "MaxPods"
	| "NoSuchPod"
	| "WrongCount"
	| "MixedGrades"
	| "TooFast"

export type ProfileState = {
	name: string,
	start: () -> (),
	coins: Vide.Source<BigNum.BigNum>,
	bay: Vide.Source<Bay>,
	-- True once the first snapshot arrived.
	loaded: Vide.Source<boolean>,
	-- Offline income paid on login: the amount and the seconds it covered.
	offlineReward: Signal.Signal<BigNum.BigNum, number>,
	-- An alien hatched or was crossbred.
	hatched: Signal.Signal<string, Location>,
	notice: Signal.Signal<Notice>,
}

local ProfileState = {}

local function emptyBay(): Bay
	return { pods = {}, inventory = {}, floor = {}, incubator = {} }
end

function ProfileState.new(): ProfileState
	local coins = source(BigNum.ZERO)
	local bay = source(emptyBay())
	local loaded = source(false)
	local offlineReward = Signal.new() :: Signal.Signal<BigNum.BigNum, number>
	local hatched = Signal.new() :: Signal.Signal<string, Location>
	local notice = Signal.new() :: Signal.Signal<Notice>

	local function readCoins(value: { mantissa: number, exponent: number })
		local restored = BigNum.fromSaved(value)
		if restored then
			coins(restored)
		else
			warn("[ProfileState] Coins arrived in an unknown shape; kept the old value")
		end
	end

	local function start()
		Remotes.ProfileSnapshot.SetCallback(function(snapshot)
			readCoins(snapshot.coins)
			bay(snapshot.bay)
			loaded(true)
		end)
		Remotes.CoinsChanged.SetCallback(readCoins)
		Remotes.BayChanged.SetCallback(function(value)
			bay(value)
		end)
		Remotes.OfflineReward.SetCallback(function(reward)
			local earned = BigNum.fromSaved(reward.coins)
			if earned then
				offlineReward.fire(earned, reward.seconds)
			end
		end)
		Remotes.Hatched.SetCallback(function(event)
			hatched.fire(event.alienId, event.location)
		end)
		Remotes.NoticeSent.SetCallback(function(value)
			notice.fire(value)
		end)
		-- The profile may have activated before these callbacks were set.
		Remotes.RequestSnapshot.Fire()
	end

	return {
		name = "ProfileState",
		start = start,
		coins = coins,
		bay = bay,
		loaded = loaded,
		offlineReward = offlineReward,
		hatched = hatched,
		notice = notice,
	}
end

return table.freeze(ProfileState)
