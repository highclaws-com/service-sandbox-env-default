import SHA256 from 'crypto-js/sha256'
import { createAvatar } from '@dicebear/core'
import * as pixelArt from '@dicebear/pixel-art'

// Agents look the same as in the console: DiceBear pixel-art seeded by the
// SHA-256 hex of the trimmed, lowercased display name. Keep these DiceBear
// versions; other versions draw other characters.
const seedOf = (name) => SHA256(name.trim().toLowerCase()).toString()

// Display name -> avatar data URI, so rendering does not redraw avatars.
const avatars = new Map()

// How an agent appears, from its display name, as in the console: a missing
// name shows the localized default name, e.g. {display_name: null} with
// t('default_agent') = '默认助手' -> name '默认助手' and that name's avatar.
// color is a stable name color, like a Discord role color: 'hsl(212 70% 45%)'.
export function agentLook(agent, t) {
  const name = agent.display_name?.trim() || t('default_agent')
  if (!avatars.has(name)) {
    avatars.set(name, createAvatar(pixelArt, { seed: seedOf(name) }).toDataUri())
  }
  const hue = parseInt(seedOf(name).slice(0, 6), 16) % 360
  return { id: agent.id, name, avatar: avatars.get(name), color: `hsl(${hue} 70% 45%)` }
}
