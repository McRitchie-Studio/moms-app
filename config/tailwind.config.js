const execSync = require('child_process').execSync
const studioPath = execSync('bundle show studio-engine').toString().trim()

// Shared color palette + theme from the studio engine (CSS-var driven roles).
const studioColors = require(`${studioPath}/tailwind/studio.tailwind.config.js`)

// Safelist all shades/opacities of the dynamic `primary` brand color so the
// theme's CSS-var utilities are never purged.
const shades = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900]
const utilities = ['bg', 'text', 'border']
const opacities = [5, 10, 20, 30, 40, 50]
const safelist = [
  ...utilities.map(util => `${util}-primary`),
  ...utilities.flatMap(util => opacities.map(op => `${util}-primary/${op}`)),
  ...shades.flatMap(shade =>
    utilities.map(util => `${util}-primary-${shade}`)
  ),
  ...shades.flatMap(shade =>
    utilities.flatMap(util => opacities.map(op => `${util}-primary-${shade}/${op}`))
  ),
]

module.exports = {
  darkMode: 'class',
  content: [
    './app/views/**/*.{erb,html}',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    // Load-bearing: the engine's @utility classes only emit when Tailwind sees
    // them used, so its views must be in the content scan.
    `${studioPath}/app/views/**/*.{erb,html}`,
  ],
  safelist,
  theme: studioColors.theme,
}
