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
    "ARKË","ARRË","BAZA","BAZË",
    "BOTË","BUKË","CIPË",
    "DERË","DIKU","DITË","DJEP","DORË","DUAJ","EMRA",
    "EMËR","EPIK","FARË","FUND","FURI","FYEJ","FYER",
    "GOCA","GAFË","GJAK","GJEL","GOJA","GOJE","GREK","GURË","HAPU",
    "HËNA","HËNË","INAT","JAVË","JEMI","JETË","KAFE","KAPE",
    "KRAH","KRYQ","KUFI","KURS","KËND","LULE",
    "LUMË","LUTA","LËRE","MAMI","MEZI","MIRË","MISH","MURE",
    "NATË","NGRE","NXIS","NYJA","NYJË","NËNË","ORAR","PARA","PATA",
    "PEMA","PENA","PICA","PIKË","PISH","PORT","PRAS","PULË","PUNË",
    "RETË","RIKA","SHAP","SKAJ","KOVË","SOBË",
    "TAKË","TETA","THEM","TOKA","TOKË","TRUP","ULEM","UNIK","VALË",
    "VERË","VIDË","VJEÇ","XIXA","ZANË","ZYRA","ÇAST","ÇIKE",
    "ÇMIM","ÇUNA","VAZO","MARS","MJEK","ROJE",
    ];

    private static readonly string[] Words5 =
    [
    "AKUJT","BABAI","BLETË","BUKUR","DARKË","DERRA",
    "DJALË","DOSJA","DREKË","DRITË","DRURË","DUAJE","DUHEJ","DYSHO","EDUKO",
    "ERËRA","FLETË","FRUTË","FSHAT","FUSHË","GATIM",
    "HANIN","HARAM","HASEJ","HEQËS","HOLLË","HYRJA",
    "HËNËZ","KISHA","KISHE","KRUAN","KUOTË","KURTH","KUSUR",
    "KËMBË","LEHIM","LIBËR","LUAJË","LUFTË","MIELL","MILJE",
    "MJEKË","MOLLË","MOTËR","MPREH","NDAJU","NDJEJ","PESHK",
    "PESHO","PJEKË","PLAKË","PLEPA","PYJET","QENIN",
    "RRUGË","SHKAK","SKAJË","TETOR","THIKË","TOKËS","TRIKO","TAKSA",
    "VAJZË","ZEMËR","ZJEVE","PAKET","ZYSHË","KAPSE","JANAR","PRILL","GUSHT","TETOR","NUMËR","FJALË",
    "MJEKE","MJEKU","PILOT","AKTOR","NOTER","POLIC"
    ];

    private static readonly string[] Words6 =
    [
    "AJROSË","BABAIT","BISEDË","DALLIM","DETARË","FITORE","FLUTUR","FËMIJË",
    "GJUAJE","GOMARË","KAFENE","KLINIK","KRIHJE","KUJDES",
    "KËSULË","MBLIDH","MBYLLI","NGRICË","PAGUAJ","QENUSH",
    "SHISHE","SHTËPI","SHËTIS","STIMUL","SHKENCË","ÇAKMAK","MAKINË","MOTORR"
    "VENDET","VITALE","VRAPOJ","VËLLAI","XHINSE","LAPTOP","SHKURT","KORRIK","NËNTOR","MËSUES",
    "ARTIST","BERBER","BIOLOG","KIRURG","PIKTOR","SHITËS","SHOFER","TEKNIK","USHTAR"
    ];

    private static readonly string[] Words7 =
    [
        "ARSIMIM","ANIMOVA","ANKORUA","ARKIVAT","ARTIKUJ","DRITARE","FILLIMI","KUJTIME","KËNAQJE",
        "LIBRARI","LËVIZNI","MBARTEN","MONOLOG","MËSUESE","NGJITJA","NJOHURI","PIKTURË","INTERES",
        "SHKOLLË","SHPIFJA","SHPRESA","SHTËPIA","VAJOSJE","NDËRTES","PALLATE","CELULAR","TAVULL",
        "QERSHOR","SHTATOR","DHJETOR","DENTIST","MJEKËSI","FARMACI","AUTOBUS","TRADITA",
        "AGRONOM","ARBITËR","BLEGTOR","DREJTOR","GAZETAR","KËPUCAR","MEKANIK","MURATOR","PEDAGOG","PUNËTOR","PYLLTAR","SALDUES"

    ];

    private static readonly string[] Words8 =
    [
        "ABUZIME","AKUZUAR","ANALIZË","ARMIQËSI","ARTISTË","BASHKIMI","BESIMTAR","BIBLOTEK",
        "BIZNESI","BUJQËSIA","DËSHMORI","DREJTËSI","DRITARET","FAMILJAR","EDUKIMI",
        "FITIMTAR","GJENERATA","GJITHMONË","GJUHËTAR","HISTORIA","HORIZONT","INSTITUT",
        "JETËSORE","KAPITULL","KËNGËTAR","KËSHILLË","KRYESORE","LARGESIA","LEXUESIT",
        "LLOGARIA","MËSIMORE","PËRPARIM",
        "PUNËTORËT","QYTETARI","QYTETARE","SHËRBIMI","SHKOLLARË",
        "SHPËTIMI","TRADITËS","UDHËHEQË","VEPRIMET","VËLLAZËRI","ZGJIDHJE","KAMARIER","PASTRUES","BIÇIKLET","ARKITEKT",
        "BANAKIER","EDUKATOR","FIZIKANT","FOTOGRAF","LABORANT","MENAXHER","MUZIKANT","OPERATOR","PARUKIER","PSIKOLOG","REGJISOR","STUDIUES"
    ];

    private static readonly string[] Words9 =
    [
        "AKTIVITET","ANALIZUAR","DREJTËSIA","DREJTORIA",
        "HISTORIAN","KAPITULLI","KRYESORET","KULTURORE","LLOGARITË",
        "NDËRTESAT","PUNËTORËT","KOMPJUTER",
        "QYTETARËT","SHËRBIMET",
        "UDHËHEQJE","ZGJIDHJET","LAVATRIÇE","TELEVIZOR",
        "INXHINIER","SEKRETARE","ESTETISTE","FARMACIST",
        "FINANCIAR","HIDRAULIK","KUZHINIER","PASTRUESE","VETERINER"
    ];

    private static readonly string[] Words10 =
    [
        "FRIGORIFER","PROGRAMUES","MAGAZINIER","SHKENCËTAR","FUTBOLLIST","SHPËTIMTAR","SHTETËRORË",
        "BIBLIOTEKA","FAMILJARËT","GJENERATAT","GJUHËTARET","KËNGËTARËT","KËSHILLTAR","ORGANIZATA","VEPRIMTARI","INFERMIER"
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
