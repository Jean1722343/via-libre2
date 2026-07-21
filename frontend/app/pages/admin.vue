<script setup lang="ts">
import type { Bloqueo, EstadoBloqueo, Rol } from '~/types/bloqueo'
import { TIPOS_META, ROLES_META } from '~/types/bloqueo'
import type { UsuarioAdmin } from '~/composables/useApi'
import { hace } from '~/utils/tiempo'

const auth = useAuth()
const api = useApi()
const toast = useToast()
const router = useRouter()

const listo = ref(false)
const tab = ref<'reportes' | 'usuarios'>('reportes')
const reportes = ref<Bloqueo[]>([])
const usuarios = ref<UsuarioAdmin[]>([])
const cargando = ref(false)

const roles: Rol[] = ['usuario', 'noticiero', 'admin']

onMounted(async () => {
  await auth.restaurar()
  if (!auth.esAdmin.value) {
    toast.add({ title: 'Necesitas una cuenta admin para entrar aquí.', color: 'warning' })
    router.replace('/mapa')
    return
  }
  listo.value = true
  await cargar()
})

async function cargar() {
  cargando.value = true
  try {
    const [activos, programados, usrs] = await Promise.all([
      api.listarBloqueos('activo'),
      api.listarBloqueos('programado'),
      api.listarUsuarios().catch(() => []),
    ])
    reportes.value = [...activos.bloqueos, ...programados.bloqueos]
    usuarios.value = usrs
  } catch {
    toast.add({ title: 'No se pudo cargar el panel.', color: 'error' })
  } finally {
    cargando.value = false
  }
}

async function verificar(b: Bloqueo) {
  try {
    await api.verificarReporte(b.id)
    toast.add({ title: 'Reporte verificado ✓', color: 'success' })
    await cargar()
  } catch {
    toast.add({ title: 'No se pudo verificar.', color: 'error' })
  }
}

async function finalizar(b: Bloqueo) {
  try {
    await api.finalizarReporte(b.id)
    toast.add({ title: 'Reporte cerrado.', color: 'success' })
    await cargar()
  } catch {
    toast.add({ title: 'No se pudo cerrar.', color: 'error' })
  }
}

async function eliminar(b: Bloqueo) {
  if (!confirm('¿Borrar este reporte definitivamente?')) return
  try {
    await api.eliminarReporte(b.id)
    toast.add({ title: 'Reporte borrado.', color: 'success' })
    await cargar()
  } catch {
    toast.add({ title: 'No se pudo borrar.', color: 'error' })
  }
}

async function cambiarRol(u: UsuarioAdmin, rol: Rol) {
  if (u.rol === rol) return
  try {
    const actualizado = await api.cambiarRol(u.id, rol)
    u.rol = actualizado.rol
    toast.add({ title: `${u.nombre} ahora es ${rol}.`, color: 'success' })
  } catch {
    toast.add({ title: 'No se pudo cambiar el rol.', color: 'error' })
  }
}
</script>

