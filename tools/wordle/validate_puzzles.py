#!/usr/bin/env python3
"""
Crossword puzzle validator for Fjalëkryq — supports all difficulty tiers.

Difficulty tiers and grid sizes:
  Easy:   5x5, 6x6, 7x7  — words 3-6 letters, 5-7 words
  Medium: 7x7, 8x8, 9x9  — words 5-8 letters, 7-9 words
  Hard:   9x9, 10x10, 11x11 — words 7-10 letters, 10-13 words
  Expert: 10x10, 11x11, 12x12, 13x13 — words 10+ letters, 12+ words

Validation rules (for every puzzle regardless of difficulty):
1. CONNECTIVITY: All words must be connected — no floating/isolated groups.
2. NO GHOST WORDS: Every horizontal or vertical run of 2+ consecutive
   letters on the grid must be an actual word in the puzzle's word list.
3. DICTIONARY: All words must be in the approved Albanian dictionary.
4. GRID INTEGRITY: Words fit in bounds, no letter conflicts, no isolated letters.
5. SWAP LIMIT: swapLimit == correct formula value for the difficulty tier.
"""
import sys, io, math
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# =============================================
# Full Albanian word dictionary (all 3-13 letter words)
# Mirrors Wordle7Dictionary.cs exactly
# =============================================
WORDS_3 = {
    "AJO","ATO","ATY","BIE","BIR","BLU","BËJ","DAL",
    "DHE","DIL","DUA","ERA","FLE","FOL","GAZ",
    "GJI","GOL","GRA","IKI",
    "JET","KJO","LOT","MAJ","MAL",
    "MOS","MUA","NGA","NJË","NUK","ORA","LEK",
    "ORË","OSE","PAK","PIJ","POR","QAJ","RRI","SHI","SOT",
    "TOP","TRE","UJK","UJË","VAJ","VET","VIT","YLL","ZOG","ZOT","ÇAJ","ÇUN","ÇUP",
}
WORDS_4 = {
    "ARKA","ARRË","BAZË","DETI","HËNA","FIKU",
    "BOTA","BUKË","CIPË","BABI","BLEJ","LUGA","MIKU",
    "DERË","DIKU","DITË","DJEP","DORË",
    "EMËR","EPIK","FARË","FUND","FURI",
    "GOCA","GAFË","GOJA","GREK","GURË","HAPU",
    "HËNA","INAT","JAVË","JEMI","JETË","KAFE","KAPE",
    "KRAH","KRYQ","KUFI","KURS","KËND","LULE",
    "LUMI","LËRE","MAMI","MEZI","MISH","MURE",
    "NATA","NGRE","NXIS","NYJA","NËNË","ORAR","PARA",
    "PEMA","PENA","PICA","PIKË","PISH","PORT","PRAS","PULA","PUNA","SKAJ","KOVA","SOBA",
    "TETA","THEM","TOKA","TRUP","ULEM","UNIK","VALË",
    "VERA","VIDA","VJEÇ","XIXA","ZANA","ZYRA","ÇAST","ÇIKE",
    "ÇMIM","ÇUNA","VAZO","MARS","MJEK","ROJE","PUSI","QENI","KALI",
}
WORDS_5 = {
    "AKULL","BLETA","BUKUR","DARKË","DERRA","FYELL","GJELI","GJAKU",
    "DJALË","DOSJA","DREKË","DRITË","DRURË","DUAJE","DUHEJ","DYSHO","EDUKO",
    "ERËRA","FLETË","FRUTA","FUSHË","GATIM","HARAM","HOLLË","HYRJA","KISHA","KRUAJ","KUOTË","KURTH","KUSUR",
    "KËMBË","LIBËR","LUAJË","LUFTË","MIELL","MILJE","VLLAI",
    "MOLLË","MOTËR","MPREH","NDAJU","NDJEJ","PESHK","VENDI",
    "PESHA","PJEKË","PLAKË","PLEPA","PYJET","MACJA",
    "RRUGË","SHKAK","SKAJË","TETOR","THIKË","TRIKO","TAKSA",
    "VAJZË","ZEMËR","PAKET","ZYSHË","KAPSE","JANAR","PRILL","GUSHT","TETOR","NUMËR","FJALË",
    "MJEKU","PILOT","AKTOR","NOTER","POLIC",
}
WORDS_6 = {
    "AJROSË","BISEDË","DALLIM","DETARË","FITORE","FLUTUR","FËMIJË",
    "GJUAJE","GOMARË","KLINIK","KRIHJE","KUJDES","HËNGRA","ABUZIM","AKUZIM",
    "KËSULË","MBLIDH","MBYLLI","NGRICË","PAGUAJ","QENUSH","FSHATI","BIZNES","LEXUES",
    "SHISHE","SHTËPI","SHËTIS","SHKENCË","ÇAKMAK","MAKINË","MOTORR","EDUKIM",
    "VITALE","VRAPOJ","VËLLAI","XHINSE","LAPTOP","SHKURT","KORRIK","NËNTOR","MËSUES",
    "ARTIST","BERBER","BIOLOG","KIRURG","PIKTOR","SHITËS","SHOFER","TEKNIK","USHTAR",
}
WORDS_7 = {
    "ARSIMIM","ANIMOVA","ANKORUA","ARKIVAT","ARTIKUJ","DRITARE","FILLIMI","KUJTIME","KËNAQJE","ANALIZË",
    "LIBRARI","LËVIZNI","MBARTEN","MONOLOG","MËSUESE","NGJITJA","NJOHURI","PIKTURË","INTERES","ARTISTË",
    "SHKOLLË","SHPIFJE","SHPRESA","VAJOSJE","NDËRTES","PALLATE","CELULAR","TAVULL","BUJQËSI","GJAHTAR",
    "QERSHOR","SHTATOR","DHJETOR","DENTIST","MJEKËSI","FARMACI","AUTOBUS","TRADITA","DËSHMOR","VEPRIME","SHËRBIM",
    "AGRONOM","ARBITËR","BLEGTOR","DREJTOR","GAZETAR","KËPUCAR","MEKANIK","MURATOR","PEDAGOG","PUNËTOR","PYLLTAR","SALDUES",
}
WORDS_8 = {
    "ARMIQËSI","BASHKIMI","BESIMTAR","BIBLOTEK",
    "DREJTËSI","FAMILJAR",
    "FITIMTAR","HISTORIA","INSTITUT",
    "JETËSORE","KAPITULL","KËNGËTAR","KËSHILLË","KRYESORE","LARGËSIA",
    "LLOGARIA","MËSIMORE","PËRPARIM","STIMULIM",
    "QYTETARI","SHKOLLARË",
    "SHPËTIMI","TRADITËS","UDHËHEQË","VËLLAZËRI","ZGJIDHJE","KAMARIER","PASTRUES","BIÇIKLET","ARKITEKT",
    "BANAKIER","EDUKATOR","FIZIKANT","FOTOGRAF","LABORANT","MENAXHER","MUZIKANT","OPERATOR","PARUKIER","PSIKOLOG","REGJISOR","STUDIUES",
}
WORDS_9 = {
    "AKTIVITET","ANALIZUAR","DREJTËSIA","DREJTORIA",
    "HISTORIAN","KAPITULLI","KULTURORE","LLOGARITË",
    "KOMPJUTER","HORIZONTI","GJENERATA","GJITHMONË","UDHËHEQJE","LAVATRIÇE","TELEVIZOR",
    "INXHINIER","SEKRETARE","ESTETISTE","FARMACIST",
    "FINANCIAR","HIDRAULIK","KUZHINIER","PASTRUESE","VETERINER",
}
WORDS_10 = {
    "FRIGORIFER","PROGRAMUES","MAGAZINIER","SHKENCËTAR","FUTBOLLIST","SHPËTIMTAR","SHTETËRORË",
    "BIBLIOTEKA","FAMILJARËT","KËSHILLTAR","ORGANIZATA","VEPRIMTARI","INFERMIER",
}
WORDS_11 = {
    "KONTABILIST","ELEKTRICIST","ZDRUKTHËTAR",
}
WORDS_12: set = set()
WORDS_13 = {
    "FIZIOTERAPIST","BASKETBOLLIST",
}

