import { execFileSync, spawn } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { selectAllowedPublicKey } from "./p2l-amr-preflight-config.mjs";

const PROTOTYPE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const WORKTREE_ROOT = resolve(PROTOTYPE_ROOT, "..");
const SUPABASE_HOME = "/private/tmp/rebuy-local-auth-supabase-home";
const LOCAL_SUPABASE_URL = "http://127.0.0.1:55321/";
const NEXT_ENTRYPOINT = resolve(
  PROTOTYPE_ROOT,
  "node_modules/next/dist/bin/next",
);

function fail(category) {
  console.error(`${category}_FAIL`);
  process.exit(1);
}

function readLocalSupabaseConfig() {
  let output;
  try {
    output = execFileSync("supabase", ["status", "-o", "json"], {
      cwd: WORKTREE_ROOT,
      encoding: "utf8",
      env: {
        ...process.env,
        SUPABASE_HOME,
        SUPABASE_TELEMETRY_DISABLED: "1",
      },
      maxBuffer: 1024 * 1024,
      stdio: ["ignore", "pipe", "ignore"],
    });
  } catch {
    fail("LOCAL_SUPABASE_STATUS");
  }

  let status;
  try {
    status = JSON.parse(output);
  } catch {
    fail("LOCAL_SUPABASE_STATUS");
  }

  const apiUrl = status?.API_URL;
  const publicKey = selectAllowedPublicKey(status);
  let normalizedUrl;
  try {
    normalizedUrl = new URL(apiUrl).href;
  } catch {
    fail("LOCAL_SUPABASE_CONFIG");
  }

  if (normalizedUrl !== LOCAL_SUPABASE_URL || !publicKey) {
    fail("LOCAL_SUPABASE_CONFIG");
  }

  return { publicKey };
}

if (process.versions.node.split(".")[0] !== "22") {
  fail("NODE_VERSION");
}

const { publicKey } = readLocalSupabaseConfig();
console.log("LOCAL_AUTH_DEV_CONFIG_PASS");

const child = spawn(
  process.execPath,
  [NEXT_ENTRYPOINT, "dev", "--hostname", "127.0.0.1", "--port", "3000"],
  {
    cwd: PROTOTYPE_ROOT,
    env: {
      ...process.env,
      SUPABASE_URL: LOCAL_SUPABASE_URL,
      SUPABASE_PUBLISHABLE_KEY: publicKey,
    },
    stdio: "inherit",
  },
);

child.once("error", () => fail("NEXT_DEV_START"));
child.once("exit", (code, signal) => {
  if (signal) {
    process.exit(signal === "SIGINT" ? 130 : 143);
    return;
  }
  process.exit(code ?? 1);
});

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.once(signal, () => {
    if (child.exitCode === null && child.signalCode === null) {
      child.kill(signal);
    }
  });
}
