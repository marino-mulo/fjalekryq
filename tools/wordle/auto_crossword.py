#!/usr/bin/env python3
"""
Automated crossword generator for Fjalëkryq (variable grid sizes 7-10).
Uses backtracking search to place words while respecting ALL rules:
1. Every H/V run of 2+ letters must be a word in the puzzle
2. All words must be connected
3. No placement conflicts

This version targets MANY words per puzzle for engaging gameplay.
"""
import sys, io, random
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# =============================================
# Albanian word dictionary (grouped by length)
# Expanded for denser puzzles
# =============================================
WORDS_3 = ["ABE", "AFI", "AGË", "AJO", "ALO", "AME", "ANE", "ANO",
            "ARI", "ATH", "ATO", "ATY", "BEC", "BIE", "BIR", "BLE",
            "BLU", "BOÇ", "BRE", "BUT", "BUZ", "BYN", "BYR", "BËJ",
            "CAK", "CEN", "CEP", "COK", "CUK", "CËR", "DEM", "DET",
            "DHE", "DIM", "DOL", "DOÇ", "DRA", "DUA", "DUF", "EGO",
            "EHI", "EHË", "ELB", "ENE", "ENG", "EPË", "ERA", "ESE",
            "FIG", "FIK", "FLE", "FOL", "FYL", "FËT", "GAL", "GAZ",
            "GEL", "GJI", "GJU", "GJË", "GOL", "GRA", "GYP", "HAJ",
            "HAS", "HON", "HOQ", "HUP", "IKE", "IKI", "IKS", "IKË",
            "IMA", "IMI", "IRE", "ISH", "JAR", "JEN", "JET", "KGB",
            "KIC", "KJO", "KOI", "KOT", "KUM", "KUQ", "KYL", "LAJ",
            "LEU", "LIE", "LIK", "LIV", "LOT", "LUG", "LYR", "LYÇ",
            "LËR", "MAJ", "MAL", "MAÇ", "MES", "MIK", "MIN", "MIT",
            "MIX", "MOS", "MUA", "NEF", "NGA", "NIS", "NJË", "NUK",
            "NUR", "OJË", "OMI", "ORA", "ORË", "OSE", "PAH", "PAK",
            "PAÇ", "PIK", "POR", "PUS", "QAJ", "QAN", "QEL", "QEN",
            "QER", "QET", "REÇ", "RIS", "ROB", "ROJ", "RRO", "RYS",
            "SAD", "SAJ", "SAP", "SEÇ", "SHI", "SOJ", "SOT", "SYR",
            "TAN", "TEL", "TEN", "THI", "TIJ", "TIM", "TOP", "TOZ",
            "TRE", "TUB", "TUK", "TUL", "TYF", "UJK", "UJË", "ULË",
            "URI", "USH", "USI", "UTI", "VAJ", "VAU", "VEG", "VEL",
            "VET", "VEU", "VIL", "VIR", "VIS", "VIT", "XËC", "YEJ",
            "YEU", "YLL", "YRT", "ZIA", "ZIM", "ZOG", "ZOT", "ÇAD",
            "ÇAF", "ÇAJ", "ÇAL", "ÇAM", "ÇAP", "ÇAU", "ÇIP", "ÇOI",
            "ÇON", "ÇOR", "ÇUK", "ÇUN", "ÇUP", "ÇUÇ", "ËHË", "ËMË"]
