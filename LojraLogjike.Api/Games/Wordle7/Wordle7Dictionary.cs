namespace LojraLogjike.Api.Games.Wordle7;

/// <summary>
/// Curated Albanian word dictionary for crossword puzzle generation.
/// Words grouped by length (3-7 letters). Total: ~880 words.
/// </summary>
public static class Wordle7Dictionary
{
    private static readonly string[] Words3 =
    [
        "ABE", "AFI", "AGË", "AJO", "ALO", "AME", "ANE", "ANO",
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
        "ÇON", "ÇOR", "ÇUK", "ÇUN", "ÇUP", "ÇUÇ", "ËHË", "ËMË"
    ];

    private static readonly string[] Words4 =
    [
        "ABEJ", "ADET", "AGON", "AHJA", "AJON", "ALEM", "ALLC", "ARAR",
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
        "ÇONA", "ÇUAM", "ÇUAN", "ËNJT"
    ];

    private static readonly string[] Words5 =
    [
        "ABATË", "AEROB", "AGAVE", "AKUJT", "ALLAT", "AULAT", "AVROM", "BABAI",
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
        "ZGAQU", "ZJEVE", "ZONIT", "ZUSHË", "ÇEÇES", "ÇEÇJA", "ÇITAR", "ÇUDOJ"
    ];

    private static readonly string[] Words6 =
    [
        "AJRISË", "AJROSË", "ARTRIT", "BABAIT", "BARKOR", "BISEDË", "BORAKS", "BRIMOJ",
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
        "VJETËT", "VRAPOJ", "VRUGOJ", "VËLLAI", "ZBUTIM", "ZELOTI", "ÇIKËTO", "ÇIKËZE"
    ];

    private static readonly string[] Words7 =
    [
        "ANIMOVA", "ANKORUA", "ARKEBUZ", "ARKIVAT", "ARTIKUJ", "BAKËROS", "BAZALJA", "BEGATTË",
        "BOSTITË", "BURONJE", "BUZORËT", "DRETHIT", "DRITARE", "DËBOJNË", "ETIKETE", "FILLIMI",
        "FSHAFTË", "GISHTEN", "GLIKOSH", "GROSHËZ", "HALVETI", "HESHTKA", "HORMOVA", "IMËTAKE",
        "KANDISU", "KUJTIME", "KËMBËSH", "KËNAQJE", "LAKËROJ", "LEZETAR", "LIBRARI", "LËVIZKE",
        "LËVIZNI", "MBARTEN", "MONOLOG", "MURGJAN", "MËSUESE", "NEMITUR", "NGJITJA", "NGUFATA",
        "NGËRMOJ", "PIKTURË", "PRARUAN", "PRIVOJI", "QEPËRON", "RIVIHEM", "SHAGESH", "SHALAQE",
        "SHKOLLË", "SHPIFJA", "SHPRESA", "SHTALKË", "SHTERËT", "SHTËPIA", "SHYTIMI", "VASALJA",
        "VENDUAM", "VERBËTE", "VIJOSNI", "XËGITIN"
    ];

    private static readonly HashSet<string> AllWordsSet;

    // Pool variants for different grid sizes
    private static readonly string[] SmallPool; // For 7x7
    private static readonly string[] MediumPool; // For 8x8
    private static readonly string[] LargePool; // For 9x9, 10x10

    static Wordle7Dictionary()
    {
        SmallPool = [.. Words3, .. Words4, .. Words5, .. Words6[..30]];
        MediumPool = [.. Words3, .. Words4, .. Words5, .. Words6];
        LargePool = [.. Words3, .. Words4, .. Words5, .. Words6, .. Words7];
        AllWordsSet = new HashSet<string>(LargePool);
    }

    public static string[] GetPool(string size) => size switch
    {
        "small" => (string[])SmallPool.Clone(),
        "medium" => (string[])MediumPool.Clone(),
        "large" => (string[])LargePool.Clone(),
        _ => (string[])LargePool.Clone()
    };

    public static bool IsValidWord(string word) => AllWordsSet.Contains(word);
}
