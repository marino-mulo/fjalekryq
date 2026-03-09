namespace LojraLogjike.Api.Games.Wordle7;

/// <summary>
/// Curated Albanian word dictionary for crossword puzzle generation.
/// Words grouped by length (3-7 letters).
/// </summary>
public static class Wordle7Dictionary
{
    private static readonly string[] Words3 =
    [
        "MAL", "DET", "UJË", "ZOG", "ERA", "VAJ", "ORA", "QEN", "ZIM",
        "DUA", "PIK", "MES", "LOT", "NJË", "SOT", "ZOT", "MUA", "DHE",
        "PAK", "TRE", "SAJ", "TIJ", "AJO", "KJO", "ARI", "VEL",
        "KOT", "FIK", "DIM", "VIT", "BUZ", "KUQ",
        "MIK", "FLE", "END", "VET", "JET", "MOS", "POR", "SHI",
        "NUK"
    ];

    private static readonly string[] Words4 =
    [
        "BUKË", "KAFË", "LULË", "MISH", "DITË", "NATË", "TOKË", "VALË",
        "GURË", "PIKË", "ARRË", "NËNË", "DORË", "EMËR", "VERË", "JETË",
        "JAVË", "INAT", "HËNË", "MAMI", "LULE", "GJAK", "LUMË", "PUNË",
        "DERË", "BIRË", "FARË", "BARË", "MIRË", "DIMË", "RËRË", "QUMË",
        "ZANË", "DËMË", "LAKË", "ARKË", "TRUP", "KRAH", "DIÇË", "PULË",
        "ARTH", "PARA", "GJEL", "FUND", "DIKU", "VËRË", "TOKA"
    ];

    private static readonly string[] Words5 =
    [
        "LIBËR", "DREKË", "DARKË", "KISHA", "FLETË", "FSHAT", "ZEMËR",
        "NXËNË", "MOLLË", "MJEKË", "BLETË", "RRUGË", "SHKAK", "DRITË",
        "QUMËS", "MOTËR", "DJATË", "UJKUJ", "PESHK", "SHOKË", "MAJMË",
        "VAJZË", "DJALI", "BABAI", "PLAKË", "THIKË", "MIZËR", "DRURË",
        "BUKUR", "LUMËT", "LAGUR"
    ];

    private static readonly string[] Words6 =
    [
        "DALLIM", "KAFENE", "SHTËPI", "SHKOLLË", "VËLLAI", "MËSUËS",
        "FEMIJË", "SHOQËR", "GJËNDË", "BISEDË", "FËMIJË", "FLUTUR"
    ];

    private static readonly string[] Words7 =
    [
        "MËSUESE", "DRITARE", "SHTËPIA", "SHPRESA", "FILLIMI", "LIBRARI",
        "PIKTURË", "KUJTIME"
    ];

    private static readonly HashSet<string> AllWordsSet;

    // Pool variants for different grid sizes
    private static readonly string[] SmallPool; // For 7x7
    private static readonly string[] MediumPool; // For 8x8
    private static readonly string[] LargePool; // For 9x9, 10x10

    static Wordle7Dictionary()
    {
        SmallPool = [.. Words3, .. Words4, .. Words5, .. Words6[..3]];
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
