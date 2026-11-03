#!/usr/bin/env python3
"""Génère tous les sons du jeu dans assets/sounds/ (fichiers WAV).

Usage (depuis la racine du projet) :
    python3 tools/generate_sounds.py

Il faut Python 3 et numpy (pip install numpy).

Comment ça marche : un son, c'est une suite de nombres entre -1 et 1 (des
« échantillons », ici 22 050 par seconde). On les fabrique avec des formules :
  - une SINUSOÏDE donne une note pure (sin(2 * pi * fréquence * temps)) ;
  - du BRUIT (des nombres au hasard) donne un souffle, un choc, un grattement ;
  - une ENVELOPPE fait monter puis descendre le volume (attaque, puis déclin) ;
  - un FILTRE passe-bas adoucit le son (il garde les graves).
En mélangeant ces briques, on obtient une pioche, des pièces, une explosion...
Tous ces sons sont donc originaux. Change les chiffres et relance le script
pour les modifier, ou remplace un fichier WAV par ton propre enregistrement.
"""

import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sounds")
RATE = 22050
rng = np.random.default_rng(1234)  # Toujours les mêmes sons.


# ---------------------------------------------------------------------------
# Briques de base
# ---------------------------------------------------------------------------

def time(duration):
    return np.arange(int(duration * RATE)) / RATE


def sine(freq, duration):
    """Une note pure. freq peut être un nombre ou un tableau (glissando)."""
    t = time(duration)
    freq = np.broadcast_to(freq, t.shape)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return np.sin(phase)


def square(freq, duration):
    """Une note « 8 bits », plus riche qu'une sinusoïde."""
    return np.sign(sine(freq, duration)) * 0.6


def noise(duration):
    return rng.uniform(-1, 1, int(duration * RATE))


def glide(start, end, duration):
    """Une fréquence qui glisse de start à end (en échelle logarithmique)."""
    return np.geomspace(start, end, int(duration * RATE))


def envelope(duration, attack=0.005, decay=None):
    """Monte en `attack` secondes, puis décroît (exponentiellement) jusqu'à la fin."""
    t = time(duration)
    env = np.ones_like(t)
    a = max(int(attack * RATE), 1)
    env[:a] = np.linspace(0, 1, a)
    decay = decay or duration / 4
    env[a:] = np.exp(-(t[a:] - t[a]) / decay)
    return env


def lowpass(signal, amount):
    """Filtre passe-bas simple : amount proche de 0 = très étouffé, 1 = intact."""
    out = np.empty_like(signal)
    value = 0.0
    for i, sample in enumerate(signal):
        value += amount * (sample - value)
        out[i] = value
    return out


def highpass(signal, amount):
    return signal - lowpass(signal, amount)


def mix(*parts):
    """Additionne des sons de longueurs différentes."""
    length = max(len(p) for p in parts)
    out = np.zeros(length)
    for p in parts:
        out[:len(p)] += p
    return out


def at(signal, delay):
    """Décale un son de `delay` secondes (du silence avant)."""
    return np.concatenate([np.zeros(int(delay * RATE)), signal])


def metal(freq, duration, decay):
    """Un son métallique : plusieurs fréquences « pas harmonieuses » ensemble."""
    ratios = [1.0, 1.51, 2.27, 3.03]
    return sum(sine(freq * r, duration) / (i + 1) for i, r in enumerate(ratios)) * envelope(duration, 0.001, decay)


