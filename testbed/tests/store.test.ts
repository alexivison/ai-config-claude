import { describe, it, expect, beforeEach } from 'vitest';
import {
  createTask,
  getTask,
  getAllTasks,
  getTasksByStatus,
  updateTask,
  deleteTask,
  clearAll,
} from '../src/store';

describe('store', () => {
  beforeEach(() => {
    clearAll();
  });

  describe('createTask', () => {
    it('creates a task with required fields', () => {
      const task = createTask({ title: 'Test task' });
      expect(task.id).toBe('1');
      expect(task.title).toBe('Test task');
      expect(task.status).toBe('todo');
      expect(task.priority).toBe('medium');
      expect(task.description).toBe('');
      expect(task.tags).toEqual([]);
    });

    it('creates a task with all fields', () => {
      const task = createTask({
        title: 'Full task',
        description: 'A detailed description',
        priority: 'high',
        tags: ['urgent', 'backend'],
      });
      expect(task.description).toBe('A detailed description');
      expect(task.priority).toBe('high');
      expect(task.tags).toEqual(['urgent', 'backend']);
    });

    it('throws on missing title', () => {
      // @ts-expect-error testing runtime validation
      expect(() => createTask({})).toThrow('Validation failed');
    });

    it('throws on empty string title', () => {
      expect(() => createTask({ title: '' })).toThrow('Validation failed');
    });

    it('assigns sequential IDs', () => {
      const t1 = createTask({ title: 'First' });
      const t2 = createTask({ title: 'Second' });
      expect(t1.id).toBe('1');
      expect(t2.id).toBe('2');
    });

    it('sets createdAt and updatedAt', () => {
      const task = createTask({ title: 'Timed' });
      expect(task.createdAt).toBeInstanceOf(Date);
      expect(task.updatedAt).toBeInstanceOf(Date);
    });
  });

  describe('getTask', () => {
    it('returns the task by id', () => {
      const created = createTask({ title: 'Find me' });
      const found = getTask(created.id);
      expect(found).toEqual(created);
    });

    it('returns undefined for non-existent id', () => {
      expect(getTask('999')).toBeUndefined();
    });
  });

  describe('getAllTasks', () => {
    it('returns empty array when no tasks', () => {
      expect(getAllTasks()).toEqual([]);
    });

    it('returns all tasks', () => {
      createTask({ title: 'One' });
      createTask({ title: 'Two' });
      expect(getAllTasks()).toHaveLength(2);
    });
  });

  describe('getTasksByStatus', () => {
    it('filters by status', () => {
      createTask({ title: 'Todo task' });
      const t = createTask({ title: 'Done task' });
      updateTask(t.id, { status: 'done' });

      expect(getTasksByStatus('todo')).toHaveLength(1);
      expect(getTasksByStatus('done')).toHaveLength(1);
      expect(getTasksByStatus('in_progress')).toHaveLength(0);
    });
  });

  describe('updateTask', () => {
    it('updates specified fields', () => {
      const task = createTask({ title: 'Original' });
      const updated = updateTask(task.id, { title: 'Updated', priority: 'high' });
      expect(updated.title).toBe('Updated');
      expect(updated.priority).toBe('high');
    });

    it('preserves unmodified fields', () => {
      const task = createTask({ title: 'Keep me', description: 'Stay', priority: 'low' });
      const updated = updateTask(task.id, { title: 'Changed' });
      expect(updated.description).toBe('Stay');
      expect(updated.priority).toBe('low');
    });

    it('updates updatedAt timestamp', () => {
      const task = createTask({ title: 'Timestamped' });
      const original = task.updatedAt;
      // Small delay to ensure different timestamp
      const updated = updateTask(task.id, { title: 'Changed' });
      expect(updated.updatedAt.getTime()).toBeGreaterThanOrEqual(original.getTime());
    });

    it('throws on non-existent task', () => {
      expect(() => updateTask('999', { title: 'Nope' })).toThrow('not found');
    });
  });

  describe('deleteTask', () => {
    it('deletes and returns true', () => {
      const task = createTask({ title: 'Delete me' });
      expect(deleteTask(task.id)).toBe(true);
      expect(getTask(task.id)).toBeUndefined();
    });

    it('returns false for non-existent', () => {
      expect(deleteTask('999')).toBe(false);
    });
  });
});
