import { Task, CreateTaskInput, UpdateTaskInput, Status } from './types';
import { validateCreateInput, validateUpdateInput } from './validators';

let nextId = 1;
const tasks: Map<string, Task> = new Map();

export function createTask(input: CreateTaskInput): Task {
  const errors = validateCreateInput(input);
  if (errors.length > 0) {
    throw new Error(`Validation failed: ${errors.join(', ')}`);
  }

  const id = String(nextId++);
  const now = new Date();

  const task: Task = {
    id,
    title: input.title,
    description: input.description ?? '',
    status: 'todo',
    priority: input.priority ?? 'medium',
    tags: input.tags ?? [],
    createdAt: now,
    updatedAt: now,
  };

  tasks.set(id, task);
  return task;
}

export function getTask(id: string): Task | undefined {
  return tasks.get(id);
}

export function getAllTasks(): Task[] {
  return Array.from(tasks.values());
}

export function getTasksByStatus(status: Status): Task[] {
  return getAllTasks().filter(t => t.status === status);
}

export function updateTask(id: string, input: UpdateTaskInput): Task {
  const task = tasks.get(id);
  if (!task) {
    throw new Error(`Task ${id} not found`);
  }

  const errors = validateUpdateInput(input);
  if (errors.length > 0) {
    throw new Error(`Validation failed: ${errors.join(', ')}`);
  }

  const updated: Task = {
    ...task,
    ...input,
    updatedAt: new Date(),
  };

  tasks.set(id, updated);
  return updated;
}

export function deleteTask(id: string): boolean {
  return tasks.delete(id);
}

export function clearAll(): void {
  tasks.clear();
  nextId = 1;
}
