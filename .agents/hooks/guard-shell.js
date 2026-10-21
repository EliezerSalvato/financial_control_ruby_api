#!/usr/bin/env node

const HOST_TOOLS = new Set([
  "rails",
  "rspec",
  "rubocop",
  "rake",
  "bundle",
  "ci",
  "brakeman",
  "bundler-audit",
  "openapi-localize",
]);

const DESTRUCTIVE_DB = new Set([
  "db:drop",
  "db:drop:all",
  "db:reset",
  "db:migrate:reset",
  "db:purge",
  "db:purge:all",
  "db:seed:replant",
]);

const DANGEROUS_RM = new Set(["/", "/*", "~", "~/", "$HOME", "$HOME/", ".", "..", "*", "~/*", "$HOME/*"]);
const SHELLS = new Set(["sh", "bash", "zsh", "dash"]);

const OPTIONS_WITH_VALUE = new Set([
  "-f",
  "--file",
  "-p",
  "--project-name",
  "--profile",
  "--project-directory",
  "--env-file",
  "-u",
  "--user",
  "-w",
  "--workdir",
  "--entrypoint",
  "--name",
  "-v",
  "--volume",
  "--publish",
  "-l",
  "--label",
  "--index",
]);

const MAKE_VALUE_FLAGS = new Set([
  "-C",
  "--directory",
  "-f",
  "--file",
  "--makefile",
  "-I",
  "--include-dir",
  "-j",
  "--jobs",
  "-o",
  "--old-file",
]);

const GIT_VALUE_FLAGS = new Set(["-c", "-C", "--git-dir", "--work-tree", "--namespace", "--config-env"]);

const RM_MESSAGE =
  "Blocked recursive delete of a root, home, or current-directory target. Run that command yourself in a terminal if you really mean it.";
const FORCE_MESSAGE = "Blocked git push --force. Force-push is not available to the agent.";
const RESET_MESSAGE = "Blocked git reset --hard. Hard reset is not available to the agent.";
const DB_MESSAGE =
  "Blocked a destructive database task. The development database is only for migrations. Pass the test environment into the container: docker compose exec -e RAILS_ENV=test api bin/rails <task>.";
const MAKE_MESSAGE = "Blocked make target. The agent may run make ci. Other Makefile targets are for humans.";
const HOST_MESSAGE =
  "Blocked host Ruby/Rails command. Run it inside the api container: docker compose exec api <command>.";
const NEST_MESSAGE = "Blocked a nested shell command that is too deep to inspect.";

function commandOf(payload) {
  if (typeof payload.command === "string") return payload.command;
  if (payload.tool_input && typeof payload.tool_input.command === "string") return payload.tool_input.command;
  return "";
}

function isClaude(payload) {
  return Boolean(payload.tool_name || payload.hook_event_name || payload.tool_input);
}

function basename(program) {
  const parts = program.split("/");
  return parts[parts.length - 1];
}

function isAssignment(token) {
  return /^[A-Za-z_][A-Za-z0-9_]*=/.test(token);
}

function splitOutsideQuotes(input, separatorOf) {
  const parts = [];
  let current = "";
  let quote = null;

  for (let index = 0; index < input.length; index += 1) {
    const char = input[index];
    if (quote) {
      current += char;
      if (char === quote) quote = null;
      continue;
    }
    if (char === "'" || char === "\"") {
      quote = char;
      current += char;
      continue;
    }
    const size = separatorOf(input, index);
    if (size > 0) {
      parts.push(current);
      current = "";
      index += size - 1;
      continue;
    }
    current += char;
  }

  parts.push(current);
  return parts.map((part) => part.trim()).filter(Boolean);
}

function splitSegments(input) {
  return splitOutsideQuotes(input, (text, index) => {
    const pair = text.slice(index, index + 2);
    if (pair === "&&" || pair === "||") return 2;
    const char = text[index];
    if (char === ";" || char === "&" || char === "\n") return 1;
    return 0;
  });
}

function splitPipes(input) {
  return splitOutsideQuotes(input, (text, index) => {
    if (text[index] !== "|" || text[index + 1] === "|") return 0;
    return 1;
  });
}

