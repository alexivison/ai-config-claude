import { describe, it, expect } from 'vitest';
import { formatTaskSummary, formatTaskDetail, formatDate, formatTaskList } from '../src/formatters';
import { Task } from '../src/types';

function makeTask(overrides: Partial<Task> = {}): Task {
  return {
    id: '1',
    title: 'Test task',
    description: '',
    status: 'todo',
    priority: 'medium',
    tags: [],
    createdAt: new Date('2025-01-15'),
    updatedAt: new Date('2025-01-15'),
    ...overrides,
  };
}

describe('formatTaskSummary', () => {
  it('formats a todo task', () => {
    expect(formatTaskSummary(makeTask())).toBe('[ ] [MED] Test task');
  });

  it('formats a done task', () => {
    expect(formatTaskSummary(makeTask({ status: 'done' }))).toBe('[x] [MED] Test task');
  });

  it('formats a cancelled task', () => {
    expect(formatTaskSummary(makeTask({ status: 'cancelled' }))).toBe('[-] [MED] Test task');
  });

  it('shows priority labels', () => {
    expect(formatTaskSummary(makeTask({ priority: 'critical' }))).toContain('[CRIT]');
    expect(formatTaskSummary(makeTask({ priority: 'high' }))).toContain('[HIGH]');
    expect(formatTaskSummary(makeTask({ priority: 'low' }))).toContain('[LOW]');
  });
});

describe('formatTaskDetail', () => {
  it('includes all basic fields', () => {
    const output = formatTaskDetail(makeTask());
    expect(output).toContain('ID: 1');
    expect(output).toContain('Status: todo');
    expect(output).toContain('Priority: medium');
  });

  it('includes description when present', () => {
    const output = formatTaskDetail(makeTask({ description: 'Details here' }));
    expect(output).toContain('Description: Details here');
  });

  it('includes tags when present', () => {
    const output = formatTaskDetail(makeTask({ tags: ['api', 'urgent'] }));
    expect(output).toContain('Tags: api, urgent');
  });
});

describe('formatDate', () => {
  it('formats as YYYY-MM-DD', () => {
    expect(formatDate(new Date('2025-06-15T10:30:00Z'))).toBe('2025-06-15');
  });
});

describe('formatTaskList', () => {
  it('returns message when empty', () => {
    expect(formatTaskList([])).toBe('No tasks found.');
  });

  it('formats multiple tasks', () => {
    const tasks = [makeTask({ title: 'First' }), makeTask({ title: 'Second' })];
    const output = formatTaskList(tasks);
    expect(output).toContain('First');
    expect(output).toContain('Second');
    expect(output.split('\n')).toHaveLength(2);
  });
});
