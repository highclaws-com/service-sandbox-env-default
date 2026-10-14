<template>
  <aside class="drawer">
    <header class="drawer-head">
      <h2>🗂️ {{ t('files') }}</h2>
      <button class="chip" :title="t('refresh')" @click="load">↻</button>
      <button class="chip" :title="t('close')" @click="$emit('close')">✕</button>
    </header>
    <div class="crumbs">
      <button class="chip" :disabled="dir === '/'" @click="open(parent)">⬑ {{ t('up') }}</button>
      <code>/worktrees{{ dir === '/' ? '' : dir }}</code>
    </div>
    <p v-if="error" class="error">{{ error }}</p>
    <ul class="files">
      <li v-for="item in items" :key="item.path" @click="item.isDir ? open(item.path) : preview(item)">
        <span class="file-icon">{{ item.isDir ? '📁' : iconOf(item.ext) }}</span>
        <span class="file-name">{{ item.name }}</span>
        <span v-if="!item.isDir" class="muted">{{ size(item.size) }}</span>
      </li>
      <li v-if="!items.length && !error" class="muted">{{ t('files_empty') }}</li>
    </ul>
    <figure v-if="image" class="file-peek">
      <img :src="image" alt="">
    </figure>
  </aside>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useTranslation } from 'i18next-vue'
import { listFiles, fileContentUrl, filePreviewUrl } from '../api'

defineEmits(['close'])
const { t } = useTranslation()

// Folder shown, as a File API path: '/' is /worktrees, '/docs' is /worktrees/docs.
const dir = ref('/')
const items = ref([])
const error = ref('')
// Inline preview URL of the image clicked last.
const image = ref(null)

// '/docs/notes' -> '/docs'; '/docs' -> '/'.
const parent = computed(() => dir.value.replace(/\/[^/]+\/?$/, '') || '/')

const IMAGE_EXTS = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg']
// File extension -> icon: 'pdf' -> '📕'; unknown -> '📄'.
const ICONS = { pdf: '📕', md: '📝', txt: '📝', csv: '📊', xlsx: '📊', zip: '📦', mp4: '🎬', mp3: '🎵' }
const iconOf = (ext) => {
  const e = ext?.replace('.', '').toLowerCase()
  return IMAGE_EXTS.includes(e) ? '🖼️' : ICONS[e] || '📄'
}

// 2048 -> '2.0 KB'.
const size = (bytes) => {
  const units = ['B', 'KB', 'MB', 'GB']
  let n = bytes
  let i = 0
  while (n >= 1024 && i < units.length - 1) { n /= 1024; i++ }
  return `${i ? n.toFixed(1) : n} ${units[i]}`
}

async function load() {
  error.value = ''
  try {
    items.value = await listFiles(dir.value)
  } catch (err) {
    items.value = []
    error.value = err.message
  }
}

async function open(path) {
  dir.value = path
  image.value = null
  await load()
}

// Images preview inline; other files open in the full file browser.
function preview(item) {
  if (IMAGE_EXTS.includes(item.ext?.replace('.', '').toLowerCase())) {
    image.value = fileContentUrl(item.path)
  } else {
    window.open(filePreviewUrl(item.path), '_blank')
  }
}

onMounted(load)
</script>