function tokenize(command) {
  const tokens = [];
  const pattern = /"([^"]*)"|'([^']*)'|(\S+)/g;
  let match = pattern.exec(command);
  while (match) {
    tokens.push(match[1] ?? match[2] ?? match[3]);
    match = pattern.exec(command);
  }
  return tokens;
}

function peel(tokens) {
  let index = 0;
  let localTestEnv = false;

  while (index < tokens.length && isAssignment(tokens[index])) {
    if (tokens[index] === "RAILS_ENV=test") localTestEnv = true;
    index += 1;
  }

  if (tokens[index] === "sudo") {
    index += 1;
    while (index < tokens.length) {
      const token = tokens[index];
      if (isAssignment(token)) {
        if (token === "RAILS_ENV=test") localTestEnv = true;
        index += 1;
        continue;
      }
      if (token === "-u" || token === "--user" || token === "-g" || token === "--group") {
        index += 2;
        continue;
      }
      if (token.startsWith("-")) {
        index += 1;
        continue;
      }
      break;
    }
  }

  return { argv: tokens.slice(index), localTestEnv };
}

function consumeOption(argv, index) {
  const token = argv[index];
  if (token === "-e" || token === "--env") {
    return { step: argv[index + 1] === undefined ? 1 : 2, env: argv[index + 1] ?? null };
  }
  if (token.startsWith("--env=")) return { step: 1, env: token.slice("--env=".length) };
  if (token.startsWith("-e") && !token.startsWith("--") && token.length > 2) {
    return { step: 1, env: token.slice(2) };
  }
  if (OPTIONS_WITH_VALUE.has(token)) {
    return { step: argv[index + 1] === undefined ? 1 : 2, env: null };
  }
  return { step: 1, env: null };
}

function parseContainerExec(argv) {
  let index = 0;
  if (argv[0] === "docker" && argv[1] === "compose") index = 2;
  else if (argv[0] === "docker-compose") index = 1;
  else if (argv[0] === "docker" && (argv[1] === "exec" || argv[1] === "run")) index = 2;
  else return null;

  if (!(argv[0] === "docker" && (argv[1] === "exec" || argv[1] === "run"))) {
    while (index < argv.length && argv[index] !== "exec" && argv[index] !== "run") {
      if (!argv[index].startsWith("-")) return null;
      index += consumeOption(argv, index).step;
    }
    if (index >= argv.length) return null;
    index += 1;
  }

  let testEnv = false;
  while (index < argv.length && argv[index].startsWith("-") && argv[index] !== "--") {
    const consumed = consumeOption(argv, index);
    if (consumed.env === "RAILS_ENV=test") testEnv = true;
    index += consumed.step;
  }
  if (argv[index] === "--") index += 1;
  if (index < argv.length) index += 1;
  if (argv[index] === "--") index += 1;
  return { testEnv, command: argv.slice(index) };
}

function shellScript(argv) {
  if (!SHELLS.has(basename(argv[0]))) return null;
  for (let index = 1; index < argv.length; index += 1) {
    const token = argv[index];
    if (token === "-c" || token === "--command") return argv[index + 1] ?? "";
    if (token.startsWith("-") && !token.startsWith("--") && token.includes("c")) return argv[index + 1] ?? "";
    if (!token.startsWith("-")) return null;
  }
  return null;
}

function unwrapBundle(argv) {
  if (basename(argv[0]) !== "bundle") return argv;
  let index = 1;
  while (index < argv.length && argv[index].startsWith("-")) index += 1;
  if (argv[index] !== "exec") return argv;
  index += 1;
  while (index < argv.length && argv[index].startsWith("-")) index += 1;
  return argv.slice(index);
}

function hasDestructiveDbTask(argv) {
  const { argv: peeled } = peel(unwrapBundle(argv));
  if (peeled.length === 0) return false;
  const base = basename(peeled[0]);
  if (base !== "rails" && base !== "rake") return false;
  return peeled.slice(1).some((arg) => DESTRUCTIVE_DB.has(arg));
}

function isMakeCi(argv) {
  const positionals = [];
  for (let index = 1; index < argv.length; index += 1) {
    const token = argv[index];
    if (isAssignment(token)) continue;
    if (token.startsWith("-")) {
      if (MAKE_VALUE_FLAGS.has(token) && argv[index + 1] !== undefined) index += 1;
      continue;
    }
    positionals.push(token);
  }
  return positionals.length === 1 && positionals[0] === "ci";
}

