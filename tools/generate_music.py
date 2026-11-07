#!/usr/bin/env python3
"""Compose et enregistre la musique gothique du jeu dans assets/music/ (OGG Vorbis).

Usage (depuis la racine du projet) :
    python3 tools/generate_music.py            # tous les morceaux
    python3 tools/generate_music.py combat     # un seul morceau

Il faut Python 3, numpy et ffmpeg (pour l'encodage en .ogg).

Les morceaux (tous en ré mineur, la tonalité « sombre » par excellence) :
  - menu    « Le Trône des Profondeurs » : orgue, glas, chœur, violoncelles (boucle).
  - calme   « Les Galeries » : clavecin, cordes graves, chœur lointain, gouttes (boucle).
  - combat  « L'Assaut » : timbales, tambours de guerre, cordes piquées, orgue, chœur (boucle).
  - victoire : roulement, orgue et chœur qui finissent en ré MAJEUR, carillon.
  - defaite  : glas funèbre et chœur qui descend.

Comment c'est écrit : chaque morceau est une partition en Python. On pose des
notes (un instrument, une hauteur, un temps de départ en « temps » musicaux et
une durée) sur une piste, puis on ajoute la réverbération d'une cathédrale.
Pour qu'une boucle ne s'entende pas, la queue d'écho de la fin est recopiée
sur le début : le morceau s'enchaîne sur lui-même sans couture.
Change les notes et relance le script pour modifier la musique !
"""

import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gothic_synth as gs  # noqa: E402
from gothic_synth import note as N  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "music")
SR = 32000

# Les accords utilisés (notes de l'orgue, du grave à l'aigu).
CHORDS = {
    "Dm": ["D3", "A3", "D4", "F4", "A4"],
    "Bb": ["Bb2", "F3", "Bb3", "D4", "F4"],
    "Gm": ["G2", "D3", "G3", "Bb3", "D4"],
    "A": ["A2", "E3", "A3", "C#4", "E4"],
    "Asus": ["A2", "E3", "A3", "D4", "E4"],
    "F": ["F2", "C3", "F3", "A3", "C4"],
    "C": ["C3", "G3", "C4", "E4", "G4"],
    "Eb": ["Eb3", "Bb3", "Eb4", "G4", "Bb4"],
    "D": ["D3", "A3", "D4", "F#4", "A4"],
}
ROOTS = {"Dm": "D", "Bb": "Bb", "Gm": "G", "A": "A", "Asus": "A", "F": "F", "C": "C", "Eb": "Eb", "D": "D"}


