<template>
  <aside class="shelf">
    <div class="brand">
      <span class="brand-mark">⌂</span>
      <div>
        <h1>{{ t('title') }}</h1>
        <p class="tagline">{{ t('tagline') }}</p>
      </div>
    </div>

    <button class="new-chat" @click="pick(null)">＋ {{ t('new_chat') }}</button>

    <nav class="notes">
      <template v-for="group in groups" :key="group.label">
        <h2 v-if="group.items.length">{{ group.label }}</h2>
        <div
          v-for="(s, i) in group.items"
          :key="s.id"
          class="note"
          :class="{ active: s.id === state.sessionId, pinned: s.pinned }"
          :style="{ '--tilt': `${TILTS[i % TILTS.length]}deg` }"
          @click="pick(s.id)"
        >
          <span class="note-title">{{ s.title || s.preview || t('untitled') }}</span>
          <span v-if="state.runs[s.id]" class="note-busy">✍️</span>
          <span class="note-actions" @click.stop>
            <button :title="s.pinned ? t('unpin') : t('pin')" @click="togglePin(s)">
              {{ s.pinned ? '📌' : '📍' }}
            </button>
            <button :title="t('delete')" @click="remove(s)">🗑️</button>
          </span>
        </div>
      </template>
      <p v-if="!state.sessions.length" class="muted">{{ t('no_chats') }}</p>
    </nav>
  </aside>
</template>

<script setup>
import { computed } from 'vue'
import { useTranslation } from 'i18next-vue'
import { state, openSession, togglePin, removeSession } from '../store'

const emit = defineEmits(['picked'])
const { t } = useTranslation()

// Sticky-note tilt in degrees, repeating down the list.
const TILTS = [-1.2, 0.8, -0.4, 1.1, -0.9]

const groups = computed(() => [
  { label: t('pinned'), items: state.sessions.filter((s) => s.pinned) },
  { label: t('recent'), items: state.sessions.filter((s) => !s.pinned) }
])

async function pick(id) {
  await openSession(id)
  emit('picked')
}

async function remove(session) {
  if (confirm(t('delete_confirm'))) await removeSession(session)
}
</script>
