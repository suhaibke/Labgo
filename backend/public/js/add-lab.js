// ==========================================
// LabGo Add Lab Form - Apple Style Interactions
// ==========================================

const LAB_DOCUMENT_FIELDS = [
    'labCertificates',
    'labOpeningLetter',
    'labOpeningLicense',
    'practiceLicense',
    'ownerUnifiedCard',
    'ownerDepartmentOrRetirementId'
];
const MAX_LAB_DOCUMENT_SIZE = 5 * 1024 * 1024;

document.addEventListener('DOMContentLoaded', function() {
    initializeAddLabForm();
});

function initializeAddLabForm() {
    initializeFormValidation();
    initializeSpecializationInteractions();
    initializeLogoUpload();
    initializeOwnerEmailSearch();
    initializeFormProgress();
    initializeFormSubmission();
    initializeCommissionPreview();
    initializeLabLocationMap();
}

// ==========================================
// Location Map (lab coordinates)
// ==========================================

let labLocationMap = null;
let labLocationMarker = null;

function initializeLabLocationMap() {
    const mapEl = document.getElementById('labLocationMap');
    if (!mapEl || typeof L === 'undefined') return;

    const defaultLat = 33.3152; // Baghdad
    const defaultLng = 44.3661;

    labLocationMap = L.map('labLocationMap').setView([defaultLat, defaultLng], 11);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors',
        maxZoom: 19
    }).addTo(labLocationMap);

    labLocationMap.on('click', function (e) {
        setLabLocationMarker(e.latlng.lat, e.latlng.lng);
    });
}

function setLabLocationMarker(lat, lng) {
    if (!labLocationMap) return;

    if (labLocationMarker) {
        labLocationMarker.setLatLng([lat, lng]);
    } else {
        labLocationMarker = L.marker([lat, lng], { draggable: true }).addTo(labLocationMap);
        labLocationMarker.on('dragend', function (e) {
            const pos = e.target.getLatLng();
            updateLabCoordsFields(pos.lat, pos.lng);
            reverseGeocodeLab(pos.lat, pos.lng);
        });
    }

    updateLabCoordsFields(lat, lng);
    reverseGeocodeLab(lat, lng);
}

const IRAQ_GOVERNORATES = [
    'بغداد', 'البصرة', 'نينوى', 'الأنبار', 'كركوك', 'صلاح الدين', 'ديالى', 'بابل',
    'كربلاء', 'النجف', 'القادسية', 'المثنى', 'واسط', 'ذي قار', 'ميسان', 'أربيل',
    'السليمانية', 'دهوك'
];

// Reverse-geocode a picked point into the hidden city field and show a
// read-only summary line (governorate). Address and zone stay manual.
async function reverseGeocodeLab(lat, lng) {
    try {
        const response = await fetch(
            `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}&zoom=14&addressdetails=1`,
            { headers: { 'Accept-Language': 'ar' } }
        );
        const data = await response.json();
        if (!data) return;

        const address = data.address || {};
        const candidates = [address.state, address.county, address.city, address.region].filter(Boolean);
        const matchedGovernorate = IRAQ_GOVERNORATES.find((gov) =>
            candidates.some((c) => c === gov || c.includes(gov) || gov.includes(c))
        );

        const cityInput = document.getElementById('labCity');
        // Only auto-select when we're confident it's a real governorate -
        // never push unmatched/foreign-language geocoder text into the field,
        // the admin picks it manually instead.
        if (cityInput && matchedGovernorate) cityInput.value = matchedGovernorate;

        const summary = document.getElementById('labLocationSummary');
        if (summary) {
            summary.textContent = matchedGovernorate
                ? matchedGovernorate
                : (candidates[0] || '') + ' - يرجى اختيار المحافظة يدويًا';
        }
    } catch (error) {
        console.error('Reverse geocoding error:', error);
    }
}

function updateLabCoordsFields(lat, lng) {
    const coordsInput = document.getElementById('labCoordinates');
    const display = document.getElementById('labCoordsDisplay');
    if (coordsInput) coordsInput.value = JSON.stringify({ latitude: lat, longitude: lng });
    if (display) display.textContent = `${lat.toFixed(6)}, ${lng.toFixed(6)}`;
}

