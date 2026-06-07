{{flutter_js}}
{{flutter_build_config}}

(async function loadQuickDraw() {
  const resetFlag = 'quickDrawServiceWorkerReset';

  async function clearFlutterServiceWorker() {
    if (!('serviceWorker' in navigator)) {
      return false;
    }

    const registrations = await navigator.serviceWorker.getRegistrations();
    let removed = false;
    for (const registration of registrations) {
      const worker =
        registration.active || registration.waiting || registration.installing;
      const scriptUrl = worker && worker.scriptURL ? worker.scriptURL : '';
      if (scriptUrl.includes('flutter_service_worker.js')) {
        await registration.unregister();
        removed = true;
      }
    }

    if ('caches' in window) {
      await Promise.all(
        ['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest'].map(
          (name) => caches.delete(name),
        ),
      );
    }

    return removed;
  }

  try {
    const removed = await clearFlutterServiceWorker();
    if (removed && navigator.serviceWorker.controller) {
      if (!sessionStorage.getItem(resetFlag)) {
        sessionStorage.setItem(resetFlag, '1');
        window.location.reload();
        return;
      }
    }
    sessionStorage.removeItem(resetFlag);
  } catch (error) {
    console.warn('Unable to clear Flutter service worker:', error);
  }

  _flutter.loader.load();
})();
