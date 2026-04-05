# Jaseci ecosystem overview

This page summarizes **what this repository is** and how the installable pieces relate. For compiler internals, contribution workflows, and file-level navigation, see the [Codebase Guide](../codebase-guide.md).

---

## What this repository is

This is the **Jaseci** monorepo: the **Jac** programming language and the plugins and tooling that ship as one ecosystem. The public pitch is “designed for humans and AI to build together.”

Jac uses Python-like syntax, compiles to **Python bytecode**, **JavaScript**, and **native machine code**, and adds AI-oriented features, **graph/walker** modeling, and **deployment** tooling.

---

## Packages in this repo (top-level)

| Path | PyPI-style name | Role |
|------|-----------------|------|
| `jac/` | `jaclang` | Language: compiler, runtime, `jac` CLI, language server. **Core** of the stack. |
| `jac-byllm/` | `byllm` | LLM integration (“Meaning Typed Programming”), e.g. `by llm()`. |
| `jac-client/` | `jac-client` | Full-stack web: bundling with the npm ecosystem, JSX-style UI. |
| `jac-scale/` | `jac-scale` | Deployment and scaling (FastAPI, Redis, MongoDB, Kubernetes-oriented flows). |
| `jac-super/` | `jac-super` | Enhanced console output (Rich). |
| `jac-mcp/` | `jac-mcp` | MCP server for AI-assisted Jac development (validate, format, docs). |
| `jac-plugins/` | (varies) | Extra plugins (e.g. UI kits such as `jac-shadcn`). |
| `jaseci-package/` | `jaseci` | **Meta-package** — depends on the packages above so `pip install jaseci` pulls the bundle. |
| `docs/` | — | MkDocs site, assets, scripts (not a single PyPI package). |

The **VS Code extension** is maintained separately (see the root [README](https://github.com/Jaseci-Labs/jaseci) for links).

---

## Root `pyproject.toml`

The file at the repository root is **minimal**: it mainly supports tooling (for example pre-commit) by pointing at `jac/` and exposing the `jac` CLI entry. It is **not** the full story of the product — each package has its own `pyproject.toml`.

---

## Technical picture of `jaclang` (core)

- **Self-hosted language:** Much of the implementation lives in **`.jac`** files under `jac/jaclang/` (CLI, compiler passes, runtime, LSP), not only in Python.
- **Compiler pipeline:** Under `jac/jaclang/compiler/` — passes for main IR, **Python bytecode**, **ECMAScript**, **native**, plus tooling (formatter, lint), and type checking.
- **Front end / IR:** Parser, lexer, and shared structures under `jac/jaclang/jac0core/`.
- **Runtime:** `jac/jaclang/runtimelib/` — execution, storage, server integration, watchers, etc.
- **Tooling:** `jac/jaclang/cli/`, `jac/jaclang/lsp/` — CLI and language server.

---

## How users typically invoke the stack

| Command | Role |
|---------|------|
| `jac run` | Run a `.jac` file like a script. |
| `jac start` | Serve a Jac program as an API. |
| `jac start … --scale` | Scaled deployment path (via `jac-scale` and its assumptions). |
| `jac create --use client` | Scaffold a client-capable project. |
| `jac plugins` | Enable or disable plugins. |

---

## CI and releases

Under `.github/workflows/` you will find separate release flows for **jaclang**, **byllm**, **client**, **scale**, **super**, **mcp**, plus combined tests, docs, and standalone builds — consistent with **multi-package releases** from one repository.

---

## Related docs in this site

- [Codebase Guide](../codebase-guide.md) — deeper orientation for contributors (bootstrap, passes, `unitree`, plugins).
- [Repository architecture map](jaseci-repository-map.md) — diagrams and command-to-package mapping.
- [Codebase search for agents](codebase-search-for-agents.md) — how to search without reading the tree by hand.
