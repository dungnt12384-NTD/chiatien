/* chiatien – © 2026 DUNGSINE (DGS-CT-2026-7Q9X) */
/* Service worker: mở được khi mất mạng. Đổi VERSION mỗi lần phát hành để máy người dùng lấy bản mới. */
const VERSION='v199';
const CACHE = 'chia-tien-' + VERSION;
const SHELL = ['./', 'index.html', 'manifest.webmanifest', 'vendor/supabase.js', 'vendor/qrcode.js',
  'icons/icon-192.png', 'icons/icon-512.png', 'icons/apple-touch-icon.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k.startsWith('chia-tien-') && k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim()));
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  /* Không đụng vào dữ liệu và đăng nhập: luôn đi thẳng ra mạng */
  if (url.origin !== location.origin) return;
  /* Trang chính: ưu tiên bản mới nhất khi có mạng, mất mạng thì dùng bản đã lưu */
  if (req.mode === 'navigate') {
    e.respondWith(
      fetch(req, { cache: 'no-cache' }).catch(() => fetch(req)).then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put('index.html', copy));
        return res;
      }).catch(() => caches.match('index.html').then(r => r || caches.match('./'))
        /* không có mạng và chưa có bản lưu: hiện trang tự thử lại, không để trình duyệt báo lỗi trắng */
        .then(r => r || new Response('<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="refresh" content="2"><body style="font-family:system-ui;padding:32px;color:#444">Đang tải lại…', { headers: { 'Content-Type': 'text/html; charset=utf-8' } }))));
    return;
  }
  /* File tĩnh khác: dùng bản đã lưu, đồng thời cập nhật ngầm */
  e.respondWith(
    caches.match(req).then(hit => {
      const net = fetch(req).then(res => {
        if (res && res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
        return res;
      }).catch(() => hit);
      return hit || net;
    }));
});
