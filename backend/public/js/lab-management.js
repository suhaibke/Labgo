// ==========================================
// LabGo Lab Management - Apple Style Interface
// ==========================================

document.addEventListener('DOMContentLoaded', function() {
    initializeLabManagement();
});

function initializeLabManagement() {
    loadLabs();
    loadStatistics();
    loadAvailableOwners();
    setupEventListeners();
    setupSpecializationCheckboxes();
}

// ==========================================
// Data Loading Functions
// ==========================================

let currentPage = 1;
let currentFilters = {};
let editingLabId = null;

async function loadLabs(page = 1, filters = {}) {
    try {
        currentPage = page;
        currentFilters = { ...filters };

        const queryParams = new URLSearchParams({
            page,
            limit: 10,
            ...filters
        });

        const response = await fetch(`/admin/api/labs?${queryParams}`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            }
        });
        const data = await response.json();

        if (data.success) {
            renderLabsTable(data.data);
            renderPagination(data.page, data.pages);
            updateResultsCount(data.total);
        } else {
            console.error('Failed to load labs:', data.message);
        }
    } catch (error) {
        console.error('Error loading labs:', error);
        renderError();
    }
}

async function loadStatistics() {
    try {
        const response = await fetch('/admin/api/labs/stats/overview', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            }
        });
        const data = await response.json();

        if (data.success) {
            updateStatCards(data.data);
        }
    } catch (error) {
        console.error('Error loading statistics:', error);
    }
}

async function loadAvailableOwners() {
    try {
        const response = await fetch('/admin/api/labs/available-owners', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            }
        });
        const data = await response.json();

        if (data.success) {
            renderOwnerOptions(data.data);
        }
    } catch (error) {
        console.error('Error loading available owners:', error);
    }
}

// ==========================================
// UI Rendering Functions
// ==========================================

function renderLabsTable(labs) {
    const tbody = document.getElementById('labsTableBody');

    if (!labs || labs.length === 0) {
        tbody.innerHTML = `
            <tr>
                <td colspan="8" class="empty-state">
                    <div class="empty-icon">
                        <i class="fas fa-flask"></i>
                    </div>
                    <p>No labs found</p>
                </td>
            </tr>
        `;
        return;
    }

    tbody.innerHTML = labs.map(lab => `
        <tr>
            <td>
                <div class="lab-info-cell">
                    ${lab.logo ? `<img src="${lab.logo}" alt="${lab.name}" class="lab-logo">` :
                      '<div class="lab-logo-placeholder"><i class="fas fa-flask"></i></div>'}
                    <div>
                        <div class="lab-name">${escapeHtml(lab.name)}</div>
                        <div class="lab-specialization">
                            ${lab.specialization?.slice(0, 2).join(', ') || 'General'}
                        </div>
                    </div>
                </div>
            </td>
            <td>
                <div class="contact-info">
                    <div><i class="fas fa-envelope"></i> ${escapeHtml(lab.email)}</div>
                    <div><i class="fas fa-phone"></i> ${escapeHtml(lab.phone)}</div>
                    <div><i class="fas fa-map-marker-alt"></i> ${escapeHtml(lab.city)}, ${escapeHtml(lab.country)}</div>
                </div>
            </td>
            <td>
                <div class="owner-info">
                    <div class="owner-name">${escapeHtml(lab.ownerId?.name || 'N/A')}</div>
                    <div class="owner-email">${escapeHtml(lab.ownerId?.email || '')}</div>
                </div>
            </td>
            <td>
                <span class="status-badge ${lab.status.toLowerCase()}">
                    ${lab.status}
                </span>
            </td>
            <td>
                <div class="test-info">
                    <div class="test-count">${lab.tests?.length || 0}</div>
                    <div class="test-label">Tests</div>
                </div>
            </td>
            <td>
                <div class="patient-info">
                    <div class="patient-count">${lab.totalPatientsServed || 0}</div>
                    <div class="patient-label">Patients</div>
                </div>
            </td>
            <td>
                <div class="date-info">
                    <div>${formatDate(lab.createdAt)}</div>
                    <div class="creator">by ${escapeHtml(lab.createdBy?.name || 'Unknown')}</div>
                </div>
            </td>
            <td>
                <div class="action-buttons">
                    <button class="action-btn featured ${lab.isFeatured ? 'active' : ''}" onclick="toggleFeatured('${lab._id}')" title="${lab.isFeatured ? 'Remove from Featured' : 'Add to Featured'}">
                        <i class="fas fa-star"></i>
                    </button>
                    <button class="action-btn featured ${lab.reportBranding?.hidePlatformFooter ? '' : 'active'}" onclick="toggleReportBranding('${lab._id}', ${!lab.reportBranding?.hidePlatformFooter})" title="${lab.reportBranding?.hidePlatformFooter ? 'LabGo footer hidden on reports — click to show' : 'LabGo footer shown on reports — click to hide'}">
                        <i class="fas fa-copyright"></i>
                    </button>
                    <button class="action-btn view" onclick="viewLabDetails('${lab._id}')" title="View Details">
                        <i class="fas fa-eye"></i>
                    </button>
                    <button class="action-btn tests" onclick="openLabTestsModal('${lab._id}')" title="${escapeHtml(window.labTestLabels?.manageTests || 'Lab Tests')}">
                        <i class="fas fa-vials"></i>
                    </button>
                    <button class="action-btn edit" onclick="editLab('${lab._id}')" title="Edit Lab">
                        <i class="fas fa-edit"></i>
                    </button>
                    <button class="action-btn delete" onclick="deleteLab('${lab._id}', '${escapeHtml(lab.name)}')" title="Delete Lab">
                        <i class="fas fa-trash"></i>
                    </button>
                </div>
            </td>
        </tr>
    `).join('');
}

