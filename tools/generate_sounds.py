#!/usr/bin/env python3
"""Génère tous les effets sonores du jeu dans assets/sounds/ (fichiers WAV).

Usage (depuis la racine du projet) :
    python3 tools/generate_sounds.py

Il faut Python 3 et numpy (pip install numpy). La musique, elle, est composée
par tools/generate_music.py.

Style : gothique. Les sons utilisent les instruments de tools/gothic_synth.py
(cloches, orgue, chœur, cordes, timbales...) et une petite réverbération de
salle de pierre, pour qu'on ait l'impression d'être sous terre.

Comment ça marche : un son, c'est une suite de nombres entre -1 et 1 (des
« échantillons », ici 22 050 par seconde). On les fabrique avec des formules :
  - une SINUSOÏDE donne une note pure (sin(2 * pi * fréquence * temps)) ;
  - du BRUIT (des nombres au hasard) donne un souffle, un choc, un grattement ;
  - une ENVELOPPE fait monter puis descendre le volume (attaque, puis déclin) ;
  - un FILTRE ne garde que les graves (passe-bas) ou que les aigus (passe-haut).
En mélangeant ces briques, on obtient une pioche, des pièces, une explosion...
Tous ces sons sont donc originaux. Change les chiffres et relance le script
pour les modifier, ou remplace un fichier WAV par ton propre enregistrement.
"""

import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gothic_synth as gs  # noqa: E402
from gothic_synth import note as N  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sounds")
RATE = 22050
rng = np.random.default_rng(1234)  # Toujours les mêmes sons.


# ---------------------------------------------------------------------------
# Briques de base
# ---------------------------------------------------------------------------

def time(duration):
    return np.arange(gs.samples(duration, RATE)) / RATE


def sine(freq, duration):
    """Une note pure. freq peut être un nombre ou un tableau (glissando)."""
    return np.sin(gs.phase_of(freq, gs.samples(duration, RATE), RATE))


def noise(duration):
    return rng.uniform(-1, 1, gs.samples(duration, RATE))


def glide(start, end, duration):
    """Une fréquence qui glisse de start à end (en échelle logarithmique)."""
    return np.geomspace(start, end, gs.samples(duration, RATE))


def envelope(duration, attack=0.005, decay=None):
    """Monte en `attack` secondes, puis décroît (exponentiellement) jusqu'à la fin."""
    t = time(duration)
    a = max(int(attack * RATE), 1)
    env = np.ones_like(t)
    env[:a] = np.linspace(0, 1, a)
    decay = decay or duration / 4
    env[a:] = np.exp(-(t[a:] - t[a - 1]) / decay)
    return env


def swell(duration, peak=0.5):
    """Monte puis redescend (en cloche) : pour les souffles et les sorts."""
    t = np.linspace(0, 1, gs.samples(duration, RATE))
    return np.where(t < peak, t / peak, (1 - t) / (1 - peak)) ** 1.5


def lowpass(signal, cutoff):
    return gs.fft_filter(signal, RATE, high=cutoff)


def highpass(signal, cutoff):
    return gs.fft_filter(signal, RATE, low=cutoff)


def bandpass(signal, low, high):
    return gs.fft_filter(signal, RATE, low=low, high=high)


def mix(*parts):
    """Additionne des sons de longueurs différentes."""
    length = max(len(p) for p in parts)
    out = np.zeros(length)
    for p in parts:
        out[:len(p)] += p
    return out


def at(signal, delay):
    """Décale un son de `delay` secondes (du silence avant)."""
    return np.concatenate([np.zeros(gs.samples(delay, RATE) if delay > 0 else 0), signal])


def metal(freq, duration, decay):
    """Un choc métallique (lame, chaîne, mécanisme) : partiels inharmoniques."""
    t = time(duration)
    out = np.zeros_like(t)
    for ratio, amp, life in [(1.0, 1.0, 1.0), (1.51, 0.6, 0.8), (2.27, 0.45, 0.6),
                             (3.03, 0.3, 0.45), (4.18, 0.2, 0.3), (5.4, 0.12, 0.2)]:
        if freq * ratio < RATE * 0.45:
            out += amp * np.exp(-t / (decay * life)) * np.sin(2 * np.pi * freq * ratio * t + rng.uniform(0, 6.28))
    return gs.soften_attack(out / 2, RATE)


def thud(duration, start=150, end=50, decay=0.08, grit=0.6):
    """Un choc sourd (pierre, bois, chair) : note grave qui tombe + bruit étouffé."""
    body = sine(glide(start, end, duration), duration) * envelope(duration, 0.002, decay)
    dust = lowpass(noise(duration), 900) * envelope(duration, 0.001, decay * 0.5) * grit
    return mix(body, dust)


