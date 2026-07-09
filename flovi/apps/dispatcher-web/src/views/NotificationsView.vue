<script setup>
import { onMounted } from 'vue'
import { useNotifications } from '../composables/useNotifications'
import NotificationItem from '../components/NotificationItem.vue'
import EmptyStatePanel from '../components/EmptyStatePanel.vue'

const { notifications, loaded, markAllRead } = useNotifications()

onMounted(() => {
  markAllRead()
})
</script>

<template>
  <div>
    <h1 class="text-display text-text-primary">Notifications</h1>

    <div class="mt-flovi-6">
      <template v-if="!loaded">
        <div
          v-for="n in 3"
          :key="n"
          class="mb-flovi-3 h-16 animate-pulse rounded-md border border-border-hairline bg-surface-card"
        />
      </template>

      <EmptyStatePanel
        v-else-if="notifications.length === 0"
        message="Nothing here yet — you'll see an update if a driver ever cancels with reassignment."
      />

      <div v-else class="rounded-md border border-border-hairline bg-surface-card px-flovi-4">
        <NotificationItem
          v-for="notification in notifications"
          :key="notification.id"
          :notification="notification"
        />
      </div>
    </div>
  </div>
</template>
