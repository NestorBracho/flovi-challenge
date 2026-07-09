<script setup>
defineProps({
  label: {
    type: String,
    required: true,
  },
})
</script>

<template>
  <button
    type="button"
    :aria-label="label"
    class="inline-flex min-h-8 min-w-8 items-center justify-center rounded-full text-text-secondary hover:bg-surface-tint focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
  >
    <slot />
  </button>
</template>
