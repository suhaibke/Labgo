const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('./models/User');
const Lab = require('./models/Lab');
const Order = require('./models/Order');
const NurseApplication = require('./models/NurseApplication');

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/labgo', {
    useNewUrlParser: true,
    useUnifiedTopology: true,
});

// Helper function to generate random dates
const randomDate = (start, end) => {
    return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()));
};

// Helper function to generate phone numbers
const generatePhone = (index) => {
    return `+964750${String(index).padStart(6, '0')}`;
};

// Sample data
const firstNames = ['Ahmed', 'Mohammed', 'Ali', 'Omar', 'Hassan', 'Hussein', 'Youssef', 'Kareem', 'Mustafa', 'Abdullah', 'Fatima', 'Zahra', 'Aisha', 'Maryam', 'Sarah', 'Layla', 'Hana', 'Noor', 'Rana', 'Amira', 'Reem', 'Nadia', 'Sama', 'Dalia', 'Yasmin'];
const lastNames = ['Al-Sultani', 'Al-Tamimi', 'Al-Husseini', 'Al-Karim', 'Al-Majid', 'Al-Said', 'Al-Rashid', 'Al-Hamad', 'Al-Sadiq', 'Al-Mansour', 'Al-Nuri', 'Al-Sharif', 'Al-Qadir', 'Al-Zahawi', 'Al-Hafidh', 'Al-Jabouri', 'Al-Dulaimi', 'Al-Ansari', 'Al-Baghdadi', 'Al-Khalidi'];
const cities = ['Baghdad', 'Basra', 'Mosul', 'Erbil', 'Najaf', 'Karbala', 'Sulaymaniyah', 'Kirkuk', 'Duhok', 'Ramadi'];
const streets = ['Al-Rashid Street', 'Al-Sadoon Street', 'Al-Karada District', 'Al-Mansour District', 'Al-Kadhimiya', 'Al-Jadriya', 'Al-Zayouna', 'Al-Saydiya', 'Al-Amil', 'Al-Ghazaliya', 'Al-Jami\'a', 'Al-Adhamiya', 'Al-Waziriya', 'Al-Shaab', 'Al-Hurriya', 'Al-Yarmouk', 'Al-Baya\'a', 'Al-Ma\'alif', 'Al-Iskan', 'Al-Shuala'];

