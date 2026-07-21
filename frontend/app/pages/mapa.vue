<script setup lang="ts">
import type { Bloqueo, EstadoBloqueo, ResultadoRuta, TipoBloqueo } from '~/types/bloqueo'

const route = useRoute()
const { listarBloqueos, resumen, crearBloqueo, subirFoto, confirmar, configurada } = useApi()
const toast = useToast()
const alertas = useAlertasCercania()
const auth = useAuth()
const { abrir: abrirLogin } = useLoginModal()

const estadoTab = ref<EstadoBloqueo>('activo')
const bloqueos = ref<Bloqueo[]>([])
const conteos = ref({ activos: 0, programados: 0, finalizados: 0 })
const cargando = ref(false)
const modoReporte = ref(false)
const posicionNueva = ref<{ lat: number; lng: number } | null>(null)
const resultadoRuta = ref<ResultadoRuta | null>(null)
const rutaActivaId = ref<string>('directa')
const panelRuta = ref(false)

// Opciones de ruta -> geometrías para el mapa (con la activa resaltada).
const rutasMapa = computed(() => {
  if (!resultadoRuta.value) return []
  const arr = [{ id: 'directa', geometria: resultadoRuta.value.directa.geometria, activa: rutaActivaId.value === 'directa' }]
  resultadoRuta.value.alternativas.forEach((a, i) =>
    arr.push({ id: `alt-${i}`, geometria: a.geometria, activa: rutaActivaId.value === `alt-${i}` }))
  return arr
})
const listaMovil = ref(false)
const mapaRef = ref<{ volarA: (lat: number, lng: number) => void }>()

async function cargar() {
  cargando.value = true
  try {
    const [lista, r] = await Promise.all([listarBloqueos(estadoTab.value), resumen().catch(() => conteos.value)])
    bloqueos.value = lista.bloqueos
    conteos.value = r
    alertas.revisar(lista.bloqueos)
    // #2: avisar de cierres programados que arrancan pronto.
    if (alertas.activas.value) {
      listarBloqueos('programado').then((p) => alertas.revisarProgramados(p.bloqueos)).catch(() => {})
    }
  } catch {
    toast.add({ title: 'No se pudieron cargar los reportes.', color: 'error' })
  } finally {
    cargando.value = false
  }
}

watch(estadoTab, cargar)

onMounted(() => {
  cargar()
  if (route.query.reportar) iniciarReporte()
  const t = setInterval(cargar, 30_000)
  onBeforeUnmount(() => clearInterval(t))
})

function entrar() {
  abrirLogin()
}

async function activarAlertas() {
  if (alertas.activas.value) return alertas.desactivar()
  const ok = await alertas.activar()
  toast.add(ok
    ? { title: 'Alertas activadas: te avisamos de bloqueos cercanos.', color: 'success' }
    : { title: 'No se pudieron activar (revisa permisos).', color: 'warning' })
}

function iniciarReporte() {
  if (!configurada.value) {
    toast.add({ title: 'Configura la API del backend para reportar.', color: 'warning' })
    return
  }
  if (!auth.usuario.value) {
    toast.add({ title: 'Inicia sesión para reportar un bloqueo.', color: 'info' })
    abrirLogin()
    return
  }
  modoReporte.value = true
  panelRuta.value = false
  posicionNueva.value = null
}

function cancelarReporte() {
  modoReporte.value = false
  posicionNueva.value = null
}

async function enviarReporte(datos: {
  tipo: TipoBloqueo
  estado: EstadoBloqueo
  inicia_en: string | null
  descripcion: string
  municipio: string
  ruta_alterna_texto: string
  foto: File | null
}) {
  if (!posicionNueva.value) return
  const { foto, ...resto } = datos
  try {
    let foto_url: string | null = null
    if (foto) {
      foto_url = await subirFoto(foto)
      if (!foto_url) toast.add({ title: 'La foto no se pudo subir; se envía sin ella.', color: 'warning' })
    }
    await crearBloqueo({ ...resto, ...posicionNueva.value, foto_url })
    toast.add({ title: 'Reporte enviado. ¡Gracias! 🙌', color: 'success' })
    cancelarReporte()
    estadoTab.value = datos.estado
    await cargar()
  } catch {
    toast.add({ title: 'No se pudo enviar el reporte.', color: 'error' })
  }
}

async function onConfirmar({ id, voto }: { id: string; voto: 'sigue' | 'liberado' }) {
  if (!auth.usuario.value) {
    toast.add({ title: 'Inicia sesión para confirmar reportes.', color: 'info' })
    abrirLogin()
    return
  }
  try {
    await confirmar(id, voto)
    toast.add({
      title: voto === 'sigue' ? 'Confirmado: sigue ahí.' : 'Marcado como liberado.',
      color: voto === 'sigue' ? 'warning' : 'success',
    })
    await cargar()
  } catch {
    toast.add({ title: 'No se pudo registrar tu confirmación.', color: 'error' })
  }
}

