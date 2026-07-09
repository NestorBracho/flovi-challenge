import { createRouter, createWebHistory } from 'vue-router'
import { useAuth } from '../composables/useAuth'

const routes = [
  { path: '/', redirect: '/requests' },
  {
    path: '/login',
    name: 'login',
    component: () => import('../views/LoginView.vue'),
  },
  {
    path: '/auth/callback',
    name: 'auth-callback',
    component: () => import('../views/AuthCallbackView.vue'),
  },
  {
    path: '/requests',
    name: 'requests',
    component: () => import('../views/RequestsView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/notifications',
    name: 'notifications',
    component: () => import('../views/NotificationsView.vue'),
    meta: { requiresAuth: true },
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach(async (to) => {
  const { isAuthenticated, ready } = useAuth()
  await ready

  if (to.meta.requiresAuth && !isAuthenticated.value) {
    return { name: 'login' }
  }

  if (to.name === 'login' && isAuthenticated.value) {
    return { name: 'requests' }
  }

  return true
})

export default router
