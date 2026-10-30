"""Makes the dialogue voice clips with Kokoro TTS (kokoro-onnx).

Input: a list of "voice_id <TAB> line" (dumped from the game: every line every NPC and
helper can say). Output: assets/audio/voice/<voice_id>/<md5 of the line>.ogg
The game plays the clip whose name is the md5 of the line it shows, so a changed line
simply has no clip (it types with the blips) until this is run again.

usage: python3 make_voices.py lines.tsv <project folder> [worker_index worker_count]
"""
import sys, os, re, hashlib, subprocess, tempfile
import soundfile as sf
from kokoro_onnx import Kokoro

MODEL = os.environ.get("KOKORO_DIR", "/tmp/claude-0/kokoro")
# voice id -> (Kokoro voice, speed, pitch factor)
CAST = {
    "merchant": ("am_puck", 1.0, 1.0),       # Momo: cheerful
    "farmer":   ("am_michael", 0.95, 1.0),   # warm and calm
    "teacher":  ("af_heart", 0.95, 1.0),     # clear and kind
    "grandma":  ("bf_emma", 0.9, 0.92),      # soft, a little lower and slower
    "builder":  ("am_fenrir", 0.95, 1.0),    # Bob: strong
    "painter":  ("am_liam", 1.0, 1.0),       # Pablo: friendly young guy
}
LETTERS = {"A": "ay", "B": "bee", "C": "see", "D": "dee", "E": "ee", "F": "eff", "G": "jee", "H": "aitch",
    "I": "eye", "J": "jay", "K": "kay", "L": "el", "M": "em", "N": "en", "O": "oh", "P": "pee", "Q": "cue",
    "R": "ar", "S": "ess", "T": "tee", "U": "you", "V": "vee", "W": "double you", "X": "ex", "Y": "why", "Z": "zee"}

def spoken(voice, text):
    """What the TTS reads (the screen text stays the same)."""
    t = text.replace(" + ", " plus ").replace(" = ", " equals ")
    t = re.sub(r"\bletter ([A-Za-z])\b", lambda m: "letter " + LETTERS[m.group(1).upper()], t)
    if voice == "teacher":
        t = re.sub(r"\b([A-Za-z])\b(?!')", lambda m: LETTERS[m.group(1).upper()], t)
    t = t.replace("Momo", "Mo-mo").replace("Kiko", "Kee-ko").replace("Nena", "Neh-nah")
    return t

def main():
    rows = []
    for line in open(sys.argv[1], encoding="utf-8"):
        line = line.rstrip("\n")
        if "\t" in line:
            v, text = line.split("\t", 1)
            rows.append((v, text))
    root = sys.argv[2]
    wi, wc = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (0, 1)
    k = Kokoro(os.path.join(MODEL, "kokoro-v1.0.onnx"), os.path.join(MODEL, "voices-v1.0.bin"))
    for n, (v, text) in enumerate(rows):
        if n % wc != wi:
            continue
        out = os.path.join(root, "assets/audio/voice", v, hashlib.md5(text.encode("utf-8")).hexdigest() + ".ogg")
        if os.path.exists(out):
            continue
        os.makedirs(os.path.dirname(out), exist_ok=True)
        name, speed, pitch = CAST[v]
        samples, sr = k.create(spoken(v, text), voice=name, speed=speed, lang="en-us")
        with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
            sf.write(tmp.name, samples, sr)
            af = "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,apad=pad_dur=0.1"
            if pitch != 1.0:
                af = "asetrate=%d,aresample=%d,atempo=%.4f," % (sr * pitch, sr, 1.0 / pitch) + af
            af += ",loudnorm=I=-18:TP=-2"
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-af", af, "-ar", "24000", "-ac", "1",
                            "-c:a", "libvorbis", "-q:a", "3", out], check=True)
        print(v, text, flush=True)

main()
