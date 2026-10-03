#!/usr/bin/env python3
"""Звуки и музыка LAST TRAIN (WAV 16 бит, моно, 22050 Гц), синтез без зависимостей.

Запуск:  python3 tools/gen_audio.py
Петли (train_loop, rain_loop, music_*) бесшовные: длина кратна такту, хвосты заворачиваются.
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
RATE = 22050
rnd = random.Random(12)
TAU = math.tau


def save(name, s, gain=0.85, normalize=True):
    peak = max(1e-6, max(abs(v) for v in s)) if normalize else 1.0
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v / peak * gain)) * 32767)) for v in s)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print("  ", f"assets/audio/{name}.wav", f"{len(s) / RATE:.2f}s")


def buf(sec):
    return [0.0] * int(sec * RATE)


def note_freq(n):
    """n — номер ноты MIDI."""
    return 440.0 * 2 ** ((n - 69) / 12)


def env_adsr(i, n, a=0.01, d=0.1, s=0.6, r=0.2):
    t = i / RATE
    length = n / RATE
    if t < a:
        return t / a
    if t < a + d:
        return 1 - (1 - s) * (t - a) / d
    if t > length - r:
        return s * max(0.0, (length - t) / r)
    return s


def add_tone(b, start, dur, freq, vol=0.3, wave_="sine", a=0.01, d=0.1, s=0.6, r=0.2, vib=0.0, wrap=False):
    n = int(dur * RATE)
    st = int(start * RATE)
    ph = 0.0
    for i in range(n):
        f = freq * (1 + vib * math.sin(TAU * 5 * i / RATE))
        ph += TAU * f / RATE
        if wave_ == "sine":
            v = math.sin(ph)
        elif wave_ == "tri":
            v = 2 / math.pi * math.asin(math.sin(ph))
        elif wave_ == "square":
            v = 0.6 if math.sin(ph) > 0 else -0.6
        elif wave_ == "bell":
            v = math.sin(ph) + 0.4 * math.sin(ph * 2.76) * math.exp(-i / RATE * 6) + 0.2 * math.sin(ph * 5.4) * math.exp(-i / RATE * 10)
        elif wave_ == "pluck":
            v = math.sin(ph) * 0.7 + 0.3 * math.sin(ph * 2) * math.exp(-i / RATE * 8)
        else:
            v = math.sin(ph)
        idx = st + i
        if wrap:
            idx %= len(b)
        elif idx >= len(b):
            break
        b[idx] += v * vol * env_adsr(i, n, a, d, s, r)


def add_noise(b, start, dur, vol=0.3, lp=0.3, decay=8.0, wrap=False):
    n = int(dur * RATE)
    st = int(start * RATE)
    y = 0.0
    for i in range(n):
        y += (rnd.uniform(-1, 1) - y) * lp
        idx = st + i
        if wrap:
            idx %= len(b)
        elif idx >= len(b):
            break
        b[idx] += y * vol * math.exp(-i / RATE * decay)


def lowpass(s, k):
    y = 0.0
    out = []
    for v in s:
        y += (v - y) * k
        out.append(y)
    return out


def reverb(s, wrap=False, mix_=0.3):
    out = list(s)
    for delay, g in ((0.031, 0.5), (0.047, 0.4), (0.073, 0.35), (0.11, 0.25), (0.17, 0.18)):
        dn = int(delay * RATE)
        for i in range(len(s)):
            j = i + dn
            if j >= len(s):
                if not wrap:
                    break
                j %= len(s)
            out[j] += s[i] * g * mix_
    return out


# --- эффекты -----------------------------------------------------------------------------
def sfx():
    b = buf(0.08)
    add_tone(b, 0, 0.06, 1200, 0.5, "sine", a=0.002, d=0.03, s=0.2, r=0.03)
    add_tone(b, 0, 0.04, 2400, 0.2, "sine", a=0.001, d=0.02, s=0.1, r=0.02)
    save("click", b, 0.5)

    b = buf(0.25)
    for i in range(len(b)):
        t = i / RATE
        b[i] = rnd.uniform(-1, 1) * math.sin(math.pi * t / 0.25) * 0.4
    b = lowpass(b, 0.08)
    add_tone(b, 0.02, 0.2, 660, 0.15, "sine", a=0.05, d=0.05, s=0.5, r=0.1)
    save("panel_open", b, 0.45)

    b = buf(0.2)
    for i in range(len(b)):
        t = i / RATE
        b[i] = rnd.uniform(-1, 1) * math.sin(math.pi * t / 0.2) * 0.4
    save("panel_close", lowpass(b, 0.05), 0.35)

    for k in range(2):
        b = buf(0.09)
        add_noise(b, 0, 0.08, 0.6, 0.12 + k * 0.05, 40)
        add_tone(b, 0, 0.06, 90 + k * 20, 0.5, "sine", a=0.002, d=0.03, s=0.2, r=0.03)
        save(f"step_{k}", b, 0.35)

    b = buf(0.5)
    for i in range(len(b)):
        t = i / RATE
        b[i] = rnd.uniform(-1, 1) * (0.5 - abs(t - 0.22)) * 0.8
    b = lowpass(b, 0.06)
    add_tone(b, 0.4, 0.08, 180, 0.4, "sine", a=0.002, d=0.03, s=0.3, r=0.04)
    save("door_open", b, 0.5)

    b = buf(0.25)
    add_tone(b, 0, 0.12, 110, 0.6, "square", a=0.002, d=0.05, s=0.3, r=0.06)
    add_noise(b, 0, 0.1, 0.5, 0.2, 30)
    add_tone(b, 0.1, 0.12, 95, 0.5, "square", a=0.002, d=0.05, s=0.3, r=0.06)
    save("door_locked", lowpass(b, 0.3), 0.5)

    # находка улики: волшебная арпеджио вверх
    b = buf(1.0)
    for i, n in enumerate((76, 79, 83, 88)):
        add_tone(b, i * 0.07, 0.6, note_freq(n), 0.3, "bell", a=0.003, d=0.2, s=0.3, r=0.3)
    save("clue", reverb(b), 0.6)

    b = buf(0.7)
    for i in range(12):
        add_tone(b, i * 0.03, 0.25, note_freq(84 + (i * 5) % 12), 0.08, "sine", a=0.005, d=0.05, s=0.4, r=0.15)
    save("magnifier", reverb(b), 0.45)

    b = buf(0.3)
    for i in range(len(b)):
        t = i / RATE
        b[i] = rnd.uniform(-1, 1) * math.exp(-((t - 0.08) / 0.05) ** 2) * 0.8
    save("page", lowpass(b, 0.25), 0.45)

    b = buf(0.5)
    for k in range(5):
        add_noise(b, k * 0.09, 0.06, 0.5, 0.6, 20)
    save("note", lowpass(b, 0.4), 0.3)

    b = buf(0.2)
    add_tone(b, 0, 0.08, 1760, 0.4, "square", a=0.002, d=0.02, s=0.4, r=0.02)
    add_tone(b, 0.1, 0.08, 1760, 0.4, "square", a=0.002, d=0.02, s=0.4, r=0.02)
    save("camera_beep", lowpass(b, 0.4), 0.35)

    b = buf(0.25)
    add_noise(b, 0, 0.03, 0.9, 0.7, 60)
    add_noise(b, 0.06, 0.04, 0.7, 0.5, 50)
    save("shutter", b, 0.5)

    b = buf(0.8)
    for i, n in enumerate((84, 88)):
        add_tone(b, i * 0.12, 0.5, note_freq(n), 0.35, "bell", a=0.002, d=0.15, s=0.3, r=0.25)
    save("contradiction", reverb(b), 0.6)

    b = buf(0.8)
    add_tone(b, 0, 0.35, 220, 0.4, "tri", a=0.01, d=0.1, s=0.6, r=0.1)
    add_tone(b, 0.3, 0.45, 165, 0.4, "tri", a=0.01, d=0.1, s=0.6, r=0.2)
    save("wrong", lowpass(b, 0.3), 0.5)

    b = buf(2.2)
    seq = [(72, 0.0, 0.18), (76, 0.15, 0.18), (79, 0.3, 0.18), (84, 0.45, 0.9), (79, 0.45, 0.9), (76, 0.45, 0.9)]
    for n, t, d in seq:
        add_tone(b, t, d + 0.4, note_freq(n), 0.25, "pluck", a=0.005, d=0.2, s=0.5, r=0.3)
    for n, t in ((88, 1.0), (91, 1.1), (96, 1.2)):
        add_tone(b, t, 0.8, note_freq(n), 0.12, "bell", a=0.003, d=0.2, s=0.2, r=0.4)
    save("success", reverb(b), 0.6)

    b = buf(2.0)
    for i in range(len(b)):
        t = i / RATE
        b[i] = rnd.uniform(-1, 1) * min(1, t / 0.6) * max(0, 1 - (t - 0.6) / 0.3 if t > 0.6 else 1) * 0.5
    b = lowpass(b, 0.1)
    for n in (50, 57, 62, 65):
        add_tone(b, 0.8, 1.1, note_freq(n), 0.18, "tri", a=0.01, d=0.3, s=0.5, r=0.5, vib=0.004)
    add_tone(b, 0.8, 1.0, note_freq(86), 0.15, "bell", a=0.002, d=0.3, s=0.2, r=0.5)
    save("reveal", reverb(b), 0.7)

    b = buf(1.0)
    add_noise(b, 0, 0.12, 0.9, 0.25, 25)
    add_tone(b, 0, 0.15, 70, 0.8, "sine", a=0.002, d=0.08, s=0.3, r=0.05)
    for i, n in enumerate((79, 84)):
        add_tone(b, 0.2 + i * 0.1, 0.6, note_freq(n), 0.25, "bell", a=0.003, d=0.2, s=0.3, r=0.3)
    save("arrest", reverb(b), 0.6)

    b = buf(0.5)
    add_tone(b, 0, 0.1, note_freq(88), 0.4, "bell", a=0.002, d=0.05, s=0.3, r=0.05)
    add_tone(b, 0.07, 0.35, note_freq(95), 0.4, "bell", a=0.002, d=0.1, s=0.3, r=0.2)
    save("coin", b, 0.5)

    # объявление: «динь-дон-динь»
    b = buf(2.0)
    for i, n in enumerate((76, 72, 79)):
        add_tone(b, i * 0.42, 1.0, note_freq(n), 0.35, "bell", a=0.003, d=0.3, s=0.35, r=0.5)
    save("announce", reverb(b, mix_=0.5), 0.55)

    b = buf(2.5)
    for i in range(len(b)):
        t = i / RATE
        b[i] = rnd.uniform(-1, 1) * math.sin(math.pi * t / 2.5) * 0.7
    save("tunnel", lowpass(b, 0.03), 0.6)

    b = buf(1.0)
    for i, n in enumerate((72, 76, 79, 84)):
        add_tone(b, i * 0.08, 0.5, note_freq(n), 0.25, "pluck", a=0.003, d=0.15, s=0.4, r=0.2)
    save("quest", reverb(b), 0.5)

    b = buf(0.4)
    add_tone(b, 0, 0.35, 330, 0.3, "sine", a=0.01, d=0.1, s=0.5, r=0.15, vib=0.03)
    add_tone(b, 0.05, 0.3, 392, 0.2, "sine", a=0.01, d=0.1, s=0.5, r=0.15, vib=0.03)
    save("talk", b, 0.35)

    b = buf(0.6)
    add_tone(b, 0, 0.5, 520, 0.35, "sine", a=0.005, d=0.1, s=0.5, r=0.2)
    add_tone(b, 0, 0.5, 780, 0.15, "sine", a=0.005, d=0.1, s=0.5, r=0.2)
    save("pop", b, 0.4)


# --- петли -------------------------------------------------------------------------------
def train_loop():
    sec = 4.0
    b = buf(sec)
    # низкий гул
    y = 0.0
    for i in range(len(b)):
        y += (rnd.uniform(-1, 1) - y) * 0.02
        b[i] = y * 1.4 + 0.25 * math.sin(TAU * 42 * i / RATE) * (0.8 + 0.2 * math.sin(TAU * i / len(b)))
    # перестук: «та-дам … та-дам»
    for t in (0.0, 0.16, 2.0, 2.16):
        add_noise(b, t, 0.12, 1.1, 0.35, 28, wrap=True)
        add_tone(b, t, 0.1, 75, 0.6, "sine", a=0.002, d=0.05, s=0.2, r=0.04, wrap=True)
    for t in (1.0, 1.16, 3.0, 3.16):
        add_noise(b, t, 0.1, 0.6, 0.3, 30, wrap=True)
    save("train_loop", b, 0.6)


def rain_loop():
    sec = 4.0
    b = buf(sec)
    y = 0.0
    for i in range(len(b)):
        y += (rnd.uniform(-1, 1) - y) * 0.35
        b[i] = y * 0.5
    for _ in range(120):
        t = rnd.uniform(0, sec)
        add_noise(b, t, 0.03, rnd.uniform(0.3, 0.8), 0.7, 80, wrap=True)
    save("rain_loop", lowpass(b, 0.5), 0.45)


def music(name, bpm, chords, melody, beats_per_bar=4, bass_wave="tri", lead="pluck", pad_vol=0.06,
          tick=False, arp=True):
    beat = 60.0 / bpm
    bars = len(chords)
    sec = bars * beats_per_bar * beat
    b = buf(sec)
    for bi, ch in enumerate(chords):
        t0 = bi * beats_per_bar * beat
        # пэд
        for n in ch:
            add_tone(b, t0, beats_per_bar * beat + 0.3, note_freq(n + 12), pad_vol, "sine", a=0.4, d=0.3, s=0.8, r=0.5, vib=0.002, wrap=True)
        # бас
        add_tone(b, t0, beat * 1.8, note_freq(ch[0] - 12), 0.22, bass_wave, a=0.01, d=0.2, s=0.6, r=0.2, wrap=True)
        add_tone(b, t0 + beat * 2, beat * 1.8, note_freq(ch[0] - 12 + (7 if beats_per_bar == 4 else 0)), 0.16, bass_wave, a=0.01, d=0.2, s=0.6, r=0.2, wrap=True)
        # арпеджио
        if arp:
            steps = beats_per_bar * 2
            for s in range(steps):
                n = ch[s % len(ch)] + (12 if (s // len(ch)) % 2 else 0) + 12
                add_tone(b, t0 + s * beat / 2, beat * 0.6, note_freq(n), 0.07, "bell", a=0.003, d=0.1, s=0.3, r=0.15, wrap=True)
        if tick:
            for s in range(beats_per_bar * 2):
                add_noise(b, t0 + s * beat / 2, 0.03, 0.12 if s % 2 else 0.2, 0.9, 90, wrap=True)
    for (n, start_beat, length_beats) in melody:
        add_tone(b, start_beat * beat, length_beats * beat + 0.2, note_freq(n), 0.16, lead, a=0.01, d=0.15, s=0.5, r=0.25, vib=0.003, wrap=True)
    b = reverb(b, wrap=True, mix_=0.35)
    save(name, b, 0.55)


def musics():
    # Исследование: загадочно-уютно, ля минор
    Am, F, C, E = [57, 60, 64], [53, 57, 60], [48, 52, 55], [52, 56, 59]
    Dm, G = [50, 53, 57], [55, 59, 62]
    music("music_explore", 84, [Am, F, C, E, Am, Dm, F, E],
          [(76, 0, 2), (72, 2, 1), (74, 3, 1), (72, 4, 2), (69, 6, 2), (67, 8, 3), (64, 11, 1),
           (68, 12, 4), (76, 16, 2), (77, 18, 1), (76, 19, 1), (74, 20, 2), (72, 22, 2), (72, 24, 2),
           (69, 26, 2), (71, 28, 4)])
    # Напряжение: ре минор, тикающий ритм
    Bb, Gm, A = [46, 50, 53], [43, 46, 50], [45, 49, 52]
    music("music_tension", 104, [Dm, Bb, Gm, A, Dm, Bb, Gm, A],
          [(74, 0, 1), (77, 1, 1), (76, 2, 2), (74, 4, 1), (70, 5, 1), (69, 6, 2), (70, 8, 2), (67, 10, 2),
           (69, 12, 3), (73, 15, 1), (74, 16, 2), (77, 18, 2), (81, 20, 2), (79, 22, 2), (76, 28, 4)],
          tick=True, pad_vol=0.05)
    # Меню: музыкальная шкатулка, вальс
    Fm = [53, 57, 60]
    music("music_menu", 96, [C, Am, Fm, G, C, Am, Dm, G], [
        (76, 0, 2), (79, 2, 1), (81, 3, 3), (79, 6, 3), (77, 9, 2), (76, 11, 1), (74, 12, 3), (72, 15, 3),
        (76, 18, 2), (79, 20, 1), (84, 21, 3), (83, 24, 2), (81, 26, 1), (79, 27, 3)],
        beats_per_bar=3, lead="bell", pad_vol=0.05)


def murder_sfx():
    """Звуки события в туннеле: гул туннеля (петля), мерцание ламп, крик, суматоха, тревожный аккорд."""
    # гул туннеля: низкий рокот + усиленный перестук (петля 4 с)
    sec = 4.0
    b = buf(sec)
    y = 0.0
    for i in range(len(b)):
        y += (rnd.uniform(-1, 1) - y) * 0.05
        b[i] = y * 1.6 + 0.35 * math.sin(TAU * 38 * i / RATE)
    for t in (0.0, 0.14, 1.0, 1.14, 2.0, 2.14, 3.0, 3.14):
        add_noise(b, t, 0.14, 1.3, 0.4, 22, wrap=True)
    save("tunnel_ambience", lowpass(b, 0.25), 0.7)

    # мерцание ламп: электрический треск и щелчки
    b = buf(1.5)
    for k in range(9):
        t = k * 0.16 + rnd.uniform(0, 0.05)
        add_noise(b, t, 0.05, 0.8, 0.9, 80)
        add_tone(b, t, 0.08, 120, 0.3, "square", a=0.002, d=0.03, s=0.4, r=0.03)
    save("lights_flicker", b, 0.45)

    # испуганный женский крик: высокий тон с подъёмом, вибрато, формантами и дыханием
    dur = 1.25
    n = int(dur * RATE)
    b = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / RATE
        k = t / dur
        f0 = 760 + 520 * math.sin(min(1.0, k * 2.2) * math.pi / 2) - 260 * max(0.0, k - 0.55)
        f0 *= 1 + 0.035 * math.sin(TAU * 7.5 * t) + 0.01 * rnd.uniform(-1, 1)
        ph += TAU * f0 / RATE
        v = math.sin(ph) + 0.55 * math.sin(2 * ph) + 0.35 * math.sin(3 * ph) + 0.18 * math.sin(4 * ph + 0.3)
        v *= 1 + 0.12 * math.sin(TAU * 31 * t)
        env = min(1.0, t / 0.05) * (1.0 - k) ** 0.6
        b[i] = v * env * 0.5 + rnd.uniform(-1, 1) * 0.08 * env
    b = lowpass(b, 0.55)
    save("female_scream", reverb(b, mix_=0.25), 0.75)

    # суматоха пассажиров: несколько «голосов»-бормотаний и шаги
    b = buf(2.4)
    for v in range(6):
        start = rnd.uniform(0, 1.4)
        base = rnd.uniform(140, 320)
        for s in range(rnd.randint(3, 6)):
            add_tone(b, start + s * 0.13, 0.12, base * rnd.uniform(0.9, 1.25), 0.18, "tri", a=0.01, d=0.04, s=0.6, r=0.04, vib=0.05)
    for s in range(8):
        add_noise(b, rnd.uniform(0, 2.2), 0.07, 0.4, 0.15, 40)
    save("passenger_panic", lowpass(reverb(b, mix_=0.3), 0.4), 0.5)

    # тревожный аккорд при обнаружении места преступления
    b = buf(2.2)
    for n_ in (38, 45, 50, 53, 56):
        add_tone(b, 0, 2.0, note_freq(n_), 0.16, "tri", a=0.01, d=0.4, s=0.5, r=0.9, vib=0.003)
    add_tone(b, 0, 1.4, note_freq(86), 0.12, "bell", a=0.002, d=0.3, s=0.2, r=0.6)
    add_noise(b, 0, 0.3, 0.6, 0.1, 10)
    save("discovery_stinger", reverb(b, mix_=0.4), 0.65)


def main():
    murder_sfx()
    sfx()
    train_loop()
    rain_loop()
    musics()


if __name__ == "__main__":
    main()
