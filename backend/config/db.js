const mongoose = require('mongoose');

mongoose.set('strictQuery', false);

const URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/labgo';
// const URI = "mongodb://localhost:27017/labgo";
mongoose.connect(URI)
.then(() => {
    console.log("Database connected");
    // Give every lab its short number (L101 ...) if it has none yet.
    require('../models/Lab').ensureNumbers()
        .then((n) => { if (n) console.log(`Lab numbers given to ${n} lab(s)`); })
        .catch((err) => console.warn('Lab numbers not given:', err.message));
})
.catch((err) => {
    console.log(err);
})