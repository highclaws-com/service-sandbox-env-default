<template>
  <aside class="drawer" :style="width ? { '--drawer-w': `${width}px` } : null">
    <!-- Drag to resize; double-click restores the default width. -->
    <div
      class="drawer-grip"
      role="separator"
      aria-orientation="vertical"
      :title="t('resize_drawer')"
      @pointerdown="startDrag"
      @dblclick="reset"
    ></div>
    <header class="drawer-head">
      <h2>{{ title }}</h2>
      <button class="chip" :title="t('refresh')" @click="$emit('refresh')">↻</button>
      <button class="chip" :title="t('close')" @click="$emit('close')">✕</button>
    </header>
    <!-- Only the body scrolls, so the header and grip stay put. -->
    <div class="drawer-body"><slot /></div>
  </aside>
</template>

<script setup>
import { ref } from 'vue'
import { useTranslation } from 'i18next-vue'

// title: heading with its emoji, e.g. '🗂️ Files'.
defineProps({ title: { type: String, required: true } })
defineEmits(['refresh', 'close'])
const { t } = useTranslation()

// Width in px chosen by dragging, shared by every drawer; null -> CSS default.
// style.css clamps it to the window, so a stored width never overflows.
const WIDTH_KEY = 'home.drawerWidth'
const width = ref(Number(localStorage.getItem(WIDTH_KEY)) || null)

// The drawer sits on the right, so dragging the left edge left widens it.
function startDrag(e) {
  if (e.button !== 0) return
  const grip = e.currentTarget
  const drawer = grip.parentElement
  const startX = e.clientX
  const startWidth = drawer.getBoundingClientRect().width
  let moved = false
  grip.setPointerCapture(e.pointerId)
  // Stops iframes (the browser stream) from swallowing the drag.
  document.body.classList.add('resizing')

  const move = (ev) => {
    moved = true
    width.value = Math.round(startWidth + startX - ev.clientX)
  }
  const stop = () => {
    grip.removeEventListener('pointermove', move)
    grip.removeEventListener('pointerup', stop)
    grip.removeEventListener('pointercancel', stop)
    document.body.classList.remove('resizing')
    // A plain click (or the first half of a double-click) keeps the default.
    if (!moved) return
    // Saves the width actually shown, after the CSS clamp.
    width.value = Math.round(drawer.getBoundingClientRect().width)
    localStorage.setItem(WIDTH_KEY, width.value)
  }
  grip.addEventListener('pointermove', move)
  grip.addEventListener('pointerup', stop)
  grip.addEventListener('pointercancel', stop)
}

function reset() {
  width.value = null
  localStorage.removeItem(WIDTH_KEY)
}
</script>
