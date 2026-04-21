# Backend Testing Reference

A methodology guide for testing backend applications.

## Testing Philosophy

The same core principles from frontend testing apply:

1. **Tests are mandatory** - Automated tests enable confident changes and guarantee specifications
2. **Test at appropriate levels** - Unit tests for pure logic, integration tests for external dependencies
3. **Write tests early** - Develop tests alongside implementation (TDD-style)
4. **Include tests in PRs** - Tests and implementation belong in the same PR

## Test Classifications

| Type | Description |
|------|-------------|
| **Unit Tests** | Isolated logic, domain models |
| **Integration Tests** | Database, external services |
| **API Tests** | Endpoint testing (HTTP/gRPC) |

## What to Test

### Guidelines

1. **Domain models** → Unit tests
   - Validation logic, business rules, state transitions

2. **Repositories/Data access** → Integration tests
   - Use real database (containerized)
   - Test queries, transactions, error handling

3. **Use cases/Services** → Unit tests with mocked dependencies
   - Business logic orchestration
   - Mock repositories and external services

4. **API handlers** → Integration or E2E tests
   - Request validation
   - Response formatting
   - Error handling

### What NOT to Test

- Don't test framework/library behavior
- Don't duplicate coverage across layers
- Don't test trivial getters/setters

---

## Test Patterns

### Table-Driven Tests

Standard pattern for multiple test cases:

```
testCases := map[string]struct {
    input    InputType
    expected OutputType
    wantErr  bool
}{
    "valid input": { ... },
    "empty input": { ... },
    "edge case":   { ... },
}

for name, tc := range testCases {
    t.Run(name, func(t *testing.T) {
        result, err := functionUnderTest(tc.input)
        // assertions
    })
}
```

Benefits:
- Easy to add new cases
- Clear test names
- Shared setup/teardown

### Testing with Mocks

1. **Define interfaces** for external dependencies
2. **Generate mocks** from interfaces (use your preferred mock generator)
3. **Inject mocks** in tests via constructor

```
// Interface
type UserRepository interface {
    Get(ctx, id) (*User, error)
    Store(ctx, user) error
}

// In tests
mockRepo := &MockUserRepository{
    GetFunc: func(ctx, id) (*User, error) {
        return &User{ID: id, Name: "Test"}, nil
    },
}
service := NewUserService(mockRepo)
```

### HTTP Handler & Middleware Tests

Use `httptest.NewRequest` + `httptest.NewRecorder` to test handlers without a real server.
For handler-level tests, inject mock dependencies directly. For router-level tests (path params, middleware chain), mount the full router via `setupRouter()`.

Test middleware in isolation: wrap a no-op `http.HandlerFunc`, call `middleware.ServeHTTP(rec, req)`, assert on status code and whether the inner handler was reached.

### Integration Tests with Containers

For database tests:
1. Start containerized database
2. Run migrations/schema
3. Execute tests
4. Container auto-terminates on cleanup

Benefits:
- Real database behavior
- Isolated per test run
- No shared state issues

### Build Tags for Integration Tests

Use `//go:build integration` to separate slow tests. Default `go test ./...` runs only unit tests; `go test -tags=integration ./...` includes integration tests. Use for anything requiring external services.

### Testing Concurrent Code

For goroutine-spawning code, synchronize with channels + `select`/`time.After` timeout (not `time.Sleep`). Always run `-race` in CI: `go test -race ./...`

---

## Test Utilities

### Fixed Clock

For time-dependent code, inject a clock interface:

```
type Clock interface {
    Now() Time
}

// Production: returns time.Now()
// Tests: returns fixed time
```

### Test Helpers

Create helpers that:
- Set up common test fixtures
- Mark themselves with `t.Helper()` for better error reporting
- Use `t.Cleanup()` for automatic teardown

### Comparison Utilities

Use diff-based comparison for complex structs:
- Shows exactly what differs
- Supports ignoring fields (timestamps, IDs)
- Better than manual field-by-field checks

### Testify

When the project uses `testify`: `require` for preconditions (stops test on failure — use when subsequent lines depend on success), `assert` for the actual assertions (logs failure, continues). Example: `require.NoError(t, err)` then `assert.Equal(t, expected, result)`.

---

## Interface-Based Design

Design for testability:

1. **Define interfaces** for dependencies
2. **Accept interfaces** in constructors
3. **Return concrete types** from constructors

```
func NewService(
    repo Repository,      // Interface
    cache Cache,          // Interface
    clock Clock,          // Interface
) *serviceImpl {
    return &serviceImpl{repo, cache, clock}
}
```

Benefits:
- Easy to mock in tests
- Clear dependency boundaries
- Compile-time interface satisfaction checks

---

## Best Practices Summary

1. **Run tests in parallel** - Use parallel test execution where safe
2. **Use context with timeout** - Prevent hanging tests
3. **Table-driven tests** - Organized, readable, extensible
4. **Use test helpers** - Mark with `t.Helper()` for better errors
5. **Automatic cleanup** - Use deferred cleanup or test hooks
6. **Mock at interface boundaries** - Not internal functions
7. **Use diff comparisons** - Better output than manual checks
8. **Use containers** - For realistic database/service tests
9. **Fixed clocks** - For deterministic time-dependent tests
10. **Black-box testing** - Test public API, not internals
