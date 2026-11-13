require('dotenv').config();
const { jwtSecret, assertSecrets } = require('./config/secrets');

// Stop early with a clear message when a required secret is missing.
assertSecrets();
const express = require('express');
const cookieParser = require('cookie-parser');
const cors = require('cors');
const app = express();
app.locals.storeLinks = require('./config/storeLinks');

// CORS configuration
app.use(cors({
  origin: true,
  credentials: true,
}));

// Import database connection
require('./config/db');

// Import models
const User = require('./models/User');

// Import authentication middleware
const { verifyToken } = require('./middleware/auth');

// Admin role verification middleware for page routes
const requireAdmin = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '') ||
      req.cookies?.token;

    if (!token) {
      return res.status(401).render('auth/login', {
        error: 'Authentication required. Please login.'
      });
    }

    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, jwtSecret());

    const user = await User.findById(decoded.userId || decoded.id).select('-password');

    if (!user || user.role !== 'admin') {
      return res.status(403).render('auth/login', {
        error: 'Access denied. Admin role required.'
      });
    }

    req.user = user;
    next();
  } catch (error) {
    return res.status(401).render('auth/login', {
      error: 'Invalid or expired token. Please login again.'
    });
  }
};

// Lab role verification middleware for page routes
const requireLab = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '') ||
      req.cookies?.token;

    if (!token) {
      return res.status(401).render('auth/login', {
        error: 'Authentication required. Please login.'
      });
    }

    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, jwtSecret());

    const user = await User.findById(decoded.userId || decoded.id).select('-password');
    const Lab = require('./models/Lab');

    if (!user || user.role !== 'lab') {
      return res.status(403).render('auth/login', {
        error: 'Access denied. Lab role required.'
      });
    }

    // Find the lab associated with this user
    const lab = await Lab.findOne({ ownerId: user._id });
    if (!lab) {
      return res.status(404).render('auth/login', {
        error: 'Lab not found for this user.'
      });
    }

    req.user = user;
    req.lab = lab;
    next();
  } catch (error) {
    return res.status(401).render('auth/login', {
      error: 'Invalid or expired token. Please login again.'
    });
  }
};

// Middleware
app.use(express.json()); // Built-in body parser for JSON
app.use(express.urlencoded({ extended: true })); // Built-in body parser for URL-encoded data
app.use(cookieParser()); // Cookie parser for language preference

// Configure i18n
require('./i18n/config')(app);

app.set('view engine', 'ejs')

// Import R2 service for file serving
const r2Service = require('./services/r2Service');

// Lab registration documents contain identity and licensing records. They are
// available only through the authenticated admin streaming endpoint.
app.use('/uploads/lab-documents', (req, res) => {
  res.status(404).json({ success: false, message: 'File not found' });
});

// Serve static files (local fallback)
app.use(express.static('public'));

// R2 file proxy endpoint - serves files from Cloudflare R2
// This handles all /uploads/* requests by fetching from R2
app.use('/uploads', async (req, res, next) => {
  try {
    const fileKey = `uploads${req.path}`;
    
    // Try to get the file from R2
    const fileData = await r2Service.getFileStream(fileKey);
    
    if (!fileData) {
      return res.status(404).json({
        success: false,
        message: 'File not found'
      });
    }

    // Set appropriate headers
    res.set('Content-Type', fileData.contentType || 'application/octet-stream');
    if (fileData.contentLength) {
      res.set('Content-Length', fileData.contentLength);
    }
    
    // Enable caching for static files
    res.set('Cache-Control', 'public, max-age=31536000'); // 1 year
    
    // Pipe the stream to the response
    fileData.stream.pipe(res);
  } catch (error) {
    console.error('R2 file serve error:', error);
    
    // Fall back to local file if R2 fails (for backward compatibility during migration)
    const localPath = require('path').join(__dirname, 'uploads', req.path);
    const fs = require('fs');
    if (fs.existsSync(localPath)) {
      return res.sendFile(localPath);
    }
    
    return res.status(404).json({
      success: false,
      message: 'File not found'
    });
  }
});

const PORT = process.env.PORT || 3000;

