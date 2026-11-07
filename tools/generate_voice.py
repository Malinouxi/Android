#!/usr/bin/env python3
"""Fait parler le Seigneur des Profondeurs : une voix grave et caverneuse
pour chaque réplique du médaillon (assets/voice/*.ogg).

Usage (depuis la racine du projet) :
    pip install piper-tts numpy pyworld "setuptools<81"
    python3 tools/generate_voice.py chemin/vers/fr-siwis-medium.onnx

Il faut aussi ffmpeg (avec le filtre « rubberband »). La voix de départ est une
voix de synthèse française libre, Piper « fr-siwis-medium » (moteur Piper : licence
MIT ; voix entraînée sur le corpus SIWIS, licence CC BY 4.0 : à créditer, voir le
README). Les voix d'homme « gilles » et « mls » ont été essayées : leur son est
creux entre 500 et 1600 Hz, donc nasillard une fois grave. On la télécharge à part
(elle n'est pas dans le dépôt) : archive voice-fr-siwis-medium.tar.gz des « releases » v0.0.2 de
github.com/rhasspy/piper.

Les répliques sont lues DIRECTEMENT dans le code du jeu : la liste LINES de
scripts/lord_portrait.gd et les conseils de _advice() dans scripts/main.gd. Ajoute
une phrase là-bas, relance ce script, et le Seigneur la dira. Chaque fichier est
nommé d'après l'empreinte MD5 du texte (12 premiers caractères), que le jeu
recalcule pour retrouver la bonne voix (voir LordPortrait.say).

Comment on fabrique une voix de démon :
  1. la voix de synthèse lit la phrase, lentement ;
  2. le vocodeur WORLD la baisse d'une octave et plus, et agrandit un peu son
     timbre (voyelles encore nettes, pas de nasillement) ;
  3. dessous, la même voix au gosier énorme, puis une troisième une octave
     plus bas, plus discrète (toutes un peu rauques) ;
  4. un grondement (la voix saturée, qui « roule » 38 fois par seconde) ;
  5. un égaliseur (moins de nasillement, plus de netteté) et l'écho d'une caverne.
"""

import hashlib
import os
import re
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gothic_synth as gs  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "voice")
RATE = 22050

## Le conseil qui contient un nombre de secondes ne peut pas être enregistré tel quel :
## la voix dit cette phrase-là à la place (même table dans LordPortrait.VOICE_ALIASES).
ALIASES = {"Des héros arrivent dans": "Des héros arrivent bientôt. Prépare pièges et portes !"}

## Comment prononcer certaines répliques (onomatopées) : texte affiché -> texte lu.
SPOKEN = {
    "Grrr...": "Grrrrr !",
    "Hmm...": "Mmmmh...",
    "Ha ha ha !": "Ah, ah, ah, ah !",
    "Encore !": "Oui, encore !",  # Seul, « Encore » fait dérailler le modèle (nasale au début).
}


def voice_id(text):
    """Le nom du fichier d'une réplique (le jeu fait le même calcul)."""
    return hashlib.md5(text.encode("utf-8")).hexdigest()[:12]


def read_lines():
    """Toutes les répliques du Seigneur, lues dans le code du jeu."""
    strings = re.compile(r'"((?:[^"\\]|\\.)*)"')
    portrait = open(os.path.join(ROOT, "scripts", "lord_portrait.gd"), encoding="utf-8").read()
    block = portrait[portrait.index("const LINES := {"):]
    block = block[:block.index("\n}\n")]
    main = open(os.path.join(ROOT, "scripts", "main.gd"), encoding="utf-8").read()
    advice = main[main.index("func _advice() -> String:"):]
    advice = advice[:advice.index("\n\n\n")]
    lines = []
    for text in strings.findall(block) + strings.findall(advice):
        for prefix, spoken in ALIASES.items():
            if text.startswith(prefix):
                text = spoken
        if "%" not in text and text not in lines:
            lines.append(text)
    return lines


