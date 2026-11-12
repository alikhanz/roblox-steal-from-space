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
	-- Under the prompt over an egg: one press grabs (docs/design/screens/grab-button.md).
	["egg.grab.hint"] = {
		ru = "Нажми, чтобы взять",
		en = "Press to grab",
	},
	["egg.grabTouch.hint"] = {
		ru = "Нажми, чтобы взять",
		en = "Tap to grab",
	},
	-- The word on the grab button, under the egg icon.
	["egg.grabButton.button"] = {
		ru = "Схватить",
		en = "Grab",
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
	-- How a guardian (or the star serpent) stands against the player's own ⚡: the word on the
	-- pill under its name (Speed.challenge; docs/design/screens/guardian-labels.md).
	["guardian.challengeWeak.title"] = { ru = "Слабый", en = "Weak" },
	["guardian.challengeFair.title"] = { ru = "По силам", en = "Your level" },
	["guardian.challengeStrong.title"] = { ru = "Сильный", en = "Strong" },
	["guardian.challengeTooStrong.title"] = { ru = "Не уйти", en = "No escape" },
	-- Alien kinds (decision 075): each guardian's second and rare kind, in post order. Its main
	-- kind is its baby and carries the guardian's name.
	["kind.patrolSwarm.title"] = { ru = "Патрульный рой", en = "Patrol Swarm" },
	["kind.patrolRay.title"] = { ru = "Скат-патрульный", en = "Patrol Ray" },
	["kind.droneRay.title"] = { ru = "Скат-дрон", en = "Drone Ray" },
	["kind.blimpWhale.title"] = { ru = "Кит-дирижабль", en = "Blimp Whale" },
	["kind.violetWorm.title"] = { ru = "Лиловый червь", en = "Violet Worm" },
	["kind.violetRay.title"] = { ru = "Лиловый скат", en = "Violet Ray" },
	["kind.acidWorm.title"] = { ru = "Кислотный червь", en = "Acid Worm" },
	["kind.acidWhale.title"] = { ru = "Кислотный кит", en = "Acid Whale" },
	["kind.rustySwarm.title"] = { ru = "Ржавый рой", en = "Rusty Swarm" },
	["kind.rustyWhale.title"] = { ru = "Ржавый кит", en = "Rusty Whale" },
	["kind.royalSwarm.title"] = { ru = "Свита короля", en = "Royal Guard" },
	["kind.royalRay.title"] = { ru = "Королевский скат", en = "Royal Ray" },
	["kind.iceSwarm.title"] = { ru = "Ледяной рой", en = "Ice Swarm" },
	["kind.iceCrab.title"] = { ru = "Ледяной краб", en = "Ice Crab" },
	["kind.snowSlime.title"] = { ru = "Снежный слизень", en = "Snow Slime" },
	["kind.snowWhale.title"] = { ru = "Снежный кит", en = "Snow Whale" },
	["kind.flakeSwarm.title"] = { ru = "Рой снежинок", en = "Snowflake Swarm" },
	["kind.frostRay.title"] = { ru = "Морозный скат", en = "Frost Ray" },
	["kind.crystalSlime.title"] = { ru = "Хрустальный слизень", en = "Crystal Slime" },
	["kind.crystalWhale.title"] = { ru = "Хрустальный кит", en = "Crystal Whale" },
	["kind.icebreakerCrab.title"] = { ru = "Краб-ледокол", en = "Icebreaker Crab" },
	["kind.auroraSwarm.title"] = { ru = "Северное сияние", en = "Aurora Swarm" },
	["kind.motherWhale.title"] = { ru = "Ледяная китиха", en = "Ice Mama Whale" },
	["kind.nannyRay.title"] = { ru = "Скат-няня", en = "Nanny Ray" },
	["kind.devourerCrab.title"] = { ru = "Краб-пожиратель", en = "Devourer Crab" },
	["kind.devourerWorm.title"] = { ru = "Червь-пожиратель", en = "Devourer Worm" },
	["kind.starSlime.title"] = { ru = "Звёздный слизень", en = "Star Slime" },
	["kind.starWhale.title"] = { ru = "Звёздный кит", en = "Star Whale" },
	["kind.fireWorm.title"] = { ru = "Огненный червь", en = "Fire Worm" },
	["kind.fireWhale.title"] = { ru = "Огненный кит", en = "Fire Whale" },
	["kind.redCrab.title"] = { ru = "Красный краб", en = "Red Crab" },
	["kind.redRay.title"] = { ru = "Красный скат", en = "Red Ray" },
	["kind.stormSlime.title"] = { ru = "Грозовой слизень", en = "Storm Slime" },
	["kind.stormWhale.title"] = { ru = "Грозовой кит", en = "Storm Whale" },
	["kind.guardCrab.title"] = { ru = "Краб-гвардеец", en = "Guard Crab" },
	["kind.empressWorm.title"] = { ru = "Червь-императрица", en = "Empress Worm" },
	["kind.shadowSlime.title"] = { ru = "Теневой слизень", en = "Shadow Slime" },
	["kind.shadowCrab.title"] = { ru = "Теневой краб", en = "Shadow Crab" },
	["kind.eclipseSwarm.title"] = { ru = "Рой затмения", en = "Eclipse Swarm" },
	["kind.eclipseWhale.title"] = { ru = "Кит-затмение", en = "Eclipse Whale" },
	["kind.voidSlime.title"] = { ru = "Слизень пустоты", en = "Void Slime" },
	["kind.voidRay.title"] = { ru = "Скат пустоты", en = "Void Ray" },
	["kind.gravityWorm.title"] = { ru = "Гравичервь", en = "Gravity Worm" },
	["kind.gravitySwarm.title"] = { ru = "Гравирой", en = "Gravity Swarm" },
	["kind.rayCalf.title"] = { ru = "Скатёнок", en = "Baby Ray" },
	["kind.stargazerCrab.title"] = { ru = "Звездочёт", en = "Stargazer Crab" },
	["kind.spaceWorm.title"] = { ru = "Космический червь", en = "Space Worm" },
	["kind.galaxySlime.title"] = { ru = "Галактический слизень", en = "Galaxy Slime" },
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
	-- On the owner's sign at the entrance of their island.
	["bay.owner.title"] = {
		ru = "Остров {name}",
		en = "{name}'s island",
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
	-- The spots where aliens stand on the island and earn (decision 068).
	["bay.places.title"] = {
		ru = "Места",
		en = "Spots",
	},
	-- One row in the spots list standing for all the empty spots.
	["bay.freePlaces.hint"] = {
		ru = "Свободно: {count}",
		en = "Free: {count}",
	},
	-- Under the spots list while the player has no aliens yet.
	["bay.placesEmpty.hint"] = {
		ru = "Вылупи пришельца, и он встанет на место",
		en = "Hatch an alien and it takes a spot",
	},
	-- Coins a second, next to a coin icon (alien rows and the spots total).
	["bay.income.hint"] = {
		ru = "{income}/с",
		en = "{income}/s",
	},
	["bay.buyPlace.button"] = {
		ru = "Место: ●{price}",
		en = "Spot: ●{price}",
	},
	["bay.incubatorSlots.title"] = {
		ru = "Инкубатор · {count}/{slots}",
		en = "Incubator · {count}/{slots}",
	},
	-- The incubator's pods: one egg warms in each (decision 068).
	["bay.buySlot.button"] = {
		ru = "+1 капсула ●{price}",
		en = "+1 pod ●{price}",
	},
	-- {price} is store.robux.hint ("19 R$").
	["bay.buySlotRobux.button"] = {
		ru = "+1 капсула {price}",
		en = "+1 pod {price}",
	},
	["bay.incubatorWaiting.hint"] = {
		ru = "Ждут капсулы: {count}",
		en = "Waiting for a pod: {count}",
	},
	["bay.incubatorFree.hint"] = {
		ru = "Есть свободная капсула",
		en = "A pod is free",
	},
	["bay.incubatorFull.hint"] = {
		ru = "Все капсулы заняты",
		en = "Every pod is taken",
	},
	["egg.waiting.hint"] = {
		ru = "Ждёт капсулы",
		en = "Waiting for a pod",
	},
	["bay.incubatorEmpty.hint"] = {
		ru = "Пусто. Укради яйцо и принеси его сюда",
		en = "Empty. Steal an egg and bring it here",
	},
	-- Hatches in a row, one toast: how many, and the best earner of them.
	["alien.hatchedMany.toast"] = {
		ru = {
			one = "+{count} пришелец! Лучший: {name}",
			few = "+{count} пришельца! Лучший: {name}",
			many = "+{count} пришельцев! Лучший: {name}",
		},
		en = { one = "+{count} alien! Best: {name}", other = "+{count} aliens! Best: {name}" },
	},
	-- The second line of a hatch or crossbreed toast: the alien's income and where it went.
	["alien.hatchedIncome.hint"] = {
		ru = "●{income}/с · {place}",
		en = "●{income}/s · {place}",
	},
	["bay.autoPlace.button"] = {
		ru = "Лучших на места",
		en = "Best to spots",
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
	["bay.selectedPlace.hint"] = {
		ru = "Выбран: {name}. Он на месте: «Убрать с места» уберёт его в инвентарь",
		en = "Selected: {name}. It's on a spot: “Off the spot” moves it to the inventory",
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
		ru = "Точно? ●+{price}",
		en = "Sure? ●+{price}",
	},
	["bay.toPlace.button"] = {
		ru = "На место",
		en = "To a spot",
	},
	["bay.toInventory.button"] = {
		ru = "В инвентарь",
		en = "To inventory",
	},
	["bay.fromPlace.button"] = {
		ru = "На стеллаж",
		en = "To shelf",
	},
	["alien.hatched.toast"] = {
		ru = "Вылупился {name}",
		en = "Hatched: {name}",
	},
	["alien.crossbred.toast"] = {
		ru = "Скрестили! {name}",
		en = "Crossbred! {name}",
	},
	["place.spot.hint"] = {
		ru = "на место",
		en = "to a spot",
	},
	["place.floor.hint"] = {
		ru = "на стеллаж",
		en = "to the shelf",
	},
	["alien.tierIncome.hint"] = {
		ru = "{tier} · ●{income}/с",
		en = "{tier} · ●{income}/s",
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
	["notice.notEnoughCoins.toast"] = {
		ru = "Не хватает монет. Подожди доход",
		en = "Not enough coins. Wait for income",
	},
	["notice.maxPlaces.toast"] = {
		ru = "Все места уже куплены",
		en = "You've bought every spot",
	},
	["notice.maxIncubatorSlots.toast"] = {
		ru = "Все капсулы уже куплены",
		en = "You've bought every pod",
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
		ru = "Тебя не было {time}",
		en = "You were away {time}",
	},
	-- Under the big numbers of the welcome-back screen.
	["welcome.places.hint"] = {
		ru = "принесли пришельцы",
		en = "from your aliens",
	},
	["welcome.trainer.hint"] = {
		ru = "накачал тренажёр",
		en = "from your trainer",
	},
	["welcome.eggsReady.hint"] = {
		ru = "Готово яиц: {count}. Вылупи их на острове",
		en = "Eggs ready: {count}. Hatch them on your island",
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
	["trainer.gain.hint"] = {
		ru = "+{gain} ⚡",
		en = "+{gain} ⚡",
	},
	-- The terminals on a player's island (docs/design/screens/terminals.md).
	["terminal.places.title"] = {
		ru = "Места",
		en = "Spots",
	},
	["terminal.places.hint"] = {
		ru = "Пришелец на месте приносит монеты",
		en = "An alien on a spot earns coins",
	},
	["terminal.incubator.title"] = {
		ru = "Инкубатор",
		en = "Incubator",
	},
	["terminal.trainer.title"] = {
		ru = "Тренажёр",
		en = "Trainer",
	},
	-- The big number on a terminal: how many there are of how many can be.
	["terminal.count.title"] = {
		ru = "{count} / {max}",
		en = "{count} / {max}",
	},
	["terminal.level.title"] = {
		ru = "Ур. {level}",
		en = "Lv. {level}",
	},
	["terminal.trainerRate.hint"] = {
		ru = "+{rate} ⚡/с на тренажёре",
		en = "+{rate} ⚡/s on the trainer",
	},
	-- The buy button on a terminal: just the price, the terminal's title says what it buys.
	["terminal.price.button"] = {
		ru = "●{price}",
		en = "●{price}",
	},
	["terminal.maxed.hint"] = {
		ru = "Всё куплено",
		en = "Maxed out",
	},
	["key.mouseLeft.hint"] = {
		ru = "ЛКМ",
		en = "LMB",
	},
	["key.shift.hint"] = {
		ru = "Shift",
		en = "Shift",
	},
	["key.space.hint"] = {
		ru = "Пробел",
		en = "Space",
	},
	["key.move.hint"] = {
		ru = "WASD",
		en = "WASD",
	},
	-- The controls window (docs/design/screens/controls.md): what each flight button does.
	["controls.window.title"] = {
		ru = "Управление",
		en = "Controls",
	},
	["controls.fly.title"] = {
		ru = "Лететь",
		en = "Fly",
	},
	["controls.flyTouch.hint"] = {
		ru = "Джойстик: летишь туда, куда смотрит камера",
		en = "Stick: you fly where the camera looks",
	},
	["controls.flyKeys.hint"] = {
		ru = "Летишь туда, куда смотрит камера",
		en = "You fly where the camera looks",
	},
	["controls.up.title"] = {
		ru = "Вверх",
		en = "Up",
	},
	["controls.up.hint"] = {
		ru = "Выше. На станции прыгни дважды — и летишь",
		en = "Go higher. On the station, double-jump to fly",
	},
	["controls.down.title"] = {
		ru = "Вниз",
		en = "Down",
	},
	["controls.down.hint"] = {
		ru = "Ниже. Коснулся пола — снова идёшь пешком",
		en = "Go lower. Touch the floor to walk again",
	},
	["controls.slowMode.title"] = {
		ru = "Медленный режим",
		en = "Slow mode",
	},
	["controls.slowMode.hint"] = {
		ru = "Летишь тише: так проще подлететь к яйцу",
		en = "Fly slower to line up with an egg",
	},
	["controls.grab.title"] = {
		ru = "Схватить",
		en = "Grab",
	},
	["controls.grab.hint"] = {
		ru = "Рядом с яйцом: джетпак сам подлетит и возьмёт его",
		en = "Near an egg: your jetpack flies in and takes it",
	},
	["controls.strike.title"] = {
		ru = "Удар",
		en = "Strike",
	},
	["controls.strike.hint"] = {
		ru = "Рывок кулаком вперёд: выбивает яйцо у того, кто рядом",
		en = "Punch forward to knock the egg out of someone close",
	},
	["controls.harpoon.title"] = {
		ru = "Гарпун",
		en = "Harpoon",
	},
	["controls.harpoon.hint"] = {
		ru = "Бьёт издалека по прицелу и тянет яйцо к тебе",
		en = "Hits what you aim at from afar and pulls the egg to you",
	},
	["controls.bomb.title"] = {
		ru = "Гравибомба",
		en = "Gravity bomb",
	},
	["controls.bomb.hint"] = {
		ru = "Через секунду взрывается и отбрасывает всех рядом",
		en = "Goes off after a second and throws everyone nearby back",
	},
	["controls.hide.hint"] = {
		ru = "Больше не показывать",
		en = "Don't show again",
	},
	["controls.ok.button"] = {
		ru = "Понятно",
		en = "Got it",
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
		ru = "{name}: звёздное яйцо в инкубаторе!",
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
		ru = "●+{coins}",
		en = "●+{coins}",
	},
	-- Beside a check mark, at the end of a guardian's row.
	["index.setDone.hint"] = {
		ru = "Собран",
		en = "Done",
	},
	-- Over the column of guardian names.
	-- Under the count while the meteor section has no finds.
	["index.meteorSource.hint"] = {
		ru = "Метеоритных выводят из метеоритных яиц",
		en = "Meteor aliens hatch from meteor eggs",
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
		ru = "Индекс: ●+{coins}",
		en = "Index: ●+{coins}",
	},
	["notice.stormTeleport.toast"] = {
		ru = "Буря! Тебя вернуло на остров",
		en = "Storm! Back to your island you go",
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
		ru = "Забрать подарок",
		en = "Claim gift",
	},
	["gift.miss.hint"] = {
		ru = "Пропустишь день — серия начнётся заново",
		en = "Miss a day and your streak starts over",
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
		ru = "Подарок: ●+{coins} и ⚡+{speed}",
		en = "Gift: ●+{coins} and ⚡+{speed}",
	},
	-- The community gift (decision 098): its window, the invitation after the tutorial, the gift.
	["community.window.title"] = {
		ru = "Сообщество игры",
		en = "Game community",
	},
	["community.gift.hint"] = {
		ru = "Вступи в сообщество игры и забери подарок. Он даётся один раз",
		en = "Join the game's community and grab a gift. You get it once",
	},
	["community.join.button"] = {
		ru = "Вступить",
		en = "Join",
	},
	["community.checking.button"] = {
		ru = "Проверяю…",
		en = "Checking…",
	},
	["community.invite.toast"] = {
		ru = "Вступи в сообщество — ⚡+{speed}!",
		en = "Join our community for ⚡+{speed}!",
	},
	["community.rewarded.toast"] = {
		ru = "Подарок сообщества: ⚡+{speed}",
		en = "Community gift: ⚡+{speed}",
	},
	["notice.notInCommunity.toast"] = {
		ru = "Ты пока не в сообществе. Попробуй ещё",
		en = "Not in the community yet. Try again",
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
		ru = "Награда: ●+{coins} и ⚡+{speed}",
		en = "Reward: ●+{coins} and ⚡+{speed}",
	},
	["quests.confirm.hint"] = {
		ru = "Точно?",
		en = "Sure?",
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
	-- The station's kiosks (decision 087): the name on each one's plate and its prompt.
	["kiosk.jetpacks.title"] = {
		ru = "Джетпаки",
		en = "Jetpacks",
	},
	["kiosk.store.title"] = {
		ru = "Магазин",
		en = "Shop",
	},
	["kiosk.quests.title"] = {
		ru = "Задания",
		en = "Quests",
	},
	["kiosk.gift.title"] = {
		ru = "Подарок",
		en = "Gift",
	},
	["kiosk.open.button"] = {
		ru = "Открыть",
		en = "Open",
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
	-- The shop window's footer and the kiosk sign. The marks of one jetpack (I, II) share a flame.
	["shop.window.hint"] = {
		ru = "Чем мощнее джетпак, тем выше скорость. У каждого своё пламя",
		en = "A stronger jetpack means more speed. Each has its own flame",
	},
	["shop.multiplier.hint"] = {
		ru = "⚡ ×{factor}",
		en = "⚡ ×{factor}",
	},
	-- The tag on the owned jetpack's row.
	["shop.owned.hint"] = {
		ru = "Твой",
		en = "Yours",
	},
	["shop.buy.button"] = {
		ru = "Купить: ●{price}",
		en = "Buy: ●{price}",
	},
	-- Over the card of the jetpack to buy next.
	["shop.next.title"] = {
		ru = "Следующий джетпак",
		en = "Next jetpack",
	},
	-- Over the card once the top jetpack is owned.
	["shop.ownedTop.title"] = {
		ru = "Твой джетпак",
		en = "Your jetpack",
	},
	-- The multiplier now and after buying the next jetpack.
	["shop.upgrade.hint"] = {
		ru = "⚡ ×{from} → ×{to}",
		en = "⚡ ×{from} → ×{to}",
	},
	-- The player's speed now and after buying the next jetpack.
	["shop.gain.hint"] = {
		ru = "Скорость: {from} → {to}",
		en = "Speed: {from} → {to}",
	},
	-- Over the dim buy button while coins are short.
	["shop.saving.hint"] = {
		ru = "Копишь: ●{coins} / {price}",
		en = "Saving up: ●{coins} / {price}",
	},
	["shop.ladder.title"] = {
		ru = "Все джетпаки",
		en = "All jetpacks",
	},
	-- Jetpacks owned (the starter counts) of all of them.
	["shop.ladderCount.hint"] = {
		ru = "{owned} из {total}",
		en = "{owned} of {total}",
	},
	-- In place of the buy button once the top jetpack is owned.
	["shop.top.hint"] = {
		ru = "Это лучший джетпак. Дальше скорость качает тренажёр",
		en = "That's the best jetpack. Now the trainer grows your speed",
	},
	["shop.bought.toast"] = {
		ru = "Новый джетпак: {name}!",
		en = "New jetpack: {name}!",
	},
	-- The double-jump hint after the tutorial (decision 096).
	["jetpack.doubleJump.toast"] = {
		ru = "Прыгни дважды — и лети на джетпаке!",
		en = "Jump twice to fly your jetpack!",
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
	["alien.income.hint"] = {
		ru = "●{income}/с",
		en = "●{income}/s",
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
	-- Short tier names over the narrow columns of the index.
	["tier.commonShort.title"] = {
		ru = "Обычн.",
		en = "Common",
	},
	["tier.uncommonShort.title"] = {
		ru = "Необычн.",
		en = "Uncom.",
	},
	["tier.rareShort.title"] = {
		ru = "Редкий",
		en = "Rare",
	},
	["tier.epicShort.title"] = {
		ru = "Эпич.",
		en = "Epic",
	},
	["tier.legendaryShort.title"] = {
		ru = "Легенд.",
		en = "Legend.",
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
	-- The pin over the player's own island while they are anywhere else (decision 069).
	["island.beacon.title"] = {
		ru = "Твой остров",
		en = "Your island",
	},
	-- The tutorial (decision 065): one line at a time, what to do now.
	["tutorial.steal.hint"] = {
		ru = "Лети к стражу и укради яйцо из гнезда",
		en = "Fly to a guardian and steal its egg",
	},
	-- At an egg, while the grab button shows.
	["tutorial.grabButton.hint"] = {
		ru = "Жми кнопку с яйцом",
		en = "Hit the egg button",
	},
	["tutorial.carryHome.hint"] = {
		ru = "Неси яйцо на станцию. За границей станции страж отстанет",
		en = "Fly the egg home. The guardian stops at the station border",
	},
	["tutorial.hatch.hint"] = {
		ru = "Яйцо готово! Беги к инкубатору и вылупи его",
		en = "Your egg is ready! Go to the incubator and hatch it",
	},
	-- {speed}: the next guardian's recommended speed ("42").
	["tutorial.train.hint"] = {
		ru = "Встань на тренажёр и накачай {speed} ⚡",
		en = "Stand on the trainer and reach {speed} ⚡",
	},
	["tutorial.stealStronger.hint"] = {
		ru = "Ты стал быстрее! Укради яйцо у следующего стража",
		en = "You're faster now! Steal from the next guardian",
	},
	["tutorial.done.hint"] = {
		ru = "Отлично! На станции тебя ждут джетпаки и задания",
		en = "Nice! Jetpacks and quests are waiting at the station",
	},
	-- Pins over what the tutorial points at.
	["tutorial.egg.title"] = {
		ru = "Твоё яйцо",
		en = "Your egg",
	},
	["tutorial.trainer.title"] = {
		ru = "Тренажёр",
		en = "Trainer",
	},
	-- The pin over the player's own island while they carry an egg home.
	["tutorial.bay.title"] = {
		ru = "Твой остров",
		en = "Your island",
	},
	["marker.distance.hint"] = {
		ru = "{distance} м",
		en = "{distance} m",
	},
	-- To everyone else on the server when a player grabs a rare enough egg: go and get it
	-- (docs/design/screens/markers.md). {name}: the player's display name.
	["radar.epicCarried.toast"] = {
		ru = "{name} несёт эпическое яйцо. Лови!",
		en = "{name} has an epic egg. Get it!",
	},
	["radar.legendaryCarried.toast"] = {
		ru = "{name} несёт легендарное яйцо. Лови!",
		en = "{name} has a legendary egg. Get it!",
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
		ru = "R$ {price}",
		en = "R$ {price}",
	},
	-- Column titles of the store: passes, and purchases that pay at once.
	["store.forever.title"] = {
		ru = "Навсегда",
		en = "Forever",
	},
	["store.now.title"] = {
		ru = "Сразу",
		en = "Right now",
	},
	-- Incubator pods now and after buying one.
	["store.slotGrow.hint"] = {
		ru = "{from} → {to}",
		en = "{from} → {to}",
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
		ru = "Тренажёр даёт ×{factor} ⚡, даже когда тебя нет в игре",
		en = "Your trainer gives ×{factor} ⚡, even while you're away",
	},
	["store.nightShift.title"] = {
		ru = "Ночная смена",
		en = "Night shift",
	},
	["store.nightShift.hint"] = {
		ru = "Без тебя пришельцы приносят монеты {income} ч вместо {incomeBase}, тренажёр качает {training} ч вместо {trainingBase}",
		en = "Offline, aliens earn for {income} h, not {incomeBase}, and the trainer works {training} h, not {trainingBase}",
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
		ru = "Капсула инкубатора",
		en = "Incubator pod",
	},
	["store.slot.hint"] = {
		ru = "Ещё одна капсула сразу, без монет. Сейчас капсул: {count}",
		en = "One more pod right away, no coins. Pods now: {count}",
	},
	["store.slotMax.hint"] = {
		ru = "Все капсулы инкубатора уже твои",
		en = "Every incubator pod is yours",
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
		ru = "Яйцо готово! Вылупи его на острове",
		en = "Egg ready! Hatch it on your island",
	},
	["store.slot.toast"] = {
		ru = "+1 капсула в инкубаторе",
		en = "+1 incubator pod",
	},
	["store.double.toast"] = {
		ru = "Ещё ●+{coins} и ⚡+{speed}",
		en = "Another ●+{coins} and ⚡+{speed}",
	},
	-- The purchase found nothing to apply to (the egg hatched, every pod bought).
	["store.compensated.toast"] = {
		ru = "Не к чему применить. Держи ●+{coins}",
		en = "Nothing to use it on. Here's ●+{coins}",
	},
	-- Aliens on the shelf, its limit, selling several, ready trios and the hints after the
	-- tutorial (decision 110, docs/design/screens/aliens-and-hints.md).
	["alien.openBay.button"] = {
		ru = "В отсек",
		en = "Open bay",
	},
	["place.placeBest.button"] = {
		ru = "Лучшего сюда",
		en = "Best one here",
	},
	["place.free.hint"] = {
		ru = "Свободное место",
		en = "Free spot",
	},
	["egg.shelfFull.button"] = {
		ru = "Стеллаж полный",
		en = "Shelf is full",
	},
	["egg.shelfFull.hint"] = {
		ru = "Стеллаж полный",
		en = "Shelf full",
	},
	["bay.shelf.title"] = {
		ru = "Стеллаж {count}/{max}",
		en = "Shelf {count}/{max}",
	},
	["bay.shelfEmpty.hint"] = {
		ru = "Пусто",
		en = "Empty",
	},
	["bay.shelfFull.hint"] = {
		ru = "Стеллаж полный, яйца ждут. Продай или скрести кого-нибудь",
		en = "Shelf full, eggs are waiting. Sell or crossbreed someone",
	},
	["bay.shelfFull.toast"] = {
		ru = "Стеллаж полный! Яйца не вылупятся",
		en = "Shelf full! Eggs can't hatch",
	},
	["notice.shelfFull.toast"] = {
		ru = "Стеллаж полный: продай или скрести",
		en = "Shelf full: sell or crossbreed",
	},
	["alien.toPlace.toast"] = {
		ru = "{name} → на место",
		en = "{name} → to a spot",
	},
	["bay.trios.title"] = {
		ru = "Можно скрестить",
		en = "Ready to crossbreed",
	},
	["bay.selectAll.button"] = {
		ru = "Выбрать всех",
		en = "Select all",
	},
	["bay.selectNone.button"] = {
		ru = "Снять выбор",
		en = "Unselect all",
	},
	["bay.selectedMany.hint"] = {
		ru = "Выбрано: {count}",
		en = "Selected: {count}",
	},
	["bay.sellMany.button"] = {
		ru = "Продать {count} ●{price}",
		en = "Sell {count} ●{price}",
	},
	["coach.shelf.hint"] = {
		ru = "Места заняты, новый пришелец на стеллаже. Купи место у терминала, и он встанет сам",
		en = "All spots taken. Buy one at the terminal and your new alien moves in",
	},
	["coach.jetpack.hint"] = {
		ru = "Хватает на новый джетпак! Лети в магазин джетпаков на станции",
		en = "You can afford a new jetpack! Fly to the jetpack shop at the station",
	},
	["coach.quest.hint"] = {
		ru = "Задание выполнено! Лети на станцию за наградой",
		en = "Quest done! Fly to the station for your reward",
	},
	["coach.crossbreed.hint"] = {
		ru = "Трое одинаковых! Скрести их: шанс на ступень выше",
		en = "Three of a kind! Crossbreed them for a shot at a higher tier",
	},
	["coach.sell.hint"] = {
		ru = "Стеллаж полный, яйца ждут. Продай слабых: монеты сразу",
		en = "Shelf full, eggs are waiting. Sell the weak ones for coins",
	},
	["coach.crossbreed.button"] = {
		ru = "Скрестить",
		en = "Crossbreed",
	},
	["coach.bay.button"] = {
		ru = "Открыть отсек",
		en = "Open bay",
	},
	["tutorial.station.title"] = {
		ru = "Станция",
		en = "Station",
	},
}

return table.freeze(Strings)
