<script setup lang="ts">
import type { Lugar, OpcionRuta, ResultadoRuta } from '~/types/bloqueo'

// Opción de ruta con identidad estable para el resaltado en el mapa.
interface Opcion extends OpcionRuta {
  id: string
  etiqueta: string
}

const activa = defineModel<string>('activa', { default: 'directa' })
const emit = defineEmits<{
  (e: 'resultado', r: ResultadoRuta): void
  (e: 'cerrar'): void
}>()

const { geocodificar, buscarRuta, configurada } = useApi()
const toast = useToast()

const textoOrigen = ref('')
const textoDestino = ref('')
const origen = ref<Lugar | null>(null)
const destino = ref<Lugar | null>(null)
const sugerenciasOrigen = ref<Lugar[]>([])
const sugerenciasDestino = ref<Lugar[]>([])
const cargando = ref(false)
const ubicando = ref(false)
const resultado = ref<ResultadoRuta | null>(null)

const opciones = computed<Opcion[]>(() => {
  if (!resultado.value) return []
  const arr: Opcion[] = [{ id: 'directa', etiqueta: 'Ruta directa', ...resultado.value.directa }]
  resultado.value.alternativas.forEach((a, i) =>
    arr.push({ id: `alt-${i}`, etiqueta: `Alterna ${i + 1}`, ...a }))
  return arr
})

function usarMiUbicacion() {
  if (!import.meta.client || !navigator.geolocation) {
    toast.add({ title: 'Tu navegador no permite ubicación.', color: 'warning' })
    return
  }
  ubicando.value = true
  navigator.geolocation.getCurrentPosition(
    (p) => {
      origen.value = { etiqueta: 'Mi ubicación', lat: p.coords.latitude, lng: p.coords.longitude }
      textoOrigen.value = 'Mi ubicación'
      sugerenciasOrigen.value = []
      ubicando.value = false
      toast.add({ title: 'Origen fijado en tu ubicación 📍', color: 'success' })
    },
    () => {
      ubicando.value = false
      toast.add({ title: 'No pudimos obtener tu ubicación (revisa permisos).', color: 'warning' })
    },
    { enableHighAccuracy: true, timeout: 8000 },
  )
}

async function sugerir(texto: string, cual: 'origen' | 'destino') {
  if (texto.trim().length < 3 || !configurada.value) return
  const r = await geocodificar(texto)
  if (cual === 'origen') sugerenciasOrigen.value = r
  else sugerenciasDestino.value = r
}

function elegir(lugar: Lugar, cual: 'origen' | 'destino') {
  if (cual === 'origen') {
    origen.value = lugar
    textoOrigen.value = lugar.etiqueta
    sugerenciasOrigen.value = []
  } else {
    destino.value = lugar
    textoDestino.value = lugar.etiqueta
    sugerenciasDestino.value = []
  }
}

async function calcular() {
  if (!origen.value || !destino.value) {
    toast.add({ title: 'Elige origen y destino de las sugerencias.', color: 'warning' })
    return
  }
  cargando.value = true
  try {
    const r = await buscarRuta(origen.value, destino.value)
    resultado.value = r
    // Selección por defecto: la directa si está libre; si no, la primera alterna libre.
    const altLibre = r.alternativas.findIndex((a) => a.libre)
    activa.value = r.directa.libre
      ? 'directa'
      : altLibre >= 0
        ? `alt-${altLibre}`
        : r.alternativas.length
          ? 'alt-0'
          : 'directa'
    emit('resultado', r)

    const bloqueos = r.directa.bloqueos_en_ruta.length
    toast.add(
      bloqueos === 0
        ? { title: 'Ruta libre 🎉', color: 'success' }
        : r.alternativas.some((a) => a.libre)
          ? { title: 'Tu ruta tiene bloqueos; te propusimos una alterna libre 🟢', color: 'warning' }
          : { title: `${bloqueos} bloqueo(s) en tu ruta`, color: 'error' },
    )
  } catch {
    toast.add({ title: 'No se pudo calcular la ruta.', color: 'error' })
  } finally {
    cargando.value = false
  }
}

function seleccionar(id: string) {
  activa.value = id
}
</script>

