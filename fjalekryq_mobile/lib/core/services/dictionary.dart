import '../models/level_config.dart';

/// Curated Albanian word dictionary for crossword puzzle generation.
/// Words grouped by length (3-13 letters). Total: ~880 words.
/// Ported from Wordle7Dictionary.cs
class Wordle7Dictionary {
  Wordle7Dictionary._();

  static const List<String> _words3 = [
    'AJO','ATO','ATY','BIE','BIR','BLU','BËJ','DAL',
    'DHE','DIL','DUA','ERA','FLE','FOL','GAZ',
    'GJI','GOL','GRA','IKI',
    'JET','KJO','LOT','MAJ','MAL',
    'MOS','MUA','NGA','NJË','NUK','ORA','LEK',
    'ORË','OSE','PAK','PIJ','POR','QAJ','RRI','SHI','SOT',
    'TOP','TRE','UJK','UJË','VAJ','VET','VIT','YLL','ZOG','ZOT','ÇAJ','ÇUN','ÇUP',
  ];

  static const List<String> _words4 = [
    'ARKA','ARRË','BAZË','DETI','HËNA','FIKU',
    'BOTA','BUKË','CIPË','BABI','BLEJ','LUGA','MIKU',
    'DERË','DIKU','DITË','DJEP','DORË',
    'EMËR','EPIK','FARË','FUND','FURI',
    'GOCA','GAFË','GOJA','GREK','GURË','HAPU',
    'HËNA','INAT','JAVË','JEMI','JETË','KAFE','KAPE',
    'KRAH','KRYQ','KUFI','KURS','KËND','LULE',
    'LUMI','LËRE','MAMI','MEZI','MISH','MURE',
    'NATA','NGRE','NXIS','NYJA','NËNË','ORAR','PARA',
    'PEMA','PENA','PICA','PIKË','PISH','PORT','PRAS','PULA','PUNA','SKAJ','KOVA','SOBA',
    'TETA','THEM','TOKA','TRUP','ULEM','UNIK','VALË',
    'VERA','VIDA','VJEÇ','XIXA','ZANA','ZYRA','ÇAST','ÇIKE',
    'ÇMIM','ÇUNA','VAZO','MARS','MJEK','ROJE','PUSI','QENI','KALI',
  ];

  static const List<String> _words5 = [
    'AKULL','BLETA','BUKUR','DARKË','DERRA','FYELL','GJELI','GJAKU',
    'DJALË','DOSJA','DREKË','DRITË','DRURË','DUAJE','DUHEJ','DYSHO','EDUKO',
    'ERËRA','FLETË','FRUTA','FUSHË','GATIM','HARAM','HOLLË','HYRJA','KISHA','KRUAJ','KUOTË','KURTH','KUSUR',
    'KËMBË','LIBËR','LUAJË','LUFTË','MIELL','MILJE','VLLAI',
    'MOLLË','MOTËR','MPREH','NDAJU','NDJEJ','PESHK','VENDI',
    'PESHA','PJEKË','PLAKË','PLEPA','PYJET','MACJA',
    'RRUGË','SHKAK','SKAJË','TETOR','THIKË','TRIKO','TAKSA',
    'VAJZË','ZEMËR','PAKET','ZYSHË','KAPSE','JANAR','PRILL','GUSHT','TETOR','NUMËR','FJALË',
    'MJEKU','PILOT','AKTOR','NOTER','POLIC',
  ];

  static const List<String> _words6 = [
    'AJROSË','BISEDË','DALLIM','DETARË','FITORE','FLUTUR','FËMIJË',
    'GJUAJE','GOMARË','KLINIK','KRIHJE','KUJDES','HËNGRA','ABUZIM','AKUZIM',
    'KËSULË','MBLIDH','MBYLLI','NGRICË','PAGUAJ','QENUSH','FSHATI','BIZNES','LEXUES',
    'SHISHE','SHTËPI','SHËTIS','SHKENCË','ÇAKMAK','MAKINË','MOTORR','EDUKIM',
    'VITALE','VRAPOJ','VËLLAI','XHINSE','LAPTOP','SHKURT','KORRIK','NËNTOR','MËSUES',
    'ARTIST','BERBER','BIOLOG','KIRURG','PIKTOR','SHITËS','SHOFER','TEKNIK','USHTAR',
  ];

