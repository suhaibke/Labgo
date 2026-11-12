// ==========================================
// LabGo Lab Dashboard JavaScript
// ==========================================

document.addEventListener('DOMContentLoaded', function() {
    initializeDashboard();
});

function initializeDashboard() {
    initializeCounters();
    initializeCharts();
    initializeEventListeners();
    initializeNavigation();
    initializeRealTimeUpdates();
}

// ==========================================
// Counter Animations
// ==========================================
function initializeCounters() {
    const counters = document.querySelectorAll('[data-counter]');

    counters.forEach(counter => {
        const target = parseInt(counter.getAttribute('data-counter'));
        const duration = 2000; // 2 seconds
        const step = target / (duration / 16); // 60fps
        let current = 0;

        const updateCounter = () => {
            current += step;
            if (current < target) {
                counter.textContent = Math.floor(current).toLocaleString();
                requestAnimationFrame(updateCounter);
            } else {
                counter.textContent = target.toLocaleString();
            }
        };

        // Start animation when element is in viewport
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    updateCounter();
                    observer.unobserve(entry.target);
                }
            });
        });

        observer.observe(counter);
    });
}

// ==========================================
// Charts Initialization
// ==========================================
function initializeCharts() {
    // Performance Chart
    const ctx = document.getElementById('performanceChart');
    if (ctx) {
        // Try to get monthly stats from the page data
        let monthlyData = [];
        try {
            const statsElement = document.querySelector('#monthly-stats');
            if (statsElement) {
                monthlyData = JSON.parse(statsElement.textContent);
                console.log('Monthly stats loaded:', monthlyData);
            }
        } catch (e) {
            console.warn('Could not parse monthly stats data:', e.message);
            // Use empty data if parsing fails
            monthlyData = [];
        }

        // Only use fallback data if there's absolutely no data
        if (!monthlyData || monthlyData.length === 0) {
            console.warn('No monthly stats data available, using fallback');
            monthlyData = [];
        }

        new Chart(ctx, {
            type: 'line',
            data: {
                labels: monthlyData.map(d => d.month),
                datasets: [
                    {
                        label: 'Tests',
                        data: monthlyData.map(d => d.tests || 0),
                        borderColor: '#6b21a8',
                        backgroundColor: 'rgba(107, 33, 168, 0.1)',
                        tension: 0.4,
                        fill: true
                    },
                    {
                        label: 'Patients',
                        data: monthlyData.map(d => d.patients || 0),
                        borderColor: '#f59e0b',
                        backgroundColor: 'rgba(245, 158, 11, 0.1)',
                        tension: 0.4,
                        fill: true
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'top',
                        labels: {
                            usePointStyle: true,
                            padding: 20,
                            font: {
                                size: 12,
                                family: "'Inter', sans-serif"
                            }
                        }
                    },
                    tooltip: {
                        backgroundColor: 'rgba(255, 255, 255, 0.9)',
                        titleColor: '#1f2937',
                        bodyColor: '#6b7280',
                        borderColor: '#e5e7eb',
                        borderWidth: 1,
                        padding: 12,
                        displayColors: true,
                        usePointStyle: true
                    }
                },
                scales: {
                    x: {
                        grid: {
                            display: false
                        },
                        ticks: {
                            font: {
                                size: 11,
                                family: "'Inter', sans-serif"
                            },
                            color: '#92400e'
                        }
                    },
                    y: {
                        beginAtZero: true,
                        grid: {
                            color: '#fef3c7'
                        },
                        ticks: {
                            font: {
                                size: 11,
                                family: "'Inter', sans-serif"
                            },
                            color: '#92400e'
                        }
                    }
                }
            }
        });
    }
}

// ==========================================
// Event Listeners
// ==========================================
function initializeEventListeners() {
    // Chart Period Controls
    const chartControls = document.querySelectorAll('.chart-control');
    chartControls.forEach(control => {
        control.addEventListener('click', function() {
            chartControls.forEach(c => c.classList.remove('active'));
            this.classList.add('active');
            updateChartData(this.dataset.period);
        });
    });

  
    // View All Buttons
    const viewAllBtns = document.querySelectorAll('.view-all-btn');
    viewAllBtns.forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.preventDefault();
            window.location.href = this.getAttribute('href') || '/lab/patient-tests';
        });
    });

    // Table Action Buttons
    const tableActionBtns = document.querySelectorAll('.table-action-btn');
    tableActionBtns.forEach(btn => {
        btn.addEventListener('click', function() {
            const icon = this.querySelector('i');
            if (icon.classList.contains('fa-eye')) {
                viewTestDetails(this.closest('tr').dataset.testId);
            } else if (icon.classList.contains('fa-edit')) {
                editTest(this.closest('tr').dataset.testId);
            } else if (icon.classList.contains('fa-download')) {
                downloadTestResult(this.closest('tr').dataset.testId);
            }
        });
    });

    // Quick Action Buttons
    const actionBtns = document.querySelectorAll('.action-btn');
    actionBtns.forEach(btn => {
        btn.addEventListener('click', function(e) {
            if (!this.getAttribute('href')) {
                e.preventDefault();
                const action = this.querySelector('span').textContent.toLowerCase();
                handleQuickAction(action);
            }
        });
    });

    // Urgent Action Buttons
    const urgentActionBtns = document.querySelectorAll('.urgent-action-btn');
    urgentActionBtns.forEach(btn => {
        btn.addEventListener('click', function() {
            const urgentTestItem = this.closest('.urgent-test-item');
            handleUrgentTest(urgentTestItem.dataset.testId);
        });
    });
}

