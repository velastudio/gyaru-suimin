type LogFields = Record<string, unknown>;

export function logInfo(event: string, fields: LogFields = {}) {
  console.info(
    JSON.stringify({
      level: 'info',
      event,
      ...fields,
    }),
  );
}

export function logError(
  event: string,
  error: unknown,
  fields: LogFields = {},
) {
  console.error(
    JSON.stringify({
      level: 'error',
      event,
      ...fields,
      error: serializeError(error),
    }),
  );
}

function serializeError(error: unknown) {
  if (!(error instanceof Error)) {
    return {
      message: String(error),
    };
  }

  return {
    name: error.name,
    message: error.message,
    stack: error.stack,
    cause: serializeCause(error.cause),
  };
}

function serializeCause(cause: unknown) {
  if (!cause) {
    return undefined;
  }

  if (cause instanceof Error) {
    return {
      name: cause.name,
      message: cause.message,
      stack: cause.stack,
    };
  }

  return String(cause);
}
