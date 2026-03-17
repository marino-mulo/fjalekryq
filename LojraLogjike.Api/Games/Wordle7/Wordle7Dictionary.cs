namespace LojraLogjike.Api.Games.Wordle7;

/// <summary>
/// Curated Albanian word dictionary for crossword puzzle generation.
/// Words grouped by length (3-7 letters). Total: ~880 words.
/// </summary>
public static class Wordle7Dictionary
{
    private static readonly string[] Words3 =
    [
    "AJO","ARI","ATO","ATY","BIE","BIR","BLE","BLU","BËJ","DAL",
    "DET","DHE","DIL","DUA","ERA","FIK","FLE","FOL","GAZ",
    "GJI","GJU","GOL","GRA","HAJ","IKE","IKI",
    "JET","KJO","LOT","LUG","LËR","MAJ","MAL",
    "MIK","MOS","MUA","NGA","NIS","NJË","NUK","ORA",
    "ORË","OSE","PAK","PIJ","POR","PUS","QAJ","QAN","QEN",
    "QET","RRI","SAJ","SHI","SOT",
    "TEL","TIJ","TOP","TRE","UJK","UJË","URI",
    "VAJ","VET","VIT","YLL","ZOG","ZOT","ÇAJ","ÇUN","ÇUP"
    ];

    private static readonly string[] Words4 =
    [
    "ADET","ARKË","ARRË","BAZA","BAZË",
    "BOTË","BUKË","CIPË",
    "DERË","DIKU","DITË","DJEP","DORË","DUAJ","EMRA",
    "EMËR","EPIK","FARË","FUND","FURI","FYEJ","FYER",
    "FYTE","GAFË","GJAK","GJEL","GOJA","GOJE","GREK","GURË","HAPU",
    "HËNA","HËNË","INAT","JAVË","JEMI","JETË","KAFE","KAPE",
    "KRAH","KRYQ","KUFI","KURS","KËND","LAKË","LANË","LARË","LULE",
    "LUMË","LUTA","LËRE","MAMI","MEZI","MIRË","MISH","MURE",
    "NATË","NGRE","NXIS","NYJA","NYJË","NËNË","ORAR","PARA","PATA",
    "PEMA","PENA","PICA","PIKË","PISH","PORT","PRAS","PULË","PUNË",
    "RETË","RIKA","SHAP","SKAJ",
    "TAKË","TETA","THEM","TOKA","TOKË","TRUP","ULEM","UNIK","VALË",
    "VERË","VIDË","VJEÇ","VOLA","XIXA","ZANË","ZYRA","ÇAST","ÇIKE",
    "ÇMIM","ÇMON","ÇUAM","ÇUAN"
    ];

    private static readonly string[] Words5 =
    [
    "AKUJT","BABAI","BLETË","BUKUR","DARKË","DERRA",
    "DJALI","DOSJA","DREKË","DRITË","DRURË","DUAJE","DUHEJ","DYSHO","EDUKO",
    "ERËRA","FLETË","FRUTË","FSHAT","FUSHË","GATIM",
    "HANIN","HARAM","HASEJ","HEQËS","HOLLË","HYRJA",
    "HËNËZ","KISHA","KISHE","KOVËN","KRUAN","KUOTË","KURTH","KUSUR",
    "KËMBË","LEHIM","LIBËR","LUAJË","LUFTË","MIELL","MILJE",
    "MJEKË","MOLLË","MOTËR","MPREH","NDAJU","NDJEJ","PESHK",
    "PESHO","PJEKË","PLAKË","PLEPA","PYJET","QENIN",
    "RRUGË","SHKAK","SKAJË","TETOR","THIKË","TOKËS","TRIKO",
    "VAJZË","VALOJ","VAZET","XHINS","ZEMËR","ZJEVE",
    "ZYSHË",
    ];

    private static readonly string[] Words6 =
    [
    "AJROSË","BABAIT","BISEDË","DALLIM","DETARË","FITORE","FLUTUR","FËMIJË",
    "GJUAJE","GOMARË","KAFENE","KLINIK","KRIHJE","KUJDES",
    "KËSULË","MBLIDH","MBYLLI","NGRICË","PAGUAJ","QENUSH",
    "SHISHE","SHTËPI","SHËTIS","STIMUL","TAKSIM",
    "VENDET","VITALE","VRAPOJ","VËLLAI"
    ];

