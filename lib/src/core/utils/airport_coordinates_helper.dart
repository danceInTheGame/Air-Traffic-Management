import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

/// Helper pour enrichir les coordonnées GPS des aéroports
/// Charge automatiquement tous les aéroports depuis le JSON et génère des coordonnées estimées
class AirportCoordinatesHelper {
  
  // Cache des aéroports chargés depuis le JSON
  static Map<String, Map<String, dynamic>>? _airportsFromJson;
  static bool _isLoaded = false;
  
  /// Base de données des coordonnées d'aéroports hardcodées (prioritaires)
  static final Map<String, LatLng> _airportCoordinates = {
    // Europe - Aéroports majeurs
    'LFPG': LatLng(49.0097, 2.5479),   // Paris CDG
    'LFPO': LatLng(48.7233, 2.3794),   // Paris Orly
    'LFPB': LatLng(48.9694, 2.4414),   // Paris Le Bourget
    'EGLL': LatLng(51.4700, -0.4543),  // London Heathrow
    'EGKK': LatLng(51.1481, -0.1903),  // London Gatwick
    'EHAM': LatLng(52.3086, 4.7639),   // Amsterdam Schiphol
    'EDDF': LatLng(50.0379, 8.5622),   // Frankfurt
    'EDDM': LatLng(48.3538, 11.7861),  // Munich
    'LEMD': LatLng(40.4983, -3.5676),  // Madrid
    'LEBL': LatLng(41.2974, 2.0833),   // Barcelona
    'LIRF': LatLng(41.8003, 12.2389),  // Rome Fiumicino
    'LSGG': LatLng(46.2381, 6.1095),   // Geneva
    'LSZH': LatLng(47.4647, 8.5492),   // Zurich
    'LOWW': LatLng(48.1103, 16.5697),  // Vienna
    'EBBR': LatLng(50.9014, 4.4844),   // Brussels
    
    // Amérique du Nord - Aéroports majeurs
    'KJFK': LatLng(40.6413, -73.7781), // New York JFK
    'KLAX': LatLng(33.9416, -118.4085),// Los Angeles
    'KORD': LatLng(41.9742, -87.9073), // Chicago O'Hare
    'KATL': LatLng(33.6407, -84.4277), // Atlanta
    'KDFW': LatLng(32.8998, -97.0403), // Dallas Fort Worth
    'KDEN': LatLng(39.8561, -104.6737),// Denver
    'KSFO': LatLng(37.6213, -122.3790),// San Francisco
    'CYUL': LatLng(45.4706, -73.7408), // Montreal
    'CYYZ': LatLng(43.6777, -79.6248), // Toronto
    'CYVR': LatLng(49.1939, -123.1844),// Vancouver
    'CYLW': LatLng(49.9561, -119.3778),// Kelowna
    
    // Asie - Aéroports majeurs
    'RJAA': LatLng(35.7647, 140.3864), // Tokyo Narita
    'VHHH': LatLng(22.3080, 113.9185), // Hong Kong
    'WSSS': LatLng(1.3644, 103.9915),  // Singapore
    'ZBAA': LatLng(40.0801, 116.5846), // Beijing
    
    // Afrique
    'FACT': LatLng(-33.9715, 18.6021), // Cape Town
    'FAJS': LatLng(-26.1392, 28.2460), // Johannesburg
    
    // Amérique du Sud
    'SBGR': LatLng(-23.4356, -46.4731),// São Paulo
    'SAEZ': LatLng(-34.8222, -58.5358),// Buenos Aires
  };
  
  /// Charge les aéroports depuis le fichier JSON
  static Future<void> loadAirportsFromJson() async {
    if (_isLoaded) return;
    
    try {
      final jsonString = await rootBundle.loadString('assets/airports_1163.json');
      final List<dynamic> airportsJson = json.decode(jsonString);
      
      _airportsFromJson = {};
      
      for (var airportData in airportsJson) {
        if (airportData['OACI'] != null && 
            airportData['OACI'].toString().trim().isNotEmpty) {
          
          final oaci = airportData['OACI'].toString().trim();
          _airportsFromJson![oaci] = {
            'name': airportData['nom']?.toString().trim() ?? '',
            'city': airportData['ville']?.toString().trim() ?? '',
            'country': airportData['Pays']?.toString().trim() ?? '',
          };
        }
      }
      
      _isLoaded = true;
      print('✅ ${_airportsFromJson!.length} aéroports chargés depuis le JSON');
    } catch (e) {
      print('❌ Erreur lors du chargement des aéroports: $e');
      _airportsFromJson = {};
      _isLoaded = true;
    }
  }
  