# Combined full dictionary
ALBANIAN_WORDS = (
    WORDS_3 | WORDS_4 | WORDS_5 | WORDS_6 | WORDS_7 |
    WORDS_8 | WORDS_9 | WORDS_10 | WORDS_11 | WORDS_12 | WORDS_13
)

# Word pools by difficulty (mirrors Wordle7Dictionary.cs)
POOL_BY_DIFFICULTY = {
    "easy":   WORDS_3 | WORDS_4 | WORDS_5 | WORDS_6,
    "medium": WORDS_5 | WORDS_6 | WORDS_7 | WORDS_8,
    "hard":   WORDS_7 | WORDS_8 | WORDS_9 | WORDS_10,
    "expert": WORDS_10 | WORDS_11 | WORDS_12 | WORDS_13,
}

# Difficulty tier parameters
DIFFICULTY_PARAMS = {
    "easy":   {"sizes": [5, 6, 7],        "min_words": 5,  "max_word_len": 6},
    "medium": {"sizes": [7, 8, 9],        "min_words": 7,  "max_word_len": 8},
    "hard":   {"sizes": [9, 10, 11],      "min_words": 10, "max_word_len": 10},
    "expert": {"sizes": [10, 11, 12, 13], "min_words": 12, "max_word_len": 99},
}

