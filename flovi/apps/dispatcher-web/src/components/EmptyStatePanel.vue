<script setup>
defineProps({
  message: {
    type: String,
    required: true,
  },
})
</script>

<template>
  <div
    class="flex flex-col items-center gap-flovi-4 rounded-md border border-dashed border-border-subtle bg-surface-card px-flovi-6 py-flovi-8 text-center"
  >
    <div class="flex h-12 w-12 items-center justify-center rounded-full bg-surface-tint" aria-hidden="true">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="text-text-tertiary">
        <path stroke-linecap="round" stroke-linejoin="round" d="M3 7h18M3 12h18M3 17h10" />
      </svg>
    </div>
    <p class="text-body text-text-secondary">{{ message }}</p>
    <slot name="action" />
  </div>
</template>