  /// Récupère les coordonnées d'un aéroport par son code OACI
  static Future<LatLng?> getCoordinates(String oaci) async {
    // Assurer que le JSON est chargé
    await loadAirportsFromJson();
    
    // 1. Vérifier d'abord les coordonnées hardcodées (priorité)
    if (_airportCoordinates.containsKey(oaci)) {
      return _airportCoordinates[oaci];
    }
    
    // 2. Si l'aéroport existe dans le JSON, générer des coordonnées estimées
    if (_airportsFromJson != null && _airportsFromJson!.containsKey(oaci)) {
      final airportData = _airportsFromJson![oaci]!;
      final country = airportData['country'] ?? '';
      
      // Essayer d'estimer par préfixe OACI
      var coords = estimateCoordinatesByOACIPrefix(oaci);
      if (coords != null) {
        return coords;
      }
      
      // Essayer d'estimer par pays
      coords = estimateCoordinatesByCountry(country);
      if (coords != null) {
        return coords;
      }
    }
    
    return null;
  }
  
  /// Vérifie si un aéroport existe (dans le JSON ou hardcodé)
  static Future<bool> hasCoordinates(String oaci) async {
    await loadAirportsFromJson();
    
    // Existe dans les coordonnées hardcodées
    if (_airportCoordinates.containsKey(oaci)) {
      return true;
    }
    
    // Existe dans le JSON (peut être estimé)
    if (_airportsFromJson != null && _airportsFromJson!.containsKey(oaci)) {
      final airportData = _airportsFromJson![oaci]!;
      final country = airportData['country'] ?? '';
      
      // Peut-on estimer ses coordonnées ?
      return estimateCoordinatesByOACIPrefix(oaci) != null ||
             estimateCoordinatesByCountry(country) != null;
    }
    
    return false;
  }
  
  /// Récupère tous les codes OACI disponibles
  static Future<List<String>> getAvailableAirports() async {
    await loadAirportsFromJson();
    
    final allOaci = <String>{};
    allOaci.addAll(_airportCoordinates.keys);
    if (_airportsFromJson != null) {
      allOaci.addAll(_airportsFromJson!.keys);
    }
    
    return allOaci.toList()..sort();
  }
  
