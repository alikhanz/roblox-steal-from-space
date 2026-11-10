--!strict
-- The tutorial (decision 065, Domain/Tutorial). Pure Luau: tests load it in Lune.

local GuardianConfig = require("./GuardianConfig")

local TutorialConfig = {}

-- The guardian of the second theft: after training, the player steals from this one (or
-- farther) to finish. The training step asks for its recommended speed.
TutorialConfig.STRONGER_GRADE = 2
TutorialConfig.TRAINING_TARGET = GuardianConfig.recommendedFor(TutorialConfig.STRONGER_GRADE)
-- The first delivered egg is ready this soon (a common one warms 10 s to 2 min): at once, so
-- the hatch step sends the player to an egg that is ready (playtest 2026-11-10).
TutorialConfig.FIRST_EGG_SECONDS = 0
-- How long the last hint ("you are on your own now") stays before the panel goes away.
TutorialConfig.DONE_HINT_SECONDS = 8

return table.freeze(TutorialConfig)