// Health check endpoint (for Docker/container orchestration)
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// Routes
app.use('/api/auth', require('./routes/auth/auth'));
app.use('/api/protected', require('./routes/protected'));
app.use('/api/app/labs', require('./routes/app/labs'));
app.use('/api/app/services', require('./routes/app/services'));
app.use('/api/app/packages', require('./routes/app/packages'));
app.use('/api/app/favorites', require('./routes/app/favorites'));
app.use('/api/app/banners', require('./routes/app/banners'));
app.use('/api/cart', require('./routes/cart'));
app.use('/api/orders', require('./routes/orders'));
app.use('/api/admin/orders', require('./routes/admin/orders'));
app.use('/api/admin/dashboard', require('./routes/admin/dashboard'));
app.use('/api/admin/telegram', require('./routes/admin/telegram'));
app.use('/api/admin/nurses', require('./routes/admin/nurses'));
app.use('/api/admin/patients', require('./routes/admin/patients'));
app.use('/api/admin/finance', require('./routes/admin/finance'));
app.use('/api/admin/reports', require('./routes/admin/reports'));
app.use('/api/admin/offers', require('./routes/admin/offers'));
app.use('/api/admin/coupons', require('./routes/admin/coupons'));
app.use('/api/admin/custody', require('./routes/admin/custody'));
app.use('/api/admin/services', require('./routes/admin/services'));
app.use('/api/admin/banners', require('./routes/admin/banners'));
app.use('/api/admin/waste', require('./routes/admin/waste'));
app.use('/api/admin/hub', require('./routes/admin/market-support'));
app.use('/api/nurse', require('./routes/nurse/applications'));
app.use('/api/nurse/orders', require('./routes/nurse'));
app.use('/api/nurse/finance', require('./routes/nurse/finance'));
app.use('/api/nurse/custody', require('./routes/nurse/custody'));

// FCM Notifications routes
app.use('/api/notifications', require('./routes/notifications'));

// Shop routes (public)
app.use('/api/shop', require('./routes/shop'));

// Admin shop management routes
app.use('/api/admin/shop', require('./routes/admin/shop'));

// Public routes (no authentication required)
app.use('/api/public', require('./routes/public'));

// Public check opened from the QR code on lab result reports
app.use(require('./routes/report-verify'));

// Public result upload / label pages opened from the QR code on shipping labels
app.use(require('./routes/transfer-upload'));

// Lab management routes (will be mounted after page routes)
const labRoutes = require('./routes/admin/labs');

// Language setting route
app.post('/api/language/set', (req, res) => {
  const { language } = req.body;

  // Validate language
  const validLanguages = ['en', 'ar', 'ku', 'tr'];
  if (!language || !validLanguages.includes(language)) {
    return res.status(400).json({
      success: false,
      message: 'Invalid language. Supported languages: en, ar, ku, tr'
    });
  }

  // Set cookie for language preference (expires in 1 year)
  res.cookie('lang', language, {
    maxAge: 365 * 24 * 60 * 60 * 1000, // 1 year
    httpOnly: false, // Allow JavaScript access
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax'
  });

  res.json({
    success: true,
    message: 'Language updated successfully',
    language: language
  });
});

// Get current language route
app.get('/api/language/current', (req, res) => {
  const language = req.cookies.language || req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 'en';

  res.json({
    success: true,
    language: language
  });
});

// Management website authentication pages. Patient registration stays mobile-only.
app.use('/auth', require('./routes/auth/pages'));

// Auth routes
app.get('/auth/logout', (req, res) => {
  res.clearCookie('token');
  res.redirect('/');
});

app.post('/auth/logout', (req, res) => {
  res.clearCookie('token');
  res.json({
    success: true,
    message: 'Logged out successfully'
  });
});

// Admin Dashboard route
app.get('/admin/dashboard', requireAdmin, (req, res) => {
  res.render('dashboard/admin-dashboard', { page: 'dashboard', user: req.user });
});

// Admin Finance Dashboard route
app.get('/admin/finance', requireAdmin, (req, res) => {
  res.render('dashboard/admin-finance', { page: 'finance', user: req.user });
});

// Lab management routes
app.use('/lab', require('./routes/lab/dashboard'));
app.use('/api/lab/finance', require('./routes/lab/finance'));

// Add Lab page route (must come before general labs route)
app.get('/admin/labs/add', requireAdmin, (req, res) => {
  res.render('labs/add-lab', { page: 'labs', user: req.user });
});

// Edit Lab page route (must come before general labs route)
app.get('/admin/labs/edit', requireAdmin, (req, res) => {
  res.render('labs/edit-lab', { page: 'labs', user: req.user });
});

// Lab Management page route (only exact match without trailing slash)
app.get('/admin/labs', requireAdmin, (req, res) => {
  res.render('labs/lab-management', { page: 'labs', user: req.user });
});