  /// Estime les coordonnées basées sur le préfixe OACI
  static LatLng? estimateCoordinatesByOACIPrefix(String oaci) {
    if (oaci.length < 2) return null;
    
    final prefix = oaci.substring(0, 2).toUpperCase();
    
    final prefixToCoordinates = {
      // Europe
      'LF': LatLng(46.6034, 1.8883),   // France (centre)
      'EG': LatLng(52.3555, -1.1743),  // UK (centre)
      'ED': LatLng(51.1657, 10.4515),  // Germany (centre)
      'LE': LatLng(40.4637, -3.7492),  // Spain (centre)
      'LI': LatLng(42.5046, 12.6749),  // Italy (centre)
      'EB': LatLng(50.5039, 4.4699),   // Belgium (centre)
      'EH': LatLng(52.1326, 5.2913),   // Netherlands (centre)
      'LS': LatLng(46.8182, 8.2275),   // Switzerland (centre)
      'LO': LatLng(47.5162, 14.5501),  // Austria (centre)
      'EE': LatLng(58.5953, 25.0136),  // Estonia
      'EF': LatLng(61.9241, 25.7482),  // Finland
      'EI': LatLng(53.4129, -8.2439),  // Ireland
      'EK': LatLng(56.2639, 9.5018),   // Denmark
      'EL': LatLng(49.8153, 6.1296),   // Luxembourg
      'EN': LatLng(60.4720, 8.4689),   // Norway
      'EP': LatLng(51.9194, 19.1451),  // Poland
      'ES': LatLng(60.1282, 18.6435),  // Sweden
      'EV': LatLng(56.8796, 24.6032),  // Latvia
      'EY': LatLng(55.1694, 23.8813),  // Lithuania
      'LA': LatLng(41.1533, 20.1683),  // Albania
      'LB': LatLng(42.7339, 25.4858),  // Bulgaria
      'LC': LatLng(35.1264, 33.4299),  // Cyprus
      'LD': LatLng(45.1, 15.2),        // Croatia
      
      // Amérique du Nord
      'K': LatLng(39.8283, -98.5795),  // USA (centre)
      'CY': LatLng(56.1304, -106.3468),// Canada (centre)
      'CZ': LatLng(56.1304, -106.3468),// Canada (autres préfixes)
      'MM': LatLng(23.6345, -102.5528),// Mexico
      
      // Amérique Centrale et Caraïbes
      'MD': LatLng(18.7357, -70.1627), // Dominican Republic
      'MU': LatLng(21.5218, -77.7812), // Cuba
      'TF': LatLng(16.2650, -61.5510), // Guadeloupe/Martinique
      'TI': LatLng(18.3358, -64.8963), // US Virgin Islands
      'TJ': LatLng(18.2208, -66.5901), // Puerto Rico
      'TK': LatLng(17.3578, -62.7830), // Saint Kitts
      'TA': LatLng(17.0608, -61.7964), // Antigua
      'TB': LatLng(13.1939, -59.5432), // Barbados
      'TD': LatLng(15.4150, -61.3710), // Dominica
      'TG': LatLng(12.1165, -61.6790), // Grenada
      
      // Amérique du Sud
      'SB': LatLng(-14.2350, -51.9253),// Brazil (centre)
      'SA': LatLng(-38.4161, -63.6167),// Argentina (centre)
      'SC': LatLng(-35.6751, -71.5430),// Chile (centre)
      'SK': LatLng(4.5709, -74.2973),  // Colombia
      'SE': LatLng(-9.1900, -75.0152), // Peru
      'SV': LatLng(6.4238, -66.5897),  // Venezuela
      
      // Asie
      'RJ': LatLng(36.2048, 138.2529), // Japan (centre)
      'RK': LatLng(35.9078, 127.7669), // South Korea
      'ZB': LatLng(35.8617, 104.1954), // China (nord/centre)
      'ZS': LatLng(31.2304, 121.4737), // China (Shanghai area)
      'ZG': LatLng(23.1291, 113.2644), // China (Guangzhou area)
      'VT': LatLng(15.8700, 100.9925), // Thailand
      'VM': LatLng(14.0583, 108.2772), // Vietnam
      'VV': LatLng(21.0285, 105.8542), // Vietnam (Hanoi area)
      'WM': LatLng(4.2105, 101.9758),  // Malaysia
      'WI': LatLng(-0.7893, 113.9213), // Indonesia
      'WS': LatLng(1.3521, 103.8198),  // Singapore
      'VE': LatLng(22.3964, 114.1095), // Hong Kong area
      'VH': LatLng(22.3193, 114.1694), // Hong Kong
      'RC': LatLng(23.6978, 120.9605), // Taiwan
      'RP': LatLng(12.8797, 121.7740), // Philippines
      'VI': LatLng(20.5937, 78.9629),  // India
      'VG': LatLng(23.6850, 90.3563),  // Bangladesh
      'VN': LatLng(27.7172, 85.3240),  // Nepal
      
      // Moyen-Orient
      'OM': LatLng(23.4241, 53.8478),  // UAE
      'OT': LatLng(25.3548, 51.1839),  // Qatar
      'OE': LatLng(23.8859, 45.0792),  // Saudi Arabia
      'OI': LatLng(32.4279, 53.6880),  // Iran
      'OJ': LatLng(31.9454, 35.9284),  // Jordan
      'OL': LatLng(33.8547, 35.8623),  // Lebanon
      'LL': LatLng(31.0461, 34.8516),  // Israel
      'LT': LatLng(38.9637, 35.2433),  // Turkey
      
      // Afrique
      'FA': LatLng(-28.4793, 24.6727), // South Africa
      'FB': LatLng(-22.3285, 24.6849), // Botswana
      'FC': LatLng(-4.0383, 21.7587),  // Congo
      'FE': LatLng(6.6111, 20.9394),   // Central African Republic
      'FG': LatLng(1.6508, 10.2679),   // Equatorial Guinea
      'FH': LatLng(-12.8864, 40.5132), // Mozambique
      'FI': LatLng(-20.3484, 57.5522), // Mauritius
      'FK': LatLng(7.3697, 12.3547),   // Cameroon
      'FL': LatLng(-13.1339, 27.8493), // Zambia
      'FM': LatLng(-18.7669, 46.8691), // Madagascar
      'FN': LatLng(-11.2027, 17.8739), // Angola
      'FO': LatLng(-0.8037, 11.6094),  // Gabon
      'FP': LatLng(0.1864, 6.6131),    // Sao Tome
      'FQ': LatLng(-18.7669, 46.8691), // Mozambique
      'FS': LatLng(-4.6796, 55.4920),  // Seychelles
      'FT': LatLng(15.4542, 18.7322),  // Chad
      'FV': LatLng(-19.0154, 29.1549), // Zimbabwe
      'FW': LatLng(-13.2543, 34.3015), // Malawi
      'FX': LatLng(-29.6100, 28.2336), // Lesotho
      'FY': LatLng(-22.5597, 17.0832), // Namibia
      'FZ': LatLng(-4.0383, 21.7587),  // DR Congo
      'GA': LatLng(17.5707, -3.9962),  // Mali
      'GB': LatLng(13.4432, -15.3101), // Gambia
      'GC': LatLng(28.2916, -16.6291), // Canary Islands
      'GF': LatLng(8.4606, -11.7799),  // Sierra Leone
      'GG': LatLng(11.8037, -15.1804), // Guinea-Bissau
      'GL': LatLng(6.4281, -9.4295),   // Liberia
      'GM': LatLng(31.7917, -7.0926),  // Morocco
      'GO': LatLng(14.4974, -14.4524), // Senegal
      'GQ': LatLng(21.0079, -10.9408), // Mauritania
      'GU': LatLng(9.9456, -9.6966),   // Guinea
      'GV': LatLng(16.5388, -23.0418), // Cape Verde
      'HA': LatLng(9.1450, 40.4897),   // Ethiopia
      'HB': LatLng(-3.3731, 29.9189),  // Burundi
      'HC': LatLng(5.1521, 46.1996),   // Somalia
      'HD': LatLng(11.8251, 42.5903),  // Djibouti
      'HE': LatLng(26.8206, 30.8025),  // Egypt
      'HH': LatLng(15.1794, 39.7823),  // Eritrea
      'HK': LatLng(-0.0236, 37.9062),  // Kenya
      'HL': LatLng(26.3351, 17.2283),  // Libya
      'HR': LatLng(-1.9403, 29.8739),  // Rwanda
      'HS': LatLng(12.8628, 30.2176),  // Sudan
      'HT': LatLng(-6.3690, 34.8888),  // Tanzania
      'HU': LatLng(1.3733, 32.2903),   // Uganda
      
      // Océanie
      'AG': LatLng(-9.6457, 160.1562), // Solomon Islands
      'AN': LatLng(-0.5228, 166.9315), // Nauru
      'AY': LatLng(-17.7134, 168.3273),// Papua New Guinea
      'NF': LatLng(-18.0150, 178.0650),// Fiji
      'NG': LatLng(1.8709, 173.0329),  // Kiribati
      'NL': LatLng(-13.7590, -177.1560),// Wallis and Futuna
      'NS': LatLng(-19.0544, -169.8672),// Samoa
      'NT': LatLng(-17.7134, -149.4068),// French Polynesia
      'NV': LatLng(-15.3767, 166.9592),// Vanuatu
      'NW': LatLng(-20.9043, 165.6180),// New Caledonia
      'NZ': LatLng(-40.9006, 174.8860),// New Zealand
      'YS': LatLng(-33.8688, 151.2093),// Australia (Sydney area)
      'YM': LatLng(-37.8136, 144.9631),// Australia (Melbourne area)
      'YB': LatLng(-27.4698, 153.0251),// Australia (Brisbane area)
      'YP': LatLng(-31.9505, 115.8605),// Australia (Perth area)
    };
    
    return prefixToCoordinates[prefix];
  }
  
