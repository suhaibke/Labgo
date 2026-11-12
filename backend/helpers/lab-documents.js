const LAB_DOCUMENT_DEFINITIONS = Object.freeze({
    labCertificates: { maxCount: 5 },
    labOpeningLetter: { maxCount: 1 },
    labOpeningLicense: { maxCount: 1 },
    practiceLicense: { maxCount: 1 },
    ownerUnifiedCard: { maxCount: 2 },
    ownerDepartmentOrRetirementId: { maxCount: 2 }
});

const LAB_DOCUMENT_FIELDS = Object.freeze(Object.keys(LAB_DOCUMENT_DEFINITIONS));

function buildLabDocuments(files = {}) {
    return Object.fromEntries(LAB_DOCUMENT_FIELDS.map(fieldName => [
        fieldName,
        (files[fieldName] || []).map(file => ({
            originalName: file.originalname,
            url: file.r2Url,
            storageKey: file.r2?.key || String(file.r2Url || '').replace(/^\//, ''),
            mimeType: file.mimetype,
            size: file.size,
            uploadedAt: new Date()
        }))
    ]));
}

function getUploadedFileUrls(files = {}) {
    return Object.values(files)
        .flat()
        .map(file => file?.r2Url)
        .filter(Boolean);
}

function getStoredDocumentUrls(documents = {}) {
    return LAB_DOCUMENT_FIELDS.flatMap(fieldName =>
        (documents[fieldName] || []).map(document => document?.url).filter(Boolean)
    );
}

module.exports = {
    LAB_DOCUMENT_DEFINITIONS,
    LAB_DOCUMENT_FIELDS,
    buildLabDocuments,
    getUploadedFileUrls,
    getStoredDocumentUrls
};
