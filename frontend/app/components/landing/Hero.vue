<script setup lang="ts">
const { resumen, configurada } = useApi()

const conteos = ref({ activos: 0, programados: 0, finalizados: 0 })

onMounted(async () => {
  if (!configurada.value) return
  try {
    conteos.value = await resumen()
  } catch {
    // silencioso: los contadores quedan en 0
  }
})
</script>

<template>
  <section class="mx-auto grid max-w-6xl items-center gap-10 px-4 py-14 sm:px-6 lg:grid-cols-2 lg:py-20">
    <!-- Columna izquierda -->
    <div>
      <span
        class="anim-subir inline-flex items-center gap-2 rounded-full border border-terracota-200 bg-terracota-50 px-3 py-1 text-sm font-medium text-terracota-800"
      >
        <span class="size-2 animate-pulse rounded-full bg-terracota-600" />
        {{ conteos.activos }} bloqueos activos ahora en el Istmo
      </span>

      <h1 class="font-display anim-subir mt-5 text-5xl font-extrabold leading-[1.05] text-stone-800 sm:text-6xl" style="animation-delay: 0.08s">
        Antes de salir,<br>
        échale un ojo a <span class="text-terracota-600">ViaLibre</span>.
      </h1>

      <p class="anim-subir mt-5 max-w-md text-lg leading-relaxed text-stone-600" style="animation-delay: 0.16s">
        Mira los bloqueos, marchas, obras y cierres del Istmo de Tehuantepec en
        tiempo real, encuentra rutas alternas y recibe un aviso cuando algo cambia.
        Hecho por la comunidad, para la comunidad.
      </p>

      <div class="anim-subir mt-7 flex flex-wrap gap-3" style="animation-delay: 0.24s">
        <UButton to="/mapa" size="xl" color="primary" icon="i-lucide-map-pin" class="press rounded-full font-semibold shadow-lg shadow-terracota-600/25">
          Ver bloqueos ahora
        </UButton>
        <UButton
          to="/mapa?reportar=1"
          size="xl"
          color="neutral"
          variant="outline"
          icon="i-lucide-megaphone"
          class="press rounded-full font-semibold"
        >
          Reportar un bloqueo
        </UButton>
      </div>

      <div class="mt-8 flex flex-wrap gap-x-6 gap-y-2 text-sm text-stone-500">
        <span class="flex items-center gap-2"><span class="size-2.5 rounded-full bg-terracota-600" /> {{ conteos.activos }} activos ahora</span>
        <span class="flex items-center gap-2"><span class="size-2.5 rounded-full bg-ambar-500" /> {{ conteos.programados }} programados</span>
        <span class="flex items-center gap-2"><span class="size-2.5 rounded-full bg-pino-600" /> actualizado en tiempo real</span>
      </div>

      <p class="mt-4 text-sm text-stone-500">
        Gratis, sin cuenta obligatoria. También puedes
        <NuxtLink to="/mapa?reportar=1" class="font-medium text-terracota-700 underline underline-offset-2">reportar sin registrarte</NuxtLink>.
      </p>
    </div>

    <!-- Columna derecha: preview del mapa -->
    <div class="relative">
      <!-- Glow decorativo -->
      <div class="absolute -inset-6 -z-10 rounded-full bg-terracota-300/30 blur-3xl" />
      <div class="flotante-suave hover-lift relative overflow-hidden rounded-3xl border border-stone-200 bg-white shadow-2xl">
        <div class="chrome-ventana relative flex h-9 items-center justify-center border-b border-stone-100 bg-stone-50 text-xs text-stone-400">
          vialibre.mx / mapa
        </div>

        <!-- Mapa abstracto -->
        <div class="relative h-80 bg-[#eaf0e6]">
          <svg class="absolute inset-0 size-full" viewBox="0 0 400 320" fill="none" preserveAspectRatio="xMidYMid slice">
            <rect width="400" height="320" fill="#e9efe4" />
            <path d="M-20 80 C120 40 200 160 440 90" stroke="#cdd8c4" stroke-width="14" fill="none" />
            <path d="M40 -20 C80 140 60 220 120 360" stroke="#cdd8c4" stroke-width="12" fill="none" />
            <path d="M-20 240 C140 210 260 260 440 220" stroke="#d8cfc0" stroke-width="10" fill="none" />
            <path d="M60 60 C180 120 220 180 360 300" stroke="#2f5d4c" stroke-width="4" stroke-dasharray="3 6" fill="none" opacity="0.7" />
          </svg>

          <!-- Marcadores -->
          <span class="absolute left-[26%] top-[33%] flex size-7 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full border-2 border-white bg-terracota-600 text-white shadow-md">
            <UIcon name="i-lucide-octagon-x" class="text-sm" />
          </span>
          <span class="absolute left-[62%] top-[28%] flex size-7 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full border-2 border-white bg-ambar-500 text-white shadow-md">
            <UIcon name="i-lucide-clock" class="text-sm" />
          </span>
          <span class="absolute left-[44%] top-[62%] flex size-7 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full border-2 border-white bg-pino-600 text-white shadow-md">
            <UIcon name="i-lucide-check" class="text-sm" />
          </span>
        </div>

        <!-- Caption flotante -->
        <div class="absolute bottom-4 left-4 right-4 rounded-xl border border-stone-100 bg-white/95 p-3 shadow-lg backdrop-blur">
          <div class="flex items-center justify-between">
            <p class="text-sm font-semibold text-stone-800">
              <span class="mr-1 inline-block size-2 rounded-full bg-terracota-600 align-middle" />
              Bloqueo magisterial — Juchitán
            </p>
            <span class="text-xs text-stone-400">14 confirman</span>
          </div>
          <p class="mt-1 text-xs text-stone-500">Ruta alterna: La Ventosa → Ixtepec.</p>
        </div>
      </div>
    </div>
  </section>
</template>