// Orders Management page route
app.get('/admin/orders', requireAdmin, (req, res) => {
  res.render('dashboard/admin-orders', { page: 'orders', user: req.user });
});

// Nurse Management page route
app.get('/admin/nurses', requireAdmin, (req, res) => {
  res.render('dashboard/admin-nurses', { page: 'nurses', user: req.user });
});

// Blocked Nurses page route
app.get('/admin/nurses/blocked', requireAdmin, (req, res) => {
  res.render('dashboard/admin-nurses-blocked', { page: 'nurses-blocked', user: req.user });
});

// Nurse Applications page route
app.get('/admin/nurse-applications', requireAdmin, (req, res) => {
  res.render('dashboard/admin-nurse-applications', { page: 'nurse-applications', user: req.user });
});

// Custody Management page route
app.get('/admin/custody', requireAdmin, (req, res) => {
  res.render('dashboard/admin-custody', { page: 'custody', user: req.user });
});

// Quick Services Management page route
app.get('/admin/services', requireAdmin, (req, res) => {
  res.render('dashboard/admin-services', { page: 'services', user: req.user });
});

// Home Page Banner Management page route
app.get('/admin/banners', requireAdmin, (req, res) => {
  const currentLang = req.cookies?.lang || 'ar';
  const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
  const font = currentLang === 'ar' ? 'Cairo, sans-serif' : 'Inter, sans-serif';
  res.render('dashboard/admin-banners', { page: 'banners', user: req.user, currentLang, direction, font });
});

// Marketplace review and support tickets
for (const [path, view, page] of [['/admin/market', 'admin-market', 'market'], ['/admin/support', 'admin-support', 'support']]) {
  app.get(path, requireAdmin, (req, res) => {
    const currentLang = req.cookies?.lang || 'ar';
    res.render('dashboard/' + view, { page, user: req.user, currentLang, direction: ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr', font: currentLang === 'ar' ? 'Cairo, sans-serif' : 'Inter, sans-serif' });
  });
}

// Medical waste pickup requests from the labs
app.get('/admin/waste', requireAdmin, (req, res) => {
  const currentLang = req.cookies?.lang || 'ar';
  const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
  const font = currentLang === 'ar' ? 'Cairo, sans-serif' : 'Inter, sans-serif';
  res.render('dashboard/admin-waste', { page: 'waste', user: req.user, currentLang, direction, font });
});

// Patients Management page route
app.get('/admin/patients', requireAdmin, (req, res) => {
  res.render('dashboard/admin-patients', { page: 'patients', user: req.user });
});

// Individual Patient Details page route
app.get('/admin/patients/:patientId', requireAdmin, async (req, res) => {
  try {
    const Order = require('./models/Order');
    const { patientId } = req.params;

    const patient = await User.findById(patientId).select('-password')
      .populate('blockedBy', 'name email');

    if (!patient || patient.role !== 'patient') {
      return res.status(404).render('error', {
        message: 'Patient not found'
      });
    }

    // Get ALL orders (no limit) with populated lab and nurse info
    const orders = await Order.find({ patientId })
      .populate('labId', 'name address city')
      .populate('nurseId', 'name phone')
      .sort({ createdAt: -1 });

    // Calculate order statistics
    const orderStats = await Order.aggregate([
      { $match: { patientId: patient._id } },
      {
        $group: {
          _id: null,
          totalOrders: { $sum: 1 },
          completedOrders: { $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] } },
          cancelledOrders: { $sum: { $cond: [{ $eq: ['$status', 'cancelled'] }, 1, 0] } },
          pendingOrders: { $sum: { $cond: [{ $eq: ['$status', 'pending'] }, 1, 0] } },
          totalSpent: { $sum: '$pricing.total' }
        }
      }
    ]);

    const stats = orderStats[0] || {
      totalOrders: 0,
      completedOrders: 0,
      cancelledOrders: 0,
      pendingOrders: 0,
      totalSpent: 0
    };

    res.render('dashboard/admin-patient-details', {
      patient,
      orders,
      stats,
      page: 'patients',
      user: req.user
    });
  } catch (error) {
    console.error('Get patient details page error:', error);
    res.status(500).render('error', {
      message: 'Server error'
    });
  }
});

// Reports page route
app.get('/admin/reports', requireAdmin, (req, res) => {
  res.render('dashboard/admin-reports', { page: 'reports', user: req.user });
});

