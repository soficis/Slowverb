import { defineConfig } from "tsup";

export default defineConfig({
  entry: ["src/index.ts"],
  format: ["esm"],
  dts: true,
  clean: true,
  outDir: "dist",
  treeshake: true,
  splitting: false,
  noExternal: ["@slowverb/shared", "@slowverb/core-worker", "tone"],
  platform: "browser",
  shims: false,
});
