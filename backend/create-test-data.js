const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('./models/User');
const Lab = require('./models/Lab');

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/labgo', {
    useNewUrlParser: true,
    useUnifiedTopology: true,
});

const createTestData = async () => {
    try {
        console.log('Creating test lab user and lab data...');

        // Create a lab user
        const existingLabUser = await User.findOne({ email: 'lab@test.com' });
        let labUser;

        if (!existingLabUser) {
            const hashedPassword = await bcrypt.hash('password123', 12);
            labUser = new User({
                name: 'Dr. John Smith',
                email: 'lab@test.com',
                phone: '+1234567890',
                gender: 'male',
                password: hashedPassword,
                birthDate: new Date('1980-01-01'),
                role: 'lab'
            });
            await labUser.save();
            console.log('Created lab user:', labUser.email);
        } else {
            labUser = existingLabUser;
            console.log('Using existing lab user:', labUser.email);
        }

        // Create a lab for this user
        const existingLab = await Lab.findOne({ ownerId: labUser._id });
        let lab;

        if (!existingLab) {
            lab = new Lab({
                name: 'Advanced Medical Laboratory',
                email: 'info@advancedlab.com',
                phone: '+1234567890',
                address: '123 Healthcare Ave',
                city: 'New York',
                country: 'USA',
                website: 'https://advancedlab.com',
                specialization: ['Blood Tests', 'X-Ray', 'MRI', 'CT Scan', 'Pathology'],
                operatingHours: {
                    monday: { open: '08:00', close: '18:00', closed: false },
                    tuesday: { open: '08:00', close: '18:00', closed: false },
                    wednesday: { open: '08:00', close: '18:00', closed: false },
                    thursday: { open: '08:00', close: '18:00', closed: false },
                    friday: { open: '08:00', close: '18:00', closed: false },
                    saturday: { open: '09:00', close: '14:00', closed: false },
                    sunday: { open: '08:00', close: '18:00', closed: true }
                },
                tests: [
                    {
                        name: 'Complete Blood Count',
                        code: 'CBC001',
                        price: 45,
                        description: 'Full blood panel including red and white blood cells',
                        category: 'Basic'
                    },
                    {
                        name: 'Comprehensive Metabolic Panel',
                        code: 'CMP001',
                        price: 65,
                        description: 'Metabolic function tests including kidney and liver panels',
                        category: 'Advanced'
                    },
                    {
                        name: 'COVID-19 PCR Test',
                        code: 'COVID001',
                        price: 120,
                        description: 'RT-PCR test for COVID-19 detection',
                        category: 'Emergency'
                    }
                ],
                status: 'Active',
                licenseNumber: 'LAB-NY-2024-001',
                accreditation: 'CLIA Certified',
                description: 'Advanced Medical Laboratory provides comprehensive diagnostic services with state-of-the-art equipment and experienced medical professionals.',
                totalPatientsServed: 1247,
                totalTestsPerformed: 3456,
                averageRating: 4.7,
                totalReviews: 89,
                ownerId: labUser._id,
                createdBy: labUser._id,
                isVerified: true,
                verificationDate: new Date('2024-01-15'),
                coordinates: {
                    latitude: 40.7128,
                    longitude: -74.0060
                },
                paymentMethods: ['Cash', 'Credit Card', 'Insurance'],
                insuranceProviders: ['Blue Cross', 'Aetna', 'Cigna'],
                emergencyContact: {
                    phone: '+1234567890',
                    email: 'emergency@advancedlab.com'
                },
                patientTests: [
                    {
                        patientId: new mongoose.Types.ObjectId(),
                        testId: new mongoose.Types.ObjectId(),
                        testName: 'Complete Blood Count',
                        requestDate: new Date(Date.now() - 24 * 60 * 60 * 1000), // 1 day ago
                        status: 'Pending',
                        urgency: 'Normal',
                        price: 45
                    },
                    {
                        patientId: new mongoose.Types.ObjectId(),
                        testId: new mongoose.Types.ObjectId(),
                        testName: 'COVID-19 PCR Test',
                        requestDate: new Date(Date.now() - 2 * 60 * 60 * 1000), // 2 hours ago
                        status: 'In Progress',
                        urgency: 'Urgent',
                        price: 120
                    },
                    {
                        patientId: new mongoose.Types.ObjectId(),
                        testId: new mongoose.Types.ObjectId(),
                        testName: 'Comprehensive Metabolic Panel',
                        requestDate: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000), // 3 days ago
                        status: 'Completed',
                        resultDate: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000),
                        urgency: 'Normal',
                        price: 65
                    }
                ]
            });
            await lab.save();
            console.log('Created lab:', lab.name);
        } else {
            lab = existingLab;
            console.log('Using existing lab:', lab.name);
        }

        console.log('\n✅ Test data created successfully!');
        console.log('📧 Lab user login: lab@test.com');
        console.log('🔑 Password: password123');
        console.log('🔗 Lab Dashboard: http://localhost:3000/lab/dashboard');

    } catch (error) {
        console.error('Error creating test data:', error);
    } finally {
        await mongoose.disconnect();
        process.exit(0);
    }
};

createTestData();