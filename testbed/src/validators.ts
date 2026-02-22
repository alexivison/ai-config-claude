import { CreateTaskInput, UpdateTaskInput, Priority, Status } from './types';

const VALID_PRIORITIES: Priority[] = ['low', 'medium', 'high', 'critical'];
const VALID_STATUSES: Status[] = ['todo', 'in_progress', 'done', 'cancelled'];

const MAX_TITLE_LENGTH = 200;
const MAX_DESCRIPTION_LENGTH = 2000;

export function validateCreateInput(input: CreateTaskInput): string[] {
  const errors: string[] = [];

  if (!input.title) {
    errors.push('Title is required');
  }

  if (input.title && input.title.length > MAX_TITLE_LENGTH) {
    errors.push(`Title must be ${MAX_TITLE_LENGTH} characters or less`);
  }

  if (input.description && input.description.length > MAX_DESCRIPTION_LENGTH) {
    errors.push(`Description must be ${MAX_DESCRIPTION_LENGTH} characters or less`);
  }

  if (input.priority && !VALID_PRIORITIES.includes(input.priority)) {
    errors.push(`Invalid priority: ${input.priority}`);
  }

  if (input.tags) {
    if (!Array.isArray(input.tags)) {
      errors.push('Tags must be an array');
    } else if (input.tags.some(t => typeof t !== 'string')) {
      errors.push('All tags must be strings');
    }
  }

  return errors;
}

export function validateUpdateInput(input: UpdateTaskInput): string[] {
  const errors: string[] = [];

  if (input.title !== undefined && input.title.length > MAX_TITLE_LENGTH) {
    errors.push(`Title must be ${MAX_TITLE_LENGTH} characters or less`);
  }

  if (input.description !== undefined && input.description.length > MAX_DESCRIPTION_LENGTH) {
    errors.push(`Description must be ${MAX_DESCRIPTION_LENGTH} characters or less`);
  }

  if (input.status && !VALID_STATUSES.includes(input.status)) {
    errors.push(`Invalid status: ${input.status}`);
  }

  if (input.priority && !VALID_PRIORITIES.includes(input.priority)) {
    errors.push(`Invalid priority: ${input.priority}`);
  }

  if (input.tags) {
    if (!Array.isArray(input.tags)) {
      errors.push('Tags must be an array');
    } else if (input.tags.some(t => typeof t !== 'string')) {
      errors.push('All tags must be strings');
    }
  }

  return errors;
}
