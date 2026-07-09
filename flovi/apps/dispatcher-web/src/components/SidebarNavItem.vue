<script setup>
import { RouterLink, useRoute } from 'vue-router'

defineProps({
  to: { type: String, required: true },
  label: { type: String, required: true },
  badge: { type: Number, default: 0 },
})

const route = useRoute()
</script>

<template>
  <RouterLink
    :to="to"
    class="relative flex items-center justify-between gap-flovi-2 rounded-sm px-flovi-4 py-flovi-3 text-body text-text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
    :class="route.path === to ? 'bg-accent-tint' : 'hover:bg-surface-tint'"
  >
    <span
      v-if="route.path === to"
      class="absolute top-flovi-2 bottom-flovi-2 left-0 w-1 rounded-full bg-accent"
      aria-hidden="true"
    />
    <span>{{ label }}</span>
    <span
      v-if="badge > 0"
      class="inline-flex min-w-[20px] items-center justify-center rounded-full bg-accent px-flovi-2 py-0.5 text-meta text-white"
    >
      {{ badge }}
    </span>
  </RouterLink>
</template>
