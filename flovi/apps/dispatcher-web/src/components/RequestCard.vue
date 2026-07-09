<script setup>
import { computed, ref } from 'vue'
import { supabase } from '../lib/supabase'
import StatusPill from './StatusPill.vue'

const props = defineProps({
  request: {
    type: Object,
    required: true,
  },
})

const emit = defineEmits(['edit', 'cancelled'])

const formattedDate = computed(() => {
  const [year, month, day] = props.request.scheduled_date.split('-').map(Number)
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(
    new Date(year, month - 1, day),
  )
})

const confirmingCancel = ref(false)
const cancelling = ref(false)
const cancelError = ref('')

function startCancel() {
  cancelError.value = ''
  confirmingCancel.value = true
}

function dismissCancel() {
  confirmingCancel.value = false
}

async function confirmCancel() {
  cancelling.value = true
  cancelError.value = ''

  const { error } = await supabase.rpc('cancel_request_dispatcher', { p_request_id: props.request.id })

  cancelling.value = false

  if (error) {
    cancelError.value = "We couldn't reach the server — try again."
    return
  }

  confirmingCancel.value = false
  emit('cancelled', { ...props.request, status: 'cancelled' })
}
</script>

<template>
  <article class="rounded-md border border-border-hairline bg-surface-card p-flovi-4 shadow-raised">
    <div class="flex items-start justify-between gap-flovi-4">
      <div class="flex items-center gap-flovi-2 text-body-strong text-text-primary">
        <span>{{ request.origin }}</span>
        <span class="text-accent" aria-hidden="true">&rarr;</span>
        <span>{{ request.destination }}</span>
      </div>
      <StatusPill :status="request.status" />
    </div>

    <p class="mt-flovi-2 text-meta text-text-secondary">{{ formattedDate }}</p>

    <p v-if="request.notes" class="mt-flovi-3 text-body text-text-secondary">{{ request.notes }}</p>

    <div class="mt-flovi-3 flex items-center justify-end gap-flovi-3">
      <template v-if="confirmingCancel">
        <span class="text-body text-text-secondary">Cancel this request?</span>
        <button
          type="button"
          :disabled="cancelling"
          class="rounded-full border border-border-subtle bg-surface-card px-flovi-4 py-flovi-2 text-body text-text-secondary hover:bg-surface-tint focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring disabled:opacity-60"
          @click="dismissCancel"
        >
          No
        </button>
        <button
          type="button"
          :disabled="cancelling"
          class="rounded-full border border-status-cancelled bg-surface-card px-flovi-4 py-flovi-2 text-body text-status-cancelled-text hover:bg-status-cancelled-tint focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring disabled:opacity-60"
          @click="confirmCancel"
        >
          Yes
        </button>
      </template>
      <template v-else>
        <button
          v-if="request.status !== 'cancelled'"
          type="button"
          class="rounded-full border border-border-subtle bg-surface-card px-flovi-4 py-flovi-2 text-body text-text-secondary hover:bg-surface-tint focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
          @click="startCancel"
        >
          Cancel
        </button>
        <button
          type="button"
          class="rounded-full border border-border-subtle bg-surface-card px-flovi-4 py-flovi-2 text-body text-text-secondary hover:bg-surface-tint focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
          @click="$emit('edit', request)"
        >
          Edit
        </button>
      </template>
    </div>

    <p v-if="cancelError" class="mt-flovi-2 text-body text-status-cancelled-text" role="alert">
      {{ cancelError }}
    </p>
  </article>
</template>
