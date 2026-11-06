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
	["guardian.violetCrab.title"] = {
		ru = "Лиловый краб",
		en = "Violet Crab",
	},
	["guardian.acidSlime.title"] = {
		ru = "Кислотный слизень",
		en = "Acid Slime",
	},
	["guardian.rustyCrab.title"] = {
		ru = "Ржавый краб",
		en = "Rusty Crab",
	},
	["guardian.slimeKing.title"] = {
		ru = "Король слизней",
		en = "Slime King",
	},
	["guardian.iceWorm.title"] = {
		ru = "Ледяной червь",
		en = "Ice Worm",
	},
	["guardian.snowCrab.title"] = {
		ru = "Снежный краб",
		en = "Snow Crab",
	},
	["guardian.frostSlime.title"] = {
		ru = "Морозный слизень",
		en = "Frost Slime",
	},
	["guardian.crystalWorm.title"] = {
		ru = "Хрустальный червь",
		en = "Crystal Worm",
	},
	["guardian.iceRay.title"] = {
		ru = "Ледяной скат",
		en = "Ice Ray",
	},
	["guardian.wormMother.title"] = {
		ru = "Мать червей",
		en = "Worm Mother",
	},
	["guardian.devourerSwarm.title"] = {
		ru = "Рой пожирателей",
		en = "Devourer Swarm",
	},
	["guardian.starRay.title"] = {
		ru = "Звёздный скат",
		en = "Star Ray",
	},
	["guardian.fireSlime.title"] = {
		ru = "Огненный слизень",
		en = "Fire Slime",
	},
	["guardian.redSwarm.title"] = {
		ru = "Красный рой",
		en = "Red Swarm",
	},
	["guardian.lightningRay.title"] = {
		ru = "Скат-молния",
		en = "Lightning Ray",
	},
	["guardian.devourerQueen.title"] = {
		ru = "Матка пожирателей",
		en = "Devourer Queen",
	},
	["guardian.shadowWorm.title"] = {
		ru = "Теневой червь",
		en = "Shadow Worm",
	},
	["guardian.blackRay.title"] = {
		ru = "Чёрный скат",
		en = "Black Ray",
	},
	["guardian.voidSwarm.title"] = {
		ru = "Рой пустоты",
		en = "Void Swarm",
	},
	["guardian.gravityCrab.title"] = {
		ru = "Гравикраб",
		en = "Gravity Crab",
	},
	["guardian.whaleCalf.title"] = {
		ru = "Китёнок",
		en = "Whale Calf",
	},
	["guardian.spaceWhale.title"] = {
		ru = "Космический Кит",
		en = "Space Whale",
	},
	["zone.debrisBelt.title"] = {
		ru = "Пояс обломков",
		en = "Debris Belt",
	},
	["zone.iceRings.title"] = {
		ru = "Ледяные кольца",
		en = "Ice Rings",
	},
	["zone.redNebula.title"] = {
		ru = "Красная туманность",
		en = "Red Nebula",
	},
	["zone.eventHorizon.title"] = {
		ru = "Горизонт событий",
		en = "Event Horizon",
	},
	["guardian.caught.toast"] = {
		ru = "Поймали!",
		en = "Caught!",
	},
	["serpent.caught.toast"] = {
		ru = "Тебя схватил змей!",
		en = "The serpent got you!",
	},
	["pvp.struck.toast"] = {
		ru = "Тебя ударили!",
		en = "You got hit!",
	},
	["pvp.strikeEgg.toast"] = {
		ru = "Попал! Яйцо выбито, хватай",
		en = "Hit! The egg is loose, grab it",
	},
	["pvp.strikeHit.toast"] = {
		ru = "Попал!",
		en = "Hit!",
	},
	["pvp.strike.button"] = {
		ru = "Удар",
		en = "Strike",
	},
	["pvp.harpoon.button"] = {
		ru = "Гарпун",
		en = "Harpoon",
	},
	["pvp.bomb.button"] = {
		ru = "Бомба",
		en = "Bomb",
	},
	["pvp.newbie.title"] = {
		ru = "Новичок",
		en = "Newbie",
	},
	["pvp.newbieStat.title"] = {
		ru = "Защита новичка",
		en = "Newbie shield",
	},
	["time.minutesShort.hint"] = {
		ru = "{count} мин",
		en = "{count} min",
	},
	["pvp.harpoonLocked.hint"] = {
		ru = "Гарпун: цель в прицеле",
		en = "Harpoon: target locked",
	},
	["pvp.harpoonEgg.toast"] = {
		ru = "Гарпун попал! Яйцо летит к тебе",
		en = "Harpoon hit! The egg flies to you",
	},
	["pvp.harpoonHit.toast"] = {
		ru = "Гарпун попал!",
		en = "Harpoon hit!",
	},
	["pvp.bombEgg.toast"] = {
		ru = "Бах! Яйцо выбито",
		en = "Boom! An egg is loose",
	},
	["pvp.bombHit.toast"] = {
		ru = "Бах! Кого-то снесло",
		en = "Boom! Someone went flying",
	},
	["pvp.harpooned.toast"] = {
		ru = "Яйцо вырвали гарпуном!",
		en = "A harpoon took your egg!",
	},
	["pvp.notReady.toast"] = {
		ru = "Ещё не готово",
		en = "Not ready yet",
	},
	["pvp.inStation.toast"] = {
		ru = "Под куполом драться нельзя",
		en = "No fighting under the dome",
	},
	["pvp.youAreNewbie.toast"] = {
		ru = "Ты новичок: 20 минут мира",
		en = "You are new: 20 minutes of peace",
	},
	["pvp.victimNewbie.toast"] = {
		ru = "Это новичок, его трогать нельзя",
		en = "That is a newbie, hands off",
	},
	["pvp.victimJustSpawned.toast"] = {
		ru = "Только появился, дай секунду",
		en = "Just spawned, give them a second",
	},
	["pvp.victimTooWeak.toast"] = {
		ru = "Слишком слабый соперник для тебя",
		en = "Too weak a target for you",
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
	["egg.epic.title"] = {
		ru = "Эпическое яйцо",
		en = "Epic egg",
	},
	["egg.legendary.title"] = {
		ru = "Легендарное яйцо",
		en = "Legendary egg",
	},
	["egg.starEgg.hint"] = {
		ru = "★ звёздное",
		en = "★ star",
	},
	["egg.hatchIn.hint"] = {
		ru = "Вылупится через {time}",
		en = "Hatches in {time}",
	},
	["egg.ready.hint"] = {
		ru = "Готово!",
		en = "Ready!",
	},
	["egg.hatch.button"] = {
		ru = "Вылупить",
		en = "Hatch",
	},
	-- On a warming egg: hatch this one now for Robux. {price}: "6 R$".
	["egg.hatchNow.button"] = {
		ru = "Вылупить за {price}",
		en = "Hatch for {price}",
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
	["bay.incubatorSlots.title"] = {
		ru = "Инкубатор · {count}/{slots}",
		en = "Incubator · {count}/{slots}",
	},
	["bay.buySlot.button"] = {
		ru = "+1 место {price} ●",
		en = "+1 slot {price} ●",
	},
	-- {price} is store.robux.hint ("19 R$").
	["bay.buySlotRobux.button"] = {
		ru = "+1 место {price}",
		en = "+1 slot {price}",
	},
	["bay.incubatorWaiting.hint"] = {
		ru = "Ждут места: {count}",
		en = "Waiting for a slot: {count}",
	},
	["bay.incubatorFree.hint"] = {
		ru = "Есть свободное место",
		en = "A slot is free",
	},
	["bay.incubatorFull.hint"] = {
		ru = "Все места заняты",
		en = "Every slot is taken",
	},
	["egg.waiting.hint"] = {
		ru = "Ждёт места",
		en = "Waiting for a slot",
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
		ru = "На полу: {count}",
		en = "On the floor: {count}",
	},
	["bay.pickUpFloor.hint"] = {
		ru = "Подойди и подбери, чтобы положить в инвентарь",
		en = "Walk over and pick them up to put them in your inventory",
	},
	["bay.floorFull.hint"] = {
		ru = "Инвентарь полный: продай или скрести кого-нибудь, тогда сможешь подбирать",
		en = "Inventory full: sell or crossbreed someone, then you can pick them up",
	},
	["alien.hatchedMany.toast"] = {
		ru = {
			one = "Вылупился {count} пришелец!",
			few = "Вылупилось {count} пришельца!",
			many = "Вылупилось {count} пришельцев!",
		},
		en = { one = "{count} alien hatched!", other = "{count} aliens hatched!" },
	},
	["bay.autoPlace.button"] = {
		ru = "Лучших в капсулы",
		en = "Best to pods",
	},
	["bay.crossbreed.button"] = {
		ru = "Скрестить 3 → 1",
		en = "Crossbreed 3→1",
	},
	["bay.crossbreed.hint"] = {
		ru = "Скрещивание: 3 пришельца одного стража → 1 новый, с шансом на ступень выше",
		en = "Crossbreed: 3 aliens of one guardian → 1 new one, with a shot at a higher tier",
	},
	["bay.select.hint"] = {
		ru = "Нажми на пришельца, чтобы выбрать его: переставить, продать или скрестить",
		en = "Tap an alien to select it, then move, sell or crossbreed it",
	},
	["bay.selected.hint"] = {
		ru = "Выбран: {name}",
		en = "Selected: {name}",
	},
	["bay.selectedPod.hint"] = {
		ru = "Выбран: {name}. Он в капсуле: «Из капсулы» уберёт его в инвентарь",
		en = "Selected: {name}. It is in a pod: “Out of the pod” moves it to the inventory",
	},
	["bay.crossbreedPick.hint"] = {
		ru = "Для скрещивания выбрано {count} из 3: нужны пришельцы одного стража",
		en = "{count} of 3 picked to crossbreed: they must be of one guardian",
	},
	["bay.crossbreedReady.hint"] = {
		ru = "Готово: нажми «Скрестить 3 → 1», и трое станут одним",
		en = "Ready: tap “Crossbreed 3→1” and three become one",
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
	["bay.fromPod.button"] = {
		ru = "Из капсулы",
		en = "Out of the pod",
	},
	["alien.hatched.toast"] = {
		ru = "Вылупился {name} → {place}",
		en = "Hatched: {name} → {place}",
	},
	["alien.crossbred.toast"] = {
		ru = "Скрестили! {name} → {place}",
		en = "Crossbred! {name} → {place}",
	},
	["place.pod.hint"] = {
		ru = "в капсулу",
		en = "to a pod",
	},
	["place.inventory.hint"] = {
		ru = "в инвентарь",
		en = "to the inventory",
	},
	["place.floor.hint"] = {
		ru = "на пол отсека",
		en = "to the bay floor",
	},
	["alien.tierIncome.hint"] = {
		ru = "{tier} · {income} ●/с",
		en = "{tier} · {income} ●/s",
	},
	["egg.grabbed.toast"] = {
		ru = "Схватил! Неси яйцо на станцию",
		en = "Got it! Fly the egg to the station",
	},
	["egg.carried.hint"] = {
		ru = "В руках",
		en = "Carrying",
	},
	["egg.delivered.toast"] = {
		ru = "Яйцо в инкубаторе!",
		en = "Egg in the incubator!",
	},
	["egg.dropped.toast"] = {
		ru = "Яйцо выпало! Подбери его",
		en = "Egg dropped! Grab it back",
	},
	["bay.crossbreedSame.hint"] = {
		ru = "Скрещивание: {guardian} {count} из 3. Выбери ещё {left} таких же",
		en = "Crossbreed: {guardian} {count} of 3. Pick {left} more of the same",
	},
	["bay.crossbreedMixed.hint"] = {
		ru = "Это разные стражи. Для скрещивания нужны 3 пришельца одного стража",
		en = "Different guardians. Crossbreeding needs 3 aliens of one guardian",
	},
	["bay.crossbreedVariants.hint"] = {
		ru = "Метеоритные скрещиваются только с метеоритными",
		en = "Meteor aliens crossbreed only with meteor ones",
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
	["notice.maxIncubatorSlots.toast"] = {
		ru = "В инкубаторе больше нет мест",
		en = "The incubator is fully upgraded",
	},
	["notice.noSuchEgg.toast"] = {
		ru = "Это яйцо уже готово",
		en = "That egg's done already",
	},
	["notice.jetpackTop.toast"] = {
		ru = "Это лучший джетпак",
		en = "That's the best jetpack",
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
		ru = "Тебя не было {time}: капсулы принесли {coins} ●, тренажёр добавил {speed} ⚡",
		en = "You were away {time}: your pods made {coins} ● and your trainer added {speed} ⚡",
	},
	["welcome.eggsReady.hint"] = {
		ru = "Готово яиц: {count}. Вылупи их в отсеке",
		en = "Eggs ready: {count}. Hatch them in your bay",
	},
	["welcome.claim.button"] = {
		ru = "Забрать",
		en = "Collect",
	},
	-- "Collect x2", next to the plain "Collect"; {price} is store.robux.hint ("29 R$").
	["welcome.double.button"] = {
		ru = "×2 за {price}",
		en = "×2 for {price}",
	},
	["trainer.level.hint"] = {
		ru = "Тренажёр · уровень {level}",
		en = "Trainer · level {level}",
	},
	["trainer.stand.hint"] = {
		ru = "Встань сюда: +{rate} ⚡/с",
		en = "Stand here: +{rate} ⚡/s",
	},
	["trainer.upgrade.button"] = {
		ru = "Улучшить: {price} ●",
		en = "Upgrade: {price} ●",
	},
	["trainer.gain.hint"] = {
		ru = "+{gain} ⚡",
		en = "+{gain} ⚡",
	},
	["bay.podsSign.title"] = {
		ru = "Капсулы: {count}/{max}",
		en = "Pods: {count}/{max}",
	},
	["bay.podsSign.hint"] = {
		ru = "Пришелец в капсуле приносит монеты",
		en = "An alien in a pod earns coins",
	},
	["bay.podsFull.hint"] = {
		ru = "Все капсулы куплены",
		en = "Every pod is yours",
	},
	["bay.buyPodSign.button"] = {
		ru = "Купить: {price} ●",
		en = "Buy: {price} ●",
	},
	["pvp.cooldown.hint"] = {
		ru = "{seconds} с",
		en = "{seconds}s",
	},
	["hud.ascend.hint"] = {
		ru = "Вверх",
		en = "Up",
	},
	["hud.descend.hint"] = {
		ru = "Вниз",
		en = "Down",
	},
	["hud.grab.hint"] = {
		ru = "Взять яйцо",
		en = "Grab egg",
	},
	["hud.slowMode.hint"] = {
		ru = "Медленно",
		en = "Slow",
	},
	["key.mouseLeft.hint"] = {
		ru = "ЛКМ",
		en = "LMB",
	},
	["key.control.hint"] = {
		ru = "Ctrl",
		en = "Ctrl",
	},
	["key.space.hint"] = {
		ru = "Пробел",
		en = "Space",
	},
	["event.meteor.title"] = {
		ru = "Метеоритный дождь",
		en = "Meteor shower",
	},
	["variant.meteor.title"] = {
		ru = "Метеоритный",
		en = "Meteor",
	},
	["variant.meteorEgg.title"] = {
		ru = "Метеоритное",
		en = "Meteor",
	},
	["index.normal.button"] = {
		ru = "Обычные",
		en = "Regular",
	},
	["index.meteor.button"] = {
		ru = "Метеоритные",
		en = "Meteor",
	},
	["notice.mixedVariants.toast"] = {
		ru = "Скрещивай метеоритных только между собой",
		en = "Crossbreed meteor aliens together",
	},
	["event.serpent.title"] = {
		ru = "Звёздный змей",
		en = "Star Serpent",
	},
	["event.storm.title"] = {
		ru = "Солнечная буря",
		en = "Solar storm",
	},
	["event.soon.hint"] = {
		ru = "{name} через {time}",
		en = "{name} in {time}",
	},
	["event.active.hint"] = {
		ru = "{name}! Ещё {time}",
		en = "{name}! {time} left",
	},
	["event.soon.announce"] = {
		ru = "{name} через {time}!",
		en = "{name} in {time}!",
	},
	["event.started.announce"] = {
		ru = "{name} начинается!",
		en = "{name} is here!",
	},
	["event.startedIn.announce"] = {
		ru = "{name} в зоне «{zone}»!",
		en = "{name} in {zone}!",
	},
	["event.serpent.announce"] = {
		ru = "Звёздный змей со звёздным яйцом в зоне «{zone}»! Бей в голову",
		en = "Star Serpent with a star egg in {zone}! Hit it on the head",
	},
	-- The star serpent's pin and what happens to its egg (decision 055).
	["serpent.hits.title"] = {
		ru = "Звёздный змей {hits}/{total}",
		en = "Star Serpent {hits}/{total}",
	},
	["serpent.egg.title"] = {
		ru = "Звёздное яйцо",
		en = "Star egg",
	},
	["serpent.knocked.announce"] = {
		ru = "{name}: звёздное яйцо выбито!",
		en = "{name} knocked the star egg loose!",
	},
	["serpent.delivered.announce"] = {
		ru = "{name}: звёздное яйцо в отсеке!",
		en = "{name} got the star egg home!",
	},
	["serpent.returned.announce"] = {
		ru = "Звёздное яйцо снова в змее! Бей ещё раз",
		en = "The star egg is back in the serpent. Hit it again!",
	},
	["serpent.escaped.announce"] = {
		ru = "Змей уполз со звёздным яйцом",
		en = "The serpent got away with the star egg",
	},
	["serpent.eggLeft.announce"] = {
		ru = "Змей уполз! Звёздное яйцо без охраны, забирай",
		en = "The serpent is gone! Grab the star egg, it's unguarded",
	},
	["serpent.eggKept.announce"] = {
		ru = "Змей уполз! Довези звёздное яйцо домой",
		en = "The serpent is gone! Bring the star egg home",
	},
	["event.crater.announce"] = {
		ru = "Новый кратер в зоне «{zone}»!",
		en = "New crater in {zone}!",
	},
	["index.open.button"] = {
		ru = "Индекс",
		en = "Index",
	},
	["index.window.title"] = {
		ru = "Индекс пришельцев",
		en = "Alien index",
	},
	["index.found.hint"] = {
		ru = "Открыто {count} из {total}",
		en = "Found {count} of {total}",
	},
	["index.tap.hint"] = {
		ru = "Нажми на светящегося пришельца и забери награду",
		en = "Tap a glowing alien to get your reward",
	},
	["index.claimAll.button"] = {
		ru = "Забрать всё",
		en = "Claim all",
	},
	["index.setClaim.button"] = {
		ru = "Набор: +{coins} ●",
		en = "Set: +{coins} ●",
	},
	["index.setDone.hint"] = {
		ru = "Набор собран",
		en = "Set complete",
	},
	["index.discovered.toast"] = {
		ru = "Новый пришелец в индексе!",
		en = "New alien in your index!",
	},
	["index.discoveredMany.toast"] = {
		ru = {
			one = "В индексе {count} новый пришелец!",
			few = "В индексе {count} новых пришельца!",
			many = "В индексе {count} новых пришельцев!",
		},
		en = { one = "{count} new alien in your index!", other = "{count} new aliens in your index!" },
	},
	["index.rewarded.toast"] = {
		ru = "Индекс: +{coins} ●",
		en = "Index: +{coins} ●",
	},
	["notice.stormTeleport.toast"] = {
		ru = "Буря! Тебя вернуло на станцию",
		en = "Storm! Back to the station you go",
	},
	["notice.indexNothing.toast"] = {
		ru = "Здесь пока нечего забрать",
		en = "Nothing to claim here yet",
	},
	["gift.open.button"] = {
		ru = "Подарок",
		en = "Gift",
	},
	["gift.window.title"] = {
		ru = "Подарок за вход",
		en = "Daily gift",
	},
	["gift.day.hint"] = {
		ru = "День {day}",
		en = "Day {day}",
	},
	["gift.claim.button"] = {
		ru = "Забрать",
		en = "Claim",
	},
	["gift.later.button"] = {
		ru = "Позже",
		en = "Later",
	},
	["gift.streak.hint"] = {
		ru = "Заходи каждый день, и подарки будут расти",
		en = "Come back every day for bigger gifts",
	},
	["gift.reset.hint"] = {
		ru = "Новая серия! Заходи каждый день",
		en = "New streak! Come back every day",
	},
	["gift.next.hint"] = {
		ru = "Следующий подарок через {time}",
		en = "Next gift in {time}",
	},
	["gift.rewarded.toast"] = {
		ru = "Подарок: +{coins} ● и +{speed} ⚡",
		en = "Gift: +{coins} ● and +{speed} ⚡",
	},
	["notice.giftTaken.toast"] = {
		ru = "Сегодняшний подарок уже у тебя",
		en = "You already got today's gift",
	},
	["quests.open.button"] = {
		ru = "Задания",
		en = "Quests",
	},
	["quests.window.title"] = {
		ru = "Задания дня",
		en = "Daily quests",
	},
	["quests.resetIn.hint"] = {
		ru = "Новые задания через {time}",
		en = "New quests in {time}",
	},
	["quests.swap.hint"] = {
		ru = "Одно задание в день можно заменить",
		en = "You can swap one quest a day",
	},
	["quests.swapUsed.hint"] = {
		ru = "Замена на сегодня уже потрачена",
		en = "You've used today's swap",
	},
	["quests.claim.button"] = {
		ru = "Забрать",
		en = "Claim",
	},
	["quests.swap.button"] = {
		ru = "Заменить",
		en = "Swap",
	},
	["quests.claimed.hint"] = {
		ru = "Получено",
		en = "Claimed",
	},
	["quests.done.toast"] = {
		ru = "Задание выполнено!",
		en = "Quest complete!",
	},
	["quests.rewarded.toast"] = {
		ru = "Награда: +{coins} ● и +{speed} ⚡",
		en = "Reward: +{coins} ● and +{speed} ⚡",
	},
	["quest.deliverEggs.hint"] = {
		ru = {
			one = "Доставь {count} яйцо",
			few = "Доставь {count} яйца",
			many = "Доставь {count} яиц",
		},
		en = { one = "Deliver {count} egg", other = "Deliver {count} eggs" },
	},
	["quest.deliverFromZone.hint"] = {
		ru = "Доставь яйцо из зоны «{zone}»",
		en = "Deliver an egg from {zone}",
	},
	["quest.hatchAliens.hint"] = {
		ru = {
			one = "Вылупи {count} пришельца",
			few = "Вылупи {count} пришельцев",
			many = "Вылупи {count} пришельцев",
		},
		en = { one = "Hatch {count} alien", other = "Hatch {count} aliens" },
	},
	["quest.train.hint"] = {
		ru = {
			one = "Потренируйся {count} минуту",
			few = "Потренируйся {count} минуты",
			many = "Потренируйся {count} минут",
		},
		en = { one = "Train for {count} minute", other = "Train for {count} minutes" },
	},
	["quest.crossbreed.hint"] = {
		ru = "Скрести пришельцев",
		en = "Crossbreed aliens",
	},
	["quest.knockEgg.hint"] = {
		ru = "Выбей яйцо у другого игрока",
		en = "Knock an egg from another player",
	},
	["notice.noSuchQuest.toast"] = {
		ru = "Задания обновились, загляни ещё раз",
		en = "Quests changed, take another look",
	},
	["notice.questNotDone.toast"] = {
		ru = "Сначала выполни задание",
		en = "Finish the quest first",
	},
	["notice.questClaimed.toast"] = {
		ru = "Эта награда уже твоя",
		en = "You already got this reward",
	},
	["notice.rerollUsed.toast"] = {
		ru = "Замена сегодня уже была",
		en = "You already swapped today",
	},
	["notice.questDone.toast"] = {
		ru = "Выполненное задание не заменить",
		en = "Done quests can't be swapped",
	},
	["notice.noOtherQuest.toast"] = {
		ru = "Других заданий пока нет",
		en = "No other quests right now",
	},
	["leaderboard.board.title"] = {
		ru = "Лучшие по монетам",
		en = "Top coin earners",
	},
	["leaderboard.allTime.hint"] = {
		ru = "Монеты, заработанные за всё время",
		en = "Coins earned all time",
	},
	["leaderboard.empty.hint"] = {
		ru = "Пока пусто. Заработай монеты и попади сюда",
		en = "Nobody here yet. Earn coins to make the board",
	},
	["shop.sign.title"] = {
		ru = "Магазин джетпаков",
		en = "Jetpack shop",
	},
	["shop.open.button"] = {
		ru = "Открыть",
		en = "Open",
	},
	["shop.window.title"] = {
		ru = "Магазин джетпаков",
		en = "Jetpack shop",
	},
	["shop.window.hint"] = {
		ru = "Каждый джетпак удваивает ⚡ и горит ярче",
		en = "Every jetpack doubles ⚡ and burns brighter",
	},
	["shop.multiplier.hint"] = {
		ru = "⚡ ×{factor}",
		en = "⚡ ×{factor}",
	},
	["shop.owned.hint"] = {
		ru = "Твой",
		en = "Yours",
	},
	["shop.buy.button"] = {
		ru = "Купить: {price} ●",
		en = "Buy: {price} ●",
	},
	["shop.locked.hint"] = {
		ru = "Ещё не доступен",
		en = "Not yet",
	},
	["shop.past.hint"] = {
		ru = "Был твоим",
		en = "Outgrown",
	},
	["jetpack.level0.title"] = {
		ru = "Стартовый",
		en = "Starter",
	},
	["jetpack.level1.title"] = {
		ru = "Искра",
		en = "Spark",
	},
	["jetpack.level2.title"] = {
		ru = "Комета",
		en = "Comet",
	},
	["jetpack.level3.title"] = {
		ru = "Плазма",
		en = "Plasma",
	},
	["jetpack.level4.title"] = {
		ru = "Ион",
		en = "Ion",
	},
	["jetpack.level5.title"] = {
		ru = "Пульсар",
		en = "Pulsar",
	},
	["jetpack.level6.title"] = {
		ru = "Квазар",
		en = "Quasar",
	},
	["jetpack.level7.title"] = {
		ru = "Антиматерия",
		en = "Antimatter",
	},
	["jetpack.level8.title"] = {
		ru = "Сингулярность",
		en = "Singularity",
	},
	["jetpack.level9.title"] = {
		ru = "Гиперпривод",
		en = "Hyperdrive",
	},
	["jetpack.level10.title"] = {
		ru = "Червоточина",
		en = "Wormhole",
	},
	["jetpack.level11.title"] = {
		ru = "Бесконечность",
		en = "Infinity",
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
	-- The next speed goal under the stat: the nearest guardian not yet within reach.
	["speed.goal.title"] = {
		ru = "Цель: {name}",
		en = "Next: {name}",
	},
	["speed.goalReached.toast"] = {
		ru = "Теперь тебе по силам {name}!",
		en = "{name} is within reach now!",
	},
	["oxygen.low.toast"] = {
		ru = "Кислород кончается! Лети к станции",
		en = "Low oxygen! Fly back to the station",
	},
	["station.beacon.title"] = {
		ru = "Станция",
		en = "Station",
	},
	["marker.distance.hint"] = {
		ru = "{distance} м",
		en = "{distance} m",
	},
	["data.corrupted.message"] = {
		ru = "Не получилось прочитать твой прогресс. Мы ничего в нём не меняли. Зайди снова через пару минут.",
		en = "We couldn't read your progress. Nothing in it was changed. Rejoin in a few minutes.",
	},
	-- The shop: Robux purchases (decision 061).
	["store.open.button"] = {
		ru = "Магазин",
		en = "Shop",
	},
	["store.window.title"] = {
		ru = "Магазин",
		en = "Shop",
	},
	["store.window.hint"] = {
		ru = "Робуксы вместо ожидания",
		en = "Robux instead of waiting",
	},
	-- A price in Robux, as buttons show it.
	["store.robux.hint"] = {
		ru = "{price} R$",
		en = "{price} R$",
	},
	["store.owned.hint"] = {
		ru = "Куплено",
		en = "Owned",
	},
	["store.doubleTraining.title"] = {
		ru = "Двойная тренировка",
		en = "Double training",
	},
	["store.doubleTraining.hint"] = {
		ru = "Тренажёр даёт ×{factor} ⚡, даже когда тебя нет в игре. Навсегда",
		en = "Your trainer gives ×{factor} ⚡, even while you're away. Forever",
	},
	["store.nightShift.title"] = {
		ru = "Ночная смена",
		en = "Night shift",
	},
	["store.nightShift.hint"] = {
		ru = "Без тебя капсулы приносят монеты {income} ч вместо {incomeBase}, тренажёр качает {training} ч вместо {trainingBase}",
		en = "Offline, pods earn for {income} h, not {incomeBase}, and the trainer works {training} h, not {trainingBase}",
	},
	["store.trainingHour.title"] = {
		ru = "Час тренировки",
		en = "1 hour of training",
	},
	["store.trainingEight.title"] = {
		ru = "8 часов тренировки",
		en = "8 hours of training",
	},
	["store.trainingDay.title"] = {
		ru = "Сутки тренировки",
		en = "A day of training",
	},
	["store.training.hint"] = {
		ru = "Сразу +{speed} ⚡: столько тренажёр даёт за это время",
		en = "+{speed} ⚡ right away: what your trainer gives in that time",
	},
	["store.slot.title"] = {
		ru = "Место в инкубаторе",
		en = "Incubator slot",
	},
	["store.slot.hint"] = {
		ru = "Ещё одно место сразу, без монет. Сейчас мест: {count}",
		en = "One more slot right away, no coins. Slots now: {count}",
	},
	["store.slotMax.hint"] = {
		ru = "Все места в инкубаторе уже твои",
		en = "Every incubator slot is yours",
	},
	-- Next to the speed goal in the HUD: opens the shop.
	["store.goal.button"] = {
		ru = "Больше ⚡",
		en = "More ⚡",
	},
	["store.unlocked.toast"] = {
		ru = "Куплено: {name}",
		en = "Unlocked: {name}",
	},
	["store.training.toast"] = {
		ru = "Готово: +{speed} ⚡",
		en = "Done: +{speed} ⚡",
	},
	["store.readyNow.toast"] = {
		ru = "Яйцо готово! Вылупи его в отсеке",
		en = "Egg ready! Hatch it in your bay",
	},
	["store.slot.toast"] = {
		ru = "+1 место в инкубаторе",
		en = "+1 incubator slot",
	},
	["store.double.toast"] = {
		ru = "Ещё +{coins} ● и +{speed} ⚡",
		en = "Another +{coins} ● and +{speed} ⚡",
	},
	-- The purchase found nothing to apply to (the egg hatched, every slot bought).
	["store.compensated.toast"] = {
		ru = "Не к чему применить. Держи +{coins} ●",
		en = "Nothing to use it on. Here's +{coins} ●",
	},
}

return table.freeze(Strings)
