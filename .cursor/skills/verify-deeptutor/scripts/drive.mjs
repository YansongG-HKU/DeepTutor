#!/usr/bin/env node
// Drive one mapped DeepTutor web journey and write proof under EVIDENCE_DIR.
import { createRequire } from "node:module";
import { spawnSync } from "node:child_process";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, "../../../..");
const require = createRequire(path.join(repoRoot, "web/package.json"));
const { chromium } = require("playwright");

const feature = process.argv[2];
const features = new Set([
  "notebooks",
  "appearance",
  "task-board",
  "chat",
  "knowledge",
]);

function fail(message) {
  console.error(`drive: ${message}`);
  process.exitCode = 1;
}

function loadState() {
  const statePath =
    process.env.VERIFY_STATE ||
    path.join(scriptDir, "../run/current.env");
  if (!existsSync(statePath)) {
    throw new Error(`No verification state at ${statePath}. Run scripts/launch.sh first.`);
  }
  const env = {};
  for (const line of require("node:fs").readFileSync(statePath, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const index = trimmed.indexOf("=");
    if (index === -1) continue;
    env[trimmed.slice(0, index)] = trimmed.slice(index + 1);
  }
  for (const key of [
    "RUN_ID",
    "HOME_DIR",
    "FRONTEND_URL",
    "BACKEND_URL",
    "EVIDENCE_DIR",
    "VERSION",
  ]) {
    if (!env[key]) throw new Error(`State file ${statePath} is missing ${key}`);
  }
  env.STATE_PATH = statePath;
  return env;
}

async function shot(page, dir, name) {
  await mkdir(dir, { recursive: true });
  await page.screenshot({ path: path.join(dir, `${name}.png`), fullPage: true });
  const aria = await page.locator("body").ariaSnapshot();
  await writeFile(
    path.join(dir, `${name}.aria.txt`),
    typeof aria === "string" ? aria : JSON.stringify(aria, null, 2),
    "utf8",
  );
}

function python() {
  const venv = path.join(repoRoot, ".venv/bin/python");
  return existsSync(venv) ? venv : "python3";
}

function runCli(home, args) {
  const result = spawnSync(python(), ["-m", "deeptutor_cli.main", ...args], {
    cwd: repoRoot,
    env: { ...process.env, DEEPTUTOR_HOME: home },
    encoding: "utf8",
  });
  return result;
}

async function writeResult(dir, result) {
  await mkdir(dir, { recursive: true });
  await writeFile(
    path.join(dir, "result.json"),
    JSON.stringify(result, null, 2) + "\n",
    "utf8",
  );
}

async function openApp(page, env) {
  await page.goto(env.FRONTEND_URL + "/", { waitUntil: "domcontentloaded" });
  // Expanded sidebar: logo plus wordmark, both alt "DeepTutor", so the link
  // name is "DeepTutor DeepTutor". Collapsed sidebar: aria-label "DeepTutor".
  const logo = page.locator('a[href="/"]').filter({
    has: page.getByRole("img", { name: "DeepTutor", exact: true }),
  });
  await logo.first().waitFor({ timeout: 120_000 });
  if ((await page.title()) !== "DeepTutor") {
    throw new Error(`Document title is ${JSON.stringify(await page.title())}, expected DeepTutor`);
  }
}

async function driveNotebooks(page, env, dir) {
  await openApp(page, env);
  await page.getByRole("link", { name: "Learning Space", exact: true }).click();
  await page.getByRole("heading", { name: "Learning Space" }).waitFor();
  await page.getByRole("link", { name: "Notebooks" }).click();
  await page.getByRole("heading", { name: "Notebooks", level: 1 }).waitFor();
  await page.getByRole("button", { name: "New notebook", exact: true }).click();
  const name = page.getByPlaceholder("Notebook name");
  const description = page.getByPlaceholder("Description (optional)");
  await name.fill("Verification notebook");
  await description.fill("Created from the browser");
  await shot(page, dir, "draft");
  await page.getByRole("button", { name: "Create", exact: true }).click();
  const heading = page.getByRole("heading", { name: "Verification notebook", level: 2 });
  await heading.waitFor();
  const descriptionText = page.getByRole("paragraph").filter({ hasText: /^Created from the browser$/ });
  await descriptionText.waitFor();
  const url = new URL(page.url());
  const notebookId = decodeURIComponent(url.pathname.split("/").filter(Boolean).pop() || "");
  if (!notebookId || notebookId === "notebooks") {
    throw new Error(`Create did not open a notebook URL: ${page.url()}`);
  }
  await page.reload({ waitUntil: "domcontentloaded" });
  await page.getByRole("heading", { name: "Notebooks", level: 1 }).waitFor();
  await heading.waitFor();
  await descriptionText.waitFor();
  await page.getByRole("button", { name: /Verification notebook/ }).waitFor();
  await shot(page, dir, "saved");

  const show = runCli(env.HOME_DIR, ["notebook", "show", notebookId, "--format", "json"]);
  await writeFile(path.join(dir, "cli-show.stdout.txt"), show.stdout || "", "utf8");
  await writeFile(path.join(dir, "cli-show.stderr.txt"), show.stderr || "", "utf8");
  await writeFile(
    path.join(dir, "cli-show.exit.txt"),
    String(show.status ?? "null") + "\n",
    "utf8",
  );
  if (show.status !== 0) {
    throw new Error(`deeptutor notebook show exited ${show.status}: ${show.stderr || show.stdout}`);
  }
  const shown = JSON.parse(show.stdout);
  if (shown.name !== "Verification notebook" || shown.description !== "Created from the browser") {
    throw new Error(`CLI show returned ${JSON.stringify({ name: shown.name, description: shown.description })}`);
  }
  const indexMatches = [];
  function walk(directory) {
    for (const entry of readdirSync(directory)) {
      const full = path.join(directory, entry);
      const info = statSync(full);
      if (info.isDirectory()) walk(full);
      else if (entry === "notebooks_index.json" || entry === `${notebookId}.json`) indexMatches.push(full);
    }
  }
  walk(env.HOME_DIR);
  const notebookFile = indexMatches.find((item) => item.endsWith(`${notebookId}.json`));
  if (!notebookFile) throw new Error(`Notebook file for ${notebookId} was not written under ${env.HOME_DIR}`);
  const stored = JSON.parse(readFileSync(notebookFile, "utf8"));
  if (stored.name !== "Verification notebook") {
    throw new Error(`Stored notebook name is ${stored.name}`);
  }
  await writeFile(path.join(dir, "notebook.json"), JSON.stringify(stored, null, 2) + "\n", "utf8");
  return {
    feature: "notebooks",
    entry: "browser Learning Space → Notebooks",
    pass: true,
    notebook_id: notebookId,
    cli: "deeptutor notebook show --format json",
    stored_file: path.relative(env.HOME_DIR, notebookFile),
  };
}

async function driveAppearance(page, env, dir) {
  await openApp(page, env);
  await page.getByRole("link", { name: "Settings", exact: true }).click();
  await page.getByRole("link", { name: "Appearance", exact: true }).click();
  await page.getByRole("heading", { name: "Appearance" }).waitFor();
  const dark = page.getByRole("button", { name: "Dark", exact: true });
  await dark.click();
  if ((await dark.getAttribute("aria-pressed")) !== "true") {
    throw new Error("Dark theme tile did not become pressed");
  }
  await page.getByRole("status").filter({ hasText: "Unsaved changes" }).waitFor();
  await shot(page, dir, "staged");
  await page.getByRole("button", { name: "Apply changes", exact: true }).click();
  await page.waitForFunction(() => document.documentElement.classList.contains("dark"));
  await page.getByRole("button", { name: "Apply changes", exact: true }).waitFor({ state: "hidden" });
  await page.reload({ waitUntil: "domcontentloaded" });
  await page.getByRole("heading", { name: "Appearance" }).waitFor();
  await page.waitForFunction(() => document.documentElement.classList.contains("dark"));
  await shot(page, dir, "applied");
  const interfacePath = path.join(env.HOME_DIR, "data/user/settings/interface.json");
  const stored = JSON.parse(await readFile(interfacePath, "utf8"));
  if (stored.theme !== "dark") {
    throw new Error(`interface.json theme is ${stored.theme}, expected dark`);
  }
  await writeFile(path.join(dir, "interface.json"), JSON.stringify(stored, null, 2) + "\n", "utf8");
  return {
    feature: "appearance",
    entry: "browser Settings → Appearance",
    pass: true,
    theme: stored.theme,
    stored_file: "data/user/settings/interface.json",
  };
}

async function driveTaskBoard(page, env, dir) {
  const title = "Verify the task board";
  await openApp(page, env);
  await page.getByRole("link", { name: "Task Board", exact: true }).click();
  await page.getByRole("heading", { name: "Task Board" }).waitFor();
  await page.getByRole("textbox", { name: "New task" }).fill(title);
  await shot(page, dir, "draft");
  await page.getByRole("button", { name: "Add", exact: true }).click();
  const column = page.getByRole("region", { name: "To do" });
  await column.getByText(title, { exact: true }).waitFor();
  await page.reload({ waitUntil: "domcontentloaded" });
  await page.getByRole("heading", { name: "Task Board" }).waitFor();
  await column.getByText(title, { exact: true }).waitFor();
  await shot(page, dir, "saved");
  const found = spawnSync(
    python(),
    [
      "-c",
      "import sqlite3,sys; from pathlib import Path\n" +
        "root=Path(sys.argv[1]); matches=list(root.glob('**/task-board/tasks.sqlite'))\n" +
        "assert matches, 'tasks.sqlite missing'\n" +
        "row=sqlite3.connect(matches[0]).execute('select title,status from cards where title=?', (sys.argv[2],)).fetchone()\n" +
        "assert row== (sys.argv[2], 'todo'), row\n" +
        "print(matches[0])",
      env.HOME_DIR,
      title,
    ],
    { encoding: "utf8" },
  );
  if (found.status !== 0) {
    throw new Error(found.stderr || found.stdout || "task row was not stored");
  }
  await writeFile(path.join(dir, "sqlite-path.txt"), (found.stdout || "").trim() + "\n", "utf8");
  return {
    feature: "task-board",
    entry: "browser sidebar Task Board",
    pass: true,
    title,
    stored_file: path.relative(env.HOME_DIR, (found.stdout || "").trim()),
  };
}

async function driveChat(page, env, dir) {
  const statusResponse = await page.request.get(env.BACKEND_URL + "/api/system/status");
  const status = await statusResponse.json();
  await writeFile(path.join(dir, "system-status.json"), JSON.stringify(status, null, 2) + "\n", "utf8");
  await openApp(page, env);
  await page.getByRole("link", { name: "Home", exact: true }).click();
  const composer = page.getByRole("textbox", { name: "How can I help you today?" });
  await composer.waitFor();
  if (status.llm?.status !== "configured") {
    await shot(page, dir, "blocked");
    return {
      feature: "chat",
      entry: "browser sidebar Home",
      pass: false,
      reason:
        `llm.status is ${status.llm?.status || "missing"}. A tutor reply needs a language model in Settings. ` +
        "The composer is on screen; this run does not send a prompt or substitute a mock model.",
    };
  }
  await composer.fill("Reply with the single word ready.");
  await shot(page, dir, "draft");
  await page.getByRole("button", { name: "Send", exact: true }).click();
  const assistant = page.locator("[data-chat-message-role='assistant']").last();
  await assistant.waitFor({ timeout: 120_000 });
  await page.getByRole("button", { name: "Send", exact: true }).waitFor({ timeout: 120_000 });
  const alert = assistant.getByRole("alert");
  if (await alert.count()) {
    await shot(page, dir, "failed");
    throw new Error(`The turn ended in an alert: ${await alert.innerText()}`);
  }
  const text = (await assistant.innerText()).trim();
  if (!text) throw new Error("The assistant message was empty");
  await shot(page, dir, "reply");
  return {
    feature: "chat",
    entry: "browser sidebar Home",
    pass: true,
    reply_excerpt: text.slice(0, 240),
  };
}

async function driveKnowledge(page, env, dir) {
  const statusResponse = await page.request.get(env.BACKEND_URL + "/api/system/status");
  const status = await statusResponse.json();
  await writeFile(path.join(dir, "system-status.json"), JSON.stringify(status, null, 2) + "\n", "utf8");
  await openApp(page, env);
  await page.getByRole("link", { name: "Learning Space", exact: true }).click();
  await page.getByRole("link", { name: "Knowledge Center" }).click();
  await page.getByRole("heading", { name: "Knowledge Center" }).waitFor();
  await page.getByRole("button", { name: "New knowledge base", exact: true }).click();
  const dialog = page.getByRole("dialog", { name: "Create knowledge base" });
  await dialog.waitFor();
  await dialog.getByPlaceholder("e.g. project-papers").fill("verification-library");
  const create = dialog.getByRole("button", { name: "Create", exact: true });
  await shot(page, dir, "dialog");
  if (status.embeddings?.status !== "configured") {
    if (await create.isEnabled()) {
      throw new Error(
        "Create became enabled without a configured embedding model. Refusing to guess which engine that selected.",
      );
    }
    return {
      feature: "knowledge",
      entry: "browser Learning Space → Knowledge Center",
      pass: false,
      reason:
        `embeddings.status is ${status.embeddings?.status || "missing"}. ` +
        "The default LlamaIndex engine leaves Create disabled until an embedding model is configured. " +
        "This run does not switch engines or mock an embedding provider.",
    };
  }
  await create.click();
  await page.getByRole("heading", { name: "verification-library" }).waitFor();
  await page.reload({ waitUntil: "domcontentloaded" });
  await page.getByText("verification-library", { exact: true }).waitFor();
  await shot(page, dir, "saved");
  return {
    feature: "knowledge",
    entry: "browser Learning Space → Knowledge Center",
    pass: true,
    name: "verification-library",
  };
}

const drivers = {
  notebooks: driveNotebooks,
  appearance: driveAppearance,
  "task-board": driveTaskBoard,
  chat: driveChat,
  knowledge: driveKnowledge,
};

if (!features.has(feature)) {
  console.error("Usage: drive.mjs <notebooks|appearance|task-board|chat|knowledge>");
  process.exit(1);
}

const env = loadState();
const dir = path.join(env.EVIDENCE_DIR, feature);
await mkdir(dir, { recursive: true });
const headless = !process.env.DISPLAY;
const launchArgs = [];
if (process.env.VERIFY_CHROMIUM_NO_SANDBOX === "1") {
  launchArgs.push("--no-sandbox", "--disable-dev-shm-usage");
}
const browser = await chromium.launch({ headless, args: launchArgs });
const context = await browser.newContext({
  locale: "en-US",
  viewport: { width: 1280, height: 800 },
});
const page = await context.newPage();
page.setDefaultTimeout(90_000);
let result;
try {
  result = await drivers[feature](page, env, dir);
  result.run_id = env.RUN_ID;
  result.frontend_url = env.FRONTEND_URL;
  result.version = env.VERSION;
  result.headless = headless;
  await writeResult(dir, result);
  if (!result.pass) {
    console.error(`drive: ${feature} failed: ${result.reason}`);
    process.exitCode = 1;
  } else {
    console.log(`drive: ${feature} passed`);
    console.log(`  evidence: ${dir}`);
  }
} catch (error) {
  try {
    await shot(page, dir, "failure");
  } catch {
    // The page may already be gone; the thrown error is the proof of the failure.
  }
  result = {
    feature,
    pass: false,
    run_id: env.RUN_ID,
    frontend_url: env.FRONTEND_URL,
    version: env.VERSION,
    headless,
    reason: error instanceof Error ? error.stack || error.message : String(error),
  };
  await writeResult(dir, result);
  fail(result.reason);
} finally {
  await browser.close();
}
