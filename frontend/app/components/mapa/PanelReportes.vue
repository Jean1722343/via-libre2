<script setup lang="ts">
import type { Bloqueo } from '~/types/bloqueo'

defineProps<{ bloqueos: Bloqueo[]; cargando?: boolean }>()

const emit = defineEmits<{
  (e: 'confirmar', datos: { id: string; voto: 'sigue' | 'liberado' }): void
  (e: 'seleccionar', b: Bloqueo): void
  (e: 'reportar'): void
}>()
</script>

<template>
  <aside class="flex h-full w-full flex-col border-r border-stone-200 bg-crema">
    <div class="flex items-center justify-between px-4 pb-2 pt-4">
      <div>
        <h2 class="font-display text-2xl font-bold text-stone-800">Reportes recientes</h2>
        <p class="text-sm text-stone-500">{{ bloqueos.length }} resultado{{ bloqueos.length === 1 ? '' : 's' }}</p>
      </div>
      <UButton color="primary" size="sm" icon="i-lucide-plus" class="rounded-full font-semibold" @click="emit('reportar')">
        Reportar
      </UButton>
    </div>

    <div class="flex-1 space-y-3 overflow-y-auto px-4 pb-4 pt-1">
      <div v-if="cargando" class="space-y-3">
        <div v-for="i in 3" :key="i" class="h-28 animate-pulse rounded-2xl bg-stone-200/60" />
      </div>

      <div v-else-if="bloqueos.length === 0" class="mt-10 text-center text-stone-400">
        <UIcon name="i-lucide-map-pin-off" class="text-3xl" />
        <p class="mt-2 text-sm">No hay reportes en esta pestaña.</p>
      </div>

      <MapaTarjetaReporte
        v-for="b in bloqueos"
        :key="b.id"
        :bloqueo="b"
        @confirmar="emit('confirmar', $event)"
        @seleccionar="emit('seleccionar', $event)"
      />
    </div>
  </aside>
</template>
