// TechnoArt Attendance Geolocation & PWA Interop
window.getBrowserLocation = function () {
    return new Promise((resolve, reject) => {
        if (!navigator.geolocation) {
            resolve({ success: false, errorMessage: "Geolocation is not supported by your browser." });
            return;
        }

        navigator.geolocation.getCurrentPosition(
            (position) => {
                resolve({
                    success: true,
                    latitude: position.coords.latitude,
                    longitude: position.coords.longitude,
                    accuracy: position.coords.accuracy,
                    errorMessage: null
                });
            },
            (error) => {
                let msg = "Unable to retrieve your location.";
                switch (error.code) {
                    case error.PERMISSION_DENIED:
                        msg = "Location permission denied. Please allow location access in your browser settings.";
                        break;
                    case error.POSITION_UNAVAILABLE:
                        msg = "Location information is unavailable.";
                        break;
                    case error.TIMEOUT:
                        msg = "Location request timed out. Please try again.";
                        break;
                }
                resolve({ success: false, errorMessage: msg });
            },
            {
                enableHighAccuracy: true,
                timeout: 10000,
                maximumAge: 0
            }
        );
    });
};

window.calculateHaversineDistance = function (lat1, lon1, lat2, lon2) {
    const R = 6371e3; // Earth's radius in meters
    const phi1 = (lat1 * Math.PI) / 180;
    const phi2 = (lat2 * Math.PI) / 180;
    const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
    const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

    const a =
        Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
        Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c; // Distance in meters
};

// Register PWA Service Worker & Capture Install Prompt
let deferredPwaPrompt = null;
window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPwaPrompt = e;
    window.isPwaInstallable = true;
    console.log('PWA: beforeinstallprompt event captured.');
});

window.installPwaApp = function () {
    if (deferredPwaPrompt) {
        deferredPwaPrompt.prompt();
        deferredPwaPrompt.userChoice.then((choiceResult) => {
            console.log('PWA user choice:', choiceResult.outcome);
            deferredPwaPrompt = null;
        });
        return true;
    }
    return false;
};

if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/service-worker.js')
            .then((reg) => console.log('ServiceWorker registered:', reg.scope))
            .catch((err) => console.warn('ServiceWorker registration failed:', err));
    });
}

// new CSV download helper
window.downloadTextFile = (fileName, text) => {
    const blob = new Blob([text], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url; a.download = fileName;
    document.body.appendChild(a); a.click(); a.remove();
    URL.revokeObjectURL(url);
};
