<script setup>
import { computed } from 'vue'

const props = defineProps({
  notification: {
    type: Object,
    required: true,
  },
})

const formattedTimestamp = computed(() =>
  new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(props.notification.created_at)),
)
</script>

<template>
  <div class="border-b border-border-hairline py-flovi-4 last:border-b-0">
    <p class="text-body text-text-primary">
      <span v-if="notification.relocation_requests" class="text-body-strong">
        {{ notification.relocation_requests.origin }}
        <span class="text-accent" aria-hidden="true">&rarr;</span>
        {{ notification.relocation_requests.destination }}
      </span>
      {{ notification.message }}
    </p>
    <p class="mt-flovi-1 text-meta text-text-secondary">{{ formattedTimestamp }}</p>
  </div>
</template>
