<script setup lang="ts">
import maplibregl from 'maplibre-gl'
import type { Bloqueo } from '~/types/bloqueo'
import { TIPOS_META, ESTADOS_META, ROLES_META } from '~/types/bloqueo'
import { resolverEstiloMapa } from '~/composables/useMapaEstilo'
import { hace, confianza } from '~/utils/tiempo'

const GLIFOS: Record<string, string> = { activo: '!', programado: '⏱', finalizado: '✓' }

interface RutaMapa {
  id: string
  geometria: { lat: number; lng: number }[]
  activa: boolean
}

const props = defineProps<{
  bloqueos: Bloqueo[]
  rutas?: RutaMapa[]
  modoReporte?: boolean
}>()

const emit = defineEmits<{
  (e: 'mapa-click', pos: { lat: number; lng: number }): void
  (e: 'confirmar', datos: { id: string; voto: 'sigue' | 'liberado' }): void
  (e: 'seleccionar-ruta', id: string): void
}>()

const contenedor = ref<HTMLDivElement>()
const esDemo = ref(false)
let mapa: maplibregl.Map | null = null
let marcadores: maplibregl.Marker[] = []
let marcadorNuevo: maplibregl.Marker | null = null
let observador: ResizeObserver | null = null
let idsRuta: string[] = []

const CENTRO_ISTMO: [number, number] = [-95.1, 16.45]

onMounted(async () => {
  if (!contenedor.value) return
  const { style, opciones, esDemo: demo } = await resolverEstiloMapa()
  esDemo.value = demo

  mapa = new maplibregl.Map({
    container: contenedor.value,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    style: style as any,
    center: CENTRO_ISTMO,
    zoom: 9,
    ...opciones,
  })

  mapa.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right')
  mapa.addControl(new maplibregl.GeolocateControl({ trackUserLocation: true, positionOptions: { enableHighAccuracy: true } }), 'top-right')

  mapa.on('load', () => {
    mapa!.resize()
    dibujarBloqueos()
    dibujarRutas()
  })

  observador = new ResizeObserver(() => mapa?.resize())
  observador.observe(contenedor.value)

  mapa.on('click', (e) => {
    if (!props.modoReporte) return
    const pos = { lat: e.lngLat.lat, lng: e.lngLat.lng }
    if (!marcadorNuevo) {
      marcadorNuevo = new maplibregl.Marker({ color: '#bf5b34', draggable: true })
      marcadorNuevo.on('dragend', () => {
        const p = marcadorNuevo!.getLngLat()
        emit('mapa-click', { lat: p.lat, lng: p.lng })
      })
    }
    marcadorNuevo.setLngLat([pos.lng, pos.lat]).addTo(mapa!)
    emit('mapa-click', pos)
  })
})

onBeforeUnmount(() => {
  observador?.disconnect()
  mapa?.remove()
})

function volarA(lat: number, lng: number) {
  mapa?.flyTo({ center: [lng, lat], zoom: 13, speed: 1.4 })
}
defineExpose({ volarA })

function limpiarMarcadores() {
  marcadores.forEach((m) => m.remove())
  marcadores = []
}

// Pin tipo "gota" anclado en la punta (anchor:'bottom'): la punta señala la
// coordenada exacta y no se desplaza al hacer zoom.
// IMPORTANTE: el contenedor NO lleva `position` inline — MapLibre le aplica
// `position:absolute` vía la clase `.maplibregl-marker`; si lo forzamos a
// `relative` el marcador se sale de sitio al hacer zoom.
function elementoMarcador(b: Bloqueo): HTMLElement {
  const estadoMeta = ESTADOS_META[b.estado] ?? ESTADOS_META.activo
  const color = estadoMeta.color
  const verificado = b.verificado !== false
  const glifo = GLIFOS[b.estado] ?? '!'

  const wrap = document.createElement('div')
  wrap.className = 'vl-pin'
  wrap.style.cssText = 'width:34px;height:44px;cursor:pointer'
  wrap.title = TIPOS_META[b.tipo]?.etiqueta ?? ''

  // Pulso "radar" alrededor de la cabeza, solo en activos verificados.
  if (b.estado === 'activo' && verificado) {
    const ring = document.createElement('span')
    ring.className = 'marcador-radar'
    ring.style.setProperty('--c', color)
    ring.style.cssText += ';width:26px;height:26px;left:4px;top:3px;right:auto;bottom:auto'
    wrap.appendChild(ring)
  }

  // Forma de la gota en SVG (borde blanco; punteado si está por verificar).
  const dash = verificado ? '' : 'stroke-dasharray="3.6 2.6"'
  wrap.insertAdjacentHTML('beforeend', `
    <svg width="34" height="44" viewBox="0 0 34 44" fill="none"
      style="position:relative;display:block;filter:drop-shadow(0 3px 4px rgba(0,0,0,.32))">
      <path d="M17 42.5 C17 42.5 4.5 26 4.5 15.5 A12.5 12.5 0 1 1 29.5 15.5 C29.5 26 17 42.5 17 42.5 Z"
        fill="${color}" stroke="#fff" stroke-width="2.5" stroke-linejoin="round" ${dash}/>
    </svg>`)

  // Glifo centrado en la cabeza.
  const glyphEl = document.createElement('div')
  glyphEl.textContent = glifo
  glyphEl.style.cssText = `position:absolute;top:8px;left:0;width:34px;text-align:center;
    color:#fff;font-weight:800;font-size:15px;line-height:1;font-family:system-ui;pointer-events:none`
  wrap.appendChild(glyphEl)

  // Badge "?" para los reportes por verificar.
  if (!verificado) {
    const badge = document.createElement('span')
    badge.textContent = '?'
    badge.style.cssText = `position:absolute;top:-1px;right:1px;width:16px;height:16px;border-radius:9999px;
      background:#e0982f;color:#fff;border:2px solid #fff;font-size:10px;font-weight:800;
      display:flex;align-items:center;justify-content:center;line-height:1;font-family:system-ui`
    wrap.appendChild(badge)
  }
  return wrap
}

