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
  driver: { full_name: string | null } | null
  created_at: string
  updated_at: string
}

const SELECT_COLUMNS =
  'id, origin, destination, scheduled_date, notes, status, driver_id, driver:profiles!driver_id(full_name), created_at, updated_at'

export function useRequests() {
  const requests = ref<RelocationRequest[]>([])
  const loading = ref(true)
  const statusChangeAnnouncement = ref('')

  let channel: RealtimeChannel | null = null

  // postgres_changes payloads carry only raw table columns, never the `driver:profiles(...)`
  // embed hydrate() gets from PostgREST — this cache lets realtime upserts resolve a driver's
  // name from driver_id without a network round-trip on every event once it's been seen once.
  const driverNameCache = new Map<string, string | null>()

  async function resolveDriver(driverId: string | null): Promise<{ full_name: string | null } | null> {
    if (!driverId) return null

    if (!driverNameCache.has(driverId)) {
      const { data } = await supabase.from('profiles').select('full_name').eq('id', driverId).single()
      driverNameCache.set(driverId, data?.full_name ?? null)
    }

    return { full_name: driverNameCache.get(driverId) ?? null }
  }

  async function hydrate() {
    const { data, error } = await supabase
      .from('relocation_requests')
      .select(SELECT_COLUMNS)
      .order('created_at', { ascending: false })

    if (!error && data) {
      requests.value = data as RelocationRequest[]
      for (const row of requests.value) {
        if (row.driver_id) driverNameCache.set(row.driver_id, row.driver?.full_name ?? null)
      }
    }
    loading.value = false
  }

  async function handleUpsert(row: RelocationRequest) {
    const resolvedRow = { ...row, driver: await resolveDriver(row.driver_id) }
    const index = requests.value.findIndex((r) => r.id === resolvedRow.id)

    if (index === -1) {
      requests.value.unshift(resolvedRow)
      return
    }

    const previousStatus = requests.value[index].status
    requests.value[index] = resolvedRow

    if (previousStatus !== resolvedRow.status) {
      statusChangeAnnouncement.value = `${resolvedRow.origin} to ${resolvedRow.destination} is now ${resolvedRow.status}.`
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
