// Estado compartido del modal de acceso, para abrirlo desde cualquier página.
export function useLoginModal() {
  const abierto = useState('login-abierto', () => false)
  const abrir = () => (abierto.value = true)
  const cerrar = () => (abierto.value = false)
  return { abierto, abrir, cerrar }
}
