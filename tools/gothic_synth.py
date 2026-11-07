"""Instruments gothiques fabriqués par calcul (numpy seulement).

Utilisé par tools/generate_sounds.py (effets) et tools/generate_music.py (musique).

Chaque instrument est une fonction qui rend un tableau numpy (son mono, valeurs
autour de -1..1) à la fréquence d'échantillonnage `sr`. Les idées :
  - SYNTHÈSE ADDITIVE : on additionne des sinusoïdes (les « harmoniques »). Leur
    mélange donne le timbre : un orgue a des harmoniques nettes et fixes, une voix
    a des harmoniques renforcées autour de quelques fréquences (les FORMANTS, qui
    font le « a », le « o » ou le « ou »), une cloche a des partiels « faux »
    (inharmoniques), d'où son côté métallique.
  - VIBRATO : la note oscille légèrement, comme un chanteur ou un violoncelliste.
  - RÉVERBÉRATION : on « convolue » le son avec la réponse d'une grande salle
    (un souffle qui décroît pendant plusieurs secondes) : c'est l'écho d'une
    cathédrale.
Tout est original : aucun enregistrement n'est utilisé.
"""

import numpy as np

A4 = 440.0
NOTE_INDEX = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}


def note(name):
    """« D3 », « C#4 », « Bb2 » -> fréquence en Hz (La 4 = 440 Hz)."""
    letter, rest = name[0], name[1:]
    shift = 0
    while rest and rest[0] in "#b":
        shift += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    semitones = NOTE_INDEX[letter] + shift + (int(rest) - 4) * 12
    return A4 * 2 ** (semitones / 12)


def samples(duration, sr):
    return max(int(round(duration * sr)), 1)


def tvec(duration, sr):
    return np.arange(samples(duration, sr)) / sr


# ---------------------------------------------------------------------------
# Briques
# ---------------------------------------------------------------------------

def adsr(duration, sr, attack=0.01, decay=0.1, sustain=0.8, release=0.3):
    """Enveloppe : monte (attack), retombe au niveau sustain (decay), tient
    jusqu'à `duration`, puis s'éteint (release). Longueur totale = duration + release."""
    n_hold = samples(duration, sr)
    n_rel = samples(release, sr)
    t = np.arange(n_hold) / sr
    env = np.where(t < attack, t / max(attack, 1e-6),
                   sustain + (1 - sustain) * np.exp(-(t - attack) / max(decay, 1e-6)))
    level = env[-1]
    tail = level * np.exp(-np.arange(n_rel) / sr / (release / 4.0))
    tail *= np.linspace(1, 0, n_rel) ** 0.5
    return np.concatenate([env, tail])


def noise(n, rng):
    return rng.uniform(-1, 1, n)


def fft_filter(signal, sr, low=None, high=None, slope=1.0):
    """Filtre dans le domaine fréquentiel : garde ce qui est entre low et high (Hz).
    slope règle la douceur des bords (en octaves)."""
    n = len(signal)
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(n, 1 / sr) + 1e-3
    gain = np.ones_like(freqs)
    if high is not None:
        gain *= 1 / (1 + (freqs / high) ** (4 / slope))
    if low is not None:
        gain *= 1 / (1 + (low / freqs) ** (4 / slope))
    return np.fft.irfft(spectrum * gain, n)


def one_pole_lowpass(signal, amount):
    """Passe-bas très simple (lent en Python : à garder pour les sons courts)."""
    out = np.empty_like(signal)
    value = 0.0
    for i, sample in enumerate(signal):
        value += amount * (sample - value)
        out[i] = value
    return out


def phase_of(freq, n, sr):
    """Phase cumulée pour une fréquence fixe ou variable (tableau)."""
    freq = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    return 2 * np.pi * np.cumsum(freq) / sr


def vibrato(base_freq, n, sr, rate=5.2, depth=0.004, delay=0.3, rng=None):
    """Fréquence qui ondule doucement (le vibrato s'installe après `delay`)."""
    t = np.arange(n) / sr
    onset = np.clip((t - delay) / 0.4, 0, 1)
    jitter = 0.0 if rng is None else rng.uniform(0, 2 * np.pi)
    wobble = 1 + depth * onset * np.sin(2 * np.pi * rate * t + jitter)
    return base_freq * wobble


