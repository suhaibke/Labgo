const mongoose = require('mongoose');
const Category = require('../models/Category');
const Product = require('../models/Product');
const ShopOrder = require('../models/ShopOrder');

// Sample User ID (replace with actual admin user ID when seeding)
const ADMIN_USER_ID = new mongoose.Types.ObjectId();

// Helper to generate unique order number
function generateOrderNumber(suffix) {
    const date = new Date();
    const dateStr = date.toISOString().slice(0, 10).replace(/-/g, '');
    return `SHP-${dateStr}-${suffix}`;
}

// =====================================================
// CATEGORIES
// =====================================================
const categories = [
    {
        name: {
            en: 'Medical Devices',
            ar: 'الأجهزة الطبية',
            ku: 'ئامرازە پزیشکییەکان'
        },
        description: {
            en: 'Professional medical equipment and devices for healthcare',
            ar: 'معدات وأجهزة طبية مهنية للرعاية الصحية',
            ku: 'ئامراز و کەلوپەلی پزیشکییی پیشەیی بۆ چاودێری تەندروستی'
        },
        image: '/images/categories/medical-devices.jpg',
        displayOrder: 1,
        status: 'active',
        slug: 'medical-devices',
        createdBy: ADMIN_USER_ID
    },
    {
        name: {
            en: 'Lab Supplies',
            ar: 'مستلزمات المختبر',
            ku: 'خەرجی لابۆراتۆری'
        },
        description: {
            en: 'Laboratory consumables and supplies',
            ar: 'مستهلكات ومستلزمات المختبر',
            ku: 'مادە بەکارھێنراوەکانی لابۆراتۆری'
        },
        image: '/images/categories/lab-supplies.jpg',
        displayOrder: 2,
        status: 'active',
        slug: 'lab-supplies',
        createdBy: ADMIN_USER_ID
    },
    {
        name: {
            en: 'Diagnostic Tools',
            ar: 'أدوات التشخيص',
            ku: 'ئامرازی دەستنیشانکردن'
        },
        description: {
            en: 'Diagnostic and testing equipment',
            ar: 'معدات التشخيص والاختبار',
            ku: 'ئامرازی دەستنیشانکردن و تێستکردن'
        },
        image: '/images/categories/diagnostic.jpg',
        displayOrder: 3,
        status: 'active',
        slug: 'diagnostic-tools',
        createdBy: ADMIN_USER_ID
    },
    {
        name: {
            en: 'Safety Equipment',
            ar: 'معدات السلامة',
            ku: 'کەلوپەلی پاراستن'
        },
        description: {
            en: 'Personal protective equipment and safety gear',
            ar: 'معدات الوقاية الشخصية ومعدات السلامة',
            ku: 'کەلوپەلی پاراستنی کەسی و ئامرازی پاراستن'
        },
        image: '/images/categories/safety.jpg',
        displayOrder: 4,
        status: 'active',
        slug: 'safety-equipment',
        createdBy: ADMIN_USER_ID
    },
    {
        name: {
            en: 'Patient Care',
            ar: 'رعاية المرضى',
            ku: 'چاودێری نەخۆش'
        },
        description: {
            en: 'Patient care essentials and comfort items',
            ar: 'أساسيات ورعاية راحة المرضى',
            ku: 'پێداویتی چاودێری نەخۆش و شتی ئارامی'
        },
        image: '/images/categories/patient-care.jpg',
        displayOrder: 5,
        status: 'active',
        slug: 'patient-care',
        createdBy: ADMIN_USER_ID
    }
];

