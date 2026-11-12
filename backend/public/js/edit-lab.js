// ==========================================
// LabGo Edit Lab Form - Apple Style Interactions
// ==========================================

let selectedOwnerId = null;
let currentLabData = null;
let currentLogoUrl = null;

document.addEventListener('DOMContentLoaded', function() {
    initializeEditLabForm();
    loadLabData();
});

function initializeEditLabForm() {
    initializeFormValidation();
    initializeSpecializationInteractions();
    initializeLogoUpload();
    initializeOwnerEmailSearch();
    initializeFormProgress();
    initializeFormSubmission();
    initializeDeleteFunction();
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

function setLabLocationMarker(lat, lng, silent) {
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
    // Skip re-geocoding when we're just placing the marker from previously-saved
    // lab data (populateForm) - the saved address/city should not be overwritten.
    if (!silent) reverseGeocodeLab(lat, lng);
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
// Load Lab Data
// ==========================================

async function loadLabData() {
    try {
        // Get lab ID from URL
        const urlParams = new URLSearchParams(window.location.search);
        const labId = urlParams.get('id');

        if (!labId) {
            showNotification('Lab ID not found', 'error');
            setTimeout(() => {
                window.location.href = '/admin/labs';
            }, 2000);
            return;
        }

        // Set lab ID in hidden field
        document.getElementById('labId').value = labId;

        // Fetch lab data
        const response = await fetch(`/admin/api/labs/${labId}`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            }
        });

        const data = await response.json();

        if (data.success) {
            currentLabData = data.data;
            populateForm(data.data);
        } else {
            showNotification('Failed to load lab data', 'error');
            setTimeout(() => {
                window.location.href = '/admin/labs';
            }, 2000);
        }
    } catch (error) {
        console.error('Error loading lab data:', error);
        showNotification('Error loading lab data', 'error');
        setTimeout(() => {
            window.location.href = '/admin/labs';
        }, 2000);
    }
}

function populateForm(lab) {
    // Basic Information
    document.getElementById('labName').value = lab.name || '';
    document.getElementById('labEmail').value = lab.email || '';
    document.getElementById('labPhone').value = lab.phone || '';
    document.getElementById('website').value = lab.website || '';
    
    // Commission Rate
    const commissionInput = document.getElementById('commissionRate');
    if (commissionInput) {
        commissionInput.value = lab.commissionRate || 0;
        updateCommissionPreview(lab.commissionRate || 0);
    }

    // Address Information
    document.getElementById('labCity').value = lab.city || '';
    document.getElementById('labZone').value = lab.zone || '';

    const summary = document.getElementById('labLocationSummary');
    if (summary && lab.city) {
        summary.textContent = lab.city;
    }

    // Map location
    if (lab.coordinates && lab.coordinates.latitude != null && lab.coordinates.longitude != null && labLocationMap) {
        labLocationMap.setView([lab.coordinates.latitude, lab.coordinates.longitude], 14);
        setLabLocationMarker(lab.coordinates.latitude, lab.coordinates.longitude, true);
    }

    // Logo
    if (lab.logo) {
        currentLogoUrl = lab.logo;
        updateLogoPreview(lab.logo);
    }

    // Status
    const statusRadio = document.querySelector(`input[name="status"][value="${lab.status || 'Active'}"]`);
    if (statusRadio) {
        statusRadio.checked = true;
        statusRadio.parentElement.classList.add('selected');
    }

    // Specializations
    if (lab.specialization && Array.isArray(lab.specialization)) {
        lab.specialization.forEach(spec => {
            const checkbox = document.querySelector(`input[name="specializations"][value="${spec}"]`);
            if (checkbox) {
                checkbox.checked = true;
                checkbox.parentElement.classList.add('selected');
            }
        });
    }

    // Owner
    if (lab.ownerId) {
        selectedOwnerId = lab.ownerId._id || lab.ownerId;
        const ownerName = lab.ownerId.name || 'Unknown Owner';
        const ownerEmail = lab.ownerId.email || '';
        showSelectedOwner(ownerName, ownerEmail);
        document.getElementById('ownerId').value = selectedOwnerId;
    }

    // Update form progress
    updateFormProgress();
}

// ==========================================
// Form Validation
// ==========================================

