-- Network contract between server and client.
-- Generated modules are written to src/{server,client}/Net/Remotes.luau by `lune run net`.
-- Docs: https://zap.redblox.dev

-- Output paths are relative to this file.
opt server_output = "../src/server/Net/Remotes.luau"
opt client_output = "../src/client/Net/Remotes.luau"
opt remote_scope = "STEAL_FROM_SPACE"
opt casing = "PascalCase"
opt write_checks = true

-- Same shape as Domain/BigNum, so a value crosses the wire as it is saved.
type BigNum = struct {
	mantissa: f64,
	exponent: i32,
}

type Alien = struct {
	uid: u32,
	id: string.utf8,
}

type Pod = struct {
	alien: Alien?,
}

type Egg = struct {
	uid: u32,
	rarity: string.utf8,
	size: string.utf8,
	grade: u8,
	-- Server (Unix) time the egg hatches.
	hatchAt: f64,
	-- The alien variant it hatches into; none: the usual one.
	variant: string.utf8?,
	-- Luck on top of its rarity's and size's (delivered in the star serpent's hunt); none: none.
	luck: f32?,
}

-- An egg waiting for an incubator slot: it takes this long to hatch once in one.
type WaitingEgg = struct {
	uid: u32,
	rarity: string.utf8,
	size: string.utf8,
	grade: u8,
	hatchSeconds: f32,
	variant: string.utf8?,
	luck: f32?,
}

-- The owner's bay, as the profile holds it.
type Bay = struct {
	pods: Pod[],
	inventory: Alien[],
	floor: Alien[],
	incubator: Egg[],
	incubatorSlots: u8,
	waiting: WaitingEgg[],
}

-- The owner's upgrade levels (the speed stat itself travels as player attributes).
type Upgrades = struct {
	trainerLevel: u16,
	jetpackLevel: u16,
}

-- Why a command was refused, for a toast on the client.
type Notice = enum {
	NoProfile,
	UnknownAlien,
	InventoryFull,
	NotEnoughCoins,
	MaxPods,
	NoSuchPod,
	WrongCount,
	MixedGrades,
	TooFast,
	-- Abilities (PvP).
	NotReady,
	AttackerInStation,
	VictimInStation,
	AttackerNewbie,
	VictimNewbie,
	VictimJustSpawned,
	VictimTooWeak,
	-- Daily quests.
	NoSuchQuest,
	QuestNotDone,
	QuestClaimed,
	RerollUsed,
	QuestDone,
	NoOtherQuest,
	-- Login gift.
	GiftTaken,
	-- Alien index.
	IndexNothing,
	IndexClaimed,
	-- Solar storm: you were brought back to the station.
	StormTeleport,
	-- Crossbreeding: meteor aliens only go with meteor aliens.
	MixedVariants,
	-- The jetpack is at its top level (Infinity): there is no next one.
	JetpackTop,
	-- The incubator has every slot there can be.
	MaxIncubatorSlots,
	-- "Egg ready now": that egg is not warming in the incubator (ready, hatched or gone).
	NoSuchEgg,
}

-- The alien index (Domain/AlienIndex): alien id -> its reward is taken (present: found), and the
-- ids of the sets whose reward is taken.
type Index = struct {
	found: map { [string.utf8]: boolean },
	sets: string.utf8[],
}

-- Where the login gift streak stands today (Domain/LoginGift).
type LoginGift = struct {
	-- The streak day of today's gift (or of the one taken today), 1..7.
	day: u8,
	available: boolean,
	-- A missed day started the streak over.
	reset: boolean,
	-- A brand-new player's first gift waits for their first delivered egg.
	locked: boolean,
}

type QuestKind = enum {
	DeliverEggs,
	DeliverFromZone,
	HatchAliens,
	Train,
	Crossbreed,
	KnockEgg,
}

-- One of today's quests (Domain/Quests); Train counts seconds.
type Quest = struct {
	kind: QuestKind,
	target: u32,
	progress: f64,
	claimed: boolean,
	zone: string.utf8?,
}

-- Today's quests: the UTC day they are for and whether the day's swap is used.
type Quests = struct {
	day: u32,
	rerolled: boolean,
	list: Quest[],
}

type AbilityKind = enum {
	Strike,
	Harpoon,
	Bomb,
}

-- Robux purchases (decision 061, MonetizationConfig): what a developer product does.
type ProductKind = enum {
	Training,
	ReadyNow,
	IncubatorSlot,
	CollectDouble,
}

-- Everything the game offers for Robux: the passes and the product kinds.
type ShopItem = enum {
	DoubleTraining,
	NightShift,
	Training,
	ReadyNow,
	IncubatorSlot,
	CollectDouble,
}

-- Where a purchase was offered: the shop window (opened from the menu or from the speed goal),
-- the welcome-back screen, the bay window, the prompt on a warming egg.
type ShopSource = enum {
	Store,
	Goal,
	Welcome,
	Bay,
	Egg,
}

-- Server -> client: the owner's private data. A snapshot on login, then the section that changed.

event ProfileSnapshot = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		coins: BigNum,
		bay: Bay,
		upgrades: Upgrades,
		quests: Quests,
		loginGift: LoginGift,
		index: Index,
	},
}

