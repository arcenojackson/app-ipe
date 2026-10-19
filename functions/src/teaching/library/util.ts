export function chunks<T>(list: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let i = 0; i < list.length; i += size) {
    result.push(list.slice(i, i + size));
  }
  return result;
}

export function unique<T>(list: T[]): T[] {
  return [...new Set(list)];
}

// Efeitos de melhor esforço (notificação, auditoria): falha só é registrada.
export async function safely(
  label: string,
  fn: () => Promise<unknown>
): Promise<void> {
  try {
    await fn();
  } catch (error) {
    console.error(`Falha em ${label}:`, error);
  }
}