function renderPagination(currentPage, totalPages) {
    const pagination = document.getElementById('pagination');

    if (totalPages <= 1) {
        pagination.innerHTML = '';
        return;
    }

    let paginationHTML = '<div class="pagination">';

    // Previous button
    paginationHTML += `
        <button class="pagination-btn ${currentPage === 1 ? 'disabled' : ''}"
                onclick="loadLabs(${currentPage - 1}, currentFilters)"
                ${currentPage === 1 ? 'disabled' : ''}>
            <i class="fas fa-chevron-left"></i>
        </button>
    `;

    // Page numbers
    const startPage = Math.max(1, currentPage - 2);
    const endPage = Math.min(totalPages, currentPage + 2);

    for (let i = startPage; i <= endPage; i++) {
        paginationHTML += `
            <button class="pagination-btn ${i === currentPage ? 'active' : ''}"
                    onclick="loadLabs(${i}, currentFilters)">
                ${i}
            </button>
        `;
    }

    // Next button
    paginationHTML += `
        <button class="pagination-btn ${currentPage === totalPages ? 'disabled' : ''}"
                onclick="loadLabs(${currentPage + 1}, currentFilters)"
                ${currentPage === totalPages ? 'disabled' : ''}>
            <i class="fas fa-chevron-right"></i>
        </button>
    `;

    paginationHTML += '</div>';
    pagination.innerHTML = paginationHTML;
}

function updateResultsCount(total) {
    const resultsCount = document.getElementById('resultsCount');
    resultsCount.textContent = `${total}`;
}

function updateStatCards(data) {
    // Animate number counting
    animateNumber('totalLabs', data.totalLabs);
    animateNumber('activeLabs', data.activeLabs);
    animateNumber('totalTests', data.totalTests);
    animateNumber('totalPatients', data.totalPatients || 0);

    // Update change indicators
    document.getElementById('labsGrowth').textContent = '+12%';
    document.getElementById('activeRate').textContent =
        data.totalLabs > 0 ? Math.round((data.activeLabs / data.totalLabs) * 100) + '%' : '0%';
    document.getElementById('testsGrowth').textContent = '+8%';
    document.getElementById('patientsGrowth').textContent = '+15%';
}

