<script setup>
defineProps({
  label: {
    type: String,
    required: true,
  },
  active: {
    type: Boolean,
    default: false,
  },
})

defineEmits(['click'])
</script>

<template>
  <button
    type="button"
    class="rounded-full px-flovi-4 py-flovi-2 text-body focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
    :class="
      active
        ? 'bg-text-primary text-surface-card'
        : 'border border-border-subtle bg-surface-card text-text-secondary hover:bg-surface-tint'
    "
    :aria-pressed="active"
    @click="$emit('click')"
  >
    {{ label }}
  </button>
</template>
