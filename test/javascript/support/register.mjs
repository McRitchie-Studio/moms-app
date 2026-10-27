// Loaded with `node --import` by test/lib/javascript_unit_test.rb. Installs
// studio-engine's shared importmap hook (lib/studio/node_tooling/node_test), so
// "slideshow/<module>" resolves to app/javascript/slideshow/<module>.js the way
// config/importmap.rb pins it in the browser, and the app's .js files load as
// the ES modules they are (the app has no package.json to say so).
// test/lib/node_tooling_test.rb holds the prefix to the importmap.
import { registerImportmapHooks } from "../../../node_modules/.studio-engine/node_test/register.mjs";

registerImportmapHooks({
  root: new URL("../../../", import.meta.url),
  prefixes: { slideshow: "app/javascript/slideshow/" },
  esmDirs: ["app/javascript/"],
});
