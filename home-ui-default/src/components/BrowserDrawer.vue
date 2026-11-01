<template>
  <aside class="drawer drawer-wide">
    <header class="drawer-head">
      <h2>🖥️ {{ t('browser') }}</h2>
      <button class="chip" :title="t('refresh')" @click="loadTabs">↻</button>
      <button class="chip" :title="t('close')" @click="$emit('close')">✕</button>
    </header>
    <p class="muted">{{ t('browser_hint') }}</p>
    <div ref="strip" class="tabs" @wheel="onWheel">
      <div v-for="tab in tabs" :key="tab.id" class="tab" :class="{ on: tab.visible }">
        <button class="tab-pick" :title="tab.url" @click="show(tab.id)">
          <img v-if="tab.faviconUrl" :src="tab.faviconUrl" alt="">
          <span class="tab-title">{{ tab.title || tab.url }}</span>
        </button>
        <button class="tab-close" :title="t('close_tab')" @click="close(tab.id)">✕</button>
      </div>
      <button class="tab-new" :title="t('new_tab')" :disabled="opening" @click="open">+</button>
    </div>
    <!-- Shared browser stream URI; keep unchanged. Shows the active tab.
         cast=1 hides the player's own controls but keeps mouse and keyboard
         input; mute_chat=1 disables chat sounds. -->
    <iframe class="screen" src="/web-browser-webrtc/?cast=1&mute_chat=1"></iframe>
  </aside>
</template>

<script setup>
import { nextTick, onMounted, ref } from 'vue'
import i18next from 'i18next'
import { useTranslation } from 'i18next-vue'
import { listTabs, switchTab, closeTab, newTab } from '../api'

defineEmits(['close'])
const { t } = useTranslation()

// Page tabs of the shared browser: [{id, title, url, faviconUrl, visible}].
const tabs = ref([])

// Tab strip scrolls sideways with no visible scrollbar.
const strip = ref(null)

// Vertical mouse wheel scrolls the strip horizontally.
function onWheel(e) {
  const el = strip.value
  if (!el || el.scrollWidth <= el.clientWidth) return
  if (Math.abs(e.deltaY) <= Math.abs(e.deltaX)) return
  e.preventDefault()
  el.scrollLeft += e.deltaY
}

async function loadTabs() {
  tabs.value = (await listTabs()).filter((tab) => tab.type === 'page')
  await nextTick()
  strip.value?.querySelector('.tab.on')?.scrollIntoView({ block: 'nearest', inline: 'nearest', behavior: 'smooth' })
}

async function show(id) {
  await switchTab(id)
  await loadTabs()
}

async function close(id) {
  await closeTab(id)
  await loadTabs()
}

// Opens Google in a new tab using the page's mood and language, then shows it.
// gl=us keeps the sandbox's location off the Google homepage; Google needs an
// explicit hl only for English (same as ui_web_browser).
const DARK_THEMES = ['night']
const opening = ref(false)

async function open() {
  if (opening.value) return
  opening.value = true
  try {
    const language = i18next.language || 'en-US'
    const url = language === 'en-US'
      ? `https://www.google.com/?hl=${language}&gl=us`
      : 'https://www.google.com/?gl=us'
    const theme = document.documentElement.dataset.theme || 'paper'
    const colorScheme = DARK_THEMES.includes(theme) ? 'dark' : 'light'
    const result = await newTab(url, colorScheme, language)
    if (result?.id) await switchTab(result.id)
    await loadTabs()
  } finally {
    opening.value = false
  }
}

onMounted(loadTabs)
</script>
