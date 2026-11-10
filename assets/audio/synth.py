"""Tiny offline synth for game sound effects: oscillators, envelopes, filters, reverb, mixing.

Everything is mono float64 at SR; a "signal" is a numpy array.
"""

import zlib

import numpy as np
from scipy import signal as sps
from scipy.io import wavfile

SR = 44100
RNG = np.random.default_rng(7)


def seed(name):
    """Every sound draws its own noise: changing one sound never changes another."""
    global RNG
    RNG = np.random.default_rng(zlib.crc32(name.encode()))


def n_(dur):
    return max(1, int(round(dur * SR)))


def t_(dur):
    return np.arange(n_(dur)) / SR


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# ---------------------------------------------------------------- curves


def curve(dur, points, shape="lin"):
    """Piecewise curve over `dur` seconds; points are (time, value). shape: lin | exp."""
    t = t_(dur)
    ts = np.array([p[0] for p in points], dtype=float)
    vs = np.array([p[1] for p in points], dtype=float)
    if shape == "exp":
        return np.exp(np.interp(t, ts, np.log(np.maximum(vs, 1e-9))))
    return np.interp(t, ts, vs)


def adsr(dur, a=0.005, d=0.1, s=0.0, r=0.05, peak=1.0):
    """Attack-decay-sustain-release spanning exactly `dur` (release at the end)."""
    n = n_(dur)
    env = np.zeros(n)
    na, nd, nr = n_(a), n_(d), n_(r)
    na = min(na, n)
    env[:na] = np.linspace(0, peak, na, endpoint=False) if na > 0 else 0
    i = na
    k = min(nd, n - i)
    if k > 0:
        env[i : i + k] = peak + (s - peak) * (1 - np.exp(-5 * np.arange(k) / max(nd, 1))) / (1 - np.exp(-5))
        i += k
    if i < n:
        env[i:] = s
    if nr > 0 and nr < n:
        env[-nr:] *= np.linspace(1, 0, nr)
    return env


def decay(dur, tau, a=0.002):
    """Fast attack, exponential decay with time constant tau."""
    t = t_(dur)
    env = np.exp(-t / tau)
    na = n_(a)
    if na > 1:
        env[:na] *= np.linspace(0, 1, na)
    return env


# ---------------------------------------------------------------- oscillators


def _as_freq(freq, dur):
    f = np.asarray(freq, dtype=float)
    if f.ndim == 0:
        f = np.full(n_(dur), float(f))
    return f


def phase(freq, dur=None, ph0=0.0):
    f = _as_freq(freq, dur)
    return (ph0 + np.cumsum(f) / SR) % 1.0, f


def _blep(p, dt):
    y = np.zeros_like(p)
    m = p < dt
    x = p[m] / dt[m]
    y[m] = 2 * x - x * x - 1
    m = p > 1 - dt
    x = (p[m] - 1) / dt[m]
    y[m] = x * x + 2 * x + 1
    return y


def osc(freq, dur=None, shape="sine", duty=0.5, ph0=0.0):
    p, f = phase(freq, dur, ph0)
    dt = np.clip(f / SR, 1e-6, 0.5)
    if shape == "sine":
        return np.sin(2 * np.pi * p)
    if shape == "tri":
        return 2 * np.abs(2 * p - 1) - 1
    if shape == "saw":
        return 2 * p - 1 - _blep(p, dt)
    if shape in ("square", "pulse"):
        a = 2 * p - 1 - _blep(p, dt)
        p2 = (p + 1 - duty) % 1.0
        b = 2 * p2 - 1 - _blep(p2, dt)
        return a - b
    if shape == "chip":  # naive pulse: crunchy on purpose
        return np.where(p < duty, 1.0, -1.0)
    if shape == "chiptri":  # 4-bit stepped triangle (NES-like)
        tri = 2 * np.abs(2 * p - 1) - 1
        return np.round(tri * 7.5) / 7.5
    raise ValueError(shape)


