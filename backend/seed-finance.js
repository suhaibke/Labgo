const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('./models/User');
const Lab = require('./models/Lab');
const Order = require('./models/Order');
const Transaction = require('./models/Transaction');
const NurseApplication = require('./models/NurseApplication');

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/labgo', {
    useNewUrlParser: true,
    useUnifiedTopology: true,
});

// Helper function to generate random dates within current month
const randomDateThisMonth = () => {
    const now = new Date();
    const firstDay = new Date(now.getFullYear(), now.getMonth(), 1);
    const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);
    return new Date(firstDay.getTime() + Math.random() * (lastDay.getTime() - firstDay.getTime()));
};

const randomDateLastMonth = () => {
    const now = new Date();
    const firstDay = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const lastDay = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59);
    return new Date(firstDay.getTime() + Math.random() * (lastDay.getTime() - firstDay.getTime()));
};

// Helper to generate phone
const generatePhone = (index) => `+964750${String(index).padStart(6, '0')}`;

// Test catalog
const testCatalog = [
    { name: 'Complete Blood Count (CBC)', code: 'CBC001', price: 15000, category: 'Blood Tests' },
    { name: 'Fasting Blood Sugar (FBS)', code: 'FBS001', price: 8000, category: 'Biochemistry' },
    { name: 'Liver Function Test (LFT)', code: 'LFT001', price: 25000, category: 'Biochemistry' },
    { name: 'Kidney Function Test (KFT)', code: 'KFT001', price: 25000, category: 'Biochemistry' },
    { name: 'Lipid Profile', code: 'LIP001', price: 30000, category: 'Biochemistry' },
    { name: 'Thyroid Function Test (TFT)', code: 'TFT001', price: 35000, category: 'Biochemistry' },
    { name: 'Vitamin D Total', code: 'VD001', price: 40000, category: 'Biochemistry' },
    { name: 'Hemoglobin A1C', code: 'HBA1C001', price: 18000, category: 'Blood Tests' },
    { name: 'Urine Culture', code: 'URIC001', price: 35000, category: 'Microbiology' },
    { name: 'Ultrasound Abdomen', code: 'USAB001', price: 50000, category: 'Ultrasound' },
    { name: 'X-Ray Chest', code: 'XRCH001', price: 20000, category: 'X-Ray' },
    { name: 'ECG (Electrocardiogram)', code: 'ECG001', price: 25000, category: 'Cardiology' },
    { name: 'Basic Health Checkup', code: 'BHC001', price: 100000, category: 'General' },
    { name: 'Iron Studies', code: 'IRON001', price: 28000, category: 'Biochemistry' },
    { name: 'Vitamin B12', code: 'B12001', price: 35000, category: 'Biochemistry' },
    { name: 'Electrolytes Panel', code: 'ELEC001', price: 20000, category: 'Biochemistry' },
];

