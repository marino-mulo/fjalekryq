namespace LojraLogjike.Api.Games.Wordle7;

/// <summary>
/// Curated Albanian word dictionary for crossword puzzle generation.
/// Words grouped by length (3-7 letters). Total: ~880 words.
/// </summary>
public static class Wordle7Dictionary
{
    private static readonly string[] Words3 =
    [
    "AJO","ATO","ATY","BIE","BIR","BLU","BËJ","DAL",
    "DHE","DIL","DUA","ERA","FLE","FOL","GAZ",
    "GJI","GOL","GRA","IKI",
    "JET","KJO","LOT","MAJ","MAL",
    "MOS","MUA","NGA","NJË","NUK","ORA","LEK",
    "ORË","OSE","PAK","PIJ","POR","QAJ","RRI","SHI","SOT",
    "TOP","TRE","UJK","UJË","VAJ","VET","VIT","YLL","ZOG","ZOT","ÇAJ","ÇUN","ÇUP"
    ];

    private static readonly string[] Words4 =
    [
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
    "ÇMIM","ÇUNA","VAZO","MARS","MJEK","ROJE","PUSI","QENI","KALI"
    ];

    private static readonly string[] Words5 =
    [
    "AKULL","BLETA","BUKUR","DARKË","DERRA","FYELL","GJELI","GJAKU",
    "DJALË","DOSJA","DREKË","DRITË","DRURË","DUAJE","DUHEJ","DYSHO","EDUKO",
    "ERËRA","FLETË","FRUTA","FUSHË","GATIM","HARAM","HOLLË","HYRJA","KISHA","KRUAJ","KUOTË","KURTH","KUSUR",
    "KËMBË","LIBËR","LUAJË","LUFTË","MIELL","MILJE","VLLAI",
    "MOLLË","MOTËR","MPREH","NDAJU","NDJEJ","PESHK","VENDI",
    "PESHA","PJEKË","PLAKË","PLEPA","PYJET","MACJA",
    "RRUGË","SHKAK","SKAJË","TETOR","THIKË","TRIKO","TAKSA",
    "VAJZË","ZEMËR","PAKET","ZYSHË","KAPSE","JANAR","PRILL","GUSHT","TETOR","NUMËR","FJALË",
    "MJEKU","PILOT","AKTOR","NOTER","POLIC"
    ];

    private static readonly string[] Words6 =
    [
    "AJROSË","BISEDË","DALLIM","DETARË","FITORE","FLUTUR","FËMIJË",
    "GJUAJE","GOMARË","KLINIK","KRIHJE","KUJDES","HËNGRA","ABUZIM","AKUZIM",
    "KËSULË","MBLIDH","MBYLLI","NGRICË","PAGUAJ","QENUSH","FSHATI","BIZNES","LEXUES",
    "SHISHE","SHTËPI","SHËTIS","SHKENCË","ÇAKMAK","MAKINË","MOTORR","EDUKIM",
    "VITALE","VRAPOJ","VËLLAI","XHINSE","LAPTOP","SHKURT","KORRIK","NËNTOR","MËSUES",
    "ARTIST","BERBER","BIOLOG","KIRURG","PIKTOR","SHITËS","SHOFER","TEKNIK","USHTAR"
    ];

    private static readonly string[] Words7 =
    [
        "ARSIMIM","ANIMOVA","ANKORUA","ARKIVAT","ARTIKUJ","DRITARE","FILLIMI","KUJTIME","KËNAQJE","ANALIZË",
        "LIBRARI","LËVIZNI","MBARTEN","MONOLOG","MËSUESE","NGJITJA","NJOHURI","PIKTURË","INTERES","ARTISTË",
        "SHKOLLË","SHPIFJE","SHPRESA","VAJOSJE","NDËRTES","PALLATE","CELULAR","TAVULL","BUJQËSI","GJAHTAR",
        "QERSHOR","SHTATOR","DHJETOR","DENTIST","MJEKËSI","FARMACI","AUTOBUS","TRADITA","DËSHMOR","VEPRIME","SHËRBIM",
        "AGRONOM","ARBITËR","BLEGTOR","DREJTOR","GAZETAR","KËPUCAR","MEKANIK","MURATOR","PEDAGOG","PUNËTOR","PYLLTAR","SALDUES"
    ];

