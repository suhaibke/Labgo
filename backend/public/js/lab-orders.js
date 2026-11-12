/**
 * LabGo Lab Orders Dashboard
 * Handles order management, QR scanning, and file uploads
 */

(function () {
    'use strict';

    // Configuration
    const CONFIG = {
        autoRefreshInterval: 30000, // 30 seconds
        maxFileSize: 5 * 1024 * 1024, // 5MB
        allowedTypes: ['application/pdf', 'image/jpeg', 'image/png', 'image/gif', 'image/heic', 'image/heif', 'image/webp']
    };

    // State
    let state = {
        autoRefresh: true,
        autoRefreshTimer: null,
        currentUploadOrderId: null,
        uploadedFileUrl: null
    };

    // DOM Elements
    const elements = {
        autoRefreshToggle: null,
        lastUpdateTime: null,
        incomingOrdersList: null,
        inLabOrdersList: null,
        qrInput: null,
        qrScanForm: null,
        uploadModal: null,
        closeModalBtn: null,
        cancelUploadBtn: null,
        confirmUploadBtn: null,
        fileUploadArea: null,
        resultFileInput: null,
        filePreview: null,
        fileName: null,
        fileSize: null,
        removeFileBtn: null,
        uploadProgress: null,
        progressFill: null,
        progressText: null,
        toastContainer: null
    };

    // Initialize
    function init() {
        // Cache DOM elements
        elements.autoRefreshToggle = document.getElementById('autoRefreshToggle');
        elements.lastUpdateTime = document.getElementById('lastUpdateTime');
        elements.incomingOrdersList = document.getElementById('incomingOrdersList');
        elements.inLabOrdersList = document.getElementById('inLabOrdersList');
        elements.qrInput = document.getElementById('qrInput');
        elements.qrScanForm = document.getElementById('qrScanForm');
        elements.uploadModal = document.getElementById('uploadModal');
        elements.closeModalBtn = document.getElementById('closeModal');
        elements.cancelUploadBtn = document.getElementById('cancelUpload');
        elements.confirmUploadBtn = document.getElementById('confirmUpload');
        elements.fileUploadArea = document.getElementById('fileUploadArea');
        elements.resultFileInput = document.getElementById('resultFile');
        elements.filePreview = document.getElementById('filePreview');
        elements.fileName = document.getElementById('fileName');
        elements.fileSize = document.getElementById('fileSize');
        elements.removeFileBtn = document.getElementById('removeFile');
        elements.uploadProgress = document.getElementById('uploadProgress');
        elements.progressFill = document.getElementById('progressFill');
        elements.progressText = document.getElementById('progressText');
        elements.toastContainer = document.getElementById('toastContainer');

        // Bind events
        bindEvents();

        // Initial data load
        loadOrders();

        // Start auto-refresh
        startAutoRefresh();

        // Update last updated time
        updateLastUpdateTime();
    }

    // Bind event listeners
    function bindEvents() {
        // Auto-refresh toggle
        if (elements.autoRefreshToggle) {
            elements.autoRefreshToggle.addEventListener('click', toggleAutoRefresh);
        }

        // QR form submit
        if (elements.qrScanForm) {
            elements.qrScanForm.addEventListener('submit', handleQRScan);
        }

        // Modal close
        if (elements.closeModalBtn) {
            elements.closeModalBtn.addEventListener('click', closeUploadModal);
        }

        if (elements.cancelUploadBtn) {
            elements.cancelUploadBtn.addEventListener('click', closeUploadModal);
        }

        if (elements.uploadModal) {
            const overlay = elements.uploadModal.querySelector('.modal-overlay');
            if (overlay) {
                overlay.addEventListener('click', closeUploadModal);
            }
        }

        // File upload handlers - label handles click automatically
        if (elements.fileUploadArea) {
            // Drag and drop
            elements.fileUploadArea.addEventListener('dragover', handleDragOver);
            elements.fileUploadArea.addEventListener('dragleave', handleDragLeave);
            elements.fileUploadArea.addEventListener('drop', handleFileDrop);
        }

        if (elements.resultFileInput) {
            elements.resultFileInput.addEventListener('change', handleFileSelect);
        }

        // Remove file
        if (elements.removeFileBtn) {
            elements.removeFileBtn.addEventListener('click', handleRemoveFile);
        }

        // Confirm upload
        if (elements.confirmUploadBtn) {
            elements.confirmUploadBtn.addEventListener('click', handleConfirmUpload);
        }
    }

    // Toggle auto-refresh
    function toggleAutoRefresh() {
        state.autoRefresh = !state.autoRefresh;

        if (elements.autoRefreshToggle) {
            elements.autoRefreshToggle.classList.toggle('active', state.autoRefresh);
        }

        if (state.autoRefresh) {
            startAutoRefresh();
        } else {
            stopAutoRefresh();
        }
    }

    // Start auto-refresh
    function startAutoRefresh() {
        stopAutoRefresh();
        state.autoRefreshTimer = setInterval(() => {
            loadOrders(true);
        }, CONFIG.autoRefreshInterval);
    }

    // Stop auto-refresh
    function stopAutoRefresh() {
        if (state.autoRefreshTimer) {
            clearInterval(state.autoRefreshTimer);
            state.autoRefreshTimer = null;
        }
    }

    // Update last updated time
    function updateLastUpdateTime() {
        if (elements.lastUpdateTime) {
            const now = new Date();
            elements.lastUpdateTime.textContent = formatTime(now);
        }
    }

    // Format time
    function formatTime(date) {
        return date.toLocaleTimeString(window.labOrdersData?.currentLang || 'en', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        });
    }

    // Load orders
    async function loadOrders(silent = false) {
        try {
            // Show loading state
            if (!silent) {
                showLoadingState();
            }

            // Fetch both order types
            const [incomingResponse, inLabResponse] = await Promise.all([
                fetch(`${window.labOrdersData.apiBaseUrl}/orders?status=sample_collected&limit=50`),
                fetch(`${window.labOrdersData.apiBaseUrl}/orders?status=at_lab&limit=50`)
            ]);

            if (!incomingResponse.ok || !inLabResponse.ok) {
                throw new Error('Failed to fetch orders');
            }

            const incomingData = await incomingResponse.json();
            const inLabData = await inLabResponse.json();

            // Render orders
            renderIncomingOrders(incomingData.data?.orders || []);
            renderInLabOrders(inLabData.data?.orders || []);

            // Update stats
            updateStats(incomingData.data?.orders?.length || 0, inLabData.data?.orders?.length || 0);

            // Update time
            updateLastUpdateTime();

        } catch (error) {
            console.error('Load orders error:', error);
            if (!silent) {
                showToast(window.labOrdersData?.texts?.errorLoading || 'Error loading orders', 'error');
            }
        }
    }

    // Show loading state
    function showLoadingState() {
        const loadingHTML = `
            <div class="la-spinner"></div>
        `;

        if (elements.incomingOrdersList) {
            elements.incomingOrdersList.innerHTML = loadingHTML;
        }

        if (elements.inLabOrdersList) {
            elements.inLabOrdersList.innerHTML = loadingHTML;
        }
    }

    // Render incoming orders
    function renderIncomingOrders(orders) {
        if (!elements.incomingOrdersList) return;

        if (orders.length === 0) {
            elements.incomingOrdersList.innerHTML = `
                <div class="la-empty-box">
                    <svg class="ic"><use href="#i-package"/></svg>
                    <p>${window.labOrdersData?.texts?.noIncomingSamples || 'No incoming samples'}</p>
                </div>
            `;
            return;
        }

        const ordersHTML = orders.map(order => createOrderCard(order, 'incoming')).join('');
        elements.incomingOrdersList.innerHTML = ordersHTML;
    }

    // Render in-lab orders
    function renderInLabOrders(orders) {
        if (!elements.inLabOrdersList) return;

        if (orders.length === 0) {
            elements.inLabOrdersList.innerHTML = `
                <div class="la-empty-box">
                    <svg class="ic"><use href="#i-flask-conical"/></svg>
                    <p>${window.labOrdersData?.texts?.noOrdersInLab || 'No orders in lab'}</p>
                </div>
            `;
            return;
        }

        const ordersHTML = orders.map(order => createOrderCard(order, 'inLab')).join('');
        elements.inLabOrdersList.innerHTML = ordersHTML;
    }

    // Create order card HTML
    function createOrderCard(order, type) {
        const patient = order.patientInfo || {};
        const patientName = patient.name || 'Unknown';
        const gender = patient.gender === 'male'
            ? (window.labOrdersData?.texts?.male || 'Male')
            : patient.gender === 'female'
                ? (window.labOrdersData?.texts?.female || 'Female')
                : (window.labOrdersData?.texts?.notAvailable || 'N/A');
        const age = Number.isInteger(patient.age)
            ? `${patient.age} ${window.labOrdersData?.texts?.years || 'years'}`
            : (window.labOrdersData?.texts?.notAvailable || 'N/A');
        const qrCode = order.qrCode || '';
        const tests = order.tests || [];
        const urgency = order.urgency || 'routine';
        const createdAt = new Date(order.createdAt);

        const initials = String(patientName).split(' ').filter(Boolean).map(w => w[0]).slice(0, 2).join('').toUpperCase();
        const urgent = urgency === 'urgent' || urgency === 'stat';
        const testTags = tests.map(test => `
            <span class="la-tag"><svg class="ic"><use href="#i-test-tube"/></svg>${test.testName}</span>
        `).join('');

        // stopPropagation keeps the button from also opening the order
        const footerHTML = type === 'incoming'
            ? `<button class="la-btn md press-95" onclick="event.stopPropagation(); window.labOrders.receiveSample('${qrCode}', '${order._id}')">
                    <svg class="ic"><use href="#i-check"/></svg>${window.labOrdersData?.texts?.receiveSample || 'Receive'}
               </button>`
            : `<button class="la-btn md press-95" onclick="event.stopPropagation(); window.labOrders.openUploadModal('${order._id}')">
                    <svg class="ic"><use href="#i-upload"/></svg>${window.labOrdersData?.texts?.uploadResult || 'Upload Result'}
               </button>`;

        return `
            <div class="la-tile la-order pop-in" data-order-id="${order._id}" data-qr-code="${qrCode}" onclick="window.labOrders.viewOrderDetails('${order._id}')">
                <div class="la-order-top">
                    <span class="la-avatar">${initials || '?'}</span>
                    <span class="main">
                        <span class="name">${patientName}</span>
                        <span class="meta">${gender} · ${age}${qrCode ? ' · ' + qrCode : ''}</span>
                    </span>
                    <span class="la-pill ${urgent ? 'red' : 'neutral'}">${urgency}</span>
                </div>
                <div class="la-tags">${testTags}</div>
                <div class="la-order-foot">
                    <div class="la-meta-row">
                        <span><svg class="ic"><use href="#i-clock"/></svg>${formatOrderDate(createdAt)}</span>
                        <span><svg class="ic"><use href="#i-clipboard-list"/></svg>${tests.length} ${window.labOrdersData?.texts?.tests || 'tests'}</span>
                    </div>
                    ${footerHTML}
                </div>
            </div>
        `;
    }

    // Format order date
    function formatOrderDate(date) {
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);

        if (diffMins < 1) return 'Just now';
        if (diffMins < 60) return `${diffMins}m ago`;
        if (diffHours < 24) return `${diffHours}h ago`;
        if (diffDays < 7) return `${diffDays}d ago`;

        return date.toLocaleDateString();
    }

    // Update stats
    function updateStats(incoming, inLab) {
        const incomingCount = document.getElementById('incomingCount');
        const inLabCount = document.getElementById('inLabCount');
        const incomingColumnCount = document.getElementById('incomingColumnCount');
        const inLabColumnCount = document.getElementById('inLabColumnCount');

        if (incomingCount) incomingCount.textContent = incoming;
        if (inLabCount) inLabCount.textContent = inLab;
        if (incomingColumnCount) incomingColumnCount.textContent = incoming;
        if (inLabColumnCount) inLabColumnCount.textContent = inLab;
    }

    // Handle QR scan
    async function handleQRScan(event) {
        event.preventDefault();

        const qrCode = elements.qrInput?.value?.trim();
        if (!qrCode) return;

        try {
            const response = await fetch(`${window.labOrdersData.apiBaseUrl}/orders/scan-qr`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ qrCode })
            });

            const data = await response.json();

            if (data.success) {
                showToast(window.labOrdersData?.texts?.sampleReceived || 'Sample received successfully', 'success');
                if (elements.qrInput) elements.qrInput.value = '';
                loadOrders();
            } else {
                showToast(data.message || (window.labOrdersData?.texts?.invalidQR || 'Invalid QR code'), 'error');
            }
        } catch (error) {
            console.error('QR scan error:', error);
            showToast(window.labOrdersData?.texts?.orderNotFound || 'Order not found', 'error');
        }
    }

    // Open upload modal
    function openUploadModal(orderId) {
        state.currentUploadOrderId = orderId;
        state.uploadedFileUrl = null;

        resetUploadForm();

        if (elements.uploadModal) {
            elements.uploadModal.classList.add('active');
        }

        if (elements.resultFileInput) {
            elements.resultFileInput.value = '';
        }
    }

    // Close upload modal
    function closeUploadModal() {
        if (elements.uploadModal) {
            elements.uploadModal.classList.remove('active');
        }

        state.currentUploadOrderId = null;
        state.uploadedFileUrl = null;
    }

    // Reset upload form
    function resetUploadForm() {
        if (elements.fileUploadArea) {
            elements.fileUploadArea.style.display = 'block';
        }

        if (elements.filePreview) {
            elements.filePreview.style.display = 'none';
        }

        if (elements.uploadProgress) {
            elements.uploadProgress.style.display = 'none';
        }

        if (elements.confirmUploadBtn) {
            elements.confirmUploadBtn.disabled = true;
        }

        if (elements.progressFill) {
            elements.progressFill.style.width = '0%';
        }

        if (elements.resultFileInput) {
            elements.resultFileInput.value = '';
        }
    }

    // Handle drag over
    function handleDragOver(event) {
        event.preventDefault();
        event.stopPropagation();
        elements.fileUploadArea?.classList.add('dragover');
    }

    // Handle drag leave
    function handleDragLeave(event) {
        event.preventDefault();
        event.stopPropagation();
        elements.fileUploadArea?.classList.remove('dragover');
    }

    // Handle file drop
    function handleFileDrop(event) {
        event.preventDefault();
        event.stopPropagation();
        elements.fileUploadArea?.classList.remove('dragover');

        const files = event.dataTransfer?.files;
        if (files && files.length > 0) {
            validateAndShowFile(files[0]);
        }
    }

    // Handle file select
    function handleFileSelect(event) {
        const files = event.target?.files;
        if (files && files.length > 0) {
            validateAndShowFile(files[0]);
        }
    }

    // Validate and show file
    function validateAndShowFile(file) {
        // Check file size
        if (file.size > CONFIG.maxFileSize) {
            showToast('File too large. Maximum size is 5MB', 'error');
            return;
        }

        // Check file type
        if (!CONFIG.allowedTypes.includes(file.type)) {
            showToast('Invalid file type. Please upload PDF or image', 'error');
            return;
        }

        // Show file preview
        showFilePreview(file);
    }

    // Show file preview
    function showFilePreview(file) {
        if (elements.fileUploadArea) {
            elements.fileUploadArea.style.display = 'none';
        }

        if (elements.filePreview) {
            elements.filePreview.style.display = 'flex';
        }

        if (elements.fileName) {
            elements.fileName.textContent = file.name;
        }

        if (elements.fileSize) {
            elements.fileSize.textContent = formatFileSize(file.size);
        }

        if (elements.confirmUploadBtn) {
            elements.confirmUploadBtn.disabled = false;
        }
    }

    // Format file size
    function formatFileSize(bytes) {
        if (bytes < 1024) return bytes + ' B';
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
        return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    }

    // Handle remove file
    function handleRemoveFile() {
        resetUploadForm();

        if (elements.resultFileInput) {
            elements.resultFileInput.value = '';
        }
    }

    // Handle confirm upload
    async function handleConfirmUpload() {
        if (!state.currentUploadOrderId) return;

        const file = elements.resultFileInput?.files?.[0];
        if (!file) return;

        try {
            // Show progress
            if (elements.uploadProgress) {
                elements.uploadProgress.style.display = 'block';
            }

            if (elements.confirmUploadBtn) {
                elements.confirmUploadBtn.disabled = true;
            }

            // Create form data
            const formData = new FormData();
            formData.append('resultFile', file);

            // Upload with progress
            const xhr = new XMLHttpRequest();

            xhr.upload.addEventListener('progress', (event) => {
                if (event.lengthComputable) {
                    const percentComplete = (event.loaded / event.total) * 100;

                    if (elements.progressFill) {
                        elements.progressFill.style.width = percentComplete + '%';
                    }

                    if (elements.progressText) {
                        elements.progressText.textContent = 'Uploading... ' + Math.round(percentComplete) + '%';
                    }
                }
            });

            xhr.addEventListener('load', function () {
                if (xhr.status === 200) {
                    const response = JSON.parse(xhr.responseText);

                    if (response.success) {
                        state.uploadedFileUrl = response.data?.fileUrl;

                        showToast(window.labOrdersData?.texts?.uploadSuccess || 'File uploaded successfully', 'success');

                        // Automatically complete the order after successful upload
                        completeOrder(state.currentUploadOrderId);

                        // Close modal after a short delay
                        setTimeout(() => {
                            closeUploadModal();
                        }, 1000);
                    } else {
                        showToast(response.message || (window.labOrdersData?.texts?.uploadError || 'Upload failed'), 'error');
                        if (elements.confirmUploadBtn) {
                            elements.confirmUploadBtn.disabled = false;
                        }
                    }
                } else {
                    showToast(window.labOrdersData?.texts?.uploadError || 'Upload failed', 'error');
                    if (elements.confirmUploadBtn) {
                        elements.confirmUploadBtn.disabled = false;
                    }
                }
            });

            xhr.addEventListener('error', function () {
                showToast(window.labOrdersData?.texts?.uploadError || 'Upload failed', 'error');
                if (elements.confirmUploadBtn) {
                    elements.confirmUploadBtn.disabled = false;
                }
            });

            xhr.open('POST', `${window.labOrdersData.uploadUrl}/${state.currentUploadOrderId}/upload-result`);
            xhr.send(formData);

        } catch (error) {
            console.error('Upload error:', error);
            showToast(window.labOrdersData?.texts?.uploadError || 'Upload failed', 'error');
            if (elements.confirmUploadBtn) {
                elements.confirmUploadBtn.disabled = false;
            }
        }
    }

    // Receive sample
    async function receiveSample(qrCode, orderId) {
        try {
            const response = await fetch(`${window.labOrdersData.apiBaseUrl}/orders/scan-qr`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ qrCode })
            });

            const data = await response.json();

            if (data.success) {
                showToast(window.labOrdersData?.texts?.sampleReceived || 'Sample received successfully', 'success');
                loadOrders();
            } else {
                showToast(data.message || (window.labOrdersData?.texts?.invalidQR || 'Invalid QR code'), 'error');
            }
        } catch (error) {
            console.error('Receive sample error:', error);
            showToast(window.labOrdersData?.texts?.orderNotFound || 'Order not found', 'error');
        }
    }

    // Complete order
    async function completeOrder(orderId) {
        if (!state.uploadedFileUrl) {
            showToast('Please upload a test result first', 'warning');
            return;
        }

        try {
            const response = await fetch(`${window.labOrdersData.apiBaseUrl}/orders/${orderId}/complete`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ reportUrl: state.uploadedFileUrl })
            });

            const data = await response.json();

            if (data.success) {
                showToast(window.labOrdersData?.texts?.orderCompleted || 'Order completed successfully', 'success');
                state.uploadedFileUrl = null;
                loadOrders();
            } else {
                showToast(data.message || 'Failed to complete order', 'error');
            }
        } catch (error) {
            console.error('Complete order error:', error);
            showToast('Failed to complete order', 'error');
        }
    }

    // Show toast notification
    function showToast(message, type = 'info') {
        if (!elements.toastContainer) return;

        const toast = document.createElement('div');
        toast.className = `la-toast ${type}`;
        toast.innerHTML = `<span class="dot"></span><span class="toast-message"></span>`;
        toast.querySelector('.toast-message').textContent = message;
        elements.toastContainer.appendChild(toast);

        // Auto remove after 5 seconds
        setTimeout(() => {
            toast.classList.add('removing');
            setTimeout(() => {
                toast.remove();
            }, 300);
        }, 5000);

        // Tap to dismiss
        toast.addEventListener('click', () => {
            toast.classList.add('removing');
            setTimeout(() => toast.remove(), 300);
        });
    }

    // View order details - navigate to detail page
    function viewOrderDetails(orderId) {
        window.location.href = `/lab/orders/${orderId}`;
    }

    // Expose functions globally
    window.labOrders = {
        receiveSample,
        openUploadModal,
        completeOrder,
        viewOrderDetails
    };

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();
