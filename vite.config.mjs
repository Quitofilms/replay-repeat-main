import { defineConfig } from "vite";
import { ember } from "@nullvoxpopuli/ember-vite";
import Icons from "unplugin-icons/vite";

/**
 * The output of unplugin-icons' "ember" compiler, with a `.js` id.
 * Babel only compiles modules with an extension,
 * and without Babel the `template()` call bundles the template compiler.
 */
const emberIcon = {
  extension: "js",
  compiler: (svg) => {
    const template = JSON.stringify(svg.replace("<svg", "<svg ...attributes"));

    return `import { template } from "@ember/template-compiler";\nexport default template(${template});`;
  },
};

const handoutBuild = process.env.VITE_HANDOUT === "true";

export default defineConfig({
  base: process.env.VITE_BASE_PATH ?? "/",
  plugins: [ember(), Icons({ compiler: emberIcon })],
  build: {
    outDir: "dist",
    emptyOutDir: !handoutBuild,
    rollupOptions: {
      input: handoutBuild ? "handout/index.html" : "index.html",
    },
  },
});
