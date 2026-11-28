// ============================================================================
// Automatic Session Inactivity & Idle Timeout Guard (25 Minutes)
// OWASP Session Management Standard
// ============================================================================
(function () {
    // 25 minutes = 1,500,000 milliseconds
    const INACTIVITY_TIMEOUT_MS = 25 * 60 * 1000;
    let idleTimer = null;

    function resetIdleTimer() {
        if (idleTimer) {
            clearTimeout(idleTimer);
        }

        // If the user is already on the login page, do not trigger auto-logout
        const currentPath = window.location.pathname.toLowerCase();
        if (currentPath === '/login' || currentPath.startsWith('/login')) {
            return;
        }

        idleTimer = setTimeout(function () {
            console.warn('[Security] Inactivity timeout reached (25 minutes). Invalidating session...');
            try {
                // Clear all session storage tokens
                window.sessionStorage.clear();
                // Clear any leftover local storage tokens
                window.localStorage.removeItem('userToken');
            } catch (e) {
                console.error('[Security] Storage purge error:', e);
            }

            // Redirect to login with explicit idle timeout parameter
            window.location.href = '/login?reason=idle_timeout';
        }, INACTIVITY_TIMEOUT_MS);
    }

    // Capture standard user interaction events to refresh the idle timer
    const activityEvents = ['mousemove', 'mousedown', 'keydown', 'touchstart', 'scroll', 'click'];
    activityEvents.forEach(function (eventName) {
        window.addEventListener(eventName, resetIdleTimer, { passive: true });
    });

    // Initialize timer on script load
    resetIdleTimer();
})();
