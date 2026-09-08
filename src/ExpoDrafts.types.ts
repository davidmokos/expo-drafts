export type DraftUpdate = {
  id: string;
  groupId?: string;
  platform: 'ios' | 'android';
  runtimeVersion: string;
};

export type Draft = {
  id: string;
  name: string;
  channel: string;
  createdAt: string;
  branch?: string;
  message?: string;
  gitCommitHash?: string;
  pullRequest?: { number: number; url: string };
  buildUrl?: string;
  updates: DraftUpdate[];
};

export type DraftCatalog = {
  schemaVersion: 1;
  projectId: string;
  generatedAt: string;
  drafts: Draft[];
};

export type DraftsState = {
  enabled: boolean;
  runtimeVersion: string | null;
  updateId: string | null;
  channel: string | null;
};
