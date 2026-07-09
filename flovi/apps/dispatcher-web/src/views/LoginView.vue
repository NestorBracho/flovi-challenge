<script setup>
import { useAuth } from '../composables/useAuth'

const { signInWithGoogle, authError } = useAuth()
</script>

<template>
  <main class="flex min-h-screen items-center justify-center bg-surface-canvas px-flovi-6">
    <div
      class="w-full max-w-sm rounded-lg border border-border-hairline bg-surface-card p-flovi-7 text-center shadow-raised"
    >
      <h1 class="text-display text-text-primary">Flovi</h1>
      <p class="mt-flovi-2 text-body text-text-secondary">Signing up here creates a dispatcher account.</p>

      <button
        type="button"
        class="mt-flovi-6 inline-flex w-full items-center justify-center rounded-full bg-accent px-flovi-5 py-[11px] text-body-strong text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
        @click="signInWithGoogle"
      >
        Sign in with Google
      </button>

      <p v-if="authError" class="mt-flovi-4 text-body text-status-cancelled-text" role="alert">
        {{ authError }}
      </p>
    </div>
  </main>
</template>