def room(signal, wet=0.18, seconds=0.8):
    """L'écho d'une galerie souterraine : une queue sombre (les aigus meurent vite
    contre la roche) et des échos sourds renvoyés par les parois du tunnel."""
    return gs.reverb(np.asarray(signal, dtype=float), RATE, rng, wet=wet * 1.6, seconds=seconds + 0.6,
                     predelay=0.015, damping=0.3, tunnel=0.6)


def save(name, signal, volume=0.8):
    """Normalise le volume, coupe le silence final, et écrit le WAV 16 bits mono."""
    # Sous terre, rien ne siffle : on adoucit les aigus de tous les sons.
    signal = gs.fft_filter(np.asarray(signal, dtype=float), RATE, high=5000, slope=2.0)
    peak = np.max(np.abs(signal)) or 1.0
    signal = signal / peak * volume
    alive = np.nonzero(np.abs(signal) > volume * 0.003)[0]
    if len(alive):
        signal = signal[:alive[-1] + 1]
    fade = min(len(signal), int(0.02 * RATE))
    signal[-fade:] *= np.linspace(1, 0, fade)
    data = (signal * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(data.tobytes())


# Raccourcis vers les instruments gothiques (à 22 050 échantillons/s).
def bell(name_or_freq, duration, brightness=1.0):
    f = N(name_or_freq) if isinstance(name_or_freq, str) else name_or_freq
    return gs.bell(f, duration, RATE, rng, brightness)


def choir(name, duration, vowel="a", **kw):
    return gs.choir(N(name), duration, RATE, rng, vowel, **kw)


def organ(name, duration, stops="plein", **kw):
    return gs.organ(N(name), duration, RATE, rng, stops, **kw)


def harpsichord(name, duration):
    return gs.harpsichord(N(name), duration, RATE, rng)


# ---------------------------------------------------------------------------
# Les sons du jeu
# ---------------------------------------------------------------------------

def make_effects():
    # Pioche dans la roche : un choc sourd, le fer qui « tonk » (grave et mat),
    # des cailloux qui tombent. 3 variantes.
    for i, pitch in enumerate([1.0, 0.86, 1.13]):
        d = 0.35
        hit = thud(d, 170 * pitch, 60, 0.05, grit=1.2)
        iron = lowpass(metal(480 * pitch, d, 0.035), 2200) * 0.35
        crumble = mix(*[at(bandpass(noise(0.04), 300, 2200) * envelope(0.04, 0.001, 0.012)
                           * rng.uniform(0.15, 0.35), rng.uniform(0.04, 0.2)) for _ in range(6)])
        save("dig_%d" % i, room(mix(hit, iron, crumble), 0.14, 0.7), 0.55)

    # Or arraché à un filon : une pépite lourde qui sonne grave et mat (ré, accordé
    # avec la musique), et quelques éclats qui roulent. Rien d'aigu ni de strident.
    nugget = lowpass(bell("D5", 0.6, 0.35), 1800)
    chips = mix(*[at(lowpass(bell(n, 0.25, 0.4), 2200) * 0.25, t) for n, t in [("A5", 0.07), ("F5", 0.13)]])
    save("gold", room(mix(thud(0.2, 200, 90, 0.03, 0.5) * 0.5, nugget, chips), 0.16, 0.8), 0.38)

    # Pièces déposées au trésor : une poignée d'or qui tinte (une octave plus bas, sourdine).
    coins = mix(*[at(lowpass(bell(f, 0.4, 0.6), 3000), delay) for f, delay in
                  [("D6", 0), ("F6", 0.05), ("A5", 0.1), ("E6", 0.15), ("A6", 0.2), ("D6", 0.26)]])
    save("coins", room(coins, 0.16, 0.8), 0.42)

    # Revendiquer une case : un murmure sombre du chœur (la magie du Seigneur).
    d = 0.35
    whisper = choir("D3", d, "u", voices=2, attack=0.08, release=0.25, breath=0.2)
    save("claim", room(whisper * envelope(len(whisper) / RATE, 0.08, 0.2), 0.3, 1.0), 0.28)

    # Construire : un bloc de pierre posé, et un coup de marteau sur le fer.
    d = 0.4
    save("build", room(mix(thud(d, 140, 55, 0.09, 1.0), at(metal(820, 0.3, 0.05) * 0.4, 0.06)), 0.15), 0.7)

    # Poser un piège / l'atelier fabrique : un mécanisme qui s'arme (cliquets + clac).
    ratchet = mix(*[at(metal(1600 + k * 120, 0.08, 0.012) * 0.4, k * 0.035) for k in range(4)])
    save("trap_place", room(mix(ratchet, at(metal(700, 0.3, 0.05), 0.16)), 0.15), 0.5)

    # Portail : un souffle qui tourbillonne et le chœur qui gronde, en montant.
    d = 1.3
    whoosh = bandpass(noise(d), 200, 1600) * swell(d, 0.6) * (0.7 + 0.3 * sine(7, d))
    voices = mix(choir("D3", 0.9, "o", attack=0.4, release=0.4, glide_to=N("A3")),
                 choir("A2", 0.9, "o", attack=0.4, release=0.4, glide_to=N("E3")) * 0.7)
    save("portal", room(mix(whoosh * 1.4, voices), 0.35, 1.6), 0.55)

    # Une créature s'en va, furieuse : une plainte qui descend.
    d = 0.8
    save("leave", room(choir("A3", d, "o", voices=2, attack=0.05, release=0.3, glide_to=N("D3")), 0.25, 1.2), 0.38)

    # Passage de niveau : arpège d'orgue qui monte, et une clochette.
    notes = ["D4", "F4", "A4", "D5"]
    arpeggio = mix(*[at(organ(n, 0.16 if i < 3 else 0.5, "plein", attack=0.02, release=0.2), i * 0.09)
                     for i, n in enumerate(notes)])
    save("level_up", room(mix(arpeggio, at(bell("D6", 1.0, 1.2) * 0.25, 0.27)), 0.3, 1.4), 0.45)

    # Coups de poing / de griffe des créatures : 2 variantes.
    for i, freq in enumerate([110, 140]):
        d = 0.18
        save("punch_%d" % i, room(thud(d, freq * 2, freq * 0.8, 0.04, 1.2), 0.08, 0.5), 0.6)

    # Coups d'épée des héros : un sifflement, puis l'acier qui sonne. 2 variantes.
    for i, freq in enumerate([1650, 2050]):
        d = 0.4
        swish = bandpass(noise(0.08), 2000, 7000) * swell(0.08, 0.7) * 0.5
        clang = at(metal(freq, d, 0.09), 0.05)
        save("sword_%d" % i, room(mix(swish, clang), 0.12, 0.6), 0.45)

    # Attaque magique du Sorcier : une décharge qui crépite et tombe.
    d = 0.35
    bolt = bandpass(noise(d), 400, 3000) * (0.6 + 0.4 * np.sign(sine(glide(90, 30, d), d)))
    tone = choir("A4", d - 0.1, "e", voices=2, attack=0.01, release=0.1, glide_to=N("A3")) * 0.6
    save("zap", room(mix(bolt * envelope(d, 0.002, 0.08), tone), 0.2), 0.32)

    # Mort : un râle grave du chœur et la chute du corps.
    d = 0.7
    groan = choir("F3", d, "o", voices=2, attack=0.02, release=0.3, glide_to=N("A2"), breath=0.15)
    save("death", room(mix(groan, at(thud(0.3, 120, 45, 0.07), 0.45)), 0.2, 1.0), 0.55)

    # Pointes qui jaillissent : « shing » d'acier et clac du mécanisme.
    d = 0.4
    save("spikes", room(mix(highpass(noise(d), 4000) * envelope(d, 0.001, 0.03), metal(2900, d, 0.08) * 0.6,
                            thud(0.15, 300, 120, 0.02) * 0.5), 0.12), 0.5)

    # Explosion de la rune : déflagration, grondement, gravats qui retombent.
    d = 1.8
    blast = lowpass(noise(d), 600) * envelope(d, 0.002, 0.3) * 2.5
    rumble = sine(glide(70, 28, d), d) * envelope(d, 0.01, 0.6)
    debris = mix(*[at(thud(0.12, rng.uniform(250, 500), 100, 0.02, 1.0) * rng.uniform(0.05, 0.2),
                      rng.uniform(0.3, 1.3)) for _ in range(10)])
    save("explosion", room(mix(blast, rumble, debris), 0.3, 1.8), 0.85)

    # Un héros frappe une porte : bois épais et ferrures qui tremblent.
    d = 0.3
    save("door_hit", room(mix(thud(d, 170, 80, 0.05, 0.8), metal(430, d, 0.06) * 0.15), 0.15), 0.6)

    # Porte enfoncée : le bois craque et éclate.
    d = 0.9
    crack = np.zeros(gs.samples(d, RATE))
    for _ in range(16):
        start = rng.integers(0, int(0.6 * RATE))
        burst = bandpass(noise(0.05), 600, 4000) * envelope(0.05, 0.001, 0.01)
        crack[start:start + len(burst)] += burst
    save("door_break", room(mix(crack, thud(d, 200, 50, 0.18), at(metal(380, 0.6, 0.12) * 0.25, 0.3)), 0.2), 0.7)

    # Le cœur est frappé : deux battements profonds qui résonnent dans la salle.
    beat = lambda: thud(0.3, 85, 40, 0.07, 0.4)
    save("heart_hit", room(mix(beat(), at(beat() * 0.7, 0.2)), 0.25, 1.2), 0.85)

    # Trompe de guerre des héros : deux notes, la seconde plus haute.
    horn = mix(gs.brass(N("D3"), 0.8, RATE, rng), at(gs.brass(N("A3"), 1.1, RATE, rng), 0.75))
    save("horn", room(horn, 0.3, 1.8), 0.6)

    # Découverte (recherche terminée, vague repoussée) : chœur et cloches.
    voices = mix(*[choir(n, 1.0, "a", voices=3, attack=0.08, release=0.6) for n in ["F4", "A4", "D5"]])
    bells = mix(bell("D5", 2.0, 1.2) * 0.6, at(bell("A5", 1.8, 1.2) * 0.4, 0.12))
    save("discovery", room(mix(voices, bells), 0.35, 1.8), 0.5)

    # Sorts. Soin : une harpe céleste et un souffle de voix.
    harp = mix(*[at(harpsichord(n, 0.6), i * 0.07) for i, n in enumerate(["D5", "F5", "A5", "D6", "F6"])])
    save("heal", room(mix(harp, choir("A4", 0.6, "a", voices=2, attack=0.15) * 0.4), 0.35, 1.4), 0.4)
    # Foudre : le claquement, puis le tonnerre qui roule sous la voûte.
    d = 1.2
    strike = highpass(noise(d), 2500) * envelope(d, 0.001, 0.05) * 2
    crackle = np.zeros(gs.samples(d, RATE))
    for _ in range(24):
        start = rng.integers(0, int(0.5 * RATE))
        crackle[start:start + 60] += rng.uniform(-1, 1, 60)
    thunder = lowpass(noise(d), 250) * swell(d, 0.25) * 4
    save("lightning", room(mix(strike, crackle * 0.6, thunder), 0.3, 1.6), 0.7)
    # Hâte : une rafale qui monte, avec une gamme de clavecin.
    d = 0.4
    gust = bandpass(noise(d), 800, 5000) * swell(d, 0.7) * 0.6
    run = mix(*[at(harpsichord(n, 0.1) * 0.6, i * 0.045) for i, n in enumerate(["D5", "E5", "F5", "G5", "A5", "C#6", "D6"])])
    save("haste", room(mix(gust, run), 0.2), 0.38)

    # Erreur (pas assez d'or, de mana...) : deux tuyaux d'orgue qui grincent ensemble.
    d = 0.18
    sour = mix(organ("D3", d, "anche", attack=0.01, release=0.08), organ("Eb3", d, "anche", attack=0.01, release=0.08))
    save("error", room(sour, 0.1), 0.3)

    # La main du maître : ramasser (souffle qui monte) et déposer (choc mat).
    d = 0.25
    lift = bandpass(noise(d), 500, 3000) * swell(d, 0.8) * 0.5
    save("pickup", room(mix(lift, at(bell("A6", 0.4, 1.1) * 0.25, 0.12)), 0.2), 0.38)
    save("drop", room(thud(0.25, 260, 90, 0.05, 1.0), 0.12), 0.5)

    # Flèche de l'archer : un sifflement court puis le « toc » dans le bois.
    d = 0.35
    whistle = bandpass(noise(d), 1500, 6000) * envelope(d, 0.02, 0.05) * 0.5
    save("arrow", room(mix(whistle, at(thud(0.12, 280, 120, 0.03), 0.13)), 0.1), 0.45)

    # Capture d'un héros : cliquetis de chaînes et la grille de la cellule qui claque.
    chains = mix(*[at(metal(f, 0.25, 0.04) * 0.6, i * 0.07) for i, f in enumerate([700, 950, 820, 1100, 760])])
    slam = at(mix(thud(0.4, 140, 55, 0.08, 1.0), metal(310, 0.5, 0.1) * 0.4), 0.38)
    save("capture", room(mix(chains, slam), 0.2, 1.0), 0.6)

    # Sacrifice : un gong grave, le chœur qui s'élève, et le glas.
    d = 2.2
    tam = gs.gong(N("D2"), d, RATE, rng) * 0.8
    rise = choir("D3", 1.4, "a", attack=1.0, release=0.5, glide_to=N("A3")) * 0.6
    save("sacrifice", room(mix(tam, rise, at(bell("D3", 1.8) * 0.6, 1.2)), 0.35, 2.0), 0.6)

    # Clic de bouton : le petit « toc » d'une pièce de pierre.
    d = 0.06
    save("click", mix(sine(glide(900, 600, d), d) * envelope(d, 0.001, 0.01),
                      bandpass(noise(d), 1500, 5000) * envelope(d, 0.001, 0.004) * 0.3), 0.3)

    # Défaite : le glas funèbre.
    save("game_over", room(mix(bell("D2", 3.0), at(bell("D2", 2.5) * 0.7, 1.4)), 0.4, 2.5), 0.6)


def main():
    make_effects()
    print("Sons générés dans", OUT)


if __name__ == "__main__":
    main()
