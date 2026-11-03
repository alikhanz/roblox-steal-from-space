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
}

-- The owner's bay, as the profile holds it.
type Bay = struct {
	pods: Pod[],
	inventory: Alien[],
	floor: Alien[],
	incubator: Egg[],
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

-- What the pods earned while the player was away.
event OfflineReward = {
	from: Server,
	type: Reliable,
	call: SingleSync,
	data: struct {
		coins: BigNum,
		seconds: f64,
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

-- The client asks for its snapshot once its controllers are ready, in case the profile
-- activated before they were.
event RequestSnapshot = {
	from: Client,
	type: Reliable,
	call: SingleSync,
}
