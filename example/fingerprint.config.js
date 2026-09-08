module.exports = {
  // EAS installs the same parent dependencies already installed for local builds.
  // Keep hashing every other script, and any change to the install command.
  fileHookTransform(source, chunk) {
    if (source.type !== 'contents' || source.id !== 'packageJson:scripts' || chunk == null) {
      return chunk;
    }
    const scripts = JSON.parse(chunk.toString());
    if (scripts['eas-build-pre-install'] === 'npm ci --prefix ..') {
      delete scripts['eas-build-pre-install'];
    }
    return JSON.stringify(scripts);
  },
};
