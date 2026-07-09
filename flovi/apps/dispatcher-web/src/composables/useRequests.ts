import { ref, onMounted, onUnmounted } from 'vue'
import { supabase } from '../lib/supabase'
import type { RealtimeChannel } from '@supabase/supabase-js'

export type RequestStatus = 'unbooked' | 'booked' | 'completed' | 'cancelled'

export interface RelocationRequest {
  id: string
  origin: string
  destination: string
  scheduled_date: string
  notes: string | null
  status: RequestStatus
  driver_id: string | null
  created_at: string
  updated_at: string
}

const SELECT_COLUMNS = 'id, origin, destination, scheduled_date, notes, status, driver_id, created_at, updated_at'

export function useRequests() {
  const requests = ref<RelocationRequest[]>([])
  const loading = ref(true)
  const statusChangeAnnouncement = ref('')

  let channel: RealtimeChannel | null = null

  async function hydrate() {
    const { data, error } = await supabase
      .from('relocation_requests')
      .select(SELECT_COLUMNS)
      .order('created_at', { ascending: false })

    if (!error && data) {
      requests.value = data as RelocationRequest[]
    }
    loading.value = false
  }

  function handleUpsert(row: RelocationRequest) {
    const index = requests.value.findIndex((r) => r.id === row.id)

    if (index === -1) {
      requests.value.unshift(row)
      return
    }

    const previousStatus = requests.value[index].status
    requests.value[index] = row

    if (previousStatus !== row.status) {
      statusChangeAnnouncement.value = `${row.origin} to ${row.destination} is now ${row.status}.`
    }
  }

  function handleDelete(id: string) {
    requests.value = requests.value.filter((r) => r.id !== id)
  }

  onMounted(async () => {
    await hydrate()

    channel = supabase
      .channel('relocation_requests-changes')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'relocation_requests' },
        (payload) => handleUpsert(payload.new as RelocationRequest),
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'relocation_requests' },
        (payload) => handleUpsert(payload.new as RelocationRequest),
      )
      .on(
        'postgres_changes',
        { event: 'DELETE', schema: 'public', table: 'relocation_requests' },
        (payload) => handleDelete((payload.old as { id: string }).id),
      )
      .subscribe()
  })

  onUnmounted(() => {
    if (channel) supabase.removeChannel(channel)
  })

  return {
    requests,
    loading,
    statusChangeAnnouncement,
    upsertLocal: handleUpsert,
  }
}
