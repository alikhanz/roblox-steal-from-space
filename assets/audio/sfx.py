"""Every sound of the game, style A "soft cartoon" (docs/design/SOUND.md).

    python assets/audio/sfx.py [out/audio] [Name ...]

Writes <Name>.wav per sound (44.1 kHz mono, 16 bit) and listen.html to hear them all. Deterministic:
each sound seeds its own noise, so a run gives the same files every time. Needs numpy and scipy
(decision 097): a venv with `pip install numpy scipy`.
"""

import base64
import os
import sys

import numpy as np

import synth
from synth import (
    adsr,
    bell,
    bp,
    curve,
    decay,
    drive,
    finish,
    hp,
    lp,
    make_loop,
    marimba,
    midi,
    mix,
    n_,
    noise,
    osc,
    reverb,
    save,
    svf,
    t_,
)

ROOM = 0.5  # the small room every one-shot sits in


def room(x, seconds=ROOM, wet=0.15):
    return reverb(x, seconds, wet)


def whoosh(dur, lo, hi, peak_at=0.7, width=2.2):
    """A soft swish: band-passed noise whose band slides from lo to hi."""
    fc = curve(dur, [(0, lo), (dur, hi)], "exp")
    x = svf(noise(dur), fc, q=1 / width, mode="bp")
    return x * curve(dur, [(0, 0), (dur * peak_at, 1), (dur, 0)]) ** 1.5


def bonk(dur, f0, f1, tau, rough=2.0):
    """The cartoon knock: a triangle dropping in pitch, a little driven for a phone speaker."""
    return drive(osc(curve(dur, [(0, f0), (dur * 0.45, f1), (dur, f1 * 0.85)], "exp"), shape="tri"), rough) * decay(dur, tau)


def thwack(dur=0.06, lo=600, hi=2200, tau=0.015):
    return bp(noise(dur), lo, hi) * decay(dur, tau)


def wood(f=1250, dur=0.05):
    return (osc(f, dur) * 0.6 + bp(noise(dur), 1200, 3000)) * decay(dur, 0.012)


def slide(dur, f0, f1, shape="sine", a=0.004, r=0.04):
    return osc(curve(dur, [(0, f0), (dur, f1)], "exp"), shape=shape) * adsr(dur, a, dur * 0.4, 0.6, r)


def sparkle(notes, gap, tau=0.25, gain=0.3, dur=0.6):
    return mix(*[(i * gap, bell(midi(m), dur, tau=tau), gain) for i, m in enumerate(notes)])


def arp(notes, gap, dur=0.7, gain=0.7):
    return mix(*[(i * gap, marimba(midi(m), dur), gain) for i, m in enumerate(notes)])


def boing(dur, f, depth=0.35, rate=14, tau=0.2):
    t = t_(dur)
    fr = f * (1 + depth * np.exp(-t / 0.15) * np.sin(2 * np.pi * rate * t))
    return osc(fr, shape="tri") * decay(dur, tau)


# ------------------------------------------------------------------ guardian alarm (chosen: "8 hilo_beeps")

ALARM_LO, ALARM_HI, ALARM_PERIOD = 740, 1100, 0.4
ALARM_LOOP = ALARM_PERIOD * 5


def rough_tone(f):
    x = 0.5 * osc(f, shape="saw") + 0.4 * osc(f * 0.5, shape="square") + 0.3 * osc(f, shape="tri")
    return lp(drive(lp(x, 3800), 2.5), 5500)


def alarm_siren(dur):
    t = t_(dur)
    ph = (t % ALARM_PERIOD) / ALARM_PERIOD
    step = np.clip(np.where(ph < 0.5, ph / 0.06, 1 - (ph - 0.5) / 0.06), 0, 1)
    f = (ALARM_LO + (ALARM_HI - ALARM_LO) * step) * (1 + 0.015 * np.sin(2 * np.pi * 8 * t))
    # Tuned a hair so the loop holds a whole number of cycles of the sub-octave: it repeats exactly.
    cycles = f[: n_(ALARM_LOOP)].mean() * ALARM_LOOP
    f = f * (round(cycles / 2) * 2 / cycles)
    x = rough_tone(f)
    gate = ((t * 8) % 1) < 0.45
    beeps = lp(osc(1760, dur, shape="square") * gate, 6000)
    return x + 0.18 * beeps


