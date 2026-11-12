const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('./models/User');
const Lab = require('./models/Lab');
const Order = require('./models/Order');
const Transaction = require('./models/Transaction');

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/labgo', {
    useNewUrlParser: true,
    useUnifiedTopology: true,
});

const cleanAndSeed = async () => {
    try {
        console.log('🧹 Clearing all finance data...');

        // Clear all collections
        await User.deleteMany({});
        await Lab.deleteMany({});
        await Order.deleteMany({});
        await Transaction.deleteMany({});

        console.log('✓ All data cleared\n');

        // Import and run the seed logic
        const seed = require('./seed-finance');
        await seed.seedFinanceData();

    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
};

cleanAndSeed();
