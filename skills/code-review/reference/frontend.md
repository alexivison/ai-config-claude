# Code Review Reference - Frontend

Guidelines specific to frontend code (React, TypeScript, CSS).

---

## CSS Rules

1. **Use modern CSS**:
   - `gap` instead of margin-top/left for spacing
   - Logical properties (`margin-inline`, `margin-block`)
   - `flex` and `grid` for layout

2. **Class naming**:
   - camelCase (CSS Modules compatibility)
   - Root element always named `root`
   - Name by concern (e.g., `userProfile`, `FooContainer`, `FooWrapper`)

3. **Dynamic styles**:
   - Prefer: HTML attributes (`data-*`, `aria-*`) → CSS variables → `style` prop
   - Only use `style` prop for truly dynamic values

4. **Anti-patterns**:
   - **No CSS nesting** — Use flat selectors with data attributes:
     ```css
     /* Good */
     .root[data-editing="true"] { ... }

     /* Bad */
     .root {
       &[data-editing="true"] { ... }
     }
     ```
   - **Parent controls child sizing** — Child components don't set their own margins:
     ```css
     /* Good - parent controls layout */
     .container > .item { margin-bottom: 8px; }

     /* Bad - child controls its own spacing */
     .item { margin-bottom: 8px; }
     ```
   - **Don't specify defaults** (e.g., `flex-direction: row` is default)

---

## React Patterns

### useState

- **Callback form required** for updates based on current value:
  ```tsx
  // Good - guaranteed latest value
  setCount(prev => prev + 1);

  // Bad - may use stale value
  setCount(count + 1);
  ```

### Props

- **Discriminated unions** over boolean props:
  ```tsx
  // Good
  type Props = { status: 'idle' } | { status: 'loading' } | { status: 'error'; message: string };

  // Bad
  type Props = { isLoading?: boolean; isError?: boolean; errorMessage?: string };
  ```

- **`readonly`** for props to prevent mutation:
  ```tsx
  type Props = { readonly items: readonly Item[] };
  ```

### Naming

- Event handlers use **`handle` prefix**:
  ```tsx
  // Good
  const handleClick = () => {};

  // Bad
  const onClick = () => {};  // Looks like a prop
  ```

---

## TypeScript Patterns

- **Discriminated unions** over optional properties for explicit state modeling
- **Avoid `default`** in switch for union types — hides missing case handling
- **Names reflect purpose**, not implementation (`visibleItems` not `filteredArray`)

---

## Testing Rules

### MUST Follow

1. **Clear test intent**:
   ```tsx
   // Good: Intent is documented
   it("returns false for integers that are not natural numbers", () => {});

   // Bad: Requires domain knowledge to understand
   it("0 returns false", () => {});

   // Very Bad: Just code translation
   it("0 === false", () => {});
   ```

2. **Test specification, not implementation** - If implementation changes require test changes, question if you're testing the right thing

3. **No test dependencies** - Tests must pass in any order

4. **Always release test doubles** - Use `onTestFinished()` or RAII patterns

### Testing Approach

| Code Type | Test Type |
|-----------|-----------|
| Pure business logic | Unit tests (1:1 coverage) |
| External integrations | Integration tests (Repository layer) |
| User-facing components | Component tests (form level, not individual inputs) |
| Hooks from components | Component tests (not hook tests) |

### What NOT to Test
- Don't re-test lower-level logic at higher levels
- Don't test external module behavior
- Don't exhaustively test input variations at page level

---

## Testing Philosophy

### Principles

- **DAMP over DRY** — Descriptive And Meaningful Phrases preferred over deduplication in tests
- **userEvent over fireEvent** — More realistic user interaction simulation
- **Separate test cases** — No conditional assertions within a single test
- **Test names include expected outcome** — "returns empty array when input is null"

### Test Structure

```tsx
// Good - clear, isolated, descriptive
it("returns empty array when input is null", () => {
  expect(transform(null)).toEqual([]);
});

it("returns transformed items when input is valid", () => {
  expect(transform([1, 2])).toEqual([2, 4]);
});

// Bad - conditional logic, unclear intent
it("handles input correctly", () => {
  if (input === null) {
    expect(transform(input)).toEqual([]);
  } else {
    expect(transform(input)).toEqual([2, 4]);
  }
});
```

---

## Red Flags Checklist

Quick pattern checks during frontend review:

- [ ] **Boolean prop explosion** — 3+ boolean props suggest need for discriminated union
- [ ] **useEffect for derived state** — Should be inline computation or useMemo
- [ ] **useState without callback** — Updates based on current value need callback form
- [ ] **Props not readonly** — Mutable props risk accidental mutation
- [ ] **Comments don't match code** — Outdated or misleading documentation
- [ ] **Default clause in union switch** — Hides missing case handling
- [ ] **Over-memoization** — useMemo/useCallback on simple values
- [ ] **Inconsistent handler naming** — Mix of `on*` and `handle*` prefixes
- [ ] **Hardcoded values in comments** — Use semantic terms ("maximum" not "100")
- [ ] **Implementation-focused names** — `filteredArray` instead of `visibleItems`
