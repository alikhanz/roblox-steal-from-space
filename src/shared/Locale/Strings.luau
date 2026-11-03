--!strict
-- Every player-facing string, keyed "<area>.<name>.<kind>".
-- <kind> sets the length limit: button, title, toast, hint, announce, message (see docs/STYLE_TEXT.md).
--
-- A value is a string, or plural forms selected by the `count` argument:
--   ru = { one = ..., few = ..., many = ... }   en = { one = ..., other = ... }
--
-- Write and review strings with the `game-copy` skill. `lune run check` validates this file.

local Strings = {
	["data.loadFailed.message"] = {
		ru = "Не получилось загрузить твой прогресс, но он не потерян. Зайди снова через минуту.",
		en = "We couldn't load your progress, but it's safe. Rejoin in a minute.",
	},
	["data.sessionLost.message"] = {
		ru = "Твой аккаунт открыли на другом сервере. Здесь игра закрыта, чтобы прогресс не потерялся.",
		en = "Your account was opened on another server. We closed this one to keep your progress safe.",
	},
	["data.newerVersion.message"] = {
		ru = "Вышло обновление игры. Зайди снова, чтобы играть дальше.",
		en = "The game just got an update. Rejoin to keep playing.",
	},
	["egg.grab.hint"] = {
		ru = "Держи, чтобы взять",
		en = "Hold to grab",
	},
	["egg.grabTouch.hint"] = {
		ru = "Нажми и держи",
		en = "Tap and hold",
	},
	["guardian.slimeWarden.title"] = {
		ru = "Слизень-сторож",
		en = "Slime Warden",
	},
	["guardian.crabDrone.title"] = {
		ru = "Краб-дрон",
		en = "Crab Drone",
	},
	["guardian.caught.toast"] = {
		ru = "Поймали!",
		en = "Caught!",
	},
	["egg.common.title"] = {
		ru = "Обычное яйцо",
		en = "Common egg",
	},
	["egg.uncommon.title"] = {
		ru = "Необычное яйцо",
		en = "Uncommon egg",
	},
	["egg.rare.title"] = {
		ru = "Редкое яйцо",
		en = "Rare egg",
	},
	["egg.hatchIn.hint"] = {
		ru = "Вылупится через {time}",
		en = "Hatches in {time}",
	},
	["egg.hatching.hint"] = {
		ru = "Вот-вот вылупится!",
		en = "Hatching any second!",
	},
	["bay.owner.title"] = {
		ru = "Отсек {name}",
		en = "{name}'s bay",
	},
	["bay.open.button"] = {
		ru = "Отсек",
		en = "Bay",
	},
	["bay.window.title"] = {
		ru = "Твой отсек",
		en = "Your bay",
	},
	["bay.close.button"] = {
		ru = "Закрыть",
		en = "Close",
	},
	["bay.pods.title"] = {
		ru = "Капсулы",
		en = "Pods",
	},
	["bay.emptyPod.hint"] = {
		ru = "Пусто",
		en = "Empty",
	},
	["bay.buyPod.button"] = {
		ru = "Капсула: {price}",
		en = "Pod: {price}",
	},
	["bay.incubator.title"] = {
		ru = "Инкубатор",
		en = "Incubator",
	},
	["bay.incubatorEmpty.hint"] = {
		ru = "Пусто. Укради яйцо и принеси его сюда",
		en = "Empty. Steal an egg and bring it here",
	},
	["bay.inventory.title"] = {
		ru = "Инвентарь {count}/{max}",
		en = "Inventory {count}/{max}",
	},
	["bay.floor.title"] = {
		ru = "На полу",
		en = "On the floor",
	},
	["bay.pickUpFloor.hint"] = {
		ru = "Подойди и подбери, чтобы положить в инвентарь",
		en = "Walk over and pick them up to put them in your inventory",
	},
	["bay.autoPlace.button"] = {
		ru = "Лучших в капсулы",
		en = "Best to pods",
	},
	["bay.crossbreed.button"] = {
		ru = "Скрестить",
		en = "Crossbreed",
	},
	["bay.crossbreed.hint"] = {
		ru = "Выбери 3 пришельцев одного стража",
		en = "Pick 3 aliens of one guardian",
	},
	["bay.sell.button"] = {
		ru = "Продать",
		en = "Sell",
	},
	["bay.sellConfirm.button"] = {
		ru = "Точно? +{price}",
		en = "Sure? +{price}",
	},
	["bay.toPod.button"] = {
		ru = "В капсулу",
		en = "To a pod",
	},
	["bay.toInventory.button"] = {
		ru = "В инвентарь",
		en = "To inventory",
	},
	["alien.hatched.toast"] = {
		ru = "Вылупился: {name}!",
		en = "Hatched: {name}!",
	},
	["notice.inventoryFull.toast"] = {
		ru = "Инвентарь полный: продай или скрести",
		en = "Inventory full: sell or crossbreed",
	},
	["notice.notEnoughCoins.toast"] = {
		ru = "Не хватает монет. Подожди доход",
		en = "Not enough coins. Wait for income",
	},
	["notice.maxPods.toast"] = {
		ru = "Больше капсул не поставить",
		en = "No room for more pods",
	},
	["notice.wrongAliens.toast"] = {
		ru = "Нужны 3 пришельца одного стража",
		en = "Pick 3 aliens of one guardian",
	},
	["notice.unknownAlien.toast"] = {
		ru = "Этого пришельца уже нет",
		en = "That alien is gone",
	},
	["notice.tooFast.toast"] = {
		ru = "Не так быстро!",
		en = "Not so fast!",
	},
	["notice.noProfile.toast"] = {
		ru = "Прогресс ещё грузится",
		en = "Still loading your progress",
	},
	["welcome.back.title"] = {
		ru = "С возвращением!",
		en = "Welcome back!",
	},
	["welcome.earned.hint"] = {
		ru = "Пока тебя не было {time}, капсулы принесли {coins} монет",
		en = "While you were away for {time}, your pods earned {coins} coins",
	},
	["welcome.claim.button"] = {
		ru = "Забрать",
		en = "Collect",
	},
	["alien.pickUp.button"] = {
		ru = "Подобрать",
		en = "Pick up",
	},
	["alien.income.hint"] = {
		ru = "{income} монет/с",
		en = "{income} coins/s",
	},
	["time.seconds.hint"] = {
		ru = { one = "{count} секунда", few = "{count} секунды", many = "{count} секунд" },
		en = { one = "{count} second", other = "{count} seconds" },
	},
	["time.minutes.hint"] = {
		ru = { one = "{count} минута", few = "{count} минуты", many = "{count} минут" },
		en = { one = "{count} minute", other = "{count} minutes" },
	},
	["time.hours.hint"] = {
		ru = { one = "{count} час", few = "{count} часа", many = "{count} часов" },
		en = { one = "{count} hour", other = "{count} hours" },
	},
	["tier.common.title"] = {
		ru = "Обычный",
		en = "Common",
	},
	["tier.uncommon.title"] = {
		ru = "Необычный",
		en = "Uncommon",
	},
	["tier.rare.title"] = {
		ru = "Редкий",
		en = "Rare",
	},
	["tier.epic.title"] = {
		ru = "Эпический",
		en = "Epic",
	},
	["tier.legendary.title"] = {
		ru = "Легендарный",
		en = "Legendary",
	},
	["coins.stat.title"] = {
		ru = "Монеты",
		en = "Coins",
	},
	["speed.stat.title"] = {
		ru = "Скорость",
		en = "Speed",
	},
	["oxygen.low.toast"] = {
		ru = "Кислород кончается! Лети к станции",
		en = "Low oxygen! Fly back to the station",
	},
	["data.corrupted.message"] = {
		ru = "Не получилось прочитать твой прогресс. Мы ничего в нём не меняли. Зайди снова через пару минут.",
		en = "We couldn't read your progress. Nothing in it was changed. Rejoin in a few minutes.",
	},
}

return table.freeze(Strings)