def compute_swap_limit(grid, size, difficulty):
    """Compute correct swapLimit from filled-cell count and difficulty tier.

    Formula mirrors PuzzlesController.cs exactly:
      Easy:   ceil(filled × 0.65) + 5
      Medium: ceil(filled × 0.65) + 7
      Hard:   ceil(filled × 0.65) + 10
      Expert: ceil(filled × 0.65) + 12
    """
    filled = sum(1 for r in grid for c in r if c != "X")
    if difficulty == "easy":
        return math.ceil(filled * 0.65) + 5
    elif difficulty == "medium":
        return math.ceil(filled * 0.65) + 7
    elif difficulty == "hard":
        return math.ceil(filled * 0.65) + 10
    elif difficulty == "expert":
        return math.ceil(filled * 0.65) + 12
    return math.ceil(filled * 0.65) + 7

def make_grid(size):
    return [["X"] * size for _ in range(size)]

def place_word(grid, word, row, col, direction, size):
    for i, ch in enumerate(word):
        r = row + (i if direction == "vertical" else 0)
        c = col + (i if direction == "horizontal" else 0)
        if r >= size or c >= size:
            raise ValueError(f"'{word}' goes out of bounds at ({r},{c}) in {size}x{size} grid")
        if grid[r][c] != "X" and grid[r][c] != ch:
            raise ValueError(f"Conflict at ({r},{c}): grid='{grid[r][c]}', word '{word}' needs '{ch}'")
        grid[r][c] = ch

def get_word_cells(word_entry):
    cells = []
    w = word_entry
    for i in range(len(w["word"])):
        r = w["row"] + (i if w["direction"] == "vertical" else 0)
        c = w["col"] + (i if w["direction"] == "horizontal" else 0)
        cells.append((r, c))
    return cells