def additive(phase, partials, sr, base_freq):
    """Somme d'harmoniques : partials = [(rapport, amplitude), ...].
    Les harmoniques au-dessus de la limite de Nyquist sont ignorées."""
    out = np.zeros(len(phase))
    limit = sr * 0.45
    for ratio, amp in partials:
        if base_freq * ratio < limit and amp > 0:
            out += amp * np.sin(ratio * phase)
    return out


def soften_attack(signal, sr, seconds=0.0015):
    """Évite le « clic » d'un son qui démarre d'un coup : une montée de 1,5 ms."""
    n = min(len(signal), samples(seconds, sr))
    signal[:n] *= np.linspace(0, 1, n)
    return signal


def pan(signal, position):
    """Place un son mono dans l'espace stéréo : -1 = gauche, 0 = centre, 1 = droite."""
    angle = (position + 1) * np.pi / 4
    return np.stack([signal * np.cos(angle), signal * np.sin(angle)])


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

# Les « jeux » de l'orgue : rapport de fréquence -> force. 0.5 = bourdon de 16 pieds
# (une octave plus bas), 1 = 8 pieds, 1.5 = quinte, 2 = prestant de 4 pieds...
ORGAN_STOPS = {
    "plein": [(0.5, 0.55), (1, 1.0), (1.5, 0.35), (2, 0.65), (3, 0.35), (4, 0.3),
              (5, 0.12), (6, 0.15), (8, 0.12), (10, 0.05), (12, 0.06), (16, 0.04)],
    "doux": [(1, 1.0), (2, 0.35), (3, 0.08), (4, 0.06)],
    "bourdon": [(0.5, 0.7), (1, 1.0), (3, 0.18), (5, 0.05)],
    "anche": [(1, 1.0), (2, 0.8), (3, 0.7), (4, 0.6), (5, 0.5), (6, 0.45), (7, 0.35),
              (8, 0.3), (9, 0.22), (10, 0.18), (12, 0.12), (14, 0.08)],
}


def organ(freq, duration, sr, rng, stops="plein", attack=0.06, release=0.45):
    """Orgue d'église : harmoniques fixes, deux rangs de tuyaux légèrement désaccordés
    (ce qui fait « vivre » le son) et un petit souffle (le « chiff ») à l'attaque."""
    env = adsr(duration, sr, attack=attack, decay=0.25, sustain=0.92, release=release)
    n = len(env)
    partials = ORGAN_STOPS[stops]
    out = additive(phase_of(freq, n, sr), partials, sr, freq)
    out += 0.6 * additive(phase_of(freq * 1.0012, n, sr) + rng.uniform(0, 6.28), partials, sr, freq)
    out *= env
    chiff_n = min(n, samples(0.07, sr))
    chiff = fft_filter(noise(chiff_n, rng), sr, low=freq * 2, high=freq * 8)
    chiff *= np.exp(-np.arange(chiff_n) / sr / 0.015)
    out[:chiff_n] += chiff * 0.25
    return out / 2.5


VOWELS = {
    # (fréquence du formant, force, largeur)
    "a": [(730, 1.0, 120), (1090, 0.55, 140), (2440, 0.18, 220), (3400, 0.06, 300)],
    "o": [(480, 1.0, 90), (820, 0.6, 110), (2600, 0.1, 220), (3300, 0.04, 300)],
    "u": [(330, 1.0, 70), (720, 0.3, 90), (2400, 0.04, 220)],
    "e": [(450, 1.0, 90), (1700, 0.4, 150), (2600, 0.2, 220)],
}


def _glide(freq, glide_to, n):
    """Facteur de glissando : de 1 à glide_to / freq (courbe logarithmique)."""
    if glide_to is None:
        return 1.0
    return np.geomspace(1.0, glide_to / freq, n)


def _formant_gain(f, vowel):
    gain = 0.04
    for center, amp, width in VOWELS[vowel]:
        gain += amp * np.exp(-((f - center) / width) ** 2)
    return gain