def AlarmStart():
    b1 = slide(0.14, 700, 1100, "square", 0.003, 0.04)
    b2 = slide(0.2, 1100, 600, "square", 0.003, 0.06)
    hit = drive(bp(noise(0.12), 200, 1500), 2) * decay(0.12, 0.04)
    return room(lp(drive(mix((0, b1, 0.6), (0.15, b2, 0.6), (0.15, hit, 0.4)), 2.5), 5000), 0.5, 0.12)


def AlarmLoop():
    return make_loop(alarm_siren, ALARM_LOOP, 0.03, preroll=ALARM_PERIOD, periodic=True)


# ------------------------------------------------------------------ eggs


def EggGrab():
    pop = slide(0.07, 380, 1200, "sine", 0.002, 0.02)
    sw = whoosh(0.14, 600, 2400, 0.8)
    tw = sparkle([91, 96], 0.05, tau=0.2, gain=0.35, dur=0.4)
    return room(mix((0, sw, 0.35), (0.06, pop, 0.9), (0.1, tw)))


def Delivery():
    up = arp([72, 76, 79, 84], 0.075, 0.8, 0.8)
    top = sparkle([84, 88, 91, 96], 0.03, tau=0.5, gain=0.35, dur=1.4)
    sw = slide(0.35, 500, 1050, "sine", 0.03, 0.1)
    return reverb(mix((0, up), (0.33, top), (0, sw, 0.25)), 0.9, 0.2)


def EggDrop():
    parts = []
    for i, (at, gain) in enumerate([(0, 1.0), (0.2, 0.6), (0.33, 0.38), (0.42, 0.22)]):
        parts.append((at, marimba(midi(86 - i), 0.35, tau=0.12), gain * 0.8))
        parts.append((at, bell(midi(98 - i), 0.3, tau=0.1), gain * 0.25))
    oops = slide(0.3, 900, 420, "tri", 0.01, 0.08)
    return room(mix((0, oops, 0.35), *parts))


def GuardianCatch():
    hit = bonk(0.3, 400, 150, 0.09, 3.0)
    clank = synth.fm(520, 1.41, curve(0.25, [(0, 4), (0.25, 0.5)], "exp"), 0.25) * decay(0.25, 0.06)
    wob = boing(0.5, 260, 0.4, 11, 0.15)
    return room(mix((0, hit, 1.0), (0, thwack(0.08, 500, 2200, 0.025), 1.0), (0, clank, 0.4), (0.05, wob, 0.45)))


# ------------------------------------------------------------------ fight


def StrikeSwing():
    return room(whoosh(0.18, 450, 2600, 0.75), 0.4, 0.1)


def StrikeHit():
    b = bonk(0.18, 420, 160, 0.06)
    return room(mix((0, b, 1.0), (0, wood(), 0.5), (0, thwack(), 0.6)), 0.4, 0.12)


def HarpoonShot():
    zip_ = slide(0.16, 280, 1600, "tri", 0.004, 0.04)
    wh = bp(noise(0.3), 800, 3500) * curve(0.3, [(0, 0.8), (0.3, 0)])
    ticks = mix(*[(i * 0.03, bp(noise(0.012), 2000, 5000) * decay(0.012, 0.004), 0.5 * (1 - i / 9)) for i in range(9)])
    return room(mix((0, zip_, 0.8), (0, wh, 0.4), (0.12, ticks, 0.6)))


def HarpoonGrab():
    thunk = mix((0, bonk(0.12, 380, 150, 0.04), 1.0), (0, thwack(0.05, 700, 2500, 0.012), 0.5))
    return room(mix((0, thunk), (0.02, boing(0.6, 330), 0.55)))


def BombThrow():
    tone = slide(0.25, 900, 380, "tri", 0.005, 0.08)
    return room(mix((0, whoosh(0.25, 2400, 700, 0.3), 0.6), (0, tone, 0.35)), 0.4, 0.1)