// ==========================================
// Navigation
// ==========================================
function initializeNavigation() {
    // Sidebar navigation (if exists)
    const navItems = document.querySelectorAll('.nav-item');
    navItems.forEach(item => {
        item.addEventListener('click', function() {
            navItems.forEach(i => i.classList.remove('active'));
            this.classList.add('active');

            const section = this.dataset.section;
            if (section) {
                showSection(section);
            }
        });
    });
}

function showSection(sectionId) {
    const sections = document.querySelectorAll('.dashboard-section');
    sections.forEach(section => {
        section.classList.remove('active');
    });

    const targetSection = document.getElementById(sectionId);
    if (targetSection) {
        targetSection.classList.add('active');
    }
}

// ==========================================
// Real-time Updates
// ==========================================
function initializeRealTimeUpdates() {
    // Update stats every 30 seconds
    setInterval(updateDashboardStats, 30000);

    // Check for new urgent tests every 10 seconds
    setInterval(checkUrgentTests, 10000);
}

function checkUrgentTests() {
    // Function to check for urgent tests
    console.log('Checking for urgent tests...');
    // In a real application, this would fetch new urgent tests from the server
}

async function updateDashboardStats() {
    try {
        const response = await fetch('/lab/api/stats');
        if (response.ok) {
            const data = await response.json();
            updateStatCards(data.data);
        }
    } catch (error) {
        console.error('Error updating stats:', error);
    }
}

function updateStatCards(stats) {
    const statCards = {
        totalPatientsServed: stats.totalPatientsServed,
        totalTestsPerformed: stats.totalTestsPerformed,
        pendingPatientTests: stats.pendingPatientTests,
        averageRating: stats.averageRating.toFixed(1)
    };

    Object.entries(statCards).forEach(([key, value]) => {
        const element = document.querySelector(`[data-counter="${value}"]`);
        if (element) {
            animateValue(element, parseInt(element.textContent.replace(/,/g, '')), value, 1000);
        }
    });
}

function animateValue(element, start, end, duration) {
    const startTime = performance.now();

    const updateValue = (currentTime) => {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);

        const currentValue = Math.floor(start + (end - start) * progress);
        element.textContent = currentValue.toLocaleString();

        if (progress < 1) {
            requestAnimationFrame(updateValue);
        }
    };

    requestAnimationFrame(updateValue);
}

// ==========================================
// Data Operations
// ==========================================
function updateChartData(period) {
    // Simulate data update based on period
    console.log('Updating chart data for period:', period);
    // In a real application, this would fetch new data from the server
}

function viewTestDetails(testId) {
    // Open test details modal or navigate to test page
    console.log('Viewing test details for:', testId);
    window.location.href = `/lab/orders/${testId}`;
}

function editTest(testId) {
    // Open edit modal or navigate to edit page
    console.log('Editing test:', testId);
    window.location.href = `/lab/patient-tests/${testId}/edit`;
}

function downloadTestResult(testId) {
    // Download test result
    console.log('Downloading test result for:', testId);
    window.open(`/lab/patient-tests/${testId}/download`, '_blank');
}

function handleQuickAction(action) {
    switch (action) {
        case 'add new test':
            window.location.href = '/lab/tests/new';
            break;
        case 'view tests':
            window.location.href = '/lab/patient-tests';
            break;
        case 'settings':
            window.location.href = '/lab/settings';
            break;
        case 'reports':
            generateReport();
            break;
        default:
            console.log('Unknown action:', action);
    }
}

function handleUrgentTest(testId) {
    console.log('Handling urgent test:', testId);
    viewTestDetails(testId);
}