  /// Estime les coordonnées basées sur le pays
  static LatLng? estimateCoordinatesByCountry(String country) {
    if (country.isEmpty) return null;
    
    final normalizedCountry = country.toLowerCase().trim();
    
    final countryCapitals = {
      // Europe
      'france': LatLng(48.8566, 2.3522),
      'lf': LatLng(48.8566, 2.3522),
      'allemagne': LatLng(52.5200, 13.4050),
      'germany': LatLng(52.5200, 13.4050),
      'ed – allemagne (aéroports civils)': LatLng(52.5200, 13.4050),
      'espagne': LatLng(40.4168, -3.7038),
      'spain': LatLng(40.4168, -3.7038),
      'italie': LatLng(41.9028, 12.4964),
      'italy': LatLng(41.9028, 12.4964),
      'li': LatLng(41.9028, 12.4964),
      'royaume-uni': LatLng(51.5074, -0.1278),
      'united kingdom': LatLng(51.5074, -0.1278),
      'eg – royaume-uni': LatLng(51.5074, -0.1278),
      'belgique': LatLng(50.8503, 4.3517),
      'belgium': LatLng(50.8503, 4.3517),
      'eb – belgique': LatLng(50.8503, 4.3517),
      'pays-bas': LatLng(52.3676, 4.9041),
      'netherlands': LatLng(52.3676, 4.9041),
      'eh – pays-bas': LatLng(52.3676, 4.9041),
      'suisse': LatLng(46.9480, 7.4474),
      'switzerland': LatLng(46.9480, 7.4474),
      
      // Amérique
      'canada': LatLng(45.4215, -75.6972),
      'cy': LatLng(45.4215, -75.6972),
      'cz': LatLng(45.4215, -75.6972),
      'unknown': LatLng(45.4215, -75.6972), // Traite "Unknown" comme Canada pour les codes CY
      
      // Autres pays...
      'brésil': LatLng(-15.7975, -47.8919),
      'brazil': LatLng(-15.7975, -47.8919),
      'japon': LatLng(35.6762, 139.6503),
      'japan': LatLng(35.6762, 139.6503),
    };
    
    // Recherche exacte
    if (countryCapitals.containsKey(normalizedCountry)) {
      return countryCapitals[normalizedCountry];
    }
    
    // Recherche partielle
    for (var entry in countryCapitals.entries) {
      if (normalizedCountry.contains(entry.key) || entry.key.contains(normalizedCountry)) {
        return entry.value;
      }
    }
    
    return null;
  }
  
