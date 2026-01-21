# React Rules

- Avoid `React.FC` - use explicit return types (e.g., `const Foo = ({ bar }: Props): JSX.Element => ...`)
- Avoid hardcoding texts - use i18n libraries or other localization methods
- Extract complex inline conditionals in JSX props to named handlers for readability
- Prefer dot notation (`obj.prop`) over bracket notation (`obj['prop']`) for property access
