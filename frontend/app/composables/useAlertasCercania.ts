import type { Bloqueo } from '~/types/bloqueo'
import { TIPOS_META } from '~/types/bloqueo'
import { distanciaKm } from '~/utils/tiempo'

// Alertas de cercanía en el navegador: cuando aparece un bloqueo NUEVO cerca de
// tu ubicación, dispara una notificación ("hay un bloqueo a 2 km de ti").
//
// Es la versión que "llega sola" en la demo sin depender de push del servidor:
// se apoya en el refresco periódico del mapa + la API de Notificaciones y la
// geolocalización del propio navegador.
export function useAlertasCercania() {
  const activas = ref(false)
  const soportado = ref(true)
  const posicion = ref<{ lat: number; lng: number } | null>(null)
  const radioKm = 5

  // Ids ya vistos: en el primer barrido solo se registran (no se notifica todo).
  const conocidos = new Set<string>()
  const programadosAvisados = new Set<string>()
  let iniciado = false
  let watchId: number | null = null

  function disponible() {
    return typeof window !== 'undefined' && 'Notification' in window && 'geolocation' in navigator
  }

  async function activar(): Promise<boolean> {
    if (!disponible()) {
      soportado.value = false
      return false
    }
    const permiso = await Notification.requestPermission()
    if (permiso !== 'granted') return false

    watchId = navigator.geolocation.watchPosition(
      (p) => (posicion.value = { lat: p.coords.latitude, lng: p.coords.longitude }),
      () => {},
      { enableHighAccuracy: true, maximumAge: 30_000 },
    )
    activas.value = true
    return true
  }

  function desactivar() {
    if (watchId !== null) navigator.geolocation.clearWatch(watchId)
    watchId = null
    activas.value = false
  }

  // Se llama tras cada carga de bloqueos.
  function revisar(bloqueos: Bloqueo[]) {
    if (!activas.value || !posicion.value) {
      // Aun sin activar, memorizamos los ids para no avisar en retroactivo.
      bloqueos.forEach((b) => conocidos.add(b.id))
      iniciado = true
      return
    }

    for (const b of bloqueos) {
      const nuevo = !conocidos.has(b.id)
      conocidos.add(b.id)
      if (!iniciado || !nuevo) continue

      const km = distanciaKm(posicion.value, { lat: b.lat, lng: b.lng })
      if (km <= radioKm) {
        const meta = TIPOS_META[b.tipo] ?? TIPOS_META.otro
        new Notification('⚠️ Bloqueo cerca de ti', {
          body: `${meta.etiqueta} a ${km.toFixed(1)} km · ${b.municipio || 'Istmo'}`,
          tag: b.id,
        })
      }
    }
    iniciado = true
  }

  // Avisa de los cierres PROGRAMADOS que arrancan pronto (≤ 90 min).
  function revisarProgramados(list: Bloqueo[]) {
    if (!activas.value) {
      list.forEach((b) => programadosAvisados.add(b.id))
      return
    }
    const ahora = Date.now()
    for (const b of list) {
      if (!b.inicia_en || programadosAvisados.has(b.id)) continue
      const minutos = (new Date(b.inicia_en).getTime() - ahora) / 60000
      if (minutos > 0 && minutos <= 90) {
        programadosAvisados.add(b.id)
        const meta = TIPOS_META[b.tipo] ?? TIPOS_META.otro
        const hora = new Date(b.inicia_en).toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' })
        new Notification('🕒 Cierre programado', {
          body: `${meta.etiqueta} en ${b.municipio || 'el Istmo'} inicia ${hora}`,
          tag: `prog-${b.id}`,
        })
      }
    }
  }

  onBeforeUnmount(desactivar)

  return { activas, soportado, posicion, activar, desactivar, revisar, revisarProgramados }
}