  /// Méthode intelligente avec fallback multiple
  static Future<LatLng?> getCoordinatesWithFallback(String oaci, String? countryName) async {
    await loadAirportsFromJson();
    
    // 1. Coordonnées hardcodées (priorité maximale)
    if (_airportCoordinates.containsKey(oaci)) {
      return _airportCoordinates[oaci];
    }
    
    // 2. Estimation par préfixe OACI
    var coords = estimateCoordinatesByOACIPrefix(oaci);
    if (coords != null) {
      print('📍 Coordonnées estimées par préfixe OACI pour $oaci: $coords');
      return coords;
    }
    
    // 3. Estimation par pays
    if (countryName != null && countryName.isNotEmpty) {
      coords = estimateCoordinatesByCountry(countryName);
      if (coords != null) {
        print('📍 Coordonnées estimées par pays pour $oaci ($countryName): $coords');
        return coords;
      }
    }
    
    return null;
  }
  
  /// Calcule la distance entre deux aéroports
  static Future<double> calculateDistance(String oaci1, String oaci2) async {
    final coords1 = await getCoordinates(oaci1);
    final coords2 = await getCoordinates(oaci2);
    
    if (coords1 == null || coords2 == null) {
      return 0.0;
    }
    
    return const Distance().distance(coords1, coords2);
  }
  
  /// Trouve l'aéroport le plus proche d'une position donnée
  static String? findNearestAirport(LatLng position) {
    String? nearestOaci;
    double minDistance = double.infinity;
    
    for (var entry in _airportCoordinates.entries) {
      final distance = const Distance().distance(position, entry.value);
      if (distance < minDistance) {
        minDistance = distance;
        nearestOaci = entry.key;
      }
    }
    
    return nearestOaci;
  }
}