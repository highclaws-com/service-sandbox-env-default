// Sandbox service APIs used by this page. /home/agent/home-ui-demo/index.html
// documents each endpoint in more detail.

// Hermes API key configured for this sandbox; keep it unchanged.
// Central gateway verifies the visitor's JWT uid matches the sandbox owner.
const KEY = 'hermes-api-server-key'

// Hermes API prefix per agent profile:
// 'default' -> /openai-endpoint/..., 'writer' -> /openai-endpoint/p/writer/...
const hermes = (profile, path) =>
  profile === 'default'
    ? `/openai-endpoint${path}`
    : `/openai-endpoint/p/${profile}${path}`

async function request(url, options = {}) {
  const res = await fetch(url, {
    ...options,
    headers: { Authorization: `Bearer ${KEY}`, ...options.headers }
  })
  if (!res.ok) throw new Error(`${res.status} ${await res.text()}`)
  return res
}

const json = (url, options) => request(url, options).then((res) => res.json())

const withJson = (method, body) => ({
  method,
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(body)
})

// Agent profiles -> [{id, display_name}]; 'default' is always first.
export const listAgents = () =>
  json('/mgr/api/v1/agents').then((res) => res.agents)

// Web chats of one agent -> [{id, title, preview, pinned, last_active}].
// source=api_server excludes chats from messaging apps.
export const listSessions = (profile) =>
  json(hermes(profile, '/api/sessions?source=api_server&limit=100'))
    .then((res) => res.data)

export const createSession = (profile) =>
  json(hermes(profile, '/api/sessions'), withJson('POST', {}))
    .then((res) => res.session)

// Accepts {pinned}, {title} or {archived}.
export const updateSession = (profile, id, fields) =>
  json(hermes(profile, `/api/sessions/${id}`), withJson('PATCH', fields))

export const deleteSession = (profile, id) =>
  request(hermes(profile, `/api/sessions/${id}`), { method: 'DELETE' })

// Saved history -> [{id, role, content, tool_calls, tool_call_id, timestamp}].
export const listMessages = (profile, id) =>
  json(hermes(profile, `/api/sessions/${id}/messages`))
    .then((res) => res.data)

// Sends one message and calls onEvent(name, payload) for every SSE event until
// the turn ends. Closing this request interrupts the agent's turn.
export async function streamChat(profile, id, message, onEvent) {
  const res = await request(
    hermes(profile, `/api/sessions/${id}/chat/stream`),
    withJson('POST', { message })
  )
  const reader = res.body.pipeThrough(new TextDecoderStream()).getReader()
  let buffer = ''
  while (true) {
    const { done, value } = await reader.read()
    if (done) return
    buffer += value
    const frames = buffer.split('\n\n')
    buffer = frames.pop()
    for (const frame of frames) {
      const event = frame.match(/^event: (.*)$/m)?.[1]
      const data = frame.match(/^data: (.*)$/m)?.[1]
      if (event && data) onEvent(event, JSON.parse(data))
    }
  }
}

export const stopRun = (profile, runId) =>
  json(hermes(profile, `/v1/runs/${runId}/stop`), { method: 'POST' })

// choice: one of the approval.request event's choices, e.g. 'once' or 'deny'.
export const answerApproval = (profile, runId, choice, requestId) =>
  json(
    hermes(profile, `/v1/runs/${runId}/approval`),
    withJson('POST', { choice, request_id: requestId })
  )

// Shared browser: tabs -> [{id, title, url, faviconUrl, type, visible}].
export const listTabs = () => json('/web-browser/api/tabs')

export const switchTab = (id) =>
  json(`/web-browser/api/switch-tab/${id}`, { method: 'POST' })

// File API paths omit the /worktrees prefix: '/' lists /worktrees.
async function fileRequest(url, options) {
  const res = await fetch(url, options)
  if (!res.ok) throw new Error(`${res.status} ${await res.text()}`)
  return res.json()
}

// -> [{name, path, isDir, size, mtime, ext}]
export const listFiles = (dir) =>
  fileRequest(
    `/file-api/api/files?dir=${encodeURIComponent(dir)}&sortBy=name&sortOrder=asc`
  ).then((res) => res.items)

// '/notes/a b.png' -> '/file-api/api/file/content?path=%2Fnotes%2Fa%20b.png'
export const fileContentUrl = (path) =>
  `/file-api/api/file/content?path=${encodeURIComponent(path)}`

// '/notes/a b.png' -> '/file-browser/notes/a%20b.png?mode=preview'
export const filePreviewUrl = (path) =>
  `/file-browser${path.split('/').map(encodeURIComponent).join('/')}?mode=preview`

// Uploads into /worktrees/uploads and returns the path the agent sees,
// e.g. 'photo.png' -> '/worktrees/uploads/photo.png'.
export async function upload(file) {
  // The folder API reports an error when the folder exists; that is expected.
  await fetch('/file-api/api/folders', withJson('POST', { dir: '/', name: 'uploads' }))
  const body = new FormData()
  body.append('file', file)
  const res = await fileRequest('/file-api/api/upload?dir=/uploads/', {
    method: 'POST',
    body
  })
  return `/worktrees${res.file.path}`
}
