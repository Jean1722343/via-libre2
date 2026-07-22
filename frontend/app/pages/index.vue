<script setup lang="ts">
const pasos = [
  { icono: 'i-lucide-map-pin', titulo: 'Reporta', texto: 'Marca en el mapa dónde está el bloqueo, de qué tipo es y qué está pasando. En segundos.' },
  { icono: 'i-lucide-users', titulo: 'La comunidad confirma', texto: 'Otros vecinos dicen si "sigue ahí" o "ya se liberó". La info se mantiene fresca sola.' },
  { icono: 'i-lucide-route', titulo: 'Llega bien', texto: 'Ve si tu ruta está libre y toma la ruta alterna sugerida antes de salir de casa.' },
]

const confianza = [
  { icono: 'i-lucide-badge-check', titulo: 'Verificado por vecinos', texto: 'Cada reporte muestra cuántas personas lo confirmaron. Mientras más confirmen, más confiable.' },
  { icono: 'i-lucide-timer', titulo: 'Caduca solo', texto: 'Los reportes tienen vigencia: si nadie los confirma, desaparecen. Nada de info vieja.' },
  { icono: 'i-lucide-shield-check', titulo: 'Sin spam', texto: 'Límite de reportes por persona para que nadie llene el mapa de bloqueos falsos.' },
]
</script>

<template>
  <div class="min-h-dvh">
    <LandingHeader />
    <LandingHero />

    <!-- El problema -->
    <section id="problema" class="relative overflow-hidden bg-crema-suave py-24">
      <div v-reveal class="mx-auto max-w-3xl px-4 text-center sm:px-6">
        <span class="inline-flex items-center gap-2 rounded-full bg-terracota-100 px-3 py-1 text-xs font-bold uppercase tracking-wide text-terracota-700">
          <UIcon name="i-lucide-clock-alert" /> El problema
        </span>
        <h2 class="font-display mt-5 text-4xl font-black leading-tight text-pino-950 sm:text-5xl">
          Perder el día por un bloqueo<br class="hidden sm:block"> ya no debería ser normal
        </h2>
        <p class="mt-6 text-lg leading-relaxed text-stone-600">
          En el Istmo los bloqueos son parte de la vida — magisteriales, comunitarios,
          por obra, por marchas. Hoy nos enteramos tarde, por grupos de WhatsApp
          revueltos o cuando ya estamos parados en la fila. <span class="font-semibold text-terracota-700">Vía Libre</span>
          junta esa información y la ordena para que llegues a donde vas.
        </p>
      </div>
    </section>

    <!-- Cómo funciona -->
    <section id="como-funciona" class="py-24">
      <div class="mx-auto max-w-6xl px-4 sm:px-6">
        <div v-reveal class="mx-auto max-w-2xl text-center">
          <span class="inline-flex items-center gap-2 rounded-full bg-pino-100 px-3 py-1 text-xs font-bold uppercase tracking-wide text-pino-700">
            <UIcon name="i-lucide-sparkles" /> Cómo funciona
          </span>
          <h2 class="font-display mt-5 text-4xl font-black text-pino-950 sm:text-5xl">Tres pasos, cero complicaciones</h2>
        </div>
        <div class="relative mt-14 grid gap-6 md:grid-cols-3">
          <!-- Línea conectora (desktop) -->
          <div class="absolute inset-x-[16%] top-11 -z-0 hidden h-0.5 bg-gradient-to-r from-terracota-200 via-ambar-200 to-pino-200 md:block" />
          <div
            v-for="(p, i) in pasos"
            :key="p.titulo"
            v-reveal="{ delay: i * 120 }"
            class="hover-lift group relative z-10 rounded-3xl border border-stone-200 bg-white p-7 shadow-sm"
          >
            <div class="flex size-14 items-center justify-center rounded-2xl bg-gradient-to-br from-terracota-500 to-terracota-600 text-white shadow-lg shadow-terracota-600/25 transition group-hover:scale-105">
              <UIcon :name="p.icono" class="text-2xl" />
            </div>
            <p class="mt-5 flex items-center gap-2 text-sm font-bold text-terracota-600">
              <span class="flex size-5 items-center justify-center rounded-full bg-terracota-100 text-[11px]">{{ i + 1 }}</span>
              Paso {{ i + 1 }}
            </p>
            <h3 class="font-display mt-1.5 text-2xl font-bold text-pino-950">{{ p.titulo }}</h3>
            <p class="mt-2 leading-relaxed text-stone-600">{{ p.texto }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- Confianza -->
    <section id="confianza" class="relative overflow-hidden bg-pino-950 py-24 text-white">
      <div class="pointer-events-none absolute inset-0 -z-0">
        <div class="absolute -right-20 top-0 size-96 rounded-full bg-pino-700/40 blur-3xl" />
        <div class="absolute -left-20 bottom-0 size-96 rounded-full bg-terracota-700/30 blur-3xl" />
      </div>
      <div class="relative mx-auto max-w-6xl px-4 sm:px-6">
        <div class="mx-auto max-w-2xl text-center">
          <span class="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-xs font-bold uppercase tracking-wide text-ambar-300">
            <UIcon name="i-lucide-shield-check" /> Confianza
          </span>
          <h2 class="font-display mt-5 text-4xl font-black sm:text-5xl">La comunidad se cuida sola</h2>
          <p class="mt-3 text-pino-100/80">Con reglas claras para que la info siempre sea confiable.</p>
        </div>
        <div class="mt-14 grid gap-6 md:grid-cols-3">
          <div v-for="(c, i) in confianza" :key="c.titulo" v-reveal="{ delay: i * 120 }" class="hover-lift rounded-3xl bg-white/5 p-7 ring-1 ring-white/10 backdrop-blur">
            <div class="flex size-14 items-center justify-center rounded-2xl bg-ambar-400/15 text-ambar-300 ring-1 ring-ambar-300/20">
              <UIcon :name="c.icono" class="text-2xl" />
            </div>
            <h3 class="font-display mt-5 text-2xl font-bold">{{ c.titulo }}</h3>
            <p class="mt-2 leading-relaxed text-pino-100/80">{{ c.texto }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- CTA final -->
    <section class="px-4 py-24 sm:px-6">
      <div v-reveal class="relative mx-auto max-w-5xl overflow-hidden rounded-[32px] bg-gradient-to-br from-terracota-500 via-terracota-600 to-terracota-700 px-6 py-16 text-center shadow-2xl shadow-terracota-600/30">
        <div class="malla-puntos absolute inset-0 opacity-30" />
        <div class="relative">
          <h2 class="font-display text-4xl font-black text-white sm:text-5xl">¿Vas a salir?<br>Échale un ojo primero.</h2>
          <p class="mx-auto mt-4 max-w-lg text-terracota-50/90">Gratis, sin cuenta obligatoria. En segundos sabes si el camino está libre.</p>
          <div class="mt-9 flex flex-wrap justify-center gap-3">
            <UButton to="/mapa" size="xl" color="neutral" icon="i-lucide-map" class="press rounded-full bg-white px-7 font-bold text-terracota-700 shadow-lg hover:bg-crema">
              Abrir el mapa en vivo
            </UButton>
            <UButton to="/mapa?reportar=1" size="xl" variant="outline" icon="i-lucide-megaphone" class="press rounded-full border-white/50 font-semibold text-white hover:bg-white/10">
              Reportar un bloqueo
            </UButton>
          </div>
        </div>
      </div>
    </section>

    <LandingFooter />
  </div>
</template>
