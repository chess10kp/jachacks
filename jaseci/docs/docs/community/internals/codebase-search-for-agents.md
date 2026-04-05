# Searching the Jaseci codebase (for humans and AI agents)

This repo is a **monorepo**: several installable Python packages live at the top level. **Do not** treat the whole tree as one flat Python package — **narrow the search path** first, then search.

For contributor-oriented file layout (compiler passes, `unitree`, bootstrap), see the [Codebase Guide](../codebase-guide.md).

---

## 1. Pick the right subtree before searching

| If you care about… | Start here (path prefix) |
|--------------------|---------------------------|
| Language, compiler, `jac` CLI, LSP, core runtime | `jac/` |
| LLM / `by llm()` / Meaning Typed Programming | `jac-byllm/` |
| Full-stack / npm / client bundling | `jac-client/` |
| Deploy / scale / K8s / FastAPI integration | `jac-scale/` |
| Rich console / terminal UX | `jac-super/` |
| MCP server for Jac tooling | `jac-mcp/` |
| Extra UI plugins | `jac-plugins/` |
| Meta-package `pip install jaseci` | `jaseci-package/` |
| Public docs site | `docs/` |
| CI and release | `.github/` |

**Rule:** If a feature is “plugin-shaped,” grep or semantic-search inside that package’s folder first. If it is core language behavior, start in `jac/`.

---

## 2. Two source kinds: `.jac` and `.py`

- **`jac/jaclang/`** contains a large amount of **Jac source** (`.jac` files), not only Python.
- When looking for **behavior of the language or compiler**, search **both**:
  - `*.jac` under `jac/jaclang/`
  - `*.py` where present (bootstrap, vendored code, tests)

**Ripgrep examples (run from repo root):**

```bash
# All Jac sources mentioning a symbol (core only)
rg -n "Walker" jac/jaclang --glob '*.jac'

# Python-only (e.g. tests, small shims)
rg -n "start_cli" jac --glob '*.py'

# Every package’s declared name / scripts
rg -n "^\[project\]" -A2 */pyproject.toml jac/*/pyproject.toml 2>/dev/null
```

---

## 3. When to use exact search vs semantic search

| Goal | Prefer |
|------|--------|
| Find a **string**, **import**, **filename**, **error message** | **Ripgrep** (`rg`) or editor grep — fast, exact |
| Find **“where is X handled?”** when you do not know the name | **Semantic / codebase search** — natural-language question scoped to one directory |
| Jump to **definition** of a symbol you already see | Grep for the exact identifier, then open the file |

**Semantic search prompts work best when scoped**, e.g. “Where does `jac start` bind the HTTP server?” with target directory `jac/` (not the whole repo).

---

## 4. High-signal fixed locations (jump here first)

| Topic | Where to look |
|-------|----------------|
| CLI entry / commands | `jac/jaclang/cli/` |
| Compiler passes | `jac/jaclang/compiler/passes/` |
| Parser / lexer / core IR | `jac/jaclang/jac0core/` |
| Runtime / execution | `jac/jaclang/runtimelib/` |
| Language server | `jac/jaclang/lsp/` |
| PyPI package name and dependencies | Each package’s `pyproject.toml` (e.g. `jac/pyproject.toml`, `jaseci-package/pyproject.toml`) |

---

## 5. Ripgrep habits that avoid noise

- **Always set a path** (e.g. `jac/` or `jac-byllm/`) before searching broad terms like `plugin`, `run`, `config`.
- Use **`--glob`** to limit file types: `--glob '*.jac'`, `--glob '*.py'`, `--glob '*.toml'`.
- For **tests**, many live under `*/tests/` — narrow the path: `rg pattern jac/jaclang/tests`.

---

## 6. What not to do manually at scale

- Do not read every file in `jac/jaclang/` linearly — use **scoped grep + semantic search** from the subfolders above.
- Do not assume all implementation is Python — **include `*.jac`** when searching core language behavior.

---

## 7. Optional: parallel exploration

For **large unknown areas** (e.g. “how do plugins register?”), split the question: one search for **registration / plugin API** in `jac/`, another in the specific plugin package. Merge results instead of one unfocused repo-wide query.

---

## Related

- [Jaseci ecosystem overview](jaseci-ecosystem-overview.md)
- [Repository architecture map](jaseci-repository-map.md)
- [Codebase Guide](../codebase-guide.md)
