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

const stats = computed(() => [
  { valor: conteos.value.activos, etiqueta: 'Bloqueos activos', color: '#bf5b34' },
  { valor: conteos.value.programados, etiqueta: 'Programados', color: '#e0982f' },
  { valor: '24/7', etiqueta: 'En tiempo real', color: '#2f5d4c' },
])
</script>

<template>
  <section class="relative overflow-hidden pb-20 pt-8 sm:pt-12">
    <!-- Fondo: brillos cálidos + textura de puntos -->
    <div class="pointer-events-none absolute inset-0 -z-10">
      <div class="absolute -left-32 -top-32 size-[34rem] rounded-full bg-terracota-300/30 blur-3xl" />
      <div class="absolute -right-24 top-32 size-[28rem] rounded-full bg-pino-300/25 blur-3xl" />
      <div class="absolute bottom-0 left-1/3 size-[24rem] rounded-full bg-ambar-200/30 blur-3xl" />
      <div class="malla-puntos absolute inset-0" />
    </div>

    <div class="mx-auto grid max-w-6xl items-center gap-12 px-4 sm:px-6 lg:grid-cols-[1.05fr_0.95fr] lg:gap-8 lg:py-14">
      <!-- Columna izquierda -->
      <div class="relative z-10">
        <span class="anim-subir inline-flex items-center gap-2 rounded-full border border-terracota-200 bg-white/70 px-3.5 py-1.5 text-sm font-semibold text-terracota-800 shadow-sm backdrop-blur">
          <span class="relative flex size-2.5">
            <span class="absolute inline-flex size-full animate-ping rounded-full bg-terracota-500 opacity-75" />
            <span class="relative inline-flex size-2.5 rounded-full bg-terracota-600" />
          </span>
          {{ conteos.activos }} bloqueos activos ahora en el Istmo
        </span>

        <h1 class="font-display anim-subir mt-6 text-[2.75rem] font-black leading-[1.02] text-pino-950 sm:text-6xl" style="animation-delay: 0.08s">
          No te quedes<br>
          <span class="relative inline-block">
            <span class="relative z-10 text-terracota-600">varado.</span>
            <span class="absolute inset-x-0 bottom-1.5 -z-0 h-3.5 -rotate-1 bg-ambar-300/60" />
          </span>
          <span class="block">Sal informado.</span>
        </h1>

        <p class="anim-subir mt-6 max-w-md text-lg leading-relaxed text-stone-600" style="animation-delay: 0.16s">
          Bloqueos, marchas, obras y cierres del Istmo de Tehuantepec
          <span class="font-semibold text-stone-800">en tiempo real</span>. Mira si tu ruta está
          libre, encuentra alternas y recibe aviso cuando algo cambia. Hecho por la comunidad.
        </p>

        <div class="anim-subir mt-8 flex flex-wrap gap-3" style="animation-delay: 0.24s">
          <UButton to="/mapa" size="xl" color="primary" icon="i-lucide-map-pin" class="press rounded-full px-6 font-semibold shadow-xl shadow-terracota-600/30">
            Ver el mapa en vivo
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

        <!-- Tarjetas de stats en vivo -->
        <div class="anim-subir mt-10 grid max-w-md grid-cols-3 gap-3" style="animation-delay: 0.32s">
          <div
            v-for="s in stats"
            :key="s.etiqueta"
            class="rounded-2xl border border-white/60 bg-white/70 p-3.5 shadow-sm backdrop-blur"
          >
            <p class="font-display text-3xl font-black leading-none" :style="{ color: s.color }">{{ s.valor }}</p>
            <p class="mt-1.5 text-xs font-medium leading-tight text-stone-500">{{ s.etiqueta }}</p>
          </div>
        </div>
      </div>

      <!-- Columna derecha: preview del mapa en vivo -->
      <div class="relative">
        <!-- Glow -->
        <div class="absolute -inset-8 -z-10 rounded-full bg-terracota-400/20 blur-3xl" />

        <div class="flotante-suave relative overflow-hidden rounded-[28px] border border-white/70 bg-white shadow-2xl ring-1 ring-black/5">
          <!-- Barra de app -->
          <div class="flex items-center gap-2 border-b border-stone-100 bg-crema-suave/80 px-4 py-3 backdrop-blur">
            <span class="flex size-7 items-center justify-center rounded-lg bg-terracota-600 text-white shadow-sm">
              <UIcon name="i-lucide-triangle-alert" class="text-sm" />
            </span>
            <span class="font-display text-base font-bold text-pino-900">Vía Libre</span>
            <span class="ml-auto flex items-center gap-1.5 rounded-full bg-terracota-600 px-2.5 py-1 text-xs font-bold text-white">
              <span class="size-1.5 animate-pulse rounded-full bg-white" /> En vivo
            </span>
          </div>

          <!-- Lienzo del mapa -->
          <div class="relative h-[22rem]">
            <svg class="absolute inset-0 size-full" viewBox="0 0 420 352" preserveAspectRatio="xMidYMid slice">
              <rect width="420" height="352" fill="#eaf0e4" />
              <!-- terreno -->
              <path d="M-20 250 C120 210 240 300 460 240 L460 360 L-20 360 Z" fill="#dfe8d6" />
              <path d="M-20 90 C120 60 220 150 460 80 L460 -20 L-20 -20 Z" fill="#eef2e8" />
              <!-- calles -->
              <path d="M-20 120 C120 90 220 170 460 110" stroke="#cdd8c0" stroke-width="16" fill="none" />
              <path d="M60 -20 C100 140 70 230 130 380" stroke="#cdd8c0" stroke-width="12" fill="none" />
              <path d="M-20 270 C150 240 280 290 460 250" stroke="#d8cfbf" stroke-width="10" fill="none" />
              <!-- ruta activa animada -->
              <path
                d="M70 300 C150 250 180 190 250 170 C320 150 340 90 380 60"
                stroke="#bf5b34" stroke-width="5" fill="none" stroke-linecap="round"
                stroke-dasharray="10 10" class="ruta-anim"
              />
            </svg>

            <!-- Pines tipo gota (mismos que el mapa real) -->
            <span class="absolute left-[24%] top-[38%] -translate-x-1/2 -translate-y-full drop-shadow-lg">
              <svg width="30" height="39" viewBox="0 0 34 44" fill="none">
                <path d="M17 42.5 C17 42.5 4.5 26 4.5 15.5 A12.5 12.5 0 1 1 29.5 15.5 C29.5 26 17 42.5 17 42.5 Z" fill="#bf5b34" stroke="#fff" stroke-width="2.5" stroke-linejoin="round" />
                <text x="17" y="21" text-anchor="middle" font-size="15" font-weight="800" fill="#fff" font-family="system-ui">!</text>
              </svg>
            </span>
            <span class="absolute left-[62%] top-[26%] -translate-x-1/2 -translate-y-full drop-shadow-lg">
              <svg width="28" height="36" viewBox="0 0 34 44" fill="none">
                <path d="M17 42.5 C17 42.5 4.5 26 4.5 15.5 A12.5 12.5 0 1 1 29.5 15.5 C29.5 26 17 42.5 17 42.5 Z" fill="#e0982f" stroke="#fff" stroke-width="2.5" stroke-linejoin="round" />
                <text x="17" y="21" text-anchor="middle" font-size="14" font-weight="800" fill="#fff" font-family="system-ui">⏱</text>
              </svg>
            </span>
            <span class="absolute left-[46%] top-[66%] -translate-x-1/2 -translate-y-full drop-shadow-lg">
              <svg width="28" height="36" viewBox="0 0 34 44" fill="none">
                <path d="M17 42.5 C17 42.5 4.5 26 4.5 15.5 A12.5 12.5 0 1 1 29.5 15.5 C29.5 26 17 42.5 17 42.5 Z" fill="#2f5d4c" stroke="#fff" stroke-width="2.5" stroke-linejoin="round" />
                <text x="17" y="21" text-anchor="middle" font-size="14" font-weight="800" fill="#fff" font-family="system-ui">✓</text>
              </svg>
            </span>

            <!-- Chip glass flotante: ruta -->
            <div class="absolute right-3 top-3 flex items-center gap-2 rounded-2xl border border-white/60 bg-white/80 px-3 py-2 shadow-lg backdrop-blur">
              <span class="flex size-8 items-center justify-center rounded-xl bg-pino-100 text-pino-700">
                <UIcon name="i-lucide-route" class="text-base" />
              </span>
              <div class="leading-tight">
                <p class="text-[11px] font-bold text-pino-700">Ruta alterna lista</p>
                <p class="text-[10px] text-stone-500">evita 1 bloqueo · +6 min</p>
              </div>
            </div>
          </div>

          <!-- Tarjeta inferior -->
          <div class="absolute inset-x-4 bottom-4 rounded-2xl border border-white/60 bg-white/90 p-3.5 shadow-xl backdrop-blur">
            <div class="flex items-center justify-between">
              <p class="text-sm font-bold text-stone-800">
                <span class="mr-1.5 inline-block size-2 rounded-full bg-terracota-600 align-middle" />
                Bloqueo magisterial — Juchitán
              </p>
              <span class="flex items-center gap-1 text-xs font-semibold text-pino-700">
                <UIcon name="i-lucide-users" class="text-sm" /> 14
              </span>
            </div>
            <p class="mt-1 text-xs text-stone-500">Alterna: La Ventosa → Ixtepec · hace 12 min</p>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
