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
  <div class="glass flex items-center gap-1 rounded-full p-1">
    <button
      v-for="t in tabs"
      :key="t.valor"
      class="flex flex-1 items-center justify-center gap-1.5 rounded-full px-3 py-1.5 text-sm font-semibold transition"
      :class="modelo === t.valor
        ? 'bg-terracota-600 text-white shadow-sm'
        : 'text-stone-600 hover:bg-white/60'"
      @click="modelo = t.valor"
    >
      {{ t.etiqueta }}
      <span
        v-if="conteos"
        class="rounded-full px-1.5 text-xs"
        :class="modelo === t.valor ? 'bg-white/25' : 'bg-stone-500/10 text-stone-500'"
      >{{ conteos[t.clave] }}</span>
    </button>
  </div>
</template>
