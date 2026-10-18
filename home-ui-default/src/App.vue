<template>
  <div class="room">
    <SessionList :class="{ open: menuOpen }" @picked="menuOpen = false" />
    <!-- Shade behind the open session list on narrow screens; a tap closes the list. -->
    <div v-if="menuOpen" class="shelf-shade" @click="menuOpen = false"></div>

    <main class="stage">
      <header class="topbar">
        <button class="chip menu-toggle" @click="menuOpen = !menuOpen">☰</button>
        <div class="stage-title">
          <strong v-if="agent" :style="{ color: agent.color }">{{ agent.name }}</strong>
        </div>
        <div class="tools">
          <!-- Reloads the whole page, for views without browser controls,
               e.g. the page embedded in an app or installed as a web app. -->
          <button class="chip reload" :title="t('refresh')" @click="reload">
            ↻ <span class="reload-label">{{ t('refresh') }}</span>
          </button>
          <label class="chip select-chip" :title="t('theme')">
            🎨
            <select v-model="theme">
              <option v-for="name in THEMES" :key="name" :value="name">
                {{ t(`theme_${name}`) }}
              </option>
            </select>
          </label>
          <LanguagePicker />
          <button class="chip" :class="{ on: drawer === 'files' }" @click="toggle('files')">
            🗂️ {{ t('files') }}
          </button>
          <button class="chip" :class="{ on: drawer === 'browser' }" @click="toggle('browser')">
            🖥️ {{ t('browser') }}
          </button>
        </div>
      </header>

      <p v-if="loadError" class="banner">{{ loadError }}</p>
      <ChatLog />
      <Composer />
    </main>

    <BrowserDrawer v-if="drawer === 'browser'" @close="drawer = null" />
    <FileDrawer v-if="drawer === 'files'" @close="drawer = null" />
    <WelcomeDialog />
  </div>
</template>

<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useTranslation } from 'i18next-vue'
import { currentAgent, loadAgents, loadSessions } from './store'
import { agentLook } from './avatar'
import SessionList from './components/SessionList.vue'
import ChatLog from './components/ChatLog.vue'
import Composer from './components/Composer.vue'
import BrowserDrawer from './components/BrowserDrawer.vue'
import FileDrawer from './components/FileDrawer.vue'
import WelcomeDialog from './components/WelcomeDialog.vue'
import LanguagePicker from './components/LanguagePicker.vue'

const { t } = useTranslation()

// Color moods defined in style.css as [data-theme="<name>"].
const THEMES = ['paper', 'night', 'candy']
// localStorage key of the chosen mood, e.g. 'night'.
const THEME_KEY = 'home.theme'

const agent = computed(() => currentAgent() && agentLook(currentAgent(), t))
// Side drawer shown on the right: 'browser', 'files' or null.
const drawer = ref(null)
// Session list visibility on narrow screens.
const menuOpen = ref(false)
const loadError = ref('')
// Theme passed by the Sandbox Management Console, mapped to a mood:
// ?theme=dark -> 'night', ?theme=light -> 'paper'; absent -> undefined.
const queryTheme = { dark: 'night', light: 'paper' }[
  new URLSearchParams(window.location.search).get('theme')
]
const theme = ref(queryTheme || localStorage.getItem(THEME_KEY) || 'paper')

watch(theme, (name) => {
  document.documentElement.dataset.theme = name
  localStorage.setItem(THEME_KEY, name)
}, { immediate: true })

const reload = () => window.location.reload()

const toggle = (name) => { drawer.value = drawer.value === name ? null : name }

onMounted(async () => {
  try {
    await loadAgents()
    await loadSessions()
  } catch (err) {
    loadError.value = err.message
  }
})
</script>