def BombBoom():
    dur = 1.3
    tt = t_(dur)
    f = curve(dur, [(0, 140), (0.25, 55), (dur, 40)], "exp") * (1 + 0.08 * np.sin(2 * np.pi * curve(dur, [(0, 6), (dur, 2)]) * tt))
    body = drive(osc(f * 2, shape="tri"), 2.5) * decay(dur, 0.35)
    suck = slide(0.07, 900, 250, "sine", 0.002, 0.02)  # a quick "fwomp" in: the gravity bit
    thump = bp(noise(0.5), 150, 1400) * decay(0.5, 0.12)
    wobble = osc(curve(1.0, [(0, 500), (1.0, 180)], "exp") * (1 + 0.1 * np.sin(2 * np.pi * 9 * t_(1.0))), shape="tri") * decay(1.0, 0.3)
    sp = sparkle([91, 88, 84, 79], 0.07, tau=0.3, gain=0.15)
    return reverb(mix((0, suck, 0.5), (0.05, body, 0.6), (0.05, thump, 0.9), (0.07, wobble, 0.5), (0.1, sp)), 1.0, 0.2)


def HitMe():
    bam = mix((0, bonk(0.2, 480, 200, 0.06, 2.5), 1.0), (0, thwack(0.07, 600, 2400, 0.02), 1.0))
    # stars circling the head while stunned: a little bell ring that wavers
    stars = []
    for i, m in enumerate([96, 100, 103, 100, 96, 100, 103, 108]):
        stars.append((0.18 + i * 0.12, bell(midi(m), 0.35, tau=0.12), 0.18 * (1 - i / 10)))
    return room(mix((0, bam), *stars), 0.6, 0.18)


# ------------------------------------------------------------------ jetpack and oxygen


def jet_hiss(dur):
    t = t_(dur)
    flutter = 1 + 0.15 * np.sin(2 * np.pi * 7 * t) + 0.08 * np.sin(2 * np.pi * 11.3 * t)
    hiss = bp(noise(dur), 500, 3200) * flutter
    rumble = lp(noise(dur), 300) * 2.0
    tone = osc(190 * (1 + 0.01 * np.sin(2 * np.pi * 5 * t)), shape="tri")
    return lp(0.6 * hiss + 0.5 * rumble + 0.12 * tone, 5000)


def JetLoop():
    return make_loop(jet_hiss, 2.0, 0.15)


def JetStart():
    puff = lp(noise(0.12), 900) * decay(0.12, 0.03)
    rise = whoosh(0.45, 400, 2400, 0.55)
    tone = slide(0.4, 200, 420, "tri", 0.02, 0.15)
    return room(mix((0, puff, 0.8), (0.04, rise, 0.7), (0.04, tone, 0.25)), 0.4, 0.1)


def OxygenLow():
    x = osc(1320, 0.12) * 0.8 + osc(2640, 0.12) * 0.15
    return room(x * adsr(0.12, 0.004, 0.05, 0.6, 0.04), 0.3, 0.1)


def OxygenRefill():
    breath = whoosh(0.6, 500, 3000, 0.85, 1.6)
    tone = slide(0.5, 440, 880, "sine", 0.05, 0.1)
    return room(mix((0, breath, 0.6), (0.08, tone, 0.35), (0.5, bell(midi(93), 0.4, tau=0.2), 0.2)))


# ------------------------------------------------------------------ events


def EventWarning():
    ding = mix((0, marimba(midi(76), 0.9, tau=0.35), 0.8), (0, bell(midi(88), 0.9, tau=0.4), 0.25))
    dong = mix((0, marimba(midi(72), 1.2, tau=0.45), 0.8), (0, bell(midi(84), 1.2, tau=0.5), 0.25))
    hum = osc(midi(48), 1.2, shape="tri") * adsr(1.2, 0.2, 0.3, 0.5, 0.6)
    return reverb(mix((0, ding), (0.32, dong), (0, hum, 0.15)), 1.0, 0.22)


def StormStart():
    dur = 3.0
    t = t_(dur)
    fc = 500 + 700 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.45 * t - 1.2)) + 300 * np.sin(2 * np.pi * 1.3 * t)
    howl = svf(noise(dur), fc, q=4.0, mode="bp")
    whistle = osc(fc * 1.5, shape="sine") * 0.06
    env = curve(dur, [(0, 0), (1.2, 1), (2.2, 0.8), (dur, 0)]) ** 1.3
    return room((howl + whistle) * env, 0.6, 0.12)


