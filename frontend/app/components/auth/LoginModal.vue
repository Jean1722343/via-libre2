<script setup lang="ts">
// Modal de acceso: correo/contraseña (activo) + Google/Facebook (dormidos hasta
// configurar sus IDs). Emite 'success' cuando la sesión queda lista.
const open = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ (e: 'success'): void }>()

const auth = useAuth()
const toast = useToast()

const modo = ref<'entrar' | 'crear'>('entrar')
const nombre = ref('')
const email = ref('')
const password = ref('')
const cargando = ref(false)

const titulo = computed(() => (modo.value === 'entrar' ? 'Bienvenido de nuevo' : 'Crea tu cuenta'))
const cta = computed(() => (modo.value === 'entrar' ? 'Entrar' : 'Crear cuenta'))

watch(open, (v) => {
  if (v) {
    nombre.value = ''
    email.value = ''
    password.value = ''
    cargando.value = false
  }
})

async function enviar() {
  if (!email.value || !password.value || (modo.value === 'crear' && !nombre.value)) {
    toast.add({ title: 'Completa los campos.', color: 'warning' })
    return
  }
  cargando.value = true
  try {
    if (modo.value === 'entrar') await auth.login(email.value, password.value)
    else await auth.registrar(nombre.value, email.value, password.value)
    toast.add({ title: `¡Hola, ${auth.usuario.value?.nombre || 'bienvenido'}! 👋`, color: 'success' })
    open.value = false
    emit('success')
  } catch (e) {
    const msg = (e as { data?: { error?: string } })?.data?.error || 'No se pudo continuar. Revisa tus datos.'
    toast.add({ title: msg, color: 'error' })
  } finally {
    cargando.value = false
  }
}

async function social(proveedor: 'google' | 'facebook') {
  cargando.value = true
  try {
    await auth.loginSocial(proveedor)
    toast.add({ title: `¡Hola, ${auth.usuario.value?.nombre || 'bienvenido'}! 👋`, color: 'success' })
    open.value = false
    emit('success')
  } catch (e) {
    const msg = (e as { data?: { error?: string } })?.data?.error || (e as Error).message
    toast.add({ title: msg || 'No se pudo iniciar sesión.', color: 'error' })
  } finally {
    cargando.value = false
  }
}
</script>

<template>
  <UModal v-model:open="open" :ui="{ content: 'max-w-sm' }">
    <template #content>
      <div class="p-6">
        <div class="mb-5 flex flex-col items-center text-center">
          <span class="mb-3 flex size-12 items-center justify-center rounded-2xl bg-terracota-600 text-white shadow-sm">
            <UIcon name="i-lucide-triangle-alert" class="text-2xl" />
          </span>
          <h2 class="font-display text-2xl font-bold text-stone-800">{{ titulo }}</h2>
          <p class="mt-1 text-sm text-stone-500">Reporta y verifica bloqueos del Istmo.</p>
        </div>

        <!-- Sociales -->
        <div class="space-y-2">
          <UButton
            block
            color="neutral"
            variant="outline"
            size="lg"
            class="justify-center rounded-xl"
            :disabled="cargando || !auth.googleActivo.value"
            icon="i-lucide-chrome"
            @click="social('google')"
          >
            Continuar con Google
            <span v-if="!auth.googleActivo.value" class="text-xs text-stone-400">(pronto)</span>
          </UButton>
          <UButton
            block
            color="neutral"
            variant="outline"
            size="lg"
            class="justify-center rounded-xl"
            :disabled="cargando || !auth.facebookActivo.value"
            icon="i-lucide-facebook"
            @click="social('facebook')"
          >
            Continuar con Facebook
            <span v-if="!auth.facebookActivo.value" class="text-xs text-stone-400">(pronto)</span>
          </UButton>
        </div>

        <div class="my-4 flex items-center gap-3 text-xs text-stone-400">
          <span class="h-px flex-1 bg-stone-200" /> o con tu correo <span class="h-px flex-1 bg-stone-200" />
        </div>

        <!-- Correo/contraseña -->
        <form class="space-y-3" @submit.prevent="enviar">
          <UInput
            v-if="modo === 'crear'"
            v-model="nombre"
            placeholder="Tu nombre"
            icon="i-lucide-user"
            size="lg"
            class="w-full"
          />
          <UInput
            v-model="email"
            type="email"
            placeholder="correo@ejemplo.com"
            icon="i-lucide-mail"
            size="lg"
            class="w-full"
          />
          <UInput
            v-model="password"
            type="password"
            placeholder="Contraseña"
            icon="i-lucide-lock"
            size="lg"
            class="w-full"
          />
          <UButton
            type="submit"
            block
            color="primary"
            size="lg"
            class="justify-center rounded-xl font-semibold"
            :loading="cargando"
          >
            {{ cta }}
          </UButton>
        </form>

        <p class="mt-4 text-center text-sm text-stone-500">
          <template v-if="modo === 'entrar'">
            ¿No tienes cuenta?
            <button class="font-semibold text-terracota-700 hover:underline" @click="modo = 'crear'">Regístrate</button>
          </template>
          <template v-else>
            ¿Ya tienes cuenta?
            <button class="font-semibold text-terracota-700 hover:underline" @click="modo = 'entrar'">Entra</button>
          </template>
        </p>
      </div>
    </template>
  </UModal>
</template>