event IndexChanged = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: Index,
}

-- An index reward was taken: the coins it paid.
event IndexRewarded = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: BigNum,
}

event LoginGiftChanged = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: LoginGift,
}

-- Today's gift was taken: what it paid (speed as the stat shows it) and whether an egg came.
event LoginGiftRewarded = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		day: u8,
		coins: BigNum,
		speed: BigNum,
		egg: boolean,
	},
}

event QuestsChanged = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: Quests,
}

-- A claimed quest paid out: coins and the speed stat gained (with the jetpack multiplier).
event QuestRewarded = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		coins: BigNum,
		speed: BigNum,
	},
}

event CoinsChanged = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: BigNum,
}

event UpgradesChanged = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: Upgrades,
}

-- One payout of the trainer: speed points gained this tick, for the floating number.
event Trained = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: BigNum,
}

event BayChanged = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: Bay,
}

-- What the pods earned and the trainer added while the player was away, and how many eggs are
-- ready to hatch.
event OfflineReward = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		coins: BigNum,
		speed: BigNum,
		seconds: f64,
		readyEggs: u8,
		-- The "Collect x2" tier that pays this time away once more (its price grows with the
		-- reward, decision 064); 0 when there is nothing to pay.
		doubleTier: u8,
	},
}

event Hatched = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		alienId: string.utf8,
		location: enum { Pod, Inventory, Floor },
	},
}

-- Three aliens became one (see Crossbreed below).
event Crossbred = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		alienId: string.utf8,
		location: enum { Pod, Inventory, Floor },
	},
}

-- An ability the player used has resolved: did it land, did an egg come loose.
event AbilityResult = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		kind: AbilityKind,
		hit: boolean,
		droppedEgg: boolean,
	},
}

-- A Robux purchase was granted: what it was, and the coins and speed stat it gave. Compensated:
-- it found nothing to apply to (the egg hatched, every slot bought) and paid coins instead.
event Purchased = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		kind: ProductKind,
		compensated: boolean,
		coins: BigNum,
		speed: BigNum,
		-- "Egg ready now" hatched the egg at once (the hatch has its own announcement).
		hatched: boolean,
	},
}

event NoticeSent = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: Notice,
}

-- Client -> server: intentions. The server checks every one (CONVENTIONS, section 5).

event AutoPlace = {
	from: Client,
	type: Reliable,
	call: SingleSync,
}

event MoveToPod = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: struct {
		uid: u32,
		pod: u8,
	},
}

event MoveToInventory = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: u32,
}

-- Three aliens of one grade (BayConfig.CROSSBREED_COUNT).
event Crossbreed = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: u32[3],
}

event Sell = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: u32,
}

event BuyPod = {
	from: Client,
	type: Reliable,
	call: SingleSync,
}

-- One more incubator slot.
event BuyIncubatorSlot = {
	from: Client,
	type: Reliable,
	call: SingleSync,
}

-- The next jetpack level, from the shop window.
event UpgradeJetpack = {
	from: Client,
	type: Reliable,
	call: SingleSync,
}

-- The next trainer level, from the sign over the trainer pad.
event UpgradeTrainer = {
	from: Client,
	type: Reliable,
	call: SingleSync,
}

-- Today's quest at this place in the list (1-based).
event ClaimQuest = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: u8,
}

-- Takes the index reward of a found alien.
event ClaimIndexAlien = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: string.utf8,
}

-- Takes the index reward of a full guardian set, by set id ("3", "3.Meteor").
event ClaimIndexSet = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: string.utf8,
}

-- Takes every reward waiting in the index at once.
event ClaimIndexAll = {
	from: Client,
	type: Reliable,
	call: SingleSync,
}

-- Takes today's login gift.
event ClaimLoginGift = {
	from: Client,
	type: Reliable,
	call: SingleSync,
}

-- The day's one swap, for the quest at this place.
event RerollQuest = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: u8,
}

-- The client is about to show Roblox's purchase prompt: where it was offered (analytics) and, for
-- "Egg ready now", the egg it is for. The purchase itself is granted only by its receipt.
event PurchasePrompted = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: struct {
		item: ShopItem,
		source: ShopSource,
		egg: u32?,
	},
}

-- The client asks for its snapshot once its controllers are ready, in case the profile
-- activated before they were.
event RequestSnapshot = {
	from: Client,
	type: Reliable,
	call: SingleSync,
}
