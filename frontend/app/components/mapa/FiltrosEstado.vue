<script setup lang="ts">
import type { EstadoBloqueo } from '~/types/bloqueo'

defineProps<{ conteos?: { activos: number; programados: number; finalizados: number } }>()
const modelo = defineModel<EstadoBloqueo>({ required: true })

const tabs: { valor: EstadoBloqueo; etiqueta: string; clave: 'activos' | 'programados' | 'finalizados' }[] = [
  { valor: 'activo', etiqueta: 'Activos', clave: 'activos' },
  { valor: 'programado', etiqueta: 'Programados', clave: 'programados' },
  { valor: 'finalizado', etiqueta: 'Finalizados', clave: 'finalizados' },
]
</script>

<template>
  <div class="flex flex-wrap items-center gap-2 border-b border-stone-200 bg-crema-suave px-4 py-2.5">
    <div class="flex gap-1.5">
      <button
        v-for="t in tabs"
        :key="t.valor"
        class="flex items-center gap-1.5 rounded-full px-3.5 py-1.5 text-sm font-semibold transition"
        :class="modelo === t.valor
          ? 'bg-terracota-600 text-white shadow-sm'
          : 'bg-white text-stone-600 ring-1 ring-stone-200 hover:bg-stone-50'"
        @click="modelo = t.valor"
      >
        {{ t.etiqueta }}
        <span
          v-if="conteos"
          class="rounded-full px-1.5 text-xs"
          :class="modelo === t.valor ? 'bg-white/20' : 'bg-stone-100 text-stone-500'"
        >{{ conteos[t.clave] }}</span>
      </button>
    </div>

    <div class="ml-auto flex items-center gap-2 text-sm text-stone-500">
      <UIcon name="i-lucide-map-pinned" />
      <span class="rounded-lg bg-white px-3 py-1.5 ring-1 ring-stone-200">Todo el Istmo</span>
    </div>
  </div>
</template>
