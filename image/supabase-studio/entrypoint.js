"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawn } = require("child_process");

// Shell-free port of the official node image's docker-entrypoint.sh, which the
// upstream supabase/studio image inherits from node:22-slim. Dispatch must stay
// behavior-identical so migrating users are never surprised:
//
//   if [ "${1#-}" != "${1}" ] ||               # first arg is a flag
//      [ -z "$(command -v "${1}")" ] ||        # or not a resolvable command
//      { [ -f "${1}" ] && ! [ -x "${1}" ]; }   # or a non-executable file (cwd)
//   then set -- node "$@"; fi
//   exec "$@"

// A command only resolves to something exec-able if it is a regular file with
// the execute bit; directories pass a bare X_OK check but are not commands.
// Handing a directory to node (exit 1) is a deliberate divergence from
// upstream, whose shell exec dies with 126/Permission denied — both reject
// the input, and node's diagnostic beats a misleading spawn EACCES.
function isExecutableFile(candidate) {
  try {
    if (!fs.statSync(candidate).isFile()) {
      return false;
    }
    fs.accessSync(candidate, fs.constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

// command -v: a name containing "/" resolves as a path; a bare name searches
// PATH, skipping empty segments.
function resolveCommand(command) {
  if (command.includes("/")) {
    return isExecutableFile(command);
  }

  return (process.env.PATH || "")
    .split(path.delimiter)
    .some(
      (directory) =>
        directory !== "" && isExecutableFile(path.join(directory, command)),
    );
}

// Upstream's third condition: a cwd-relative file without the execute bit is
// treated as a script for node, even when a same-named command exists on PATH.
function isNonExecutableFile(candidate) {
  try {
    return fs.statSync(candidate).isFile() && !isExecutableFile(candidate);
  } catch {
    return false;
  }
}

const args = process.argv.slice(2);
if (args.length === 0) {
  console.error("supabase-studio entrypoint: no command specified");
  process.exit(1);
}

const command = args[0];
if (
  command === "" ||
  command.startsWith("-") ||
  !resolveCommand(command) ||
  isNonExecutableFile(command)
) {
  args.unshift(process.execPath);
}

// dumb-init runs as PID 1 and delivers every signal it receives to this
// launcher's entire process group, so the workload child gets each signal
// directly and orphaned grandchildren are reaped by dumb-init. Under dumb-init
// the launcher only has to survive those group-delivered signals (default
// disposition would kill it) long enough to mirror how the child exits —
// relaying would double-deliver. Invoked without dumb-init (an --entrypoint
// override), the launcher is PID 1 itself and nothing else delivers to the
// child, so it falls back to relaying. Registered before spawn so a signal in
// the startup window cannot kill the launcher first.
let child = null;
const signals = [
  "SIGINT",
  "SIGTERM",
  "SIGHUP",
  "SIGQUIT",
  "SIGUSR1",
  "SIGUSR2",
  "SIGWINCH",
];
for (const signal of signals) {
  process.on(signal, () => {
    if (process.pid === 1 && child) {
      child.kill(signal);
    }
  });
}

// spawn() throws synchronously on some invalid inputs instead of emitting
// "error"; both paths must produce the same clean diagnostic.
try {
  child = spawn(args[0], args.slice(1), { stdio: "inherit" });
} catch (error) {
  console.error(`supabase-studio entrypoint: ${error.message}`);
  process.exit(1);
}

child.on("error", (error) => {
  console.error(`supabase-studio entrypoint: ${error.message}`);
  process.exit(1);
});

child.on("exit", (code, signal) => {
  if (signal) {
    process.exit(128 + (os.constants.signals[signal] || 0));
  }
  process.exit(code === null ? 1 : code);
});