<template>
  <div class="min-h-dvh bg-crema">
    <header class="border-b border-stone-200 bg-white">
      <div class="mx-auto flex h-14 max-w-5xl items-center gap-3 px-4">
        <UButton to="/mapa" icon="i-lucide-arrow-left" color="neutral" variant="ghost" size="sm" square />
        <span class="flex size-7 items-center justify-center rounded-lg bg-terracota-600 text-white">
          <UIcon name="i-lucide-shield" />
        </span>
        <span class="font-display text-lg font-bold text-stone-800">Panel de administración</span>
        <UButton class="ml-auto" icon="i-lucide-refresh-cw" color="neutral" variant="ghost" size="sm" :loading="cargando" @click="cargar" />
      </div>
    </header>

    <div v-if="listo" class="mx-auto max-w-5xl px-4 py-6">
      <div class="mb-5 inline-flex rounded-xl bg-stone-100 p-1">
        <button
          v-for="t in (['reportes', 'usuarios'] as const)"
          :key="t"
          class="rounded-lg px-4 py-1.5 text-sm font-semibold capitalize transition"
          :class="tab === t ? 'bg-white text-terracota-700 shadow-sm' : 'text-stone-500'"
          @click="tab = t"
        >
          {{ t }}
        </button>
      </div>

      <!-- Reportes -->
      <div v-if="tab === 'reportes'" class="space-y-2">
        <p v-if="!reportes.length" class="py-12 text-center text-stone-400">No hay reportes activos ni programados.</p>
        <article
          v-for="b in reportes"
          :key="b.id"
          class="flex flex-wrap items-center gap-3 rounded-xl border border-stone-200 bg-white p-3"
        >
          <UIcon :name="(TIPOS_META[b.tipo] ?? TIPOS_META.otro).icono" class="text-xl text-stone-400" />
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <span class="truncate font-semibold text-stone-800">{{ b.municipio || (TIPOS_META[b.tipo] ?? TIPOS_META.otro).etiqueta }}</span>
              <span
                v-if="b.verificado"
                class="rounded-full bg-pino-100 px-1.5 py-0.5 text-[10px] font-bold uppercase text-pino-700"
              >Verificado</span>
              <span
                v-else
                class="rounded-full bg-ambar-100 px-1.5 py-0.5 text-[10px] font-bold uppercase text-ambar-700"
              >Por verificar</span>
              <span class="rounded-full bg-stone-100 px-1.5 py-0.5 text-[10px] font-bold uppercase text-stone-500">{{ b.estado }}</span>
            </div>
            <p class="truncate text-xs text-stone-500">{{ b.descripcion || 'Sin descripción' }} · {{ hace(b.creado_en) }}</p>
          </div>
          <div class="flex gap-1.5">
            <UButton v-if="!b.verificado" size="xs" color="success" icon="i-lucide-badge-check" @click="verificar(b)">Verificar</UButton>
            <UButton size="xs" color="neutral" variant="outline" icon="i-lucide-flag" @click="finalizar(b)">Cerrar</UButton>
            <UButton size="xs" color="error" variant="ghost" icon="i-lucide-trash-2" square @click="eliminar(b)" />
          </div>
        </article>
      </div>

      <!-- Usuarios -->
      <div v-else class="space-y-2">
        <p v-if="!usuarios.length" class="py-12 text-center text-stone-400">Aún no hay usuarios registrados.</p>
        <article
          v-for="u in usuarios"
          :key="u.id"
          class="flex flex-wrap items-center gap-3 rounded-xl border border-stone-200 bg-white p-3"
        >
          <UAvatar :alt="u.nombre" size="sm" />
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <span class="truncate font-semibold text-stone-800">{{ u.nombre }}</span>
              <span
                class="rounded-full px-1.5 py-0.5 text-[10px] font-bold uppercase"
                :style="{ background: (ROLES_META[u.rol as Rol] ?? ROLES_META.usuario).color + '1a', color: (ROLES_META[u.rol as Rol] ?? ROLES_META.usuario).color }"
              >{{ (ROLES_META[u.rol as Rol] ?? ROLES_META.usuario).etiqueta }}</span>
            </div>
            <p class="truncate text-xs text-stone-500">{{ u.email }}</p>
          </div>
          <div class="inline-flex rounded-lg bg-stone-100 p-0.5">
            <button
              v-for="r in roles"
              :key="r"
              class="rounded-md px-2.5 py-1 text-xs font-semibold capitalize transition"
              :class="u.rol === r ? 'bg-white text-terracota-700 shadow-sm' : 'text-stone-500 hover:text-stone-700'"
              @click="cambiarRol(u, r)"
            >
              {{ r }}
            </button>
          </div>
        </article>
      </div>
    </div>

    <div v-else class="flex h-dvh items-center justify-center text-stone-400">Verificando acceso…</div>
  </div>
</template>
