#!/usr/bin/env python3
"""Gera os sons do jogo (Etapa 27) em assets/audio/.

Uso:  python3 tools/audio/build_sfx.py <pasta_com_gravacoes_baixadas>

Dois tipos de som:
 1. SINTETIZADOS por modelo FÍSICO (não existe gravação livre acessível de
    bola de futebol): a bola é um pulso de força com o TEMPO DE CONTATO real
    (pé ~9-16 ms, chão ~5 ms, ferro ~3 ms) passando por um banco de modos de
    vibração da casca e da cavidade de ar de uma bola de raio 11 cm
    (modos da cavidade: ka = 2,08 / 3,34 / 4,49 -> ~1,03 / 1,66 / 2,23 kHz).
    Contato longo (pé) quase não excita o "ping" da cavidade -> "tum";
    contato curto (chão) excita -> "póc". Trave de ferro = modos de flexão de
    um tubo (razões 1 : 2,76 : 5,40). Apito = tom de ~3,2 kHz modulado pela
    bolinha interna (trinado de ~30 Hz).
 2. GRAVAÇÕES reais CC0/CC-BY (OpenGameArt): passos, quedas, vozes de
    crianças, ambiência — recortadas, limpas (passa-altas, fades),
    normalizadas e convertidas para OGG mono (ambiência em estéreo).

Tudo é determinístico (sementes fixas).
"""
import os
import subprocess
import sys

import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "audio")


# --------------------------------------------------------------------------- io
def load(path, sr=SR, mono=True):
    cmd = ["ffmpeg", "-v", "quiet", "-i", path, "-ac", "1" if mono else "2", "-ar", str(sr), "-f", "f32le", "-"]
    r = subprocess.run(cmd, capture_output=True, check=True)
    x = np.frombuffer(r.stdout, dtype=np.float32).astype(np.float64)
    if not mono:
        x = x.reshape(-1, 2)
    return x


def save(name, x, quality=5, stereo=False):
    path = os.path.join(OUT, name + ".ogg")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = np.asarray(x, dtype=np.float32)
    ch = "2" if stereo else "1"
    cmd = ["ffmpeg", "-v", "quiet", "-y", "-f", "f32le", "-ar", str(SR), "-ac", ch, "-i", "-",
           "-c:a", "libvorbis", "-q:a", str(quality), path]
    subprocess.run(cmd, input=x.tobytes(), check=True)
    return path


def norm(x, peak_db=-1.0):
    p = np.max(np.abs(x)) + 1e-12
    return x * (10 ** (peak_db / 20.0) / p)


def fade(x, fin=0.002, fout=0.02):
    x = x.copy()
    a = int(fin * SR)
    b = int(fout * SR)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a) ** 2 if x.ndim == 1 else (np.linspace(0, 1, a) ** 2)[:, None]
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b) ** 2 if x.ndim == 1 else (np.linspace(1, 0, b) ** 2)[:, None]
    return x


