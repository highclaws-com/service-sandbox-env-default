<template>
  <label class="chip select-chip" :title="t('language')">
    🌐
    <select :value="i18next.language" @change="i18next.changeLanguage($event.target.value)">
      <option v-for="(label, code) in LANGUAGES" :key="code" :value="code">{{ label }}</option>
    </select>
  </label>
</template>

<script setup>
import { useTranslation } from 'i18next-vue'

const { t, i18next } = useTranslation()

// Same language list as the Sandbox Management Console.
const LANGUAGES = {
  'en-US': 'English',
  'de-DE': 'Deutsch',
  'fr-FR': 'Français',
  'zh-CN': '简体中文',
  'zh-TW': '繁體中文',
  'ja-JP': '日本語',
  'ko-KR': '한국어',
  'es-ES': 'Español',
  'pt-BR': 'Português'
}
</script>