const seedFinanceData = async () => {
    try {
        console.log('💰 Seeding Finance Test Data...\n');

        // Get or create admin
        let admin = await User.findOne({ email: 'admin@labgo.com', role: 'admin' });
        const hashedPassword = await bcrypt.hash('password123', 12);

        if (!admin) {
            admin = await User.create({
                name: 'Admin User',
                email: 'admin@labgo.com',
                phone: '+9647500000001',
                gender: 'male',
                password: hashedPassword,
                birthDate: new Date('1990-01-01'),
                role: 'admin',
                phoneVerified: true,
            });
            console.log('✓ Created admin user');
        }

        // ==================== CREATE LABS WITH COMMISSION RATES ====================
        console.log('\n🏥 Creating labs with commission rates...');

        const labsData = [
            {
                name: 'Baghdad Central Laboratory',
                email: 'info@baghdadlab.iq',
                phone: '+9647501000001',
                city: 'Baghdad',
                commissionRate: 20, // Nurse gets 20%, Lab gets 80%
                specialization: ['Blood Tests', 'Biochemistry', 'Microbiology']
            },
            {
                name: 'Basra Diagnostic Center',
                email: 'info@basradiag.iq',
                phone: '+9647501000002',
                city: 'Basra',
                commissionRate: 25, // Nurse gets 25%, Lab gets 75%
                specialization: ['X-Ray', 'Ultrasound', 'CT Scan']
            },
            {
                name: 'Mosul Pathology Lab',
                email: 'info@mosulpath.iq',
                phone: '+9647501000003',
                city: 'Mosul',
                commissionRate: 15, // Nurse gets 15%, Lab gets 85%
                specialization: ['Pathology', 'Microbiology']
            },
        ];

        const createdLabs = [];
        for (let i = 0; i < labsData.length; i++) {
            const labInfo = labsData[i];

            // Create lab user
            let labUser = await User.findOne({ email: `lab${i + 1}@labgo.com` });
            if (!labUser) {
                labUser = await User.create({
                    name: `${labInfo.name} Manager`,
                    email: `lab${i + 1}@labgo.com`,
                    phone: labInfo.phone,
                    gender: i % 2 === 0 ? 'male' : 'female',
                    password: hashedPassword,
                    birthDate: new Date('1985-01-01'),
                    role: 'lab',
                    phoneVerified: true,
                });
            }

            // Create lab
            let lab = await Lab.findOne({ email: labInfo.email });
            if (!lab) {
                lab = await Lab.create({
                    name: labInfo.name,
                    email: labInfo.email,
                    phone: labInfo.phone,
                    address: `${labInfo.city} Center`,
                    city: labInfo.city,
                    country: 'Iraq',
                    specialization: labInfo.specialization,
                    tests: testCatalog.map(t => ({...t, _id: new mongoose.Types.ObjectId()})),
                    status: 'Active',
                    ownerId: labUser._id,
                    createdBy: admin._id,
                    commissionRate: labInfo.commissionRate,
                    isVerified: true,
                    coordinates: { latitude: 33.3152, longitude: 44.3661 }
                });
            }
            createdLabs.push(lab);
            console.log(`   ✓ ${lab.name} (${lab.commissionRate}% commission)`);
        }

        // ==================== CREATE NURSES WITH COMMISSION RATES ====================
        console.log('\n👨‍⚕️ Creating nurses with commission rates...');

        const nursesData = [
            { name: 'Sarah Ahmed', commissionRate: 20, gender: 'female' },
            { name: 'Mohammed Hassan', commissionRate: 25, gender: 'male' },
            { name: 'Fatima Ali', commissionRate: 15, gender: 'female' },
            { name: 'Omar Hussein', commissionRate: 30, gender: 'male' },
            { name: 'Layla Mohammed', commissionRate: 20, gender: 'female' },
            { name: 'Kareem Al-Sultani', commissionRate: 25, gender: 'male' },
        ];

        const createdNurses = [];
        for (let i = 0; i < nursesData.length; i++) {
            const nurseInfo = nursesData[i];

            let nurse = await User.findOne({ email: `nurse${i + 1}@labgo.com` });
            if (!nurse) {
                nurse = await User.create({
                    name: nurseInfo.name,
                    email: `nurse${i + 1}@labgo.com`,
                    phone: generatePhone(10 + i),
                    gender: nurseInfo.gender,
                    password: hashedPassword,
                    birthDate: new Date('1990-01-01'),
                    role: 'nurse',
                    phoneVerified: true,
                    // Nurse financial fields
                    nurseCommissionRate: nurseInfo.commissionRate,
                    nurseBalance: 0,
                    totalEarnings: 0,
                    totalPaidToAdmin: 0,
                    lastSettlementDate: null,
                });
            }
            createdNurses.push(nurse);
            console.log(`   ✓ ${nurse.name} (${nurse.nurseCommissionRate}% commission to admin)`);
        }

        // ==================== CREATE PATIENTS ====================
        console.log('\n👤 Creating patients...');
        const patients = [];
        for (let i = 0; i < 15; i++) {
            let patient = await User.findOne({ email: `patient${i + 1}@labgo.com` });
            if (!patient) {
                patient = await User.create({
                    name: `Patient ${i + 1}`,
                    email: `patient${i + 1}@labgo.com`,
                    phone: generatePhone(50 + i),
                    gender: i % 2 === 0 ? 'male' : 'female',
                    password: hashedPassword,
                    birthDate: new Date('1985-01-01'),
                    role: 'patient',
                    phoneVerified: true,
                });
            }
            patients.push(patient);
        }
        console.log(`   ✓ Created ${patients.length} patients`);

        // ==================== CREATE ORDERS WITH FINANCIALS ====================
        console.log('\n📋 Creating orders with financial calculations...');

        // Clear existing orders and transactions
        await Order.deleteMany({});
        await Transaction.deleteMany({});

        const ordersThisMonth = [];
        const ordersLastMonth = [];

        // Orders this month (for testing current month filter)
        for (let i = 0; i < 40; i++) {
            const lab = createdLabs[i % createdLabs.length];
            const nurse = createdNurses[i % createdNurses.length];
            const patient = patients[i % patients.length];

            const numTests = Math.floor(Math.random() * 3) + 1;
            const selectedTests = lab.tests
                .sort(() => Math.random() - 0.5)
                .slice(0, numTests)
                .map(t => ({
                    testId: t._id,
                    testName: t.name,
                    testCode: t.code,
                    category: t.category,
                    price: t.price
                }));

            const subtotal = selectedTests.reduce((sum, t) => sum + t.price, 0);
            const total = subtotal;

            // Calculate financials
            // Nurse keeps labCommissionRate% of total as earning before admin cut
            const nurseEarningBeforeAdmin = Math.round((total * lab.commissionRate) / 100);
            const labAmount = total - nurseEarningBeforeAdmin;
            // Admin gets nurseCommissionRate% of nurse's earning
            const adminAmount = Math.round((nurseEarningBeforeAdmin * nurse.nurseCommissionRate) / 100);
            const nurseNetEarning = nurseEarningBeforeAdmin - adminAmount;

            const order = await Order.create({
                patientId: patient._id,
                labId: lab._id,
                nurseId: nurse._id,
                tests: selectedTests,
                qrCode: Order.generateQRCode(),
                location: {
                    address: `Street ${i + 1}, Baghdad`,
                    coordinates: { latitude: 33.3152, longitude: 44.3661 }
                },
                orderType: 'home_collection',
                urgency: ['routine', 'urgent'][Math.floor(Math.random() * 2)],
                status: ['sample_collected', 'at_lab', 'completed'][Math.floor(Math.random() * 3)],
                payment: {
                    status: 'paid',
                    method: 'cash',
                    amount: total,
                    currency: 'IQD',
                },
                pricing: {
                    subtotal: subtotal,
                    urgencyFee: 0,
                    discount: 0,
                    total: total
                },
                paymentCollected: {
                    collected: true,
                    collectedAt: randomDateThisMonth(),
                    collectedBy: nurse._id,
                },
                financials: {
                    labCommissionRate: lab.commissionRate,
                    nurseCommissionRate: nurse.nurseCommissionRate,
                    labAmount: labAmount,
                    nurseEarningBeforeAdmin: nurseEarningBeforeAdmin,
                    adminAmount: adminAmount,
                    nurseNetEarning: nurseNetEarning,
                    labSettled: Math.random() > 0.5,
                    adminSettled: Math.random() > 0.7,
                },
                createdAt: randomDateThisMonth(),
            });
            ordersThisMonth.push(order);
        }

        // Orders last month (for testing date range filter)
        for (let i = 0; i < 25; i++) {
            const lab = createdLabs[i % createdLabs.length];
            const nurse = createdNurses[(i + 1) % createdNurses.length];
            const patient = patients[(i + 2) % patients.length];

            const numTests = Math.floor(Math.random() * 3) + 1;
            const selectedTests = lab.tests
                .sort(() => Math.random() - 0.5)
                .slice(0, numTests)
                .map(t => ({
                    testId: t._id,
                    testName: t.name,
                    testCode: t.code,
                    category: t.category,
                    price: t.price
                }));

            const subtotal = selectedTests.reduce((sum, t) => sum + t.price, 0);
            const total = subtotal;

            const nurseEarningBeforeAdmin = Math.round((total * lab.commissionRate) / 100);
            const labAmount = total - nurseEarningBeforeAdmin;
            const adminAmount = Math.round((nurseEarningBeforeAdmin * nurse.nurseCommissionRate) / 100);
            const nurseNetEarning = nurseEarningBeforeAdmin - adminAmount;

            const order = await Order.create({
                patientId: patient._id,
                labId: lab._id,
                nurseId: nurse._id,
                tests: selectedTests,
                qrCode: Order.generateQRCode(),
                location: {
                    address: `Street ${i + 100}, Baghdad`,
                    coordinates: { latitude: 33.3152, longitude: 44.3661 }
                },
                orderType: 'home_collection',
                urgency: 'routine',
                status: 'completed',
                payment: {
                    status: 'paid',
                    method: 'cash',
                    amount: total,
                    currency: 'IQD',
                },
                pricing: {
                    subtotal: subtotal,
                    total: total
                },
                paymentCollected: {
                    collected: true,
                    collectedAt: randomDateLastMonth(),
                    collectedBy: nurse._id,
                },
                financials: {
                    labCommissionRate: lab.commissionRate,
                    nurseCommissionRate: nurse.nurseCommissionRate,
                    labAmount: labAmount,
                    nurseEarningBeforeAdmin: nurseEarningBeforeAdmin,
                    adminAmount: adminAmount,
                    nurseNetEarning: nurseNetEarning,
                    labSettled: true,
                    adminSettled: true,
                    labSettledAt: randomDateLastMonth(),
                    adminSettledAt: randomDateLastMonth(),
                },
                results: {
                    reportUrl: `https://example.com/report-${i}.pdf`,
                    completedAt: randomDateLastMonth(),
                },
                createdAt: randomDateLastMonth(),
            });
            ordersLastMonth.push(order);
        }

        console.log(`   ✓ Created ${ordersThisMonth.length} orders this month`);
        console.log(`   ✓ Created ${ordersLastMonth.length} orders last month`);

        // ==================== CREATE TRANSACTIONS ====================
        console.log('\n💳 Creating transactions...');

        let transactionCount = 0;

        // Create admin settlement transactions
        for (const nurse of createdNurses) {
            // Get orders where this nurse is involved and admin settlement is done
            const settledOrders = [...ordersThisMonth, ...ordersLastMonth].filter(
                o => o.nurseId?.toString() === nurse._id.toString() && o.financials.adminSettled
            );

            for (const order of settledOrders.slice(0, 5)) {
                await Transaction.create({
                    type: 'admin_settlement',
                    amount: order.financials.adminAmount,
                    currency: 'IQD',
                    nurseId: nurse._id,
                    orderId: order._id,
                    labId: order.labId,
                    processedBy: admin._id,
                    description: `Admin settlement for order ${order.qrCode}`,
                    referenceNumber: Transaction.generateReferenceNumber('admin_settlement'),
                    breakdown: {
                        totalAmount: order.pricing.total,
                        labAmount: order.financials.labAmount,
                        adminCommission: order.financials.adminAmount,
                        commissionRate: order.financials.nurseCommissionRate,
                    },
                    balanceAfter: {
                        nurseBalance: Math.floor(Math.random() * 100000),
                    },
                    status: 'completed',
                    createdAt: randomDateThisMonth(),
                });
                transactionCount++;
            }

            // Update nurse's financial stats
            const nurseOrders = [...ordersThisMonth, ...ordersLastMonth].filter(
                o => o.nurseId?.toString() === nurse._id.toString() && o.paymentCollected.collected
            );

            const totalEarnings = nurseOrders.reduce((sum, o) => sum + o.financials.nurseEarningBeforeAdmin, 0);
            const totalAdminAmount = nurseOrders.reduce((sum, o) => sum + o.financials.adminAmount, 0);
            const totalPaid = nurseOrders.filter(o => o.financials.adminSettled).reduce((sum, o) => sum + o.financials.adminAmount, 0);

            nurse.totalEarnings = totalEarnings;
            nurse.totalPaidToAdmin = totalPaid;
            nurse.nurseBalance = totalAdminAmount - totalPaid;
            if (totalPaid > 0) {
                nurse.lastSettlementDate = randomDateThisMonth();
            }
            await nurse.save();
        }

        // Create lab settlement transactions
        for (const lab of createdLabs) {
            const labOrders = [...ordersThisMonth, ...ordersLastMonth].filter(
                o => o.labId?.toString() === lab._id.toString() && o.financials.labSettled
            );

            for (const order of labOrders.slice(0, 3)) {
                const nurse = await User.findById(order.nurseId);
                await Transaction.create({
                    type: 'lab_settlement',
                    amount: order.financials.labAmount,
                    currency: 'IQD',
                    nurseId: nurse?._id,
                    orderId: order._id,
                    labId: lab._id,
                    processedBy: admin._id,
                    description: `Lab payment for order ${order.qrCode}`,
                    referenceNumber: Transaction.generateReferenceNumber('lab_settlement'),
                    breakdown: {
                        totalAmount: order.pricing.total,
                        labAmount: order.financials.labAmount,
                        commissionRate: order.financials.labCommissionRate,
                    },
                    status: 'completed',
                    createdAt: randomDateThisMonth(),
                });
                transactionCount++;
            }
        }

        console.log(`   ✓ Created ${transactionCount} transactions`);

        // ==================== CALCULATE TOTALS FOR DISPLAY ====================
        const totalRevenue = [...ordersThisMonth, ...ordersLastMonth].reduce((sum, o) => sum + o.pricing.total, 0);
        const totalAdminAmount = [...ordersThisMonth, ...ordersLastMonth].reduce((sum, o) => sum + o.financials.adminAmount, 0);
        const totalLabAmount = [...ordersThisMonth, ...ordersLastMonth].reduce((sum, o) => sum + o.financials.labAmount, 0);
        const totalNurseEarnings = [...ordersThisMonth, ...ordersLastMonth].reduce((sum, o) => sum + o.financials.nurseNetEarning, 0);

        // ==================== PRINT SUMMARY ====================
        console.log('\n' + '='.repeat(60));
        console.log('✅ FINANCE TEST DATA SEEDED SUCCESSFULLY!');
        console.log('='.repeat(60));
        console.log('\n📊 FINANCIAL SUMMARY:');
        console.log(`   💰 Total Revenue (all orders):     ${formatMoney(totalRevenue)}`);
        console.log(`   👑 Admin Share:                    ${formatMoney(totalAdminAmount)}`);
        console.log(`   🏥 Lab Share:                      ${formatMoney(totalLabAmount)}`);
        console.log(`   👨‍⚕️ Nurse Earnings:                 ${formatMoney(totalNurseEarnings)}`);
        console.log(`   📋 Orders This Month:               ${ordersThisMonth.length}`);
        console.log(`   📋 Orders Last Month:               ${ordersLastMonth.length}`);
        console.log('\n👨‍⚕️ NURSE BALANCES:');
        for (const nurse of createdNurses) {
            console.log(`   ${nurse.name}: Balance ${formatMoney(nurse.nurseBalance)} | Earned ${formatMoney(nurse.totalEarnings)} | Paid ${formatMoney(nurse.totalPaidToAdmin)}`);
        }

        console.log('\n🏥 LABS WITH COMMISSION RATES:');
        for (const lab of createdLabs) {
            console.log(`   ${lab.name}: ${lab.commissionRate}% commission`);
        }

        console.log('\n🔑 LOGIN CREDENTIALS (Password: password123):');
        console.log('   👑 Admin:     admin@labgo.com');
        console.log('   👨‍⚕️ Nurses:   nurse1@labgo.com through nurse6@labgo.com');
        console.log('   👤 Patients:  patient1@labgo.com through patient15@labgo.com');

        console.log('\n💡 DATE FILTER TESTING:');
        console.log('   • "This Month" will show ' + ordersThisMonth.length + ' orders');
        console.log('   • "Last Month" will show ' + ordersLastMonth.length + ' orders');
        console.log('   • Total: ' + (ordersThisMonth.length + ordersLastMonth.length) + ' orders');
        console.log('\n' + '='.repeat(60) + '\n');

    } catch (error) {
        console.error('❌ Error seeding finance data:', error);
    } finally {
        await mongoose.disconnect();
        process.exit(0);
    }
};

function formatMoney(amount) {
    return new Intl.NumberFormat('en-IQ', {
        style: 'currency',
        currency: 'IQD',
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
    }).format(amount);
}

seedFinanceData();
