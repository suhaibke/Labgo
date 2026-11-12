// ==========================================
// LabGo Admin Dashboard - Modern Professional
// ==========================================

// Helper function to get auth token
function getAuthToken() {
    return localStorage.getItem('token') || sessionStorage.getItem('token');
}

document.addEventListener('DOMContentLoaded', function() {
    initializeDashboard();
});

function initializeDashboard() {
    initializeCharts();
    initializeStatCardClicks();
    initializeOverviewMap();

    // Load real data
    loadDashboardStatistics();
    loadRecentActivity();
    startAutoRefresh(30000); // 30 seconds
}

// ==========================================
// Live Overview Map (labs + nurses + active orders)
// ==========================================

let overviewMap = null;
let overviewOrderMarker = null;

async function initializeOverviewMap() {
    const mapEl = document.getElementById('overviewMap');
    if (!mapEl || typeof L === 'undefined') return;

    overviewMap = L.map('overviewMap').setView([33.3152, 44.3661], 6);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors',
        maxZoom: 19
    }).addTo(overviewMap);

    try {
        const response = await fetch('/api/admin/orders/map/overview', {
            headers: { 'Authorization': `Bearer ${getAuthToken()}` }
        });
        const data = await response.json();
        if (!response.ok || !data.success) return;

        (data.data.labs || []).forEach((lab) => {
            if (lab.latitude != null && lab.longitude != null) {
                addOverviewMarker(lab.latitude, lab.longitude, lab.name, '#3B82F6');
            }
        });

        (data.data.nurses || []).forEach((nurse) => {
            if (nurse.latitude != null && nurse.longitude != null) {
                addOverviewMarker(nurse.latitude, nurse.longitude, nurse.name, '#10B981');
            }
        });

        renderOverviewOrdersList(data.data.orders || []);
    } catch (error) {
        console.error('Error loading map overview:', error);
    }
}

function addOverviewMarker(lat, lng, label, color) {
    const icon = L.divIcon({
        className: '',
        html: `<div style="background:${color};width:14px;height:14px;border-radius:50%;border:2px solid white;box-shadow:0 0 4px rgba(0,0,0,0.4);"></div>`,
        iconSize: [14, 14],
    });
    L.marker([lat, lng], { icon }).addTo(overviewMap).bindPopup(label || '');
}

function renderOverviewOrdersList(orders) {
    const container = document.getElementById('overviewOrdersList');
    if (!container) return;

    if (orders.length === 0) {
        container.innerHTML = '<div style="color:#888; font-size:13px;">No active orders</div>';
        return;
    }

    container.innerHTML = orders.map((order) => `
        <div style="padding:10px; border:1px solid #eee; border-radius:8px; margin-bottom:8px; cursor:pointer;"
             onclick="showOrderOnMap('${order.id}', ${order.latitude}, ${order.longitude}, '${(order.patientName || '').replace(/'/g, "\\'")}')">
            <div style="font-weight:600; font-size:13px;">${order.patientName || ''}</div>
            <div style="font-size:11px; color:#888;">${order.status}${order.nurseName ? ' · ' + order.nurseName : ''}${order.labName ? ' · ' + order.labName : ''}</div>
        </div>
    `).join('');
}

function showOrderOnMap(orderId, lat, lng, patientName) {
    if (lat == null || lng == null || isNaN(lat) || isNaN(lng)) return;

    if (overviewOrderMarker) {
        overviewMap.removeLayer(overviewOrderMarker);
    }

    const icon = L.divIcon({
        className: '',
        html: `<div style="background:#8378F4;width:16px;height:16px;border-radius:50%;border:2px solid white;box-shadow:0 0 4px rgba(0,0,0,0.4);"></div>`,
        iconSize: [16, 16],
    });
    overviewOrderMarker = L.marker([lat, lng], { icon }).addTo(overviewMap).bindPopup(patientName || '').openPopup();
    overviewMap.setView([lat, lng], 14);
}

// ==========================================
// Stat Card Click Navigation
// ==========================================

function initializeStatCardClicks() {
    const statCards = document.querySelectorAll('.stat-card');
    statCards.forEach(card => {
        card.addEventListener('click', function() {
            // Add click animation
            this.style.transform = 'scale(0.98)';
            setTimeout(() => {
                this.style.transform = '';
            }, 150);
        });
    });
}

// ==========================================
// Charts Initialization
// ==========================================

function initializeCharts() {
    initializeActivityChart();
}