// Valid test categories from schema: ['Blood Tests', 'X-Ray', 'MRI', 'CT Scan', 'Ultrasound', 'Pathology', 'Microbiology', 'Biochemistry', 'Genetics', 'Allergy', 'Cardiology', 'Neurology', 'General']
const testCatalog = [
    // Blood Tests
    { name: 'Complete Blood Count (CBC)', code: 'CBC001', price: 15000, description: 'Measures red blood cells, white blood cells, hemoglobin, hematocrit, and platelets', category: 'Blood Tests' },
    { name: 'ESR (Erythrocyte Sedimentation Rate)', code: 'ESR001', price: 8000, description: 'Measures inflammation in the body', category: 'Blood Tests' },
    { name: 'Blood Type & Rh Factor', code: 'BT001', price: 10000, description: 'Determines blood type (A, B, AB, O) and Rh factor', category: 'Blood Tests' },
    { name: 'Reticulocyte Count', code: 'RET001', price: 12000, description: 'Measures immature red blood cells', category: 'Blood Tests' },
    { name: 'Peripheral Blood Smear', code: 'PBS001', price: 15000, description: 'Microscopic examination of blood cells', category: 'Blood Tests' },
    { name: 'Platelet Count', code: 'PLT001', price: 10000, description: 'Measures platelet count in blood', category: 'Blood Tests' },
    { name: 'Hemoglobin A1C', code: 'HBA1C001', price: 18000, description: 'Measures average blood sugar over 3 months', category: 'Blood Tests' },
    { name: 'Bleeding Time', code: 'BTIME001', price: 12000, description: 'Measures bleeding time', category: 'Blood Tests' },
    { name: 'Clotting Time', code: 'CTIME001', price: 12000, description: 'Measures clotting time', category: 'Blood Tests' },
    { name: 'Prothrombin Time (PT)', code: 'PT001', price: 15000, description: 'Measures blood clotting time', category: 'Blood Tests' },

    // Biochemistry
    { name: 'Fasting Blood Sugar (FBS)', code: 'FBS001', price: 8000, description: 'Measures blood glucose after fasting', category: 'Biochemistry' },
    { name: 'Random Blood Sugar (RBS)', code: 'RBS001', price: 7000, description: 'Measures blood glucose at any time', category: 'Biochemistry' },
    { name: 'Liver Function Test (LFT)', code: 'LFT001', price: 25000, description: 'ALT, AST, ALP, GGT, bilirubin, total protein, albumin', category: 'Biochemistry' },
    { name: 'Kidney Function Test (KFT)', code: 'KFT001', price: 25000, description: 'Urea, creatinine, uric acid, electrolytes', category: 'Biochemistry' },
    { name: 'Lipid Profile', code: 'LIP001', price: 30000, description: 'Total cholesterol, HDL, LDL, triglycerides', category: 'Biochemistry' },
    { name: 'Thyroid Function Test (TFT)', code: 'TFT001', price: 35000, description: 'T3, T4, TSH', category: 'Biochemistry' },
    { name: 'Uric Acid', code: 'UA001', price: 10000, description: 'Measures uric acid levels for gout diagnosis', category: 'Biochemistry' },
    { name: 'Iron Studies', code: 'IRON001', price: 28000, description: 'Serum iron, TIBC, ferritin, transferrin saturation', category: 'Biochemistry' },
    { name: 'Vitamin B12', code: 'B12001', price: 35000, description: 'Measures Vitamin B12 levels', category: 'Biochemistry' },
    { name: 'Vitamin D Total', code: 'VD001', price: 40000, description: 'Measures Vitamin D levels (25-OH)', category: 'Biochemistry' },
    { name: 'Electrolytes Panel', code: 'ELEC001', price: 20000, description: 'Sodium, potassium, chloride, bicarbonate', category: 'Biochemistry' },
    { name: 'Cardiac Enzymes', code: 'CARD001', price: 45000, description: 'Troponin, CK-MB, LDH', category: 'Biochemistry' },
    { name: 'Amylase', code: 'AMY001', price: 15000, description: 'Pancreatic enzyme', category: 'Biochemistry' },
    { name: 'Lipase', code: 'LIPASE001', price: 18000, description: 'Pancreatic enzyme', category: 'Biochemistry' },
    { name: 'Total Protein', code: 'TP001', price: 10000, description: 'Total protein in blood', category: 'Biochemistry' },
    { name: 'Albumin', code: 'ALB001', price: 12000, description: 'Albumin level in blood', category: 'Biochemistry' },
    { name: 'Globulin', code: 'GLB001', price: 12000, description: 'Globulin level in blood', category: 'Biochemistry' },
    { name: 'Calcium', code: 'CA001', price: 10000, description: 'Calcium level in blood', category: 'Biochemistry' },
    { name: 'Phosphorus', code: 'PHOS001', price: 10000, description: 'Phosphorus level in blood', category: 'Biochemistry' },
    { name: 'Magnesium', code: 'MG001', price: 12000, description: 'Magnesium level in blood', category: 'Biochemistry' },

    // Microbiology
    { name: 'Malaria Smear', code: 'MAL001', price: 15000, description: 'Malaria parasite detection', category: 'Microbiology' },
    { name: 'Dengue NS1 Antigen', code: 'DENNS1001', price: 25000, description: 'Dengue NS1 antigen test', category: 'Microbiology' },
    { name: 'Typhoid Test (Widal)', code: 'WID001', price: 18000, description: 'Widal test for typhoid', category: 'Microbiology' },
    { name: 'Urine Culture', code: 'URIC001', price: 35000, description: 'Urine culture and sensitivity', category: 'Microbiology' },
    { name: 'Stool Culture', code: 'STOOLC001', price: 35000, description: 'Stool culture and sensitivity', category: 'Microbiology' },
    { name: 'Throat Swab Culture', code: 'THROAT001', price: 30000, description: 'Throat swab culture', category: 'Microbiology' },
    { name: 'Sputum Culture', code: 'SPUTUM001', price: 30000, description: 'Sputum culture for TB', category: 'Microbiology' },
    { name: 'Blood Culture', code: 'BLC001', price: 45000, description: 'Blood culture for bacteria', category: 'Microbiology' },

    // Pathology
    { name: 'Biopsy Report', code: 'BIOP001', price: 50000, description: 'Tissue biopsy examination', category: 'Pathology' },
    { name: 'Pap Smear', code: 'PAP001', price: 35000, description: 'Cervical cancer screening', category: 'Pathology' },
    { name: 'FNAC', code: 'FNAC001', price: 30000, description: 'Fine needle aspiration cytology', category: 'Pathology' },

    // Genetics
    { name: 'Karyotyping', code: 'KARY001', price: 150000, description: 'Chromosome analysis', category: 'Genetics' },
    { name: 'DNA Testing (Basic)', code: 'DNA001', price: 200000, description: 'Basic DNA analysis', category: 'Genetics' },

    // Allergy
    { name: 'IgE Total', code: 'IGE001', price: 25000, description: 'Total IgE level', category: 'Allergy' },
    { name: 'Allergy Screen Panel', code: 'ALLSC001', price: 150000, description: 'Common allergen screening', category: 'Allergy' },

    // Cardiology
    { name: 'ECG (Electrocardiogram)', code: 'ECG001', price: 25000, description: 'Heart electrical activity', category: 'Cardiology' },
    { name: 'Echocardiography', code: 'ECHO001', price: 75000, description: 'Heart ultrasound', category: 'Cardiology' },
    { name: 'Stress Test', code: 'STRESS001', price: 100000, description: 'Cardiac stress test', category: 'Cardiology' },

    // Neurology
    { name: 'EEG (Electroencephalogram)', code: 'EEG001', price: 60000, description: 'Brain electrical activity', category: 'Neurology' },
    { name: 'EMG (Electromyography)', code: 'EMG001', price: 80000, description: 'Muscle and nerve function', category: 'Neurology' },

    // Imaging
    { name: 'X-Ray Chest', code: 'XRCH001', price: 20000, description: 'Chest X-ray', category: 'X-Ray' },
    { name: 'X-Ray Abdomen', code: 'XRAB001', price: 20000, description: 'Abdominal X-ray', category: 'X-Ray' },
    { name: 'X-Ray Extremity', code: 'XREX001', price: 15000, description: 'Arm or leg X-ray', category: 'X-Ray' },
    { name: 'X-Ray Spine', code: 'XRSP001', price: 25000, description: 'Spine X-ray', category: 'X-Ray' },
    { name: 'X-Ray Sinus', code: 'XRSN001', price: 18000, description: 'Sinus X-ray', category: 'X-Ray' },

    { name: 'MRI Brain', code: 'MRIBR001', price: 250000, description: 'Brain MRI', category: 'MRI' },
    { name: 'MRI Spine', code: 'MRISP001', price: 250000, description: 'Spine MRI', category: 'MRI' },
    { name: 'MRI Joint', code: 'MRIJT001', price: 200000, description: 'Joint MRI', category: 'MRI' },
    { name: 'MRI Abdomen', code: 'MRIAB001', price: 300000, description: 'Abdominal MRI', category: 'MRI' },

    { name: 'CT Scan Brain', code: 'CTBR001', price: 150000, description: 'Brain CT scan', category: 'CT Scan' },
    { name: 'CT Scan Chest', code: 'CTCH001', price: 150000, description: 'Chest CT scan', category: 'CT Scan' },
    { name: 'CT Scan Abdomen', code: 'CTAB001', price: 180000, description: 'Abdominal CT scan', category: 'CT Scan' },
    { name: 'CT Scan Sinus', code: 'CTSN001', price: 120000, description: 'Sinus CT scan', category: 'CT Scan' },

    { name: 'Ultrasound Abdomen', code: 'USAB001', price: 50000, description: 'Abdominal ultrasound', category: 'Ultrasound' },
    { name: 'Ultrasound Pelvis', code: 'USPL001', price: 50000, description: 'Pelvic ultrasound', category: 'Ultrasound' },
    { name: 'Ultrasound Thyroid', code: 'USTH001', price: 35000, description: 'Thyroid ultrasound', category: 'Ultrasound' },
    { name: 'Ultrasound Breast', code: 'USBR001', price: 40000, description: 'Breast ultrasound', category: 'Ultrasound' },
    { name: 'Obstetric Ultrasound', code: 'USOB001', price: 60000, description: 'Pregnancy ultrasound', category: 'Ultrasound' },
    { name: 'Ultrasound Kidney', code: 'USKD001', price: 40000, description: 'Kidney ultrasound', category: 'Ultrasound' },
    { name: 'Ultrasound Prostate', code: 'USPR001', price: 45000, description: 'Prostate ultrasound', category: 'Ultrasound' },
    { name: 'Doppler Study', code: 'DOPPLER001', price: 75000, description: 'Blood flow Doppler study', category: 'Ultrasound' },

    // General
    { name: 'Basic Health Checkup', code: 'BHC001', price: 100000, description: 'Basic health screening package', category: 'General' },
    { name: 'Complete Health Checkup', code: 'CHC001', price: 250000, description: 'Complete health screening package', category: 'General' },
    { name: 'Executive Health Checkup', code: 'EHC001', price: 400000, description: 'Executive health screening package', category: 'General' },
    { name: 'Diabetic Screening', code: 'DS001', price: 80000, description: 'Diabetes screening package', category: 'General' },
    { name: 'Cardiac Screening', code: 'CS001', price: 150000, description: 'Heart health screening', category: 'General' },
    { name: 'Women Health Checkup', code: 'WHC001', price: 120000, description: 'Women health screening', category: 'General' },
    { name: 'Senior Citizen Checkup', code: 'SCC001', price: 180000, description: 'Senior citizen health package', category: 'General' },
    { name: 'Pre-Employment Checkup', code: 'PEC001', price: 70000, description: 'Pre-employment medical test', category: 'General' },
    { name: 'Insurance Medical', code: 'INS001', price: 60000, description: 'Insurance medical exam', category: 'General' },
];