function animateNumber(elementId, targetValue) {
    const element = document.getElementById(elementId);
    const duration = 1000;
    const steps = 50;
    const increment = targetValue / steps;
    let current = 0;

    const timer = setInterval(() => {
        current += increment;
        if (current >= targetValue) {
            current = targetValue;
            clearInterval(timer);
        }
        element.textContent = Math.round(current).toLocaleString();
    }, duration / steps);
}

function renderOwnerOptions(users) {
    const select = document.getElementById('labOwner');
    select.innerHTML = '<option value="">Select an owner</option>';

    users.forEach(user => {
        const option = document.createElement('option');
        option.value = user._id;
        option.textContent = `${user.name} (${user.email})`;
        select.appendChild(option);
    });
}

function renderError() {
    const tbody = document.getElementById('labsTableBody');
    tbody.innerHTML = `
        <tr>
            <td colspan="8" class="error-state">
                <div class="error-icon">
                    <i class="fas fa-exclamation-triangle"></i>
                </div>
                <p>Failed to load labs. Please try again.</p>
            </td>
        </tr>
    `;
}

// ==========================================
// Event Listeners
// ==========================================

function setupEventListeners() {
    // Search
    document.getElementById('searchInput').addEventListener('input', debounce(() => {
        const search = document.getElementById('searchInput').value;
        loadLabs(1, { ...currentFilters, search });
    }, 500));

    // Filters
    document.getElementById('statusFilter').addEventListener('change', () => {
        const status = document.getElementById('statusFilter').value;
        loadLabs(1, { ...currentFilters, status });
    });

  
    // Form submission
    document.getElementById('labForm').addEventListener('submit', handleLabSubmit);
    document.getElementById('labTestForm').addEventListener('submit', handleLabTestSubmit);
    document.getElementById('labTestImportFile').addEventListener('change', handleLabTestImport);
}

function setupSpecializationCheckboxes() {
    const container = document.getElementById('specializationCheckboxes');
    const specializations = [
        'Blood Tests', 'X-Ray', 'MRI', 'CT Scan', 'Ultrasound',
        'Pathology', 'Microbiology', 'Biochemistry', 'Genetics',
        'Allergy', 'Cardiology', 'Neurology', 'General'
    ];

    container.innerHTML = specializations.map(spec => `
        <label class="checkbox-item">
            <input type="checkbox" name="specialization" value="${spec}">
            <span>${spec}</span>
        </label>
    `).join('');
}

// ==========================================
// Modal Functions
// ==========================================

function openAddLabModal() {
    editingLabId = null;
    document.getElementById('modalTitle').textContent = 'Add New Lab';
    document.getElementById('labForm').reset();
    document.getElementById('labModal').classList.add('show');
}

async function editLab(labId) {
    // Redirect to edit lab page with lab ID as parameter
    window.location.href = `/admin/labs/edit?id=${labId}`;
}

function closeLabModal() {
    document.getElementById('labModal').classList.remove('show');
    editingLabId = null;
}

function populateLabForm(lab) {
    document.getElementById('labName').value = lab.name || '';
    document.getElementById('labEmail').value = lab.email || '';
    document.getElementById('labPhone').value = lab.phone || '';
    document.getElementById('labWebsite').value = lab.website || '';
    document.getElementById('labAddress').value = lab.address || '';
    document.getElementById('labCity').value = lab.city || '';
    document.getElementById('labCountry').value = lab.country || '';
    document.getElementById('labStatus').value = lab.status || 'Active';
    document.getElementById('labOwner').value = lab.ownerId?._id || '';

    // Set specializations
    const checkboxes = document.querySelectorAll('input[name="specialization"]');
    checkboxes.forEach(checkbox => {
        checkbox.checked = lab.specialization?.includes(checkbox.value) || false;
    });
}

