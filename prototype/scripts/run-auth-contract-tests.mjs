import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const prototypeRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outputDirectory = mkdtempSync(join(tmpdir(), "rebuy-auth-contract-"));
const tscPath = resolve(prototypeRoot, "node_modules/.bin/tsc");

const tscArgs = [
  "--target",
  "ES2022",
  "--lib",
  "ES2022,DOM",
  "--module",
  "commonjs",
  "--moduleResolution",
  "node",
  "--esModuleInterop",
  "--strict",
  "--skipLibCheck",
  "--noEmitOnError",
  "--outDir",
  outputDirectory,
  "lib/auth/redirect.ts",
  "lib/auth/callback.ts",
  "lib/auth/callback-route.ts",
  "lib/auth/email-otp.ts",
  "lib/auth/email-otp-route.ts",
  "lib/auth/session.ts",
  "lib/supabase/config.ts",
  "lib/supabase/cookies.ts",
  "tests/auth/contract.test.ts",
];

try {
  execFileSync(tscPath, tscArgs, {
    cwd: prototypeRoot,
    stdio: "inherit",
  });

  execFileSync(
    process.execPath,
    ["--test", join(outputDirectory, "tests/auth/contract.test.js")],
    {
      cwd: prototypeRoot,
      stdio: "inherit",
    },
  );
} finally {
  rmSync(outputDirectory, { recursive: true, force: true });
}