function seleccionar(b: Bloqueo) {
  mapaRef.value?.volarA(b.lat, b.lng)
}

function onResultadoRuta(r: ResultadoRuta) {
  resultadoRuta.value = r
}

function cerrarRuta() {
  panelRuta.value = false
  resultadoRuta.value = null
}
</script>

<template>
  <div class="flex h-dvh flex-col bg-crema">
    <MapaBarraMapa
      :conteos="conteos"
      :alertas-activas="alertas.activas.value"
      :alertas-soportado="alertas.soportado.value"
      :usuario="auth.usuario.value"
      @reportar="iniciarReporte"
      @toggle-alertas="activarAlertas"
      @entrar="entrar"
      @salir="auth.salir()"
    />

    <MapaFiltrosEstado v-model="estadoTab" :conteos="conteos" />

    <div class="flex min-h-0 flex-1 overflow-hidden">
      <div class="hidden w-[380px] shrink-0 md:block">
        <MapaPanelReportes
          :bloqueos="bloqueos"
          :cargando="cargando"
          @confirmar="onConfirmar"
          @seleccionar="seleccionar"
          @reportar="iniciarReporte"
        />
      </div>

      <main class="relative min-w-0 flex-1">
        <ClientOnly>
          <MapaBloqueos
            ref="mapaRef"
            :bloqueos="bloqueos"
            :rutas="rutasMapa"
            :modo-reporte="modoReporte"
            @mapa-click="posicionNueva = $event"
            @confirmar="onConfirmar"
            @seleccionar-ruta="rutaActivaId = $event"
          />
          <template #fallback>
            <div class="flex h-full items-center justify-center text-stone-400">Cargando mapa…</div>
          </template>
        </ClientOnly>

        <!-- Buscador de ruta (flotante) -->
        <div class="pointer-events-none absolute inset-x-0 top-3 z-10 px-3">
          <div class="pointer-events-auto mx-auto max-w-md">
            <BuscadorRuta
              v-if="panelRuta"
              v-model:activa="rutaActivaId"
              class="anim-subir"
              @resultado="onResultadoRuta"
              @cerrar="cerrarRuta"
            />
          </div>
        </div>

        <!-- Formulario de reporte (flotante) -->
        <Transition name="slide-up">
          <div v-if="modoReporte" class="pointer-events-none absolute inset-x-0 bottom-0 z-20 p-3">
            <div class="pointer-events-auto mx-auto max-w-md">
              <FormularioReporte :posicion="posicionNueva" @enviar="enviarReporte" @cancelar="cancelarReporte" />
            </div>
          </div>
        </Transition>

        <!-- Botón flotante: ruta -->
        <div v-if="!modoReporte" class="absolute bottom-4 right-4 z-10">
          <UButton
            :icon="panelRuta ? 'i-lucide-x' : 'i-lucide-route'"
            :color="panelRuta ? 'neutral' : 'primary'"
            size="lg"
            class="rounded-full font-semibold shadow-lg"
            @click="panelRuta ? cerrarRuta() : (panelRuta = true)"
          >
            <span class="hidden sm:inline">{{ panelRuta ? 'Cerrar' : '¿Mi ruta está libre?' }}</span>
          </UButton>
        </div>

        <!-- Botón "Ver lista" (solo móvil) -->
        <div v-if="!modoReporte" class="absolute bottom-4 left-4 z-10 md:hidden">
          <UButton
            icon="i-lucide-list"
            color="neutral"
            size="lg"
            class="rounded-full font-semibold shadow-lg"
            @click="listaMovil = true"
          >
            Lista ({{ bloqueos.length }})
          </UButton>
        </div>

        <!-- Panel de reportes como cajón en móvil -->
        <Transition name="slide-up">
          <div v-if="listaMovil" class="absolute inset-0 z-30 flex flex-col bg-crema md:hidden">
            <div class="flex items-center justify-between border-b border-stone-200 px-4 py-3">
              <span class="font-display text-lg font-bold text-stone-800">Reportes</span>
              <UButton icon="i-lucide-x" color="neutral" variant="ghost" @click="listaMovil = false" />
            </div>
            <MapaPanelReportes
              class="min-h-0 flex-1"
              :bloqueos="bloqueos"
              :cargando="cargando"
              @confirmar="onConfirmar"
              @seleccionar="(b) => { seleccionar(b); listaMovil = false }"
              @reportar="() => { listaMovil = false; iniciarReporte() }"
            />
          </div>
        </Transition>
      </main>
    </div>
  </div>
</template>

<style scoped>
.slide-up-enter-active,
.slide-up-leave-active {
  transition: transform 0.25s ease, opacity 0.25s ease;
}
.slide-up-enter-from,
.slide-up-leave-to {
  transform: translateY(20px);
  opacity: 0;
}
</style>
