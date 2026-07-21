<script setup lang="ts">
import type { Bloqueo, Rol } from '~/types/bloqueo'
import { TIPOS_META, ESTADOS_META, ROLES_META } from '~/types/bloqueo'
import { hace } from '~/utils/tiempo'

const props = defineProps<{ bloqueo: Bloqueo }>()

const emit = defineEmits<{
  (e: 'confirmar', datos: { id: string; voto: 'sigue' | 'liberado' }): void
  (e: 'seleccionar', b: Bloqueo): void
}>()

const meta = computed(() => TIPOS_META[props.bloqueo.tipo] ?? TIPOS_META.otro)
const estadoMeta = computed(() => ESTADOS_META[props.bloqueo.estado] ?? ESTADOS_META.activo)

// Hora de inicio "INICIA 14:00" para los programados.
const inicia = computed(() => {
  if (props.bloqueo.estado !== 'programado' || !props.bloqueo.inicia_en) return null
  return new Date(props.bloqueo.inicia_en).toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' })
})

const titulo = computed(() => props.bloqueo.municipio || meta.value.etiqueta)
const enCurso = computed(() => props.bloqueo.estado !== 'finalizado')
const verificado = computed(() => props.bloqueo.verificado !== false)
const rolMeta = computed(() => (props.bloqueo.autor_rol ? ROLES_META[props.bloqueo.autor_rol as Rol] : null))
</script>

<template>
  <article
    class="hover-lift cursor-pointer rounded-2xl border border-stone-200 bg-white p-4 shadow-sm transition hover:border-terracota-300"
    :style="{ borderLeft: `4px solid ${estadoMeta.color}` }"
    @click="emit('seleccionar', bloqueo)"
  >
    <div class="flex items-start justify-between gap-2">
      <span class="text-[11px] font-bold uppercase tracking-wide text-stone-400">
        {{ meta.etiqueta }}
      </span>
      <span
        v-if="inicia"
        class="shrink-0 rounded-full bg-ambar-100 px-2 py-0.5 text-[11px] font-bold uppercase text-ambar-700"
      >
        Inicia {{ inicia }}
      </span>
      <span
        v-else
        class="shrink-0 rounded-full px-2 py-0.5 text-[11px] font-bold uppercase"
        :style="{ background: estadoMeta.color + '1a', color: estadoMeta.color }"
      >
        {{ estadoMeta.etiqueta }}
      </span>
    </div>

    <div class="mt-1.5 flex items-center gap-2">
      <h3 class="text-lg font-bold leading-tight text-stone-800">{{ titulo }}</h3>
      <span
        v-if="verificado"
        class="inline-flex items-center gap-0.5 rounded-full bg-pino-100 px-1.5 py-0.5 text-[10px] font-bold uppercase text-pino-700"
      >
        <UIcon name="i-lucide-badge-check" /> Verificado
      </span>
      <span
        v-else
        class="inline-flex items-center gap-0.5 rounded-full bg-ambar-100 px-1.5 py-0.5 text-[10px] font-bold uppercase text-ambar-700"
      >
        Por verificar
      </span>
    </div>
    <p v-if="bloqueo.descripcion" class="mt-1 text-sm leading-snug text-stone-500">{{ bloqueo.descripcion }}</p>

    <div class="mt-2 flex items-center gap-3 text-xs text-stone-400">
      <span class="flex items-center gap-1"><UIcon :name="meta.icono" /> {{ meta.etiqueta }}</span>
      <span class="flex items-center gap-1"><UIcon name="i-lucide-users" /> {{ bloqueo.confirmaciones_sigue }}</span>
      <span class="ml-auto">{{ hace(bloqueo.creado_en) }}</span>
    </div>

    <div v-if="bloqueo.autor_nombre" class="mt-2 flex items-center gap-1.5 text-xs text-stone-400">
      <UAvatar v-if="bloqueo.autor_foto" :src="bloqueo.autor_foto" size="3xs" />
      <UIcon v-else name="i-lucide-user" />
      Reportado por {{ bloqueo.autor_nombre }}
      <span
        v-if="rolMeta"
        class="rounded-full px-1.5 py-0.5 text-[9px] font-bold uppercase"
        :style="{ background: rolMeta.color + '1a', color: rolMeta.color }"
      >{{ rolMeta.etiqueta }}</span>
    </div>

    <div
      v-if="bloqueo.ruta_alterna_texto"
      class="mt-2 flex items-start gap-1.5 rounded-lg bg-terracota-50 px-2.5 py-1.5 text-xs text-terracota-800"
    >
      <UIcon name="i-lucide-corner-up-right" class="mt-0.5 shrink-0" />
      <span><span class="font-semibold">Ruta alterna:</span> {{ bloqueo.ruta_alterna_texto }}</span>
    </div>

    <div v-if="enCurso" class="mt-3 flex gap-2" @click.stop>
      <UButton
        color="success"
        size="sm"
        icon="i-lucide-circle-check"
        class="flex-1 justify-center rounded-lg font-semibold"
        @click="emit('confirmar', { id: bloqueo.id, voto: 'sigue' })"
      >
        {{ verificado ? 'Sigue así' : 'Confirmar' }}
      </UButton>
      <UButton
        color="neutral"
        variant="outline"
        size="sm"
        icon="i-lucide-circle-x"
        class="flex-1 justify-center rounded-lg"
        @click="emit('confirmar', { id: bloqueo.id, voto: 'liberado' })"
      >
        Ya no está
      </UButton>
    </div>
  </article>
</template>
