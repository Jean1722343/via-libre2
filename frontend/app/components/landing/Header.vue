<script setup lang="ts">
const auth = useAuth()
const { abrir } = useLoginModal()

const enlaces = [
  { texto: 'El problema', href: '#problema' },
  { texto: 'Cómo funciona', href: '#como-funciona' },
  { texto: 'Confianza', href: '#confianza' },
]
</script>

<template>
  <header class="sticky top-0 z-30 border-b border-stone-200/70 bg-crema/85 backdrop-blur">
    <div class="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
      <NuxtLink to="/" class="flex items-center gap-2">
        <span class="flex size-8 items-center justify-center rounded-lg bg-terracota-600 text-white shadow-sm">
          <UIcon name="i-lucide-triangle-alert" class="text-lg" />
        </span>
        <span class="font-display text-xl font-bold text-pino-950">Vía Libre</span>
      </NuxtLink>

      <nav class="hidden items-center gap-7 md:flex">
        <a
          v-for="e in enlaces"
          :key="e.href"
          :href="e.href"
          class="text-sm font-medium text-stone-600 transition hover:text-terracota-700"
        >
          {{ e.texto }}
        </a>
      </nav>

      <div class="flex items-center gap-2">
        <UButton
          v-if="auth.usuario.value"
          to="/mapa"
          variant="ghost"
          color="neutral"
          class="hidden gap-2 sm:inline-flex"
        >
          <UAvatar :src="auth.usuario.value.foto || undefined" :alt="auth.usuario.value.nombre" size="2xs" />
          <span class="max-w-24 truncate">{{ auth.usuario.value.nombre }}</span>
        </UButton>
        <UButton
          v-else
          variant="ghost"
          color="neutral"
          class="hidden sm:inline-flex"
          @click="abrir()"
        >
          Entrar
        </UButton>
        <UButton to="/mapa" color="primary" icon="i-lucide-map" class="rounded-full font-semibold">
          Abrir mapa
        </UButton>
      </div>
    </div>
  </header>
</template>