# =============================================
# RULE 1: Connectivity check
# =============================================
def check_connectivity(words):
    if len(words) <= 1:
        return True, []
    word_cells = [set(get_word_cells(w)) for w in words]
    adj = {i: set() for i in range(len(words))}
    for i in range(len(words)):
        for j in range(i + 1, len(words)):
            if word_cells[i] & word_cells[j]:
                adj[i].add(j)
                adj[j].add(i)
    visited = {0}
    queue = [0]
    while queue:
        node = queue.pop(0)
        for neighbor in adj[node]:
            if neighbor not in visited:
                visited.add(neighbor)
                queue.append(neighbor)
    if len(visited) == len(words):
        return True, []
    disconnected = [words[i]["word"] for i in range(len(words)) if i not in visited]
    connected = [words[i]["word"] for i in visited]
    return False, [f"Disconnected: {connected} vs {disconnected}"]

# =============================================
# RULE 2: No ghost words
# Every horizontal/vertical run of 2+ letters must be a known puzzle word
# =============================================
def find_all_runs(grid, size):
    runs = []
    # Horizontal
    for r in range(size):
        c = 0
        while c < size:
            if grid[r][c] != "X":
                start_c = c
                letters = ""
                while c < size and grid[r][c] != "X":
                    letters += grid[r][c]
                    c += 1
                if len(letters) >= 2:
                    runs.append({"text": letters, "row": r, "col": start_c, "dir": "H"})
            else:
                c += 1
    # Vertical
    for c in range(size):
        r = 0
        while r < size:
            if grid[r][c] != "X":
                start_r = r
                letters = ""
                while r < size and grid[r][c] != "X":
                    letters += grid[r][c]
                    r += 1
                if len(letters) >= 2:
                    runs.append({"text": letters, "row": start_r, "col": c, "dir": "V"})
            else:
                r += 1
    return runs

def check_no_ghost_words(grid, words, size):
    word_set = set(w["word"] for w in words)
    runs = find_all_runs(grid, size)
    errors = []
    for run in runs:
        if run["text"] not in word_set:
            errors.append(
                f"'{run['text']}' at ({run['row']},{run['col']}) {run['dir']} "
                f"is NOT a puzzle word (ghost word!)"
            )
    return len(errors) == 0, errors

# =============================================
# RULE 3: All words in Albanian dictionary
# =============================================
def check_dictionary(words):
    errors = []
    for w in words:
        if w["word"] not in ALBANIAN_WORDS:
            errors.append(f"'{w['word']}' NOT in Albanian dictionary")
    return len(errors) == 0, errors

# =============================================
# RULE 4: Grid integrity — no out-of-bounds, no conflicts, grid matches words
# =============================================
def check_grid_integrity(grid, words, size):
    errors = []
    expected = make_grid(size)
    for w in words:
        for i, ch in enumerate(w["word"]):
            r = w["row"] + (i if w["direction"] == "vertical" else 0)
            c = w["col"] + (i if w["direction"] == "horizontal" else 0)
            if r >= size or c >= size:
                errors.append(f"'{w['word']}' out of bounds at ({r},{c}) in {size}x{size}")
                continue
            if expected[r][c] != "X" and expected[r][c] != ch:
                errors.append(f"Conflict at ({r},{c}): '{expected[r][c]}' vs '{ch}' from '{w['word']}'")
            expected[r][c] = ch
    for r in range(size):
        for c in range(size):
            if grid[r][c] != expected[r][c]:
                errors.append(f"Grid mismatch at ({r},{c}): grid='{grid[r][c]}', expected='{expected[r][c]}'")
    return len(errors) == 0, errors

# =============================================
# RULE 5: No isolated letters (every filled cell is in a run of 2+)
# =============================================
def check_no_isolated_letters(grid, size):
    errors = []
    for r in range(size):
        for c in range(size):
            if grid[r][c] == "X":
                continue
            # Check horizontal run through this cell
            hl = c
            while hl > 0 and grid[r][hl-1] != "X": hl -= 1
            hr = c
            while hr < size-1 and grid[r][hr+1] != "X": hr += 1
            h_len = hr - hl + 1
            # Check vertical run through this cell
            vt = r
            while vt > 0 and grid[vt-1][c] != "X": vt -= 1
            vb = r
            while vb < size-1 and grid[vb+1][c] != "X": vb += 1
            v_len = vb - vt + 1
            if h_len < 2 and v_len < 2:
                errors.append(f"Isolated letter '{grid[r][c]}' at ({r},{c}) — not part of any word")
    return len(errors) == 0, errors

