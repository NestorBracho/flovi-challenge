<script setup>
defineProps({
  label: {
    type: String,
    required: true,
  },
  count: {
    type: Number,
    required: true,
  },
})
</script>

<template>
  <div class="rounded-md border border-border-hairline bg-surface-card px-flovi-4 py-flovi-3">
    <p class="text-label uppercase text-text-secondary">{{ label }}</p>
    <p class="mt-flovi-1 text-display text-text-primary">{{ count }}</p>
  </div>
</template>
