<script setup lang="ts">
import type { Usuario } from '~/composables/useAuth'
import { ROLES_META, type Rol } from '~/types/bloqueo'

const props = defineProps<{
  conteos: { activos: number; programados: number; finalizados: number }
  alertasActivas: boolean
  alertasSoportado: boolean
  usuario: Usuario | null
}>()

const emit = defineEmits<{
  (e: 'reportar'): void
  (e: 'toggle-alertas'): void
  (e: 'entrar'): void
  (e: 'salir'): void
}>()

const rolMeta = computed(() => (props.usuario ? ROLES_META[(props.usuario.rol as Rol)] ?? ROLES_META.usuario : null))
const esAdmin = computed(() => props.usuario?.rol === 'admin')

const menu = computed(() => [
  [{ label: props.usuario?.email ?? '', type: 'label' as const }],
  ...(esAdmin.value ? [[{ label: 'Panel de administración', icon: 'i-lucide-shield', to: '/admin' }]] : []),
  [{ label: 'Cerrar sesión', icon: 'i-lucide-log-out', onSelect: () => emit('salir') }],
])
</script>

<template>
  <header class="glass flex h-14 items-center gap-2 rounded-full px-2.5 sm:gap-3 sm:px-3">
    <NuxtLink to="/" class="flex items-center gap-2">
      <UButton icon="i-lucide-arrow-left" color="neutral" variant="ghost" size="sm" square />
      <span class="flex size-8 items-center justify-center rounded-xl bg-terracota-600 text-white shadow-sm">
        <UIcon name="i-lucide-triangle-alert" />
      </span>
      <span class="font-display hidden text-lg font-bold text-pino-800 sm:inline">Vía Libre</span>
    </NuxtLink>

    <span class="ml-1 flex items-center gap-1.5 rounded-full bg-terracota-600 px-2.5 py-1 text-xs font-bold text-white">
      <span class="size-1.5 animate-pulse rounded-full bg-white" /> {{ conteos.activos }} activos
    </span>

    <div class="ml-auto flex items-center gap-1 sm:gap-2">
      <UButton
        :icon="alertasActivas ? 'i-lucide-bell-ring' : 'i-lucide-bell'"
        :color="alertasActivas ? 'primary' : 'neutral'"
        variant="ghost"
        size="sm"
        square
        :disabled="!alertasSoportado"
        @click="emit('toggle-alertas')"
      />

      <UDropdownMenu v-if="usuario" :items="menu" :content="{ align: 'end' }">
        <UButton color="neutral" variant="ghost" size="sm" class="gap-2">
          <UAvatar :src="usuario.foto || undefined" :alt="usuario.nombre" size="2xs" />
          <span class="hidden max-w-24 truncate text-left sm:inline">{{ usuario.nombre }}</span>
          <span
            v-if="rolMeta"
            class="hidden rounded-full px-1.5 py-0.5 text-[10px] font-bold uppercase md:inline"
            :style="{ background: rolMeta.color + '1a', color: rolMeta.color }"
          >{{ rolMeta.etiqueta }}</span>
          <UIcon name="i-lucide-chevron-down" class="text-stone-400" />
        </UButton>
      </UDropdownMenu>
      <UButton
        v-else
        icon="i-lucide-log-in"
        color="neutral"
        variant="ghost"
        size="sm"
        class="font-semibold"
        @click="emit('entrar')"
      >
        <span class="hidden sm:inline">Entrar</span>
      </UButton>

      <UButton color="primary" icon="i-lucide-megaphone" class="rounded-full font-semibold" @click="emit('reportar')">
        <span class="hidden sm:inline">Reportar incidente</span>
        <span class="sm:hidden">Reportar</span>
      </UButton>
    </div>
  </header>
</template>
