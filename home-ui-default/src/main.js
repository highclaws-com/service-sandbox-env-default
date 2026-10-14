import { createApp } from 'vue'
import i18next from 'i18next'
import I18NextVue from 'i18next-vue'
import LanguageDetector from 'i18next-browser-languagedetector'
import App from './App.vue'
import './style.css'

import en from './locales/en-US.json'
import de from './locales/de-DE.json'
import zh from './locales/zh-CN.json'
import zhTw from './locales/zh-TW.json'
import fr from './locales/fr-FR.json'
import ja from './locales/ja-JP.json'
import ko from './locales/ko-KR.json'
import es from './locales/es-ES.json'
import pt from './locales/pt-BR.json'

// Same languages and detection order as the Sandbox Management Console:
// ?lang=zh-CN, then cookie, then localStorage, then the browser language.
i18next.use(LanguageDetector).init({
  fallbackLng: 'en-US',
  resources: {
    'en-US': { translation: en },
    'de-DE': { translation: de },
    'zh-CN': { translation: zh },
    'zh-TW': { translation: zhTw },
    'fr-FR': { translation: fr },
    'ja-JP': { translation: ja },
    'ko-KR': { translation: ko },
    'es-ES': { translation: es },
    'pt-BR': { translation: pt }
  },
  detection: {
    order: ['querystring', 'cookie', 'localStorage', 'navigator'],
    lookupQuerystring: 'lang',
    caches: ['localStorage', 'cookie']
  }
})

const updateTitle = () => { document.title = i18next.t('title') }
i18next.on('languageChanged', updateTitle)
updateTitle()

createApp(App).use(I18NextVue, { i18next }).mount('#app')
