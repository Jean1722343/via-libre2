<script setup lang="ts">
const auth = useAuth()
const { abierto } = useLoginModal()

// Rehidrata la sesión guardada al cargar la app.
onMounted(() => {
  auth.restaurar()
})
</script>

<template>
  <UApp>
    <NuxtPage />
    <AuthLoginModal v-model:open="abierto" />
  </UApp>
</template>