function initializeFormValidation() {
    const form = document.getElementById('editLabForm');
    const inputs = form.querySelectorAll('.form-input, .form-select');

    inputs.forEach(input => {
        input.addEventListener('blur', function() {
            validateField(this);
        });

        input.addEventListener('input', function() {
            if (this.parentElement.classList.contains('error')) {
                this.parentElement.classList.remove('error');
            }
            updateFormProgress();
        });

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

    // Remove previous error state
    formGroup.classList.remove('error');

    let isValid = true;
    let message = '';

    // Required field validation
    if (field.hasAttribute('required') && !field.value.trim()) {
        isValid = false;
        message = getRequiredErrorMessage(field);
    }

    // Email validation
    if (field.type === 'email' && field.value) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(field.value)) {
            isValid = false;
            message = 'Please enter a valid email address';
        }
    }

    // Phone validation
    if (field.type === 'tel' && field.value) {
        const phoneRegex = /^[\d\s\-\+\(\)]+$/;
        if (!phoneRegex.test(field.value)) {
            isValid = false;
            message = 'Please enter a valid phone number';
        }
    }

    // URL validation
    if (field.type === 'url' && field.value) {
        try {
            new URL(field.value);
        } catch (e) {
            isValid = false;
            message = 'Please enter a valid URL (e.g., https://example.com)';
        }
    }

    if (!isValid) {
        formGroup.classList.add('error');
        if (errorMessage) {
            errorMessage.textContent = message;
        }
    }

    return isValid;
}

function getRequiredErrorMessage(field) {
    const fieldName = field.name.charAt(0).toUpperCase() + field.name.slice(1);
    return `${fieldName} is required`;
}

// ==========================================
// Specializations Interactions
// ==========================================

function initializeSpecializationInteractions() {
    const specializationItems = document.querySelectorAll('.specialization-item');

    specializationItems.forEach(item => {
        item.addEventListener('click', function(e) {
            if (e.target.type !== 'checkbox') {
                const checkbox = this.querySelector('input[type="checkbox"]');
                checkbox.checked = !checkbox.checked;
            }

            if (this.querySelector('input[type="checkbox"]').checked) {
                this.classList.add('selected');
            } else {
                this.classList.remove('selected');
            }

            updateFormProgress();
        });
    });
}

// ==========================================
// Logo Upload
// ==========================================

function initializeLogoUpload() {
    const logoPreview = document.getElementById('logoPreview');
    const logoInput = document.getElementById('labLogo');

    logoPreview.addEventListener('click', function() {
        logoInput.click();
    });

    logoInput.addEventListener('change', function(e) {
        const file = e.target.files[0];
        if (file) {
            if (file.type.startsWith('image/')) {
                const reader = new FileReader();
                reader.onload = function(e) {
                    updateLogoPreview(e.target.result);
                    currentLogoUrl = e.target.result;
                };
                reader.readAsDataURL(file);
            } else {
                showNotification('Please select an image file', 'error');
            }
        }
    });
}

function updateLogoPreview(imageSrc) {
    const logoPreview = document.getElementById('logoPreview');

    if (imageSrc) {
        logoPreview.innerHTML = `
            <img src="${imageSrc}" alt="Lab Logo" />
        `;
        logoPreview.classList.add('has-image');
    } else {
        logoPreview.innerHTML = `
            <i class="fas fa-flask"></i>
            <span>Upload Lab Logo</span>
        `;
        logoPreview.classList.remove('has-image');
    }
}

// ==========================================
// Owner Email Search
// ==========================================

function initializeOwnerEmailSearch() {
    const ownerEmailInput = document.getElementById('ownerEmail');
    const searchResults = document.getElementById('ownerSearchResults');
    const ownerLoading = document.querySelector('.owner-loading');
    let searchTimeout;

    ownerEmailInput.addEventListener('input', function() {
        const query = this.value.trim();

        clearTimeout(searchTimeout);

        if (query.length >= 3) {
            ownerLoading.classList.add('show');

            searchTimeout = setTimeout(() => {
                searchOwners(query);
            }, 500);
        } else {
            searchResults.classList.remove('show');
            ownerLoading.classList.remove('show');
        }
    });

    // Close search results when clicking outside
    document.addEventListener('click', function(e) {
        if (!e.target.closest('.owner-email-container')) {
            searchResults.classList.remove('show');
        }
    });

    // Remove owner button
    document.getElementById('removeOwner').addEventListener('click', function() {
        removeSelectedOwner();
    });
}

