--!strict
-- The friend bonus (decision 128, Domain/FriendBonus): while a player's Roblox friends play on
-- the same server, the player's aliens bring more coins. Pure Luau: tests load it in Lune.

local FriendConfig = {}

-- Extra income for each friend on the server, percent.
FriendConfig.PERCENT_PER_FRIEND = 10
-- Friends past this many add nothing more (+30 %: a server of 8 would otherwise give +70 %).
FriendConfig.MAX_FRIENDS = 3

-- Asking Roblox whether two players are friends: this many tries, this far apart, seconds.
FriendConfig.CHECK_ATTEMPTS = 3
FriendConfig.CHECK_RETRY_SECONDS = 2

-- Player attribute: how many of the player's friends play on this server now (not capped; the
-- client works the bonus out of it with Domain/FriendBonus). None: not counted yet.
FriendConfig.FRIENDS_ATTRIBUTE = "FriendsHere"

-- Analytics: how often the minutes played with the bonus are counted, seconds.
FriendConfig.METRICS_MINUTE_SECONDS = 60
-- A client reports at most this often how many invites a prompt sent, seconds.
FriendConfig.INVITE_REPORT_SECONDS = 2

return table.freeze(FriendConfig)
