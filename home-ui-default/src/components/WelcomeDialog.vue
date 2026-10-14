<template>
  <div v-if="open" class="veil">
    <div class="welcome" role="dialog" aria-modal="true">
      <span class="welcome-stamp">✂ DEMO</span>
      <LanguagePicker class="welcome-language" />
      <h2>{{ t('welcome_title') }}</h2>
      <p>{{ t('welcome_body') }}</p>
      <label class="check">
        <input v-model="hide" type="checkbox"> {{ t('welcome_hide') }}
      </label>
      <button class="send" @click="close">{{ t('welcome_ok') }}</button>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useTranslation } from 'i18next-vue'
import LanguagePicker from './LanguagePicker.vue'

const { t } = useTranslation()

// localStorage key set to 'true' once the user asks not to see this again.
const HIDE_KEY = 'home.welcome.hidden'

const open = ref(localStorage.getItem(HIDE_KEY) !== 'true')
const hide = ref(false)

function close() {
  if (hide.value) localStorage.setItem(HIDE_KEY, 'true')
  open.value = false
}
</script>
