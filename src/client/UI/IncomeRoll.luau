--!strict
-- How an alien's income roll reads (decision 130, Domain/AlienIncome): "+23%" beside its income,
-- coloured from the bad end (red) through plain (muted) to the lucky end (gold), so the best of a
-- shelf is seen at a glance. One place for the bay window, the toasts and the chip over a pet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienIncome = require(ReplicatedStorage.Shared.Domain.AlienIncome)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Theme)

local NEON = Theme.NEON

local IncomeRoll = {}

-- The roll's distance from 100 with its sign, as the texts take it: "+23", "-8", "+0".
function IncomeRoll.bonus(percent: number): string
	local bonus = percent - AlienIncome.NEUTRAL
	return if bonus < 0 then tostring(bonus) else `+{bonus}`
end

-- "+23%".
function IncomeRoll.text(locale: Text.Locale, percent: number): string
	return Text.get(locale, "alien.roll.hint", { bonus = IncomeRoll.bonus(percent) })
end

-- Red at the lowest roll, muted at 100, gold at the highest.
function IncomeRoll.color(percent: number): Color3
	local roll = AlienConfig.INCOME_ROLL
	if percent < AlienIncome.NEUTRAL then
		local share = (AlienIncome.NEUTRAL - percent) / (AlienIncome.NEUTRAL - roll.min)
		return NEON.MUTED:Lerp(NEON.ROLL_LOW, math.clamp(share, 0, 1))
	end
	local share = (percent - AlienIncome.NEUTRAL) / (roll.max - AlienIncome.NEUTRAL)
	return NEON.MUTED:Lerp(NEON.ROLL_HIGH, math.clamp(share, 0, 1))
end

return table.freeze(IncomeRoll)