// =====================================================
// PRODUCTS
// =====================================================
const products = [
    // Medical Devices
    {
        name: {
            en: 'Digital Blood Pressure Monitor',
            ar: 'جهاز قياس ضغط الدم الرقمي',
            ku: 'ئامرازی دیجیتاڵی پەستانی خوێن'
        },
        description: {
            en: 'Professional digital blood pressure monitor with irregular heartbeat detection. Large LCD display with date and time function. Memory for 90 readings.',
            ar: 'جهاز رقمي لقياس ضغط الدم مع كشف عدم انتظام ضربات القلب. شاشة LCD كبيرة مع وظيفة التاريخ والوقت. ذاكرة لـ 90 قراءة.',
            ku: 'ئامرازی دیجیتاڵی پزیشکی بۆ پەستانی خوێن لەگەڵ دەستنیشانکردنی ناڕێکی لێدانی دڵ. پشاندانێکی LCDی گەورە لەگەڵ فەنکشنی بەروار و کات. بیرگە بۆ 90 خوێندنەوە.'
        },
        shortDescription: {
            en: 'Professional digital BP monitor with memory',
            ar: 'شاشة رقمية احترافية مع ذاكرة',
            ku: 'ئامرازی دیجیتاڵی BPی پیشەیی لەگەڵ بیرگە'
        },
        categoryRef: 'Medical Devices', // Will be replaced with actual ID
        slug: 'digital-blood-pressure-monitor',
        images: [
            { url: '/images/products/bp-monitor-1.jpg', alt: 'Blood Pressure Monitor Front', isPrimary: true },
            { url: '/images/products/bp-monitor-2.jpg', alt: 'Blood Pressure Monitor Side', isPrimary: false }
        ],
        price: 45000,
        compareAtPrice: 55000,
        inventory: { trackInventory: true, quantity: 25, lowStockThreshold: 5 },
        status: 'active',
        isFeatured: true,
        tags: ['blood-pressure', 'monitor', 'diagnostic', 'home-care'],
        specifications: [
            { key: { en: 'Display', ar: 'الشاشة', ku: 'پشاندان' }, value: { en: 'LCD 3.2 inch', ar: 'شاشة 3.2 بوصة', ku: 'LCD 3.2 ئینج' } },
            { key: { en: 'Memory', ar: 'الذاكرة', ku: 'بیرگە' }, value: { en: '90 readings', ar: '90 قراءة', ku: '90 خوێندنەوە' } },
            { key: { en: 'Power', ar: 'التشغيل', ku: 'work' }, value: { en: 'Battery / AC Adapter', ar: 'بطارية / محول', ku: 'باتری / گۆڕەر' } }
        ],
        createdBy: ADMIN_USER_ID
    },
    {
        name: {
            en: 'Pulse Oximeter',
            ar: 'مقياس تشبع الأكسجين',
            ku: 'ئامرازی ئۆکسیجینی خوێن'
        },
        description: {
            en: 'Compact finger pulse oximeter for measuring blood oxygen saturation (SpO2) and pulse rate. LED display with low battery indicator.',
            ar: 'مقياس تشبع الأكسجين أصبع compact لقياس تشبع أكسجين الدم (SpO2) ومعدل النبض. شاشة LED مع مؤشر بطارية منخفضة.',
            ku: 'ئامرازی ئۆکسیجینی خوێنی بچووک بۆ پەنجە بۆ پێوانی تێکڕای ئۆکسیجینی خوێن (SpO2) و تێکڕای لێدان. پشاندانی LED لەگەڵ نیشانەری باتریی نزم.'
        },
        shortDescription: {
            en: 'Finger pulse oximeter with LED display',
            ar: 'مقياس الأكسجين للإصبع بشاشة LED',
            ku: 'ئامرازی ئۆکسیجینی پەنجە بە پشاندانی LED'
        },
        categoryRef: 'Medical Devices',
        slug: 'pulse-oximeter',
        images: [
            { url: '/images/products/oximeter-1.jpg', alt: 'Pulse Oximeter', isPrimary: true }
        ],
        price: 15000,
        compareAtPrice: 18000,
        inventory: { trackInventory: true, quantity: 50, lowStockThreshold: 10 },
        status: 'active',
        isFeatured: true,
        tags: ['oximeter', 'oxygen', 'monitor', 'diagnostic'],
        specifications: [
            { key: { en: 'SpO2 Range', ar: 'مدى SpO2', ku: 'SpO2 Range' }, value: { en: '0-100%', ar: '0-100٪', ku: '0-100%' } },
            { key: { en: 'PR Range', ar: 'مدى النبض', ku: 'لێدان Range' }, value: { en: '25-250 BPM', ar: '25-250 نبضة/دقيقة', ku: '25-250 BPM' } }
        ],
        createdBy: ADMIN_USER_ID
    },
    {
        name: {
            en: 'Digital Thermometer',
            ar: 'ترمومتر رقمي',
            ku: 'ترمومەترێکی دیجیتاڵی'
        },
        description: {
            en: 'Fast and accurate digital thermometer with fever alarm. Waterproof design with auto shut-off.',
            ar: 'ترمومتر رقمي سريع ودقيق مع إنذار الحمى. تصميم مقاوم للماء مع إيقاف تلقائي.',
            ku: 'ترمومەترێکی دیجیتاڵی خێرا و ورد لەگەڵ ئاگادارکەرەوەی تا. دیزاین بەرگ لەگەڵ داخستنی خۆکار.'
        },
        shortDescription: {
            en: 'Fast digital thermometer with fever alarm',
            ar: 'ترمومتر رقمي سريع مع إنذار الحمى',
            ku: 'ترمومەتری دیجیتاڵی خێرا لەگەڵ ئاگادارکەرەوەی تا'
        },
        categoryRef: 'Medical Devices',
        slug: 'digital-thermometer',
        images: [
            { url: '/images/products/thermometer-1.jpg', alt: 'Digital Thermometer', isPrimary: true }
        ],
        price: 8000,
        inventory: { trackInventory: true, quantity: 100, lowStockThreshold: 20 },
        status: 'active',
        tags: ['thermometer', 'fever', 'diagnostic'],
        specifications: [
            { key: { en: 'Measurement Time', ar: 'وقت القياس', ku: 'کاتی پێوان' }, value: { en: '10-60 seconds', ar: '10-60 ثانية', ku: '10-60 چرکە' } },
            { key: { en: 'Temperature Range', ar: 'مدى درجة الحرارة', ku: 'گەرمی Range' }, value: { en: '32-42.9°C', ar: '32-42.9 درجة مئوية', ku: '32-42.9°C' } }
        ],
        createdBy: ADMIN_USER_ID
    },

    // Lab Supplies
    {
        name: {
            en: 'Medical Examination Gloves (Box of 100)',
            ar: 'قفازات فحص طبي (علبة 100 قطعة)',
            ku: 'دەستکێشتی پشکنینی پزیشکی (سنووق 100 دانە)'
        },
        description: {
            en: 'Powder-free latex examination gloves. Ambidextrous design with beaded cuff for easy donning. Non-sterile.',
            ar: 'قفازات فحص خالية من المساحيق من اللاتكس. تصميم متعدد الاستخدامات مع كفة ملفوفة للارتداء السهل. غير معقم.',
            ku: 'دەستکێشتی پشکنینی بێ پەڕ بە لاتێکس. دیزاینی دەستی دوو لایەن لەگەڵ دەستکێشتی بچووک بۆ لەبەرکردنی ئاسان. نا-پزیشکی.'
        },
        shortDescription: {
            en: 'Powder-free latex gloves, 100 pieces',
            ar: 'قفازات خالية من المساحيق، 100 قطعة',
            ku: 'دەستکێشتی بێ پەڕ، 100 دانە'
        },
        categoryRef: 'Lab Supplies',
        slug: 'medical-examination-gloves',
        images: [
            { url: '/images/products/gloves-1.jpg', alt: 'Medical Gloves', isPrimary: true }
        ],
        price: 5000,
        inventory: { trackInventory: true, quantity: 200, lowStockThreshold: 50 },
        status: 'active',
        isFeatured: true,
        tags: ['gloves', 'latex', 'examination', 'protection'],
        specifications: [
            { key: { en: 'Material', ar: 'المادة', ku: 'ماددە' }, value: { en: 'Latex', ar: 'لاتكس', ku: 'لاتێکس' } },
            { key: { en: 'Quantity', ar: 'الكمية', ku: 'ژمارە' }, value: { en: '100 pieces', ar: '100 قطعة', ku: '100 دانە' } }
        ],
        createdBy: ADMIN_USER_ID
    },
    {
        name: {
            en: 'Surgical Face Masks (Pack of 50)',
            ar: 'كمامات جراحية (حزمة 50 قطعة)',
            ku: 'ماسکی نەشتەرگەری (پاکێت 50 دانە)'
        },
        description: {
            en: '3-ply disposable surgical face masks with ear loops. Fluid resistant and breathable.',
            ar: 'كمامات جراحية قابلة للإزمال من 3 طبقات مع علق للأذن. مقاومة للسوائل وقابلة للتنفس.',
            ku: 'ماسکی ڕووپۆشی نەشتەرگەری یەکجاری 3 لایەن لەگەڵ هەڵقوڵانی گوێ. بەرگ لە دەست و وقام.'
        },
        shortDescription: {
            en: '3-ply surgical masks, 50 pieces',
            ar: 'كمامات جراحية 3 طبقات، 50 قطعة',
            ku: 'ماسکی نەشتەرگەری 3 لایەن، 50 دانە'
        },
        categoryRef: 'Lab Supplies',
        slug: 'surgical-face-masks',
        images: [
            { url: '/images/products/masks-1.jpg', alt: 'Face Masks', isPrimary: true }
        ],
        price: 12000,
        inventory: { trackInventory: true, quantity: 150, lowStockThreshold: 30 },
        status: 'active',
        isFeatured: true,
        tags: ['masks', 'surgical', 'protection', 'disposable'],
        specifications: [
            { key: { en: 'Layers', ar: 'الطبقات', ku: 'لایەن' }, value: { en: '3-ply', ar: '3 طبقات', ku: '3-لایەن' } },
            { key: { en: 'Quantity', ar: 'الكمية', ku: 'ژمارە' }, value: { en: '50 pieces', ar: '50 قطعة', ku: '50 دانە' } }
        ],
        createdBy: ADMIN_USER_ID
    },
    {
        name: {
            en: 'Alcohol Swabs (Box of 100)',
            ar: 'مناديل كحول (علبة 100 قطعة)',
            ku: 'پاککەرەوەی ئەلکڕۆڵ (سنووق 100 دانە)'
        },
        description: {
            en: 'Isopropyl alcohol 70% swabs for skin preparation. Individually wrapped.',
            ar: 'مناديل كحول أيزوبروبيل 70٪ لتحضير الجلد. ملفوفة بشكل فردي.',
            ku: 'پاککەرەوەی ئەلکڕۆڵی ئایزۆپڕۆپیل 70٪ بۆ ئامادەکردنی پێست. بە تاکەکەیی داپۆشراون.'
        },
        shortDescription: {
            en: '70% isopropyl alcohol swabs, 100 pieces',
            ar: 'مناديل كحول 70٪، 100 قطعة',
            ku: 'پاککەرەوەی ئەلکڕۆڵ 70٪، 100 دانە'
        },
        categoryRef: 'Lab Supplies',
        slug: 'alcohol-swabs',
        images: [
            { url: '/images/products/swabs-1.jpg', alt: 'Alcohol Swabs', isPrimary: true }
        ],
        price: 6000,
        inventory: { trackInventory: true, quantity: 300, lowStockThreshold: 50 },
        status: 'active',
        tags: ['alcohol', 'swabs', 'disinfectant', 'supplies'],
        specifications: [
            { key: { en: 'Alcohol Content', ar: 'محتوى الكحول', ku: 'ئەلکڕۆڵ' }, value: { en: '70% Isopropyl', ar: '70٪ أيزوبروبيل', ku: '70% Isopropyl' } },
            { key: { en: 'Quantity', ar: 'الكمية', ku: 'ژمارە' }, value: { en: '100 pieces', ar: '100 قطعة', ku: '100 دانە' } }
        ],
        createdBy: ADMIN_USER_ID
    },

    // Diagnostic Tools
    {
        name: {
            en: 'Professional Stethoscope',
            ar: 'سماعة الطبيب المهنية',
            ku: 'ستێتۆسکۆپی پیشەیی'
        },
        description: {
            en: 'High-quality acoustic stethoscope with dual-sided chest piece. Includes spare ear tips and diaphragm.',
            ar: 'سماعة عازلة عالية الجودة مع قطعة صدر مزدوجة الجانبين. تشمل أطراف أذن احتياطية والغشاء.',
            ku: 'ستێتۆسکۆپی دەنگی بەرز لەگەڵ پارچەی سینگ دوو لایەن. ئەنجامی زەویی تەنزا و تەنزا.'
        },
        shortDescription: {
            en: 'Professional acoustic stethoscope',
            ar: 'سماعة عازلة احترافية',
            ku: 'ستێتۆسکۆپی دەنگی پیشەیی'
        },
        categoryRef: 'Diagnostic Tools',
        slug: 'professional-stethoscope',
        images: [
            { url: '/images/products/stethoscope-1.jpg', alt: 'Stethoscope', isPrimary: true }
        ],
        price: 35000,
        compareAtPrice: 45000,
        inventory: { trackInventory: true, quantity: 15, lowStockThreshold: 5 },
        status: 'active',
        isFeatured: true,
        tags: ['stethoscope', 'diagnostic', 'professional'],
        specifications: [
            { key: { en: 'Chest Piece', ar: 'قطعة الصدر', ku: 'پارچەی سینگ' }, value: { en: 'Dual-sided', ar: 'مزدوجة الجانبين', ku: 'دوو لایەن' } },
            { key: { en: 'Tube Length', ar: 'طول الأنبوب', ku: 'درێژی ئاهەنگ' }, value: { en: '27 inches', ar: '27 بوصة', ku: '27 ئینج' } }
        ],
        createdBy: ADMIN_USER_ID
    },
    {
        name: {
            en: 'Medical Penlight',
            ar: 'مصباح طبي قلمي',
            ku: 'فۆنێری پزیشکی'
        },
        description: {
            en: 'LED medical penlight for pupil examination and general assessment. Includes pupil gauge imprint. Batteries included.',
            ar: 'مصباح طبي LED لفحص البؤبؤ والتقييم العام. يتضمن علامة قياس البؤبؤ. البطاريات مشمولة.',
            ku: 'فۆنێری پزیشکی LED بۆ پشکنینی قۆڵە و تەماشای گشتی. بریتیە لە نیشانەری قۆڵە. باترییەکان تێدایە.'
        },
        shortDescription: {
            en: 'LED penlight with pupil gauge',
            ar: 'مصباح LED مع علامة قياس البؤبؤ',
            ku: 'فۆنێری LED لەگەڵ پێوانی قۆڵە'
        },
        categoryRef: 'Diagnostic Tools',
        slug: 'medical-penlight',
        images: [
            { url: '/images/products/penlight-1.jpg', alt: 'Medical Penlight', isPrimary: true }
        ],
        price: 5000,
        inventory: { trackInventory: true, quantity: 80, lowStockThreshold: 15 },
        status: 'active',
        tags: ['penlight', 'diagnostic', 'pupil', 'led'],
        specifications: [
            { key: { en: 'Light Type', ar: 'نوع الضوء', ku: 'جۆری ڕووناکی' }, value: { en: 'LED', ar: 'LED', ku: 'LED' } },
            { key: { en: 'Batteries', ar: 'ال batteries', ku: 'باتری' }, value: { en: 'AAA included', ar: 'AAA مشمولة', ku: 'AAA تێدایە' } }
        ],
        createdBy: ADMIN_USER_ID
    },

    // Safety Equipment
    {
        name: {
            en: 'Isolation Gown',
            ar: 'رداء عزل',
            ku: 'جلێنی جیاکردنەوە'
        },
        description: {
            en: 'Disposable fluid-resistant isolation gown with ties at neck and waist. One size fits most. Non-sterile.',
            ar: 'رداء عزل قابل للإزمال مقاوم للسوائل مع ربطات عند الرقبة والخصر. مقاس واحد يناسب الغالبية. غير معقم.',
            ku: 'جلێنی جیاکردنەوەی یەکجاری بەرگ لە دەست لەگەڵ بەستن لە مل و مێشک. یەک قەبارە زۆرینەی دەگرێتەوە. نا-پزیشکی.'
        },
        shortDescription: {
            en: 'Fluid-resistant disposable isolation gown',
            ar: 'رداء عزل مقاوم للسوائل قابل للإزمال',
            ku: 'جلێنی جیاکردنەوەی بەرگ لە دەست یەکجاری'
        },
        categoryRef: 'Safety Equipment',
        slug: 'isolation-gown',
        images: [
            { url: '/images/products/gown-1.jpg', alt: 'Isolation Gown', isPrimary: true }
        ],
        price: 3000,
        inventory: { trackInventory: true, quantity: 100, lowStockThreshold: 20 },
        status: 'active',
        tags: ['gown', 'isolation', 'protection', 'disposable'],
        specifications: [
            { key: { en: 'Size', ar: 'الحجم', ku: 'قەبارە' }, value: { en: 'One size', ar: 'مقاس واحد', ku: 'یەک قەبارە' } },
            { key: { en: 'Fluid Resistance', ar: 'مقاومة السوائل', ku: 'بەرگ لە دەست' }, value: { en: 'Yes', ar: 'نعم', ku: 'بەڵێ' } }
        ],
        createdBy: ADMIN_USER_ID
    },
    {
        name: {
            en: 'Face Shield',
            ar: 'درع الوجه',
            ku: 'پەپکەی ڕوو'
        },
        description: {
            en: 'Reusable full-face protection shield with adjustable headband. Anti-fog PET film. Can be worn over glasses and masks.',
            ar: 'درع حماية الوجه قابل لإعادة الاستخدام مع عاصفة الرأس القابلة للتعديل. فيلم PET ضد الضباب. يمكن ارتداؤه فوق النظارات والأقنعة.',
            ku: 'پەپکەی پاراستنی ڕووپۆشی تەواو قەبارەی جارێک دیاری بەپێی سەر. فیلمی PET بەرگ لە دڵەودەیی. دەکرێت لەسەر عەینک و ماسک بەکرێت.'
        },
        shortDescription: {
            en: 'Reusable full-face shield with anti-fog',
            ar: 'درع وجه قابل لإعادة الاستخدام ضد الضباب',
            ku: 'پەپکەی ڕووپۆشی تەواو قەبارەی جارێک لەگەڵ بەرگ لە دڵەودەیی'
        },
        categoryRef: 'Safety Equipment',
        slug: 'face-shield',
        images: [
            { url: '/images/products/face-shield-1.jpg', alt: 'Face Shield', isPrimary: true }
        ],
        price: 7500,
        inventory: { trackInventory: true, quantity: 60, lowStockThreshold: 10 },
        status: 'active',
        tags: ['face-shield', 'protection', 'reusable', 'ppe'],
        specifications: [
            { key: { en: 'Material', ar: 'المادة', ku: 'ماددە' }, value: { en: 'PET Film', ar: 'فيلم PET', ku: 'فیلمی PET' } },
            { key: { en: 'Anti-fog', ar: 'ضد الضباب', ku: 'بەرگ لە دڵەودەیی' }, value: { en: 'Yes', ar: 'نعم', ku: 'بەڵێ' } }
        ],
        createdBy: ADMIN_USER_ID
    },

    // Patient Care
    {
        name: {
            en: 'Compression Socks (Pair)',
            ar: 'جوارب الضغط (زوج)',
            ku: 'جورابەی پەستان (جۆرێک)'
        },
        description: {
            en: 'Medical-grade compression socks for improved circulation. 15-20 mmHg compression level. Available in multiple sizes.',
            ar: 'جوارب ضغط من الدرجة الطبية لتحسين الدورة الدموية. مستوى ضغط 15-20 مم زئبق. متاحة بأحجام متعددة.',
            ku: 'جورابەی پەستانی پلەی پزیشکی بۆ باشتر کردنی خولانە. ئاستی پەستانی 15-20 mmHg. لە قەبارەی جۆراوجۆردا.'
        },
        shortDescription: {
            en: 'Medical compression socks 15-20 mmHg',
            ar: 'جوارب ضغط طبي 15-20 مم زئبق',
            ku: 'جورابەی پەستانی پزیشکی 15-20 mmHg'
        },
        categoryRef: 'Patient Care',
        slug: 'compression-socks',
        images: [
            { url: '/images/products/compression-socks-1.jpg', alt: 'Compression Socks', isPrimary: true }
        ],
        price: 18000,
        inventory: { trackInventory: true, quantity: 40, lowStockThreshold: 10 },
        status: 'active',
        tags: ['compression', 'socks', 'circulation', 'patient-care'],
        specifications: [
            { key: { en: 'Compression', ar: 'الضغط', ku: 'پەستان' }, value: { en: '15-20 mmHg', ar: '15-20 مم زئبق', ku: '15-20 mmHg' } },
            { key: { en: 'Material', ar: 'المادة', ku: 'ماددە' }, value: { en: 'Nylon/Spandex blend', ar: 'خليط نايلون/إسباندكس', ku: 'خەلتی نایلۆن/سپاندێکس' } }
        ],
        createdBy: ADMIN_USER_ID
    },
    {
        name: {
            en: 'Hot & Cold Therapy Pack',
            ar: 'حزمة العلاج الساخن والبارد',
            ku: 'پاکێتی چارەسەری گەرم و سارد'
        },
        description: {
            en: 'Reusable gel pack for hot or cold therapy. Microwave safe for heat therapy. Freezer safe for cold therapy. Includes fabric cover.',
            ar: 'حزمة هلام قابلة لإعادة الاستخدام للعلاج الساخن أو البارد. آمنة للاستخدام في الميكروويف للعلاج الحراري. آمنة للاستخدام في الفريزر للعلاج البارد. تشمل الغلاف القماشي.',
            ku: 'پاکێتی جێل قەبارەی جارێک بۆ چارەسەری گەرم یان سارد. پارێزەری بۆ بەکارهێنان لە مایکرۆیەڤ بۆ چارەسەری گەرمی. پارێزەری بۆ بەکارهێنان لە فریژەر بۆ چارەسەری سارد. بریتیە لە داپۆڕینی تەنور.'
        },
        shortDescription: {
            en: 'Reusable hot/cold gel therapy pack',
            ar: 'حزمة جيل ساخن/بارد قابلة لإعادة الاستخدام',
            ku: 'پاکێتی جێلی گەرم/سارد قەبارەی جارێک'
        },
        categoryRef: 'Patient Care',
        slug: 'hot-cold-therapy-pack',
        images: [
            { url: '/images/products/therapy-pack-1.jpg', alt: 'Therapy Pack', isPrimary: true }
        ],
        price: 9000,
        inventory: { trackInventory: true, quantity: 70, lowStockThreshold: 15 },
        status: 'active',
        tags: ['therapy', 'hot-cold', 'pain-relief', 'reusable'],
        specifications: [
            { key: { en: 'Size', ar: 'الحجم', ku: 'قەبارە' }, value: { en: 'Standard', ar: 'قياسي', ku: 'ستاندارد' } },
            { key: { en: 'Includes Cover', ar: 'يشمل الغلاف', ku: 'دابەپۆشی لەخۆدەگرێت' }, value: { en: 'Yes', ar: 'نعم', ku: 'بەڵێ' } }
        ],
        createdBy: ADMIN_USER_ID
    }
];

