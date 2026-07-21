<script setup lang="ts">
import type { EstadoBloqueo, TipoBloqueo } from '~/types/bloqueo'
import { TIPOS_META } from '~/types/bloqueo'

const props = defineProps<{
  posicion: { lat: number; lng: number } | null
}>()

const emit = defineEmits<{
  (e: 'enviar', datos: {
    tipo: TipoBloqueo
    estado: EstadoBloqueo
    inicia_en: string | null
    descripcion: string
    municipio: string
    ruta_alterna_texto: string
    foto: File | null
  }): void
  (e: 'cancelar'): void
}>()

const auth = useAuth()

const tipos = Object.entries(TIPOS_META).map(([valor, meta]) => ({
  value: valor as TipoBloqueo,
  label: meta.etiqueta,
  icon: meta.icono,
}))

// Un noticiero/admin publica verificado; un usuario normal queda "por verificar".
const publicaVerificado = computed(() => auth.esNoticiero.value)

const tipo = ref<TipoBloqueo>('manifestacion')
const estado = ref<'activo' | 'programado'>('activo')
const iniciaEn = ref('')
const municipio = ref('')
const descripcion = ref('')
const rutaAlterna = ref('')
const foto = ref<File | null>(null)
const fotoPreview = ref<string | null>(null)

const puedeEnviar = computed(() =>
  Boolean(props.posicion) && (estado.value === 'activo' || Boolean(iniciaEn.value)),
)

function onFoto(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0] ?? null
  foto.value = file
  fotoPreview.value = file ? URL.createObjectURL(file) : null
}

function quitarFoto() {
  foto.value = null
  fotoPreview.value = null
}

function enviar() {
  if (!puedeEnviar.value) return
  emit('enviar', {
    tipo: tipo.value,
    estado: estado.value,
    inicia_en: estado.value === 'programado' && iniciaEn.value ? new Date(iniciaEn.value).toISOString() : null,
    descripcion: descripcion.value,
    municipio: municipio.value,
    ruta_alterna_texto: rutaAlterna.value,
    foto: foto.value,
  })
  municipio.value = ''
  descripcion.value = ''
  rutaAlterna.value = ''
  iniciaEn.value = ''
  estado.value = 'activo'
  quitarFoto()
}
</script>

<template>
  <UCard class="rounded-2xl shadow-2xl ring-1 ring-black/5">
    <template #header>
      <div class="flex items-center justify-between">
        <h3 class="font-display text-xl font-bold text-stone-800">Reportar incidente</h3>
        <UButton icon="i-lucide-x" color="neutral" variant="ghost" size="xs" @click="emit('cancelar')" />
      </div>
    </template>

    <div class="space-y-4">
      <UAlert
        v-if="!posicion"
        icon="i-lucide-map-pin"
        color="primary"
        variant="soft"
        title="Toca el mapa"
        description="Marca dónde está el bloqueo."
      />
      <UAlert
        v-else
        icon="i-lucide-check"
        color="success"
        variant="soft"
        :title="`Ubicación: ${posicion.lat.toFixed(4)}, ${posicion.lng.toFixed(4)}`"
        description="Puedes arrastrar el pin para ajustar."
      />

      <!-- Estado: activo ahora vs programado -->
      <div class="grid grid-cols-2 gap-2">
        <button
          type="button"
          class="rounded-xl border px-3 py-2 text-sm font-semibold transition"
          :class="estado === 'activo' ? 'border-terracota-500 bg-terracota-50 text-terracota-700' : 'border-stone-200 text-stone-500 hover:bg-stone-50'"
          @click="estado = 'activo'"
        >
          Activo ahora
        </button>
        <button
          type="button"
          class="rounded-xl border px-3 py-2 text-sm font-semibold transition"
          :class="estado === 'programado' ? 'border-ambar-500 bg-ambar-50 text-ambar-700' : 'border-stone-200 text-stone-500 hover:bg-stone-50'"
          @click="estado = 'programado'"
        >
          Programado
        </button>
      </div>

      <UFormField v-if="estado === 'programado'" label="¿Cuándo inicia?">
        <UInput v-model="iniciaEn" type="datetime-local" class="w-full" />
      </UFormField>

      <UFormField label="Tipo de bloqueo">
        <USelect v-model="tipo" :items="tipos" class="w-full" />
      </UFormField>

      <UFormField label="Municipio (opcional)">
        <UInput v-model="municipio" placeholder="Ej: Juchitán de Zaragoza" class="w-full" />
      </UFormField>

      <UFormField label="Descripción (opcional)">
        <UTextarea v-model="descripcion" :rows="2" placeholder="¿Qué está pasando?" class="w-full" />
      </UFormField>

      <UFormField label="Ruta alterna (opcional)">
        <UInput v-model="rutaAlterna" placeholder="Ej: Toma el libramiento sur" class="w-full" />
      </UFormField>

      <div
        class="flex items-start gap-2 rounded-xl px-3 py-2 text-xs"
        :class="publicaVerificado ? 'bg-pino-50 text-pino-800' : 'bg-ambar-50 text-ambar-800'"
      >
        <UIcon :name="publicaVerificado ? 'i-lucide-badge-check' : 'i-lucide-users'" class="mt-0.5 shrink-0" />
        <span v-if="publicaVerificado">Se publica <b>verificado</b> al instante (tu rol lo permite).</span>
        <span v-else>Se publicará como <b>“por verificar”</b> hasta que la comunidad lo confirme.</span>
      </div>

      <UFormField label="Foto (opcional)">
        <div v-if="!fotoPreview">
          <label class="flex cursor-pointer items-center justify-center gap-2 rounded-xl border border-dashed border-stone-300 px-3 py-3 text-sm text-stone-500 hover:bg-stone-50">
            <UIcon name="i-lucide-camera" />
            Adjuntar foto
            <input type="file" accept="image/*" class="hidden" @change="onFoto">
          </label>
        </div>
        <div v-else class="relative">
          <img :src="fotoPreview" alt="Vista previa" class="h-32 w-full rounded-xl object-cover">
          <UButton icon="i-lucide-x" color="neutral" size="xs" class="absolute right-1 top-1" @click="quitarFoto" />
        </div>
      </UFormField>
    </div>

    <template #footer>
      <div class="flex gap-2">
        <UButton color="neutral" variant="soft" class="flex-1 justify-center rounded-lg" @click="emit('cancelar')">
          Cancelar
        </UButton>
        <UButton
          color="primary"
          class="flex-1 justify-center rounded-lg font-semibold"
          :disabled="!puedeEnviar"
          icon="i-lucide-send"
          @click="enviar"
        >
          Reportar
        </UButton>
      </div>
    </template>
  </UCard>
</template>