WORDS_4 = ["ABEJ", "ADET", "AGON", "AHJA", "AJON", "ALEM", "ALLC", "ARAR",
            "ARKË", "ARRË", "ASPO", "BAGE", "BAHE", "BAMË", "BARË", "BASK",
            "BASË", "BATO", "BAZA", "BAZE", "BAZO", "BEHA", "BEHE", "BEND",
            "BETA", "BETË", "BEUT", "BIBA", "BIGO", "BILË", "BIRR", "BIRË",
            "BLUZ", "BOER", "BONI", "BOTË", "BUFE", "BUJA", "BUKË", "BULI",
            "BUMI", "BUNE", "BYPE", "BËNA", "CAKË", "CIME", "CIPË", "COHA",
            "CUBË", "CURR", "CYTI", "DEDË", "DERË", "DIKU", "DINI", "DISK",
            "DITË", "DJEP", "DORE", "DORË", "DREN", "DRES", "DUAJ", "EHËT",
            "EMRA", "EMËR", "EPIK", "EPIN", "EPKE", "ETAN", "ETHU", "ETËN",
            "FARO", "FARË", "FEJE", "FEKS", "FICE", "FILA", "FLIQ", "FRAT",
            "FRUG", "FUGË", "FUND", "FURI", "FUTU", "FYEJ", "FYER", "FYTE",
            "GAFË", "GARO", "GAUS", "GAZO", "GEGE", "GJAK", "GJEL", "GOJA",
            "GOJE", "GREC", "GREK", "GREN", "GURË", "HAGË", "HAPU", "HIMN",
            "HIQU", "HITI", "HUNJ", "HYKE", "HËNA", "HËNË", "IBRI", "IKJA",
            "IMUN", "INAT", "IRËT", "JAVË", "JEMI", "JEPE", "JETË", "KAFË",
            "KAPE", "KEPI", "KIVE", "KIZE", "KOHE", "KOVE", "KRAH", "KRYQ",
            "KUFI", "KULE", "KUMT", "KUPE", "KURS", "KUSI", "KËND", "LAKË",
            "LANË", "LARË", "LASË", "LATA", "LATE", "LEPE", "LIJE", "LISË",
            "LOCE", "LORD", "LUBI", "LULE", "LULË", "LUMË", "LURA", "LUTA",
            "LYPU", "LËRE", "MAMI", "MARA", "MARE", "MATU", "MAZI", "MEJE",
            "META", "METE", "METI", "MEZI", "MIHE", "MIRË", "MISH", "MORË",
            "MUNK", "MURE", "MËSA", "NAPË", "NATË", "NDOQ", "NETO", "NGIT",
            "NGRE", "NIME", "NOLI", "NURE", "NURË", "NXIS", "NYJA", "NYJË",
            "NËNË", "OKJE", "OKËR", "ORAR", "ORUM", "PARA", "PARI", "PATA",
            "PEJË", "PEMA", "PENA", "PICA", "PIKË", "PILL", "PILO", "PISA",
            "PISH", "PLIM", "PLIQ", "PORE", "PORT", "PRAS", "PULS", "PULË",
            "PUNË", "PURE", "QAPO", "QEMË", "QEVE", "QOSH", "QYQO", "QYRI",
            "RAJT", "RATA", "REGJ", "RETË", "RIAL", "RIGA", "RIKA", "RIUN",
            "RIVE", "ROGO", "ROLA", "ROMI", "RUTE", "RËRË", "SAKË", "SHAP",
            "SHOI", "SHUK", "SIDË", "SKAJ", "SOJE", "SOLO", "SOPI", "SOSH",
            "SPEC", "STIS", "TAKË", "TARO", "TATË", "TEHE", "TERK", "TETA",
            "THEM", "TOKA", "TOKË", "TRES", "TRUP", "TUFO", "TUGE", "TUJA",
            "TUJË", "ULEM", "UNIK", "UNZA", "UNZË", "USIA", "VALË", "VEGË",
            "VERS", "VERË", "VIDË", "VJEÇ", "VOLA", "VONA", "VRAH", "VUNO",
            "VUTH", "VUTË", "VUVE", "VËNI", "VËRE", "VËRË", "XIXA", "YEKA",
            "YJTË", "ZALI", "ZAME", "ZANË", "ZBIM", "ZHYE", "ZUMË", "ZYRA",
            "ZËNE", "ÇAJA", "ÇAST", "ÇIKE", "ÇIKU", "ÇMIM", "ÇMON", "ÇOMË",
            "ÇONA", "ÇUAM", "ÇUAN", "ËNJT"]