def hp(x, fc, order=2):
    sos = signal.butter(order, fc, "highpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def lp(x, fc, order=2):
    sos = signal.butter(order, fc, "lowpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def bp(x, f1, f2, order=2):
    sos = signal.butter(order, [f1, f2], "bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def trim_silence(x, thr_db=-50.0, pre=0.004, post=0.03):
    env = np.abs(x) if x.ndim == 1 else np.max(np.abs(x), axis=1)
    thr = np.max(env) * 10 ** (thr_db / 20.0)
    idx = np.where(env > thr)[0]
    if len(idx) == 0:
        return x
    a = max(idx[0] - int(pre * SR), 0)
    b = min(idx[-1] + int(post * SR), len(x))
    return x[a:b]


# ---------------------------------------------------------------- modal synth
def half_sine(tc, amp=1.0, skew=1.3):
    n = max(int(tc * SR), 3)
    t = np.linspace(0, np.pi, n)
    return amp * np.sin(t) ** skew


def modal_ir(modes, dur, rng, jitter=0.03):
    t = np.arange(int(dur * SR)) / SR
    h = np.zeros_like(t)
    for f, tau, g in modes:
        f = f * (1.0 + rng.uniform(-jitter, jitter))
        tau = tau * (1.0 + rng.uniform(-0.15, 0.15))
        ph = rng.uniform(0, 2 * np.pi)
        h += g * np.exp(-t / tau) * np.sin(2 * np.pi * f * t + ph)
    return h


def strike(force, modes, dur, rng, jitter=0.03):
    """Pulso de força passando pelos modos (convolução) + 'empurrão' de ar
    (derivada da força, a parte grave do impacto)."""
    h = modal_ir(modes, dur, rng, jitter)
    y = signal.fftconvolve(force, h)[: len(h)]
    push = np.zeros_like(y)
    dfo = np.gradient(force)
    push[: len(dfo)] = dfo
    return y, push


def noise_burst(dur, rng, f1, f2, decay):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = rng.standard_normal(n) * np.exp(-t / decay)
    return bp(x, f1, f2, 2)


def place(buf, x, at):
    # toda camada termina em zero (sem clique de corte)
    x = np.asarray(x, dtype=np.float64).copy()
    k = min(len(x) // 4, int(0.01 * SR))
    if k > 1:
        x[-k:] *= np.linspace(1, 0, k)
    i = int(at * SR)
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i]
    return buf


# Bola de rua (raio 11 cm, ~0,9 bar): casca e cavidade de ar.
BALL_SHELL = [(185, 0.030, 1.0), (330, 0.020, 0.75), (520, 0.013, 0.5), (760, 0.010, 0.3)]
BALL_CAVITY = [(1035, 0.060, 0.55), (1660, 0.032, 0.30), (2230, 0.025, 0.22)]


def ball_kick(rng, kind):
    # tempo de contato do pé com a bola (s) e brilho do estalo do calçado
    if kind == "soft":
        tc, slap, boom, dur = rng.uniform(0.013, 0.017), 0.10, 0.0, 0.28
    elif kind == "pass":
        tc, slap, boom, dur = rng.uniform(0.010, 0.012), 0.22, 0.25, 0.34
    else:  # strong
        tc, slap, boom, dur = rng.uniform(0.0085, 0.0095), 0.42, 0.75, 0.42
    force = half_sine(tc, 1.0, rng.uniform(1.1, 1.6))
    modes = BALL_SHELL + [(f, tau, g * 0.6) for f, tau, g in BALL_CAVITY]
    y, push = strike(force, modes, dur, rng)
    y = y / (np.max(np.abs(y)) + 1e-9)
    push = lp(push, 260) / (np.max(np.abs(push)) + 1e-9)
    out = 0.7 * y + 0.55 * push
    # estalo do couro/calçado no contato (curto, médio-agudo)
    s = noise_burst(0.012, rng, 1400, 6000, 0.0025) * slap
    out = place(out, s / (np.max(np.abs(s)) + 1e-9) * slap, 0.0)
    if boom > 0:
        # massa da perna atravessando a bola: "boom" grave no chute forte
        t = np.arange(int(0.12 * SR)) / SR
        b = np.sin(2 * np.pi * rng.uniform(78, 96) * t) * np.exp(-t / 0.035) * boom
        out = place(out, b, 0.001)
    out = hp(out, 45)
    return fade(norm(trim_silence(out, -60)), 0.0008, 0.05)


def ball_bounce(rng, surface="ground"):
    # chão de bloquinhos/asfalto: contato curto -> a cavidade "canta" (póc)
    tc = rng.uniform(0.0045, 0.0065)
    force = half_sine(tc, 1.0, 1.2)
    cav = [(f, tau * 1.1, g * 1.25) for f, tau, g in BALL_CAVITY]
    shell = [(f, tau, g * 0.7) for f, tau, g in BALL_SHELL]
    y, push = strike(force, shell + cav, 0.35, rng)
    y = y / (np.max(np.abs(y)) + 1e-9)
    push = lp(push, 400) / (np.max(np.abs(push)) + 1e-9)
    out = 0.8 * y + 0.35 * push
    grit = noise_burst(0.02, rng, 900, 5000, 0.003)
    out = place(out, grit / (np.max(np.abs(grit)) + 1e-9) * 0.30, 0.0)
    if surface == "curb":
        k = noise_burst(0.02, rng, 2000, 8000, 0.002)
        out = place(out, k / (np.max(np.abs(k)) + 1e-9) * 0.35, 0.0)
    out = hp(out, 60)
    return fade(norm(trim_silence(out, -60)), 0.0005, 0.05)


def ball_wall(rng, material):
    base = ball_bounce(rng, "ground")
    out = np.zeros(int(0.7 * SR))
    out = place(out, base * 0.8, 0.0)
    if material == "brick":
        t = np.arange(int(0.25 * SR)) / SR
        th = sum(np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * np.exp(-t / d) * g
                 for f, d, g in [(118, 0.04, 1.0), (205, 0.03, 0.6), (390, 0.018, 0.3)])
        out = place(out, th * 0.7, 0.0)
        s = noise_burst(0.03, rng, 1500, 7000, 0.004)
        out = place(out, s / (np.max(np.abs(s)) + 1e-9) * 0.35, 0.0)
    elif material == "wood":
        f0 = rng.uniform(280, 340)
        modes = [(f0, 0.05, 1.0), (f0 * 2.3, 0.035, 0.6), (f0 * 3.9, 0.02, 0.35), (f0 * 6.1, 0.012, 0.2)]
        force = half_sine(0.003, 1.0)
        y, _ = strike(force, modes, 0.4, rng, 0.05)
        out = place(out, y / (np.max(np.abs(y)) + 1e-9) * 0.9, 0.0)
        # tábuas soltas batendo (chocalho curto)
        for k in range(rng.integers(3, 6)):
            c = noise_burst(0.01, rng, 600, 3000, 0.0015)
            out = place(out, c / (np.max(np.abs(c)) + 1e-9) * rng.uniform(0.15, 0.35), rng.uniform(0.02, 0.14))
    elif material == "wire":
        # alambrado: muitos arames vibrando (tilintar metálico) + balanço
        for k in range(rng.integers(18, 30)):
            f = rng.uniform(1800, 6500)
            d = rng.uniform(0.02, 0.09)
            t = np.arange(int(d * 4 * SR)) / SR
            p = np.sin(2 * np.pi * f * t) * np.exp(-t / d) * rng.uniform(0.05, 0.2)
            out = place(out, p, rng.uniform(0.0, 0.30) ** 1.6)
        t = np.arange(int(0.5 * SR)) / SR
        sw = rng.standard_normal(len(t)) * np.exp(-t / 0.12)
        out = place(out, lp(sw, 900) * 0.35, 0.0)
    elif material == "iron":
        out = place(out, metal_tube(rng, rng.uniform(420, 520), 0.55) * 0.75, 0.0)
    out = hp(out, 50)
    return fade(norm(trim_silence(out, -55)), 0.0005, 0.08)


def metal_tube(rng, f0, decay):
    # modos de flexão de um tubo livre (razões ~1 : 2,76 : 5,40 : 8,93)
    modes = [(f0, decay, 1.0), (f0 * 2.756, decay * 0.55, 0.7), (f0 * 5.404, decay * 0.3, 0.45),
             (f0 * 8.933, decay * 0.18, 0.25)]
    force = half_sine(0.0025, 1.0)
    y, _ = strike(force, modes, decay * 4.0, rng, 0.01)
    # batimento: o tubo soldado tem dois modos quase iguais (vibrato natural)
    y2, _ = strike(force, [(f * 1.006, d, g * 0.5) for f, d, g in modes], decay * 4.0, rng, 0.0)
    return (y + y2) / (np.max(np.abs(y + y2)) + 1e-9)


def ball_post(rng):
    out = np.zeros(int(2.2 * SR))
    pok = ball_bounce(rng, "ground")
    out = place(out, pok * 0.9, 0.0)
    out = place(out, metal_tube(rng, rng.uniform(560, 700), rng.uniform(0.45, 0.7)) * 0.85, 0.0)
    out = hp(out, 70)
    return fade(norm(trim_silence(out, -60)), 0.0005, 0.25)


def ball_body(rng):
    # bola no peito/costas/coxa: contato longo e amortecido, roupa abafa
    tc = rng.uniform(0.012, 0.016)
    force = half_sine(tc, 1.0, 1.4)
    y, push = strike(force, BALL_SHELL + [(f, tau * 0.6, g * 0.3) for f, tau, g in BALL_CAVITY], 0.25, rng)
    out = 0.5 * y / (np.max(np.abs(y)) + 1e-9) + 0.7 * lp(push, 220) / (np.max(np.abs(push)) + 1e-9)
    c = noise_burst(0.05, rng, 300, 2500, 0.012)
    out = place(out, c / (np.max(np.abs(c)) + 1e-9) * 0.25, 0.0)
    out = lp(hp(out, 50), 3500)
    return fade(norm(trim_silence(out, -60)), 0.001, 0.05)


def ball_head(rng):
    tc = rng.uniform(0.007, 0.009)
    force = half_sine(tc, 1.0, 1.2)
    y, push = strike(force, BALL_SHELL + BALL_CAVITY, 0.3, rng)
    out = 0.75 * y / (np.max(np.abs(y)) + 1e-9) + 0.45 * lp(push, 300) / (np.max(np.abs(push)) + 1e-9)
    k = noise_burst(0.01, rng, 1200, 5000, 0.002)
    out = place(out, k / (np.max(np.abs(k)) + 1e-9) * 0.25, 0.0)
    return fade(norm(trim_silence(hp(out, 60), -60)), 0.0008, 0.05)


def ball_roll_loop(rng, seconds=4.0):
    # rolando nos bloquinhos: ronco grave granulado (cada junta do piso é um
    # micro-impacto) — tocado em loop, volume e tom pela velocidade da bola
    n = int(seconds * SR)
    x = rng.standard_normal(n)
    b, a = [0.049922035, -0.095993537, 0.050612699, -0.004408786], [1, -2.494956002, 2.017265875, -0.522189400]
    pink = signal.lfilter(b, a, x)
    rumble = bp(pink, 70, 420, 2)
    grains = np.zeros(n)
    pos = 0
    while pos < n:
        pos += int(rng.uniform(0.018, 0.05) * SR)
        if pos >= n:
            break
        g = noise_burst(0.015, rng, 250, 1300, 0.004) * rng.uniform(0.2, 1.0)
        place(grains, g, pos / SR)
    y = rumble / (np.std(rumble) + 1e-9) * 0.5 + grains / (np.std(grains) + 1e-9) * 0.08
    y = lp(y, 1800)
    # emenda do loop sem clique (crossfade de 0,3 s)
    cf = int(0.3 * SR)
    w = np.linspace(0, 1, cf)
    y[:cf] = y[:cf] * w + y[-cf:] * (1 - w)
    y = y[:-cf]
    return norm(y, -6.0)


def slide_scrape(rng):
    # carrinho no piso áspero: raspado granulado + pano da roupa
    dur = rng.uniform(0.7, 0.95)
    n = int(dur * SR)
    t = np.arange(n) / SR
    env = np.minimum(t / 0.04, 1.0) * np.exp(-t / (dur * 0.45))
    x = rng.standard_normal(n)
    mod = 1.0 + 0.6 * lp(rng.standard_normal(n), 30) / 0.2
    scr = bp(x, 450, 4200, 2) * env * np.clip(mod, 0.2, 2.0)
    cloth = lp(rng.standard_normal(n), 1200) * env * 0.4
    grains = np.zeros(n)
    for k in range(int(dur * 70)):
        g = noise_burst(0.006, rng, 1500, 7000, 0.0012) * rng.uniform(0.1, 0.6)
        place(grains, g, rng.uniform(0, dur * 0.8))
    y = scr / (np.std(scr) + 1e-9) * 0.4 + cloth / (np.std(cloth) + 1e-9) * 0.15 + grains * 0.8
    return fade(norm(hp(y, 120)), 0.005, 0.15)


def referee_whistle(rng, dur):
    # apito com bolinha: tom ~3,2 kHz, trinado (AM+FM) de ~28 Hz, sopro
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = rng.uniform(3050, 3350)
    trill_f = rng.uniform(24, 32)
    ph_jit = np.cumsum(rng.standard_normal(n)) / SR * 6.0
    trill = 0.5 + 0.5 * np.sin(2 * np.pi * trill_f * t + ph_jit)
    fm = f0 * (1.0 + 0.035 * (trill - 0.5) + 0.004 * lp(rng.standard_normal(n), 8))
    phase = 2 * np.pi * np.cumsum(fm) / SR
    tone = np.sin(phase) + 0.18 * np.sin(2 * phase + 0.4) + 0.05 * np.sin(3 * phase + 1.1)
    am = 0.55 + 0.45 * trill
    breath = bp(rng.standard_normal(n), f0 * 0.8, f0 * 1.25, 2) * 0.12
    env = np.minimum(t / 0.025, 1.0) * np.minimum((dur - t) / 0.06, 1.0)
    env = np.clip(env, 0, 1)
    y = (tone * am + breath / (np.std(breath) + 1e-9) * 0.08) * env
    return fade(norm(hp(y, 600), -2.0), 0.002, 0.03)


def whistle_sequence(rng, pattern):
    parts = []
    for i, d in enumerate(pattern):
        parts.append(referee_whistle(rng, d))
        if i < len(pattern) - 1:
            parts.append(np.zeros(int(0.14 * SR)))
    return np.concatenate(parts)


# ------------------------------------------------------------- recordings
def segments(x, thr_db=-30.0, min_gap=0.12, min_len=0.05, max_len=3.0):
    env = np.convolve(np.abs(x), np.ones(441) / 441, "same")
    thr = np.max(env) * 10 ** (thr_db / 20.0)
    on = env > thr
    out = []
    i = 0
    n = len(x)
    while i < n:
        if on[i]:
            j = i
            last = i
            while j < n and (on[j] or j - last < int(min_gap * SR)):
                if on[j]:
                    last = j
                j += 1
            a, b = i, last
            if (b - a) / SR >= min_len and (b - a) / SR <= max_len:
                out.append((max(a - int(0.01 * SR), 0), min(b + int(0.06 * SR), n)))
            i = j
        else:
            i += 1
    return out


def step_clean(x, pitch=1.0, tail=0.22, weight=0.0, rng=None, soft=0.0):
    x = trim_silence(x, -42, 0.003, 0.02)
    x = x[: int(tail * SR)]
    if pitch != 1.0:
        idx = np.arange(0, len(x) - 1, pitch)
        x = np.interp(idx, np.arange(len(x)), x)
    x = hp(x, 110, 2)
    if soft > 0.0:
        # tênis (sola de borracha): menos estalo agudo que a sola dura da gravação
        x = (1.0 - soft) * x + soft * lp(x, 3800)
    x = norm(x, -1.0)
    if weight > 0.0 and rng is not None:
        # PESO do corpo pousando no pé: "tum" grave curto (calcanhar/antepé)
        t = np.arange(int(0.09 * SR)) / SR
        f = rng.uniform(95, 130)
        th = np.sin(2 * np.pi * f * t * (1.0 - 0.25 * t / 0.09)) * np.exp(-t / 0.022)
        th = lp(th, 400)
        y = np.zeros(max(len(x), len(th)))
        y[: len(x)] += x
        y[: len(th)] += th / (np.max(np.abs(th)) + 1e-9) * weight
        x = y
    return fade(norm(x, -1.0), 0.001, 0.04)


def build_recordings(src):
    made = []
    j = os.path.join
    # PASSOS (Fantozzi, CC0: pedra; metrô, CC0: concreto)
    fz = []
    for dp, _dn, fn in os.walk(j(src, "x_Fantozzi-footsteps")):
        fz += [j(dp, f) for f in fn if f.endswith(".ogg")]
    fz.sort()
    stone = [p for p in fz if "Stone" in os.path.basename(p)]
    sand = [p for p in fz if "Sand" in os.path.basename(p)]
    # metrô: só as gravações limpas (02 e 06 são dominadas por chiado)
    subway = [j(src, "%02d-footstep%s.ogg" % (k, "_0" if k == 1 else "")) for k in (1, 3, 4, 5)]
    subway += [j(src, "x_sfx_100_v2", "sfx100v2_footstep_0%d.ogg" % k) for k in (1, 2)]
    k = 0
    srng = np.random.default_rng(77)
    for p in stone:
        x = load(p)
        k += 1
        made.append(save("steps/run_%02d" % k, step_clean(x, 1.04, 0.16, 0.75, srng, 0.55)))
        made.append(save("steps/walk_%02d" % k, step_clean(x, 1.0, 0.25, 0.45, srng, 0.45)))
    for i, p in enumerate(subway):
        x = load(p)
        made.append(save("steps/walk_%02d" % (k + i + 1), step_clean(x, 1.0, 0.25)))
    for i, p in enumerate(sand):
        x = load(p)
        made.append(save("steps/scuff_%02d" % (i + 1), step_clean(x, 0.92, 0.3)))
    # QUEDAS / CORPO (body_hits: CC-BY 3.0; jumpland: CC0)
    x = load(j(src, "body_hits.wav"))
    segs = segments(x, -26, 0.15, 0.05, 1.2)
    for i, (a, b) in enumerate(segs[:6]):
        y = fade(norm(hp(x[a:b], 50), -1.0), 0.001, 0.06)
        made.append(save("body/fall_%02d" % (i + 1), y))
    y = trim_silence(load(j(src, "jumpland.wav")), -45)
    made.append(save("body/land_01", fade(norm(hp(y, 50)), 0.001, 0.05)))
    # VOZES DE CRIANÇAS (CC0)
    x = load(j(src, "children.wav"))
    for i, (a, b) in enumerate(segments(x, -24, 0.18, 0.25, 3.5)[:8]):
        made.append(save("voices/kid_%02d" % (i + 1), fade(norm(hp(x[a:b], 120), -1.5), 0.01, 0.12)))
    x = load(j(src, "group_giggling.ogg"))
    segs = segments(x, -18, 0.08, 0.25, 6.0)
    if len(segs) < 2:
        n = len(x)
        segs = [(int(n * k / 3), int(n * (k + 1) / 3)) for k in range(3)]
    for i, (a, b) in enumerate(segs[:6]):
        made.append(save("voices/giggle_%02d" % (i + 1), fade(norm(hp(x[a:b], 120), -1.5), 0.02, 0.15)))
    # torcida de crianças/vizinhos no gol (CC0: gritos mixados)
    x = load(j(src, "crowd_shouting_0.ogg"))
    env = np.convolve(np.abs(x), np.ones(SR // 4) / (SR // 4), "same")
    c = int(np.argmax(env))
    a = max(c - int(1.5 * SR), 0)
    y = x[a: a + int(4.5 * SR)]
    made.append(save("voices/cheer_01", fade(norm(hp(y, 150), -2.0), 0.08, 1.2)))
    a2 = max(int(len(x) * 0.25), 0)
    made.append(save("voices/cheer_02", fade(norm(hp(x[a2: a2 + int(3.5 * SR)], 150), -2.0), 0.08, 1.0)))
    # AMBIÊNCIA (CC0): rua residencial de dia — pássaros, cidade ao longe
    morning = load(j(src, "amb_morning_0.ogg"), mono=False)
    outdoor = load(j(src, "amb_outdoor1_loop.ogg"), mono=False)
    birds = load(j(src, "park_ambience_birds.wav"), mono=False)
    traffic = load(j(src, "gatve Varniu_2.ogg"), mono=False)
    L = int(48 * SR)

    def take(x, start_frac):
        s = int(len(x) * start_frac)
        y = x[s: s + L]
        while len(y) < L:
            y = np.concatenate([y, x[: L - len(y)]])
        return y

    def rms(x):
        return np.sqrt(np.mean(x ** 2)) + 1e-9

    m = take(morning, 0.2)
    o = take(outdoor, 0.0)
    bi = take(birds, 0.3)
    tr = lp(take(traffic, 0.1), 1400)
    mix = (m / rms(m)) * 0.10 + (o / rms(o)) * 0.06 + (hp(bi, 300) / rms(bi)) * 0.05 + (tr / rms(tr)) * 0.025
    mix = hp(mix, 60)
    cf = int(2.0 * SR)
    w = np.linspace(0, 1, cf)[:, None]
    mix[:cf] = mix[:cf] * w + mix[-cf:] * (1 - w)
    mix = mix[:-cf]
    made.append(save("ambience/street_day", norm(mix, -3.0), 4, stereo=True))
    return made


def build_synth():
    made = []
    rng = np.random.default_rng(2027)
    for kind, n in [("soft", 8), ("pass", 8), ("strong", 6)]:
        for i in range(n):
            made.append(save("ball/kick_%s_%02d" % (kind, i + 1), ball_kick(rng, kind)))
    for i in range(8):
        made.append(save("ball/bounce_%02d" % (i + 1), ball_bounce(rng)))
    for i in range(4):
        made.append(save("ball/curb_%02d" % (i + 1), ball_bounce(rng, "curb")))
    for mat, n in [("brick", 4), ("wood", 4), ("wire", 4), ("iron", 3)]:
        for i in range(n):
            made.append(save("ball/%s_%02d" % (mat, i + 1), ball_wall(rng, mat)))
    for i in range(4):
        made.append(save("ball/post_%02d" % (i + 1), ball_post(rng)))
    for i in range(5):
        made.append(save("ball/body_%02d" % (i + 1), ball_body(rng)))
    for i in range(4):
        made.append(save("ball/head_%02d" % (i + 1), ball_head(rng)))
    made.append(save("ball/roll_loop", ball_roll_loop(rng)))
    for i in range(3):
        made.append(save("body/slide_%02d" % (i + 1), slide_scrape(rng)))
    made.append(save("whistle/short", whistle_sequence(rng, [0.32])))
    made.append(save("whistle/long", whistle_sequence(rng, [0.95])))
    made.append(save("whistle/double", whistle_sequence(rng, [0.22, 0.55])))
    made.append(save("whistle/final", whistle_sequence(rng, [0.35, 0.35, 1.2])))
    return made


if __name__ == "__main__":
    made = build_synth()
    if len(sys.argv) > 1:
        made += build_recordings(sys.argv[1])
    print("gerados:", len(made))