// =====================================================
// SHOP ORDERS
// =====================================================
const shopOrders = [
    {
        orderNumber: generateOrderNumber('A1B2C3'),
        customer: {
            userId: null, // Guest order
            name: 'Ahmed Ali',
            phone: '+9647501234567',
            phoneVerified: true,
            verification: {
                messageId: 'msg_' + Math.random().toString(36).substr(2, 9),
                verifiedAt: new Date(Date.now() - 2 * 60 * 60 * 1000) // 2 hours ago
            }
        },
        deliveryAddress: {
            address: 'Baghdad, Karrada, Street 123, Building 5, Floor 2',
            city: 'Baghdad',
            notes: 'Please call before delivery'
        },
        items: [], // Will be populated with product references
        pricing: {
            subtotal: 0, // Will be calculated
            deliveryFee: 5000,
            discount: 0,
            total: 0, // Will be calculated
            currency: 'IQD'
        },
        status: 'processing',
        payment: {
            method: 'cash_on_delivery',
            status: 'pending',
            paidAt: null
        },
        adminNotes: 'First time customer - ensure quality packaging',
        itemRefs: [
            { productName: 'Digital Blood Pressure Monitor', quantity: 1 },
            { productName: 'Pulse Oximeter', quantity: 2 }
        ]
    },
    {
        orderNumber: generateOrderNumber('D4E5F6'),
        customer: {
            userId: null,
            name: 'Fatima Hassan',
            phone: '+9647709876543',
            phoneVerified: true,
            verification: {
                messageId: 'msg_' + Math.random().toString(36).substr(2, 9),
                verifiedAt: new Date(Date.now() - 24 * 60 * 60 * 1000) // 1 day ago
            }
        },
        deliveryAddress: {
            address: 'Erbil, Ankawa, Main Road, Near Hospital',
            city: 'Erbil',
            notes: ''
        },
        items: [],
        pricing: {
            subtotal: 0,
            deliveryFee: 3000,
            discount: 2000, // Discount coupon applied
            total: 0,
            currency: 'IQD'
        },
        status: 'done',
        payment: {
            method: 'cash_on_delivery',
            status: 'paid',
            paidAt: new Date(Date.now() - 20 * 60 * 60 * 1000) // 20 hours ago
        },
        adminNotes: '',
        itemRefs: [
            { productName: 'Medical Examination Gloves (Box of 100)', quantity: 5 },
            { productName: 'Surgical Face Masks (Pack of 50)', quantity: 3 }
        ]
    },
    {
        orderNumber: generateOrderNumber('G7H8I9'),
        customer: {
            userId: null,
            name: 'Mohammed Karim',
            phone: '+9647505555777',
            phoneVerified: true,
            verification: {
                messageId: 'msg_' + Math.random().toString(36).substr(2, 9),
                verifiedAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000) // 3 days ago
            }
        },
        deliveryAddress: {
            address: 'Basra, Al-Ashar, Corniche Street',
            city: 'Basra',
            notes: 'Ring doorbell twice'
        },
        items: [],
        pricing: {
            subtotal: 0,
            deliveryFee: 4000,
            discount: 0,
            total: 0,
            currency: 'IQD'
        },
        status: 'pending',
        payment: {
            method: 'cash_on_delivery',
            status: 'pending',
            paidAt: null
        },
        adminNotes: '',
        itemRefs: [
            { productName: 'Professional Stethoscope', quantity: 1 },
            { productName: 'Medical Penlight', quantity: 3 }
        ]
    },
    {
        orderNumber: generateOrderNumber('J0K1L2'),
        customer: {
            userId: null,
            name: 'Zainab Ibrahim',
            phone: '+9647712341234',
            phoneVerified: true,
            verification: {
                messageId: 'msg_' + Math.random().toString(36).substr(2, 9),
                verifiedAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000) // 5 days ago
            }
        },
        deliveryAddress: {
            address: 'Sulaymaniyah, Goizha, Apartment 12',
            city: 'Sulaymaniyah',
            notes: ''
        },
        items: [],
        pricing: {
            subtotal: 0,
            deliveryFee: 3500,
            discount: 0,
            total: 0,
            currency: 'IQD'
        },
        status: 'done',
        payment: {
            method: 'cash_on_delivery',
            status: 'paid',
            paidAt: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000) // 4 days ago
        },
        adminNotes: 'Express delivery - delivered within 2 hours',
        itemRefs: [
            { productName: 'Compression Socks (Pair)', quantity: 4 },
            { productName: 'Hot & Cold Therapy Pack', quantity: 2 }
        ]
    },
    {
        orderNumber: generateOrderNumber('M3N4O5'),
        customer: {
            userId: null,
            name: 'Omar Youssef',
            phone: '+9647509999888',
            phoneVerified: true,
            verification: {
                messageId: 'msg_' + Math.random().toString(36).substr(2, 9),
                verifiedAt: new Date(Date.now() - 6 * 24 * 60 * 60 * 1000) // 6 days ago
            }
        },
        deliveryAddress: {
            address: 'Najaf, Al-Haidariya, Near Medical Center',
            city: 'Najaf',
            notes: 'Leave at reception'
        },
        items: [],
        pricing: {
            subtotal: 0,
            deliveryFee: 6000,
            discount: 0,
            total: 0,
            currency: 'IQD'
        },
        status: 'cancelled',
        payment: {
            method: 'cash_on_delivery',
            status: 'refunded',
            paidAt: null
        },
        adminNotes: 'Customer requested cancellation - out of delivery area',
        cancellation: {
            cancelledAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000),
            cancelledBy: ADMIN_USER_ID,
            reason: 'Out of delivery area'
        },
        itemRefs: [
            { productName: 'Digital Thermometer', quantity: 10 },
            { productName: 'Face Shield', quantity: 5 }
        ]
    }
];

