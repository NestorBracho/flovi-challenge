<script setup>
import { nextTick, reactive, ref } from 'vue'
import { supabase } from '../lib/supabase'
import IconButton from './IconButton.vue'

const emit = defineEmits(['saved'])

const dialogEl = ref(null)
const headingEl = ref(null)
const originInput = ref(null)
const destinationInput = ref(null)
const scheduledDateInput = ref(null)

const mode = ref('create')
const requestId = ref(null)
const saving = ref(false)

const form = reactive({
  origin: '',
  destination: '',
  scheduledDate: '',
  notes: '',
})

const errors = reactive({
  origin: '',
  destination: '',
  scheduledDate: '',
})

let triggerEl = null

function resetForm(request) {
  form.origin = request?.origin ?? ''
  form.destination = request?.destination ?? ''
  form.scheduledDate = request?.scheduled_date ?? ''
  form.notes = request?.notes ?? ''
  errors.origin = ''
  errors.destination = ''
  errors.scheduledDate = ''
}

async function openCreate() {
  mode.value = 'create'
  requestId.value = null
  resetForm(null)
  triggerEl = document.activeElement
  dialogEl.value.showModal()
  await nextTick()
  originInput.value?.focus()
}

async function openEdit(request) {
  mode.value = 'edit'
  requestId.value = request.id
  resetForm(request)
  triggerEl = document.activeElement
  dialogEl.value.showModal()
  await nextTick()
  headingEl.value?.focus()
}

defineExpose({ openCreate, openEdit })

function handleBackdropClick(event) {
  if (event.target === dialogEl.value) {
    dialogEl.value.close()
  }
}

function handleClose() {
  triggerEl?.focus()
  triggerEl = null
}

function handleCancel() {
  dialogEl.value.close()
}

function validate() {
  errors.origin = form.origin.trim() ? '' : 'Origin is required.'
  errors.destination = form.destination.trim() ? '' : 'Destination is required.'
  errors.scheduledDate = form.scheduledDate ? '' : 'Scheduled date is required.'
  return !errors.origin && !errors.destination && !errors.scheduledDate
}

async function handleSave() {
  if (!validate()) {
    await nextTick()
    const firstInvalid = errors.origin
      ? originInput.value
      : errors.destination
        ? destinationInput.value
        : scheduledDateInput.value
    firstInvalid?.focus()
    return
  }

  saving.value = true

  const payload = {
    origin: form.origin.trim(),
    destination: form.destination.trim(),
    scheduled_date: form.scheduledDate,
    notes: form.notes.trim() || null,
  }

  const query =
    mode.value === 'create'
      ? supabase.from('relocation_requests').insert(payload).select().single()
      : supabase.from('relocation_requests').update(payload).eq('id', requestId.value).select().single()

  const { data, error } = await query

  saving.value = false

  if (error || !data) {
    return
  }

  emit('saved', data)
  dialogEl.value.close()
}
</script>

<template>
  <dialog
    ref="dialogEl"
    class="modal-dialog w-[420px] max-w-[calc(100vw-2rem)] rounded-lg bg-surface-card p-flovi-6 shadow-raised"
    @click="handleBackdropClick"
    @close="handleClose"
  >
    <div class="flex items-start justify-between gap-flovi-4">
      <h2 ref="headingEl" tabindex="-1" class="text-heading text-text-primary focus:outline-none">
        {{ mode === 'create' ? 'New request' : 'Edit request' }}
      </h2>
      <IconButton label="Close" @click="handleCancel">
        <span aria-hidden="true">&#10005;</span>
      </IconButton>
    </div>

    <form class="mt-flovi-5 flex flex-col gap-flovi-4" novalidate @submit.prevent="handleSave">
      <div>
        <label for="request-origin" class="text-label uppercase text-text-secondary">Origin</label>
        <input
          id="request-origin"
          ref="originInput"
          v-model="form.origin"
          type="text"
          :aria-invalid="errors.origin ? 'true' : undefined"
          :aria-describedby="errors.origin ? 'request-origin-error' : undefined"
          class="mt-flovi-1 w-full rounded-sm border border-border-subtle bg-surface-tint px-flovi-3 py-flovi-2 text-body text-text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
        />
        <p
          v-if="errors.origin"
          id="request-origin-error"
          class="mt-flovi-1 flex items-center gap-flovi-1 text-meta text-status-cancelled-text"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <circle cx="12" cy="12" r="10" />
            <line x1="12" y1="8" x2="12" y2="12" />
            <line x1="12" y1="16" x2="12" y2="16.01" />
          </svg>
          {{ errors.origin }}
        </p>
      </div>

      <div>
        <label for="request-destination" class="text-label uppercase text-text-secondary">Destination</label>
        <input
          id="request-destination"
          ref="destinationInput"
          v-model="form.destination"
          type="text"
          :aria-invalid="errors.destination ? 'true' : undefined"
          :aria-describedby="errors.destination ? 'request-destination-error' : undefined"
          class="mt-flovi-1 w-full rounded-sm border border-border-subtle bg-surface-tint px-flovi-3 py-flovi-2 text-body text-text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
        />
        <p
          v-if="errors.destination"
          id="request-destination-error"
          class="mt-flovi-1 flex items-center gap-flovi-1 text-meta text-status-cancelled-text"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <circle cx="12" cy="12" r="10" />
            <line x1="12" y1="8" x2="12" y2="12" />
            <line x1="12" y1="16" x2="12" y2="16.01" />
          </svg>
          {{ errors.destination }}
        </p>
      </div>

      <div>
        <label for="request-scheduled-date" class="text-label uppercase text-text-secondary">Scheduled date</label>
        <input
          id="request-scheduled-date"
          ref="scheduledDateInput"
          v-model="form.scheduledDate"
          type="date"
          :aria-invalid="errors.scheduledDate ? 'true' : undefined"
          :aria-describedby="errors.scheduledDate ? 'request-scheduled-date-error' : undefined"
          class="mt-flovi-1 w-full rounded-sm border border-border-subtle bg-surface-tint px-flovi-3 py-flovi-2 text-body text-text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
        />
        <p
          v-if="errors.scheduledDate"
          id="request-scheduled-date-error"
          class="mt-flovi-1 flex items-center gap-flovi-1 text-meta text-status-cancelled-text"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <circle cx="12" cy="12" r="10" />
            <line x1="12" y1="8" x2="12" y2="12" />
            <line x1="12" y1="16" x2="12" y2="16.01" />
          </svg>
          {{ errors.scheduledDate }}
        </p>
      </div>

      <div>
        <label for="request-notes" class="text-label uppercase text-text-secondary">Notes</label>
        <textarea
          id="request-notes"
          v-model="form.notes"
          rows="3"
          class="mt-flovi-1 w-full rounded-sm border border-border-subtle bg-surface-tint px-flovi-3 py-flovi-2 text-body text-text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
        />
      </div>

      <div class="mt-flovi-2 flex justify-end gap-flovi-3">
        <button
          type="button"
          class="inline-flex items-center justify-center rounded-full border border-border-subtle bg-surface-card px-flovi-5 py-flovi-2 text-body text-text-secondary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring"
          @click="handleCancel"
        >
          Cancel
        </button>
        <button
          type="submit"
          :disabled="saving"
          class="inline-flex items-center justify-center rounded-full bg-accent px-flovi-5 py-[11px] text-body-strong text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring disabled:opacity-60"
        >
          Save
        </button>
      </div>
    </form>
  </dialog>
</template>

<style scoped>
.modal-dialog {
  border: none;
}

.modal-dialog::backdrop {
  background: rgba(61, 54, 48, 0.35);
}
</style>
