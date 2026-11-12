const mongoose = require('mongoose');
const Lab = require('../models/Lab');
const User = require('../models/User');
require('dotenv').config();

async function addSamplePatientTest() {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/labgo');
    console.log('Connected to database');

    // Get the first lab
    const lab = await Lab.findOne({}).sort({ createdAt: -1 });

    if (!lab) {
      console.log('No lab found!');
      process.exit(1);
    }

    console.log('Using Lab:', lab.name);

    // Get a patient user
    const patient = await User.findOne({ role: 'patient' });

    if (!patient) {
      console.log('No patient user found! Creating a sample patient...');

      // Create a sample patient if none exists
      const bcrypt = require('bcryptjs');
      const salt = await bcrypt.genSalt(12);
      const hashedPassword = await bcrypt.hash('password123', salt);

      patient = new User({
        name: 'John Doe',
        email: 'john.doe@example.com',
        phone: '+1234567890',
        gender: 'Male',
        birthDate: new Date('1990-01-01'),
        role: 'patient',
        password: hashedPassword
      });

      await patient.save();
      console.log('Created sample patient:', patient.name);
    }

    console.log('Using Patient:', patient.name);

    // Get a test from the lab's catalog or create a reference
    let testId = null;
    let testPrice = 50000;
    let testCategory = 'Blood Tests';

    if (lab.tests && lab.tests.length > 0) {
      testId = lab.tests[0]._id;
      testPrice = lab.tests[0].price;
      testCategory = lab.tests[0].category;
    }

    // Add a sample patient test
    const samplePatientTest = {
      patientId: patient._id,
      testId: testId || new mongoose.Types.ObjectId(),
      testName: lab.tests && lab.tests.length > 0 ? lab.tests[0].name : 'Complete Blood Count (CBC)',
      requestDate: new Date(),
      status: 'In Progress',
      urgency: 'Urgent',
      price: testPrice,
      notes: 'Patient fasting for 12 hours. Special handling required.'
    };

    lab.patientTests.push(samplePatientTest);
    await lab.save();

    const addedTest = lab.patientTests[lab.patientTests.length - 1];

    console.log('\n=== SAMPLE PATIENT TEST CREATED ===');
    console.log('Test ID:', addedTest._id.toString());
    console.log('Test Name:', addedTest.testName);
    console.log('Status:', addedTest.status);
    console.log('Urgency:', addedTest.urgency);
    console.log('Price:', addedTest.price);
    console.log('\nAccess URL:');
    console.log('http://localhost:3000/lab/tests/' + addedTest._id.toString());

    // Add more sample tests with different statuses
    const statuses = ['Pending', 'In Progress', 'Completed', 'Cancelled'];
    const urgencies = ['Normal', 'Urgent', 'Emergency'];

    for (let i = 0; i < 3; i++) {
      const anotherTest = {
        patientId: patient._id,
        testId: testId || new mongoose.Types.ObjectId(),
        testName: i === 0 ? 'Lipid Panel' : i === 1 ? 'Thyroid Function Test' : 'HbA1c Test',
        requestDate: new Date(Date.now() - i * 86400000),
        status: statuses[i],
        urgency: urgencies[i],
        price: 30000 + i * 10000,
        notes: i === 2 ? 'Test completed successfully. Results within normal range.' : 'Processing'
      };

      lab.patientTests.push(anotherTest);
    }

    await lab.save();
    console.log('\n=== Added 3 more sample tests ===');
    console.log('Total patient tests:', lab.patientTests.length);

    await mongoose.connection.close();
    console.log('\nDatabase connection closed');
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

addSamplePatientTest();