async function searchOwners(query) {
    try {
        const response = await fetch(`/admin/api/labs/search-owner?query=${encodeURIComponent(query)}`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            }
        });

        const data = await response.json();
        const searchResults = document.getElementById('ownerSearchResults');
        const ownerLoading = document.querySelector('.owner-loading');

        ownerLoading.classList.remove('show');

        if (data.success && data.data.length > 0) {
            const resultsHtml = data.data.map(owner => `
                <div class="owner-search-item" data-owner-id="${owner._id}" data-owner-name="${owner.name}" data-owner-email="${owner.email}">
                    <div class="owner-search-name">${escapeHtml(owner.name)}</div>
                    <div class="owner-search-email">${escapeHtml(owner.email)}</div>
                </div>
            `).join('');

            searchResults.innerHTML = resultsHtml;
            searchResults.classList.add('show');

            // Add click handlers to search results
            searchResults.querySelectorAll('.owner-search-item').forEach(item => {
                item.addEventListener('click', function() {
                    const ownerId = this.dataset.ownerId;
                    const ownerName = this.dataset.ownerName;
                    const ownerEmail = this.dataset.ownerEmail;

                    selectOwner(ownerId, ownerName, ownerEmail);
                });
            });
        } else {
            searchResults.innerHTML = `
                <div class="owner-search-item">
                    <div class="owner-search-name">No owners found</div>
                    <div class="owner-search-email">Try a different search term</div>
                </div>
            `;
            searchResults.classList.add('show');
        }
    } catch (error) {
        console.error('Error searching owners:', error);
        const ownerLoading = document.querySelector('.owner-loading');
        ownerLoading.classList.remove('show');
    }
}

function selectOwner(ownerId, ownerName, ownerEmail) {
    selectedOwnerId = ownerId;
    showSelectedOwner(ownerName, ownerEmail);
    document.getElementById('ownerId').value = ownerId;
    document.getElementById('ownerEmail').value = ownerEmail;
    document.getElementById('ownerSearchResults').classList.remove('show');
    updateFormProgress();
}

function showSelectedOwner(name, email) {
    const selectedOwner = document.getElementById('selectedOwner');
    const selectedOwnerName = document.getElementById('selectedOwnerName');
    const selectedOwnerEmail = document.getElementById('selectedOwnerEmail');

    selectedOwnerName.textContent = name;
    selectedOwnerEmail.textContent = email;
    selectedOwner.style.display = 'block';
}

function removeSelectedOwner() {
    selectedOwnerId = null;
    document.getElementById('ownerId').value = '';
    document.getElementById('ownerEmail').value = '';
    document.getElementById('selectedOwner').style.display = 'none';
    updateFormProgress();
}

// ==========================================
// Form Progress
// ==========================================

function initializeFormProgress() {
    updateFormProgress();
}

function updateFormProgress() {
    const form = document.getElementById('editLabForm');
    const requiredFields = form.querySelectorAll('[required]');
    const filledFields = Array.from(requiredFields).filter(field => {
        if (field.type === 'radio') {
            return form.querySelector(`input[name="${field.name}"]:checked`);
        }
        return field.value.trim() !== '';
    });

    const progress = filledFields.length / requiredFields.length;
    const dots = document.querySelectorAll('.progress-dot');

    dots.forEach((dot, index) => {
        if (index < Math.ceil(progress * dots.length)) {
            dot.classList.add('active');
        } else {
            dot.classList.remove('active');
        }
    });
}

// ==========================================
// Form Submission
// ==========================================

function initializeFormSubmission() {
    const form = document.getElementById('editLabForm');

    form.addEventListener('submit', handleFormSubmit);
}

async function handleFormSubmit(e) {
    e.preventDefault();

    const form = e.target;
    const submitBtn = form.querySelector('button[type="submit"]');

    // Validate all fields
    const inputs = form.querySelectorAll('.form-input, .form-select');
    let isValid = true;

    inputs.forEach(input => {
        if (!validateField(input)) {
            isValid = false;
        }
    });

    // Validate status
    const statusChecked = form.querySelector('input[name="status"]:checked');
    if (!statusChecked) {
        isValid = false;
        const statusGroup = form.querySelector('.status-options').closest('.form-group');
        statusGroup.classList.add('error');
    }

    // Validate owner
    if (!selectedOwnerId) {
        isValid = false;
        const ownerGroup = document.getElementById('ownerEmail').closest('.form-group');
        ownerGroup.classList.add('error');
    }

    if (!isValid) {
        showNotification('Please fill in all required fields', 'error');
        return;
    }

    // Create FormData
    const formData = new FormData(form);

    // Add specializations
    const specializations = Array.from(form.querySelectorAll('input[name="specializations"]:checked'))
        .map(cb => cb.value);
    formData.set('specialization', JSON.stringify(specializations));

    // Add owner ID
    formData.set('ownerId', selectedOwnerId);

    try {
        // Show loading state
        submitBtn.classList.add('loading');
        submitBtn.disabled = true;

        const labId = formData.get('labId');
        const response = await fetch(`/admin/api/labs/${labId}`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            },
            body: formData
        });

        const data = await response.json();

        if (data.success) {
            showNotification('Lab updated successfully', 'success');
            document.getElementById('successMessage').classList.add('show');

            // Redirect after delay
            setTimeout(() => {
                window.location.href = '/admin/labs';
            }, 2000);
        } else {
            showNotification(data.message || 'Failed to update lab', 'error');
        }
    } catch (error) {
        console.error('Error updating lab:', error);
        showNotification('Error updating lab', 'error');
    } finally {
        // Hide loading state
        submitBtn.classList.remove('loading');
        submitBtn.disabled = false;
    }
}

