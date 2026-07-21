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
    <section id="problema" class="bg-crema-suave py-20">
      <div v-reveal class="mx-auto max-w-3xl px-4 text-center sm:px-6">
        <h2 class="font-display text-4xl font-bold text-stone-800 sm:text-5xl">
          Perder el día por un bloqueo ya no debería ser normal
        </h2>
        <p class="mt-6 text-lg leading-relaxed text-stone-600">
          En el Istmo los bloqueos son parte de la vida — magisteriales, comunitarios,
          por obra, por marchas. Hoy nos enteramos tarde, por grupos de WhatsApp
          revueltos o cuando ya estamos parados en la fila. <span class="font-semibold text-terracota-700">ViaLibre</span>
          junta esa información y la ordena para que llegues a donde vas.
        </p>
      </div>
    </section>

    <!-- Cómo funciona -->
    <section id="como-funciona" class="py-20">
      <div class="mx-auto max-w-6xl px-4 sm:px-6">
        <div v-reveal class="mx-auto max-w-2xl text-center">
          <h2 class="font-display text-4xl font-bold text-stone-800">Cómo funciona</h2>
          <p class="mt-3 text-stone-600">Tres pasos, cero complicaciones.</p>
        </div>
        <div class="mt-12 grid gap-6 md:grid-cols-3">
          <div
            v-for="(p, i) in pasos"
            :key="p.titulo"
            v-reveal="{ delay: i * 110 }"
            class="hover-lift rounded-2xl border border-stone-200 bg-white p-7 shadow-sm"
          >
            <div class="flex size-12 items-center justify-center rounded-xl bg-terracota-50 text-terracota-600">
              <UIcon :name="p.icono" class="text-2xl" />
            </div>
            <p class="mt-5 text-sm font-semibold text-terracota-600">Paso {{ i + 1 }}</p>
            <h3 class="font-display mt-1 text-2xl font-bold text-stone-800">{{ p.titulo }}</h3>
            <p class="mt-2 text-stone-600">{{ p.texto }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- Confianza -->
    <section id="confianza" class="bg-pino-950 py-20 text-white">
      <div class="mx-auto max-w-6xl px-4 sm:px-6">
        <div class="mx-auto max-w-2xl text-center">
          <h2 class="font-display text-4xl font-bold">¿Por qué confiar en ViaLibre?</h2>
          <p class="mt-3 text-pino-100/80">La comunidad se cuida sola, con reglas claras.</p>
        </div>
        <div class="mt-12 grid gap-6 md:grid-cols-3">
          <div v-for="(c, i) in confianza" :key="c.titulo" v-reveal="{ delay: i * 110 }" class="hover-lift rounded-2xl bg-white/5 p-7 ring-1 ring-white/10">
            <div class="flex size-12 items-center justify-center rounded-xl bg-white/10 text-ambar-300">
              <UIcon :name="c.icono" class="text-2xl" />
            </div>
            <h3 class="font-display mt-5 text-2xl font-bold">{{ c.titulo }}</h3>
            <p class="mt-2 text-pino-100/80">{{ c.texto }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- CTA final -->
    <section class="py-20">
      <div v-reveal class="mx-auto max-w-3xl px-4 text-center sm:px-6">
        <h2 class="font-display text-4xl font-bold text-stone-800">¿Vas a salir? Échale un ojo primero.</h2>
        <div class="mt-8 flex justify-center gap-3">
          <UButton to="/mapa" size="xl" color="primary" icon="i-lucide-map" class="press rounded-full font-semibold shadow-lg shadow-terracota-600/25">
            Abrir el mapa en vivo
          </UButton>
        </div>
      </div>
    </section>

    <LandingFooter />
  </div>
</template>