WORDS_5 = ["ABATË", "AEROB", "AGAVE", "AKUJT", "ALLAT", "AULAT", "AVROM", "BABAI",
            "BAKËS", "BEJÇE", "BERËZ", "BETEC", "BICES", "BIMËS", "BITME", "BIXHË",
            "BLETË", "BORAK", "BUKUR", "BËKAM", "BËZAJ", "CALIK", "CENSE", "CIKMA",
            "DARKË", "DERRA", "DJALI", "DJATË", "DJEGA", "DOSJA", "DOÇKË", "DREKË",
            "DRITË", "DRURË", "DUAJE", "DUDUM", "DUHEJ", "DYSHO", "EDLIR", "EDUKO",
            "EGJRA", "ERËRA", "ETURE", "EUNUK", "FANIT", "FAROR", "FEJON", "FLETË",
            "FRETH", "FRUTË", "FSHAT", "FURMI", "FUSHË", "FYERA", "FËRGO", "GARBË",
            "GATIM", "GOJCË", "GREKË", "GRIHO", "GRIMA", "HANIN", "HARAM", "HASEJ",
            "HEQËS", "HILET", "HOLLË", "HYRJA", "HYRËN", "HËNËZ", "IMNIT", "KABOT",
            "KADET", "KAPUA", "KISHA", "KISHE", "KONES", "KOSAR", "KOVËN", "KRELO",
            "KRUAN", "KUOTË", "KUQIN", "KURTH", "KUSUR", "KYLKA", "KYLËT", "KËMBE",
            "LAKRE", "LATON", "LEFSH", "LEHIM", "LENTA", "LIBËR", "LIGAT", "LIJUA",
            "LOCEN", "LOZKA", "LUAJË", "LUFTE", "LULOI", "LUMËT", "LURKË", "LUTKA",
            "LYRON", "LËMAR", "MAJMI", "MAJTA", "MELTE", "MESTE", "MIELL", "MIJAT",
            "MILJE", "MIOZË", "MJEKË", "MOLLË", "MOTËR", "MPREH", "MURON", "MËLCO",
            "MËNGO", "MËSYJ", "NDAJU", "NDJEJ", "NGECU", "NGELU", "NIMFA", "NIOBË",
            "NXËNË", "NËMJA", "OKRËS", "ORKAN", "PENOJ", "PESHK", "PESHO", "PIKJE",
            "PIQTE", "PIRET", "PITOK", "PLAKË", "PLEPA", "PLOTE", "PRIJU", "PRURE",
            "PUROI", "PYJET", "PYKËL", "QAFET", "QASAT", "QEBET", "QEHËN", "QENIN",
            "QESHU", "QUMËS", "RESIT", "RREMË", "RRUGË", "SAZET", "SHKAK", "SHUTE",
            "SIDAT", "SIMON", "SIVËT", "SKOTË", "STISI", "TAKËM", "TERKE", "TETOR",
            "THAKE", "THIKË", "TIFOS", "TIRAN", "TOKËS", "TRAZE", "TRESË", "TRIKO",
            "TROKE", "TROMB", "TUTEJ", "TUTRA", "TËNGË", "URATO", "VAJZË", "VALOJ",
            "VATAN", "VAZET", "VELJE", "VOLIA", "XHINS", "YEJNË", "ZBETË", "ZEMËR",
            "ZGAQU", "ZJEVE", "ZONIT", "ZUSHË", "ÇEÇES", "ÇEÇJA", "ÇITAR", "ÇUDOJ"]