function contenidoPopup(b: Bloqueo): HTMLElement {
  const meta = TIPOS_META[b.tipo] ?? TIPOS_META.otro
  const estadoMeta = ESTADOS_META[b.estado] ?? ESTADOS_META.activo
  const verificado = b.verificado !== false
  const conf = confianza(b)
  const cont = document.createElement('div')
  cont.style.cssText = 'font-family:\'Plus Jakarta Sans\',system-ui;min-width:224px;max-width:252px;color:#33302b'
  const foto = b.foto_url
    ? `<img src="${b.foto_url}" alt="Foto" style="width:100%;height:110px;object-fit:cover;border-radius:8px;margin-bottom:8px">`
    : ''

  const insignia = verificado
    ? `<span style="font-size:10px;font-weight:700;text-transform:uppercase;padding:1px 7px;border-radius:999px;background:#2f5d4c1a;color:#2f5d4c">✓ Verificado</span>`
    : `<span style="font-size:10px;font-weight:700;text-transform:uppercase;padding:1px 7px;border-radius:999px;background:#e0982f1a;color:#b7791f">Por verificar</span>`

  const rolMeta = b.autor_rol ? ROLES_META[b.autor_rol as keyof typeof ROLES_META] : null
  const autor = b.autor_nombre
    ? `<div style="font-size:11px;color:#78716c;margin-bottom:6px">Reportado por <b>${b.autor_nombre}</b>${rolMeta ? ` · ${rolMeta.etiqueta}` : ''}</div>`
    : ''

  const rutaAlt = b.ruta_alterna_texto
    ? `<div style="font-size:11px;background:#fbf3ee;color:#8a3823;padding:6px 8px;border-radius:8px;margin-bottom:8px">
         <b>Ruta alterna:</b> ${b.ruta_alterna_texto}</div>`
    : ''

  const botones = b.estado === 'finalizado' ? '' : `
    <div style="display:flex;gap:6px">
      <button data-voto="sigue" style="flex:1;padding:7px;border:0;border-radius:8px;
        background:#2f5d4c;color:#fff;cursor:pointer;font-size:12px;font-weight:600">${verificado ? 'Sigue así' : 'Confirmar'}</button>
      <button data-voto="liberado" style="flex:1;padding:7px;border:1px solid #d6d3cd;border-radius:8px;
        background:#fff;color:#57534e;cursor:pointer;font-size:12px;font-weight:600">Ya no está</button>
    </div>`

  cont.innerHTML = `
    ${foto}
    <div style="display:flex;align-items:center;gap:6px;margin-bottom:4px">
      <span style="font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.04em;color:#a8a29e">${meta.etiqueta}</span>
      <span style="margin-left:auto;font-size:10px;font-weight:700;text-transform:uppercase;padding:1px 7px;border-radius:999px;background:${estadoMeta.color}1a;color:${estadoMeta.color}">${estadoMeta.etiqueta}</span>
    </div>
    <strong style="font-size:17px;font-family:'Fraunces',Georgia,serif;font-weight:600;letter-spacing:-.01em">${b.municipio || 'Istmo'}</strong>
    <div style="margin:4px 0 6px">${insignia}</div>
    <div style="font-size:12px;color:#57534e;margin:2px 0 6px">${b.descripcion || ''}</div>
    ${autor}
    <div style="font-size:11px;color:#78716c;margin-bottom:6px">
      🕒 ${hace(b.creado_en)} ·
      <span style="color:${conf.color};font-weight:600">${conf.etiqueta}</span> ·
      👥 ${b.confirmaciones_sigue}
    </div>
    ${rutaAlt}
    ${botones}`
  cont.querySelectorAll('button').forEach((btn) => {
    btn.addEventListener('click', () => {
      emit('confirmar', { id: b.id, voto: (btn as HTMLElement).dataset.voto as 'sigue' | 'liberado' })
    })
  })
  return cont
}

