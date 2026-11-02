--!strict

local Signal = require("../../src/shared/Runtime/Signal")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Signal", function()
	it("calls listeners in connection order with the fired arguments", function()
		local signal = Signal.new() :: Signal.Signal<string, number>
		local calls: { string } = {}
		signal.connect(function(name, count)
			table.insert(calls, `first {name} {count}`)
		end)
		signal.connect(function(name, count)
			table.insert(calls, `second {name} {count}`)
		end)

		signal.fire("egg", 3)

		expect(calls).toEqual({ "first egg 3", "second egg 3" })
	end)

	it("stops calling a disconnected listener", function()
		local signal = Signal.new() :: Signal.Signal<>
		local count = 0
		local connection = signal.connect(function()
			count += 1
		end)

		signal.fire()
		connection.disconnect()
		connection.disconnect()
		signal.fire()

		expect(count).toBe(1)
		expect(connection.isConnected()).toBe(false)
	end)

	it("lets a listener disconnect itself while firing", function()
		local signal = Signal.new() :: Signal.Signal<>
		local calls = 0
		local connection: Signal.Connection
		connection = signal.connect(function()
			calls += 1
			connection.disconnect()
		end)
		signal.connect(function()
			calls += 1
		end)

		signal.fire()
		signal.fire()

		expect(calls).toBe(3)
	end)

	it("disconnects everything at once", function()
		local signal = Signal.new() :: Signal.Signal<>
		local count = 0
		signal.connect(function()
			count += 1
		end)

		signal.disconnectAll()
		signal.fire()

		expect(count).toBe(0)
	end)
end)
