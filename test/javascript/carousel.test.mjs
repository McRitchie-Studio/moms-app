// [unit] The carousel's scroll decisions (app/javascript/slideshow/carousel.js).
import { test } from "node:test"
import assert from "node:assert/strict"
// The importmap name the carousel controller imports, resolved by the shared
// hook test/javascript/support/register.mjs installs.
import { GAP_PX, stepWidth, nextScroll, prevScroll } from "slideshow/carousel"

const track = (scrollLeft) => ({ scrollLeft, clientWidth: 900, scrollWidth: 2700 })

test("a step is one card and its gap", () => {
  assert.equal(GAP_PX, 16)
  assert.equal(stepWidth(284, 900), 300)
  assert.equal(stepWidth(0, 900), 16)
})

test("a step is the track's width when it holds no card", () => {
  assert.equal(stepWidth(null, 900), 900)
})

test("next steps forward until the end, then returns to the start", () => {
  assert.deepEqual(nextScroll(track(0), 300), { by: 300 })
  assert.deepEqual(nextScroll(track(1500), 300), { by: 300 })
  assert.deepEqual(nextScroll(track(1797.6), 300), { to: 0 })
  assert.deepEqual(nextScroll(track(1800), 300), { to: 0 })
})

test("prev steps back until the start, then goes around to the end", () => {
  assert.deepEqual(prevScroll(track(900), 300), { by: -300 })
  assert.deepEqual(prevScroll(track(3), 300), { by: -300 })
  assert.deepEqual(prevScroll(track(2), 300), { to: 2700 })
  assert.deepEqual(prevScroll(track(0), 300), { to: 2700 })
})
