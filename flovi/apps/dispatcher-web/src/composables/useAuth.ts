import { ref, computed } from 'vue'
import { supabase } from '../lib/supabase'

const session = ref(null)
const authError = ref('')

let readyResolve: () => void
const ready = new Promise<void>((resolve) => {
  readyResolve = resolve
})

let initialized = false
function init() {
  if (initialized) return
  initialized = true

  supabase.auth.getSession().then(({ data }) => {
    session.value = data.session
    readyResolve()
  })

  supabase.auth.onAuthStateChange((_event, newSession) => {
    session.value = newSession
  })
}
init()

export function useAuth() {
  const isAuthenticated = computed(() => !!session.value)

  async function signInWithGoogle() {
    authError.value = ''
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    })
    if (error) {
      authError.value = "We couldn't sign you in — try again."
    }
  }

  async function signOut() {
    await supabase.auth.signOut()
    session.value = null
  }

  async function claimRole(role: 'dispatcher' | 'driver') {
    const { error } = await supabase.rpc('claim_role', { p_role: role })
    if (error) throw error
  }

  return {
    session,
    isAuthenticated,
    authError,
    ready,
    signInWithGoogle,
    signOut,
    claimRole,
  }
}
