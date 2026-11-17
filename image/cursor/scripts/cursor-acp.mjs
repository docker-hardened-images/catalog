#!/usr/bin/env node
// acp-graceful <command> [args...]
//
// Runs an agent's built-in ACP server so that stdin EOF and SIGTERM both
// end it within acp@1's five-second shutdown bound, whichever of the two
// the agent itself honors. Either event closes the agent's stdin, the
// orderly stop every ACP server is built around; an agent still running
// after the grace period gets SIGTERM, then SIGKILL. Signals go to the
// agent's whole process group, because agents that re-exec themselves
// (gemini relaunches under a larger heap) would otherwise leave the real
// worker behind.
//
// stdout and stderr are inherited rather than piped, so protocol
// messages reach the host unbuffered and logs stay on stderr.

import { spawn } from "node:child_process";
import { constants } from "node:os";

const GRACE_MS = 2_000;

const [command, ...args] = process.argv.slice(2);
if (!command) {
  console.error("usage: acp-graceful <command> [args...]");
  process.exit(2);
}

const child = spawn(command, args, {
  stdio: ["pipe", "inherit", "inherit"],
  detached: true,
});

function signalGroup(signal) {
  try {
    process.kill(-child.pid, signal);
  } catch {
    // The group is already gone.
  }
}

let stopping = false;
function stop() {
  if (stopping) return;
  stopping = true;
  if (!child.stdin.destroyed) child.stdin.end();
  setTimeout(() => signalGroup("SIGTERM"), GRACE_MS).unref();
  setTimeout(() => signalGroup("SIGKILL"), 2 * GRACE_MS).unref();
}

process.stdin.pipe(child.stdin);
process.stdin.once("end", stop);
child.stdin.on("error", () => {});
for (const signal of ["SIGTERM", "SIGINT", "SIGHUP"]) process.on(signal, stop);

child.once("error", (error) => {
  console.error(`acp-graceful: ${command}: ${error.message}`);
  process.exit(127);
});
child.once("exit", (code, signal) => {
  process.exit(code ?? 128 + (constants.signals[signal] ?? 0));
});
