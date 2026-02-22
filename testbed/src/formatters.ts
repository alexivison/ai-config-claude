import { Task, Priority } from './types';

const PRIORITY_LABELS: Record<Priority, string> = {
  low: 'LOW',
  medium: 'MED',
  high: 'HIGH',
  critical: 'CRIT',
};

export function formatTaskSummary(task: Task): string {
  const priority = PRIORITY_LABELS[task.priority];
  const check = task.status === 'done' ? 'x' : task.status === 'cancelled' ? '-' : ' ';
  return `[${check}] [${priority}] ${task.title}`;
}

export function formatTaskDetail(task: Task): string {
  const lines = [
    formatTaskSummary(task),
    `  ID: ${task.id}`,
    `  Status: ${task.status}`,
    `  Priority: ${task.priority}`,
  ];

  if (task.description) {
    lines.push(`  Description: ${task.description}`);
  }

  if (task.tags.length > 0) {
    lines.push(`  Tags: ${task.tags.join(', ')}`);
  }

  lines.push(`  Created: ${formatDate(task.createdAt)}`);
  lines.push(`  Updated: ${formatDate(task.updatedAt)}`);

  return lines.join('\n');
}

export function formatDate(date: Date): string {
  return date.toISOString().split('T')[0];
}

export function formatTaskList(tasks: Task[]): string {
  if (tasks.length === 0) {
    return 'No tasks found.';
  }
  return tasks.map(formatTaskSummary).join('\n');
}
