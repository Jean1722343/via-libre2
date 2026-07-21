// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  modules: ['@nuxt/ui', '@vite-pwa/nuxt'],
  // El CSS de MapLibre va global (si solo se importa en el componente, el build
  // estático puede no aplicarlo y el mapa queda invisible).
  css: ['maplibre-gl/dist/maplibre-gl.css', '~/assets/css/main.css'],

  // PWA: instalable + caché offline (mapa y último estado de la API).
  pwa: {
    registerType: 'autoUpdate',
    manifest: {
      name: 'Vía Libre Oaxaca',
      short_name: 'ViaLibre',
      description: 'Bloqueos carreteros del Istmo de Tehuantepec en tiempo real.',
      lang: 'es',
      theme_color: '#bf5b34',
      background_color: '#f6efe1',
      display: 'standalone',
      start_url: '/',
      icons: [
        { src: '/icon-192.png', sizes: '192x192', type: 'image/png' },
        { src: '/icon-512.png', sizes: '512x512', type: 'image/png' },
        { src: '/maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
      ],
    },
    workbox: {
      navigateFallback: '/',
      globPatterns: ['**/*.{js,css,html,svg,png,woff2}'],
      runtimeCaching: [
        {
          urlPattern: ({ url }) => /tile\.openstreetmap\.org/.test(url.href),
          handler: 'CacheFirst',
          options: {
            cacheName: 'osm-tiles',
            expiration: { maxEntries: 400, maxAgeSeconds: 60 * 60 * 24 * 14 },
            cacheableResponse: { statuses: [0, 200] },
          },
        },
        {
          urlPattern: ({ url }) => url.pathname.includes('/api/'),
          handler: 'NetworkFirst',
          options: {
            cacheName: 'api-reportes',
            networkTimeoutSeconds: 4,
            expiration: { maxEntries: 60, maxAgeSeconds: 60 * 60 },
            cacheableResponse: { statuses: [0, 200] },
          },
        },
        {
          urlPattern: ({ url }) => /fonts\.(googleapis|gstatic)\.com/.test(url.href),
          handler: 'CacheFirst',
          options: { cacheName: 'google-fonts', expiration: { maxEntries: 20, maxAgeSeconds: 60 * 60 * 24 * 365 } },
        },
      ],
    },
    client: { installPrompt: true },
    devOptions: { enabled: false },
  },
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },

  // SPA estático: se genera a archivos y se sube a S3/CloudFront (sin servidor).
  ssr: false,

  // Valores que llegan del backend (se llenan con NUXT_PUBLIC_* del .env).
  runtimeConfig: {
    public: {
      apiUrl: '',
      awsRegion: '',
      mapName: '',
      identityPoolId: '',
      googleClientId: '',
      facebookAppId: '',
    },
  },

  app: {
    pageTransition: { name: 'page', mode: 'out-in' },
    head: {
      title: 'Vía Libre — Bloqueos del Istmo en tiempo real',
      htmlAttrs: { lang: 'es' },
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        { name: 'description', content: 'Alertas comunitarias de bloqueos carreteros en tiempo real en el Istmo de Tehuantepec.' },
        { name: 'theme-color', content: '#bf5b34' },
        { name: 'apple-mobile-web-app-capable', content: 'yes' },
        { name: 'apple-mobile-web-app-title', content: 'ViaLibre' },
      ],
      link: [
        { rel: 'icon', type: 'image/png', href: '/favicon.png' },
        { rel: 'apple-touch-icon', href: '/apple-touch-icon.png' },
        { rel: 'manifest', href: '/manifest.webmanifest' },
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        {
          rel: 'stylesheet',
          href: 'https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;600;700;800;900&family=Inter:wght@400;500;600;700&display=swap',
        },
      ],
    },
  },
})
