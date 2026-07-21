// Login propio: el backend (Laravel) emite un JWT con el rol. Soporta correo/
// contraseña (siempre activo) y proveedores sociales (Google/Facebook), que quedan
// dormidos hasta configurar sus IDs (NUXT_PUBLIC_GOOGLE_CLIENT_ID / _FACEBOOK_APP_ID).

import type { Rol } from '~/types/bloqueo'

export interface Usuario {
  id: string
  nombre: string
  email: string
  rol: Rol | string
  foto?: string | null
  proveedor?: string
}

interface Sesion {
  token: string
  usuario: Usuario
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
declare global {
  interface Window {
    google?: any
    FB?: any
    __gisReady?: Promise<void>
    __fbReady?: Promise<void>
    fbAsyncInit?: () => void
  }
}

const CLAVE = 'vialibre_sesion'

function expDelToken(token: string): number {
  try {
    const base = token.split('.')[1] ?? ''
    const json = atob(base.replace(/-/g, '+').replace(/_/g, '/'))
    return Number(JSON.parse(json).exp ?? 0)
  } catch {
    return 0
  }
}

export function useAuth() {
  const cfg = useRuntimeConfig().public
  const base = cfg.apiUrl as string
  const googleClientId = cfg.googleClientId as string
  const facebookAppId = (cfg.facebookAppId as string) || ''

  const usuario = useState<Usuario | null>('usuario', () => null)
  const token = useState<string | null>('token', () => null)

  const googleActivo = computed(() => Boolean(googleClientId))
  const facebookActivo = computed(() => Boolean(facebookAppId))
  const esAdmin = computed(() => usuario.value?.rol === 'admin')
  const esNoticiero = computed(() => usuario.value?.rol === 'noticiero' || esAdmin.value)

  function persistir(s: Sesion | null) {
    if (s) {
      usuario.value = s.usuario
      token.value = s.token
      if (import.meta.client) localStorage.setItem(CLAVE, JSON.stringify(s))
    } else {
      usuario.value = null
      token.value = null
      if (import.meta.client) localStorage.removeItem(CLAVE)
    }
  }

  // Restaura la sesión guardada (si el token no caducó) y la refresca con /auth/yo.
  async function restaurar() {
    if (!import.meta.client) return
    const raw = localStorage.getItem(CLAVE)
    if (!raw) return
    try {
      const s = JSON.parse(raw) as Sesion
      if (expDelToken(s.token) * 1000 <= Date.now()) return persistir(null)
      persistir(s)
      // Refresco en segundo plano (rol actualizado, etc.).
      const r = await $fetch<{ usuario: Usuario }>(`${base}/auth/yo`, {
        headers: { Authorization: `Bearer ${s.token}` },
      }).catch(() => null)
      if (r?.usuario) persistir({ token: s.token, usuario: r.usuario })
    } catch {
      persistir(null)
    }
  }

  async function registrar(nombre: string, email: string, password: string) {
    const s = await $fetch<Sesion>(`${base}/auth/registro`, {
      method: 'POST',
      body: { nombre, email, password },
    })
    persistir(s)
  }

  async function login(email: string, password: string) {
    const s = await $fetch<Sesion>(`${base}/auth/login`, {
      method: 'POST',
      body: { email, password },
    })
    persistir(s)
  }

  async function loginSocial(proveedor: 'google' | 'facebook') {
    const tokenProveedor = proveedor === 'google' ? await tokenGoogle() : await tokenFacebook()
    const s = await $fetch<Sesion>(`${base}/auth/social`, {
      method: 'POST',
      body: { proveedor, token: tokenProveedor },
    })
    persistir(s)
  }

  function salir() {
    if (import.meta.client && window.google?.accounts?.id) {
      window.google.accounts.id.disableAutoSelect()
    }
    persistir(null)
  }

  function authHeader(): Record<string, string> {
    return token.value ? { Authorization: `Bearer ${token.value}` } : {}
  }

  return {
    usuario,
    token,
    googleActivo,
    facebookActivo,
    esAdmin,
    esNoticiero,
    restaurar,
    registrar,
    login,
    loginSocial,
    salir,
    authHeader,
  }

  // ── Proveedores sociales (SDKs cargados on-demand) ─────────────────────────

  function cargarGis(): Promise<void> {
    if (window.__gisReady) return window.__gisReady
    window.__gisReady = new Promise((resolve, reject) => {
      const s = document.createElement('script')
      s.src = 'https://accounts.google.com/gsi/client'
      s.async = true
      s.defer = true
      s.onload = () => resolve()
      s.onerror = () => reject(new Error('No se pudo cargar Google Sign-In'))
      document.head.appendChild(s)
    })
    return window.__gisReady
  }

  async function tokenGoogle(): Promise<string> {
    if (!googleActivo.value) throw new Error('El login con Google no está configurado.')
    await cargarGis()
    return new Promise<string>((resolve, reject) => {
      window.google.accounts.id.initialize({
        client_id: googleClientId,
        callback: (resp: { credential: string }) => resolve(resp.credential),
      })
      window.google.accounts.id.prompt((n: { isNotDisplayed: () => boolean; isSkippedMoment: () => boolean }) => {
        if (n.isNotDisplayed() || n.isSkippedMoment()) {
          reject(new Error('El diálogo de Google no se mostró (revisa el Client ID y los orígenes autorizados).'))
        }
      })
    })
  }

  function cargarFb(): Promise<void> {
    if (window.__fbReady) return window.__fbReady
    window.__fbReady = new Promise((resolve, reject) => {
      window.fbAsyncInit = () => {
        window.FB.init({ appId: facebookAppId, cookie: true, xfbml: false, version: 'v19.0' })
        resolve()
      }
      const s = document.createElement('script')
      s.src = 'https://connect.facebook.net/es_LA/sdk.js'
      s.async = true
      s.defer = true
      s.onerror = () => reject(new Error('No se pudo cargar Facebook Login'))
      document.head.appendChild(s)
    })
    return window.__fbReady
  }

  async function tokenFacebook(): Promise<string> {
    if (!facebookActivo.value) throw new Error('El login con Facebook no está configurado.')
    await cargarFb()
    return new Promise<string>((resolve, reject) => {
      window.FB.login((resp: { authResponse?: { accessToken: string } }) => {
        if (resp.authResponse?.accessToken) resolve(resp.authResponse.accessToken)
        else reject(new Error('No se completó el inicio de sesión con Facebook.'))
      }, { scope: 'public_profile,email' })
    })
  }
}