function useMyLocation() {
    if (!navigator.geolocation) return;

    navigator.geolocation.getCurrentPosition(
        function (position) {
            const lat = position.coords.latitude;
            const lng = position.coords.longitude;
            labLocationMap.setView([lat, lng], 15);
            setLabLocationMarker(lat, lng);
        },
        function (error) {
            console.error('Geolocation error:', error);
        }
    );
}

// ==========================================
// Form Validation
// ==========================================

function initializeFormValidation() {
    const form = document.getElementById('addLabForm');
    const inputs = form.querySelectorAll('.form-input, .form-select, .form-textarea');

    inputs.forEach(input => {
        // Add real-time validation
        input.addEventListener('blur', function() {
            validateField(this);
        });

        input.addEventListener('input', function() {
            // Clear error state when user starts typing
            if (this.parentElement.classList.contains('error')) {
                this.parentElement.classList.remove('error');
            }
            updateFormProgress();
        });

        // Add focus effects
        input.addEventListener('focus', function() {
            this.parentElement.style.transform = 'translateY(-1px)';
        });

        input.addEventListener('blur', function() {
            this.parentElement.style.transform = 'translateY(0)';
        });
    });
}

function validateField(field) {
    const formGroup = field.closest('.form-group');
    const errorMessage = formGroup.querySelector('.error-message');
    let isValid = true;
    let errorText = '';

    // Remove previous error state
    formGroup.classList.remove('error');

    // Special validation for owner email field
    if (field.id === 'ownerEmail') {
        const ownerId = document.getElementById('ownerId').value;
        if (!ownerId && !field.value.trim()) {
            isValid = false;
            errorText = 'Please select a lab owner';
        }
        return isValid;
    }

    // Check if field is required and empty
    if (field.hasAttribute('required') && !field.value.trim()) {
        isValid = false;
        errorText = 'This field is required';
    }

    // Email validation
    if (field.type === 'email' && field.value) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(field.value)) {
            isValid = false;
            errorText = 'Please enter a valid email address';
        }
    }

    // Phone validation
    if (field.type === 'tel' && field.value) {
        const phoneRegex = /^[\d\s\-\+\(\)]+$/;
        if (!phoneRegex.test(field.value) || field.value.replace(/\D/g, '').length < 10) {
            isValid = false;
            errorText = 'Please enter a valid phone number';
        }
    }

    // URL validation
    if (field.type === 'url' && field.value) {
        try {
            new URL(field.value);
        } catch {
            isValid = false;
            errorText = 'Please enter a valid URL (e.g., https://example.com)';
        }
    }

    // Show error state
    if (!isValid) {
        formGroup.classList.add('error');
        if (errorMessage) {
            errorMessage.textContent = errorText;
        }
        // Add haptic feedback if available
        if (navigator.vibrate) {
            navigator.vibrate(50);
        }
    }

    return isValid;
}

function validateForm() {
    const form = document.getElementById('addLabForm');
    const requiredFields = form.querySelectorAll('[required]');
    let isValid = true;

    requiredFields.forEach(field => {
        if (!validateField(field)) {
            isValid = false;
        }
    });

    return isValid;
}

// ==========================================
// Specialization Interactions
// ==========================================

function initializeSpecializationInteractions() {
    const specializationItems = document.querySelectorAll('.specialization-item');

    specializationItems.forEach(item => {
        item.addEventListener('click', function(e) {
            if (e.target.tagName !== 'INPUT') {
                const checkbox = this.querySelector('input[type="checkbox"]');
                checkbox.checked = !checkbox.checked;
            }
            this.classList.toggle('selected', this.querySelector('input[type="checkbox"]').checked);

            // Add haptic feedback if available
            if (navigator.vibrate) {
                navigator.vibrate(10);
            }
        });
    });
}

function getSelectedSpecializations() {
    const checkboxes = document.querySelectorAll('input[name="specializations"]:checked');
    return Array.from(checkboxes).map(cb => cb.value);
}

// ==========================================
// Logo Upload
// ==========================================

function initializeLogoUpload() {
    const logoInput = document.getElementById('labLogo');
    const logoPreview = document.getElementById('logoPreview');

    if (!logoInput || !logoPreview) return;

    logoPreview.addEventListener('click', function() {
        logoInput.click();
    });

    logoInput.addEventListener('change', function(e) {
        const file = e.target.files[0];
        if (file && file.type.startsWith('image/')) {
            const reader = new FileReader();
            reader.onload = function(e) {
                logoPreview.innerHTML = `<img src="${e.target.result}" alt="Lab Logo">`;
                logoPreview.classList.add('has-image');
            };
            reader.readAsDataURL(file);
        }
    });
}