def choir(freq, duration, sr, rng, vowel="a", voices=4, attack=0.35, release=0.8, breath=0.05, glide_to=None):
    """Chœur : plusieurs chanteurs (voix légèrement désaccordées, chacune avec son
    vibrato), et un timbre de voyelle donné par les formants."""
    env = adsr(duration, sr, attack=attack, decay=0.4, sustain=0.85, release=release)
    n = len(env)
    out = np.zeros(n)
    max_k = int(min(5200, sr * 0.45) / freq)
    for v in range(voices):
        detune = 2 ** (rng.uniform(-9, 9) / 1200)
        f0 = freq * detune
        f = vibrato(f0, n, sr, rate=rng.uniform(4.6, 5.8), depth=rng.uniform(0.003, 0.006),
                    delay=0.25, rng=rng) * _glide(freq, glide_to, n)
        phase = phase_of(f, n, sr) + rng.uniform(0, 6.28)
        voice = np.zeros(n)
        for k in range(1, max_k + 1):
            amp = _formant_gain(k * f0, vowel) / k ** 0.6
            voice += amp * np.sin(k * phase)
        # Chaque voix entre un tout petit peu après les autres.
        lag = samples(rng.uniform(0, 0.05), sr)
        out[lag:] += voice[:n - lag]
    out /= voices
    if breath > 0:
        f1 = VOWELS[vowel][1][0]
        air = fft_filter(noise(n, rng), sr, low=f1 * 0.7, high=f1 * 2.2)
        out += air * breath
    return out * env / 1.6


def strings(freq, duration, sr, rng, voices=3, attack=0.22, release=0.5, staccato=False, bright=2600):
    """Cordes (violoncelle, contrebasse) : dent de scie adoucie, vibrato, plusieurs
    instrumentistes. staccato=True : notes courtes et piquées (coups d'archet)."""
    if staccato:
        env = adsr(duration, sr, attack=0.008, decay=duration * 0.6, sustain=0.25, release=0.12)
    else:
        env = adsr(duration, sr, attack=attack, decay=0.5, sustain=0.85, release=release)
    n = len(env)
    out = np.zeros(n)
    max_k = int(min(7000, sr * 0.45) / freq)
    for v in range(voices):
        f0 = freq * 2 ** (rng.uniform(-6, 6) / 1200)
        f = f0 if staccato else vibrato(f0, n, sr, rate=rng.uniform(5.0, 6.0), depth=0.0035, delay=0.35, rng=rng)
        phase = phase_of(f, n, sr) + rng.uniform(0, 6.28)
        for k in range(1, max_k + 1):
            fk = k * f0
            # Pente du timbre + deux résonances de la caisse en bois.
            amp = (1 / k) / (1 + (fk / bright) ** 2)
            amp *= 1 + 0.8 * np.exp(-((fk - 280) / 120) ** 2) + 0.5 * np.exp(-((fk - 1100) / 300) ** 2)
            out += amp * np.sin(k * phase)
    out /= voices
    bow = fft_filter(noise(n, rng), sr, low=freq * 3, high=freq * 12) * (0.06 if staccato else 0.025)
    return (out + bow) * env


def harpsichord(freq, duration, sr, rng, release=0.15):
    """Clavecin : une corde pincée. Les harmoniques aiguës s'éteignent plus vite
    que les graves, et un petit claquement marque l'attaque."""
    ring = min(duration, 2.5) + release
    n = samples(ring, sr)
    t = np.arange(n) / sr
    out = np.zeros(n)
    phase = phase_of(freq, n, sr)
    for k in range(1, 40):
        stretch = k * (1 + 0.0004 * k * k)  # Corde un peu raide : légère inharmonicité.
        if freq * stretch > sr * 0.45:
            break
        pluck = abs(np.sin(np.pi * k * 0.13)) / k ** 0.8  # Pincée près du bout de la corde.
        tau = 1.8 / (1 + 0.18 * k) * (220 / freq) ** 0.4
        out += pluck * np.exp(-t / tau) * np.sin(stretch * phase)
    # Le doigt relâche la touche : l'étouffoir coupe la corde.
    cut = samples(duration, sr)
    if cut < n:
        out[cut:] *= np.exp(-np.arange(n - cut) / sr / 0.04)
    click_n = samples(0.006, sr)
    out[:click_n] += fft_filter(noise(click_n, rng), sr, low=2000) * np.linspace(1, 0, click_n) * 0.3
    return soften_attack(out * 0.6, sr)


