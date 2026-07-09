<script setup>
import { onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuth } from '../composables/useAuth'

const router = useRouter()
const { claimRole, signOut, authError } = useAuth()

const OAUTH_FAILURE_MESSAGE = "We couldn't sign you in — try again."
const ROLE_MISMATCH_MESSAGE =
  'This Google account is already registered as a driver — sign in through the driver app instead.'

onMounted(async () => {
  const params = new URLSearchParams(window.location.search)
  if (params.get('error')) {
    authError.value = OAUTH_FAILURE_MESSAGE
    router.replace({ name: 'login' })
    return
  }

  const { data, error } = await supabase.auth.getSession()

  if (error || !data.session) {
    authError.value = OAUTH_FAILURE_MESSAGE
    router.replace({ name: 'login' })
    return
  }

  try {
    await claimRole('dispatcher')
    router.replace({ name: 'requests' })
  } catch {
    await signOut()
    authError.value = ROLE_MISMATCH_MESSAGE
    router.replace({ name: 'login' })
  }
})
</script>

<template>
  <main class="flex min-h-screen items-center justify-center bg-surface-canvas">
    <p class="text-body text-text-secondary">Signing you in…</p>
  </main>
</template>
