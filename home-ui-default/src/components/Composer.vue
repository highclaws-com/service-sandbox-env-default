<template>
  <form class="composer" @submit.prevent="submit">
    <!-- Profile picker: who this message goes to. -->
    <div class="who">
      <button type="button" class="who-button" :title="t('talking_to')" @click="pickerOpen = !pickerOpen">
        <img v-if="agent" :src="agent.avatar" alt="">
      </button>
      <ul v-if="pickerOpen" class="who-menu">
        <li v-for="a in looks" :key="a.id" :class="{ on: a.id === state.profile }"
          @click="choose(a.id)">
          <img :src="a.avatar" alt="">
          <span :style="{ color: a.color }">{{ a.name }}</span>
        </li>
      </ul>
    </div>

    <div class="field">
      <span v-if="file" class="file-tag">
        📎 {{ file.name }} <button type="button" @click="file = null">✕</button>
      </span>
      <textarea
        ref="input"
        v-model="text"
        rows="1"
        :placeholder="t('placeholder', { name: agent?.name })"
        @keydown.enter.exact.prevent="submit"
        @input="grow"
      ></textarea>
    </div>

    <label class="chip attach" :title="t('attach')">
      📎<input type="file" hidden @change="file = $event.target.files[0]; $event.target.value = ''">
    </label>
    <button v-if="busy" type="button" class="send stop" @click="stop">■ {{ t('stop') }}</button>
    <button v-else class="send" :disabled="!text.trim() && !file">{{ t('send') }} ➤</button>
  </form>
</template>

<script setup>
import { computed, nextTick, ref } from 'vue'
import { useTranslation } from 'i18next-vue'
import { state, currentAgent, selectProfile, send, stop } from '../store'
import { upload } from '../api'
import { agentLook } from '../avatar'

const { t } = useTranslation()

const agent = computed(() => currentAgent() && agentLook(currentAgent(), t))
// Every profile as shown in the picker: [{id, name, avatar, color}].
const looks = computed(() => state.agents.map((a) => agentLook(a, t)))
const busy = computed(() => Boolean(state.runs[state.sessionId]))
const text = ref('')
// File picked to attach to the next message.
const file = ref(null)
const pickerOpen = ref(false)
const input = ref(null)

async function choose(id) {
  pickerOpen.value = false
  await selectProfile(id)
}

// Textarea grows with its content up to the CSS max-height; only text
// taller than that scrolls, e.g. 3 lines -> no scrollbar, 20 lines -> scrollbar.
function grow() {
  const el = input.value
  el.style.height = 'auto'
  el.style.height = `${el.scrollHeight}px`
  el.style.overflowY = el.scrollHeight > el.clientHeight ? 'auto' : 'hidden'
}

async function submit() {
  if (busy.value) return
  let message = text.value.trim()
  const attachment = file.value
  if (!message && !attachment) return
  // The agent reads attachments from disk: 'hi' -> 'hi\nAttached file: /worktrees/uploads/a.png'.
  // A failed upload keeps the draft so the user can retry.
  if (attachment) {
    try {
      message = `${message}\n${t('attached', { path: await upload(attachment) })}`.trim()
    } catch (err) {
      alert(err.message)
      return
    }
  }
  text.value = ''
  file.value = null
  await nextTick()
  grow()
  // Failures inside a turn show in the chat; this catches the rest, e.g. creating the chat.
  await send(message).catch((err) => alert(err.message))
}
</script>
