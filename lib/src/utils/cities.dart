/// Iraqi cities for the LabGo app
/// These cities are used for user registration and filtering

class City {
  final String id;
  final String nameAr;
  final String nameEn;
  final String nameKu;
  final String nameTr;

  const City({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.nameKu,
    required this.nameTr,
  });

  /// Get the localized name based on locale code
  String getLocalizedName(String localeCode) {
    switch (localeCode) {
      case 'ar':
        return nameAr;
      case 'ku':
        return nameKu;
      case 'tr':
        return nameTr;
      default:
        return nameEn;
    }
  }
}

/// List of all 18 Iraqi governorates/cities
const List<City> iraqiCities = [
  City(
    id: 'baghdad',
    nameAr: 'بغداد',
    nameEn: 'Baghdad',
    nameKu: 'بەغدا',
    nameTr: 'Bağdat',
  ),
  City(
    id: 'basra',
    nameAr: 'البصرة',
    nameEn: 'Basra',
    nameKu: 'بەسرە',
    nameTr: 'Basra',
  ),
  City(
    id: 'ninawa',
    nameAr: 'نينوى',
    nameEn: 'Nineveh',
    nameKu: 'نەینەوا',
    nameTr: 'Ninova',
  ),
  City(
    id: 'anbar',
    nameAr: 'الأنبار',
    nameEn: 'Al-Anbar',
    nameKu: 'ئەنبار',
    nameTr: 'Anbar',
  ),
  City(
    id: 'kirkuk',
    nameAr: 'كركوك',
    nameEn: 'Kirkuk',
    nameKu: 'کەرکووک',
    nameTr: 'Kerkük',
  ),
  City(
    id: 'salahadin',
    nameAr: 'صلاح الدين',
    nameEn: 'Salah ad-Din',
    nameKu: 'سەلاحەدین',
    nameTr: 'Selahaddin',
  ),
  City(
    id: 'diyala',
    nameAr: 'ديالى',
    nameEn: 'Diyala',
    nameKu: 'دیالە',
    nameTr: 'Diyala',
  ),
  City(
    id: 'babel',
    nameAr: 'بابل',
    nameEn: 'Babylon',
    nameKu: 'بابل',
    nameTr: 'Babil',
  ),
  City(
    id: 'karbala',
    nameAr: 'كربلاء',
    nameEn: 'Karbala',
    nameKu: 'کەربەلا',
    nameTr: 'Kerbela',
  ),
  City(
    id: 'najaf',
    nameAr: 'النجف',
    nameEn: 'Najaf',
    nameKu: 'نەجەف',
    nameTr: 'Necef',
  ),
  City(
    id: 'qadisiyah',
    nameAr: 'القادسية',
    nameEn: 'Al-Qadisiyyah',
    nameKu: 'قادسیە',
    nameTr: 'Kadisiye',
  ),
  City(
    id: 'muthanna',
    nameAr: 'المثنى',
    nameEn: 'Al-Muthanna',
    nameKu: 'موسەننا',
    nameTr: 'Müsenna',
  ),
  City(
    id: 'wasit',
    nameAr: 'واسط',
    nameEn: 'Wasit',
    nameKu: 'واسط',
    nameTr: 'Vasıt',
  ),
  City(
    id: 'thiqar',
    nameAr: 'ذي قار',
    nameEn: 'Dhi Qar',
    nameKu: 'زیقار',
    nameTr: 'Zikar',
  ),
  City(
    id: 'maysan',
    nameAr: 'ميسان',
    nameEn: 'Maysan',
    nameKu: 'میسان',
    nameTr: 'Meysan',
  ),
  City(
    id: 'erbil',
    nameAr: 'أربيل',
    nameEn: 'Erbil',
    nameKu: 'هەولێر',
    nameTr: 'Erbil',
  ),
  City(
    id: 'sulaymaniyah',
    nameAr: 'السليمانية',
    nameEn: 'Sulaymaniyah',
    nameKu: 'سلێمانی',
    nameTr: 'Süleymaniye',
  ),
  City(
    id: 'duhok',
    nameAr: 'دهوك',
    nameEn: 'Duhok',
    nameKu: 'دهۆک',
    nameTr: 'Duhok',
  ),
];

/// Get a city by its Arabic name (used for backend communication)
City? getCityByArabicName(String nameAr) {
  try {
    return iraqiCities.firstWhere((city) => city.nameAr == nameAr);
  } catch (e) {
    return null;
  }
}

/// Get a city by its ID
City? getCityById(String id) {
  try {
    return iraqiCities.firstWhere((city) => city.id == id);
  } catch (e) {
    return null;
  }
}
