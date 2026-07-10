#!/usr/bin/env bun
// PostToolUse guardrail for llm executor children (Write|Edit|MultiEdit).
//
// Weak free-pool models write deliberation prose into source files, dump
// mangled tool-call syntax as content, and import modules/exports that do
// not exist (2026-07-06 bake-off postmortem: all three failure modes, in
// 4 of 6 children). Each is machine-detectable the moment the file lands:
//   1. transport garbage:   <tool_call> / <function= text in file content
//   2. deliberation prose:  fails to parse as TS/JS
//   3. phantom imports:     relative or @/ specifier resolving to no file,
//                           or a named import absent from the target module
//
// Exit 2 feeds stderr straight back to the model as a blocking correction.
// Anything uncertain fails OPEN (exit 0) — this is a tripwire, not a compiler.

const EXT_LOADERS = {
  ".ts": "ts",
  ".tsx": "tsx",
  ".js": "js",
  ".jsx": "jsx",
  ".mjs": "js",
  ".cjs": "js",
};
const RESOLVE_EXTS = ["", ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".json"];
const INDEX_EXTS = ["/index.ts", "/index.tsx", "/index.js", "/index.jsx"];

import { readFileSync, existsSync, statSync } from "node:fs";
import { dirname, extname, resolve, join } from "node:path";

function fail(msgs) {
  process.stderr.write(
    "post-edit-check found problems in this file — fix them now:\n" +
      msgs.map((m) => `  - ${m}`).join("\n") +
      "\nIf an import target genuinely exists elsewhere, Read the real file and use its exact path and export names.\n",
  );
  process.exit(2);
}

function tryResolve(spec, fromDir, repoRoot) {
  const bases = [];
  if (spec.startsWith("./") || spec.startsWith("../")) {
    bases.push(resolve(fromDir, spec));
  } else if (spec.startsWith("@/") && repoRoot) {
    // Next.js convention: "@/*" maps to "./src/*" or "./*"
    bases.push(join(repoRoot, "src", spec.slice(2)));
    bases.push(join(repoRoot, spec.slice(2)));
  } else {
    return { checked: false };
  }
  for (const base of bases) {
    for (const ext of RESOLVE_EXTS) {
      const p = base + ext;
      if (existsSync(p) && statSync(p).isFile()) return { checked: true, path: p };
    }
    for (const idx of INDEX_EXTS) {
      const p = base + idx;
      if (existsSync(p)) return { checked: true, path: p };
    }
  }
  return { checked: true, path: null };
}

function findRepoRoot(dir) {
  let cur = dir;
  for (let i = 0; i < 12; i++) {
    if (existsSync(join(cur, "tsconfig.json")) || existsSync(join(cur, "package.json"))) return cur;
    const parent = dirname(cur);
    if (parent === cur) break;
    cur = parent;
  }
  return null;
}

// Verify named/default imports exist in the resolved module. Conservative:
// non-code targets (assets/json — the bundler synthesizes their exports),
// any `export *` re-export, or an unreadable/huge target skip the check.
function missingExports(targetPath, names, wantsDefault) {
  if (!(extname(targetPath) in EXT_LOADERS)) return [];
  let src;
  try {
    if (statSync(targetPath).size > 512 * 1024) return [];
    src = readFileSync(targetPath, "utf8");
  } catch {
    return [];
  }
  if (/export\s+\*/.test(src)) return [];
  const missing = [];
  if (wantsDefault && !/export\s+default\b/.test(src)) missing.push("default");
  for (const name of names) {
    const direct = new RegExp(
      `export\\s+(?:declare\\s+)?(?:abstract\\s+)?(?:async\\s+)?(?:const|let|var|function|class|type|interface|enum)\\s+${name}\\b`,
    );
    const braced = new RegExp(`export\\s+(?:type\\s+)?\\{[^}]*\\b${name}\\b[^}]*\\}`);
    // export const { Link, useRouter } = factory(...)  /  export const [a, b] = ...
    const destructured = new RegExp(
      `export\\s+(?:const|let|var)\\s*[\\{\\[][^}\\]]*\\b${name}\\b[^}\\]]*[\\}\\]]\\s*=`,
    );
    if (!direct.test(src) && !braced.test(src) && !destructured.test(src)) missing.push(name);
  }
  return missing;
}

async function main() {
  let input;
  try {
    input = JSON.parse(await Bun.stdin.text());
  } catch {
    return; // fail open
  }
  const filePath = input?.tool_input?.file_path;
  if (!filePath) return;
  const loader = EXT_LOADERS[extname(filePath)];
  if (!loader) return;

  let content;
  try {
    content = readFileSync(filePath, "utf8");
  } catch {
    return;
  }

  const problems = [];

  // 1. mangled tool-call syntax dumped as file content
  if (/<tool_call>|<function=/.test(content)) {
    problems.push(
      "file contains raw tool-call syntax (<tool_call> / <function=) — that is not source code; rewrite the file with only real code",
    );
  }

  // 2. must parse — deliberation prose ("We need to import...") is a syntax error
  try {
    new Bun.Transpiler({ loader }).transformSync(content);
  } catch (e) {
    const detail = String(e?.message ?? e).split("\n")[0];
    problems.push(
      `file does not parse as ${loader.toUpperCase()} (${detail}) — file content must be only code and comments, never prose or deliberation`,
    );
  }

  // 3. phantom imports (only when the file parses — garbage in, garbage out)
  if (problems.length === 0) {
    const fromDir = dirname(resolve(filePath));
    const repoRoot = findRepoRoot(fromDir);
    const importRe =
      /(?:import|export)\s+(?:type\s+)?([\w$]+)?\s*,?\s*(?:\{([^}]*)\})?\s*(?:from\s+)?["']([^"']+)["']/g;
    for (const m of content.matchAll(importRe)) {
      const [, defaultName, namedBlock, spec] = m;
      if (!spec.startsWith("./") && !spec.startsWith("../") && !spec.startsWith("@/")) continue;
      const res = tryResolve(spec, fromDir, repoRoot);
      if (!res.checked) continue;
      if (!res.path) {
        problems.push(
          `import "${spec}" resolves to no file — Read the module you meant and use its real path`,
        );
        continue;
      }
      const names = (namedBlock ?? "")
        .split(",")
        .map((s) => s.trim().replace(/^type\s+/, "").split(/\s+as\s+/)[0])
        .filter((s) => s && /^[\w$]+$/.test(s));
      const missing = missingExports(res.path, names, Boolean(defaultName));
      if (missing.length) {
        problems.push(
          `"${spec}" has no export named: ${missing.join(", ")} — Read ${res.path} and copy the exact export names`,
        );
      }
    }
  }

  if (problems.length) fail(problems);
}

await main();
