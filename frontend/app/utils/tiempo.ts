import type { Bloqueo } from '~/types/bloqueo'

// "hace 8 min", "hace 2 h"... a partir de una fecha ISO.
export function hace(iso?: string): string {
  if (!iso) return ''
  const seg = Math.max(0, Math.floor((Date.now() - new Date(iso).getTime()) / 1000))
  if (seg < 60) return 'hace un momento'
  const min = Math.floor(seg / 60)
  if (min < 60) return `hace ${min} min`
  const h = Math.floor(min / 60)
  if (h < 24) return `hace ${h} h`
  const d = Math.floor(h / 24)
  return `hace ${d} d`
}

export interface Confianza {
  etiqueta: string
  nivel: 'alta' | 'media' | 'baja'
  color: string
}

// Nivel de confianza según las confirmaciones de la comunidad.
export function confianza(b: Pick<Bloqueo, 'confirmaciones_sigue' | 'confirmaciones_liberado'>): Confianza {
  const n = (b.confirmaciones_sigue ?? 0) - (b.confirmaciones_liberado ?? 0)
  if (n >= 3) return { etiqueta: 'Confirmado por la comunidad', nivel: 'alta', color: '#16a34a' }
  if (n >= 1) return { etiqueta: 'Confirmado', nivel: 'media', color: '#f59e0b' }
  return { etiqueta: 'Sin confirmar', nivel: 'baja', color: '#6b7280' }
}

// Distancia en km entre dos coordenadas (haversine).
export function distanciaKm(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const R = 6371
  const dLat = ((b.lat - a.lat) * Math.PI) / 180
  const dLng = ((b.lng - a.lng) * Math.PI) / 180
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((a.lat * Math.PI) / 180) * Math.cos((b.lat * Math.PI) / 180) * Math.sin(dLng / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(s), Math.sqrt(1 - s))
}