// ==========================================
// Owner Email Search
// ==========================================

let ownerSearchTimeout;

function initializeOwnerEmailSearch() {
    const ownerEmailInput = document.getElementById('ownerEmail');
    const searchResults = document.getElementById('ownerSearchResults');
    const loadingIndicator = document.querySelector('.owner-loading');
    const selectedOwnerDiv = document.getElementById('selectedOwner');
    const removeOwnerBtn = document.getElementById('removeOwner');

    if (!ownerEmailInput || !searchResults) return;

    // Email input handler
    ownerEmailInput.addEventListener('input', function() {
        const email = this.value.trim();

        if (email.length < 3) {
            hideSearchResults();
            return;
        }

        // Debounce search
        clearTimeout(ownerSearchTimeout);
        ownerSearchTimeout = setTimeout(() => {
            searchOwnerByEmail(email);
        }, 300);
    });

    // Click outside to hide results
    document.addEventListener('click', function(e) {
        if (!searchResults.contains(e.target) && e.target !== ownerEmailInput) {
            hideSearchResults();
        }
    });

    // Remove owner handler
    if (removeOwnerBtn) {
        removeOwnerBtn.addEventListener('click', removeSelectedOwner);
    }
}

async function searchOwnerByEmail(email) {
    const searchResults = document.getElementById('ownerSearchResults');
    const loadingIndicator = document.querySelector('.owner-loading');

    try {
        loadingIndicator.classList.add('show');

        const response = await fetch(`/admin/api/labs/search-owner?email=${encodeURIComponent(email)}`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${getAuthToken()}`
            }
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.message || 'Failed to search for owner');
        }

        displayOwnerSearchResults(data.users || []);

    } catch (error) {
        console.error('Error searching for owner:', error);
        displayOwnerSearchResults([]);
    } finally {
        loadingIndicator.classList.remove('show');
    }
}

function displayOwnerSearchResults(users) {
    const searchResults = document.getElementById('ownerSearchResults');

    if (users.length === 0) {
        searchResults.innerHTML = `
            <div class="owner-search-item">
                <div style="padding: 20px; text-align: center; color: #86868b;">
                    No users found
                </div>
            </div>
        `;
        searchResults.classList.add('show');
        return;
    }

    searchResults.innerHTML = users.map(user => `
        <div class="owner-search-item" onclick="selectOwner('${user._id}', '${escapeHtml(user.name)}', '${escapeHtml(user.email)}')">
            <div class="owner-search-name">${escapeHtml(user.name)}</div>
            <div class="owner-search-email">${escapeHtml(user.email)}</div>
        </div>
    `).join('');

    searchResults.classList.add('show');
}

function selectOwner(userId, name, email) {
    const ownerIdInput = document.getElementById('ownerId');
    const selectedOwnerDiv = document.getElementById('selectedOwner');
    const selectedOwnerName = document.getElementById('selectedOwnerName');
    const selectedOwnerEmail = document.getElementById('selectedOwnerEmail');
    const ownerEmailInput = document.getElementById('ownerEmail');
    const formGroup = ownerEmailInput.closest('.form-group');

    // Set hidden input value
    ownerIdInput.value = userId;

    // Update selected owner display (using textContent to prevent HTML injection)
    selectedOwnerName.textContent = name;
    selectedOwnerEmail.textContent = email;

    // Show selected owner section
    selectedOwnerDiv.style.display = 'block';

    // Clear email input
    ownerEmailInput.value = '';

    // Hide search results
    hideSearchResults();

    // Clear any validation error state
    formGroup.classList.remove('error');

    // Add haptic feedback if available
    if (navigator.vibrate) {
        navigator.vibrate(10);
    }

    updateFormProgress();
}

function removeSelectedOwner() {
    const ownerIdInput = document.getElementById('ownerId');
    const selectedOwnerDiv = document.getElementById('selectedOwner');
    const ownerEmailInput = document.getElementById('ownerEmail');

    // Clear hidden input
    ownerIdInput.value = '';

    // Hide selected owner section
    selectedOwnerDiv.style.display = 'none';

    // Focus back to email input for better UX
    ownerEmailInput.focus();

    // Add haptic feedback if available
    if (navigator.vibrate) {
        navigator.vibrate(10);
    }

    updateFormProgress();
}

function hideSearchResults() {
    const searchResults = document.getElementById('ownerSearchResults');
    searchResults.classList.remove('show');
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// ==========================================
// Owner Selection
// ==========================================

async function initializeOwnerSelection() {
    const ownerSelect = document.getElementById('labOwner');
    const loadingIndicator = document.querySelector('.owner-loading');

    if (!ownerSelect) return;

    try {
        loadingIndicator.classList.add('show');

        const response = await fetch('/admin/api/labs/available-owners', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${getAuthToken()}`
            }
        });

        if (!response.ok) {
            throw new Error('Failed to load available owners');
        }

        const data = await response.json();

        // Clear existing options except the first one
        while (ownerSelect.children.length > 1) {
            ownerSelect.removeChild(ownerSelect.lastChild);
        }

        // Add owner options
        data.owners?.forEach(owner => {
            const option = document.createElement('option');
            option.value = owner._id;
            option.textContent = `${owner.firstName} ${owner.lastName} (${owner.email})`;
            ownerSelect.appendChild(option);
        });

    } catch (error) {
        console.error('Error loading owners:', error);
        // Show error in select
        const option = document.createElement('option');
        option.value = '';
        option.textContent = 'Error loading owners';
        ownerSelect.appendChild(option);
    } finally {
        loadingIndicator.classList.remove('show');
    }
}

