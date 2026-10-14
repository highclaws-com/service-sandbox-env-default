<template>
  <section ref="scroller" class="log">
    <div v-if="!entries.length" class="empty">
      <img v-if="agent" :src="agent.avatar" class="empty-avatar" alt="">
      <h2>{{ t('empty_title') }}</h2>
      <p>{{ t('empty_body', { name: agent?.name }) }}</p>
    </div>

    <template v-for="(e, i) in entries" :key="i">
      <!-- A message: avatar and name only when the speaker changes, like Discord. -->
      <article v-if="e.kind === 'text'" class="msg" :class="[e.who, { grouped: grouped(i) }]">
        <div class="msg-side">
          <template v-if="!grouped(i)">
            <img v-if="e.who === 'agent'" :src="agent?.avatar" class="avatar" alt="">
            <span v-else class="avatar avatar-me">🙂</span>
          </template>
        </div>
        <div class="msg-body">
          <header v-if="!grouped(i)">
            <strong :style="e.who === 'agent' ? { color: agent?.color } : null">
              {{ e.who === 'agent' ? agent?.name : t('you') }}
            </strong>
            <time>{{ clock(e.ts) }}</time>
          </header>
          <div v-if="e.who === 'agent'" class="md" :class="{ streaming: e.streaming }"
            v-html="renderMarkdown(e.text)"></div>
          <div v-else class="plain">{{ e.text }}</div>
          <span v-if="e.reaction" :key="e.reaction" class="reaction">{{ e.reaction }} 1</span>
        </div>
      </article>

      <div v-else-if="e.kind === 'tool'" class="tool" :class="e.status">
        <span class="tool-icon">{{ TOOL_ICONS[e.status] }}</span>
        <code>{{ e.name }}</code>
        <span v-if="e.preview" class="tool-preview">{{ e.preview }}</span>
        <span class="tool-status">{{ t(`tool_${e.status}`) }}</span>
      </div>

      <div v-else-if="e.kind === 'approval'" class="approval">
        <p>⚠️ {{ t('approval_title', { name: agent?.name }) }}</p>
        <p v-if="e.description" class="muted">{{ e.description }}</p>
        <pre v-if="e.command">{{ e.command }}</pre>
        <div v-if="!e.answer" class="approval-actions">
          <button v-for="c in e.choices" :key="c" class="chip" :class="{ danger: c === 'deny' }"
            @click="answerApproval(e, c)">
            {{ t(`choice_${c}`) }}
          </button>
        </div>
        <p v-else class="muted">{{ t('approval_answer', { choice: t(`choice_${e.answer}`) }) }}</p>
      </div>

      <p v-else-if="e.kind === 'error'" class="error">💥 {{ e.text }}</p>
    </template>

    <p v-if="typing" class="typing">
      <span class="dots"><i></i><i></i><i></i></span>
      {{ t('typing', { name: agent?.name }) }}
    </p>
  </section>
</template>

<script setup>
import { computed, nextTick, ref, watch } from 'vue'
import { useTranslation } from 'i18next-vue'
import { state, currentAgent, answerApproval } from '../store'
import { renderMarkdown } from '../markdown'
import { agentLook } from '../avatar'

const { t } = useTranslation()

// Tool card icon per status.
const TOOL_ICONS = { running: '⚙️', done: '✔️', failed: '✖️' }

const agent = computed(() => currentAgent() && agentLook(currentAgent(), t))
const entries = computed(() => state.entries[state.sessionId] || [])
// "… is typing" shows while the agent works but has no message streaming.
const typing = computed(() =>
  Boolean(state.runs[state.sessionId]) && !entries.value.at(-1)?.streaming
)
const scroller = ref(null)

// Consecutive text messages from the same speaker share one header.
const grouped = (i) => {
  const prev = entries.value[i - 1]
  const e = entries.value[i]
  return prev?.kind === 'text' && prev.who === e.who && e.ts - prev.ts < 300
}

// Seconds since epoch -> local '14:05'.
const clock = (ts) =>
  ts ? new Date(ts * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''

// Keep the newest message in view while it streams, unless the user
// scrolled up to read older ones.
watch(
  () => [entries.value.length, entries.value.at(-1)?.text, typing.value],
  async () => {
    const el = scroller.value
    const nearBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 160
    await nextTick()
    if (nearBottom) el.scrollTop = el.scrollHeight
  }
)
watch(() => state.sessionId, async () => {
  await nextTick()
  scroller.value.scrollTop = scroller.value.scrollHeight
})
</script>
