const i18n = require('i18n');

module.exports = (app) => {
  i18n.configure({
    locales: ['ar', 'en', 'ku', 'tr'],

    // Directory where language files are stored
    directory: __dirname + '/languages',

    // Default language
    defaultLocale: 'ar',

    // Query parameter to switch language (e.g., ?lang=en)
    queryParameter: 'lang',

    // Cookie name to store the language preference
    cookie: 'lang',

    // Register helper for EJS templates
    register: global,

    // Object or namespace where the translations will be attached (e.g., __ for global, req.__ for request)
    api: {
      '__': '__',
      '__n': '__n'
    },

    // Auto save language preference to cookie
    autoReload: false,
    updateFiles: false,
    syncFiles: false,

    // Enable indent formatting for JSON files
    indent: '  ',

    // Setting of log level
    logLevel: 'warn',

    // Object that defines internal error messages
    missingKeyFunc: function(locale, value) {
      console.warn(`Missing translation key for locale '${locale}': '${value}'`);
      return value;
    }
  });

  // Initialize i18n
  app.use(i18n.init);

  // Import custom i18n helper
  const { __: translateHelper, getLocaleTranslations } = require('../helpers/i18n-helper');

  // Language detection middleware
  app.use((req, res, next) => {
    // Priority: Query parameter > Cookie > Accept-Language header > Default
    let locale = req.query.lang ||
                 req.cookies.lang ||
                 req.acceptsLanguages(['ar', 'en', 'ku', 'tr']) ||
                 'ar';

    // Ensure locale is supported
    if (!['ar', 'en', 'ku', 'tr'].includes(locale)) {
      locale = 'ar';
    }

    // Set language for this request
    req.setLocale(locale);

    // Set cookie if language is different from current
    if (req.query.lang && req.query.lang !== req.cookies.lang) {
      res.cookie('lang', locale, {
        maxAge: 365 * 24 * 60 * 60 * 1000, // 1 year
        httpOnly: false
      });
    }

    // Get locale translations
    const localeTranslations = getLocaleTranslations(locale);

    // Make language info available to templates
    res.locals.currentLang = locale;
    res.locals.direction = localeTranslations.direction || 'ltr';
    res.locals.font = localeTranslations.font || 'system-ui, sans-serif';

    // Expose translation function to templates
    res.locals.__ = (key) => translateHelper(key, locale);
    res.locals.__n = (key, count) => {
      // Simple pluralization - could be enhanced
      const translation = translateHelper(key, locale);
      if (count === 1) {
        return translation;
      }
      // For now, just return the translation for plural
      return translation;
    };

    res.locals.supportedLanguages = [
      { code: 'ar', name: translateHelper('languages.ar', locale), dir: 'rtl' },
      { code: 'en', name: translateHelper('languages.en', locale), dir: 'ltr' },
      { code: 'ku', name: translateHelper('languages.ku', locale), dir: 'rtl' },
      { code: 'tr', name: translateHelper('languages.tr', locale), dir: 'ltr' }
    ];

    next();
  });

  return i18n;
};