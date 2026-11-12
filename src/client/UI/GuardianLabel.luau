--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The sign over a guardian, and over the star serpent (docs/design/screens/guardian-labels.md):
-- its name, and under it a pill of glass with an icon and a word for how it stands against the
-- player's own ⚡ (Speed.challenge, GuardianLooks.CHALLENGES). The number itself is not shown:
-- the HUD's goal shows how far the next guardian is.
--
-- The sign is sized in studs (GuardianLooks.LABEL), so the engine shrinks it with distance every
-- frame, smoothly, between a big size near and a readable one far (`size` holds it there);
-- everything in it is laid out in shares of its size and its text is scaled
-- to fit, so nothing reflows as it shrinks. Far away it also fades (`fade`). Every length below is
-- in name-line heights ("units").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuardianLooks = require(ReplicatedStorage.Shared.Config.GuardianLooks)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Speed = require(ReplicatedStorage.Shared.Domain.Speed)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local NEON = Theme.NEON
local LABEL = GuardianLooks.LABEL

-- Rows, units: the name, a gap, the pill, and the Studio-only debug line.
local NAME = 1
local GAP = 0.08
local PILL = 0.72
local DEBUG = 0.45
-- Wide enough for the longest name (17 letters) at full height, units.
local WIDTH = 11.5
-- Inside the pill: the share of its height the icon and the word take, its padding and the gap
-- after the icon (units), and how wide a letter of the word is for its height (Nunito Heavy,
-- with room to spare: a pill too narrow would shrink its word).
local PILL_CONTENT = 0.78
local PILL_PADDING = 0.25
local ICON_GAP = 0.12
local LETTER_WIDTH = 0.66
-- Glass a little denser than the HUD's: the pill stands over a busy scene (as WorldChip's).
local GLASS_TRANSPARENCY = 0.35

export type Props = {
	adornee: BasePart,
	name: string,
	-- How it stands against the player now; no pill while it is unknown (nil).
	challenge: () -> Speed.Challenge?,
	-- The word for each challenge, in the player's language.
	words: { [Speed.Challenge]: string },
	-- Its size in studs as a share of its own (GuardianPose.labelSize): 1 in the middle distances;
	-- the owner moves it only by visible steps (GuardianLooks.LABEL.SIZE_STEP).
	size: () -> number,
	-- How faded the sign is, 0 (clear) to 1 (GuardianPose.labelFade); the owner moves it only by
	-- visible steps (GuardianLooks.LABEL.FADE_STEP).
	fade: () -> number,
	-- Height of the sign's bottom above the adornee's centre, studs.
	studsAbove: number,
	-- The sign is hidden beyond this distance, studs (ZoneLooks.GUARDIAN_SIGN_DISTANCE).
	maxDistance: number,
	-- Studio-only debug line under the pill (DevConfig.STUDIO_GUARDIAN_SPEED); nil in live games.
	debugText: string?,
}

local function GuardianLabel(props: Props): BillboardGui
	local function look(): GuardianLooks.ChallengeLook?
		local challenge = props.challenge()
		return if challenge then GuardianLooks.CHALLENGES[challenge] else nil
	end
	local function color(): Color3
		local current = look()
		return if current then current.color else NEON.TEXT
	end
	local function word(): string
		local challenge = props.challenge()
		return if challenge then props.words[challenge] else ""
	end
	-- `base` transparency faded further by the sign's fade.
	local function faded(base: number): () -> number
		return function(): number
			return 1 - (1 - base) * (1 - props.fade())
		end
	end

	-- The pill is as wide as its word (estimated from its letters), in units.
	local content = PILL * PILL_CONTENT
	local function pillWidth(): number
		return 2 * PILL_PADDING + content + ICON_GAP + (utf8.len(word()) or 0) * LETTER_WIDTH * content
	end

	local function stroke(): UIStroke
		local instance = Layout.textStroke()
		local base = instance.Transparency
		Vide.effect(function()
			instance.Transparency = faded(base)()
		end)
		return instance
	end

	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Thickness = NEON.LINE_THICKNESS
	Vide.effect(function()
		outline.Color = color()
		outline.Transparency = props.fade()
	end)

	local height = NAME + GAP + PILL + (if props.debugText then GAP + DEBUG else 0)
	-- A row `top` units down, `rows` units tall, as a share of the sign's height.
	local function row(top: number, rows: number): (UDim2, UDim2)
		return UDim2.fromScale(0.5, top / height), UDim2.fromScale(1, rows / height)
	end
	local namePosition, nameSize = row(0, NAME)
	local pillPosition = UDim2.fromScale(0.5, (NAME + GAP) / height)
	local debugPosition, debugSize = row(NAME + GAP + PILL + GAP, DEBUG)

	local studs = LABEL.NAME_STUDS
	return create("BillboardGui")({
		Name = "GuardianLabel",
		Adornee = props.adornee,
		Size = function(): UDim2
			local size = studs * props.size()
			return UDim2.fromScale(WIDTH * size, height * size)
		end,
		-- The sign's bottom middle sits `studsAbove` over the adornee.
		StudsOffset = Vector3.new(0, props.studsAbove, 0),
		SizeOffset = Vector2.new(0, 0.5),
		MaxDistance = props.maxDistance,
		AlwaysOnTop = true,
		LightInfluence = 0,

		create("TextLabel")({
			-- Not "Name": that would shadow the Instance property for anyone reading the sign.
			Name = "Title",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = namePosition,
			Size = nameSize,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextScaled = true,
			TextColor3 = NEON.TEXT,
			TextTransparency = props.fade,
			Text = props.name,
			stroke(),
		}),

		create("Frame")({
			Name = "Pill",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = pillPosition,
			Size = function(): UDim2
				return UDim2.fromScale(pillWidth() / WIDTH, PILL / height)
			end,
			Visible = function(): boolean
				return look() ~= nil
			end,
			BackgroundColor3 = NEON.GLASS,
			BackgroundTransparency = faded(GLASS_TRANSPARENCY),
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			outline,
			create("ImageLabel")({
				Name = "Icon",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = function(): UDim2
					return UDim2.fromScale(PILL_PADDING / pillWidth(), 0.5)
				end,
				Size = function(): UDim2
					return UDim2.fromScale(content / pillWidth(), PILL_CONTENT)
				end,
				BackgroundTransparency = 1,
				Image = function(): string
					local current = look()
					return if current then Icons.ICONS[current.icon :: Icons.Name] or "" else ""
				end,
				ImageColor3 = function(): Color3
					return Layout.iconColor(color())
				end,
				ImageTransparency = props.fade,
			}),
			create("TextLabel")({
				Name = "Word",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = function(): UDim2
					return UDim2.fromScale((PILL_PADDING + content + ICON_GAP) / pillWidth(), 0.5)
				end,
				Size = function(): UDim2
					local width = pillWidth()
					return UDim2.fromScale((width - 2 * PILL_PADDING - content - ICON_GAP) / width, PILL_CONTENT)
				end,
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = color,
				TextTransparency = props.fade,
				Text = word,
				stroke(),
			}),
		}),

		if props.debugText
			then create("TextLabel")({
				Name = "Debug",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = debugPosition,
				Size = debugSize,
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextScaled = true,
				TextColor3 = Theme.SPEED,
				TextStrokeTransparency = 0.4,
				Text = props.debugText,
			})
			else nil,
	}) :: BillboardGui
end

return GuardianLabel