WORDS_6 = ["AJRISË", "AJROSË", "ARTRIT", "BABAIT", "BARKOR", "BISEDË", "BORAKS", "BRIMOJ",
            "CANGËL", "CENGËS", "CËRRLA", "DALLIM", "DEJÇËS", "DETARË", "DIMËRO", "DRUSIM",
            "ERORET", "FITORE", "FLUTUR", "FURRON", "FËMIJË", "GAMËRR", "GJUAJE", "GJUASH",
            "GOMARË", "GRANAT", "GUITNI", "HAHENI", "HATANË", "HIPËSI", "KAFENE", "KALLAJ",
            "KAPOLE", "KLINIK", "KORAQI", "KORBËN", "KRIHJE", "KRIPJE", "KRODHI", "KUJDES",
            "KËLLAS", "KËRRLA", "KËSULË", "LAPSNI", "LEDHON", "LEHTËT", "LESHEJ", "LIBROR",
            "LLUMRA", "LËREJE", "LËVRIM", "MAHITE", "MARANA", "MBLIDH", "MBYLLI", "MOBILO",
            "MËRTIK", "MËSUËS", "NDEZÇE", "NDJEMA", "NDRYJË", "NGRICË", "NISMËS", "NJEHEN",
            "NJEHSH", "PAGUNI", "PREKKE", "PRITME", "PROKËS", "PUSHEM", "PUTANA", "PUTHMË",
            "QENUSH", "QINGËL", "QULLTO", "RENOME", "RESHME", "RETINË", "RINJSH", "RISILL",
            "RRASTE", "RRENIT", "RURALË", "SANOHU", "SEKËND", "SEMITE", "SENEVE", "SHARZH",
            "SHISHË", "SHPINO", "SHPURI", "SHTËPI", "SHUPKË", "SHURIT", "SHUTOI", "SHËTIS",
            "SORGUM", "SPIRUQ", "SQAQEM", "STIMUL", "TAKSIM", "TALLIM", "TAVANO", "THEKEN",
            "TRANSE", "TUFËSE", "TYMTËS", "UJITEN", "URINOJ", "VENDET", "VIKEND", "VITALE",
            "VJETËT", "VRAPOJ", "VRUGOJ", "VËLLAI", "ZBUTIM", "ZELOTI", "ÇIKËTO", "ÇIKËZE"]
WORDS_7 = ["ANIMOVA", "ANKORUA", "ARKEBUZ", "ARKIVAT", "ARTIKUJ", "BAKËROS", "BAZALJA", "BEGATTË",
            "BOSTITË", "BURONJE", "BUZORËT", "DRETHIT", "DRITARE", "DËBOJNË", "ETIKETE", "FILLIMI",
            "FSHAFTË", "GISHTEN", "GLIKOSH", "GROSHËZ", "HALVETI", "HESHTKA", "HORMOVA", "IMËTAKE",
            "KANDISU", "KUJTIME", "KËMBËSH", "KËNAQJE", "LAKËROJ", "LEZETAR", "LIBRARI", "LËVIZKE",
            "LËVIZNI", "MBARTEN", "MONOLOG", "MURGJAN", "MËSUESE", "NEMITUR", "NGJITJA", "NGUFATA",
            "NGËRMOJ", "PIKTURË", "PRARUAN", "PRIVOJI", "QEPËRON", "RIVIHEM", "SHAGESH", "SHALAQE",
            "SHKOLLË", "SHPIFJA", "SHPRESA", "SHTALKË", "SHTERËT", "SHTËPIA", "SHYTIMI", "VASALJA",
            "VENDUAM", "VERBËTE", "VIJOSNI", "XËGITIN"]

ALL_WORDS_EASY   = WORDS_3 + WORDS_4 + WORDS_5 + WORDS_6        # Easy  3-6 letters
ALL_WORDS_MEDIUM = WORDS_5 + WORDS_6 + WORDS_7                   # Medium 5-7 letters
ALL_WORDS_HARD   = WORDS_6 + WORDS_7                             # Hard  6-7 letters (extend with 8-10 when available)
ALL_WORDS_EXPERT = WORDS_7                                        # Expert 7+ letters (extend with 8-13 when available)


def make_grid(size):
    return [["X"] * size for _ in range(size)]

def copy_grid(g):
    return [r[:] for r in g]

def show(g):
    for r in g:
        print("  " + " ".join(r))

def find_all_runs(grid, size):
    """Find every H and V run of 2+ consecutive letters."""
    runs = []
    for r in range(size):
        c = 0
        while c < size:
            if grid[r][c] != "X":
                s = ""
                while c < size and grid[r][c] != "X":
                    s += grid[r][c]
                    c += 1
                if len(s) >= 2:
                    runs.append(s)
            else:
                c += 1
    for c in range(size):
        r = 0
        while r < size:
            if grid[r][c] != "X":
                s = ""
                while r < size and grid[r][c] != "X":
                    s += grid[r][c]
                    r += 1
                if len(s) >= 2:
                    runs.append(s)
            else:
                r += 1
    return runs