async function initializeActivityChart() {
    const canvas = document.getElementById('activityChart');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');

    try {
        // Fetch real chart data from API
        const response = await fetch('/api/admin/dashboard/charts/activity?period=day', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${getAuthToken()}`
            }
        });
        const result = await response.json();

        let chartData;

        if (result.success) {
            chartData = result.data;
        } else {
            // Fallback data
            chartData = {
                labels: ['6 AM', '9 AM', '12 PM', '3 PM', '6 PM', '9 PM'],
                datasets: [{
                    label: 'Patients',
                    data: [12, 45, 89, 56, 78, 34],
                    borderColor: '#4F46E5',
                    backgroundColor: 'rgba(79, 70, 229, 0.1)',
                    borderWidth: 2,
                    tension: 0.4,
                    fill: true
                }, {
                    label: 'Tests',
                    data: [8, 32, 67, 43, 61, 28],
                    borderColor: '#F59E0B',
                    backgroundColor: 'rgba(245, 158, 11, 0.1)',
                    borderWidth: 2,
                    tension: 0.4,
                    fill: true
                }]
            };
        }

        const config = {
            type: 'line',
            data: chartData,
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: true,
                        position: 'top',
                        labels: {
                            usePointStyle: true,
                            padding: 20,
                            font: { size: 12, family: 'Inter, sans-serif' }
                        }
                    },
                    tooltip: {
                        backgroundColor: 'rgba(255, 255, 255, 0.95)',
                        titleColor: '#111827',
                        bodyColor: '#6B7280',
                        borderColor: '#E5E7EB',
                        borderWidth: 1,
                        padding: 12,
                        displayColors: true,
                        intersect: false,
                        mode: 'index'
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        grid: { display: true, color: '#F3F4F6' },
                        ticks: { font: { size: 11 }, color: '#6B7280' }
                    },
                    x: {
                        grid: { display: false },
                        ticks: { font: { size: 11 }, color: '#6B7280' }
                    }
                }
            }
        };

        window.activityChartInstance = new Chart(ctx, config);
    } catch (error) {
        console.error('Failed to load chart:', error);
    }
}

// ==========================================
// Dashboard Data Loading
// ==========================================

let autoRefreshInterval;

async function loadDashboardStatistics() {
    try {
        showLoadingState();

        const response = await fetch('/api/admin/dashboard/statistics', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${getAuthToken()}`
            }
        });
        const result = await response.json();

        if (result.success) {
            updateOverviewStats(result.data.overview);
            updateOrderStats(result.data.orders);
            updateNurseStats(result.data.nurses);
            updateLabStats(result.data.labs);
            updateFinanceStats(result.data.finance);
            updatePendingApprovals(result.data.pendingApprovals);
            updateStatusBreakdown(result.data.orders);
        }
    } catch (error) {
        console.error('Failed to load dashboard statistics:', error);
        showErrorState();
    } finally {
        hideLoadingState();
    }
}

function updateOverviewStats(stats) {
    updateStatValue('totalPatients', stats.totalPatients);
    updateStatValue('todayAppointments', stats.todayAppointments);

    // Update trend if available
    if (stats.patientsChange !== undefined) {
        updateStatTrend('patientsTrend', stats.patientsChange);
    }
}

function updateOrderStats(stats) {
    // Order stats are handled by updateStatusBreakdown
}

function updateNurseStats(stats) {
    updateStatValue('totalNurses', stats.total);
    updateStatValue('activeNurses', stats.active);
    updateStatValue('blockedNurses', stats.blocked);
    updateStatValue('pendingNurses', stats.pendingApplications);
}

function updateLabStats(stats) {
    updateStatValue('totalLabs', stats.total);
    updateStatValue('activeLabs', stats.active);
    updateStatValue('pendingLabs', stats.pending);
    updateStatValue('suspendedLabs', stats.suspended);
}

function updateFinanceStats(stats) {
    updateStatValue('totalRevenue', formatCurrency(stats.totalRevenue));
    updateStatValue('pendingSettlements', formatCurrency(stats.pendingSettlements));
    updateStatValue('nurseBalances', formatCurrency(stats.nurseBalances));
}

function updatePendingApprovals(approvals) {
    updateStatValue('pendingLabs', approvals.labs);
    updateStatValue('pendingNurses', approvals.nurses);
    updateStatValue('pendingOrders', approvals.orders);
    updateStatValue('lowRatings', approvals.lowRatings);
}

function updateStatusBreakdown(orderStats) {
    updateStatValue('pendingStatus', orderStats.pending);
    updateStatValue('confirmedStatus', orderStats.confirmed);
    updateStatValue('inProgressStatus', orderStats.inProgress);
    updateStatValue('completedStatus', orderStats.completed);
    updateStatValue('cancelledStatus', orderStats.cancelled);
    updateStatValue('urgentStatus', orderStats.urgent);
}

function updateStatValue(statName, value) {
    const element = document.querySelector(`[data-stat="${statName}"]`);
    if (element) {
        animateNumber(element, value);
    }
}

function updateStatTrend(statName, change) {
    const element = document.querySelector(`[data-trend="${statName}"]`);
    if (!element) return;

    const sign = change >= 0 ? '+' : '';
    const className = change >= 0 ? 'positive' : 'negative';

    element.innerHTML = `<i class="fas fa-arrow-${change >= 0 ? 'up' : 'down'}"></i> ${sign}${change}%`;
    element.className = `stat-trend ${className}`;
}

