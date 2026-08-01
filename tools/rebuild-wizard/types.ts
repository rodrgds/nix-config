export type TargetKind = "nixos" | "darwin" | "nixos-remote";
export type PlatformKind = "darwin" | "linux" | "other";
export type BuildHostMode = "local" | "target" | string;

export type Target = {
  name: string;
  flakeAttr: string;
  kind: TargetKind;
  description: string;
  allowedFrom: string[];
  remote?: {
    targetHost: string;
    buildHost?: BuildHostMode;
  };
};

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