class Track:
    """Une piste stéréo. Les positions et durées sont en temps (beats)."""

    def __init__(self, bpm, beats, seed, tail=7.0):
        self.beat = 60.0 / bpm
        self.length = beats * self.beat
        self.rng = np.random.default_rng(seed)
        n = gs.samples(self.length + tail, SR)
        self.dry = np.zeros((2, n))
        self.send = np.zeros((2, n))

    def sec(self, beats):
        return beats * self.beat

    def add(self, mono, at_beat, pan=0.0, gain=1.0, send=0.4):
        """Pose un son. send = part du son envoyée dans la réverbération."""
        start = gs.samples(self.sec(at_beat), SR) if at_beat > 0 else 0
        stereo = gs.pan(mono * gain, pan)
        end = min(start + stereo.shape[1], self.dry.shape[1])
        self.dry[:, start:end] += stereo[:, :end - start]
        self.send[:, start:end] += stereo[:, :end - start] * send

    # Raccourcis pour chaque instrument.
    def organ(self, names, at, dur, stops="plein", gain=0.5, send=0.55, spread=0.6):
        for i, name in enumerate(names):
            p = (i / max(len(names) - 1, 1) - 0.5) * spread
            self.add(gs.organ(N(name), self.sec(dur), SR, self.rng, stops), at, p, gain / len(names) ** 0.5, send)

    def choir(self, names, at, dur, vowel="a", gain=0.5, send=0.6, spread=0.8, attack=0.35):
        for i, name in enumerate(names):
            p = (i / max(len(names) - 1, 1) - 0.5) * spread
            sound = gs.choir(N(name), self.sec(dur), SR, self.rng, vowel, attack=attack)
            self.add(sound, at, p, gain / len(names) ** 0.5, send)

    def strings(self, name, at, dur, gain=0.5, pan=-0.2, send=0.4, staccato=False, **kw):
        self.add(gs.strings(N(name), self.sec(dur), SR, self.rng, staccato=staccato, **kw), at, pan, gain, send)

    def harpsichord(self, name, at, dur, gain=0.35, pan=0.3, send=0.35):
        self.add(gs.harpsichord(N(name), self.sec(dur), SR, self.rng), at, pan, gain, send)

    def bell(self, name, at, seconds=6.0, gain=0.5, pan=0.0, send=0.6, brightness=1.0):
        self.add(gs.bell(N(name), seconds, SR, self.rng, brightness), at, pan, gain, send)

    def timpani(self, name, at, gain=0.6, force=1.0, pan=0.1, send=0.35):
        self.add(gs.timpani(N(name), 2.2, SR, self.rng, force), at, pan, gain, send)

    def drum(self, at, gain=0.6, pitch=1.0, force=1.0, pan=-0.1, send=0.3):
        self.add(gs.war_drum(SR, self.rng, pitch, force), at, pan, gain, send)

    def render(self, loop, loudness, reverb_seconds=3.6, wet=0.9):
        """Mélange, réverbération, boucle sans couture, puis mise à niveau du volume."""
        verb = gs.reverb(self.send, SR, self.rng, wet=1.0, seconds=reverb_seconds, dry=False)
        out = np.zeros((2, max(self.dry.shape[1], verb.shape[1])))
        out[:, :self.dry.shape[1]] += self.dry
        out[:, :verb.shape[1]] += verb * wet
        n = gs.samples(self.length, SR)
        if loop:
            tail = out[:, n:]
            while tail.shape[1] > 0:  # La queue d'écho de la fin retombe sur le début.
                chunk = tail[:, :n]
                out[:, :chunk.shape[1]] += chunk
                tail = tail[:, n:]
            out = out[:, :n]
        else:
            # On coupe quand le son est retombé dans le silence.
            level = np.abs(out).max(axis=0)
            last = np.nonzero(level > level.max() * 0.002)[0][-1]
            out = out[:, :last + SR // 4]
            fade = min(out.shape[1], SR // 2)
            out[:, -fade:] *= np.linspace(1, 0, fade)
        # Volume : on vise une puissance moyenne (RMS), puis on adoucit les pics.
        rms = np.sqrt(np.mean(out ** 2)) or 1.0
        out = out * (loudness / rms)
        return gs.soft_clip(out, 1.2) * 0.95


def save(name, stereo):
    """Écrit un WAV temporaire puis l'encode en OGG Vorbis avec ffmpeg."""
    os.makedirs(OUT, exist_ok=True)
    data = (np.clip(stereo.T, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    with wave.open(path, "wb") as file:
        file.setnchannels(2)
        file.setsampwidth(2)
        file.setframerate(SR)
        file.writeframes(data.tobytes())
    target = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", path, "-c:a", "libvorbis",
                    "-q:a", "3", target], check=True)
    os.remove(path)
    print("  %-9s %5.1f s  %4d Ko" % (name, stereo.shape[1] / SR, os.path.getsize(target) // 1024))


def drips(track, count, seed):
    """Gouttes d'eau qui tombent dans la caverne (pour l'ambiance calme)."""
    rng = np.random.default_rng(seed)
    beats = track.length / track.beat
    for _ in range(count):
        f = rng.uniform(900, 1600)
        d = 0.14
        t = gs.tvec(d, SR)
        drop = np.sin(gs.phase_of(f * np.exp(-t * 4), len(t), SR)) * np.exp(-t / 0.03)
        track.add(drop, rng.uniform(0, beats - 1), rng.uniform(-0.8, 0.8), rng.uniform(0.04, 0.09), 0.7)


def wind(track, gain):
    """Souffle d'air grave dans les galeries, qui ondule lentement."""
    n = gs.samples(track.length, SR)
    t = np.arange(n) / SR
    air = gs.fft_filter(track.rng.uniform(-1, 1, n), SR, low=60, high=380)
    period = track.length
    air *= 0.6 + 0.4 * np.sin(2 * np.pi * 2 * t / period + 1.0)  # Ondule 2 fois par boucle.
    air /= np.max(np.abs(air))
    track.add(air, 0, -0.3, gain, 0.2)
    track.add(np.roll(air, n // 3), 0, 0.3, gain, 0.2)


# ---------------------------------------------------------------------------
# Les morceaux
# ---------------------------------------------------------------------------

def menu_theme():
    """« Le Trône des Profondeurs » — lent et solennel, 60 battements/min, 16 mesures."""
    tr = Track(bpm=60, beats=64, seed=11)
    prog = ["Dm", "Bb", "Gm", "A", "Dm", "F", "Gm", "A",
            "Bb", "Gm", "Dm", "A", "Dm", "Bb", "Gm", [("Asus", 2), ("A", 2)]]
    for bar, content in enumerate(prog):
        parts = [(content, 4)] if isinstance(content, str) else content
        at = bar * 4
        for chord, length in parts:
            stops = "doux" if bar < 4 else "plein"
            tr.organ(CHORDS[chord], at, length, stops, gain=0.45 if bar < 4 else 0.55)
            # Pédale de l'orgue : la basse, deux octaves sous l'accord.
            tr.organ([ROOTS[chord] + "1"], at, length, "bourdon", gain=0.35, spread=0)
            at += length
    # Le glas, au début de chaque phrase.
    for bar in [0, 4, 8, 12]:
        tr.bell("D3", bar * 4, 7.0, gain=0.55, pan=-0.3)
    tr.bell("A3", 62, 5.0, gain=0.25, pan=0.4, brightness=0.8)

    # Le chœur chante la mélodie (mesures 5 à 16).
    melody = [("A4", 2), ("D5", 2), ("C5", 2), ("A4", 2), ("Bb4", 2), ("G4", 1), ("A4", 1),
              ("C#5", 2), ("E5", 2), ("D5", 3), ("F5", 1), ("D5", 2), ("Bb4", 2),
              ("A4", 4), ("G4", 1), ("F4", 1), ("E4", 2),
              ("D5", 2), ("F5", 2), ("F5", 2), ("D5", 2), ("Bb4", 2), ("A4", 2), ("D5", 2), ("C#5", 2)]
    sing(tr, melody, 16, prog, 4, "a", gain=0.5, attack=0.25)
    # Nappes du chœur grave (« ou ») sur la deuxième moitié.
    for bar in range(8, 16):
        chord = chord_at(prog, bar * 4, 4)
        tr.choir(CHORDS[chord][1:3], bar * 4, 4, "u", gain=0.22, attack=0.6)
    # Violoncelles : la basse qui chante, mesures 9 à 16.
    for bar in range(8, 16):
        root = ROOTS[chord_at(prog, bar * 4, 4)]
        tr.strings(root + "2", bar * 4, 2, gain=0.35)
        tr.strings(root + "3", bar * 4 + 2, 2, gain=0.25)
    # Timbales qui annoncent le retour au début.
    for i, b in enumerate([60, 61, 62, 62.5, 63, 63.5]):
        tr.timpani("A2" if i < 4 else "D2", b, gain=0.25 + i * 0.05, force=0.7)
    return tr.render(loop=True, loudness=0.13)


def harmony_below(name, chord, gap=3):
    """La note de l'accord la plus proche sous la mélodie (au moins `gap` demi-tons
    plus bas) : c'est la deuxième voix du chœur."""
    top = N(name)
    best = None
    for base in CHORDS[chord]:
        for octave in range(-2, 3):
            f = N(base) * 2 ** octave
            if f < top / 2 ** (gap / 12) + 0.01 and (best is None or f > best):
                best = f
    return best


def chord_at(prog, beat, beats_per_bar):
    """L'accord qui sonne à ce temps-là. Une mesure peut contenir [(accord, temps), ...]."""
    bar = prog[int(beat // beats_per_bar) % len(prog)]
    if isinstance(bar, str):
        return bar
    pos = beat % beats_per_bar
    for chord, length in bar:
        if pos < length:
            return chord
        pos -= length
    return bar[-1][0]


def sing(tr, melody, start, prog, beats_per_bar, vowel, gain, attack, send=0.6, octave_double=False):
    """Fait chanter une mélodie au chœur, harmonisée à deux (ou trois) voix."""
    pos = start
    for name, dur in melody:
        chord = chord_at(prog, pos, beats_per_bar)
        freqs = [N(name), harmony_below(name, chord)]
        if octave_double:
            freqs.append(N(name) / 2)
        for i, f in enumerate(freqs):
            sound = gs.choir(f, tr.sec(dur), SR, tr.rng, vowel, attack=attack)
            tr.add(sound, pos, (i - 1) * 0.35, gain / len(freqs) ** 0.5, send)
        pos += dur


def calm_theme():
    """« Les Galeries » — à trois temps, clavecin et cordes graves, 72 battements/min, 32 mesures."""
    tr = Track(bpm=72, beats=96, seed=22)
    prog = ["Dm", "Dm", "Gm", "Gm", "Bb", "Gm", "A", "A",
            "Dm", "F", "C", "Gm", "Bb", "Gm", "A", "Dm",
            "Bb", "Gm", "Dm", "A", "Bb", "Gm", "Asus", "A",
            "Dm", "Dm", "Gm", "A", "Dm", "Bb", "Gm", "A"]
    for bar, chord in enumerate(prog):
        at = bar * 3
        notes = CHORDS[chord]
        # Clavecin : arpège en croches (6 par mesure), sauf dans le passage des cordes.
        if not 16 <= bar < 24 or bar % 2 == 0:
            pattern = [notes[0], notes[2], notes[3], notes[4], notes[3], notes[2]]
            for i, name in enumerate(pattern):
                up = name[:-1] + str(int(name[-1]) + 1)
                tr.harpsichord(up, at + i * 0.5, 0.5, gain=0.2 if i else 0.26, pan=0.35)
        # Contrebasse : la fondamentale tenue, très douce.
        tr.strings(ROOTS[chord] + "2", at, 3, gain=0.18, pan=-0.35, attack=0.6)
    # Bourdon d'orgue lointain (ré + la) qui tient tout le morceau.
    for bar in range(0, 32, 4):
        tr.organ(["D2", "A2"], bar * 3, 12, "bourdon", gain=0.12, send=0.7)
    # Chœur lointain (« ou ») sur la deuxième phrase.
    for bar in range(8, 16, 2):
        names = CHORDS[prog[bar]][2:4]
        tr.choir(names, bar * 3, 6, "u", gain=0.16, send=0.8, attack=1.0)
    # Le violoncelle chante (mesures 17 à 24).
    cello = [(0, "F3", 2), (2, "D3", 1), (3, "G3", 3), (6, "A3", 2), (8, "F3", 1), (9, "E3", 2), (11, "C#3", 1),
             (12, "D3", 2), (14, "F3", 1), (15, "Bb3", 2), (17, "A3", 1), (18, "G3", 1), (19, "F3", 1),
             (20, "E3", 1), (21, "A2", 3)]
    for start, name, dur in cello:
        tr.strings(name, 48 + start, dur, gain=0.11, pan=-0.15, voices=1, attack=0.15, bright=2000)
    # Cloche lointaine.
    tr.bell("A3", 24 * 3, 7.0, gain=0.15, pan=0.6, send=0.85, brightness=0.6)
    tr.bell("D3", 72, 7.0, gain=0.12, pan=-0.6, send=0.85, brightness=0.6)
    drips(tr, 34, seed=5)
    wind(tr, 0.05)
    return tr.render(loop=True, loudness=0.09, reverb_seconds=4.2)


def combat_theme():
    """« L'Assaut » — 132 battements/min, 32 mesures à quatre temps."""
    tr = Track(bpm=132, beats=128, seed=33)
    prog = ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A",
            "Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A",
            "Dm", "Eb", "Dm", "Eb", "Bb", "C", "A", "A",
            "Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A"]
    # Petit motif inquiétant des cordes (en demi-tons au-dessus de la fondamentale).
    motif = [0, 0, 0, 0, 1, 0, 0, -2]
    for bar, chord in enumerate(prog):
        at = bar * 4
        root = N(ROOTS[chord] + "2")
        for i, step in enumerate(motif):
            freq = root * 2 ** (step / 12)
            for octave, gain, p in [(1, 0.32, -0.35), (2, 0.2, 0.35)]:
                tr.add(gs.strings(freq * octave, tr.sec(0.45), SR, tr.rng, voices=2, staccato=True),
                       at + i * 0.5, p, gain * (1.25 if i in (0, 4) else 1.0), 0.25)
        # Orgue : accords puissants toutes les deux mesures.
        if bar % 2 == 0:
            tr.organ(CHORDS[chord][:3], at, 8, "anche" if bar >= 8 else "plein", gain=0.32, send=0.5)
        # Timbales sur 1 et 3, roulement toutes les 4 mesures.
        timp = ROOTS[chord] + "2" if ROOTS[chord] in ("D", "Eb", "F", "G", "A", "C") else "F2"
        tr.timpani(timp, at, gain=0.5)
        tr.timpani("A2" if ROOTS[chord] == "D" else timp, at + 2, gain=0.38)
        if bar % 4 == 3:
            for k in range(8):
                tr.timpani("A2", at + 2 + k * 0.25, gain=0.18 + k * 0.03, force=0.7)
        # Tambours de guerre.
        for b, force in [(0, 1.0), (1.5, 0.6), (2, 0.85), (3, 0.6), (3.5, 0.7)]:
            if bar >= 4 or b in (0, 2):
                tr.drum(at + b, gain=0.55, force=force, pitch=1.0 if b != 3.5 else 1.2)
        if bar % 8 == 7:
            tr.add(gs.snare_roll(tr.sec(2), SR, tr.rng), at + 2, 0.2, 0.35, 0.3)
    # Cloches et tam-tam au début de chaque grande phrase.
    for bar in [0, 8, 16, 24]:
        tr.bell("D3", bar * 4, 5.0, gain=0.4, pan=-0.4)
        tr.add(gs.gong(N("D2"), 6.0, SR, tr.rng), bar * 4, 0.3, 0.35 if bar % 16 == 0 else 0.2, 0.5)
    # Le chœur (« o ») : mélodie martelée, mesures 9 à 16 et 25 à 32.
    melody = [("D5", 4), ("D5", 2), ("F5", 2), ("E5", 4), ("D5", 2), ("C#5", 2),
              ("D5", 4), ("Bb4", 2), ("D5", 2), ("C#5", 6), ("A4", 2),
              ("D5", 2), ("F5", 2), ("A5", 4), ("G5", 2), ("F5", 2), ("D5", 4),
              ("Bb4", 2), ("D5", 2), ("G5", 4), ("E5", 4), ("C#5", 4)]
    sing(tr, melody[:11], 32, prog, 4, "o", gain=0.42, attack=0.12, send=0.5, octave_double=True)
    sing(tr, melody[11:], 96, prog, 4, "o", gain=0.42, attack=0.12, send=0.5, octave_double=True)
    # Passage sombre (mesures 17 à 24) : chœur grave qui gronde.
    for bar in range(16, 24, 2):
        tr.choir(CHORDS[prog[bar]][:2], bar * 4, 8, "u", gain=0.3, attack=0.4)
    return tr.render(loop=True, loudness=0.16, reverb_seconds=3.0, wet=0.8)


def victory_theme():
    """Victoire : roulement, puis cadence qui s'illumine en ré majeur, et carillon."""
    tr = Track(bpm=80, beats=16, seed=44, tail=9.0)
    tr.add(gs.snare_roll(tr.sec(2), SR, tr.rng), 0, 0.2, 0.4, 0.3)
    for k in range(8):
        tr.timpani("A2", k * 0.25, gain=0.2 + k * 0.04, force=0.7)
    tr.organ(CHORDS["Bb"], 2, 1.5, "plein", gain=0.55)
    tr.organ(CHORDS["C"], 3.5, 1.5, "plein", gain=0.55)
    tr.organ(CHORDS["D"], 5, 6, "plein", gain=0.65)
    tr.organ(["D1"], 5, 6, "bourdon", gain=0.4)
    tr.choir(["D4", "F#4", "A4", "D5"], 5, 6, "a", gain=0.5, attack=0.2)
    tr.timpani("D2", 2, gain=0.6)
    tr.timpani("D2", 5, gain=0.8)
    for i, name in enumerate(["D5", "A4", "F#4", "D4", "A4", "D5", "F#5", "A5"]):
        tr.bell(name, 5.5 + i * 0.5, 5.0, gain=0.3, pan=-0.6 + i * 0.17, brightness=1.2)
    tr.bell("D3", 5, 8.0, gain=0.5)
    return tr.render(loop=False, loudness=0.15)


def defeat_theme():
    """Défaite : le glas sonne trois fois, le chœur descend vers le silence."""
    tr = Track(bpm=50, beats=12, seed=55, tail=9.0)
    for b in [0, 3, 6]:
        tr.bell("D2" if b < 6 else "A1", b, 8.0, gain=0.6, send=0.7)
    tr.organ(CHORDS["Dm"][:3], 0, 3, "bourdon", gain=0.35)
    tr.organ(["G2", "Bb2", "D3"], 3, 3, "bourdon", gain=0.32)
    tr.organ(["A2", "C#3", "E3"], 6, 2, "bourdon", gain=0.3)
    tr.organ(["D2", "A2", "D3"], 8, 4, "bourdon", gain=0.32)
    for i, name in enumerate(["A4", "G4", "F4", "E4", "D4"]):
        tr.choir([name], 1 + i * 1.5, 1.6 if i < 4 else 4, "u", gain=0.45, attack=0.3)
    tr.strings("D2", 8, 4, gain=0.3, attack=0.8)
    return tr.render(loop=False, loudness=0.12, reverb_seconds=4.5)


PIECES = {
    "menu": menu_theme,
    "calm": calm_theme,
    "combat": combat_theme,
    "victory": victory_theme,
    "defeat": defeat_theme,
}


def main():
    names = sys.argv[1:] or list(PIECES)
    print("Composition de la musique dans", OUT)
    for name in names:
        save(name, PIECES[name]())


if __name__ == "__main__":
    main()
