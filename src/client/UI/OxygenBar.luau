--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The oxygen tank in the HUD's bottom stack (docs/design/screens/hud.md): the bubble icon, a
-- glass bar and the percent left; red, with a warning above it, when the tank runs low. A catch
-- (a sudden drop, decision 112) leaves the lost piece of the bar lit for a moment, melting to
-- the new edge, and the loss in percent beside the bar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
local WIDTH = 253
local BAR_HEIGHT = 14
local ICON_SIZE = 24
local GAP = 7
local PERCENT_WIDTH = 38
-- The fill runs from deep to light blue.
local FILL_FROM = Color3.fromHex("#1F9AD8")
local FILL_TO = Color3.fromHex("#78D6E8")
-- A drop of this share of the tank at once is a catch, not the drain (a second in space takes
-- 1/180 of it, a guardian's catch at least 5 %).
local DROP_SHARE = 0.02
-- The lost piece melts to the new edge in this time; the loss in percent fades out in this one.
local LOST_PIECE_SECONDS = 0.8
local LOST_TEXT_SECONDS = 1.5

export type Props = {
	-- Share of a full tank, 0..1.
	fraction: () -> number,
	isLow: () -> boolean,
	visible: () -> boolean,
	warningText: string,
	layoutOrder: number,
}

local function OxygenBar(props: Props): Frame
	local fillGradient = Instance.new("UIGradient")
	Vide.effect(function()
		fillGradient.Color = if props.isLow()
			then ColorSequence.new(NEON.DANGER)
			else ColorSequence.new(FILL_FROM, FILL_TO)
	end)

	-- The lost piece: over the empty part of the bar, from the new edge to where the fill was.
	local lostPiece = create("Frame")({
		Name = "Lost",
		BorderSizePixel = 0,
		BackgroundColor3 = NEON.DANGER,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0, 1),
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
	}) :: Frame
	local lostStroke = Layout.textStroke()
	local lostText = create("TextLabel")({
		Name = "LostPercent",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, GAP, 0.5, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		FontFace = NEON.FONT,
		TextSize = NEON.TEXT_BODY,
		TextColor3 = NEON.DANGER,
		TextTransparency = 1,
		Text = "",
		lostStroke,
	}) :: TextLabel
	lostStroke.Transparency = 1

	local tweens: { Tween } = {}
	local function play(instance: Instance, seconds: number, style: Enum.EasingStyle, goal: { [string]: any })
		local tween = TweenService:Create(instance, TweenInfo.new(seconds, style, Enum.EasingDirection.In), goal)
		table.insert(tweens, tween)
		tween:Play()
	end
	local function stopTweens()
		for _, tween in tweens do
			tween:Cancel()
		end
		table.clear(tweens)
	end
	Vide.cleanup(stopTweens)

	local function showLoss(before: number, now: number, low: boolean)
		stopTweens()
		-- With the rest of the bar red (low), the lost piece is white so it still stands out.
		lostPiece.BackgroundColor3 = if low then NEON.TEXT else NEON.DANGER
		lostPiece.Position = UDim2.fromScale(now, 0)
		lostPiece.Size = UDim2.fromScale(before - now, 1)
		lostPiece.BackgroundTransparency = 0
		play(lostPiece, LOST_PIECE_SECONDS, Enum.EasingStyle.Quad, {
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 0.6,
		})
		lostText.Text = `-{math.floor((before - now) * 100 + 0.5)}%`
		lostText.TextTransparency = 0
		lostStroke.Transparency = NEON.TEXT_STROKE_TRANSPARENCY
		play(lostText, LOST_TEXT_SECONDS, Enum.EasingStyle.Quint, { TextTransparency = 1 })
		play(lostStroke, LOST_TEXT_SECONDS, Enum.EasingStyle.Quint, { Transparency = 1 })
	end

	local last: number? = nil
	Vide.effect(function()
		local now = math.clamp(props.fraction(), 0, 1)
		local before = last
		last = now
		if before and before - now >= DROP_SHARE then
			showLoss(before, now, Vide.untrack(props.isLow))
		end
	end)

	return create("Frame")({
		Name = "OxygenBar",
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = props.visible,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		create("TextLabel")({
			Name = "Warning",
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_BODY,
			TextColor3 = NEON.DANGER,
			Text = props.warningText,
			Visible = props.isLow,
			Layout.textStroke(),
		}),
		create("Frame")({
			Name = "Row",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, ICON_SIZE),
			BackgroundTransparency = 1,
			create("ImageLabel")({
				Name = "Icon",
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				BackgroundTransparency = 1,
				Image = Icons.ICONS.Oxygen,
				ImageColor3 = function()
					return if props.isLow() then NEON.DANGER else NEON.OXYGEN
				end,
			}),
			create("Frame")({
				Name = "Bar",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, ICON_SIZE + GAP, 0.5, 0),
				Size = UDim2.new(1, -(ICON_SIZE + GAP * 2 + PERCENT_WIDTH), 0, BAR_HEIGHT),
				BackgroundColor3 = NEON.GLASS,
				BackgroundTransparency = NEON.GLASS_TRANSPARENCY,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				Layout.panelLine(),
				create("Frame")({
					Name = "Fill",
					BorderSizePixel = 0,
					Size = function()
						return UDim2.fromScale(math.clamp(props.fraction(), 0, 1), 1)
					end,
					BackgroundColor3 = Color3.new(1, 1, 1),
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					fillGradient,
				}),
				lostPiece,
			}),
			create("TextLabel")({
				Name = "Percent",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(PERCENT_WIDTH, NEON.TEXT_BODY),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_BODY,
				TextColor3 = NEON.TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = function()
					return `{math.floor(math.clamp(props.fraction(), 0, 1) * 100 + 0.5)}%`
				end,
				Layout.textStroke(),
			}),
			lostText,
		}),
	}) :: Frame
end

return OxygenBar