async function handleLabSubmit(e) {
    e.preventDefault();

    const formData = new FormData(e.target);
    const labData = {
        name: formData.get('name'),
        email: formData.get('email'),
        phone: formData.get('phone'),
        website: formData.get('website'),
        address: formData.get('address'),
        city: formData.get('city'),
        country: formData.get('country'),
        status: formData.get('status'),
        ownerId: formData.get('ownerId'),
        specialization: Array.from(document.querySelectorAll('input[name="specialization"]:checked'))
            .map(cb => cb.value)
    };

    try {
        const url = editingLabId ? `/admin/api/labs/${editingLabId}` : '/admin/api/labs';
        const method = editingLabId ? 'PUT' : 'POST';

        const response = await fetch(url, {
            method,
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            },
            body: JSON.stringify(labData)
        });

        const data = await response.json();

        if (data.success) {
            closeLabModal();
            loadLabs(currentPage, currentFilters);
            loadStatistics();
            showNotification(editingLabId ? 'Lab updated successfully' : 'Lab created successfully', 'success');
        } else {
            showNotification(data.message || 'Failed to save lab', 'error');
        }
    } catch (error) {
        console.error('Error saving lab:', error);
        showNotification('Failed to save lab', 'error');
    }
}

async function deleteLab(labId, labName) {
    if (!confirm(`Are you sure you want to delete "${labName}"? This action cannot be undone.`)) {
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
            loadLabs(currentPage, currentFilters);
            loadStatistics();
            showNotification('Lab deleted successfully', 'success');
        } else {
            showNotification(data.message || 'Failed to delete lab', 'error');
        }
    } catch (error) {
        console.error('Error deleting lab:', error);
        showNotification('Failed to delete lab', 'error');
    }
}

