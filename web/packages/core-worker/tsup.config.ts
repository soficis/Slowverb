import { defineConfig } from "tsup";

export default defineConfig({
  entry: ["src/worker.ts"],
  format: ["esm"],
  dts: true,
  clean: true,
  outDir: "dist",
  treeshake: true,
  splitting: false,
  noExternal: ["@slowverb/shared", "@ffmpeg/core"],
  platform: "browser",
  shims: false,
  esbuildOptions(options) {
    options.external ??= [];
    options.external.push("module", "fs", "path", "url");
  },
});