// Offers Management page route
app.get('/admin/offers', requireAdmin, (req, res) => {
  res.render('dashboard/admin-offers', { page: 'offers', user: req.user });
});

// Coupons Management page route
app.get('/admin/coupons', requireAdmin, (req, res) => {
  res.render('dashboard/admin-coupons', { page: 'coupons', user: req.user });
});

// ==================== SHOP MANAGEMENT ROUTES ====================
// Shop Categories Management page
app.get('/admin/shop/categories', requireAdmin, (req, res) => {
  res.render('dashboard/admin-shop-categories', { page: 'shop', user: req.user });
});

// Shop Products Management page
app.get('/admin/shop/products', requireAdmin, (req, res) => {
  res.render('dashboard/admin-shop-products', { page: 'shop', user: req.user });
});

// Add/Edit Product page
app.get('/admin/shop/products/add', requireAdmin, (req, res) => {
  res.render('dashboard/admin-shop-product-form', { page: 'shop', user: req.user, mode: 'add' });
});

app.get('/admin/shop/products/edit/:id', requireAdmin, async (req, res) => {
  try {
    const Product = require('./models/Product');
    const product = await Product.findById(req.params.id).populate('category');
    if (!product) {
      return res.status(404).render('error', { message: 'Product not found' });
    }
    res.render('dashboard/admin-shop-product-form', { page: 'shop', user: req.user, mode: 'edit', product });
  } catch (error) {
    res.status(500).render('error', { message: 'Server error' });
  }
});

// Shop Orders Management page
app.get('/admin/shop/orders', requireAdmin, (req, res) => {
  res.render('dashboard/admin-shop-orders', { page: 'shop-orders', user: req.user });
});

// Shop Order Details page
app.get('/admin/shop/orders/:orderId', requireAdmin, async (req, res) => {
  try {
    res.render('dashboard/admin-shop-order-details', { page: 'shop-orders', user: req.user, orderId: req.params.orderId });
  } catch (error) {
    res.status(500).render('error', { message: 'Server error' });
  }
});

// Shop redirect
app.get('/admin/shop', requireAdmin, (req, res) => {
  res.redirect('/admin/shop/categories');
});

// Individual Nurse Details page route
app.get('/admin/nurses/:nurseId', requireAdmin, async (req, res) => {
  try {
    const User = require('./models/User');
    const NurseApplication = require('./models/NurseApplication');
    const { nurseId } = req.params;

    const nurse = await User.findById(nurseId).select('-password');

    if (!nurse || nurse.role !== 'nurse') {
      return res.status(404).render('error', {
        message: 'Nurse not found'
      });
    }

    // Get nurse's application to get documents
    const application = await NurseApplication.findOne({
      userId: nurseId,
      status: 'approved'
    }).sort({ submittedAt: -1 });

    res.render('dashboard/admin-nurse-details', {
      nurse,
      application,
      page: 'nurses',
      user: req.user
    });
  } catch (error) {
    console.error('Get nurse details page error:', error);
    res.status(500).render('error', {
      message: 'Server error'
    });
  }
});

// Order Details page route
app.get('/admin/orders/:orderId/details', requireAdmin, async (req, res) => {
  try {
    const Order = require('./models/Order');
    const { orderId } = req.params;

    const order = await Order.findById(orderId)
      .populate('patientId', 'name email phone')
      .populate('labId', 'name address email phone city country')
      .populate('nurseId', 'name email phone')
      .populate('adminConfirmation.confirmedBy', 'name email')
      .populate('payment.collectedBy', 'name email')
      .populate('paymentCollected.collectedBy', 'name email')
      .populate('cancellation.cancelledBy', 'name email');

    if (!order) {
      return res.status(404).render('error', {
        message: 'Order not found'
      });
    }

    res.render('dashboard/admin-order-details', {
      order,
      page: 'orders',
      user: req.user,
      path: req.baseUrl
    });
  } catch (error) {
    console.error('Get order details error:', error);
    res.status(500).render('error', {
      message: 'Server error'
    });
  }
});

// Mount API routes with a clear path separation
app.use('/admin/api/labs', labRoutes);

