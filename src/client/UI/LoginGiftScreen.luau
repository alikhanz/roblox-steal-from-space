--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The login gift screen: a tile per streak day with what it gives. Days already taken are
-- ticked, today's tile glows and pulses, the days ahead show their gifts; the last day also
-- shows its egg. Texts come in resolved. `burst` throws sparks out of a tile for the claim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Button = require(script.Parent.Button)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

-- Seven tiles in a row plus the padding.
local MAX_WIDTH = 650
local PADDING = 18
local GAP = 10
local TITLE_TEXT_SIZE = 28
local HINT_TEXT_SIZE = 16
local TILE_SIZE = Vector2.new(74, 104)
local TILE_GAP = 8
local DAY_TEXT_SIZE = 15
local VALUE_TEXT_SIZE = 13
local CHECK_TEXT_SIZE = 30
-- The sparks of a claim.
local SPARK_COUNT = 14
local SPARK_SIZE = 12
local SPARK_DISTANCE = 140
local SPARK_SECONDS = 0.8
-- The tile of the claim swells and snaps back.
local POP_SCALE = 1.35
local POP_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true)

export type TileState = "Taken" | "Today" | "Ahead"

export type Tile = {
	-- "Day 3"
	title: string,
	coins: string,
	speed: string,
	-- The egg the day adds, or nil.
	egg: string?,
	state: TileState,
}

export type Props = {
	visible: () -> boolean,
	tiles: () -> { Tile },
	title: string,
	-- The line under the title: keep the streak going, it started over, or when the next gift is.
	hint: () -> string,
	claim: string,
	later: string,
	canClaim: () -> boolean,
	-- Today's tile breathes: a scale around 1.
	pulse: () -> number,
	onClaim: () -> (),
	onClose: () -> (),
}

local LoginGiftScreen = {}

local function line(name: string, order: number, text: () -> string, size: number, color: Color3): TextLabel
	return create("TextLabel")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, size + 2),
		BackgroundTransparency = 1,
		FontFace = Theme.FONT,
		TextSize = size,
		TextColor3 = color,
		TextWrapped = true,
		Text = text,
	}) :: TextLabel
end

local function tile(props: Props, index: number): Frame
	local function entry(): Tile?
		return props.tiles()[index]
	end
	local function state(): TileState
		local current = entry()
		return if current then current.state else "Ahead"
	end
	local scale = Instance.new("UIScale")
	Vide.effect(function()
		scale.Scale = if state() == "Today" then props.pulse() else 1
	end)
	return create("Frame")({
		Name = `Day{index}`,
		LayoutOrder = index,
		BackgroundColor3 = function()
			return if state() == "Today" then Theme.SELECTED else Theme.PANEL
		end,
		BackgroundTransparency = function()
			return if state() == "Taken" then 0.5 else 0
		end,
		Visible = function()
			return entry() ~= nil
		end,
		create("UICorner")({ CornerRadius = Theme.CORNER }),
		Layout.stroke(Theme.COINS, 3, function()
			return state() == "Today"
		end),
		Layout.padding(4, 6),
		scale,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		line("Title", 1, function()
			local current = entry()
			return if current then current.title else ""
		end, DAY_TEXT_SIZE, Theme.TEXT),
		create("TextLabel")({
			Name = "Check",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, CHECK_TEXT_SIZE + 2),
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = CHECK_TEXT_SIZE,
			TextColor3 = Theme.TOAST_GOOD,
			Text = "✓",
			Visible = function()
				return state() == "Taken"
			end,
		}),
		line("Coins", 3, function()
			local current = entry()
			return if current then `+{current.coins} ●` else ""
		end, VALUE_TEXT_SIZE, Theme.COINS),
		line("Speed", 4, function()
			local current = entry()
			return if current then `+{current.speed} ⚡` else ""
		end, VALUE_TEXT_SIZE, Theme.SPEED),
		create("TextLabel")({
			Name = "Egg",
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, VALUE_TEXT_SIZE * 2 + 2),
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = VALUE_TEXT_SIZE,
			TextColor3 = Theme.OXYGEN,
			TextWrapped = true,
			Text = function()
				local current = entry()
				return if current and current.egg then `+ {current.egg}` else ""
			end,
			Visible = function()
				local current = entry()
				return current ~= nil and current.egg ~= nil
			end,
		}),
	}) :: Frame