def is_valid_after_placement(grid, word_set, size):
    for run in find_all_runs(grid, size):
        if run not in word_set:
            return False
    return True

def try_place(grid, word, row, col, direction, size):
    g = copy_grid(grid)
    for i, ch in enumerate(word):
        r = row + (i if direction == "vertical" else 0)
        c = col + (i if direction == "horizontal" else 0)
        if r >= size or c >= size:
            return None
        if g[r][c] != "X" and g[r][c] != ch:
            return None
        g[r][c] = ch
    return g

def word_shares_cell(grid, word, row, col, direction, size):
    for i in range(len(word)):
        r = row + (i if direction == "vertical" else 0)
        c = col + (i if direction == "horizontal" else 0)
        if r < size and c < size and grid[r][c] != "X":
            return True
    return False

def count_letters(grid):
    return sum(1 for r in grid for c in r if c != "X")

def check_connectivity(placed_words):
    if len(placed_words) <= 1:
        return True
    cells_per_word = []
    for w, r, c, d in placed_words:
        cells = set()
        for i in range(len(w)):
            rr = r + (i if d == "vertical" else 0)
            cc = c + (i if d == "horizontal" else 0)
            cells.add((rr, cc))
        cells_per_word.append(cells)
    adj = {i: set() for i in range(len(placed_words))}
    for i in range(len(placed_words)):
        for j in range(i+1, len(placed_words)):
            if cells_per_word[i] & cells_per_word[j]:
                adj[i].add(j)
                adj[j].add(i)
    visited = {0}
    queue = [0]
    while queue:
        n = queue.pop(0)
        for nb in adj[n]:
            if nb not in visited:
                visited.add(nb)
                queue.append(nb)
    return len(visited) == len(placed_words)

def find_all_placements(grid, word, word_set, size):
    placements = []
    new_ws = word_set | {word}
    for direction in ["horizontal", "vertical"]:
        max_r = size - (len(word) if direction == "vertical" else 1)
        max_c = size - (len(word) if direction == "horizontal" else 1)
        for r in range(max_r + 1):
            for c in range(max_c + 1):
                new_grid = try_place(grid, word, r, c, direction, size)
                if new_grid is None:
                    continue
                if count_letters(grid) > 0 and not word_shares_cell(grid, word, r, c, direction, size):
                    continue
                if is_valid_after_placement(new_grid, new_ws, size):
                    placements.append((r, c, direction, new_grid))
    return placements