async function generateReport() {
    try {
        showLoading();

        // Generate report (this would be an API call in a real app)
        await new Promise(resolve => setTimeout(resolve, 2000));

        hideLoading();
        showNotification('Report generated successfully!', 'success');

        // Download the report
        window.open('/lab/api/reports/download', '_blank');
    } catch (error) {
        hideLoading();
        showNotification('Error generating report', 'error');
        console.error('Report generation error:', error);
    }
}

// ==========================================
// Notification System
// ==========================================
function showNotification(message, type = 'info') {
    // Remove existing notifications
    const existingNotifications = document.querySelectorAll('.notification');
    existingNotifications.forEach(n => n.remove());

    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.innerHTML = `
        <div class="notification-content">
            <i class="fas fa-${getNotificationIcon(type)}"></i>
            <span>${message}</span>
            <button class="notification-close" onclick="this.parentElement.parentElement.remove()">
                <i class="fas fa-times"></i>
            </button>
        </div>
    `;

    // Add styles
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: ${getNotificationColor(type)};
        color: white;
        padding: 16px;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        z-index: 1000;
        max-width: 400px;
        animation: slideIn 0.3s ease;
    `;

    document.body.appendChild(notification);

    // Auto remove after 5 seconds
    setTimeout(() => {
        if (notification.parentElement) {
            notification.remove();
        }
    }, 5000);
}

function getNotificationIcon(type) {
    const icons = {
        success: 'check-circle',
        error: 'exclamation-circle',
        warning: 'exclamation-triangle',
        info: 'info-circle'
    };
    return icons[type] || 'info-circle';
}

function getNotificationColor(type) {
    const colors = {
        success: '#10b981',
        error: '#ef4444',
        warning: '#f59e0b',
        info: '#3b82f6'
    };
    return colors[type] || '#3b82f6';
}

// ==========================================
// Loading States
// ==========================================
function showLoading() {
    const loadingOverlay = document.createElement('div');
    loadingOverlay.id = 'loading-overlay';
    loadingOverlay.innerHTML = `
        <div class="loading-spinner">
            <div class="spinner"></div>
            <p>Loading...</p>
        </div>
    `;

    loadingOverlay.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(255, 255, 255, 0.9);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 9999;
        backdrop-filter: blur(2px);
    `;

    const spinner = loadingOverlay.querySelector('.spinner');
    spinner.style.cssText = `
        width: 40px;
        height: 40px;
        border: 4px solid #e5e7eb;
        border-top: 4px solid #22c55e;
        border-radius: 50%;
        animation: spin 1s linear infinite;
    `;

    const loadingText = loadingOverlay.querySelector('p');
    loadingText.style.cssText = `
        margin-top: 16px;
        color: #6b7280;
        font-weight: 500;
    `;

    document.body.appendChild(loadingOverlay);
}

function hideLoading() {
    const loadingOverlay = document.getElementById('loading-overlay');
    if (loadingOverlay) {
        loadingOverlay.remove();
    }
}

// ==========================================
// Utility Functions
// ==========================================
function formatCurrency(amount) {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD'
    }).format(amount);
}

function formatDate(date) {
    return new Intl.DateTimeFormat('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    }).format(new Date(date));
}

function formatDateTime(date) {
    return new Intl.DateTimeFormat('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    }).format(new Date(date));
}

// ==========================================
// Keyboard Shortcuts
// ==========================================
document.addEventListener('keydown', function(e) {
    // Ctrl/Cmd + K for quick search
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        openQuickSearch();
    }

    // Escape to close modals
    if (e.key === 'Escape') {
        closeAllModals();
        hideLoading();
    }
});

function openQuickSearch() {
    // Implementation for quick search modal
    console.log('Opening quick search...');
}

function closeAllModals() {
    // Close all open modals
    const modals = document.querySelectorAll('.modal');
    modals.forEach(modal => modal.remove());
}

// ==========================================
// Error Handling
// ==========================================
window.addEventListener('error', function(e) {
    console.error('Dashboard error:', e.error);
    showNotification('An unexpected error occurred', 'error');
});

window.addEventListener('unhandledrejection', function(e) {
    console.error('Unhandled promise rejection:', e.reason);
    showNotification('An operation failed', 'error');
});

// ==========================================
// Add CSS animations
// ==========================================
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

    @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
    }

    .notification-content {
        display: flex;
        align-items: center;
        gap: 12px;
    }

    .notification-close {
        background: none;
        border: none;
        color: white;
        cursor: pointer;
        padding: 4px;
        border-radius: 4px;
        opacity: 0.8;
        transition: opacity 0.2s;
    }

    .notification-close:hover {
        opacity: 1;
    }

    .loading-spinner {
        display: flex;
        flex-direction: column;
        align-items: center;
    }
`;
document.head.appendChild(style);