// =====================================================
// SEED FUNCTION
// =====================================================
async function seedShopData() {
    try {
        console.log('🌱 Starting shop data seed...');

        // Connect to database (if not already connected)
        if (mongoose.connection.readyState === 0) {
            await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/labgo', {
                useNewUrlParser: true,
                useUnifiedTopology: true,
            });
        }

        // Clear existing data
        console.log('🗑️ Clearing existing shop data...');
        await ShopOrder.deleteMany({});
        await Product.deleteMany({});
        await Category.deleteMany({});

        // Insert Categories
        console.log('📁 Inserting categories...');
        const insertedCategories = await Category.insertMany(categories);
        console.log(`✅ Inserted ${insertedCategories.length} categories`);

        // Create category lookup map
        const categoryMap = {};
        insertedCategories.forEach(cat => {
            categoryMap[cat.name.en] = cat._id;
        });

        // Prepare Products with category IDs
        const productsWithCategoryIds = products.map(product => {
            const { categoryRef, ...productData } = product;
            return {
                ...productData,
                category: categoryMap[categoryRef]
                // slug is already defined in each product
            };
        });

        // Insert Products
        console.log('📦 Inserting products...');
        const insertedProducts = await Product.insertMany(productsWithCategoryIds);
        console.log(`✅ Inserted ${insertedProducts.length} products`);

        // Create product lookup map
        const productMap = {};
        insertedProducts.forEach(prod => {
            productMap[prod.name.en] = prod;
        });

        // Prepare Orders with product references
        const ordersWithItems = shopOrders.map(order => {
            const orderItems = order.itemRefs.map(ref => {
                const product = productMap[ref.productName];
                if (!product) {
                    console.warn(`⚠️ Product not found: ${ref.productName}`);
                    return null;
                }
                const subtotal = product.price * ref.quantity;
                return {
                    productId: product._id,
                    name: product.name,
                    image: product.primaryImage,
                    price: product.price,
                    quantity: ref.quantity,
                    subtotal: subtotal
                };
            }).filter(Boolean);

            const itemsSubtotal = orderItems.reduce((sum, item) => sum + item.subtotal, 0);
            const total = itemsSubtotal + order.pricing.deliveryFee - order.pricing.discount;

            const orderData = {
                ...order,
                items: orderItems,
                pricing: {
                    ...order.pricing,
                    subtotal: itemsSubtotal,
                    total: total
                }
            };

            // Remove temporary fields
            delete orderData.itemRefs;
            if (orderData.cancellation) {
                // Keep cancellation for cancelled orders
            }

            return orderData;
        });

        // Insert Orders
        console.log('🛒 Inserting shop orders...');
        const insertedOrders = await ShopOrder.insertMany(ordersWithItems);
        console.log(`✅ Inserted ${insertedOrders.length} shop orders`);

        console.log('\n🎉 Shop data seeded successfully!');
        console.log('\n📊 Summary:');
        console.log(`   Categories: ${insertedCategories.length}`);
        console.log(`   Products: ${insertedProducts.length}`);
        console.log(`   Orders: ${insertedOrders.length}`);

        // Display some stats
        console.log('\n💰 Order Status Breakdown:');
        const orderStats = {
            pending: insertedOrders.filter(o => o.status === 'pending').length,
            processing: insertedOrders.filter(o => o.status === 'processing').length,
            done: insertedOrders.filter(o => o.status === 'done').length,
            cancelled: insertedOrders.filter(o => o.status === 'cancelled').length
        };
        console.log(`   Pending: ${orderStats.pending}`);
        console.log(`   Processing: ${orderStats.processing}`);
        console.log(`   Done: ${orderStats.done}`);
        console.log(`   Cancelled: ${orderStats.cancelled}`);

    } catch (error) {
        console.error('❌ Error seeding shop data:', error);
        throw error;
    } finally {
        // Close connection if we opened it
        if (process.env.AUTO_CLOSE === 'true') {
            await mongoose.connection.close();
            console.log('🔌 Database connection closed');
        }
    }
}

// Run seed if executed directly
if (require.main === module) {
    seedShopData()
        .then(() => {
            console.log('\n✨ Seed completed successfully!');
            process.exit(0);
        })
        .catch((error) => {
            console.error('\n💥 Seed failed:', error);
            process.exit(1);
        });
}

module.exports = seedShopData;