// Test translations
app.get('/test-translations', (req, res) => {
  const testTranslations = {
    'labManagement.title': res.locals.__('labManagement.title'),
    'labManagement.subtitle': res.locals.__('labManagement.subtitle'),
    'labManagement.status': res.locals.__('labManagement.status'),
    'labManagement.tests': res.locals.__('labManagement.tests'),
    'labManagement.patients': res.locals.__('labManagement.patients'),
    'labManagement.created': res.locals.__('labManagement.created'),
    'labManagement.allStatus': res.locals.__('labManagement.allStatus'),
    'labManagement.allCountries': res.locals.__('labManagement.allCountries'),
    'common.refresh': res.locals.__('common.refresh'),
    'common.clear': res.locals.__('common.clear'),
    'common.actions': res.locals.__('common.actions'),
    'currentLang': res.locals.currentLang,
    'direction': res.locals.direction
  };
  res.json(testTranslations);
});

// Privacy Policy page route (public)
app.get(['/terms', '/terms-of-use'], (req, res) => res.render('terms'));

app.get('/privacy-policy', (req, res) => {
  res.render('privacy-policy');
});

// ==================== PUBLIC SHOP ROUTES ====================
// Shop main page
app.get('/shop', (req, res) => {
  res.render('shop/shop', { page: 'shop' });
});

// Shop category page
app.get('/shop/category/:slug', (req, res) => {
  res.render('shop/category', { page: 'shop', categorySlug: req.params.slug });
});

// Product detail page
app.get('/shop/product/:slug', (req, res) => {
  res.render('shop/product', { page: 'shop', productSlug: req.params.slug });
});

// Cart page
app.get('/shop/cart', (req, res) => {
  res.render('shop/cart', { page: 'shop' });
});

// Checkout page
app.get('/shop/checkout', (req, res) => {
  res.render('shop/checkout', { page: 'shop' });
});

// Order confirmation page
app.get('/shop/order-confirmation/:orderNumber', (req, res) => {
  res.render('shop/order-confirmation', { page: 'shop', orderNumber: req.params.orderNumber });
});

// Order tracking page
app.get('/shop/track-order', (req, res) => {
  res.render('shop/order-tracking', { page: 'shop' });
});

// Root route - Public landing page
app.get('/', (req, res) => {
  res.render('landing');
});

// Lets iOS open https://labgo-iq.com/p/:id in the app when it's installed.
app.get('/.well-known/apple-app-site-association', (req, res) => {
  res.json({
    applinks: {
      apps: [],
      details: [{ appID: 'J2CUF228NR.com.labgollc.labgo', paths: ['/p/*'] }],
    },
  });
});

// Public package share landing page. Opens the app when installed, otherwise
// sends the visitor to the store for their device (see package-share.ejs).
app.get('/p/:packageId', async (req, res) => {
  try {
    const Package = require('./models/Package');
    const pkg = await Package.findOne({ _id: req.params.packageId, isActive: true })
      .populate('labId', 'name city status');

    if (!pkg || !pkg.labId || pkg.labId.status !== 'Active') {
      return res.status(404).render('package-share', {
        found: false,
        pkg: null,
        lab: null,
        storeLinks: app.locals.storeLinks,
      });
    }

    res.render('package-share', {
      found: true,
      pkg,
      lab: pkg.labId,
      storeLinks: app.locals.storeLinks,
    });
  } catch (error) {
    console.error('Package share page error:', error);
    res.status(500).render('package-share', {
      found: false,
      pkg: null,
      lab: null,
      storeLinks: app.locals.storeLinks,
    });
  }
});

// Admin dashboard redirect (for logged-in admins)
app.get('/admin', requireAdmin, (req, res) => {
  res.redirect('/admin/dashboard');
});

// API info route
app.get('/api', (req, res) => {
  res.json({
    message: 'LabGo API',
    status: 'running',
    endpoints: {
      auth: {
        register: 'POST /api/auth/register',
        login: 'POST /api/auth/login',
        me: 'GET /api/auth/me (requires Bearer token)'
      },
      protected: {
        profile: 'GET /api/protected/profile (requires Bearer token)',
        adminOnly: 'GET /api/protected/admin-only (admin only)',
        nurseSection: 'GET /api/protected/nurse-section (nurse, admin)',
        labSection: 'GET /api/protected/lab-section (lab, admin)',
        dashboard: 'GET /api/protected/dashboard (all roles)',
        labTests: 'GET /api/protected/lab-tests (lab, admin)',
        records: 'GET /api/protected/records/:id (owner check)',
        createAppointment: 'POST /api/protected/create-appointment (nurse, lab, admin)',
        myData: 'GET /api/protected/my-data (authenticated users)'
      }
    }
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Endpoint not found'
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
