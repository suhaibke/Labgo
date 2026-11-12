// ==========================================
// LabGo Admin Profile Menu - Shared Component
// ==========================================
// This file provides the profile menu dropdown functionality
// for all admin pages. Uses event delegation for reliability.
// ==========================================

(function () {
    'use strict';

    // Track initialization to prevent duplicates
    let isInitialized = false;

    function initializeProfileMenu() {
        // Prevent multiple initializations
        if (isInitialized) return;

        const profileTrigger = document.getElementById('profileTrigger');
        const profileDropdown = document.getElementById('profileDropdown');

        if (!profileTrigger || !profileDropdown) {
            // Elements not found - retry after a short delay (for dynamically loaded content)
            setTimeout(initializeProfileMenu, 100);
            return;
        }

        isInitialized = true;

        // Direct click handler on trigger
        profileTrigger.addEventListener('click', function (e) {
            e.preventDefault();
            e.stopPropagation();
            toggleProfileDropdown();
        });

        // Close dropdown when clicking anywhere on the document
        document.addEventListener('click', function (e) {
            const dropdown = document.getElementById('profileDropdown');
            const trigger = document.getElementById('profileTrigger');

            if (!dropdown || !trigger) return;

            // Check if click is outside both trigger and dropdown
            if (!dropdown.contains(e.target) && !trigger.contains(e.target)) {
                closeProfileDropdown();
            }
        });

        // Close dropdown on Escape key
        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape') {
                closeProfileDropdown();
            }
        });
    }

    function toggleProfileDropdown() {
        const profileDropdown = document.getElementById('profileDropdown');
        if (!profileDropdown) return;

        const isOpen = profileDropdown.classList.contains('show');
        if (isOpen) {
            closeProfileDropdown();
        } else {
            openProfileDropdown();
        }
    }

    function openProfileDropdown() {
        const profileDropdown = document.getElementById('profileDropdown');
        const profileTrigger = document.getElementById('profileTrigger');

        if (!profileDropdown || !profileTrigger) return;

        if (navigator.vibrate) {
            navigator.vibrate(10);
        }

        profileDropdown.classList.add('show');
        profileTrigger.setAttribute('aria-expanded', 'true');
    }

    function closeProfileDropdown() {
        const profileDropdown = document.getElementById('profileDropdown');
        const profileTrigger = document.getElementById('profileTrigger');

        if (!profileDropdown || !profileTrigger) return;

        profileDropdown.classList.remove('show');
        profileTrigger.setAttribute('aria-expanded', 'false');
    }

    // Expose functions globally for inline onclick handlers
    window.toggleProfileDropdown = toggleProfileDropdown;
    window.openProfileDropdown = openProfileDropdown;
    window.closeProfileDropdown = closeProfileDropdown;

    // ==========================================
    // Language Switching
    // ==========================================

    function changeLanguage(language) {
        if (navigator.vibrate) {
            navigator.vibrate(10);
        }

        const validLanguages = ['en', 'ar', 'ku', 'tr'];
        if (!validLanguages.includes(language)) {
            console.error('Invalid language selected');
            closeProfileDropdown();
            return;
        }

        fetch(`/api/language/set`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ language: language })
        })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    setTimeout(() => {
                        window.location.reload();
                    }, 300);
                }
            })
            .catch(error => {
                console.error('Language change error:', error);
                document.cookie = `lang=${language}; max-age=${365 * 24 * 60 * 60}; path=/`;
                setTimeout(() => {
                    const currentUrl = new URL(window.location);
                    currentUrl.searchParams.set('lang', language);
                    window.location.href = currentUrl.toString();
                }, 500);
            })
            .finally(() => {
                closeProfileDropdown();
            });
    }

    // Expose globally
    window.changeLanguage = changeLanguage;

    // ==========================================
    // Logout Functionality
    // ==========================================

    function handleLogout() {
        if (navigator.vibrate) {
            navigator.vibrate(10);
        }

        if (confirm('Are you sure you want to logout?')) {
            fetch('/auth/logout', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' }
            })
                .then(response => response.json())
                .then(data => {
                    window.location.href = '/auth/login';
                })
                .catch(error => {
                    console.error('Logout error:', error);
                    window.location.href = '/auth/login';
                });
        }

        closeProfileDropdown();
    }

    // Expose globally
    window.handleLogout = handleLogout;

    // ==========================================
    // Auto-Initialize
    // ==========================================

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initializeProfileMenu);
    } else {
        // DOM is already ready
        initializeProfileMenu();
    }

})();
