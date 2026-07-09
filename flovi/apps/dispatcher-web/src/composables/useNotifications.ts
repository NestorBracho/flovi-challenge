import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import type { RealtimeChannel } from '@supabase/supabase-js'

export interface Notification {
  id: string
  message: string
  created_at: string
  read_at: string | null
  relocation_requests: { origin: string; destination: string } | null
}

const SELECT_COLUMNS = 'id, message, created_at, read_at, relocation_requests(origin, destination)'

const notifications = ref<Notification[]>([])
const unreadCount = ref(0)
const loaded = ref(false)

let channel: RealtimeChannel | null = null
let initialized = false

async function hydrate() {
  const { data, error } = await supabase
    .from('notifications')
    .select(SELECT_COLUMNS)
    .order('created_at', { ascending: false })

  if (!error && data) {
    notifications.value = data as unknown as Notification[]
    unreadCount.value = notifications.value.filter((n) => !n.read_at).length
  }
  loaded.value = true
}

async function fetchNotification(id: string) {
  const { data } = await supabase.from('notifications').select(SELECT_COLUMNS).eq('id', id).single()
  return data as unknown as Notification | null
}

function init() {
  if (initialized) return
  initialized = true

  hydrate()

  channel = supabase
    .channel('notifications-changes')
    .on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'notifications' },
      async (payload) => {
        const row = await fetchNotification((payload.new as { id: string }).id)
        if (!row) return
        notifications.value.unshift(row)
        unreadCount.value += 1
      },
    )
    .subscribe()
}

async function markAllRead() {
  const unreadIds = notifications.value.filter((n) => !n.read_at).map((n) => n.id)
  if (unreadIds.length === 0) return

  const readAt = new Date().toISOString()
  const { error } = await supabase.from('notifications').update({ read_at: readAt }).is('read_at', null)

  if (error) return

  notifications.value = notifications.value.map((n) =>
    unreadIds.includes(n.id) ? { ...n, read_at: readAt } : n,
  )
  unreadCount.value = 0
}

export function useNotifications() {
  init()

  return {
    notifications,
    unreadCount,
    loaded,
    markAllRead,
  }
}