def supersaw(freq, dur, voices=5, detune=0.012):
    f = _as_freq(freq, dur)
    out = np.zeros_like(f)
    for i in range(voices):
        d = 1 + detune * (i - (voices - 1) / 2) / ((voices - 1) / 2 or 1)
        out += osc(f * d, shape="saw", ph0=RNG.random())
    return out / voices


def fm(fc, ratio, index, dur):
    """Two-operator FM; fc and index may be arrays."""
    fc = _as_freq(fc, dur)
    idx = np.broadcast_to(np.asarray(index, dtype=float), fc.shape)
    pm, _ = phase(fc * ratio)
    pc, _ = phase(fc)
    return np.sin(2 * np.pi * pc + idx * np.sin(2 * np.pi * pm))


def noise(dur):
    return RNG.uniform(-1, 1, n_(dur))


def chip_noise(dur, rate):
    """Sample-and-hold noise with a (possibly time-varying) clock rate, like a console noise channel."""
    n = n_(dur)
    r = np.broadcast_to(np.asarray(rate, dtype=float), (n,))
    clock = np.floor(np.cumsum(r / SR)).astype(int)
    vals = RNG.choice([-1.0, 1.0], clock[-1] + 1)
    return vals[clock]


def bell(freq, dur, tau=0.6, partials=((1, 1), (2.76, 0.4), (5.4, 0.2), (8.93, 0.1))):
    t = t_(dur)
    out = np.zeros_like(t)
    for ratio, amp in partials:
        out += amp * np.sin(2 * np.pi * freq * ratio * t + RNG.random() * 6) * np.exp(-t * ratio**0.6 / tau)
    return out * decay(dur, 10, a=0.001)


def marimba(freq, dur, tau=0.25):
    t = t_(dur)
    out = np.sin(2 * np.pi * freq * t) * np.exp(-t / tau)
    out += 0.35 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t / (tau * 0.25))
    out += 0.12 * np.sin(2 * np.pi * freq * 10 * t) * np.exp(-t / (tau * 0.08))
    return out * decay(dur, 10, a=0.0015)


# ---------------------------------------------------------------- filters


def lp(x, fc, order=2):
    return sps.sosfilt(sps.butter(order, min(fc, SR * 0.49), "low", fs=SR, output="sos"), x)