// Valid lab specializations: ['Blood Tests', 'X-Ray', 'MRI', 'CT Scan', 'Ultrasound', 'Pathology', 'Microbiology', 'Biochemistry', 'Genetics', 'Allergy', 'Cardiology', 'Neurology', 'General']
const labSpecializations = [
    ['Blood Tests', 'Biochemistry', 'Microbiology', 'Pathology', 'General'],
    ['X-Ray', 'Ultrasound', 'CT Scan', 'MRI', 'General'],
    ['Pathology', 'Microbiology', 'Biochemistry', 'Blood Tests'],
    ['Blood Tests', 'Biochemistry', 'Cardiology', 'Neurology', 'General'],
    ['Genetics', 'Biochemistry', 'Blood Tests', 'General'],
    ['X-Ray', 'Ultrasound', 'Biochemistry', 'Blood Tests', 'General'],
];

const createComprehensiveSeed = async () => {
    try {
        console.log('🌱 Starting comprehensive database seeding...\n');

        // Clean existing data
        console.log('🧹 Cleaning existing data...');
        await User.deleteMany({});
        await Lab.deleteMany({});
        await Order.deleteMany({});
        await NurseApplication.deleteMany({});
        console.log('✅ Database cleared\n');

        const hashedPassword = await bcrypt.hash('password123', 12);
        const createdUsers = { admins: [], labs: [], nurses: [], patients: [] };

        // ==================== CREATE ADMIN USERS ====================
        console.log('👑 Creating admin users...');
        const adminData = [
            { name: 'Admin User', email: 'admin@labgo.com', phone: '+9647500000001' },
            { name: 'Super Admin', email: 'superadmin@labgo.com', phone: '+9647500000002' },
            { name: 'System Admin', email: 'sysadmin@labgo.com', phone: '+9647500000003' },
        ];

        for (const admin of adminData) {
            const adminUser = new User({
                name: admin.name,
                email: admin.email,
                phone: admin.phone,
                gender: 'male',
                password: hashedPassword,
                birthDate: new Date('1990-01-01'),
                role: 'admin',
                isVerified: true,
                defaultLocation: {
                    address: 'Admin Office, Baghdad',
                    coordinates: { latitude: 33.3152, longitude: 44.3661 }
                }
            });
            await adminUser.save();
            createdUsers.admins.push(adminUser);
            console.log(`   ✓ Created admin: ${admin.email}`);
        }

        // ==================== CREATE LAB USERS AND LABS ====================
        console.log('\n🏥 Creating lab users and labs...');
        const labData = [
            {
                name: 'Baghdad Central Laboratory',
                email: 'info@baghdadlab.iq',
                phone: '+9647501000001',
                address: 'Al-Karada District, Baghdad',
                city: 'Baghdad',
                specialization: labSpecializations[0],
                coordinates: { latitude: 33.3152, longitude: 44.3661 },
            },
            {
                name: 'Basra Diagnostic Center',
                email: 'info@basradiag.iq',
                phone: '+9647501000002',
                address: 'Ashar Quarter, Basra',
                city: 'Basra',
                specialization: labSpecializations[1],
                coordinates: { latitude: 30.5081, longitude: 47.7835 },
            },
            {
                name: 'Mosul Pathology Lab',
                email: 'info@mosulpath.iq',
                phone: '+9647501000003',
                address: 'Al-Muaazzal District, Mosul',
                city: 'Mosul',
                specialization: labSpecializations[2],
                coordinates: { latitude: 36.3489, longitude: 43.1577 },
            },
            {
                name: 'Erbil Medical Laboratory',
                email: 'info@erbilmed.iq',
                phone: '+9647501000004',
                address: 'Gulan Street, Erbil',
                city: 'Erbil',
                specialization: labSpecializations[3],
                coordinates: { latitude: 36.1901, longitude: 43.9950 },
            },
            {
                name: 'Najaf Research Center',
                email: 'info@najafres.iq',
                phone: '+9647501000005',
                address: 'Al-Safa Street, Najaf',
                city: 'Najaf',
                specialization: labSpecializations[4],
                coordinates: { latitude: 32.0000, longitude: 44.3333 },
            },
            {
                name: 'Karbala Imaging & Diagnostics',
                email: 'info@karbimaging.iq',
                phone: '+9647501000006',
                address: 'Al-Quds Street, Karbala',
                city: 'Karbala',
                specialization: labSpecializations[5],
                coordinates: { latitude: 32.6167, longitude: 44.0333 },
            },
        ];

        const createdLabs = [];

        for (let i = 0; i < labData.length; i++) {
            const labInfo = labData[i];

            // Create lab user
            const labUser = new User({
                name: `${labInfo.name} - Lab Manager`,
                email: `lab${i + 1}@labgo.com`,
                phone: labInfo.phone,
                gender: i % 2 === 0 ? 'male' : 'female',
                password: hashedPassword,
                birthDate: new Date('1985-0' + ((i % 9) + 1) + '-15'),
                role: 'lab',
                isVerified: true,
                defaultLocation: {
                    address: labInfo.address,
                    coordinates: labInfo.coordinates
                }
            });
            await labUser.save();
            createdUsers.labs.push(labUser);
            console.log(`   ✓ Created lab user: lab${i + 1}@labgo.com`);

            // Create lab profile
            const labTests = testCatalog
                .sort(() => Math.random() - 0.5)
                .slice(0, Math.floor(Math.random() * 30) + 20)
                .map(test => ({
                    ...test,
                    _id: new mongoose.Types.ObjectId()
                }));

            const lab = new Lab({
                name: labInfo.name,
                email: labInfo.email,
                phone: labInfo.phone,
                address: labInfo.address,
                city: labInfo.city,
                country: 'Iraq',
                website: `https://${labInfo.name.toLowerCase().replace(/\s+/g, '')}.iq`,
                specialization: labInfo.specialization,
                operatingHours: {
                    monday: { open: '08:00', close: '20:00', closed: false },
                    tuesday: { open: '08:00', close: '20:00', closed: false },
                    wednesday: { open: '08:00', close: '20:00', closed: false },
                    thursday: { open: '08:00', close: '20:00', closed: false },
                    friday: { open: '08:00', close: '14:00', closed: false },
                    saturday: { open: '09:00', close: '18:00', closed: false },
                    sunday: { open: '09:00', close: '18:00', closed: false }
                },
                tests: labTests,
                status: 'Active',
                licenseNumber: `LAB-${labInfo.city.substring(0, 3).toUpperCase()}-2024-00${i + 1}`,
                accreditation: 'Iraqi Ministry of Health & ISO 15189 Certified',
                description: `${labInfo.name} is a leading diagnostic facility in ${labInfo.city}, providing comprehensive laboratory services with state-of-the-art equipment and experienced medical professionals.`,
                totalPatientsServed: Math.floor(Math.random() * 5000) + 1000,
                totalTestsPerformed: Math.floor(Math.random() * 15000) + 5000,
                averageRating: (Math.random() * 1.5 + 3.5).toFixed(1),
                totalReviews: Math.floor(Math.random() * 200) + 50,
                ownerId: labUser._id,
                createdBy: labUser._id,
                isVerified: true,
                verificationDate: randomDate(new Date('2024-01-01'), new Date('2024-06-01')),
                coordinates: labInfo.coordinates,
                paymentMethods: ['Cash', 'Credit Card', 'Insurance'],
                insuranceProviders: ['Al-Methaq Health Insurance', 'Iraq Insurance Company', 'Gulf Insurance'],
                emergencyContact: {
                    phone: labInfo.phone,
                    email: `emergency@${labInfo.name.toLowerCase().replace(/\s+/g, '')}.iq`
                },
                patientTests: []
            });
            await lab.save();
            createdLabs.push(lab);
            console.log(`   ✓ Created lab: ${lab.name} with ${labTests.length} tests`);
        }

        // ==================== CREATE NURSE USERS ====================
        console.log('\n👨‍⚕️ Creating nurse users and applications...');
        const nurseNames = [
            { name: 'Nurse Sarah Ahmed', gender: 'female' },
            { name: 'Nurse Mohammed Hassan', gender: 'male' },
            { name: 'Nurse Fatima Ali', gender: 'female' },
            { name: 'Nurse Omar Hussein', gender: 'male' },
            { name: 'Nurse Layla Mohammed', gender: 'female' },
            { name: 'Nurse Kareem Al-Sultani', gender: 'male' },
            { name: 'Nurse Zahra Al-Tamimi', gender: 'female' },
            { name: 'Nurse Youssef Al-Husseini', gender: 'male' },
        ];

        const createdNurses = [];

        for (let i = 0; i < nurseNames.length; i++) {
            const nurseData = nurseNames[i];

            // Create nurse user (approved ones only)
            const nurseUser = new User({
                name: nurseData.name,
                email: `nurse${i + 1}@labgo.com`,
                phone: generatePhone(10 + i),
                gender: nurseData.gender,
                password: hashedPassword,
                birthDate: randomDate(new Date('1980-01-01'), new Date('1995-12-31')),
                role: 'nurse',
                isVerified: true,
                defaultLocation: {
                    address: `${streets[i % streets.length]}, ${cities[i % cities.length]}`,
                    coordinates: {
                        latitude: 33.3152 + (Math.random() - 0.5) * 2,
                        longitude: 44.3661 + (Math.random() - 0.5) * 2
                    }
                }
            });
            await nurseUser.save();
            createdUsers.nurses.push(nurseUser);

            // Create nurse application
            const applicationStatuses = ['approved', 'approved', 'approved', 'approved', 'approved', 'pending', 'under_review', 'rejected'];
            const status = applicationStatuses[i];

            const application = new NurseApplication({
                userId: nurseUser._id,
                personalInfo: {
                    name: nurseData.name,
                    email: `nurse${i + 1}@labgo.com`,
                    phone: generatePhone(10 + i),
                    dateOfBirth: randomDate(new Date('1980-01-01'), new Date('1995-12-31')),
                    gender: nurseData.gender
                },
                nationalCardImageFront: `https://example.com/national-front-${i}.jpg`,
                nationalCardImageBack: `https://example.com/national-back-${i}.jpg`,
                certificateImage: `https://example.com/certificate-${i}.jpg`,
                location: {
                    city: cities[i % cities.length],
                    zone: `Zone ${i + 1}`,
                    address: `${streets[i % streets.length]}`,
                    coordinates: {
                        latitude: 33.3152 + (Math.random() - 0.5) * 2,
                        longitude: 44.3661 + (Math.random() - 0.5) * 2
                    }
                },
                questionnaire: {
                    ownsCar: i % 3 === 0,
                    isEmployed: i % 2 === 0
                },
                status: status,
                additionalInfo: i % 3 === 0 ? 'Experienced in home sample collection.' : null,
                submittedAt: randomDate(new Date('2024-01-01'), new Date('2024-11-01')),
            });

            if (status === 'approved') {
                application.nurseUserId = nurseUser._id;
                application.reviewDetails = {
                    reviewedBy: createdUsers.admins[0]._id,
                    reviewedAt: randomDate(new Date('2024-06-01'), new Date('2024-11-01')),
                    notes: 'Application approved after verification of documents.'
                };
            } else if (status === 'rejected') {
                application.reviewDetails = {
                    reviewedBy: createdUsers.admins[0]._id,
                    reviewedAt: randomDate(new Date('2024-06-01'), new Date('2024-11-01')),
                    rejectionReason: 'Certificate verification failed.'
                };
            }

            await application.save();
            createdNurses.push({ user: nurseUser, application });
            console.log(`   ✓ Created nurse: nurse${i + 1}@labgo.com (${status})`);
        }

        // ==================== CREATE PATIENT USERS ====================
        console.log('\n👤 Creating patient users...');
        for (let i = 0; i < 30; i++) {
            const firstName = firstNames[Math.floor(Math.random() * firstNames.length)];
            const lastName = lastNames[Math.floor(Math.random() * lastNames.length)];
            const gender = Math.random() > 0.5 ? 'male' : 'female';
            const city = cities[Math.floor(Math.random() * cities.length)];
            const street = streets[Math.floor(Math.random() * streets.length)];

            const patient = new User({
                name: `${firstName} ${lastName}`,
                email: `patient${i + 1}@labgo.com`,
                phone: generatePhone(50 + i),
                gender: gender,
                password: hashedPassword,
                birthDate: randomDate(new Date('1960-01-01'), new Date('2005-12-31')),
                role: 'patient',
                isVerified: Math.random() > 0.3,
                isPhoneVerified: Math.random() > 0.2,
                defaultLocation: {
                    address: `${street}, ${city}`,
                    coordinates: {
                        latitude: 33.3152 + (Math.random() - 0.5) * 3,
                        longitude: 44.3661 + (Math.random() - 0.5) * 3
                    }
                },
                cart: [],
                prescriptions: Math.random() > 0.7 ? [`https://example.com/prescription-${i}.jpg`] : []
            });
            await patient.save();
            createdUsers.patients.push(patient);

            if ((i + 1) % 10 === 0) {
                console.log(`   ✓ Created ${i + 1} patients...`);
            }
        }
        console.log(`   ✓ Created total of 30 patients`);

        // ==================== CREATE ORDERS ====================
        console.log('\n📋 Creating orders...');
        const orderStatuses = [
            'pending', 'confirmed', 'nurse_assigned', 'at_patient', 'going_to_lab',
            'at_lab', 'in_progress', 'completed', 'completed', 'completed', 'cancelled'
        ];

        const orderCount = 100;
        const createdOrders = [];

        for (let i = 0; i < orderCount; i++) {
            const patient = createdUsers.patients[Math.floor(Math.random() * createdUsers.patients.length)];
            const lab = createdLabs[Math.floor(Math.random() * createdLabs.length)];
            const status = orderStatuses[Math.floor(Math.random() * orderStatuses.length)];

            // Select random tests from this lab
            const numTests = Math.floor(Math.random() * 4) + 1;
            const selectedTests = lab.tests
                .sort(() => Math.random() - 0.5)
                .slice(0, numTests)
                .map(test => ({
                    testId: test._id,
                    testName: test.name,
                    testCode: test.code,
                    category: test.category,
                    price: test.price
                }));

            const subtotal = selectedTests.reduce((sum, test) => sum + test.price, 0);
            const urgency = ['routine', 'urgent', 'emergency'][Math.floor(Math.random() * 3)];
            const urgencyFee = urgency === 'urgent' ? 7500 : urgency === 'emergency' ? 15000 : 0;
            const discount = Math.random() > 0.8 ? Math.floor(subtotal * 0.1) : 0;
            const total = subtotal + urgencyFee - discount;

            const scheduledDate = randomDate(new Date('2024-09-01'), new Date('2025-02-01'));
            const timeSlots = [
                { start: '08:00', end: '10:00' },
                { start: '10:00', end: '12:00' },
                { start: '12:00', end: '14:00' },
                { start: '14:00', end: '16:00' },
                { start: '16:00', end: '18:00' },
                { start: '18:00', end: '20:00' }
            ];

            const order = new Order({
                patientId: patient._id,
                labId: lab._id,
                nurseId: null,
                tests: selectedTests,
                prescriptionImage: Math.random() > 0.7 ? `https://example.com/prescription-order-${i}.jpg` : null,
                qrCode: Order.generateQRCode(),
                scheduledDate: scheduledDate,
                timeSlot: timeSlots[Math.floor(Math.random() * timeSlots.length)],
                location: {
                    address: patient.defaultLocation?.address || `${streets[i % streets.length]}, ${cities[i % cities.length]}`,
                    landmark: Math.random() > 0.5 ? `Near ${streets[(i + 1) % streets.length]}` : null,
                    coordinates: patient.defaultLocation?.coordinates || {
                        latitude: 33.3152 + (Math.random() - 0.5) * 3,
                        longitude: 44.3661 + (Math.random() - 0.5) * 3
                    },
                    buildingName: Math.random() > 0.6 ? `Building ${Math.floor(Math.random() * 20) + 1}` : null,
                    floorNumber: Math.random() > 0.7 ? `Floor ${Math.floor(Math.random() * 5) + 1}` : null,
                    apartmentNumber: Math.random() > 0.7 ? `Apt ${Math.floor(Math.random() * 50) + 1}` : null,
                    instructions: Math.random() > 0.7 ? 'Please call upon arrival' : null
                },
                orderType: 'home_collection',
                urgency: urgency,
                status: status,
                payment: {
                    status: status === 'completed' ? 'paid' : 'pending',
                    method: 'cash',
                    amount: total,
                    currency: 'IQD',
                    paidAt: status === 'completed' ? randomDate(scheduledDate, new Date()) : null,
                    collectedBy: null
                },
                pricing: {
                    subtotal: subtotal,
                    urgencyFee: urgencyFee,
                    discount: discount,
                    total: total
                },
                statusHistory: [{ status: 'pending', timestamp: randomDate(new Date('2024-09-01'), scheduledDate) }],
                adminConfirmation: {
                    confirmed: ['confirmed', 'nurse_assigned', 'at_patient', 'going_to_lab', 'at_lab', 'in_progress', 'completed'].includes(status),
                    confirmedBy: ['confirmed', 'nurse_assigned', 'at_patient', 'going_to_lab', 'at_lab', 'in_progress', 'completed'].includes(status) ? createdUsers.admins[Math.floor(Math.random() * createdUsers.admins.length)]._id : null,
                    confirmedAt: ['confirmed', 'nurse_assigned', 'at_patient', 'going_to_lab', 'at_lab', 'in_progress', 'completed'].includes(status) ? scheduledDate : null,
                    notes: null
                },
                nurseAssignment: null,
                qrScanned: {
                    scanned: ['at_patient', 'going_to_lab', 'at_lab', 'in_progress', 'completed'].includes(status),
                    scannedAt: ['at_patient', 'going_to_lab', 'at_lab', 'in_progress', 'completed'].includes(status) ? randomDate(scheduledDate, new Date()) : null,
                    scannedBy: ['at_patient', 'going_to_lab', 'at_lab', 'in_progress', 'completed'].includes(status) ? createdNurses[Math.floor(Math.random() * 5)].user._id : null
                },
                paymentCollected: {
                    collected: status === 'completed' && Math.random() > 0.3,
                    collectedAt: status === 'completed' && Math.random() > 0.3 ? randomDate(scheduledDate, new Date()) : null,
                    collectedBy: status === 'completed' && Math.random() > 0.3 ? createdNurses[Math.floor(Math.random() * 5)].user._id : null
                },
                results: status === 'completed' ? {
                    reportUrl: `https://example.com/reports/order-${i}.pdf`,
                    completedAt: randomDate(scheduledDate, new Date()),
                    notified: Math.random() > 0.5
                } : null,
                cancellation: status === 'cancelled' ? {
                    reason: 'Patient requested cancellation',
                    cancelledBy: patient._id,
                    cancelledAt: randomDate(new Date('2024-09-01'), new Date()),
                    refundAmount: total * 0.8
                } : null,
                notes: {
                    patientNotes: Math.random() > 0.8 ? 'Please be careful, I have fear of needles.' : null,
                    labNotes: ['at_lab', 'in_progress', 'completed'].includes(status) && Math.random() > 0.7 ? 'Samples received in good condition.' : null,
                    nurseNotes: ['at_patient', 'going_to_lab', 'at_lab', 'in_progress', 'completed'].includes(status) && Math.random() > 0.7 ? 'Sample collection completed successfully.' : null
                },
                notifications: {
                    smsSent: Math.random() > 0.3,
                    emailSent: Math.random() > 0.4,
                    pushSent: Math.random() > 0.5
                },
                rating: status === 'completed' && Math.random() > 0.4 ? {
                    labRating: Math.floor(Math.random() * 2) + 4,
                    nurseRating: Math.floor(Math.random() * 2) + 4,
                    serviceRating: Math.floor(Math.random() * 2) + 4,
                    feedback: Math.random() > 0.6 ? 'Excellent service, very professional staff.' : null,
                    ratedAt: randomDate(scheduledDate, new Date())
                } : null,
                createdAt: randomDate(new Date('2024-09-01'), new Date('2024-12-01'))
            });

            // Assign nurse if status requires it
            if (['nurse_assigned', 'at_patient', 'going_to_lab', 'at_lab', 'in_progress', 'completed'].includes(status)) {
                const availableNurse = createdNurses.filter(n => n.application.status === 'approved')[Math.floor(Math.random() * 5)];
                if (availableNurse) {
                    order.nurseId = availableNurse.user._id;
                    order.nurseAssignment = {
                        assignedAt: scheduledDate,
                        acceptedAt: randomDate(scheduledDate, new Date(scheduledDate.getTime() + 3600000)),
                        estimatedArrival: new Date(scheduledDate.getTime() + 3600000),
                        notes: null
                    };
                }
            }

            // Build status history based on status
            const statusFlow = {
                'confirmed': ['pending', 'confirmed'],
                'nurse_assigned': ['pending', 'confirmed', 'nurse_assigned'],
                'at_patient': ['pending', 'confirmed', 'nurse_assigned', 'at_patient'],
                'going_to_lab': ['pending', 'confirmed', 'nurse_assigned', 'at_patient', 'going_to_lab'],
                'at_lab': ['pending', 'confirmed', 'nurse_assigned', 'at_patient', 'going_to_lab', 'at_lab'],
                'in_progress': ['pending', 'confirmed', 'nurse_assigned', 'at_patient', 'going_to_lab', 'at_lab', 'in_progress'],
                'completed': ['pending', 'confirmed', 'nurse_assigned', 'at_patient', 'going_to_lab', 'at_lab', 'in_progress', 'completed'],
            };

            if (statusFlow[status]) {
                order.statusHistory = statusFlow[status].map((s, idx) => ({
                    status: s,
                    timestamp: new Date(scheduledDate.getTime() + idx * 3600000),
                    updatedBy: ['confirmed', 'nurse_assigned', 'at_patient', 'going_to_lab'].includes(s) ?
                        (s === 'confirmed' ? createdUsers.admins[0]._id : order.nurseId) :
                        (lab.createdBy || lab.ownerId)
                }));
            }

            await order.save();
            createdOrders.push(order);

            if ((i + 1) % 20 === 0) {
                console.log(`   ✓ Created ${i + 1} orders...`);
            }
        }
        console.log(`   ✓ Created total of ${orderCount} orders`);

        // ==================== ADD PATIENT TESTS TO LABS ====================
        console.log('\n📊 Adding patient test records to labs...');
        for (const lab of createdLabs) {
            const patientTests = [];
            for (let i = 0; i < 15; i++) {
                const patient = createdUsers.patients[Math.floor(Math.random() * createdUsers.patients.length)];
                const test = lab.tests[Math.floor(Math.random() * lab.tests.length)];
                const statuses = ['Pending', 'In Progress', 'Completed', 'Cancelled'];
                const urgencies = ['Normal', 'Urgent', 'Emergency'];

                patientTests.push({
                    patientId: patient._id,
                    patientName: patient.name,
                    testId: test._id,
                    testName: test.name,
                    requestDate: randomDate(new Date('2024-08-01'), new Date()),
                    status: statuses[Math.floor(Math.random() * statuses.length)],
                    urgency: urgencies[Math.floor(Math.random() * urgencies.length)],
                    price: test.price,
                    resultDate: Math.random() > 0.5 ? randomDate(new Date('2024-09-01'), new Date()) : null
                });
            }
            lab.patientTests = patientTests;
            await lab.save();
            console.log(`   ✓ Added ${patientTests.length} patient tests to ${lab.name}`);
        }

        // ==================== PRINT SUMMARY ====================
        console.log('\n' + '='.repeat(60));
        console.log('✅ COMPREHENSIVE SEEDING COMPLETED SUCCESSFULLY!');
        console.log('='.repeat(60));
        console.log('\n📊 SUMMARY:');
        console.log('   👑 Admin Users:        3');
        console.log('   🏥 Labs:               6');
        console.log('   👨‍⚕️ Nurses:             8 (5 approved, 1 pending, 1 under review, 1 rejected)');
        console.log('   👤 Patients:           30');
        console.log('   📋 Orders:             100');
        console.log('   🧪 Tests per Lab:      20-45 tests');
        console.log('\n🔑 LOGIN CREDENTIALS (Password: password123 for all):');
        console.log('\n   👑 ADMIN ACCOUNTS:');
        createdUsers.admins.forEach((admin, i) => {
            console.log(`      ${admin.email}`);
        });
        console.log('\n   🏥 LAB ACCOUNTS:');
        createdUsers.labs.forEach((lab, i) => {
            console.log(`      lab${i + 1}@labgo.com`);
        });
        console.log('\n   👨‍⚕️ NURSE ACCOUNTS:');
        createdUsers.nurses.forEach((nurse, i) => {
            console.log(`      nurse${i + 1}@labgo.com`);
        });
        console.log('\n   👤 PATIENT ACCOUNTS (sample):');
        console.log('      patient1@labgo.com');
        console.log('      patient2@labgo.com');
        console.log('      patient15@labgo.com');
        console.log('\n📱 FLUTTER APP:');
        console.log('   Backend URL: http://localhost:3000');
        console.log('   Use any of the above accounts to test the app!');
        console.log('\n' + '='.repeat(60) + '\n');

    } catch (error) {
        console.error('❌ Error creating seed data:', error);
    } finally {
        await mongoose.disconnect();
        process.exit(0);
    }
};

createComprehensiveSeed();
