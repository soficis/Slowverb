export interface WorkerProgressState {
  stage?: string;
  offset: number;
  scale: number;
}

export function withProgressStageState(
  state: WorkerProgressState,
  stage: string,
  offset: number,
  scale: number,
  run: () => void
): void {
  const prevStage = state.stage;
  const prevOffset = state.offset;
  const prevScale = state.scale;

  state.stage = stage;
  state.offset = offset;
  state.scale = scale;
  try {
    run();
  } finally {
    state.stage = prevStage;
    state.offset = prevOffset;
    state.scale = prevScale;
  }
}