function animateNumber(element, targetValue) {
    const duration = 1000;
    const startValue = parseInt(element.textContent) || 0;
    const difference = targetValue - startValue;
    const startTime = performance.now();

    function update(currentTime) {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);
        const ease = 1 - Math.pow(1 - progress, 4);

        const currentValue = Math.round(startValue + (difference * ease));

        if (typeof targetValue === 'string') {
            element.textContent = targetValue;
        } else {
            element.textContent = formatNumber(currentValue);
        }

        if (progress < 1) {
            requestAnimationFrame(update);
        } else {
            element.textContent = typeof targetValue === 'string' ? targetValue : formatNumber(targetValue);
            element.classList.add('animate');
            setTimeout(() => element.classList.remove('animate'), 300);
        }
    }

    requestAnimationFrame(update);
}

async function loadRecentActivity() {
    try {
        const response = await fetch('/api/admin/dashboard/recent-activity?limit=5', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${getAuthToken()}`
            }
        });
        const result = await response.json();

        if (result.success) {
            renderRecentOrders(result.data.activities);
        }
    } catch (error) {
        console.error('Failed to load recent activity:', error);
    }
}

function renderRecentOrders(orders) {
    const tbody = document.querySelector('.orders-table tbody');

    if (!tbody) return;

    if (!orders || orders.length === 0) {
        tbody.innerHTML = `
            <tr>
                <td colspan="5">
                    <div class="empty-state">
                        <i class="fas fa-inbox empty-state-icon"></i>
                        <p class="empty-state-text">No recent orders</p>
                    </div>
                </td>
            </tr>
        `;
        return;
    }

    tbody.innerHTML = orders.map(order => {
        const statusClass = order.status.replace(/_/g, ' ');
        const urgencyIcon = order.urgency === 'urgent'
            ? '<i class="fas fa-exclamation-circle" style="color: #EF4444;"></i>'
            : '';

        return `
            <tr>
                <td>${order.patientName || 'Unknown'}</td>
                <td>${order.testName || 'No tests'}</td>
                <td>
                    <span class="order-status ${statusClass}">${formatStatus(order.status)}</span>
                    ${urgencyIcon}
                </td>
                <td>${formatDate(order.date)}</td>
                <td>
                    <button class="table-action-btn" onclick="viewOrder('${order.id}')" style="width: 32px; height: 32px; border: none; background: #F3F4F6; border-radius: 6px; cursor: pointer;">
                        <i class="fas fa-eye" style="color: #6B7280;"></i>
                    </button>
                </td>
            </tr>
        `;
    }).join('');
}

function showLoadingState() {
    // Show loading spinners
    document.querySelectorAll('[data-stat]').forEach(el => {
        if (!el.textContent || el.textContent === '--' || el.textContent === '0') {
            el.textContent = '...';
        }
    });
}

function hideLoadingState() {
    // Loading state is hidden when data is loaded
}

function showErrorState() {
    document.querySelectorAll('[data-stat]').forEach(el => {
        if (el.textContent === '...' || el.textContent === 'Loading...') {
            el.textContent = '--';
        }
    });
}

function formatNumber(num) {
    if (typeof num !== 'number') return num;
    if (num >= 1000000) {
        return (num / 1000000).toFixed(1) + 'M';
    }
    if (num >= 1000) {
        return (num / 1000).toFixed(1) + 'K';
    }
    return num.toString();
}

function formatCurrency(amount) {
    if (typeof amount !== 'number') return '--';
    if (amount >= 1000000) {
        return '$' + (amount / 1000000).toFixed(1) + 'M';
    }
    if (amount >= 1000) {
        return '$' + (amount / 1000).toFixed(1) + 'K';
    }
    return '$' + amount.toFixed(0);
}

function formatStatus(status) {
    const statusMap = {
        'pending': 'Pending',
        'confirmed': 'Confirmed',
        'nurse_assigned': 'In Progress',
        'sample_collected': 'Collected',
        'at_lab': 'At Lab',
        'completed': 'Completed',
        'cancelled': 'Cancelled'
    };
    return statusMap[status] || status;
}

function formatDate(date) {
    return new Intl.DateTimeFormat('en-US', {
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    }).format(new Date(date));
}

function startAutoRefresh(interval = 30000) {
    stopAutoRefresh();

    autoRefreshInterval = setInterval(() => {
        loadDashboardStatistics();
        loadRecentActivity();
    }, interval);
}

function stopAutoRefresh() {
    if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
        autoRefreshInterval = null;
    }
}

// View order function
function viewOrder(orderId) {
    window.location.href = `/admin/orders/${orderId}/details`;
}


// ==========================================
// Error Handling
// ==========================================

window.addEventListener('error', function(e) {
    console.error('Dashboard error:', e.error);
});

window.addEventListener('unhandledrejection', function(e) {
    console.error('Unhandled promise rejection:', e.reason);
});

// ==========================================
// Keyboard Shortcuts
// ==========================================

document.addEventListener('keydown', function(e) {
    // Ctrl/Cmd + K for quick search
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        console.log('Quick search coming soon!');
    }

    // Escape to close dropdown
    if (e.key === 'Escape') {
        closeProfileDropdown();
    }
});