def trim(audio, rate, threshold=0.02, max_gap=0.35):
    """Coupe le silence au début et à la fin, et raccourcit les longs silences au milieu."""
    window = int(0.02 * rate)
    frames = len(audio) // window
    if frames == 0:
        return audio
    level = np.sqrt(np.mean(audio[:frames * window].reshape(frames, window) ** 2, axis=1))
    loud = level > threshold * np.max(level)
    keep = []
    gap = 0
    for i, on in enumerate(loud):
        gap = 0 if on else gap + 1
        if gap * window / rate <= max_gap:
            keep.append(i)
    active = [i for i in keep if loud[i]]
    if not active:
        return audio
    keep = [i for i in keep if active[0] - 2 <= i <= active[-1] + 3]
    return np.concatenate([audio[i * window:(i + 1) * window] for i in keep])


def speak_sentence(voice, phonemes, config, takes=24):
    """Ce vieux modèle déraille parfois (il babille plusieurs secondes) : on fait
    plusieurs prises et on garde celle dont la durée est la plus vraisemblable."""
    rate = voice.config.sample_rate
    sounds = sum(1 for p in phonemes if p.isalpha() or p in "ŋɔɛɑœøəʁʃʒɲ")
    expected = 0.11 * config.length_scale * sounds + 0.15
    best, best_score = None, None
    for _ in range(takes):
        audio = voice.phoneme_ids_to_audio(voice.phonemes_to_ids(phonemes), config)
        audio = trim(np.asarray(audio, dtype=float).ravel(), rate)
        score = abs(np.log((len(audio) / rate) / expected))
        if best_score is None or score < best_score:
            best, best_score = audio, score
    return best


def speak(voice, text):
    """La voix de synthèse lit la phrase (tableau numpy, à la fréquence du modèle)."""
    from piper import SynthesisConfig
    config = SynthesisConfig(length_scale=1.2, noise_scale=0.5, noise_w_scale=0.5)
    pieces = []
    for sentence in voice.phonemize(SPOKEN.get(text, text)):
        # Ce modèle ne connaît pas la marque de nasale « ̃ » : on l'enlève, la voyelle
        # devient orale (« mon » se dit « mo »). Sous la voix de démon, ça reste
        # compréhensible, et c'est bien moins nasillard qu'un « ng » ajouté.
        phonemes = [p for p in sentence if p != "\u0303"]
        audio = speak_sentence(voice, phonemes, config)
        pieces += [audio / (np.max(np.abs(audio)) or 1.0), np.zeros(int(0.12 * voice.config.sample_rate))]
    return np.concatenate(pieces)


