export type TipoBloqueo =
  | 'manifestacion'
  | 'obra'
  | 'accidente'
  | 'conflicto'
  | 'derrumbe'
  | 'otro'

export type EstadoBloqueo = 'activo' | 'programado' | 'finalizado'

export type Rol = 'usuario' | 'noticiero' | 'admin'

export interface Bloqueo {
  id: string
  estado: EstadoBloqueo
  tipo: TipoBloqueo
  lat: number
  lng: number
  descripcion: string
  municipio: string
  foto_url?: string | null
  inicia_en?: string | null
  ruta_alterna_texto?: string | null
  verificado?: boolean
  autor_id?: string | null
  autor_rol?: Rol | string | null
  autor_nombre?: string | null
  autor_foto?: string | null
  creado_en: string
  actualizado_en: string
  confirmaciones_sigue: number
  confirmaciones_liberado: number
  expira_en: number
  distancia_a_ruta?: number
}

// Metadatos de presentación por rol (badge en tarjetas y header).
export const ROLES_META: Record<Rol, { etiqueta: string; icono: string; color: string }> = {
  admin:     { etiqueta: 'Admin',     icono: 'i-lucide-shield', color: '#bf5b34' },
  noticiero: { etiqueta: 'Noticiero', icono: 'i-lucide-badge-check', color: '#2f5d4c' },
  usuario:   { etiqueta: 'Usuario',   icono: 'i-lucide-user', color: '#78716c' },
}

// Metadatos de presentación por estado (color del marcador/badge, ícono, etiqueta).
export const ESTADOS_META: Record<EstadoBloqueo, { etiqueta: string; icono: string; color: string }> = {
  activo:     { etiqueta: 'Activo',     icono: 'i-lucide-octagon-x', color: '#bf5b34' },
  programado: { etiqueta: 'Programado', icono: 'i-lucide-clock',     color: '#e0982f' },
  finalizado: { etiqueta: 'Finalizado', icono: 'i-lucide-check',     color: '#2f5d4c' },
}

// Una opción de ruta (directa o alterna).
export interface OpcionRuta {
  libre: boolean
  resumen?: { distancia_km: number; duracion_min: number }
  geometria: { lat: number; lng: number }[]
  bloqueos_en_ruta: Bloqueo[]
}

export interface ResultadoRuta {
  origen: { lat: number; lng: number }
  destino: { lat: number; lng: number }
  directa: OpcionRuta
  // Hasta 2 rutas que rodean los bloqueos (solo si la directa tiene bloqueos).
  alternativas: OpcionRuta[]
}

export interface Lugar {
  etiqueta: string
  lat: number
  lng: number
}

// Metadatos de presentación por tipo de bloqueo (color, icono, etiqueta).
export const TIPOS_META: Record<
  TipoBloqueo,
  { etiqueta: string; icono: string; color: string }
> = {
  manifestacion: { etiqueta: 'Manifestación', icono: 'i-lucide-megaphone', color: '#dc2626' },
  obra:          { etiqueta: 'Obra',          icono: 'i-lucide-construction', color: '#f59e0b' },
  accidente:     { etiqueta: 'Accidente',     icono: 'i-lucide-car-front', color: '#ea580c' },
  conflicto:     { etiqueta: 'Conflicto',     icono: 'i-lucide-flame', color: '#b91c1c' },
  derrumbe:      { etiqueta: 'Derrumbe',      icono: 'i-lucide-mountain', color: '#78716c' },
  otro:          { etiqueta: 'Otro',          icono: 'i-lucide-triangle-alert', color: '#6b7280' },
}