// ==========================================
// Delete Function
// ==========================================

function initializeDeleteFunction() {
    const deleteBtn = document.getElementById('deleteBtn');
    deleteBtn.addEventListener('click', handleDeleteLab);
}

async function handleDeleteLab() {
    const labId = document.getElementById('labId').value;
    const labName = document.getElementById('labName').value;

    if (!labId) {
        showNotification('Lab ID not found', 'error');
        return;
    }

    // Confirmation dialog
    const isConfirmed = confirm(`Are you sure you want to delete "${labName}"? This action cannot be undone.`);

    if (!isConfirmed) {
        return;
    }

    try {
        const response = await fetch(`/admin/api/labs/${labId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            }
        });

        const data = await response.json();

        if (data.success) {
            showNotification('Lab deleted successfully', 'success');
            setTimeout(() => {
                window.location.href = '/admin/labs';
            }, 1500);
        } else {
            showNotification(data.message || 'Failed to delete lab', 'error');
        }
    } catch (error) {
        console.error('Error deleting lab:', error);
        showNotification('Error deleting lab', 'error');
    }
}

// ==========================================
// Status Radio Buttons
// ==========================================

document.addEventListener('DOMContentLoaded', function() {
    const statusOptions = document.querySelectorAll('.status-option');

    statusOptions.forEach(option => {
        option.addEventListener('click', function() {
            // Remove selected class from all options
            statusOptions.forEach(opt => opt.classList.remove('selected'));

            // Add selected class to clicked option
            this.classList.add('selected');

            // Check the radio button
            const radio = this.querySelector('input[type="radio"]');
            radio.checked = true;

            updateFormProgress();
        });
    });
});

// ==========================================
// Utility Functions
// ==========================================

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.innerHTML = `
        <i class="fas fa-${type === 'success' ? 'check-circle' : type === 'error' ? 'exclamation-circle' : 'info-circle'}"></i>
        <span>${message}</span>
    `;

    // Add styles
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: ${type === 'success' ? '#d4edda' : type === 'error' ? '#f8d7da' : '#d1ecf1'};
        color: ${type === 'success' ? '#155724' : type === 'error' ? '#721c24' : '#0c5460'};
        padding: 16px 24px;
        border-radius: 12px;
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
        display: flex;
        align-items: center;
        gap: 12px;
        z-index: 10000;
        animation: slideIn 0.3s ease;
        max-width: 400px;
    `;

    document.body.appendChild(notification);

    // Auto remove after 5 seconds
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            document.body.removeChild(notification);
        }, 300);
    }, 5000);
}

function cancelForm() {
    if (confirm('Are you sure you want to discard your changes?')) {
        window.location.href = '/admin/labs';
    }
}

// Add animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from {
            transform: translateX(100%);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }

    @keyframes slideOut {
        from {
            transform: translateX(0);
            opacity: 1;
        }
        to {
            transform: translateX(100%);
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);

// ==========================================
// Commission Preview
// ==========================================

function initializeCommissionPreview() {
    const commissionInput = document.getElementById('commissionRate');
    
    if (commissionInput) {
        commissionInput.addEventListener('input', function() {
            const rate = parseFloat(this.value) || 0;
            updateCommissionPreview(rate);
        });
        
        // Initialize with current value
        updateCommissionPreview(parseFloat(commissionInput.value) || 0);
    }
}

function updateCommissionPreview(rate) {
    const exampleOrder = 10000; // 10,000 IQD
    const commission = Math.round((exampleOrder * rate) / 100);
    const labAmount = exampleOrder - commission;
    
    const commissionAmountEl = document.getElementById('commissionAmount');
    const labAmountEl = document.getElementById('labAmount');
    
    if (commissionAmountEl) {
        commissionAmountEl.textContent = formatCurrency(commission);
    }
    
    if (labAmountEl) {
        labAmountEl.textContent = formatCurrency(labAmount);
    }
}

function formatCurrency(amount) {
    return amount.toLocaleString() + ' IQD';
}