def MeteorFall():
    fall = 1.4  # MeteorLooks.STREAK.seconds: the impact lands with the meteor
    whistle = osc(curve(fall, [(0, 2200), (fall, 500)], "exp"), shape="sine") * curve(fall, [(0, 0), (fall * 0.8, 1), (fall, 0.6)]) ** 1.5
    roar = bp(noise(fall), 300, 2500) * curve(fall, [(0, 0), (fall, 1)]) ** 2
    impact = mix(
        (0, bonk(0.5, 200, 70, 0.14, 3.0), 1.0),
        (0, bp(noise(0.6), 150, 1600) * decay(0.6, 0.12), 0.9),
        *[(0.03 + i * 0.045, hp(noise(0.015), 2500) * decay(0.015, 0.004), 0.3 * (1 - i / 8)) for i in range(8)],
    )
    return reverb(mix((0, whistle, 0.35), (0, roar, 0.35), (fall, impact)), 0.9, 0.18)


def SerpentAppear():
    dur = 1.3
    t = t_(dur)
    f = curve(dur, [(0, 140), (0.35, 290), (0.9, 220), (dur, 110)], "exp") * (1 + 0.03 * np.sin(2 * np.pi * 26 * t))
    growl = osc(f, shape="saw") * (1 + 0.4 * np.sin(2 * np.pi * 31 * t))
    vowel = bp(growl, 500, 1300) * 1.2 + bp(growl, 2000, 3000) * 0.4  # an "aah" mouth
    x = drive(vowel, 2.0) * adsr(dur, 0.06, 0.4, 0.7, 0.4)
    return reverb(mix((0, x), (0.15, sparkle([96, 91], 0.1, gain=0.15), 1.0)), 1.0, 0.22)


def SerpentHit():
    gong = bell(midi(67), 0.9, tau=0.35, partials=((1, 1), (2.0, 0.5), (2.76, 0.4), (5.4, 0.15)))
    return room(mix((0, gong, 0.8), (0, bonk(0.16, 420, 170, 0.05), 0.7), (0, wood(1600), 0.4)), 0.6, 0.15)


def StarEggOut():
    notes = [84, 88, 91, 96, 100, 103, 108]
    run = sparkle(notes, 0.045, tau=0.4, gain=0.3, dur=1.0)
    pop = slide(0.08, 350, 1100, "sine", 0.002, 0.02)
    chord = mix(*[(0, bell(midi(m), 1.2, tau=0.5), 0.18) for m in [84, 88, 91]])
    return reverb(mix((0, pop, 0.7), (0.05, run), (0.35, chord)), 1.1, 0.25)


# ------------------------------------------------------------------ bay, purchases, rewards


def Hatch():
    cracks = mix(*[(d, hp(noise(0.02), 2500) * decay(0.02, 0.005), g) for d, g in [(0, 0.5), (0.13, 0.7), (0.22, 0.9)]])
    pop = slide(0.07, 350, 1100, "sine", 0.002, 0.02)
    tada = arp([79, 84, 88], 0.06, 0.6, 0.6)
    sp = sparkle([96, 100, 103, 108, 103], 0.05, tau=0.25, gain=0.3, dur=0.5)
    return reverb(mix((0, cracks), (0.32, pop, 0.9), (0.38, tada), (0.4, sp)), 0.8, 0.2)


def HatchRare():
    up = sparkle([72, 76, 79, 84, 88, 91, 96], 0.05, tau=0.35, gain=0.3, dur=0.8)
    t = t_(1.3)
    trem = 1 + 0.25 * np.sin(2 * np.pi * 9 * t)
    chord = mix(*[(0, bell(midi(m), 1.3, tau=0.6) * trem, 0.22) for m in [84, 88, 91, 96]])
    bass = marimba(midi(60), 0.9, tau=0.4)
    return reverb(mix((0, up), (0.36, chord), (0.36, bass, 0.5)), 1.2, 0.25)


def Crossbreed():
    bubbles = [(i * 0.11, slide(0.06, 220 * 1.3**i, 600 * 1.3**i, "sine", 0.004, 0.02), 0.6) for i in range(3)]
    pop = slide(0.07, 400, 1300, "sine", 0.002, 0.02)
    return room(mix(*bubbles, (0.36, pop, 0.9), (0.4, sparkle([96, 100], 0.05, gain=0.3, dur=0.5), 1.0)))


