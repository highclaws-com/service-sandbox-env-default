<template>
  <aside class="drawer drawer-wide">
    <header class="drawer-head">
      <h2>🖥️ {{ t('browser') }}</h2>
      <button class="chip" :title="t('refresh')" @click="loadTabs">↻</button>
      <button class="chip" :title="t('close')" @click="$emit('close')">✕</button>
    </header>
    <p class="muted">{{ t('browser_hint') }}</p>
    <div class="tabs">
      <div v-for="tab in tabs" :key="tab.id" class="tab" :class="{ on: tab.visible }">
        <button class="tab-pick" :title="tab.url" @click="show(tab.id)">
          <img v-if="tab.faviconUrl" :src="tab.faviconUrl" alt="">
          <span class="tab-title">{{ tab.title || tab.url }}</span>
        </button>
        <button class="tab-close" :title="t('close_tab')" @click="close(tab.id)">✕</button>
      </div>
    </div>
    <!-- Shared browser stream URI; keep unchanged. Shows the active tab.
         cast=1 hides the player's own controls but keeps mouse and keyboard
         input; mute_chat=1 disables chat sounds. -->
    <iframe class="screen" src="/web-browser-webrtc/?cast=1&mute_chat=1"></iframe>
  </aside>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import { useTranslation } from 'i18next-vue'
import { listTabs, switchTab, closeTab } from '../api'

defineEmits(['close'])
const { t } = useTranslation()

// Page tabs of the shared browser: [{id, title, url, faviconUrl, visible}].
const tabs = ref([])

async function loadTabs() {
  tabs.value = (await listTabs()).filter((tab) => tab.type === 'page')
}

async function show(id) {
  await switchTab(id)
  await loadTabs()
}

async function close(id) {
  await closeTab(id)
  await loadTabs()
}

onMounted(loadTabs)
</script>
