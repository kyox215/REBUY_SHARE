import type { AuthRuntimeMode } from "../auth/runtime-mode-core";

const noStoreHeaders = {
  "Cache-Control": "no-store",
};

export function createAppHealthResponse(mode: AuthRuntimeMode) {
  return Response.json(
    { status: "healthy", mode },
    { status: 200, headers: noStoreHeaders },
  );
}
