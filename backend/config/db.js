const mongoose = require('mongoose');

mongoose.set('strictQuery', false);

const URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/labgo';
// const URI = "mongodb://localhost:27017/labgo";
mongoose.connect(URI)
.then(() => {
    console.log("Database connected");
})
.catch((err) => {
    console.log(err);
})