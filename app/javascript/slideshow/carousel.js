// The carousel's scroll decisions. No DOM: the controller reads the track and
// applies the answer.

// The gap between cards (gap-4).
export const GAP_PX = 16

// How far one step moves: a card and its gap, or the track's width with no card.
export function stepWidth(cardWidth, trackWidth) {
  return cardWidth == null ? trackWidth : cardWidth + GAP_PX
}

// A step forward: back to the start from the end, one step otherwise.
export function nextScroll(track, step) {
  if (Math.ceil(track.scrollLeft + track.clientWidth) >= track.scrollWidth - 2) return { to: 0 }
  return { by: step }
}

// A step back: around to the end from the start, one step otherwise.
export function prevScroll(track, step) {
  if (track.scrollLeft <= 2) return { to: track.scrollWidth }
  return { by: -step }
}
