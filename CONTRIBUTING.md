# Contributing to llm-armory

Thanks for wanting to help.

## Community

| Kind | Where |
|---|---|
| Questions, ideas, show-and-tell | [Discussions](https://github.com/muslewski/llm-armory/discussions) |
| Bugs & concrete feature requests | [Issues](https://github.com/muslewski/llm-armory/issues/new/choose) |
| Security | [SECURITY.md](./SECURITY.md) — private only |

Please follow the [Code of Conduct](./CODE_OF_CONDUCT.md).

## Dev setup

```bash
git clone https://github.com/muslewski/llm-armory.git
cd llm-armory
npm install -g .   # or: ln -sfn "$PWD/bin/llm" ~/.local/bin/armory
```

## Checks

```bash
bash tests/run.sh
bash -n bin/llm
```

### Notes

- **Never commit real API keys** under `presets/providers/` — only `*.env.example` with placeholders.
- The launcher must stay no-TTY safe: chrome on stderr only.
- Prefer fixing `bin/llm` + tests over large rewrites of fleet helpers.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/) preferred
(`feat:`, `fix:`, `docs:`, `chore:`).

## Pull requests

1. Branch from `main`, keep the diff focused.
2. Fill in the PR template.
3. Link issues with `Fixes #…` when applicable.