def save(name, signal, volume=0.8):
    """Normalise le volume, adoucit la fin et écrit le fichier WAV 16 bits mono."""
    signal = np.asarray(signal, dtype=float)
    peak = np.max(np.abs(signal)) or 1.0
    signal = signal / peak * volume
    fade = min(len(signal), int(0.01 * RATE))
    signal[-fade:] *= np.linspace(1, 0, fade)
    data = (signal * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(data.tobytes())


# ---------------------------------------------------------------------------
# Les sons du jeu
# ---------------------------------------------------------------------------

def make_effects():
    # Pioche dans la terre : un « tchac » (bruit étouffé) + le choc du métal. 3 variantes.
    for i, pitch in enumerate([1.0, 0.85, 1.15]):
        d = 0.16
        thud = lowpass(noise(d), 0.25) * envelope(d, 0.001, 0.035)
        tick = metal(1500 * pitch, d, 0.02) * 0.35
        save("dig_%d" % i, mix(thud, tick), 0.55)

    # Or arraché à un filon : un tintement clair.
    save("gold", metal(2400, 0.35, 0.08), 0.45)

    # Pièces déposées au trésor : plusieurs tintements à la suite.
    coins = mix(*[at(metal(f, 0.3, 0.06), delay) for f, delay in
                  [(2600, 0), (3100, 0.06), (2300, 0.11), (2900, 0.17), (3300, 0.22)]])
    save("coins", coins, 0.5)

    # Revendiquer une case : un petit scintillement magique qui monte.
    d = 0.45
    shimmer = sine(glide(500, 950, d), d) * (0.6 + 0.4 * sine(18, d)) * envelope(d, 0.05, 0.15)
    save("claim", shimmer, 0.3)

    # Construire : un choc sourd (« boum ») de pierre posée.
    d = 0.3
    save("build", mix(sine(glide(160, 70, d), d) * envelope(d, 0.002, 0.08),
                      lowpass(noise(d), 0.15) * envelope(d, 0.001, 0.05) * 0.8), 0.7)

    # Poser un piège / l'atelier fabrique : clic-clac métallique.
    save("trap_place", mix(metal(900, 0.25, 0.04), at(metal(1300, 0.2, 0.03), 0.08)), 0.5)

    # Portail : un souffle qui monte, avec une note qui glisse.
    d = 1.1
    whoosh = lowpass(noise(d), 0.08) * np.sin(np.linspace(0, np.pi, int(d * RATE)))
    tone = sine(glide(180, 620, d), d) * np.sin(np.linspace(0, np.pi, int(d * RATE))) * 0.4
    save("portal", mix(whoosh * 2.5, tone), 0.55)

    # Une créature s'en va, furieuse : une note qui descend tristement.
    d = 0.9
    save("leave", square(glide(420, 140, d), d) * envelope(d, 0.02, 0.4), 0.3)

    # Passage de niveau : arpège montant en « 8 bits ».
    notes = [523, 659, 784, 1047]
    save("level_up", mix(*[at(square(f, 0.18) * envelope(0.18, 0.005, 0.08), i * 0.09)
                           for i, f in enumerate(notes)]), 0.35)

    # Coups de poing / de griffe des créatures : 2 variantes.
    for i, freq in enumerate([110, 140]):
        d = 0.14
        save("punch_%d" % i, mix(sine(glide(freq * 2, freq, d), d) * envelope(d, 0.001, 0.04),
                                 lowpass(noise(d), 0.3) * envelope(d, 0.001, 0.025)), 0.6)

    # Coups d'épée des héros : un choc métallique avec un peu de souffle. 2 variantes.
    for i, freq in enumerate([1800, 2200]):
        d = 0.25
        save("sword_%d" % i, mix(metal(freq, d, 0.05) * 0.7,
                                 highpass(noise(d), 0.5) * envelope(d, 0.001, 0.02) * 0.6), 0.45)

    # Attaque magique du Sorcier : un « zap » électrique.
    d = 0.25
    save("zap", square(glide(1800, 300, d), d) * envelope(d, 0.001, 0.07), 0.3)

    # Mort : une chute de note avec un souffle.
    d = 0.6
    save("death", mix(sine(glide(420, 70, d), d) * envelope(d, 0.005, 0.2),
                      lowpass(noise(d), 0.1) * envelope(d, 0.005, 0.15) * 0.6), 0.55)

    # Pointes qui jaillissent : « shing ! »
    d = 0.3
    save("spikes", mix(highpass(noise(d), 0.6) * envelope(d, 0.001, 0.03),
                       metal(3200, d, 0.06) * 0.5), 0.5)

    # Explosion de la rune : gros bruit grave qui s'éteint lentement.
    d = 1.2
    blast = lowpass(noise(d), 0.06) * envelope(d, 0.002, 0.3) * 3
    rumble = sine(glide(80, 35, d), d) * envelope(d, 0.01, 0.4)
    save("explosion", mix(blast, rumble), 0.85)

    # Un héros frappe une porte : « toc » de bois.
    d = 0.2
    save("door_hit", mix(sine(180, d) * envelope(d, 0.001, 0.04), sine(330, d) * envelope(d, 0.001, 0.03) * 0.5,
                         lowpass(noise(d), 0.4) * envelope(d, 0.001, 0.015) * 0.5), 0.6)

    # Porte enfoncée : craquements de bois.
    d = 0.7
    crack = np.zeros(int(d * RATE))
    for _ in range(14):
        start = rng.integers(0, int(0.5 * RATE))
        burst = lowpass(noise(0.05), 0.5) * envelope(0.05, 0.001, 0.01)
        crack[start:start + len(burst)] += burst
    save("door_break", mix(crack, sine(glide(200, 60, d), d) * envelope(d, 0.002, 0.15) * 0.6), 0.7)

    # Le cœur est frappé : double battement grave (« boum-boum »).
    beat = lambda: sine(glide(90, 50, 0.18), 0.18) * envelope(0.18, 0.003, 0.05)
    save("heart_hit", mix(beat(), at(beat() * 0.7, 0.16)), 0.8)

    # Cor de guerre : une vague de héros arrive.
    d = 1.6
    horn = sum(np.sin(2 * np.pi * 110 * k * time(d)) / k for k in range(1, 7))
    swell = np.minimum(1, time(d) / 0.25) * np.exp(-time(d) / 1.4)
    note_two = sum(np.sin(2 * np.pi * 146.8 * k * time(1.2)) / k for k in range(1, 7))
    swell_two = np.minimum(1, time(1.2) / 0.2) * np.exp(-time(1.2) / 0.8)
    save("horn", lowpass(mix(horn * swell, at(note_two * swell_two, 1.1)), 0.3), 0.6)

    # Découverte (recherche terminée, vague repoussée) : un accord de cloches.
    d = 1.4
    save("discovery", mix(*[at(metal(f, d - i * 0.1, 0.5), i * 0.1) for i, f in enumerate([660, 830, 990])]), 0.4)

    # Sorts.
    d = 0.8
    save("heal", mix(*[at(sine(f, 0.5) * envelope(0.5, 0.01, 0.2), i * 0.1)
                       for i, f in enumerate([784, 988, 1175, 1568])]), 0.35)
    d = 0.7
    strike = highpass(noise(d), 0.7) * envelope(d, 0.001, 0.06) * 2
    crackle = np.zeros(int(d * RATE))
    for _ in range(20):
        start = rng.integers(0, int(0.6 * RATE))
        crackle[start:start + 60] += rng.uniform(-1, 1, 60)
    save("lightning", mix(strike, crackle * 0.6, sine(glide(120, 40, d), d) * envelope(d, 0.002, 0.25)), 0.7)
    d = 0.35
    save("haste", sine(glide(300, 1600, d), d) * envelope(d, 0.01, 0.12), 0.35)

    # Erreur (pas assez d'or, de mana...) : un petit « bzz » grave.
    d = 0.18
    save("error", square(150, d) * envelope(d, 0.003, 0.08), 0.25)

    # La main du maître : ramasser (souffle qui monte) et déposer (« plop »).
    d = 0.2
    save("pickup", sine(glide(300, 900, d), d) * envelope(d, 0.005, 0.07), 0.35)
    save("drop", mix(sine(glide(500, 120, d), d) * envelope(d, 0.002, 0.05),
                     lowpass(noise(d), 0.3) * envelope(d, 0.001, 0.02) * 0.5), 0.5)

    # Clic de bouton.
    d = 0.04
    save("click", sine(1200, d) * envelope(d, 0.001, 0.008), 0.3)

    # Défaite : notes qui descendent, lentes et graves.
    d = 2.4
    save("game_over", mix(*[at(square(f, 0.7) * envelope(0.7, 0.01, 0.35), i * 0.45)
                            for i, f in enumerate([392, 349, 311, 262])]), 0.35)


def make_ambience():
    """Une ambiance de caverne qui tourne en boucle : bourdon grave, souffle d'air
    et gouttes d'eau. Les 2 dernières secondes se fondent dans le début pour que
    la boucle ne s'entende pas."""
    length, overlap = 40.0, 2.0
    d = length + overlap
    t = time(d)
    drone = (np.sin(2 * np.pi * 55 * t) * 0.5 + np.sin(2 * np.pi * 82.4 * t) * 0.3
             + np.sin(2 * np.pi * 110.3 * t) * 0.15) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.05 * t))
    wind = lowpass(noise(d), 0.01) * 6 * (0.6 + 0.4 * np.sin(2 * np.pi * 0.033 * t + 1.0))
    drips = np.zeros_like(t)
    for _ in range(26):
        start = rng.uniform(0, length - 1)
        freq = rng.uniform(900, 1500)
        drip = sine(glide(freq, freq * 0.6, 0.12), 0.12) * envelope(0.12, 0.002, 0.03) * rng.uniform(0.15, 0.35)
        i = int(start * RATE)
        drips[i:i + len(drip)] += drip
    for start in [9.0, 27.5]:  # Une cloche lointaine, de temps en temps.
        bell = metal(196, 3.0, 1.0) * 0.12
        i = int(start * RATE)
        drips[i:i + len(bell)] += bell
    signal = drone * 0.35 + wind * 0.25 + drips
    n, o = int(length * RATE), int(overlap * RATE)
    loop = signal[:n].copy()
    fade = np.linspace(0, 1, o)
    loop[:o] = loop[:o] * fade + signal[n:n + o] * (1 - fade)
    save("ambience", loop, 0.5)


def main():
    make_effects()
    make_ambience()
    print("Sons générés dans", OUT)


if __name__ == "__main__":
    main()