def coin(at=0.0):
    """The classic two-ping coin: a short high ping, then a higher ringing one."""
    ping = lambda m, tau: bell(midi(m), 0.6, tau=tau, partials=((1, 1), (2.0, 0.3), (3.0, 0.15), (4.2, 0.08)))
    return (at, mix((0, ping(95, 0.05), 0.5), (0.07, ping(100, 0.22), 0.6)))


def BuyCoins():
    return room(mix(coin(0), coin(0.14)), 0.5, 0.15)


def BuyRobux():
    fanfare = arp([72, 76, 79, 84], 0.06, 0.7, 0.6)
    chord = mix(*[(0, bell(midi(m), 1.0, tau=0.45), 0.2) for m in [84, 88, 91]])
    return reverb(mix(coin(0), coin(0.12), (0.22, fanfare), (0.42, chord)), 0.9, 0.2)


def Reward():
    gliss = sparkle([79, 83, 86, 91, 95, 98], 0.035, tau=0.3, gain=0.25, dur=0.6)
    return reverb(mix((0, gliss), coin(0.22), (0.22, marimba(midi(84), 0.7), 0.5)), 0.8, 0.2)


def TrainerOn():
    clack = mix((0, wood(900, 0.05), 0.8), (0.06, wood(1400, 0.05), 0.6), (0.06, thwack(0.05, 1500, 4000, 0.01), 0.4))
    engine = mix((0, whoosh(0.5, 300, 1800, 0.7), 0.6), (0, slide(0.5, 150, 330, "tri", 0.05, 0.15), 0.3))
    return room(mix((0, clack), (0.12, engine)), 0.4, 0.1)


def TrainerTick():
    return room(slide(0.08, 820, 1240, "sine", 0.003, 0.03), 0.25, 0.08)


def WindowOpen():
    return mix((0, whoosh(0.2, 700, 2600, 0.6, 1.8), 0.7), (0.02, slide(0.16, 520, 780, "sine", 0.02, 0.06), 0.25))


def WindowClose():
    return mix((0, whoosh(0.18, 2400, 700, 0.4, 1.8), 0.7), (0.02, slide(0.14, 700, 470, "sine", 0.02, 0.06), 0.25))


def Toast():
    return room(mix((0, marimba(midi(88), 0.5, tau=0.18), 0.7), (0, bell(midi(100), 0.5, tau=0.2), 0.2)), 0.5, 0.15)


def Denied():
    a = osc(midi(76), 0.13, shape="tri") * adsr(0.13, 0.005, 0.05, 0.7, 0.03)
    b = osc(curve(0.2, [(0, midi(72)), (0.2, midi(69))], "exp"), shape="tri") * adsr(0.2, 0.005, 0.08, 0.6, 0.08)
    return room(mix((0, a, 0.7), (0.14, b, 0.7)), 0.3, 0.1)


# ------------------------------------------------------------------ the list
# (name, what it is, when it plays) — the brief's table; listen.html shows the same words.