# Partiels d'une cloche d'église (rapports à la note « nominale ») : bourdon,
# fondamentale, tierce mineure, quinte, octave... d'où son timbre sombre.
BELL_PARTIALS = [(0.5, 0.9, 1.0), (1.0, 0.8, 0.55), (1.19, 0.6, 0.4), (1.5, 0.35, 0.3),
                 (2.0, 0.55, 0.25), (2.51, 0.25, 0.15), (2.66, 0.2, 0.13), (3.01, 0.18, 0.1),
                 (4.16, 0.12, 0.07), (5.43, 0.08, 0.05)]


def bell(freq, duration, sr, rng, brightness=1.0):
    """Cloche : partiels inharmoniques, chacun avec sa propre durée (le grave
    « bourdonne » longtemps), et un léger battement entre deux partiels proches."""
    n = samples(duration, sr)
    t = np.arange(n) / sr
    out = np.zeros(n)
    for ratio, amp, life in BELL_PARTIALS:
        f = freq * ratio
        if f > sr * 0.45:
            continue
        amp = amp * (brightness if ratio > 1.6 else 1.0)
        decay = np.exp(-t / (life * duration))
        beat = 1 + 0.15 * np.sin(2 * np.pi * rng.uniform(0.5, 2.0) * t)
        out += amp * decay * beat * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28))
    strike_n = min(n, samples(0.02, sr))
    out[:strike_n] += fft_filter(noise(strike_n, rng), sr, low=1500) * np.linspace(1, 0, strike_n) * 0.5
    return soften_attack(out / 2.2, sr)


def timpani(freq, duration, sr, rng, force=1.0):
    """Timbale : membrane accordée (partiels propres aux timbales), la hauteur
    baisse un peu juste après le coup, plus le choc de la mailloche."""
    n = samples(duration, sr)
    t = np.arange(n) / sr
    bend = 1 + 0.025 * force * np.exp(-t / 0.06)
    phase = phase_of(freq * bend, n, sr)
    out = np.zeros(n)
    for ratio, amp, life in [(1.0, 1.0, 0.9), (1.5, 0.5, 0.6), (1.98, 0.35, 0.45),
                             (2.44, 0.2, 0.3), (2.94, 0.12, 0.2)]:
        out += amp * np.exp(-t / (life * duration * 0.6)) * np.sin(ratio * phase)
    thump = fft_filter(noise(n, rng), sr, high=400) * np.exp(-t / 0.03) * 2.5
    return soften_attack((out + thump) * force * 0.6, sr)


def war_drum(sr, rng, pitch=1.0, force=1.0):
    """Grand tambour de guerre : un « boum » grave qui tombe, et la peau qui claque."""
    duration = 0.9
    n = samples(duration, sr)
    t = np.arange(n) / sr
    f = 55 * pitch * (1 + 0.8 * np.exp(-t / 0.04))
    body = np.sin(phase_of(f, n, sr)) * np.exp(-t / 0.28)
    skin = fft_filter(noise(n, rng), sr, low=150, high=2500) * np.exp(-t / 0.035) * 0.7
    return soften_attack((body + skin) * force * 0.9, sr)


def snare_roll(duration, sr, rng, force=1.0):
    """Roulement de tambour militaire (caisse claire), qui enfle."""
    n = samples(duration, sr)
    t = np.arange(n) / sr
    hits = np.zeros(n)
    step = samples(0.045, sr)
    for i in range(0, n, step):
        hits[i] = rng.uniform(0.6, 1.0)
    kernel = np.exp(-np.arange(samples(0.05, sr)) / sr / 0.012)
    rattle = np.convolve(hits, kernel)[:n] * fft_filter(noise(n, rng), sr, low=1500, high=7000)
    return rattle * (0.25 + 0.75 * t / duration) * force * 0.5


