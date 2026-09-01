import type { AuthRuntimeModeReader } from "../auth/runtime-mode-core";
import { createAppHealthResponse } from "./app";

export function createAppHealthGetHandler(readMode: AuthRuntimeModeReader) {
  return (request: Request) => createAppHealthResponse(readMode(request));
}