def write_wav(path, signal, rate):
    data = (np.clip(signal, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(rate)
        file.writeframes(data.tobytes())


def ffmpeg_filter(signal, rate, filters):
    """Passe le son dans un filtre ffmpeg et le récupère à RATE échantillons/s."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    write_wav(path, signal, rate)
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-af", filters + ",aresample=%d" % RATE,
                          "-f", "f32le", "-ac", "1", "-"], capture_output=True, check=True).stdout
    os.remove(path)
    return np.frombuffer(raw, np.float32).astype(float)


def equalize(signal, bands):
    """Égaliseur : bands = [(fréquence en Hz, gain en dB, largeur en octaves), ...]."""
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1 / RATE) + 1.0
    gain_db = np.zeros_like(freqs)
    for center, gain, width in bands:
        gain_db += gain * np.exp(-(np.log2(freqs / center) / width) ** 2)
    return np.fft.irfft(spectrum * 10 ** (gain_db / 20), len(signal))


def world_shift(speech, rate, pitch, formant, roughness=0.0, rng=None):
    """Change la hauteur ET le timbre séparément, avec le vocodeur WORLD (pyworld) :
    on décompose la voix en hauteur (f0), enveloppe du spectre (le timbre : les
    voyelles) et souffle, puis on recompose. formant < 1 = gosier plus grand.
    roughness : la hauteur tremble au hasard (voix rauque, grondante)."""
    import pyworld
    x = np.ascontiguousarray(speech, dtype=np.float64)
    f0, times = pyworld.harvest(x, rate, f0_floor=60.0, f0_ceil=500.0, frame_period=5.0)
    envelope = pyworld.cheaptrick(x, f0, times, rate)
    aperiodicity = pyworld.d4c(x, f0, times, rate)
    bins = np.arange(envelope.shape[1])
    source = np.clip(bins / formant, 0, bins[-1])
    warped = np.ascontiguousarray([np.interp(source, bins, frame) for frame in envelope])
    new_f0 = f0 * pitch
    if roughness > 0 and rng is not None:
        new_f0 *= 1 + roughness * rng.standard_normal(len(f0))
    out = pyworld.synthesize(new_f0, warped, aperiodicity, rate, frame_period=5.0)
    if rate != RATE:
        out = ffmpeg_filter(out / (np.max(np.abs(out)) or 1.0), rate, "anull")
    return out


def demonize(speech, rate, rng):
    """Transforme la voix de synthèse en voix de démon grave et caverneuse.
    La voix principale est grave mais garde des voyelles nettes (sinon elle
    devient nasillarde) ; la taille du démon vient des couches ajoutées dessous."""
    main = world_shift(speech, rate, pitch=0.45, formant=0.78, roughness=0.02, rng=rng)
    body = world_shift(speech, rate, pitch=0.45, formant=0.62, roughness=0.06, rng=rng)
    sub = world_shift(speech, rate, pitch=0.225, formant=0.7, roughness=0.03, rng=rng)
    n = min(len(main), len(body), len(sub))
    main, body, sub = (x[:n] / (np.max(np.abs(x)) or 1.0) for x in (main, body, sub))
    t = np.arange(n) / RATE
    # Le grondement : la voix saturée, filtrée, qui roule (modulation à 38 Hz).
    growl = np.tanh(body * 4.0)
    growl = gs.fft_filter(growl, RATE, low=90, high=1600) * (0.55 + 0.45 * np.sin(2 * np.pi * 38 * t))
    voice = main + body * 0.35 + sub * 0.3 + growl * 0.12
    voice = gs.fft_filter(voice, RATE, low=55, high=7000)
    voice = equalize(voice, [
        (140, 2.0, 0.7),    # La poitrine.
        (450, -2.0, 0.6),   # Moins « dans une boîte ».
        (2400, 3.0, 0.9),   # La netteté des consonnes.
    ])
    cave = gs.reverb(voice, RATE, rng, wet=0.3, seconds=1.8, predelay=0.025, damping=0.35, tunnel=0.35)
    alive = np.nonzero(np.abs(cave) > np.max(np.abs(cave)) * 0.004)[0]
    cave = cave[:alive[-1] + 1] if len(alive) else cave
    fade = min(len(cave), int(0.05 * RATE))
    cave[-fade:] *= np.linspace(1, 0, fade)
    return cave / (np.max(np.abs(cave)) or 1.0) * 0.9


def save_ogg(name, signal):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    write_wav(path, signal, RATE)
    target = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", path, "-c:a", "libvorbis", "-q:a", "4", target],
                   check=True)
    os.remove(path)
    return target


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    from piper import PiperVoice
    voice = PiperVoice.load(sys.argv[1])
    rng = np.random.default_rng(666)
    os.makedirs(OUT, exist_ok=True)
    lines = read_lines()
    keep = set()
    for text in lines:
        name = voice_id(text)
        keep.add(name + ".ogg")
        sound = demonize(speak(voice, text), voice.config.sample_rate, rng)
        save_ogg(name, sound)
        print("  %s  %4.1f s  %s" % (name, len(sound) / RATE, text))
    # Les voix des répliques qui n'existent plus sont effacées.
    for file in os.listdir(OUT):
        if file.endswith(".ogg") and file not in keep:
            os.remove(os.path.join(OUT, file))
    print("%d répliques enregistrées dans %s" % (len(lines), OUT))


if __name__ == "__main__":
    main()
