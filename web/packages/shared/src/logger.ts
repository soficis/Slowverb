type LogLevel = "debug" | "info" | "warn" | "error";

type LogEntry = {
  readonly timestamp: number;
  readonly level: LogLevel;
  readonly message: string;
  readonly data?: unknown;
};

const MAX_LOG_ENTRIES = 100;
const logBuffer: LogEntry[] = [];

export function log(level: LogLevel, message: string, data?: unknown): void {
  const entry: LogEntry = {
    timestamp: Date.now(),
    level,
    message,
    data,
  };

  logBuffer.push(entry);
  if (logBuffer.length > MAX_LOG_ENTRIES) {
    logBuffer.shift();
  }

  const env = (import.meta as { env?: { DEV?: boolean } }).env;
  if (env?.DEV && typeof console?.[level] === "function") {
    console[level](message, data);
  }
}

export function getLogDump(): string {
  return logBuffer
    .map(
      (entry) =>
        `[${new Date(entry.timestamp).toISOString()}] ${entry.level}: ${entry.message}`
    )
    .join("\n");
}
