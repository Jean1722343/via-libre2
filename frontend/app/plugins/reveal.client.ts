// Directiva v-reveal: anima la aparición del elemento cuando entra en pantalla.
// Uso: <div v-reveal>  o  <div v-reveal="{ delay: 120 }">
export default defineNuxtPlugin((nuxtApp) => {
  nuxtApp.vueApp.directive('reveal', {
    mounted(el: HTMLElement, binding) {
      el.classList.add('reveal')
      const delay = (binding.value?.delay as number) ?? 0
      if (delay) el.style.transitionDelay = `${delay}ms`

      const io = new IntersectionObserver(
        (entries) => {
          entries.forEach((e) => {
            if (e.isIntersecting) {
              el.classList.add('reveal-visible')
              io.unobserve(el)
            }
          })
        },
        { threshold: 0.12, rootMargin: '0px 0px -8% 0px' },
      )
      io.observe(el)
    },
  })
})