end

function LoginGiftScreen.create(props: Props, dayCount: number): Frame
	local tiles = {}
	for index = 1, dayCount do
		table.insert(tiles, tile(props, index))
	end

	return create("Frame")({
		Name = "LoginGift",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.94, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = 0.02,
		Visible = props.visible,
		ZIndex = 5,
		create("UICorner")({ CornerRadius = Theme.CORNER }),
		Layout.maxSize(MAX_WIDTH, math.huge),
		Layout.padding(PADDING, PADDING),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		line("Title", 1, function()
			return props.title
		end, TITLE_TEXT_SIZE, Theme.TEXT),
		line("Hint", 2, props.hint, HINT_TEXT_SIZE, Theme.MUTED),

		create("Frame")({
			Name = "Days",
			LayoutOrder = 3,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			-- Seven in a row on a wide screen, wrapping onto two rows on a phone.
			create("UIGridLayout")({
				CellSize = UDim2.fromOffset(TILE_SIZE.X, TILE_SIZE.Y),
				CellPadding = UDim2.fromOffset(TILE_GAP, TILE_GAP),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			tiles,
		}),

		create("Frame")({
			Name = "Buttons",
			LayoutOrder = 4,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("Frame")({
				Name = "ClaimSlot",
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Visible = props.canClaim,
				Button({
					name = "Claim",
					text = props.claim,
					color = Theme.COINS_DARK,
					onClick = props.onClaim,
				}),
			}),
			Button({
				name = "Later",
				layoutOrder = 2,
				text = props.later,
				color = Theme.ACCENT,
				onClick = props.onClose,
			}),
		}),
	}) :: Frame
end

-- Celebrates a claim on the tile of `day` inside `screen`: the tile pops and sparks fly out of
-- it in the tile's color, drawn in `layer` (a ScreenGui) above everything.
function LoginGiftScreen.burst(screen: Instance, layer: ScreenGui, day: number, color: Color3)
	local target = screen:FindFirstChild(`Day{day}`, true)
	if not target or not target:IsA("GuiObject") then
		return
	end
	local scale = target:FindFirstChildOfClass("UIScale")
	if scale then
		TweenService:Create(scale, POP_TWEEN, { Scale = POP_SCALE }):Play()
	end
	local center = target.AbsolutePosition + target.AbsoluteSize / 2
	local random = Random.new()
	for index = 1, SPARK_COUNT do
		-- A little diamond: a turned square (a glyph would depend on the font having it).
		local spark = Instance.new("Frame")
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Position = UDim2.fromOffset(center.X, center.Y)
		spark.Size = UDim2.fromOffset(SPARK_SIZE, SPARK_SIZE)
		spark.Rotation = 45
		spark.BackgroundColor3 = color
		spark.BorderSizePixel = 0
		spark.ZIndex = 20
		spark.Parent = layer
		local angle = (index / SPARK_COUNT + random:NextNumber(-0.03, 0.03)) * math.pi * 2
		local distance = SPARK_DISTANCE * random:NextNumber(0.6, 1)
		local goal = center + Vector2.new(math.cos(angle), math.sin(angle)) * distance
		local flight = TweenInfo.new(SPARK_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(spark, flight, {
			Position = UDim2.fromOffset(goal.X, goal.Y),
			BackgroundTransparency = 1,
			Rotation = 45 + random:NextNumber(-90, 90),
		})
		tween:Play()
		tween.Completed:Once(function()
			spark:Destroy()
		end)
	end
end

return table.freeze(LoginGiftScreen)