    private static readonly string[] Words8 =
    [
        "ARMIQËSI","BASHKIMI","BESIMTAR","BIBLOTEK",
        "DREJTËSI","FAMILJAR",
        "FITIMTAR","HISTORIA","INSTITUT",
        "JETËSORE","KAPITULL","KËNGËTAR","KËSHILLË","KRYESORE","LARGËSIA",
        "LLOGARIA","MËSIMORE","PËRPARIM","STIMULIM",
        "QYTETARI","SHKOLLARË",
        "SHPËTIMI","TRADITËS","UDHËHEQË","VËLLAZËRI","ZGJIDHJE","KAMARIER","PASTRUES","BIÇIKLET","ARKITEKT",
        "BANAKIER","EDUKATOR","FIZIKANT","FOTOGRAF","LABORANT","MENAXHER","MUZIKANT","OPERATOR","PARUKIER","PSIKOLOG","REGJISOR","STUDIUES"
    ];

    private static readonly string[] Words9 =
    [
        "AKTIVITET","ANALIZUAR","DREJTËSIA","DREJTORIA",
        "HISTORIAN","KAPITULLI","KULTURORE","LLOGARITË",
        "KOMPJUTER","HORIZONTI","GJENERATA","GJITHMONË","UDHËHEQJE","LAVATRIÇE","TELEVIZOR",
        "INXHINIER","SEKRETARE","ESTETISTE","FARMACIST",
        "FINANCIAR","HIDRAULIK","KUZHINIER","PASTRUESE","VETERINER"
    ];

    private static readonly string[] Words10 =
    [
        "FRIGORIFER","PROGRAMUES","MAGAZINIER","SHKENCËTAR","FUTBOLLIST","SHPËTIMTAR","SHTETËRORË",
        "BIBLIOTEKA","FAMILJARËT","KËSHILLTAR","ORGANIZATA","VEPRIMTARI","INFERMIER"
    ];

    private static readonly string[] Words11 =
    [
        "KONTABILIST","ELEKTRICIST","ZDRUKTHËTAR"
    ];

    private static readonly string[] Words12 =
    [
        
    ];

    private static readonly string[] Words13 =
    [
        "FIZIOTERAPIST","BASKETBOLLIST"
    ];
    private static readonly HashSet<string> AllWordsSet;

    // Pool variants for different grid sizes
    private static readonly string[] SmallPool;  // For 7x7 (Mon-Tue)
    private static readonly string[] MediumPool; // For 8x8 (Wed-Thu)
    private static readonly string[] LargePool;  // For 9x9+ (Fri-Sun)
    private static readonly string[] FullPool;   // All words 3-13 letters

    static Wordle7Dictionary()
    {
        SmallPool = [.. Words3, .. Words4, .. Words5, .. Words6, .. Words7];
        MediumPool = [.. Words3, .. Words4, .. Words5, .. Words6, .. Words7, .. Words8];
        LargePool = [.. Words3, .. Words4, .. Words5, .. Words6, .. Words7, .. Words8, .. Words9];
        FullPool = [.. Words3, .. Words4, .. Words5, .. Words6, .. Words7, .. Words8, .. Words9, .. Words10, .. Words11, .. Words12, .. Words13];
        AllWordsSet = new HashSet<string>(FullPool);
    }

    public static string[] GetPool(string size) => size switch
    {
        "small" => (string[])SmallPool.Clone(),
        "medium" => (string[])MediumPool.Clone(),
        "large" => (string[])LargePool.Clone(),
        "full" => (string[])FullPool.Clone(),
        _ => (string[])FullPool.Clone()
    };

    /// <summary>
    /// Returns words of a specific length for "featured big word" placement.
    /// </summary>
    public static string[] GetWordsByLength(int length) => length switch
    {
        7 => (string[])Words7.Clone(),
        8 => (string[])Words8.Clone(),
        9 => (string[])Words9.Clone(),
        10 => (string[])Words10.Clone(),
        11 => (string[])Words11.Clone(),
        13 => (string[])Words13.Clone(),
        _ => []
    };

    public static bool IsValidWord(string word) => AllWordsSet.Contains(word);
}