function getAuthToken() {
    // Try to get token from cookie first
    const cookies = document.cookie.split(';');
    for (let cookie of cookies) {
        const [name, value] = cookie.trim().split('=');
        if (name === 'token') {
            return value;
        }
    }

    // Fallback to localStorage
    return localStorage.getItem('token');
}

// ==========================================
// Form Progress
// ==========================================

function initializeFormProgress() {
    updateFormProgress();
}

function updateFormProgress() {
    const form = document.getElementById('addLabForm');
    const requiredFields = form.querySelectorAll('[required]');
    const progressDots = document.querySelectorAll('.progress-dot');

    let filledCount = 0;
    requiredFields.forEach(field => {
        if (field.value.trim()) {
            filledCount++;
        }
    });

    // Special handling for owner email field - check if owner is selected
    const ownerEmailField = document.getElementById('ownerEmail');
    const ownerIdField = document.getElementById('ownerId');
    if (ownerEmailField && ownerIdField) {
        const allFields = Array.from(requiredFields);
        const hasOwnerSelected = ownerIdField.value.trim() !== '';

        // Add owner field to progress calculation if owner is selected
        if (hasOwnerSelected) {
            filledCount++;
        }

        // Update total count to include owner field in progress calculation
        const totalRequiredFields = allFields.length + 1; // +1 for owner field
        const progress = filledCount / totalRequiredFields;
        const activeDots = Math.ceil(progress * progressDots.length);

        progressDots.forEach((dot, index) => {
            dot.classList.toggle('active', index < activeDots);
        });
    } else {
        // Regular progress calculation
        const progress = filledCount / requiredFields.length;
        const activeDots = Math.ceil(progress * progressDots.length);

        progressDots.forEach((dot, index) => {
            dot.classList.toggle('active', index < activeDots);
        });
    }
}

// ==========================================
// Form Submission
// ==========================================