def gong(freq, duration, sr, rng):
    """Tam-tam : une nuée de partiels qui enfle un instant puis s'éteint lentement."""
    n = samples(duration, sr)
    t = np.arange(n) / sr
    out = np.zeros(n)
    for _ in range(40):
        f = freq * rng.uniform(1, 30)
        if f > sr * 0.45:
            continue
        swell = (1 - np.exp(-t / rng.uniform(0.05, 0.4))) * np.exp(-t / (duration * rng.uniform(0.15, 0.4)))
        out += swell * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) / (1 + f / 800)
    out += np.sin(2 * np.pi * freq * t) * np.exp(-t / (duration * 0.35)) * 1.5
    return out / 6


def brass(freq, duration, sr, rng, attack=0.12, release=0.35):
    """Cor / trompe de guerre : plus on souffle fort, plus le son devient éclatant."""
    env = adsr(duration, sr, attack=attack, decay=0.3, sustain=0.8, release=release)
    n = len(env)
    f = vibrato(freq, n, sr, rate=4.5, depth=0.003, delay=0.4, rng=rng)
    phase = phase_of(f, n, sr)
    out = np.zeros(n)
    for k in range(1, int(sr * 0.45 / freq)):
        brightness = env ** (0.5 + 0.35 * k)  # Les aiguës n'arrivent qu'à pleine puissance.
        out += brightness * np.sin(k * phase) / k ** 0.9
    return out * 0.5


# ---------------------------------------------------------------------------
# Réverbération de cathédrale
# ---------------------------------------------------------------------------

def _fft_convolve(a, b):
    n = len(a) + len(b) - 1
    size = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(a, size) * np.fft.rfft(b, size), size)[:n]


def impulse_response(sr, rng, seconds=3.5, predelay=0.03, damping=0.45, stereo=True):
    """La « réponse » d'une grande salle de pierre : des échos précoces, puis un
    souffle qui décroît. Les aigus s'éteignent plus vite que les graves (damping)."""
    n = samples(seconds * 1.3, sr)
    t = np.arange(n) / sr
    channels = []
    for _ in range(2 if stereo else 1):
        low = fft_filter(noise(n, rng), sr, high=900) * np.exp(-6.9 * t / seconds)
        high = fft_filter(noise(n, rng), sr, low=900) * np.exp(-6.9 * t / (seconds * damping))
        tail = low * 1.4 + high * 0.6
        tail *= 1 - np.exp(-t / 0.04)  # Le souffle s'installe en douceur.
        early = np.zeros(n)
        for _ in range(10):
            delay = rng.uniform(0.008, 0.09)
            early[samples(delay, sr)] += rng.uniform(-1, 1) * (1 - delay * 8)
        ir = np.concatenate([np.zeros(samples(predelay, sr)), tail * 0.06 + early * 0.5])
        channels.append(ir / np.sqrt(np.sum(ir ** 2)))
    return channels


def reverb(signal, sr, rng, wet=0.35, seconds=3.5, predelay=0.03, damping=0.45, dry=True):
    """Ajoute l'écho d'une grande salle. signal : mono (n,) ou stéréo (2, n).
    Le résultat est plus long que le signal (la queue de réverbération).
    dry=False : rend seulement l'écho, sans le son d'origine."""
    irs = impulse_response(sr, rng, seconds, predelay, damping)
    stereo = signal.ndim == 2
    dry_l = signal[0] if stereo else signal
    dry_r = signal[1] if stereo else signal
    wet_l = _fft_convolve(dry_l, irs[0])
    wet_r = _fft_convolve(dry_r, irs[1])
    out = np.zeros((2, len(wet_l)))
    out[0] = wet_l * wet
    out[1] = wet_r * wet
    if dry:
        out[0, :len(dry_l)] += dry_l * (1 - wet * 0.5)
        out[1, :len(dry_r)] += dry_r * (1 - wet * 0.5)
    return out if stereo else out.mean(axis=0) * 1.2


def soft_clip(signal, drive=1.0):
    """Compression douce : écrase gentiment les pics au lieu de saturer."""
    return np.tanh(signal * drive) / np.tanh(drive)
