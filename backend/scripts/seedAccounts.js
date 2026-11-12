const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('../models/User');
require('dotenv').config();

// Test accounts data
const testAccounts = [
  { name: 'Ahmed Ali', email: 'ahmed.ali@test.com', phone: '07501234567', gender: 'male', role: 'patient' },
  { name: 'Fatima Hassan', email: 'fatima.hassan@test.com', phone: '07501234568', gender: 'female', role: 'patient' },
  { name: 'Omar Karim', email: 'omar.karim@test.com', phone: '07501234569', gender: 'male', role: 'patient' },
  { name: 'Layla Mahmoud', email: 'layla.mahmoud@test.com', phone: '07501234570', gender: 'female', role: 'patient' },
  { name: 'Yusuf Rahman', email: 'yusuf.rahman@test.com', phone: '07501234571', gender: 'male', role: 'patient' },
  { name: 'Aisha Khidir', email: 'aisha.khidir@test.com', phone: '07501234572', gender: 'female', role: 'patient' },
  { name: 'Hussein Omar', email: 'hussein.omar@test.com', phone: '07501234573', gender: 'male', role: 'patient' },
  { name: 'Zainab Ali', email: 'zainab.ali@test.com', phone: '07501234574', gender: 'female', role: 'patient' },
  { name: 'Ali Hassan', email: 'ali.hassan@test.com', phone: '07501234575', gender: 'male', role: 'patient' },
  { name: 'Rana Karim', email: 'rana.karim@test.com', phone: '07501234576', gender: 'female', role: 'patient' },
  { name: 'Mohammed Tariq', email: 'mohammed.tariq@test.com', phone: '07501234577', gender: 'male', role: 'patient' },
  { name: 'Sarah Ahmed', email: 'sarah.ahmed@test.com', phone: '07501234578', gender: 'female', role: 'patient' },
  { name: 'Khalid Yasin', email: 'khalid.yasin@test.com', phone: '07501234579', gender: 'male', role: 'patient' },
  { name: 'Nour Hussein', email: 'nour.hussein@test.com', phone: '07501234580', gender: 'female', role: 'patient' },
  { name: 'Ibrahim Malik', email: 'ibrahim.malik@test.com', phone: '07501234581', gender: 'male', role: 'patient' },
  { name: 'Hana Rashid', email: 'hana.rashid@test.com', phone: '07501234582', gender: 'female', role: 'patient' },
  { name: 'Jasim Nabil', email: 'jasim.nabil@test.com', phone: '07501234583', gender: 'male', role: 'patient' },
  { name: 'Mona Samir', email: 'mona.samir@test.com', phone: '07501234584', gender: 'female', role: 'patient' },
  { name: 'Tariq Farooq', email: 'tariq.farooq@test.com', phone: '07501234585', gender: 'male', role: 'patient' },
  { name: 'Lamia Walid', email: 'lamia.walid@test.com', phone: '07501234586', gender: 'female', role: 'patient' },
  { name: 'Dr. Saad Ibrahim', email: 'dr.saad@labgo.com', phone: '07701234501', gender: 'male', role: 'nurse' },
  { name: 'Dr. Maha Karim', email: 'dr.maha@labgo.com', phone: '07701234502', gender: 'female', role: 'nurse' },
  { name: 'Dr. Amir Hassan', email: 'dr.amir@labgo.com', phone: '07701234503', gender: 'male', role: 'nurse' },
  { name: 'Dr. Ruqaya Ahmed', email: 'dr.ruqaya@labgo.com', phone: '07701234504', gender: 'female', role: 'nurse' },
  { name: 'Dr. Nabil Omar', email: 'dr.nabil@labgo.com', phone: '07701234505', gender: 'male', role: 'nurse' },
  { name: 'Central Lab Baghdad', email: 'lab.baghdad@labgo.com', phone: '07801234501', gender: 'male', role: 'lab' },
  { name: 'Central Lab Basra', email: 'lab.basra@labgo.com', phone: '07801234502', gender: 'male', role: 'lab' },
  { name: 'Central Lab Erbil', email: 'lab.erbil@labgo.com', phone: '07801234503', gender: 'male', role: 'lab' },
  { name: 'Admin User', email: 'admin@labgo.com', phone: '07901234501', gender: 'male', role: 'admin' },
  { name: 'Support Team', email: 'support@labgo.com', phone: '07901234502', gender: 'female', role: 'admin' },
  { name: 'Test Account', email: 'test@test.com', phone: '07509998877', gender: 'male', role: 'patient' },
];

async function seedAccounts() {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/labgo', {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('Connected to MongoDB');

    let created = 0;
    let skipped = 0;

    for (const account of testAccounts) {
      // Check if user already exists
      const existingUser = await User.findOne({ email: account.email });
      if (existingUser) {
        console.log(`Skipped: ${account.email} (already exists)`);
        skipped++;
        continue;
      }

      // Hash password (email is the password)
      const salt = await bcrypt.genSalt(12);
      const hashedPassword = await bcrypt.hash(account.email, salt);

      // Create user
      const user = new User({
        name: account.name,
        email: account.email,
        phone: account.phone,
        gender: account.gender,
        password: hashedPassword,
        birthDate: new Date(1990, 0, 1), // Default birthdate
        role: account.role,
        status: 'active',
        phoneVerified: true,
      });

      await user.save();
      console.log(`Created: ${account.email} | Password: ${account.email}`);
      created++;
    }

    console.log('\n=================================');
    console.log(`Seeding completed!`);
    console.log(`Created: ${created} accounts`);
    console.log(`Skipped: ${skipped} accounts (already existed)`);
    console.log('=================================\n');

    await mongoose.disconnect();
  } catch (error) {
    console.error('Error seeding accounts:', error);
    process.exit(1);
  }
}

seedAccounts();
