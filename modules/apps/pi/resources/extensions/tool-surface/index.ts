import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const HINDSIGHT_ADMIN_TOOLS = new Set([
  "hindsight_status",
  "hindsight_seed_git",
  "hindsight_scope",
  "hindsight_config",
  "hindsight_bank",
  "hindsight_mental_model",
  "hindsight_knowledge",
  "hindsight_scope_migrate",
]);

const COMMAND_ONLY_TOOLS = new Set(["annotate"]);

const GOAL_TOOLS = ["get_goal", "create_goal", "update_goal"] as const;
const GOAL_TOOL_SET = new Set<string>(GOAL_TOOLS);
const GOAL_ENTRY_TYPE = "pi-codex-goal";
const CREATE_GOAL_PROMPT_MARKER =
  "Turn the user task into exactly one durable pi-codex-goal objective";

interface SessionEntryLike {
  type?: string;
  customType?: string;
  data?: unknown;
}

interface GoalState {
  goalId: string;
  status: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function activeGoal(entries: SessionEntryLike[]): boolean {
  let goal: GoalState | null = null;

  for (const entry of entries) {
    if (entry.type !== "custom" || entry.customType !== GOAL_ENTRY_TYPE) {
      continue;
    }
    if (!isRecord(entry.data)) continue;

    if (entry.data.kind === "clear") {
      goal = null;
      continue;
    }

    if (entry.data.kind === "set" && isRecord(entry.data.goal)) {
      const goalId = entry.data.goal.goalId;
      const status = entry.data.goal.status;
      if (typeof goalId === "string" && typeof status === "string") {
        goal = { goalId, status };
      }
      continue;
    }

    if (
      entry.data.kind === "usage" &&
      goal &&
      entry.data.goalId === goal.goalId &&
      typeof entry.data.status === "string"
    ) {
      goal = { ...goal, status: entry.data.status };
    }
  }

  return goal?.status === "active";
}

function sameTools(left: string[], right: string[]): boolean {
  return (
    left.length === right.length &&
    left.every((toolName, index) => toolName === right[index])
  );
}

export default function toolSurface(pi: ExtensionAPI) {
  function applyPolicy(ctx: ExtensionContext, goalCreationRequested = false) {
    const current = pi.getActiveTools();
    const goalToolsEnabled =
      goalCreationRequested ||
      activeGoal(ctx.sessionManager.getBranch() as SessionEntryLike[]);
    const next = current.filter(
      (toolName) =>
        !HINDSIGHT_ADMIN_TOOLS.has(toolName) &&
        !COMMAND_ONLY_TOOLS.has(toolName) &&
        (goalToolsEnabled || !GOAL_TOOL_SET.has(toolName)),
    );

    if (goalToolsEnabled) {
      const available = new Set(pi.getAllTools().map((tool) => tool.name));
      for (const toolName of GOAL_TOOLS) {
        if (available.has(toolName) && !next.includes(toolName)) {
          next.push(toolName);
        }
      }
    }

    if (!sameTools(current, next)) pi.setActiveTools(next);
  }

  pi.on("session_start", (_event, ctx) => applyPolicy(ctx));

  pi.on("model_select", (_event, ctx) => applyPolicy(ctx));

  pi.on("before_agent_start", (event, ctx) => {
    applyPolicy(ctx, event.prompt.includes(CREATE_GOAL_PROMPT_MARKER));
  });

  pi.on("tool_result", (event, ctx) => {
    if (GOAL_TOOL_SET.has(event.toolName)) applyPolicy(ctx);
  });

  pi.on("agent_settled", (_event, ctx) => applyPolicy(ctx));
}