function gitDenial(argv) {
  if (basename(argv[0]) !== "git") return null;
  let index = 1;
  while (index < argv.length) {
    const token = argv[index];
    if (GIT_VALUE_FLAGS.has(token)) {
      index += 2;
      continue;
    }
    if (token.startsWith("-")) {
      index += 1;
      continue;
    }
    break;
  }

  const subcommand = argv[index];
  const args = argv.slice(index + 1);
  if (subcommand === "push" && args.some((arg) => arg === "-f" || arg === "--force" || arg.startsWith("--force-with-lease"))) {
    return FORCE_MESSAGE;
  }
  if (subcommand === "reset" && args.includes("--hard")) return RESET_MESSAGE;
  return null;
}

function rmDenial(argv) {
  if (basename(argv[0]) !== "rm") return null;
  let recursive = false;
  const targets = [];
  for (let index = 1; index < argv.length; index += 1) {
    const part = argv[index];
    if (part.startsWith("-") && part.length > 1) {
      if (/[rR]/.test(part.slice(1))) recursive = true;
      continue;
    }
    targets.push(part);
  }
  if (recursive && targets.some((target) => DANGEROUS_RM.has(target))) return RM_MESSAGE;
  return null;
}

function evaluateCommand(command, ctx, depth) {
  if (depth > 5) return NEST_MESSAGE;
  for (const segment of splitSegments(command)) {
    for (const stage of splitPipes(segment)) {
      const message = evaluateArgv(tokenize(stage), ctx, depth);
      if (message) return message;
    }
  }
  return null;
}

function evaluateArgv(tokens, ctx, depth) {
  const { argv, localTestEnv } = peel(tokens);
  if (argv.length === 0) return null;

  const base = basename(argv[0]);
  if (base === "rm") return rmDenial(argv);
  if (base === "git") return gitDenial(argv);

  const container = parseContainerExec(argv);
  if (container) {
    return evaluateArgv(container.command, { insideDocker: true, testEnv: container.testEnv }, depth);
  }

  if (base === "env") {
    let index = 1;
    let testEnv = ctx.testEnv || localTestEnv;
    while (index < argv.length && (argv[index].startsWith("-") || isAssignment(argv[index]))) {
      if (argv[index] === "RAILS_ENV=test") testEnv = true;
      if ((argv[index] === "-u" || argv[index] === "--unset") && argv[index + 1] !== undefined) index += 2;
      else index += 1;
    }
    return evaluateArgv(argv.slice(index), { insideDocker: ctx.insideDocker, testEnv }, depth);
  }

  const script = shellScript(argv);
  if (script !== null) {
    return evaluateCommand(script, { insideDocker: ctx.insideDocker, testEnv: ctx.testEnv || localTestEnv }, depth + 1);
  }

  const here = { insideDocker: ctx.insideDocker, testEnv: ctx.testEnv || localTestEnv };

  if (base === "make" || base === "gmake") {
    if (!isMakeCi(argv)) return MAKE_MESSAGE;
    return null;
  }

  if (!here.insideDocker && HOST_TOOLS.has(base)) return HOST_MESSAGE;
  if (hasDestructiveDbTask(argv) && !here.testEnv) return DB_MESSAGE;
  return null;
}

function denial(command) {
  if (!command.trim()) return null;
  return evaluateCommand(command, { insideDocker: false, testEnv: false }, 0);
}

function emit(payload, message) {
  if (isClaude(payload)) {
    const hookSpecificOutput = message
      ? { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: message }
      : { hookEventName: "PreToolUse", permissionDecision: "allow" };
    process.stdout.write(JSON.stringify({ hookSpecificOutput }));
    return;
  }

  if (message) {
    process.stdout.write(JSON.stringify({ permission: "deny", user_message: message, agent_message: message }));
    return;
  }

  process.stdout.write(JSON.stringify({ permission: "allow" }));
}

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  let payload = {};
  try {
    payload = raw.trim() ? JSON.parse(raw) : {};
  } catch {
    emit({}, null);
    return;
  }
  emit(payload, denial(commandOf(payload)));
});
