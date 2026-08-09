export type PlatformKind = "darwin" | "linux" | "other";

type TargetBase = {
  name: string;
  cliFlag: `--${string}`;
  flakeAttr: string;
  description: string;
  allowedFrom: string[];
};

export type Target = TargetBase &
  (
    | {
        kind: "darwin" | "nixos";
        remote?: never;
      }
    | {
        kind: "nixos-remote";
        remote: {
          deployNode: string;
          remoteBuildFrom: string[];
        };
      }
  );

export type CommandOptions = {
  cwd?: string;
  env?: Record<string, string | undefined>;
  check?: boolean;
  retryNixDaemonCrash?: boolean;
};

export type LogCommandOptions = CommandOptions & {
  stdin?: "ignore" | "inherit";
};

export type MenuItem<T> = {
  label: string;
  value: T;
  description?: string;
};

export type ChecklistItem = {
  label: string;
  value: string;
  description?: string;
};

export type SecretFile = {
  name: string;
  encryptedFile: string;
  plainFile: string;
};

export type RebuildOptions = {
  updateInputs: string[];
};
