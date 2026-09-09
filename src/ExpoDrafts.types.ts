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

/** Device builds verified by trusted CI. Installation hands the verified build to the iOS installer. */
export type DraftBuild = {
  runtimeVersion: string;
  platform: 'ios';
  profile: string;
  state: 'queued' | 'building' | 'ready' | 'failed';
  requestId: string;
  requestedAt: string;
  updatedAt: string;
  gitCommitHash: string;
  buildId?: string;
  installUrl?: string;
  requestUrl?: string;
  statusUrl?: string;
};

export type DraftBuildCatalog = {
  schemaVersion: 1;
  projectId: string;
  generatedAt: string;
  builds: DraftBuild[];
};

export type DraftsState = {
  enabled: boolean;
  runtimeVersion: string | null;
  updateId: string | null;
  channel: string | null;
};
