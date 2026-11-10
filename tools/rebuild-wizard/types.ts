export type PlatformKind = "darwin" | "linux" | "other";

export type Target = {
  name: string;
  cliFlag: `--${string}`;
  kind: "darwin" | "nixos" | "nixos-remote";
  allowedFrom: string[];
  remoteBuildFrom?: string[];
};

export type CommandOptions = {
  phase?: string;
  cwd?: string;
  env?: Record<string, string | undefined>;
  check?: boolean;
  retryNixDaemonCrash?: boolean;
};

export type Action =
  | { kind: "rebuild"; target?: string }
  | { kind: "update" }
  | { kind: "secrets"; file?: string }
  | { kind: "help" };