    private static readonly string[] Words7 =
    [
        "ANIMOVA","ANKORUA","ARKIVAT","ARTIKUJ","DRITARE","FILLIMI","KUJTIME","KËNAQJE",
        "LIBRARI","LËVIZNI","MBARTEN","MONOLOG","MËSUESE","NGJITJA","PIKTURË",
        "SHKOLLË","SHPIFJA","SHPRESA","SHTËPIA","VAJOSJE"
    ];

    private static readonly string[] Words8 =
    [
        "ABUZIME","AKUZUAR","ANALIZË","ARMIQËSI","ARTISTË","BASHKIMI","BESIMTAR","BIBLOTEK",
        "BIZNESI","BUJQËSIA","DËSHMORI","DREJTORI","DREJTËSI","DRITARET","FAMILJAR","EDUKIMI",
        "FITIMTAR","GJENERATA","GJITHMONË","GJUHËTAR","HISTORIA","HORIZONT","INSTITUT","INTERES",
        "JETËSORE","KAPITULL","KËNGËTAR","KËSHILLË","KRYESORE","LARGESIA","LEXUESIT",
        "LLOGARIA","MËSIMORE","NDËRTESA","NJOHURIA","PËRPARIM",
        "PUNËTORËT","QYTETARI","QYTETARE","SHËRBIMI","SHKENCËS","SHKOLLAT",
        "SHPËTIMI","TRADITËS","UDHËHEQË","VEPRIMET","VËLLAZËRI","ZGJIDHJE"
    ];

    private static readonly string[] Words9 =
    [
        "AKTIVITET","ANALIZUAR","ARMIQËSIA","ARSIMIMIN","BIBLIOTEKA","DREJTËSIA","DREJTORIA",
        "FAMILJARËT","FITUESIT","GJENERATAT","GJUHËTARET","HISTORIAN","INSTITUTI",
        "INTERESAT","KAPITULLI","KËNGËTARËT","KËSHILLTAR","KRYESORET","KULTURORE","LLOGARITË",
        "NDËRTESAT","ORGANIZATA","PËRVOJAT","PUNËTORËT",
        "QYTETARËT","RËNDËSISHME","SHËRBIMET","SHKENCËTAR","SHKOLLARËT","SHPËTIMTAR","SHTETËRORË","TRADITAT",
        "UDHËHEQËSI","VEPRIMTARI","ZGJIDHJET"
    ];

    private static readonly HashSet<string> AllWordsSet;

    // Pool variants for different grid sizes
    private static readonly string[] SmallPool;  // For 7x7 (Mon-Tue)
    private static readonly string[] MediumPool; // For 8x8 (Wed-Thu)
    private static readonly string[] LargePool;  // For 9x9+ (Fri-Sun)

    static Wordle7Dictionary()
    {
        SmallPool = [.. Words3, .. Words4, .. Words5, .. Words6, .. Words7];
        MediumPool = [.. Words3, .. Words4, .. Words5, .. Words6, .. Words7, .. Words8];
        LargePool = [.. Words3, .. Words4, .. Words5, .. Words6, .. Words7, .. Words8, .. Words9];
        AllWordsSet = new HashSet<string>(LargePool);
    }

    public static string[] GetPool(string size) => size switch
    {
        "small" => (string[])SmallPool.Clone(),
        "medium" => (string[])MediumPool.Clone(),
        "large" => (string[])LargePool.Clone(),
        _ => (string[])LargePool.Clone()
    };

    /// <summary>
    /// Returns words of a specific length for "featured big word" placement.
    /// </summary>
    public static string[] GetWordsByLength(int length) => length switch
    {
        7 => (string[])Words7.Clone(),
        8 => (string[])Words8.Clone(),
        9 => (string[])Words9.Clone(),
        _ => []
    };

    public static bool IsValidWord(string word) => AllWordsSet.Contains(word);
}
