<script setup>
import { computed, ref, watch, nextTick } from 'vue'

const props = defineProps({
  status: {
    type: String,
    required: true,
    validator: (value) => ['unbooked', 'booked', 'completed', 'cancelled'].includes(value),
  },
})

const STATUS_META = {
  unbooked: { label: 'Unbooked', dot: 'bg-status-unbooked', text: 'text-status-unbooked-text', tint: 'bg-status-unbooked-tint' },
  booked: { label: 'Booked', dot: 'bg-status-booked', text: 'text-status-booked-text', tint: 'bg-status-booked-tint' },
  completed: { label: 'Completed', dot: 'bg-status-completed', text: 'text-status-completed-text', tint: 'bg-status-completed-tint' },
  cancelled: { label: 'Cancelled', dot: 'bg-status-cancelled', text: 'text-status-cancelled-text', tint: 'bg-status-cancelled-tint' },
}

const meta = computed(() => STATUS_META[props.status])

const flashing = ref(false)

watch(
  () => props.status,
  (newStatus, oldStatus) => {
    if (oldStatus && newStatus !== oldStatus) {
      flashing.value = true
      nextTick(() => {
        flashing.value = false
      })
    }
  },
)
</script>

<template>
  <span
    class="status-pill inline-flex items-center gap-flovi-2 rounded-full px-flovi-4 py-1.5 text-meta"
    :class="[meta.text, flashing ? 'status-pill--flash' : meta.tint]"
  >
    <span class="h-2 w-2 shrink-0 rounded-full" :class="meta.dot" aria-hidden="true" />
    {{ meta.label }}
  </span>
</template>

<style scoped>
.status-pill {
  transition: background-color 600ms ease;
}

.status-pill--flash {
  background-color: var(--color-accent-tint);
}

@media (prefers-reduced-motion: reduce) {
  .status-pill {
    transition: none;
  }
}
</style>
