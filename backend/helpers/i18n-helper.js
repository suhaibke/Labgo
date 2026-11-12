const path = require('path');

class I18nHelper {
    constructor() {
        this.translations = {};
        this.loadTranslations();
    }

    loadTranslations() {
        const fs = require('fs');
        const languagesPath = path.join(__dirname, '../i18n/languages');

        try {
            const files = fs.readdirSync(languagesPath);
            files.forEach(file => {
                if (file.endsWith('.json')) {
                    const lang = path.basename(file, '.json');
                    const content = fs.readFileSync(path.join(languagesPath, file), 'utf8');
                    this.translations[lang] = JSON.parse(content);
                }
            });
        } catch (error) {
            console.error('Error loading translations:', error);
        }
    }

    translate(key, locale = 'ar') {
        const keys = key.split('.');
        let translation = this.translations[locale];

        for (const k of keys) {
            if (translation && translation[k]) {
                translation = translation[k];
            } else {
                // Fallback to English if translation not found
                let englishTranslation = this.translations['en'];
                for (const fallbackKey of keys) {
                    if (englishTranslation && englishTranslation[fallbackKey]) {
                        englishTranslation = englishTranslation[fallbackKey];
                    } else {
                        console.warn(`Missing translation key "${key}" for locale "${locale}", falling back to English also failed`);
                        return key; // Return the key if no translation found
                    }
                }
                return typeof englishTranslation === 'string' ? englishTranslation : key;
            }
        }

        return typeof translation === 'string' ? translation : key;
    }
}

const i18nHelper = new I18nHelper();

module.exports = {
    // Make it available as a function that can be called in templates
    __: (key, locale) => i18nHelper.translate(key, locale),
    getTranslations: () => i18nHelper.translations,
    getLocaleTranslations: (locale) => i18nHelper.translations[locale] || {}
};