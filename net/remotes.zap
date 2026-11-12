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
	-- The shelf (decision 110).
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
	-- The shelf has no free niche (decision 110).
	ShelfFull,
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
	-- The community gift: Roblox does not show the player in the game's community (yet), or did
	-- not answer.
	NotInCommunity,
	-- Crossbreeding: only aliens of one tier go together (decision 113).
	MixedTiers,
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

-- What the tutorial asks of the player now (Domain/Tutorial.Hint).
type TutorialHint = enum {
	Steal,
	CarryHome,
	Hatch,
	Train,
	StealStronger,
	CarryHomeStronger,
	Done,
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

-- The tutorial hint changed; also sent on login and with a requested snapshot. Done right after
-- another hint means the player has just finished it.
event TutorialChanged = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: TutorialHint,
}

-- The hint after the tutorial to show now (Domain/Coach, decision 110); none: no hint.
type CoachTip = enum {
	Shelf,
	Jetpack,
	Quest,
	Crossbreed,
	Sell,
}

event CoachChanged = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: CoachTip?,
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
		location: enum { Pod, Floor },
	},
}

-- Three aliens became one (see Crossbreed below).
event Crossbred = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		alienId: string.utf8,
		location: enum { Pod, Floor },
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

-- Someone fired the harpoon (to every client, which draws the hook: World/HarpoonVisual). `target`
-- is where the hook flies: the target's surface, or the end of its reach on a miss. `aim`: the
-- direction it was fired in (a miss flies out along it, moving with the shooter). `egg`: an egg
-- came loose there and drifts towards the shooter, the hook rides it.
event HarpoonShot = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		shooter: Instance.Player,
		target: Vector3,
		aim: Vector3,
		hit: boolean,
		egg: boolean,
	},
}

-- Someone threw the gravity bomb (to every client, which draws it: World/BombVisual). It flies
-- from `start` at `velocity` until BombExploded with the same `id`, at most `fuse` seconds,
-- steering for `target` (a root part; nil: straight) as Domain/Homing does on the server.
event BombThrown = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		id: u16,
		thrower: Instance.Player,
		start: Vector3,
		velocity: Vector3,
		fuse: f32,
		target: Instance.BasePart?,
	},
}

-- The bomb `id` went off at `center`.
event BombExploded = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		id: u16,
		center: Vector3,
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

-- The community gift was paid (decision 098): the speed stat it added (with the jetpack).
event CommunityRewarded = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: BigNum,
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

-- From a pod onto the shelf.
event MoveToShelf = {
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

-- Sells all of them at once, or none ("Sell all", decision 110; BayConfig.SELL_MANY_MAX).
event SellMany = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: u32[1..64],
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

-- Whom the client's harpoon lock is on right now (World/AimTargets: the egg carrier nearest the
-- crosshair), sent when it changes; nil: nobody. The server hits that one on the next shot if it
-- is near enough to its own view of the aim, allowing for what the client sees lagging behind
-- (PvpService, decision 106).
event HarpoonLock = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: struct {
		target: Instance.BasePart?,
	},
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

-- The client is about to show Roblox's prompt to join the game's community (analytics).
event CommunityPrompted = {
	from: Client,
	type: Reliable,
	call: SingleSync,
}

-- Roblox's community prompt says the player joined (or already was in): the server asks Roblox
-- itself and pays the gift if so. Nothing is taken on the client's word.
event CommunityJoined = {
	from: Client,
	type: Reliable,
	call: SingleSync,
}

-- "Don't show again" in the controls window was ticked (true) or cleared (false): the server
-- keeps it in the profile (decision 105). It changes nothing in play.
event SetControlsHidden = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: boolean,
}

-- The client asks for its snapshot once its controllers are ready, in case the profile
-- activated before they were.
event RequestSnapshot = {
	from: Client,
	type: Reliable,
	call: SingleSync,
}

-- The pet bench for measuring on a phone (BenchService, decision 082): true fills the island
-- with 30 aliens, false takes them away. The server ignores anyone not allowed.
event Bench = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: boolean,
}

-- Display guardians round the player (BenchService.showGuardians): Bench sets the Event Horizon's
-- 42 guardians for a phone measurement, Gallery one guardian of every post to look at, Off takes
-- either away. The server ignores anyone not allowed.
type GuardianDisplay = enum {
	Off,
	Bench,
	Gallery,
}

event BenchGuardians = {
	from: Client,
	type: Reliable,
	call: SingleSync,
	data: GuardianDisplay,
}
