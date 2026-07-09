<script setup>
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { useNotifications } from '../composables/useNotifications'
import SidebarNavItem from './SidebarNavItem.vue'

const router = useRouter()
const { session, signOut } = useAuth()
const { unreadCount } = useNotifications()

async function handleSignOut() {
  await signOut()
  router.push({ name: 'login' })
}
</script>

<template>
  <div>
    <div class="flex min-h-screen items-center justify-center bg-surface-canvas px-flovi-6 text-center lg:hidden">
      <p class="text-body text-text-secondary">Flovi is best viewed on a larger screen.</p>
    </div>

    <div class="hidden min-h-screen lg:flex">
      <nav
        class="flex w-[220px] shrink-0 flex-col justify-between border-r border-border-hairline bg-surface-canvas p-flovi-4"
        aria-label="Primary"
      >
        <div class="flex flex-col gap-flovi-1">
          <SidebarNavItem to="/requests" label="Requests" />
          <SidebarNavItem to="/notifications" label="Notifications" :badge="unreadCount" />
        </div>

        <div class="border-t border-border-hairline pt-flovi-3">
          <p class="truncate text-body text-text-primary">
            {{ session?.user?.user_metadata?.full_name || session?.user?.email }}
          </p>
          <button
            type="button"
            class="mt-flovi-2 text-body text-text-secondary hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
            @click="handleSignOut"
          >
            Sign out
          </button>
        </div>
      </nav>

      <main class="flex-1 overflow-y-auto bg-surface-canvas p-flovi-7">
        <slot />
      </main>
    </div>
  </div>
</template>
