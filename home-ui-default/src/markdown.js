import { marked } from 'marked'
import DOMPurify from 'dompurify'

// Links in agent replies open in a new tab instead of replacing this page.
DOMPurify.addHook('afterSanitizeAttributes', (node) => {
  if (node.tagName === 'A') {
    node.setAttribute('target', '_blank')
    node.setAttribute('rel', 'noopener noreferrer')
  }
})

// Agent Markdown -> sanitized HTML: '**hi**' -> '<p><strong>hi</strong></p>'.
export const renderMarkdown = (text) =>
  DOMPurify.sanitize(marked.parse(text, { breaks: true }))