<template>
  <div class="rounded-2xl bg-white shadow-2xl ring-1 ring-black/5">
    <div class="flex items-center justify-between border-b border-stone-100 px-4 py-3">
      <h3 class="font-display font-bold text-stone-800">Calcular ruta</h3>
      <UButton icon="i-lucide-x" color="neutral" variant="ghost" size="xs" square @click="emit('cerrar')" />
    </div>

    <div class="space-y-3 p-4">
      <div>
        <div class="flex items-center justify-between">
          <label class="text-xs font-semibold text-stone-500">Origen</label>
          <button
            class="flex items-center gap-1 text-xs font-semibold text-terracota-700 transition hover:text-terracota-800"
            :disabled="ubicando"
            @click="usarMiUbicacion"
          >
            <UIcon :name="ubicando ? 'i-lucide-loader-circle' : 'i-lucide-locate-fixed'" :class="ubicando && 'animate-spin'" />
            Mi ubicación
          </button>
        </div>
        <UInput
          v-model="textoOrigen"
          placeholder="¿Desde dónde?"
          icon="i-lucide-circle-dot"
          size="lg"
          class="mt-1 w-full"
          @update:model-value="sugerir(textoOrigen, 'origen')"
        />
        <ul v-if="sugerenciasOrigen.length" class="mt-1 overflow-hidden rounded-lg border border-stone-200 text-sm">
          <li
            v-for="(s, i) in sugerenciasOrigen"
            :key="i"
            class="cursor-pointer px-3 py-2 hover:bg-stone-50"
            @click="elegir(s, 'origen')"
          >
            {{ s.etiqueta }}
          </li>
        </ul>
      </div>

      <div>
        <label class="text-xs font-semibold text-stone-500">Destino</label>
        <UInput
          v-model="textoDestino"
          placeholder="¿A dónde vas?"
          icon="i-lucide-flag"
          size="lg"
          class="mt-1 w-full"
          @update:model-value="sugerir(textoDestino, 'destino')"
        />
        <ul v-if="sugerenciasDestino.length" class="mt-1 overflow-hidden rounded-lg border border-stone-200 text-sm">
          <li
            v-for="(s, i) in sugerenciasDestino"
            :key="i"
            class="cursor-pointer px-3 py-2 hover:bg-stone-50"
            @click="elegir(s, 'destino')"
          >
            {{ s.etiqueta }}
          </li>
        </ul>
      </div>

      <UButton
        block
        icon="i-lucide-navigation"
        size="lg"
        class="justify-center rounded-xl font-semibold"
        :loading="cargando"
        :disabled="!configurada"
        @click="calcular"
      >
        {{ resultado ? 'Recalcular' : 'Calcular ruta' }}
      </UButton>

      <!-- Opciones de ruta (estilo Waze) -->
      <div v-if="opciones.length" class="space-y-2 pt-1">
        <button
          v-for="o in opciones"
          :key="o.id"
          class="w-full rounded-xl border p-3 text-left transition hover-lift"
          :class="activa === o.id ? 'border-terracota-400 bg-terracota-50 ring-1 ring-terracota-300' : 'border-stone-200 bg-white hover:border-stone-300'"
          @click="seleccionar(o.id)"
        >
          <div class="flex items-center gap-2">
            <UIcon
              :name="o.libre ? 'i-lucide-circle-check' : 'i-lucide-triangle-alert'"
              :class="o.libre ? 'text-pino-600' : 'text-terracota-600'"
            />
            <span class="font-semibold text-stone-800">{{ o.etiqueta }}</span>
            <span
              v-if="activa === o.id"
              class="ml-auto rounded-full bg-terracota-600 px-2 py-0.5 text-[10px] font-bold uppercase text-white"
            >Elegida</span>
          </div>
          <div class="mt-1 flex items-center gap-3 text-xs text-stone-500">
            <span v-if="o.resumen">{{ o.resumen.distancia_km }} km · {{ o.resumen.duracion_min }} min</span>
            <span
              class="font-semibold"
              :class="o.libre ? 'text-pino-600' : 'text-terracota-600'"
            >{{ o.libre ? 'Libre' : `${o.bloqueos_en_ruta.length} bloqueo(s) en el camino` }}</span>
          </div>
        </button>

        <p
          v-if="resultado && !resultado.directa.libre && !resultado.alternativas.length"
          class="rounded-lg bg-ambar-50 px-3 py-2 text-xs text-ambar-800"
        >
          No encontramos una ruta que evite los bloqueos (el Istmo tiene un corredor
          principal). Te mostramos la de menos bloqueos; conduce con precaución.
        </p>
      </div>

      <p v-if="!configurada" class="text-xs text-stone-400">
        Disponible al configurar la API del backend.
      </p>
    </div>
  </div>
</template>