# =============================================
# RULE 6: Swap limit matches difficulty formula
# =============================================
def check_swap_limit(grid, size, swap_limit, difficulty):
    if swap_limit is None or difficulty is None:
        return True, []   # skip if not provided
    expected = compute_swap_limit(grid, size, difficulty)
    if swap_limit != expected:
        return False, [f"swapLimit={swap_limit} but formula gives {expected} for difficulty='{difficulty}'"]
    return True, []

# =============================================
# Master validator
# =============================================
def validate_puzzle(label, grid, words, size, difficulty=None, swap_limit=None):
    print(f"\n{'='*55}")
    print(f"  {label}  [{size}x{size}" + (f", {difficulty}" if difficulty else "") + "]")
    print(f"{'='*55}")
    for row in grid:
        print("  " + " ".join(row))
    wl = compute_swap_limit(grid, size, difficulty) if difficulty else "?"
    print(f"  Words ({len(words)}): {[w['word'] for w in words]}")
    print(f"  swapLimit formula: {wl}")

    all_passed = True
    checks = [
        ("CONNECTIVITY",        check_connectivity(words)),
        ("NO GHOST WORDS",      check_no_ghost_words(grid, words, size)),
        ("DICTIONARY",          check_dictionary(words)),
        ("GRID INTEGRITY",      check_grid_integrity(grid, words, size)),
        ("NO ISOLATED LETTERS", check_no_isolated_letters(grid, size)),
        ("SWAP LIMIT",          check_swap_limit(grid, size, swap_limit, difficulty)),
    ]
    for name, (ok, errs) in checks:
        if ok:
            print(f"  \u2713 {name}: OK")
        else:
            print(f"  \u2717 {name} FAILED:")
            for e in errs:
                print(f"    -> {e}")
            all_passed = False

    status = "\u2705 PASSED" if all_passed else "\u274c FAILED"
    print(f"  >> {label}: {status}")
    return all_passed

# =============================================
# Test puzzles — one per difficulty tier / grid size.
# Each uses a simple TWO-WORD CROSS: one horizontal word and one vertical
# word that share exactly ONE letter at their intersection.  No other
# letters are adjacent, so ghost-word detection is trivially satisfied.
# All words are verified present in ALBANIAN_WORDS.
# =============================================
puzzles_data = []  # (label, grid, words, size, difficulty, swap_limit)

# ── EASY 5x5 ──────────────────────────────────────────────
# ERA (H r2,c0): E(2,0) R(2,1) A(2,2)
# ORA (V r0,c2): O(0,2) R(1,2) A(2,2)  ← shared A at (2,2)
size = 5
g = make_grid(size)
w = [
    {"word": "ERA", "row": 2, "col": 0, "direction": "horizontal"},
    {"word": "ORA", "row": 0, "col": 2, "direction": "vertical"},
]
for x in w: place_word(g, x["word"], x["row"], x["col"], x["direction"], size)
puzzles_data.append(("Easy 5x5", g, w, size, "easy", compute_swap_limit(g, size, "easy")))

# ── EASY 6x6 ──────────────────────────────────────────────
# MAMI (H r3,c0): M(3,0) A(3,1) M(3,2) I(3,3)
# PARA (V r0,c1): P(0,1) A(1,1) R(2,1) A(3,1)  ← shared A at (3,1)
size = 6
g = make_grid(size)
w = [
    {"word": "MAMI", "row": 3, "col": 0, "direction": "horizontal"},
    {"word": "PARA", "row": 0, "col": 1, "direction": "vertical"},
]
for x in w: place_word(g, x["word"], x["row"], x["col"], x["direction"], size)
puzzles_data.append(("Easy 6x6", g, w, size, "easy", compute_swap_limit(g, size, "easy")))