SOUNDS = [
    ("AlarmStart", "Тревога: начало", "Страж заметил пропажу яйца и погнался за тобой"),
    ("AlarmLoop", "Тревога: погоня (петля)", "Пока страж гонится за тобой; чужая погоня — от стража, тише"),
    ("EggGrab", "Яйцо в руках", "Взял яйцо из гнезда или подобрал выпавшее"),
    ("Delivery", "Доставка", "Яйцо засчитано на станции или своём острове"),
    ("EggDrop", "Яйцо выпало", "Яйцо выбили — у тебя или у другого, рядом"),
    ("GuardianCatch", "Страж ударил", "Страж догнал вора и ударил"),
    ("StrikeSwing", "Удар: взмах", "Кто-то бьёт (кнопка удара)"),
    ("StrikeHit", "Удар попал", "Удар попал по цели"),
    ("HarpoonShot", "Гарпун: выстрел", "Выстрел гарпуна"),
    ("HarpoonGrab", "Гарпун: захват", "Крюк зацепил цель"),
    ("BombThrow", "Бомба: бросок", "Брошена гравибомба"),
    ("BombBoom", "Бомба: взрыв", "Гравибомба взорвалась"),
    ("HitMe", "По тебе попали", "Тебя оглушили: страж, удар, бомба или змей"),
    ("JetLoop", "Джетпак (петля)", "Пока джетпак работает; громче и выше с тягой"),
    ("JetStart", "Джетпак: запуск", "Джетпак включился или завёлся после оглушения"),
    ("OxygenLow", "Кислород на исходе", "Меньше четверти: бип, чем меньше — тем чаще"),
    ("OxygenRefill", "Кислород: вдох", "Под куполом баллон пополняется после «на исходе»"),
    ("EventWarning", "Ивент объявлен", "Вместе с баннером бури, дождя, змея"),
    ("StormStart", "Буря началась", "Солнечная буря пришла"),
    ("MeteorFall", "Метеор", "Метеор падает в кратер (удар — в момент касания)"),
    ("SerpentAppear", "Змей появился", "Звёздный змей вылетел"),
    ("SerpentHit", "Попадание по змею", "Удар, гарпун или бомба попали в змея"),
    ("StarEggOut", "Звёздное яйцо выбито", "Третье попадание выбило звёздное яйцо"),
    ("Hatch", "Вылупление", "Пришелец вылупился (у редких — выше)"),
    ("HatchRare", "Вылупление: редкий", "Добавка, когда вылупился эпический или легендарный"),
    ("Crossbreed", "Скрещивание", "Три пришельца стали одним"),
    ("BuyCoins", "Покупка за монеты", "Место, капсула, тренажёр, джетпак"),
    ("BuyRobux", "Покупка за R$", "Покупка за робуксы прошла"),
    ("Reward", "Награда", "Задание, подарок за вход, индекс, доход за отсутствие"),
    ("TrainerOn", "Тренажёр: пристегнул", "Встал на стенд тренажёра"),
    ("TrainerTick", "Тренажёр: +⚡", "Выплата скорости на тренажёре (не чаще раза в секунду)"),
    ("WindowOpen", "Окно открылось", "Отсек, магазин, задания, индекс, подарок"),
    ("WindowClose", "Окно закрылось", "То же, закрытие"),
    ("Toast", "Уведомление", "Хорошая новость в уведомлении"),
    ("Denied", "Отказ", "Нельзя: тост отказа или нажата выключенная кнопка"),
]
LOOPS = {"AlarmLoop", "JetLoop"}


def render(name):
    synth.seed(name)
    x = globals()[name]()
    return finish(x, loop=name in LOOPS)


def page(out, names):
    rows = []
    for name, title, when in SOUNDS:
        if name not in names:
            continue
        with open(os.path.join(out, f"{name}.wav"), "rb") as f:
            data = base64.b64encode(f.read()).decode()
        loop = " loop" if name in LOOPS else ""
        rows.append(
            f'<tr><td><b>{title}</b><code>{name}</code></td><td>{when}</td>'
            f'<td><audio controls{loop} preload="none" src="data:audio/wav;base64,{data}"></audio></td></tr>'
        )
    html = (
        '<!doctype html><html lang="ru"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1"><title>Звуки игры</title><style>'
        ":root{color-scheme:dark}body{margin:0;padding:16px;background:#070a1e;color:#eaf2ff;font:15px/1.4 system-ui,sans-serif}"
        "h1{font-size:20px;margin:0 0 4px}p{color:#9db6d2;margin:0 0 14px}table{border-collapse:collapse;width:100%}"
        "td{border-bottom:1px solid rgba(130,236,255,.2);padding:8px 6px;vertical-align:middle}"
        "td:first-child{width:26%}td:nth-child(2){color:#9db6d2}code{display:block;color:#82ecff;font-size:12px}"
        "audio{width:260px;max-width:100%}</style></head><body><h1>Звуки игры — стиль A</h1>"
        "<p>Петли (тревога погони, джетпак) играют по кругу — останови сам.</p>"
        f"<table>{''.join(rows)}</table></body></html>"
    )
    with open(os.path.join(out, "listen.html"), "w", encoding="utf-8") as f:
        f.write(html)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join("out", "audio")
    only = set(sys.argv[2:])
    os.makedirs(out, exist_ok=True)
    names = [s[0] for s in SOUNDS]
    for name in names:
        if only and name not in only:
            continue
        x = render(name)
        save(os.path.join(out, f"{name}.wav"), x)
        print(f"{name:14s} {len(x) / synth.SR:5.2f}s")
    page(out, [n for n in names if os.path.exists(os.path.join(out, f"{n}.wav"))])


if __name__ == "__main__":
    main()
