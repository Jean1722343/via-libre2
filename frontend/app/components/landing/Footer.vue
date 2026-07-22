<template>
  <footer class="border-t border-stone-200 bg-crema-suave">
    <div class="mx-auto flex max-w-6xl flex-col items-start justify-between gap-6 px-4 py-10 sm:flex-row sm:px-6">
      <div>
        <div class="flex items-center gap-2">
          <span class="flex size-7 items-center justify-center rounded-lg bg-terracota-600 text-white">
            <UIcon name="i-lucide-triangle-alert" />
          </span>
          <span class="font-display text-lg font-bold text-stone-800">Vía Libre</span>
        </div>
        <p class="mt-2 max-w-xs text-sm text-stone-500">
          Alertas comunitarias de bloqueos carreteros en el Istmo de Tehuantepec, Oaxaca.
        </p>
      </div>

      <div class="flex gap-12 text-sm">
        <div class="space-y-2">
          <p class="font-semibold text-stone-700">Producto</p>
          <NuxtLink to="/mapa" class="block text-stone-500 hover:text-terracota-700">Ver mapa</NuxtLink>
          <NuxtLink to="/mapa?reportar=1" class="block text-stone-500 hover:text-terracota-700">Reportar</NuxtLink>
        </div>
        <div class="space-y-2">
          <p class="font-semibold text-stone-700">Comunidad</p>
          <a href="#confianza" class="block text-stone-500 hover:text-terracota-700">Confianza</a>
          <a href="#como-funciona" class="block text-stone-500 hover:text-terracota-700">Cómo funciona</a>
        </div>
      </div>
    </div>
    <div class="border-t border-stone-200 py-4 text-center text-xs text-stone-400">
      Hecho en Oaxaca, para Oaxaca · Hackaton Kiro 2026
    </div>
  </footer>
</template>