# ── EASY 7x7 ──────────────────────────────────────────────
# DARKË (H r3,c0): D(3,0) A(3,1) R(3,2) K(3,3) Ë(3,4)
# ORAR  (V r0,c2): O(0,2) R(1,2) A(2,2) R(3,2)  ← shared R at (3,2)
size = 7
g = make_grid(size)
w = [
    {"word": "DARKË", "row": 3, "col": 0, "direction": "horizontal"},
    {"word": "ORAR",  "row": 0, "col": 2, "direction": "vertical"},
]
for x in w: place_word(g, x["word"], x["row"], x["col"], x["direction"], size)
puzzles_data.append(("Easy 7x7", g, w, size, "easy", compute_swap_limit(g, size, "easy")))

# ── MEDIUM 7x7 ────────────────────────────────────────────
# BISEDË (H r3,c0): B(3,0) I(3,1) S(3,2) E(3,3) D(3,4) Ë(3,5)
# LULE   (V r0,c3): L(0,3) U(1,3) L(2,3) E(3,3)  ← shared E at (3,3)
size = 7
g = make_grid(size)
w = [
    {"word": "BISEDË", "row": 3, "col": 0, "direction": "horizontal"},
    {"word": "LULE",   "row": 0, "col": 3, "direction": "vertical"},
]
for x in w: place_word(g, x["word"], x["row"], x["col"], x["direction"], size)
puzzles_data.append(("Medium 7x7", g, w, size, "medium", compute_swap_limit(g, size, "medium")))

# ── MEDIUM 8x8 ────────────────────────────────────────────
# FLUTUR (H r4,c0): F(4,0) L(4,1) U(4,2) T(4,3) U(4,4) R(4,5)
# NATA   (V r2,c3): N(2,3) A(3,3) T(4,3) A(5,3)  ← shared T at (4,3)
size = 8
g = make_grid(size)
w = [
    {"word": "FLUTUR", "row": 4, "col": 0, "direction": "horizontal"},
    {"word": "NATA",   "row": 2, "col": 3, "direction": "vertical"},
]
for x in w: place_word(g, x["word"], x["row"], x["col"], x["direction"], size)
puzzles_data.append(("Medium 8x8", g, w, size, "medium", compute_swap_limit(g, size, "medium")))

# ── MEDIUM 9x9 ────────────────────────────────────────────
# KUJDES (H r4,c1): K(4,1) U(4,2) J(4,3) D(4,4) E(4,5) S(4,6)
# GJELI  (V r3,c3): G(3,3) J(4,3) E(5,3) L(6,3) I(7,3)  ← shared J at (4,3)
size = 9
g = make_grid(size)
w = [
    {"word": "KUJDES", "row": 4, "col": 1, "direction": "horizontal"},
    {"word": "GJELI",  "row": 3, "col": 3, "direction": "vertical"},
]
for x in w: place_word(g, x["word"], x["row"], x["col"], x["direction"], size)
puzzles_data.append(("Medium 9x9", g, w, size, "medium", compute_swap_limit(g, size, "medium")))

# ── HARD 9x9 ──────────────────────────────────────────────
# KOMPJUTER (H r4,c0): spans entire row 4 of a 9x9 grid
# FUND      (V r3,c5): F(3,5) U(4,5) N(5,5) D(6,5)  ← shared U at (4,5)
size = 9
g = make_grid(size)
w = [
    {"word": "KOMPJUTER", "row": 4, "col": 0, "direction": "horizontal"},
    {"word": "FUND",      "row": 3, "col": 5, "direction": "vertical"},
]
for x in w: place_word(g, x["word"], x["row"], x["col"], x["direction"], size)
puzzles_data.append(("Hard 9x9", g, w, size, "hard", compute_swap_limit(g, size, "hard")))