def generate_puzzle(word_pool, size, min_words=5, min_letters=18, max_attempts=50):
    """Generate a valid crossword puzzle using backtracking.
    Optimized for maximum word count."""
    best = None
    best_score = 0

    for attempt in range(max_attempts):
        random.shuffle(word_pool)
        grid = make_grid(size)
        word_set = set()
        placed = []

        # Place first word in center area
        first = word_pool[0]
        r = size // 2
        c = max(0, (size - len(first)) // 2)
        grid = try_place(grid, first, r, c, "horizontal", size)
        if grid is None:
            continue
        word_set.add(first)
        placed.append((first, r, c, "horizontal"))

        # Try to add remaining words — try ALL of them multiple times with different orderings
        remaining = [w for w in word_pool[1:] if w not in word_set]

        # Multiple passes to try to fit more words
        for pass_num in range(3):
            random.shuffle(remaining)
            still_remaining = []
            for word in remaining:
                if word in word_set:
                    continue
                if len(word) > size:
                    still_remaining.append(word)
                    continue
                placements = find_all_placements(grid, word, word_set, size)
                if placements:
                    r, c, d, new_grid = random.choice(placements)
                    grid = new_grid
                    word_set.add(word)
                    placed.append((word, r, c, d))
                else:
                    still_remaining.append(word)
            remaining = still_remaining

        n_words = len(placed)
        n_letters = count_letters(grid)
        if n_words >= min_words and n_letters >= min_letters and check_connectivity(placed):
            score = n_words * 10 + n_letters
            if score > best_score:
                best_score = score
                best = (grid, placed)
                # Keep searching for better results — only stop early if we get a really high count
                if n_words >= min_words + 4:
                    break

    return best

def clean_placed_words(grid, placed, size):
    """Remove words that don't match actual grid runs.
    When a shorter word is extended by a longer one, the shorter word's run
    no longer exists — only the longer run is valid."""
    # Build set of actual runs with their positions
    actual_runs = set()
    for r_idx in range(size):
        c = 0
        while c < size:
            if grid[r_idx][c] != "X":
                start = c; s = ""
                while c < size and grid[r_idx][c] != "X":
                    s += grid[r_idx][c]; c += 1
                if len(s) >= 2:
                    actual_runs.add((s, r_idx, start, "horizontal"))
            else:
                c += 1
    for c_idx in range(size):
        r = 0
        while r < size:
            if grid[r][c_idx] != "X":
                start = r; s = ""
                while r < size and grid[r][c_idx] != "X":
                    s += grid[r][c_idx]; r += 1
                if len(s) >= 2:
                    actual_runs.add((s, start, c_idx, "vertical"))
            else:
                r += 1

    # Keep only placed words that match an actual run exactly
    clean = []
    used_runs = set()
    for word, row, col, direction in placed:
        key = (word, row, col, direction)
        if key in actual_runs and key not in used_runs:
            clean.append((word, row, col, direction))
            used_runs.add(key)
    return clean

def format_puzzle(grid, placed, size):
    placed = clean_placed_words(grid, placed, size)
    words = []
    for word, row, col, direction in placed:
        words.append({"word": word, "row": row, "col": col, "direction": direction})
    return grid, words

import math

def compute_swap_limit(words, difficulty):
    """Compute swap limit based on sum of all word lengths and difficulty tier."""
    total = sum(len(w["word"]) for w in words)
    if difficulty == "easy":
        return math.ceil(total * 1.6)
    elif difficulty == "medium":
        return math.ceil(total * 1.5) + 5
    elif difficulty == "hard":
        return math.ceil(total * 1.4) + 10
    elif difficulty == "expert":
        return math.ceil(total * 1.2) + 15
    return math.ceil(total * 1.5) + 5

# =============================================
# Generate puzzles by difficulty tier
# Easy:   5x5/6x6/7x7, min words 5-7, word lengths 3-6
# Medium: 7x7/8x8/9x9, min words 7-9, word lengths 5-8
# Hard:   9x9/10x10/11x11, min words 10-13, word lengths 7-10
# Expert: 10x10/11x11/12x12/13x13, min words 12+, word lengths 10+
# =============================================
DIFFICULTY_CONFIGS = [
    {"name": "Easy (5x5)",    "difficulty": "easy",   "size": 5,  "min_words": 5,  "min_letters": 12, "attempts": 600,  "pool": "easy"},
    {"name": "Easy (6x6)",    "difficulty": "easy",   "size": 6,  "min_words": 6,  "min_letters": 15, "attempts": 700,  "pool": "easy"},
    {"name": "Easy (7x7)",    "difficulty": "easy",   "size": 7,  "min_words": 7,  "min_letters": 18, "attempts": 800,  "pool": "easy"},
    {"name": "Medium (7x7)",  "difficulty": "medium", "size": 7,  "min_words": 7,  "min_letters": 20, "attempts": 800,  "pool": "medium"},
    {"name": "Medium (8x8)",  "difficulty": "medium", "size": 8,  "min_words": 8,  "min_letters": 25, "attempts": 1000, "pool": "medium"},
    {"name": "Medium (9x9)",  "difficulty": "medium", "size": 9,  "min_words": 9,  "min_letters": 30, "attempts": 1200, "pool": "medium"},
    {"name": "Hard (9x9)",    "difficulty": "hard",   "size": 9,  "min_words": 10, "min_letters": 32, "attempts": 1200, "pool": "hard"},
    {"name": "Hard (10x10)",  "difficulty": "hard",   "size": 10, "min_words": 11, "min_letters": 38, "attempts": 1500, "pool": "hard"},
    {"name": "Hard (11x11)",  "difficulty": "hard",   "size": 11, "min_words": 13, "min_letters": 45, "attempts": 1500, "pool": "hard"},
    {"name": "Expert (10x10)","difficulty": "expert", "size": 10, "min_words": 12, "min_letters": 40, "attempts": 1500, "pool": "expert"},
    {"name": "Expert (11x11)","difficulty": "expert", "size": 11, "min_words": 12, "min_letters": 45, "attempts": 1500, "pool": "expert"},
    {"name": "Expert (12x12)","difficulty": "expert", "size": 12, "min_words": 12, "min_letters": 50, "attempts": 2000, "pool": "expert"},
    {"name": "Expert (13x13)","difficulty": "expert", "size": 13, "min_words": 12, "min_letters": 55, "attempts": 2000, "pool": "expert"},
]

POOL_MAP = {
    "easy":   ALL_WORDS_EASY,
    "medium": ALL_WORDS_MEDIUM,
    "hard":   ALL_WORDS_HARD,
    "expert": ALL_WORDS_EXPERT,
}

import sys
# Accept optional difficulty argument: python auto_crossword.py easy
target_difficulty = sys.argv[1] if len(sys.argv) > 1 else None
configs_to_run = [c for c in DIFFICULTY_CONFIGS if target_difficulty is None or c["difficulty"] == target_difficulty]

random.seed(99)

all_puzzles = []
for i, cfg in enumerate(configs_to_run):
    print(f"\n{'='*55}")
    print(f"  Generating {cfg['name']}...")
    print(f"{'='*55}")

    pool = POOL_MAP[cfg["pool"]][:]
    size = cfg["size"]
    result = generate_puzzle(pool, size, cfg["min_words"], cfg["min_letters"], cfg["attempts"])

    if result:
        grid, placed = result
        grid, words = format_puzzle(grid, placed, size)
        n_letters = count_letters(grid)
        swap_limit = compute_swap_limit(words, cfg["difficulty"])
        print(f"  ✓ {len(words)} words, {n_letters} letters (grid {size}x{size}), swapLimit={swap_limit}")
        show(grid)
        print(f"  Words: {[w['word'] for w in words]}")

        word_set = set(w["word"] for w in words)
        runs = find_all_runs(grid, size)
        ghosts = [r for r in runs if r not in word_set]
        if ghosts:
            print(f"  ✗ GHOST WORDS: {ghosts}")
        else:
            print(f"  ✓ No ghost words")

        if check_connectivity([(w["word"], w["row"], w["col"], w["direction"]) for w in words]):
            print(f"  ✓ All connected")
        else:
            print(f"  ✗ NOT connected")

        all_puzzles.append((cfg["name"], grid, words, size, swap_limit))
    else:
        print(f"  ✗ Failed! Trying with lower requirements...")
        result = generate_puzzle(pool, size, max(3, cfg["min_words"]-3), max(10, cfg["min_letters"]-8), cfg["attempts"]*2)
        if result:
            grid, placed = result
            grid, words = format_puzzle(grid, placed, size)
            swap_limit = compute_swap_limit(words, cfg["difficulty"])
            print(f"  ✓ (reduced) {len(words)} words, {count_letters(grid)} letters, swapLimit={swap_limit}")
            show(grid)
            print(f"  Words: {[w['word'] for w in words]}")
            all_puzzles.append((cfg["name"], grid, words, size, swap_limit))
        else:
            print(f"  ✗✗ Complete failure for {cfg['name']}")

# =============================================
# Output summary
# =============================================
print(f"\n\n{'='*55}")
print(f"  GENERATED {len(all_puzzles)}/{len(configs_to_run)} PUZZLES")
print(f"{'='*55}\n")
for label, grid, words, size, swap_limit in all_puzzles:
    wl = [w["word"] for w in words]
    print(f"  {label} ({size}x{size}): {', '.join(wl)} | swapLimit={swap_limit}")