async function toggleFeatured(labId) {
    try {
        const response = await fetch(`/admin/api/labs/${labId}/featured`, {
            method: 'PATCH',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`,
                'Content-Type': 'application/json'
            }
        });

        const data = await response.json();

        if (data.success) {
            loadLabs(currentPage, currentFilters);
            showNotification(data.message, 'success');
        } else {
            showNotification(data.message || 'Failed to update featured status', 'error');
        }
    } catch (error) {
        console.error('Error toggling featured status:', error);
        showNotification('Failed to update featured status', 'error');
    }
}

// "Powered by LabGo" footer on the lab's result reports (platform admins only).
async function toggleReportBranding(labId, hide) {
    try {
        const response = await fetch(`/admin/api/labs/${labId}/report-branding`, {
            method: 'PATCH',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ hidePlatformFooter: hide })
        });
        const data = await response.json();
        if (data.success) {
            loadLabs(currentPage, currentFilters);
            showNotification(data.message, 'success');
        } else {
            showNotification(data.message || 'Failed to update report branding', 'error');
        }
    } catch (error) {
        console.error('Error updating report branding:', error);
        showNotification('Failed to update report branding', 'error');
    }
}

async function viewLabDetails(labId) {
    try {
        const response = await fetch(`/admin/api/labs/${labId}`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            }
        });
        const data = await response.json();

        if (data.success) {
            renderLabDetails(data.data, data.recentTests);
            document.getElementById('labDetailsModal').classList.add('show');
        }
    } catch (error) {
        console.error('Error loading lab details:', error);
    }
}

function closeDetailsModal() {
    document.getElementById('labDetailsModal').classList.remove('show');
}

// ==========================================
// Lab Tests Modal
// ==========================================

let labTestsLabId = null;
let labTests = [];

function setLabTestStatus(message = '', isError = false) {
    const status = document.getElementById('labTestStatus');
    status.textContent = message;
    status.hidden = !message;
    status.classList.toggle('error', isError);
}

function renderLabTestsList() {
    const labels = window.labTestLabels;
    const list = document.getElementById('labTestsList');

    if (labTests.length === 0) {
        list.innerHTML = `<p class="lab-tests-empty">${escapeHtml(labels.empty)}</p>`;
        return;
    }

    list.innerHTML = labTests.map(test => `
        <div class="lab-tests-item">
            <div>
                <div class="lab-tests-item-name"><bdi>${escapeHtml(test.nameAr || test.name)}</bdi></div>
                <div class="lab-tests-item-category">${escapeHtml(labels.categories[test.category] || test.category)}</div>
            </div>
            <div class="lab-tests-item-price" dir="ltr">${Math.round(test.price).toLocaleString('en-US')} IQD</div>
        </div>
    `).join('');
}

async function openLabTestsModal(labId) {
    labTestsLabId = labId;
    labTests = [];
    document.getElementById('labTestForm').reset();
    document.getElementById('labTestsLabName').textContent = '';
    document.getElementById('labTestsList').innerHTML = '';
    setLabTestStatus();
    setLabTestImportStatus();
    document.getElementById('labTestsModal').classList.add('show');

    try {
        const response = await fetch(`/admin/api/labs/${labId}`, {
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            }
        });
        const data = await response.json();

        if (labTestsLabId !== labId) return;
        if (!data.success) throw new Error(data.message);

        labTests = data.data.tests || [];
        document.getElementById('labTestsLabName').textContent = data.data.name;
        renderLabTestsList();
    } catch (error) {
        if (labTestsLabId !== labId) return;
        console.error('Error loading lab tests:', error);
        setLabTestStatus(window.labTestLabels.loadError, true);
    }
}

function closeLabTestsModal() {
    labTestsLabId = null;
    document.getElementById('labTestsModal').classList.remove('show');
}

function setLabTestImportStatus(message = '', isError = false, issues = []) {
    const status = document.getElementById('labTestImportStatus');
    const list = document.getElementById('labTestImportIssues');

    status.textContent = message;
    status.hidden = !message;
    status.classList.toggle('error', isError);
    list.innerHTML = issues.map(issue => `<li><bdi>${escapeHtml(issue)}</bdi></li>`).join('');
    list.hidden = issues.length === 0;
}

async function downloadLabTestTemplate() {
    try {
        const response = await fetch('/admin/api/labs/tests/template', {
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            }
        });
        if (!response.ok) throw new Error(`Template request failed: ${response.status}`);

        const url = URL.createObjectURL(await response.blob());
        const link = document.createElement('a');
        link.href = url;
        link.download = 'labgo-tests-template.xlsx';
        link.click();
        window.setTimeout(() => URL.revokeObjectURL(url), 60000);
    } catch (error) {
        console.error('Error downloading lab test template:', error);
        setLabTestImportStatus(window.labTestLabels.import.templateError, true);
    }
}

function describeImportResults({ added, skipped, errors }) {
    const labels = window.labTestLabels.import;
    const rowLabel = row => labels.row.replace('{row}', row);
    const issues = [
        ...errors.map(({ row, code }) => `${rowLabel(row)}: ${labels[code] || code}`),
        ...skipped.map(({ row, name }) => `${rowLabel(row)}: ${name} - ${labels.duplicate}`)
    ];
    const summary = labels.summary
        .replace('{added}', added.length)
        .replace('{skipped}', skipped.length)
        .replace('{errors}', errors.length);

    return { summary, issues };
}

async function handleLabTestImport(e) {
    const input = e.target;
    const file = input.files[0];
    const labId = labTestsLabId;
    if (!file || !labId) return;

    const labels = window.labTestLabels.import;
    const button = document.getElementById('labTestImportButton');
    const body = new FormData();
    body.append('file', file);

    button.disabled = true;
    setLabTestImportStatus(labels.uploading);

    try {
        const response = await fetch(`/admin/api/labs/${labId}/tests/import`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            },
            body
        });
        const data = await response.json();

        if (labTestsLabId !== labId) {
            if (data.success) loadLabs(currentPage, currentFilters);
            return;
        }

        if (!data.success) {
            setLabTestImportStatus(labels[data.code] || labels.failed, true);
            return;
        }

        const { summary, issues } = describeImportResults(data.results);
        labTests.push(...data.results.added);
        renderLabTestsList();
        setLabTestImportStatus(summary, data.results.added.length === 0, issues);

        if (data.results.added.length > 0) {
            loadLabs(currentPage, currentFilters);
            loadStatistics();
        }
    } catch (error) {
        console.error('Error importing lab tests:', error);
        if (labTestsLabId === labId) {
            setLabTestImportStatus(labels.failed, true);
        }
    } finally {
        button.disabled = false;
        input.value = '';
    }
}

async function handleLabTestSubmit(e) {
    e.preventDefault();

    const labId = labTestsLabId;
    const form = e.target;
    const submitButton = document.getElementById('labTestSubmit');

    submitButton.disabled = true;
    setLabTestStatus();

    try {
        const response = await fetch(`/admin/api/labs/${labId}/tests`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            },
            body: JSON.stringify(Object.fromEntries(new FormData(form)))
        });
        const data = await response.json();

        if (!data.success) throw new Error(data.message);

        if (labTestsLabId === labId) {
            labTests.push(data.data);
            renderLabTestsList();
            form.reset();
            setLabTestStatus(window.labTestLabels.added);
            document.getElementById('labTestNameAr').focus();
        }

        loadLabs(currentPage, currentFilters);
        loadStatistics();
    } catch (error) {
        console.error('Error adding lab test:', error);
        if (labTestsLabId === labId) {
            setLabTestStatus(window.labTestLabels.addError, true);
        }
    } finally {
        submitButton.disabled = false;
    }
}

function renderLabDocuments(lab) {
    const labels = window.labDocumentLabels || {};
    const documentGroups = [
        ['labCertificates', labels.labCertificates || 'Laboratory Certificates'],
        ['labOpeningLetter', labels.labOpeningLetter || 'Laboratory Opening Letter'],
        ['labOpeningLicense', labels.labOpeningLicense || 'Laboratory Opening Licence'],
        ['practiceLicense', labels.practiceLicense || 'Professional Practice Licence'],
        ['ownerUnifiedCard', labels.ownerUnifiedCard || 'Owner Unified Card'],
        ['ownerDepartmentOrRetirementId', labels.ownerDepartmentOrRetirementId || 'Owner Department or Retirement ID']
    ];
    const availableGroups = documentGroups
        .map(([category, label]) => ({
            category,
            label,
            documents: Array.isArray(lab.documents?.[category]) ? lab.documents[category] : []
        }))
        .filter(group => group.documents.length > 0);

    return `
        <div class="info-card lab-documents-card">
            <h3 class="card-title">
                <i class="fas fa-folder-open"></i>
                ${escapeHtml(labels.documentsTitle || 'Registration Documents')}
            </h3>
            <div class="card-content">
                ${availableGroups.length === 0 ? `
                    <div class="lab-documents-empty">
                        <i class="fas fa-file-circle-xmark"></i>
                        <span>${escapeHtml(labels.noDocuments || 'No documents uploaded')}</span>
                    </div>
                ` : `
                    <div class="lab-document-groups">
                        ${availableGroups.map(group => `
                            <section class="lab-document-group">
                                <h4>${escapeHtml(group.label)}</h4>
                                <div class="lab-document-list">
                                    ${group.documents.map(document => {
                                        const documentUrl = `/admin/api/labs/${encodeURIComponent(lab._id)}/documents/${group.category}/${encodeURIComponent(document._id)}`;
                                        const isPdf = document.mimeType === 'application/pdf';
                                        return `
                                            <div class="lab-document-item">
                                                <span class="lab-document-icon">
                                                    <i class="fas ${isPdf ? 'fa-file-pdf' : 'fa-file-image'}"></i>
                                                </span>
                                                <span class="lab-document-name" title="${escapeHtml(document.originalName || group.label)}">
                                                    ${escapeHtml(document.originalName || group.label)}
                                                </span>
                                                <button type="button" class="lab-document-open" onclick="openLabDocument('${documentUrl}')">
                                                    <i class="fas fa-arrow-up-right-from-square"></i>
                                                    ${escapeHtml(labels.openDocument || 'Open')}
                                                </button>
                                            </div>
                                        `;
                                    }).join('')}
                                </div>
                            </section>
                        `).join('')}
                    </div>
                `}
            </div>
        </div>
    `;
}

async function openLabDocument(documentUrl) {
    const previewWindow = window.open('', '_blank');
    if (previewWindow) {
        previewWindow.opener = null;
        previewWindow.document.body.textContent = 'Loading document…';
    }

    try {
        const response = await fetch(documentUrl, {
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            }
        });

        if (!response.ok) {
            const errorBody = await response.json().catch(() => ({}));
            throw new Error(errorBody.message || 'Failed to load document');
        }

        const objectUrl = URL.createObjectURL(await response.blob());
        if (previewWindow) {
            previewWindow.location.replace(objectUrl);
        } else {
            window.open(objectUrl, '_blank', 'noopener');
        }
        window.setTimeout(() => URL.revokeObjectURL(objectUrl), 60000);
    } catch (error) {
        previewWindow?.close();
        console.error('Error loading lab document:', error);
        alert(window.labDocumentLabels?.documentLoadError || 'The document could not be loaded.');
    }
}

function renderLabDetails(lab, recentTests) {
    const content = document.getElementById('labDetailsContent');

    content.innerHTML = `
        <div class="lab-details-redesign">
            <!-- Lab Header Section -->
            <div class="lab-header">
                <div class="lab-avatar">
                    ${lab.logo ?
                        `<img src="${lab.logo}" alt="${lab.name}" class="lab-logo">` :
                        `<div class="lab-logo-placeholder">
                            <i class="fas fa-flask"></i>
                        </div>`
                    }
                </div>
                <div class="lab-info">
                    <div class="lab-title-section">
                        <h1 class="lab-name">${escapeHtml(lab.name)}</h1>
                        <span class="status-badge ${lab.status.toLowerCase()}">${lab.status}</span>
                        ${lab.isVerified ? '<span class="verification-badge"><i class="fas fa-check-circle"></i></span>' : ''}
                    </div>
                    <p class="lab-description">${escapeHtml(lab.description || 'Excellence in laboratory services')}</p>
                    <div class="lab-contact">
                        <span class="contact-item">
                            <i class="fas fa-envelope"></i>
                            ${escapeHtml(lab.email)}
                        </span>
                        <span class="contact-item">
                            <i class="fas fa-phone"></i>
                            ${escapeHtml(lab.phone)}
                        </span>
                    </div>
                </div>
            </div>

            <!-- Main Content Grid -->
            <div class="content-grid">
                <!-- Location & Hours Card -->
                <div class="info-card">
                    <h3 class="card-title">
                        <i class="fas fa-map-marker-alt"></i>
                        Location & Contact
                    </h3>
                    <div class="card-content">
                        <div class="location-info">
                            <p class="address">${escapeHtml(lab.address)}, ${escapeHtml(lab.city)}, ${escapeHtml(lab.country)}</p>
                            ${lab.website ? `
                                <a href="${lab.website}" target="_blank" class="website-link">
                                    <i class="fas fa-external-link-alt"></i>
                                    ${escapeHtml(lab.website.replace(/^https?:\/\//, ''))}
                                </a>
                            ` : ''}
                        </div>
                    </div>
                </div>

                <!-- Performance Overview Card -->
                <div class="info-card">
                    <h3 class="card-title">
                        <i class="fas fa-chart-line"></i>
                        Performance Overview
                    </h3>
                    <div class="card-content">
                        <div class="metrics-row">
                            <div class="metric">
                                <div class="metric-value">${lab.totalTestsPerformed || 0}</div>
                                <div class="metric-label">Tests</div>
                            </div>
                            <div class="metric">
                                <div class="metric-value">${lab.totalPatientsServed || 0}</div>
                                <div class="metric-label">Patients</div>
                            </div>
                            <div class="metric">
                                <div class="metric-value">${lab.averageRating.toFixed(1)}</div>
                                <div class="metric-label">Rating</div>
                            </div>
                            <div class="metric">
                                <div class="metric-value">${lab.totalReviews || 0}</div>
                                <div class="metric-label">Reviews</div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Owner & Lab Info Card -->
                <div class="info-card">
                    <h3 class="card-title">
                        <i class="fas fa-user-circle"></i>
                        Lab Management
                    </h3>
                    <div class="card-content">
                        <div class="owner-section">
                            <div class="owner-avatar">
                                <i class="fas fa-user"></i>
                            </div>
                            <div class="owner-info">
                                <div class="owner-name">${escapeHtml(lab.ownerId?.name || 'Not Assigned')}</div>
                                <div class="owner-email">${escapeHtml(lab.ownerId?.email || 'N/A')}</div>
                                <div class="owner-meta">
                                    <span class="role-badge">${escapeHtml(lab.ownerId?.role || 'lab')}</span>
                                    <span class="member-info">Member since ${lab.ownerId?.createdAt ? formatDate(lab.ownerId.createdAt) : 'N/A'}</span>
                                </div>
                            </div>
                        </div>

                        ${lab.ownerId ? `
                            <div class="owner-details-grid">
                                <div class="detail-item">
                                    <div class="detail-label">
                                        <i class="fas fa-phone"></i>
                                        Phone
                                    </div>
                                    <div class="detail-value">${escapeHtml(lab.ownerId.phone || 'N/A')}</div>
                                </div>

                                <div class="detail-item">
                                    <div class="detail-label">
                                        <i class="fas fa-venus-mars"></i>
                                        Gender
                                    </div>
                                    <div class="detail-value">${lab.ownerId.gender ? lab.ownerId.gender.charAt(0).toUpperCase() + lab.ownerId.gender.slice(1) : 'N/A'}</div>
                                </div>

                                ${lab.ownerId.birthDate ? `
                                    <div class="detail-item">
                                        <div class="detail-label">
                                            <i class="fas fa-birthday-cake"></i>
                                            Date of Birth
                                        </div>
                                        <div class="detail-value">${formatDate(lab.ownerId.birthDate)}</div>
                                    </div>
                                ` : ''}

                                <div class="detail-item">
                                    <div class="detail-label">
                                        <i class="fas fa-user-check"></i>
                                        Account Status
                                    </div>
                                    <div class="detail-value">
                                        <span class="account-status ${lab.ownerId.role}">
                                            ${lab.ownerId.role.charAt(0).toUpperCase() + lab.ownerId.role.slice(1)}
                                        </span>
                                    </div>
                                </div>
                            </div>
                        ` : ''}
                    </div>
                </div>

                <!-- Specializations Card -->
                <div class="info-card specializations">
                    <h3 class="card-title">
                        <i class="fas fa-microscope"></i>
                        Specializations
                    </h3>
                    <div class="card-content">
                        <div class="specialization-tags">
                            ${lab.specialization.map(spec =>
                                `<span class="spec-tag">${escapeHtml(spec)}</span>`
                            ).join('')}
                        </div>
                    </div>
                </div>

                ${renderLabDocuments(lab)}
            </div>

            ${recentTests && recentTests.length > 0 ? `
                <div class="recent-tests-section">
                    <div class="section-header">
                        <h3 class="section-title">Recent Tests</h3>
                        <span class="section-count">${recentTests.length} tests</span>
                    </div>
                    <div class="tests-grid">
                        ${recentTests.map(test => `
                            <div class="test-card">
                                <div class="test-header">
                                    <div class="test-name">${escapeHtml(test.testName)}</div>
                                    <span class="test-status ${test.status.toLowerCase()}">${test.status}</span>
                                </div>
                                <div class="test-details">
                                    <div class="test-patient">
                                        <i class="fas fa-user"></i>
                                        ${escapeHtml(test.patientId?.name || 'Unknown')}
                                    </div>
                                    <div class="test-date">
                                        <i class="fas fa-calendar"></i>
                                        ${formatDate(test.requestDate)}
                                    </div>
                                </div>
                            </div>
                        `).join('')}
                    </div>
                </div>
            ` : ''}
        </div>
    `;
}

// ==========================================
// Utility Functions
// ==========================================

function clearFilters() {
    document.getElementById('searchInput').value = '';
    document.getElementById('statusFilter').value = '';
    loadLabs(1, {});
}

async function refreshData() {
    await loadLabs(currentPage, currentFilters);
    await loadStatistics();
}

function formatDate(dateString) {
    const options = { year: 'numeric', month: 'short', day: 'numeric' };
    return new Date(dateString).toLocaleDateString(undefined, options);
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// ==========================================
// Notifications (Simple console version)
// ==========================================

function showNotification(message, type = 'info') {
    console.log(`[${type.toUpperCase()}] ${message}`);
    // In a real implementation, this would show a toast notification
}
