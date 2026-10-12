# Contributing

Thanks for helping make these patterns more useful.

## What makes a good pattern

A strong contribution includes:

1. The production problem, in plain language.
2. Runnable SQL against the synthetic demo dataset, or a clearly isolated extension of it.
3. The index, CRS, or planner assumption the pattern depends on.
4. The trade-off — memory, write cost, precision, lock risk, or operational complexity.
5. An assertion or expected result when the behavior can be tested deterministically.

## Ground rules

- Do not submit real parcel, utility, customer, infrastructure-sensitive, or personally identifying data.
- Keep coordinates and SRIDs explicit.
- Prefer `ST_DWithin` over filtering on a computed distance when an index should participate.
- Explain any use of Web Mercator for measurement; in most cases, use `geography` or an appropriate projected CRS instead.
- Run `bash scripts/run_examples.sh` before opening a pull request.

## Style

- Use lowercase SQL keywords or uppercase consistently within a file; existing files use uppercase for major clauses.
- Fully qualify demo objects with the `demo` schema.
- Make setup and pattern files safe to rerun where practical.
- Keep comments focused on why a choice is made, not a narration of obvious syntax.
