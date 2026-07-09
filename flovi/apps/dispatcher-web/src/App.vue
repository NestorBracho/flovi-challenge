<script setup>
import { RouterView, useRoute } from 'vue-router'
import AppShell from './components/AppShell.vue'

const route = useRoute()
</script>

<template>
  <AppShell v-if="route.meta.requiresAuth">
    <RouterView />
  </AppShell>
  <RouterView v-else />
</template>
