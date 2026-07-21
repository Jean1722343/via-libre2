import type { Bloqueo, EstadoBloqueo, Lugar, ResultadoRuta, Rol } from '~/types/bloqueo'

export interface UsuarioAdmin {
  id: string
  email: string
  nombre: string
  rol: Rol | string
  proveedor?: string
  creado_en?: string
}

// Cliente de la API del backend (API Gateway + Lambda).
export function useApi() {
  const base = useRuntimeConfig().public.apiUrl as string
  const { authHeader } = useAuth()

  const configurada = computed(() => Boolean(base))

  async function listarBloqueos(
    estado: EstadoBloqueo = 'activo',
  ): Promise<{ estado: string; total: number; bloqueos: Bloqueo[] }> {
    if (!base) return { estado, total: 0, bloqueos: [] }
    return await $fetch(`${base}/reportes`, { query: { estado } })
  }

  async function resumen(): Promise<{ activos: number; programados: number; finalizados: number }> {
    if (!base) return { activos: 0, programados: 0, finalizados: 0 }
    return await $fetch(`${base}/reportes/resumen`)
  }

  async function crearBloqueo(datos: {
    tipo: string
    lat: number
    lng: number
    descripcion?: string
    municipio?: string
    foto_url?: string | null
    estado?: EstadoBloqueo
    inicia_en?: string | null
    ruta_alterna_texto?: string | null
  }): Promise<Bloqueo> {
    return await $fetch(`${base}/reportes`, { method: 'POST', body: datos, headers: authHeader() })
  }

  // Sube una foto DIRECTO a S3 con una URL firmada del backend y devuelve la URL
  // pública. Si la subida de fotos no está configurada (local/501), devuelve null
  // y el reporte simplemente va sin imagen.
  async function subirFoto(file: File): Promise<string | null> {
    if (!base) return null
    try {
      const firma = await $fetch<{ url_subida: string; url_publica: string }>(
        `${base}/fotos/firma`,
        { method: 'POST', body: { tipo: file.type }, headers: authHeader() },
      )
      const res = await fetch(firma.url_subida, {
        method: 'PUT',
        headers: { 'Content-Type': file.type },
        body: file,
      })
      if (!res.ok) return null
      return firma.url_publica
    } catch {
      return null
    }
  }

  async function confirmar(id: string, voto: 'sigue' | 'liberado'): Promise<Bloqueo> {
    return await $fetch(`${base}/reportes/${id}/confirmar`, {
      method: 'POST',
      body: { voto },
      headers: authHeader(),
    })
  }

  // ── Moderación (noticiero / admin) ─────────────────────────────────────────
  async function verificarReporte(id: string): Promise<Bloqueo> {
    return await $fetch(`${base}/reportes/${id}/verificar`, { method: 'POST', headers: authHeader() })
  }

  async function finalizarReporte(id: string): Promise<Bloqueo> {
    return await $fetch(`${base}/reportes/${id}/finalizar`, { method: 'POST', headers: authHeader() })
  }

  async function eliminarReporte(id: string): Promise<void> {
    await $fetch(`${base}/reportes/${id}`, { method: 'DELETE', headers: authHeader() })
  }

  async function listarUsuarios(): Promise<UsuarioAdmin[]> {
    const r = await $fetch<{ usuarios: UsuarioAdmin[] }>(`${base}/admin/usuarios`, { headers: authHeader() })
    return r.usuarios ?? []
  }

  async function cambiarRol(id: string, rol: Rol): Promise<UsuarioAdmin> {
    const r = await $fetch<{ usuario: UsuarioAdmin }>(`${base}/admin/usuarios/${id}/rol`, {
      method: 'POST',
      body: { rol },
      headers: authHeader(),
    })
    return r.usuario
  }

  async function geocodificar(texto: string): Promise<Lugar[]> {
    if (!base) return []
    const r = await $fetch<{ resultados: Lugar[] }>(`${base}/geocode`, {
      query: { texto },
    })
    return r.resultados ?? []
  }

  async function buscarRuta(
    origen: { lat: number; lng: number },
    destino: { lat: number; lng: number },
  ): Promise<ResultadoRuta> {
    return await $fetch(`${base}/rutas`, {
      query: {
        origenLat: origen.lat,
        origenLng: origen.lng,
        destinoLat: destino.lat,
        destinoLng: destino.lng,
      },
    })
  }

  return {
    configurada,
    listarBloqueos,
    resumen,
    crearBloqueo,
    subirFoto,
    confirmar,
    geocodificar,
    buscarRuta,
    verificarReporte,
    finalizarReporte,
    eliminarReporte,
    listarUsuarios,
    cambiarRol,
  }
}
