--!strict
-- Minimal typed signal. Listeners run synchronously, in connection order;
-- a listener error propagates to the caller of `fire`, so failures stay visible.

export type Connection = {
	disconnect: () -> (),
	isConnected: () -> boolean,
}

export type Signal<T...> = {
	connect: (listener: (T...) -> ()) -> Connection,
	fire: (T...) -> (),
	disconnectAll: () -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local listeners: { (T...) -> () } = {}

	local function connect(listener: (T...) -> ()): Connection
		table.insert(listeners, listener)
		local connected = true
		return {
			disconnect = function()
				if not connected then
					return
				end
				connected = false
				local index = table.find(listeners, listener)
				if index then
					table.remove(listeners, index)
				end
			end,
			isConnected = function()
				return connected
			end,
		}
	end

	local function fire(...: T...)
		-- Snapshot, so listeners may connect or disconnect while the signal fires.
		for _, listener in table.clone(listeners) do
			listener(...)
		end
	end

	local function disconnectAll()
		table.clear(listeners)
	end

	return {
		connect = connect,
		fire = fire,
		disconnectAll = disconnectAll,
	}
end

return table.freeze(Signal)