function initializeFormSubmission() {
    const form = document.getElementById('addLabForm');

    form.addEventListener('submit', async function(e) {
        e.preventDefault();

        if (!validateForm()) {
            // Scroll to first error
            const firstError = document.querySelector('.form-group.error');
            if (firstError) {
                firstError.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
            return;
        }

        await submitLabForm();
    });
}

async function submitLabForm() {
    const form = document.getElementById('addLabForm');
    const submitButton = form.querySelector('button[type="submit"]');
    const successMessage = document.getElementById('successMessage');

    // Validate owner is selected
    const ownerId = document.getElementById('ownerId').value;
    if (!ownerId) {
        alert('Please select a lab owner');
        return;
    }

    // Prepare form data
    const formData = new FormData();
    const labData = Object.fromEntries(formData.entries());

    // Add all form fields except file inputs
    const allInputs = form.querySelectorAll('input:not([type="file"]), select, textarea');
    allInputs.forEach(input => {
        if (input.name && input.type !== 'file') {
            labData[input.name] = input.value;
        }
    });

    // Add logo file if present
    const logoInput = document.getElementById('labLogo');
    if (logoInput && logoInput.files[0]) {
        labData.logo = logoInput.files[0];
    }

    const selectedDocuments = Object.fromEntries(LAB_DOCUMENT_FIELDS.map(fieldName => [
        fieldName,
        Array.from(document.getElementById(fieldName)?.files || [])
    ]));
    const oversizedDocument = Object.values(selectedDocuments).flat()
        .find(file => file.size > MAX_LAB_DOCUMENT_SIZE);

    if (oversizedDocument) {
        alert(`${oversizedDocument.name} exceeds the 5 MB file limit`);
        return;
    }

    // Handle specializations (model expects 'specialization' singular)
    labData.specialization = getSelectedSpecializations();

    // Handle operating hours (include all days and closed property for model)
    labData.operatingHours = {
        monday: {
            open: labData['monday-open'] || '',
            close: labData['monday-close'] || '',
            closed: !labData['monday-open'] || !labData['monday-close']
        },
        tuesday: {
            open: labData['tuesday-open'] || '',
            close: labData['tuesday-close'] || '',
            closed: !labData['tuesday-open'] || !labData['tuesday-close']
        },
        wednesday: {
            open: labData['wednesday-open'] || '',
            close: labData['wednesday-close'] || '',
            closed: !labData['wednesday-open'] || !labData['wednesday-close']
        },
        thursday: {
            open: labData['thursday-open'] || '',
            close: labData['thursday-close'] || '',
            closed: !labData['thursday-open'] || !labData['thursday-close']
        },
        friday: {
            open: labData['friday-open'] || '',
            close: labData['friday-close'] || '',
            closed: !labData['friday-open'] || !labData['friday-close']
        },
        saturday: {
            open: labData['saturday-open'] || '',
            close: labData['saturday-close'] || '',
            closed: !labData['saturday-open'] || !labData['saturday-close']
        },
        sunday: {
            open: labData['sunday-open'] || '',
            close: labData['sunday-close'] || '',
            closed: !labData['sunday-open'] || !labData['sunday-close']
        }
    };

    // Remove time inputs from main data
    delete labData['saturday-open'];
    delete labData['saturday-close'];
    delete labData['sunday-open'];
    delete labData['sunday-close'];
    delete labData['monday-open'];
    delete labData['monday-close'];
    delete labData['tuesday-open'];
    delete labData['tuesday-close'];
    delete labData['wednesday-open'];
    delete labData['wednesday-close'];
    delete labData['thursday-open'];
    delete labData['thursday-close'];
    delete labData['friday-open'];
    delete labData['friday-close'];
    delete labData['ownerEmail']; // This was just for search

    try {
        // Set loading state
        submitButton.classList.add('loading');
        submitButton.disabled = true;

        // Create FormData for file upload
        const formData = new FormData();

        // Add all lab data fields
        Object.keys(labData).forEach(key => {
            if (key !== 'logo') {
                if (Array.isArray(labData[key])) {
                    // Handle arrays properly - send each item separately
                    labData[key].forEach(item => {
                        formData.append(`${key}[]`, item);
                    });
                } else if (typeof labData[key] === 'object' && key !== 'specialization') {
                    formData.append(key, JSON.stringify(labData[key]));
                } else {
                    formData.append(key, labData[key]);
                }
            }
        });

        // Add logo file if present
        if (labData.logo) {
            formData.append('logo', labData.logo);
        }

        for (const [fieldName, files] of Object.entries(selectedDocuments)) {
            files.forEach(file => formData.append(fieldName, file));
        }

        const response = await fetch('/admin/api/labs', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${getAuthToken()}`
            },
            body: formData
        });

        const result = await response.json();

        if (!response.ok) {
            throw new Error(result.message || 'Failed to create lab');
        }

        // Show success message
        successMessage.classList.add('show');

        // Add haptic feedback if available
        if (navigator.vibrate) {
            navigator.vibrate([100, 50, 100]);
        }

        // Scroll to top
        window.scrollTo({ top: 0, behavior: 'smooth' });

        // Reset form after delay
        setTimeout(() => {
            form.reset();
            document.querySelectorAll('.specialization-item.selected').forEach(item => {
                item.classList.remove('selected');
            });
            updateFormProgress();
        }, 2000);

        // Redirect to labs page after delay
        setTimeout(() => {
            window.location.href = '/admin/labs';
        }, 1500);

    } catch (error) {
        console.error('Error creating lab:', error);

        // Show error message
        alert('Error creating lab: ' + error.message);

        // Add haptic feedback if available
        if (navigator.vibrate) {
            navigator.vibrate(100);
        }
    } finally {
        // Remove loading state
        submitButton.classList.remove('loading');
        submitButton.disabled = false;
    }
}

// ==========================================
// Cancel Form
// ==========================================

function cancelForm() {
    if (confirm('Are you sure you want to cancel? All unsaved changes will be lost.')) {
        window.location.href = '/admin/labs';
    }
}

// ==========================================
// Auto-save Draft (Optional Feature)
// ==========================================

function initializeAutoSave() {
    const form = document.getElementById('addLabForm');
    const inputs = form.querySelectorAll('.form-input, .form-select, .form-textarea');
    let autoSaveTimeout;

    inputs.forEach(input => {
        input.addEventListener('input', function() {
            clearTimeout(autoSaveTimeout);
            autoSaveTimeout = setTimeout(() => {
                saveDraft();
            }, 2000); // Auto-save after 2 seconds of inactivity
        });
    });
}

function saveDraft() {
    const form = document.getElementById('addLabForm');
    const formData = new FormData(form);
    const draftData = Object.fromEntries(formData.entries());

    // Save to localStorage
    localStorage.setItem('labDraft', JSON.stringify(draftData));

    // Show subtle indicator (optional)
    console.log('Draft saved');
}

function loadDraft() {
    const draft = localStorage.getItem('labDraft');
    if (draft) {
        try {
            const draftData = JSON.parse(draft);
            const form = document.getElementById('addLabForm');

            // Populate form fields
            Object.entries(draftData).forEach(([key, value]) => {
                const field = form.querySelector(`[name="${key}"]`);
                if (field) {
                    field.value = value;
                }
            });

            updateFormProgress();
        } catch (error) {
            console.error('Error loading draft:', error);
        }
    }
}

// ==========================================
// Keyboard Shortcuts
// ==========================================

document.addEventListener('keydown', function(e) {
    // Ctrl/Cmd + S to save
    if ((e.ctrlKey || e.metaKey) && e.key === 's') {
        e.preventDefault();
        document.getElementById('addLabForm').dispatchEvent(new Event('submit'));
    }

    // Escape to cancel
    if (e.key === 'Escape') {
        cancelForm();
    }
});

// ==========================================
// Window Management
// ==========================================

window.addEventListener('beforeunload', function(e) {
    const form = document.getElementById('addLabForm');
    const isFormDirty = Array.from(form.elements).some(element => {
        return element.value !== element.defaultValue;
    });

    if (isFormDirty) {
        e.preventDefault();
        e.returnValue = '';
    }
});

// ==========================================
// Error Handling
// ==========================================

window.addEventListener('error', function(e) {
    console.error('Add Lab form error:', e.error);
});

window.addEventListener('unhandledrejection', function(e) {
    console.error('Unhandled promise rejection:', e.reason);
});

// Initialize auto-save if needed
// initializeAutoSave();
// loadDraft();

// ==========================================
// Commission Rate Preview
// ==========================================

function initializeCommissionPreview() {
    const commissionInput = document.getElementById('commissionRate');
    const previewAdminAmount = document.getElementById('previewAdminAmount');
    const previewLabAmount = document.getElementById('previewLabAmount');

    if (!commissionInput || !previewAdminAmount || !previewLabAmount) return;

    function updatePreview() {
        const rate = parseFloat(commissionInput.value) || 0;
        const sampleOrder = 10000; // Sample order amount in IQD

        const adminAmount = Math.round((sampleOrder * rate) / 100);
        const labAmount = sampleOrder - adminAmount;

        previewAdminAmount.textContent = adminAmount.toLocaleString() + ' IQD';
        previewLabAmount.textContent = labAmount.toLocaleString() + ' IQD';
    }

    // Update preview on input
    commissionInput.addEventListener('input', updatePreview);
    commissionInput.addEventListener('change', updatePreview);

    // Initial update
    updatePreview();
};
