import { reactive } from 'vue'
import * as api from './api'

// localStorage key of the agent profile picked last, e.g. 'writer'.
const PROFILE_KEY = 'home.profile'

// The whole page state. Chat entries are what the log renders, one of:
//   {kind: 'text', who: 'user'|'agent', text, ts, reaction, streaming}
//   {kind: 'tool', name, preview, status: 'running'|'done'|'failed', ts}
//   {kind: 'approval', runId, requestId, command, description, choices, answer}
//   {kind: 'error', text, ts}
export const state = reactive({
  // Agent profiles: [{id, display_name}], 'default' first. Never show id;
  // agentLook() in avatar.js gives the name and avatar to show.
  agents: [],
  // Profile the composer talks to; the session list shows its chats.
  profile: localStorage.getItem(PROFILE_KEY) || 'default',
  // Web chats of the selected profile, most recently active first.
  sessions: [],
  // Open chat; null is a new chat that is created on its first message.
  sessionId: null,
  // Session id -> chat entries, for every chat opened in this page.
  entries: {},
  // Session id -> {runId} while the agent works on that chat.
  runs: {}
})

// The selected profile's {id, display_name}; undefined until agents load.
export const currentAgent = () =>
  state.agents.find((a) => a.id === state.profile) || state.agents[0]

const now = () => Date.now() / 1000

// Message content is a string or a list of parts:
// [{type: 'text', text: 'hi'}, {type: 'image_url', ...}] -> 'hi'.
function textOf(content) {
  if (typeof content === 'string') return content
  if (!Array.isArray(content)) return ''
  return content.filter((p) => p.type === 'text').map((p) => p.text).join('\n')
}

// Saved messages -> chat entries. Tool results (role 'tool') are left out;
// the tool card from the assistant's tool_calls stands for them.
function historyEntries(messages) {
  const entries = []
  for (const m of messages) {
    if (m.display_kind === 'hidden') continue
    const text = textOf(m.content)
    if (m.role === 'user' && text) {
      entries.push({ kind: 'text', who: 'user', text, ts: m.timestamp })
    }
    if (m.role === 'assistant') {
      if (text) entries.push({ kind: 'text', who: 'agent', text, ts: m.timestamp })
      for (const call of m.tool_calls || []) {
        entries.push({
          kind: 'tool', name: call.function?.name, status: 'done', ts: m.timestamp
        })
      }
    }
  }
  return entries
}

export async function loadAgents() {
  state.agents = await api.listAgents()
  if (!state.agents.some((a) => a.id === state.profile)) state.profile = 'default'
}

export async function loadSessions() {
  state.sessions = await api.listSessions(state.profile)
}

export async function selectProfile(id) {
  state.profile = id
  localStorage.setItem(PROFILE_KEY, id)
  await loadSessions()
  // Opens the profile's most recently active chat; a profile without chats
  // opens a new chat. Pinned chats may be listed out of recency order.
  const newest = state.sessions.reduce(
    (a, b) => (b.last_active > a.last_active ? b : a),
    state.sessions[0]
  )
  await openSession(newest?.id ?? null)
}

export async function openSession(id) {
  // A chat with a running turn keeps its live entries.
  if (id && !state.runs[id]) {
    state.entries[id] = historyEntries(await api.listMessages(state.profile, id))
  }
  state.sessionId = id
}

export async function togglePin(session) {
  await api.updateSession(state.profile, session.id, { pinned: !session.pinned })
  await loadSessions()
}

export async function removeSession(session) {
  await api.deleteSession(state.profile, session.id)
  delete state.entries[session.id]
  if (state.sessionId === session.id) state.sessionId = null
  await loadSessions()
}

export async function stop() {
  const runId = state.runs[state.sessionId]?.runId
  if (runId) await api.stopRun(state.profile, runId)
}

export async function answerApproval(entry, choice) {
  await api.answerApproval(state.profile, entry.runId, choice, entry.requestId)
  entry.answer = choice
}

// Sends one message and renders the reply live, Discord-style:
// 1. 'run.started' (the gateway got the message): 👀 on the user's message.
// 2. 'assistant.delta': the agent's message grows in place while it streams.
// 3. 'tool.*': a tool card per call, from running to done or failed.
// 4. 'run.completed': 👀 becomes ✅; a failure or stop becomes ❌.
export async function send(text) {
  const profile = state.profile
  let id = state.sessionId
  if (!id) {
    id = (await api.createSession(profile)).id
    state.entries[id] = []
    state.sessionId = id
  }
  const list = state.entries[id]
  list.push({ kind: 'text', who: 'user', text, ts: now(), reaction: null })
  const mine = list.at(-1)
  state.runs[id] = { runId: null }
  // The agent message currently receiving deltas; a tool call ends it.
  let reply = null
  const endReply = () => {
    if (reply) reply.streaming = false
    reply = null
  }
  const say = (body) => {
    endReply()
    list.push({ kind: 'text', who: 'agent', text: body, ts: now() })
  }

  const handlers = {
    'run.started': (data) => {
      mine.reaction = '👀'
      state.runs[id].runId = data.run_id
    },
    'assistant.delta': (data) => {
      if (!reply) {
        list.push({ kind: 'text', who: 'agent', text: '', ts: now(), streaming: true })
        reply = list.at(-1)
      }
      reply.text += data.delta
    },
    // Text the agent wrote between tool calls that was not streamed as deltas.
    'assistant.commentary': (data) => {
      if (!data.already_streamed) say(data.text)
    },
    'tool.started': (data) => {
      endReply()
      list.push({
        kind: 'tool', name: data.tool_name, preview: data.preview,
        status: 'running', ts: now()
      })
    },
    'tool.completed': (data) => finishTool(data.tool_name, 'done'),
    'tool.failed': (data) => finishTool(data.tool_name, 'failed'),
    'approval.request': (data) => {
      endReply()
      list.push({
        kind: 'approval', runId: data.run_id, requestId: data.request_id,
        command: data.command, description: data.description,
        choices: data.choices, answer: null
      })
    },
    // The final reply text; it replaces the streamed text of the same message.
    'assistant.completed': (data) => {
      if (reply) {
        reply.text = data.content || reply.text
        endReply()
      } else if (data.content) {
        say(data.content)
      }
    },
    'run.completed': () => { mine.reaction = '✅' },
    'run.failed': () => { mine.reaction = '❌' },
    'run.cancelled': () => { mine.reaction = '❌' },
    error: (data) => {
      mine.reaction = '❌'
      list.push({ kind: 'error', text: data.message, ts: now() })
    }
  }
  // The newest running card of this tool: 'terminal' -> its card.
  const finishTool = (name, status) => {
    const card = list.findLast(
      (e) => e.kind === 'tool' && e.name === name && e.status === 'running'
    )
    if (card) card.status = status
  }

  try {
    await api.streamChat(profile, id, text, (event, data) => handlers[event]?.(data))
  } catch (err) {
    mine.reaction = '❌'
    list.push({ kind: 'error', text: err.message, ts: now() })
  } finally {
    endReply()
    delete state.runs[id]
  }
  if (state.profile === profile) await loadSessions()
}
