<script setup>
import { ref, computed } from 'vue'
import { useRequests } from '../composables/useRequests'
import StatTile from '../components/StatTile.vue'
import FilterChip from '../components/FilterChip.vue'
import RequestCard from '../components/RequestCard.vue'
import EmptyStatePanel from '../components/EmptyStatePanel.vue'
import RequestModal from '../components/RequestModal.vue'

const { requests, loading, statusChangeAnnouncement, upsertLocal } = useRequests()

const requestModal = ref(null)

function openCreateModal() {
  requestModal.value.openCreate()
}

function openEditModal(request) {
  requestModal.value.openEdit(request)
}

const FILTERS = [
  { key: 'all', label: 'All requests' },
  { key: 'unbooked', label: 'Unbooked' },
  { key: 'booked', label: 'Booked' },
  { key: 'completed', label: 'Completed' },
  { key: 'cancelled', label: 'Cancelled' },
]

const activeFilter = ref('all')
const searchTerm = ref('')

const statCounts = computed(() => ({
  unbooked: requests.value.filter((r) => r.status === 'unbooked').length,
  booked: requests.value.filter((r) => r.status === 'booked').length,
  completed: requests.value.filter((r) => r.status === 'completed').length,
  cancelled: requests.value.filter((r) => r.status === 'cancelled').length,
}))

const filteredRequests = computed(() => {
  let list = requests.value

  if (activeFilter.value !== 'all') {
    list = list.filter((r) => r.status === activeFilter.value)
  }

  const term = searchTerm.value.trim().toLowerCase()
  if (term) {
    list = list.filter(
      (r) =>
        r.origin.toLowerCase().includes(term) ||
        r.destination.toLowerCase().includes(term) ||
        (r.notes && r.notes.toLowerCase().includes(term)),
    )
  }

  return list
})

const resultCountAnnouncement = computed(() => {
  const count = filteredRequests.value.length
  return `${count} ${count === 1 ? 'request' : 'requests'} shown.`
})

const zeroResultsMessage = computed(() => {
  const term = searchTerm.value.trim()
  if (term) return `No requests match '${term}'.`
  const activeChip = FILTERS.find((f) => f.key === activeFilter.value)
  return `No requests match '${activeChip.label}'.`
})

function clearFilters() {
  activeFilter.value = 'all'
  searchTerm.value = ''
}
</script>

<template>
  <div>
    <div class="flex items-center justify-between gap-flovi-4">
      <h1 class="text-display text-text-primary">Requests</h1>
      <button
        type="button"
        class="inline-flex items-center justify-center rounded-full bg-accent px-flovi-5 py-[11px] text-body-strong text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
        @click="openCreateModal"
      >
        + New request
      </button>
    </div>

    <div class="mt-flovi-6 grid grid-cols-4 gap-flovi-3">
      <StatTile label="Unbooked" :count="statCounts.unbooked" />
      <StatTile label="Booked" :count="statCounts.booked" />
      <StatTile label="Completed" :count="statCounts.completed" />
      <StatTile label="Cancelled" :count="statCounts.cancelled" />
    </div>

    <div class="mt-flovi-6 flex flex-wrap items-center justify-between gap-flovi-3">
      <div class="flex flex-wrap gap-flovi-2">
        <FilterChip
          v-for="filter in FILTERS"
          :key="filter.key"
          :label="filter.label"
          :active="activeFilter === filter.key"
          @click="activeFilter = filter.key"
        />
      </div>

      <input
        v-model="searchTerm"
        type="search"
        placeholder="Search origin, destination, or notes"
        aria-label="Search requests"
        class="w-full max-w-xs rounded-full border border-border-subtle bg-surface-tint px-flovi-4 py-flovi-2 text-body text-text-primary placeholder:text-text-tertiary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
      />
    </div>

    <p aria-live="polite" class="sr-only">{{ resultCountAnnouncement }}</p>
    <p aria-live="polite" class="sr-only">{{ statusChangeAnnouncement }}</p>

    <div class="mt-flovi-6 flex flex-col gap-flovi-3">
      <template v-if="loading">
        <div
          v-for="n in 3"
          :key="n"
          class="h-24 animate-pulse rounded-md border border-border-hairline bg-surface-card"
        />
      </template>

      <EmptyStatePanel v-else-if="requests.length === 0" message="No relocation requests yet.">
        <template #action>
          <button
            type="button"
            class="inline-flex items-center justify-center rounded-full bg-accent px-flovi-5 py-[11px] text-body-strong text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
            @click="openCreateModal"
          >
            + New request
          </button>
        </template>
      </EmptyStatePanel>

      <EmptyStatePanel v-else-if="filteredRequests.length === 0" :message="zeroResultsMessage">
        <template #action>
          <button
            type="button"
            class="inline-flex items-center justify-center rounded-full border border-border-subtle bg-surface-card px-flovi-5 py-flovi-2 text-body text-text-secondary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
            @click="clearFilters"
          >
            Clear filters
          </button>
        </template>
      </EmptyStatePanel>

      <template v-else>
        <RequestCard
          v-for="request in filteredRequests"
          :key="request.id"
          :request="request"
          @edit="openEditModal"
          @cancelled="upsertLocal"
        />
      </template>
    </div>

    <RequestModal ref="requestModal" @saved="upsertLocal" />
  </div>
</template>
