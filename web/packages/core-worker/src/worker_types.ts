export interface WorkerFsBridge {
  writeFile(path: string, data: Uint8Array): void;
  readFile(path: string): unknown;
  unlink(path: string): void;
  analyzePath(path: string): { exists?: boolean };
}

export interface WorkerFfmpegBridge {
  FS: WorkerFsBridge;
  exec(...args: string[]): number;
  setLogger?(handler: (entry: { type: string; message: string }) => void): void;
  setProgress?(handler: (entry: { progress: number }) => void): void;
}