function dibujarBloqueos() {
  if (!mapa) return
  limpiarMarcadores()
  for (const b of props.bloqueos) {
    const popup = new maplibregl.Popup({ offset: 26, closeButton: false }).setDOMContent(contenidoPopup(b))
    const m = new maplibregl.Marker({ element: elementoMarcador(b), anchor: 'bottom' })
      .setLngLat([b.lng, b.lat])
      .setPopup(popup)
      .addTo(mapa)
    marcadores.push(m)
  }
}

function limpiarRutas() {
  for (const id of idsRuta) {
    if (mapa?.getLayer(id)) mapa.removeLayer(id)
    if (mapa?.getLayer(id + '-hit')) mapa.removeLayer(id + '-hit')
    if (mapa?.getSource(id)) mapa.removeSource(id)
  }
  idsRuta = []
}

function dibujarRutas() {
  if (!mapa || !mapa.isStyleLoaded()) return
  limpiarRutas()
  const rutas = props.rutas ?? []
  if (!rutas.length) return

  const bounds = new maplibregl.LngLatBounds()
  // Inactivas primero (debajo), activa al final (encima).
  const ordenadas = [...rutas].sort((a, b) => Number(a.activa) - Number(b.activa))

  for (const r of ordenadas) {
    if (r.geometria.length < 2) continue
    const coords = r.geometria.map((p) => [p.lng, p.lat])
    r.geometria.forEach((p) => bounds.extend([p.lng, p.lat]))
    const id = `ruta-${r.id}`
    idsRuta.push(id)

    mapa.addSource(id, {
      type: 'geojson',
      data: { type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates: coords } },
    })
    mapa.addLayer({
      id,
      type: 'line',
      source: id,
      layout: { 'line-join': 'round', 'line-cap': 'round' },
      paint: r.activa
        ? { 'line-color': '#bf5b34', 'line-width': 6, 'line-opacity': 0.95 }
        : { 'line-color': '#9ca3af', 'line-width': 4, 'line-opacity': 0.55, 'line-dasharray': [1.4, 1.4] },
    })
    // Capa invisible ancha para captar clics fácilmente (seleccionar la ruta).
    mapa.addLayer({
      id: id + '-hit',
      type: 'line',
      source: id,
      paint: { 'line-color': '#000', 'line-width': 18, 'line-opacity': 0 },
    })
    mapa.on('click', id + '-hit', () => emit('seleccionar-ruta', r.id))
    mapa.on('mouseenter', id + '-hit', () => { if (mapa) mapa.getCanvas().style.cursor = 'pointer' })
    mapa.on('mouseleave', id + '-hit', () => { if (mapa) mapa.getCanvas().style.cursor = '' })
  }

  if (!bounds.isEmpty()) mapa.fitBounds(bounds, { padding: 70, maxZoom: 13 })
}

watch(() => props.bloqueos, () => mapa?.isStyleLoaded() && dibujarBloqueos(), { deep: true })
watch(() => props.rutas, () => mapa?.isStyleLoaded() && dibujarRutas(), { deep: true })

watch(() => props.modoReporte, (activo) => {
  if (!activo && marcadorNuevo) {
    marcadorNuevo.remove()
    marcadorNuevo = null
  }
})
</script>

<template>
  <div class="relative h-full w-full">
    <div ref="contenedor" class="h-full w-full" />

    <!-- Leyenda del mapa (se corre para no chocar con el panel flotante en desktop) -->
    <div class="glass pointer-events-none absolute bottom-3 left-3 hidden rounded-xl px-3 py-2 text-xs shadow-lg sm:block md:left-[384px]">
      <div class="mb-1 flex items-center gap-2"><span class="size-3 rounded-full bg-terracota-600" /> Activo</div>
      <div class="mb-1 flex items-center gap-2"><span class="size-3 rounded-full bg-ambar-500" /> Programado</div>
      <div class="flex items-center gap-2"><span class="size-3 rounded-full border-2 border-dashed border-stone-400 bg-stone-300" /> Por verificar</div>
    </div>

    <div
      v-if="esDemo"
      class="absolute bottom-2 right-2 rounded bg-amber-100 px-2 py-1 text-xs text-amber-800 shadow"
    >
      Mapa OpenStreetMap
    </div>
  </div>
</template>
