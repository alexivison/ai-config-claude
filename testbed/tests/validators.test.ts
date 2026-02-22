import { describe, it, expect } from 'vitest';
import { validateCreateInput, validateUpdateInput } from '../src/validators';

describe('validateCreateInput', () => {
  it('returns no errors for valid input', () => {
    expect(validateCreateInput({ title: 'Valid task' })).toEqual([]);
  });

  it('returns error when title is missing', () => {
    // @ts-expect-error testing runtime validation
    const errors = validateCreateInput({});
    expect(errors).toContain('Title is required');
  });

  it('returns error when title is empty string', () => {
    const errors = validateCreateInput({ title: '' });
    expect(errors).toContain('Title is required');
  });

  it('returns error when title exceeds max length', () => {
    const errors = validateCreateInput({ title: 'a'.repeat(201) });
    expect(errors.some(e => e.includes('200 characters'))).toBe(true);
  });

  it('returns error for invalid priority', () => {
    // @ts-expect-error testing runtime validation
    const errors = validateCreateInput({ title: 'Test', priority: 'urgent' });
    expect(errors.some(e => e.includes('Invalid priority'))).toBe(true);
  });

  it('returns error when tags is not an array', () => {
    // @ts-expect-error testing runtime validation
    const errors = validateCreateInput({ title: 'Test', tags: 'not-array' });
    expect(errors.some(e => e.includes('Tags must be an array'))).toBe(true);
  });

  it('accepts valid optional fields', () => {
    const errors = validateCreateInput({
      title: 'Full',
      description: 'A description',
      priority: 'high',
      tags: ['a', 'b'],
    });
    expect(errors).toEqual([]);
  });
});

describe('validateUpdateInput', () => {
  it('returns no errors for valid input', () => {
    expect(validateUpdateInput({ title: 'Updated' })).toEqual([]);
  });

  it('returns no errors for empty input', () => {
    expect(validateUpdateInput({})).toEqual([]);
  });

  it('returns error for invalid status', () => {
    // @ts-expect-error testing runtime validation
    const errors = validateUpdateInput({ status: 'archived' });
    expect(errors.some(e => e.includes('Invalid status'))).toBe(true);
  });

  it('returns error when title exceeds max length', () => {
    const errors = validateUpdateInput({ title: 'a'.repeat(201) });
    expect(errors.some(e => e.includes('200 characters'))).toBe(true);
  });
});
