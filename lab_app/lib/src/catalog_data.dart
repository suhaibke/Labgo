import 'models.dart';

// Generated from the design data (sH = catalog, _6 = packages).
const kCatalog = <CatalogTest>[
  CatalogTest(
    name: 'CBC',
    price: 15000,
    priceB2B: 12000,
    category: 'General',
    on: true,
    units: 'g/dL',
    normalText: '',
    ranges: [
      RangeRow('0', '30', 'D', 'Both', '11', '14'),
      RangeRow('1', '12', 'M', 'Both', '12', '15'),
      RangeRow('18', '99', 'Y', 'Both', '12', '16'),
    ],
  ),
  CatalogTest(
    name: 'Sugar',
    price: 10000,
    priceB2B: 8000,
    category: 'General',
    on: true,
    units: 'mg/dL',
    normalText: '',
    ranges: [
      RangeRow('0', '30', 'D', 'Both', '60', '100'),
      RangeRow('1', '12', 'M', 'Both', '70', '110'),
      RangeRow('18', '99', 'Y', 'Both', '70', '99'),
    ],
  ),
  CatalogTest(
    name: 'Vitamin D',
    price: 40000,
    priceB2B: 32000,
    category: 'Vitamins',
    on: true,
    units: 'ng/mL',
    normalText: '',
    ranges: [
      RangeRow('0', '30', 'D', 'Male', '20', '50'),
      RangeRow('1', '12', 'M', 'Female', '25', '60'),
      RangeRow('18', '99', 'Y', 'Both', '30', '100'),
    ],
  ),
  CatalogTest(
    name: 'Hormone',
    price: 60000,
    priceB2B: 48000,
    category: 'Hormones',
    on: false,
    units: 'ng/dL',
    normalText: '',
    ranges: [
      RangeRow('0', '30', 'D', 'Both', '200', '800'),
      RangeRow('1', '12', 'M', 'Both', '300', '900'),
      RangeRow('18', '99', 'Y', 'Both', '300', '1000'),
    ],
  ),
  CatalogTest(
    name: 'Lipid',
    price: 35000,
    priceB2B: 28000,
    category: 'General',
    on: true,
    units: 'mg/dL',
    normalText: '',
    ranges: [
      RangeRow('0', '30', 'D', 'Both', '100', '170'),
      RangeRow('1', '12', 'M', 'Both', '120', '180'),
      RangeRow('18', '99', 'Y', 'Both', '0', '200'),
    ],
  ),
  CatalogTest(
    name: 'Thyroid',
    price: 45000,
    priceB2B: 36000,
    category: 'Thyroid',
    on: true,
    units: 'µIU/mL',
    normalText: '',
    ranges: [
      RangeRow('0', '30', 'D', 'Both', '0.7', '6'),
      RangeRow('1', '12', 'M', 'Both', '0.5', '5'),
      RangeRow('18', '99', 'Y', 'Both', '0.4', '4'),
    ],
  ),
];

const kPackages = <LabPackage>[
  LabPackage(
    id: 'pkg-hair',
    code: 'HAIR-01',
    name: 'Hair Loss',
    category: 'Hair Loss',
    aliases: ['تساقط الشعر', 'کەوتنی قژ'],
    tests: ['CBC', 'Vitamin D', 'Thyroid'],
    price: 95000,
    priceB2B: 76000,
    active: true,
  ),
  LabPackage(
    id: 'pkg-vitamins',
    code: 'VIT-02',
    name: 'Vitamins',
    category: 'Vitamins',
    aliases: ['فيتامينات', 'ڤیتامینەکان'],
    tests: ['Vitamin D', 'CBC'],
    price: 65000,
    priceB2B: 52000,
    active: true,
  ),
  LabPackage(
    id: 'pkg-full',
    code: 'FULL-03',
    name: 'Full Checkup',
    category: 'Full Checkup',
    aliases: ['فحص شامل', 'پشکنینی تەواو'],
    tests: ['CBC', 'Sugar', 'Vitamin D', 'Lipid', 'Thyroid'],
    price: 120000,
    priceB2B: 96000,
    active: true,
  ),
  LabPackage(
    id: 'pkg-thyroid',
    code: 'THY-04',
    name: 'Thyroid',
    category: 'Thyroid',
    aliases: ['الغدة', 'غودە'],
    tests: ['Thyroid'],
    price: 45000,
    priceB2B: 36000,
    active: true,
  ),
  LabPackage(
    id: 'pkg-offer',
    code: 'OFFER-05',
    name: 'Offer Package',
    isOffer: true,
    category: 'Offer',
    aliases: ['باقة العروض', 'پاکێجی ئۆفەر'],
    tests: ['CBC', 'Sugar', 'Vitamin D'],
    price: 75000,
    priceB2B: 60000,
    active: true,
  ),
];

/// Fallback prices when a test is not in the catalog (design `nw`).
const kFallbackPrices = {
  'CBC': 15000,
  'Sugar': 10000,
  'Vitamin D': 40000,
  'Hormone': 60000,
  'Lipid': 35000,
  'Thyroid': 45000,
};

/// Treating doctors suggested in Add Patient (design `rw`).
const kDoctors = ['Dr. Ahmed', 'Dr. Sara', 'Dr. Omar'];

int testPrice(String name, String mode) {
  for (final c in kCatalog) {
    if (c.name == name)
      return mode == 'B2B' ? (c.priceB2B != 0 ? c.priceB2B : c.price) : c.price;
  }
  return kFallbackPrices[name] ?? 0;
}

int packagePrice(LabPackage p, String mode) {
  if (mode != 'B2B') return p.price;
  if (p.priceB2B != 0) return p.priceB2B;
  return p.tests.fold(0, (a, t) => a + testPrice(t, 'B2B'));
}
