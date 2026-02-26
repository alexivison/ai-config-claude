---
paths: ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"]
---

# TypeScript Rules

- Prefer `type` over `interface`
- Avoid `any`/`unknown` — comment if necessary
- Avoid `as` type assertions — prefer type predicates, runtime validation (schema `.parse()` etc.), or restructuring code so TypeScript can infer the type naturally.
- Use `readonly` for props
- Prefer discriminated unions over optional properties
- Avoid `default` in switch for union types (hides exhaustiveness)
- Names reflect purpose, not implementation: `isFeatureEnabled` not `thresholdCheck`