def hp(x, fc, order=2):
    return sps.sosfilt(sps.butter(order, fc, "high", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    return sps.sosfilt(sps.butter(order, [lo, min(hi, SR * 0.49)], "band", fs=SR, output="sos"), x)


def svf(x, fc, q=0.7, mode="lp"):
    """Time-varying state-variable filter (TPT). fc may be an array."""
    n = len(x)
    fc = np.broadcast_to(np.asarray(fc, dtype=float), (n,))
    g = np.tan(np.pi * np.clip(fc, 20, SR * 0.45) / SR)
    k = 1.0 / q
    a1 = 1 / (1 + g * (g + k))
    ic1 = ic2 = 0.0
    out = np.empty(n)
    xs = x.tolist()
    gs = g.tolist()
    a1s = a1.tolist()
    for i in range(n):
        gi = gs[i]
        v3 = xs[i] - ic2
        v1 = a1s[i] * ic1 + gi * a1s[i] * v3
        v2 = ic2 + gi * v1
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        if mode == "lp":
            out[i] = v2
        elif mode == "bp":
            out[i] = v1
        else:
            out[i] = xs[i] - k * v1 - v2
    return out


# ---------------------------------------------------------------- effects


def drive(x, amount):
    return np.tanh(x * amount) / np.tanh(amount)


def crush(x, bits=6, hold=4):
    y = np.repeat(x[::hold], hold)[: len(x)]
    q = 2 ** (bits - 1)
    return np.round(y * q) / q


def reverb(x, seconds=1.2, mix=0.25, damp=6000, pre=0.012, bright=0.0):
    n = n_(seconds)
    t = np.arange(n) / SR
    ir = RNG.standard_normal(n) * np.exp(-6.9 * t / seconds)
    ir = lp(ir, damp)
    if bright:
        ir += bright * hp(RNG.standard_normal(n), 5000) * np.exp(-6.9 * t / (seconds * 0.6))
    ir[: n_(pre)] = 0
    ir /= np.sqrt(np.sum(ir**2))
    wet = sps.fftconvolve(np.concatenate([x, np.zeros(n)]), ir)[: len(x) + n]
    dry = np.concatenate([x, np.zeros(n)])
    return dry * (1 - mix) + wet * mix * 1.4


def echo(x, delay=0.12, fb=0.35, taps=4, damp=5000):
    d = n_(delay)
    out = np.concatenate([x, np.zeros(d * taps)])
    tap = x.copy()
    for i in range(1, taps + 1):
        tap = lp(tap, damp) * fb
        out[d * i : d * i + len(tap)] += tap
    return out


def shimmer(x, seconds=2.0, mix=0.3):
    """Reverb fed with an octave-up copy: glassy halo."""
    up = np.interp(np.arange(0, len(x), 2), np.arange(len(x)), x)
    up = np.concatenate([up, up])[: len(x)]
    halo = reverb(hp(up, 1500), seconds, mix=1.0, damp=9000)
    out = reverb(x, seconds * 0.6, mix=mix)
    m = max(len(out), len(halo))
    return pad(out, m) + pad(halo, m) * mix * 0.6


# ---------------------------------------------------------------- mixing


def pad(x, n):
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n] if len(x) < n else x


def mix(*parts):
    """parts: (start_seconds, signal[, gain])."""
    end = max(n_(p[0]) + len(p[1]) for p in parts)
    out = np.zeros(end)
    for p in parts:
        s, x = n_(p[0]) if p[0] > 0 else 0, p[1]
        g = p[2] if len(p) > 2 else 1.0
        nf = min(n_(0.006), len(x))
        x = x.copy()
        x[-nf:] *= np.linspace(1, 0, nf)  # every part ends at zero: no clicks
        out[s : s + len(x)] += x * g
    return out


def finish(x, peak_db=-1.0, loud_db=-10.0, fade=0.03, loop=False):
    """Bring a sound to the common loudness under a peak ceiling. A one-shot also loses its
    trailing silence and fades out; a loop keeps its exact length (it is seamless already)."""
    if not loop:
        x = hp(x, 25)
        a = np.abs(x)
        last = np.nonzero(a > a.max() * 10 ** (-50 / 20))[0]
        x = x[: (last[-1] + 1) if len(last) else len(x)]
        nf = min(n_(fade), len(x))
        x[-nf:] *= np.linspace(1, 0, nf) ** 2
    # Loudness: the loudest 40 ms, as a phone speaker hears it (deep bass does not count).
    w = n_(0.04)
    xw = hp(x, 200)
    rms = np.sqrt(np.convolve(xw**2, np.ones(w) / w, "same")).max()
    ceil = 10 ** (peak_db / 20)
    # Louder only as far as the soft ceiling bends peaks a little, never squashes them.
    x = x * min(10 ** (loud_db / 20) / max(rms, 1e-9), ceil * 1.1 / np.abs(x).max())
    knee = ceil * 0.7
    over = np.abs(x) > knee
    x = np.where(over, np.sign(x) * (knee + (ceil - knee) * np.tanh((np.abs(x) - knee) / (ceil - knee))), x)
    return x


def make_loop(make, length, xfade=0.05, preroll=0.4, periodic=False):
    """A seamless loop of `length` seconds: the overhang crossfades into the head, after the filters'
    start-up is cut off. A noisy sound crossfades at equal power; a `periodic` one (it repeats
    exactly every `length`, `preroll` being whole periods) linearly, or the seam would bulge."""
    n, nx, npre = n_(length), n_(xfade), n_(preroll)
    x = make(preroll + length + xfade)[npre:]
    y = x[:n].copy()
    if periodic:
        k = np.linspace(0, 1, nx)
        y[:nx] = x[:nx] * k + x[n : n + nx] * (1 - k)
    else:
        k = np.linspace(0, np.pi / 2, nx)
        y[:nx] = x[:nx] * np.sin(k) + x[n : n + nx] * np.cos(k)
    return y


def save(path, x):
    wavfile.write(path, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