  static const List<String> _words7 = [
    'ARSIMIM','ANIMOVA','ANKORUA','ARKIVAT','ARTIKUJ','DRITARE','FILLIMI','KUJTIME','KËNAQJE','ANALIZË',
    'LIBRARI','LËVIZNI','MBARTEN','MONOLOG','MËSUESE','NGJITJA','NJOHURI','PIKTURË','INTERES','ARTISTË',
    'SHKOLLË','SHPIFJE','SHPRESA','VAJOSJE','NDËRTES','PALLATE','CELULAR','TAVULL','BUJQËSI','GJAHTAR',
    'QERSHOR','SHTATOR','DHJETOR','DENTIST','MJEKËSI','FARMACI','AUTOBUS','TRADITA','DËSHMOR','VEPRIME','SHËRBIM',
    'AGRONOM','ARBITËR','BLEGTOR','DREJTOR','GAZETAR','KËPUCAR','MEKANIK','MURATOR','PEDAGOG','PUNËTOR','PYLLTAR','SALDUES',
  ];

  static const List<String> _words8 = [
    'ARMIQËSI','BASHKIMI','BESIMTAR','BIBLOTEK',
    'DREJTËSI','FAMILJAR',
    'FITIMTAR','HISTORIA','INSTITUT',
    'JETËSORE','KAPITULL','KËNGËTAR','KËSHILLË','KRYESORE','LARGËSIA',
    'LLOGARIA','MËSIMORE','PËRPARIM','STIMULIM',
    'QYTETARI','SHKOLLARË',
    'SHPËTIMI','TRADITËS','UDHËHEQË','VËLLAZËRI','ZGJIDHJE','KAMARIER','PASTRUES','BIÇIKLET','ARKITEKT',
    'BANAKIER','EDUKATOR','FIZIKANT','FOTOGRAF','LABORANT','MENAXHER','MUZIKANT','OPERATOR','PARUKIER','PSIKOLOG','REGJISOR','STUDIUES',
  ];

  static const List<String> _words9 = [
    'AKTIVITET','ANALIZUAR','DREJTËSIA','DREJTORIA',
    'HISTORIAN','KAPITULLI','KULTURORE','LLOGARITË',
    'KOMPJUTER','HORIZONTI','GJENERATA','GJITHMONË','UDHËHEQJE','LAVATRIÇE','TELEVIZOR',
    'INXHINIER','SEKRETARE','ESTETISTE','FARMACIST',
    'FINANCIAR','HIDRAULIK','KUZHINIER','PASTRUESE','VETERINER',
  ];

  static const List<String> _words10 = [
    'FRIGORIFER','PROGRAMUES','MAGAZINIER','SHKENCËTAR','FUTBOLLIST','SHPËTIMTAR','SHTETËRORË',
    'BIBLIOTEKA','FAMILJARËT','KËSHILLTAR','ORGANIZATA','VEPRIMTARI','INFERMIER',
  ];

  static const List<String> _words11 = [
    'KONTABILIST','ELEKTRICIST','ZDRUKTHËTAR',
  ];

  static const List<String> _words12 = [];

  static const List<String> _words13 = [
    'FIZIOTERAPIST','BASKETBOLLIST',
  ];

  // Pre-built pools by difficulty
  static late final List<String> _easyPool;
  static late final List<String> _mediumPool;
  static late final List<String> _hardPool;
  static late final List<String> _expertPool;
  static late final List<String> _fullPool;
  static late final Set<String> _allWordsSet;

  static bool _initialized = false;

  static void _ensureInitialized() {
    if (_initialized) return;
    _easyPool = [..._words3, ..._words4, ..._words5, ..._words6];
    _mediumPool = [..._words5, ..._words6, ..._words7, ..._words8];
    _hardPool = [..._words7, ..._words8, ..._words9, ..._words10];
    _expertPool = [..._words10, ..._words11, ..._words12, ..._words13];
    _fullPool = [
      ..._words3, ..._words4, ..._words5, ..._words6, ..._words7,
      ..._words8, ..._words9, ..._words10, ..._words11, ..._words12, ..._words13,
    ];
    _allWordsSet = _fullPool.toSet();
    _initialized = true;
  }

  /// Get a copy of the word pool for the given difficulty.
  static List<String> getPool(Difficulty difficulty) {
    _ensureInitialized();
    switch (difficulty) {
      case Difficulty.easy:
        return List<String>.from(_easyPool);
      case Difficulty.medium:
        return List<String>.from(_mediumPool);
      case Difficulty.hard:
        return List<String>.from(_hardPool);
      case Difficulty.expert:
        return List<String>.from(_expertPool);
    }
  }

  /// Get words of a specific length for "featured big word" placement.
  static List<String> getWordsByLength(int length) {
    switch (length) {
      case 7:  return List<String>.from(_words7);
      case 8:  return List<String>.from(_words8);
      case 9:  return List<String>.from(_words9);
      case 10: return List<String>.from(_words10);
      case 11: return List<String>.from(_words11);
      case 13: return List<String>.from(_words13);
      default: return [];
    }
  }

  /// Check if a word is in the dictionary.
  static bool isValidWord(String word) {
    _ensureInitialized();
    return _allWordsSet.contains(word);
  }
}