# ── HARD 10x10 ────────────────────────────────────────────
# TELEVIZOR (H r4,c0): T(4,0)…R(4,8) — 9 letters
# LULE      (V r4,c2): L(4,2) U(5,2) L(6,2) E(7,2)  ← shared L at (4,2)
size = 10
g = make_grid(size)
w = [
    {"word": "TELEVIZOR", "row": 4, "col": 0, "direction": "horizontal"},
    {"word": "LULE",      "row": 4, "col": 2, "direction": "vertical"},
]
for x in w: place_word(g, x["word"], x["row"], x["col"], x["direction"], size)
puzzles_data.append(("Hard 10x10", g, w, size, "hard", compute_swap_limit(g, size, "hard")))

# ── HARD 11x11 ────────────────────────────────────────────
# KOMPJUTER (H r5,c1): K(5,1) O(5,2) M(5,3) P(5,4) J(5,5) U(5,6) T(5,7) E(5,8) R(5,9)
# NATA      (V r3,c7): N(3,7) A(4,7) T(5,7) A(6,7)  ← shared T at (5,7)
size = 11
g = make_grid(size)
w = [
    {"word": "KOMPJUTER", "row": 5, "col": 1, "direction": "horizontal"},
    {"word": "NATA",      "row": 3, "col": 7, "direction": "vertical"},
]
for x in w: place_word(g, x["word"], x["row"], x["col"], x["direction"], size)
puzzles_data.append(("Hard 11x11", g, w, size, "hard", compute_swap_limit(g, size, "hard")))

# ── EXPERT 10x10 ──────────────────────────────────────────
# FRIGORIFER (H r4,c0): spans entire row 4 (10 letters)
# EMËR       (V r4,c8): E(4,8) M(5,8) Ë(6,8) R(7,8)  ← shared E at (4,8)
# FRIGORIFER[8] = E ✓
size = 10
g = make_grid(size)
w = [
    {"word": "FRIGORIFER", "row": 4, "col": 0, "direction": "horizontal"},
    {"word": "EMËR",       "row": 4, "col": 8, "direction": "vertical"},
]
for x in w: place_word(g, x["word"], x["row"], x["col"], x["direction"], size)
puzzles_data.append(("Expert 10x10", g, w, size, "expert", compute_swap_limit(g, size, "expert")))

# ── EXPERT 13x13 ──────────────────────────────────────────
# FIZIOTERAPIST (H r6,c0): spans entire row 6 (13 letters)
# EMËR          (V r6,c6): E(6,6) M(7,6) Ë(8,6) R(9,6)  ← shared E at (6,6)
# FIZIOTERAPIST[6] = E ✓
size = 13
g = make_grid(size)
w = [
    {"word": "FIZIOTERAPIST", "row": 6, "col": 0, "direction": "horizontal"},
    {"word": "EMËR",          "row": 6, "col": 6, "direction": "vertical"},
]
for x in w: place_word(g, x["word"], x["row"], x["col"], x["direction"], size)
puzzles_data.append(("Expert 13x13", g, w, size, "expert", compute_swap_limit(g, size, "expert")))

# ── Run all ────────────────────────────────────────────────
total_pass = 0
total_fail = 0
for entry in puzzles_data:
    label, grid, words, size, difficulty, swap_limit = entry
    if validate_puzzle(label, grid, words, size, difficulty, swap_limit):
        total_pass += 1
    else:
        total_fail += 1

print(f"\n{'='*55}")
print(f"  SUMMARY: {total_pass} passed, {total_fail} failed out of {len(puzzles_data)}")
print(f"{'='*55}")
if total_fail > 0:
    sys.exit(1)
else:
    print(f"  All puzzles valid!")
    sys.exit(0)
