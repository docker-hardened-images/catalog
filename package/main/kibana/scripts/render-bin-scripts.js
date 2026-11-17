/*
 * Render Kibana launcher scripts into a platform build directory when the
 * upstream CopyBinScripts task did not run (observed on Kibana 9.4 builds).
 */
require('@kbn/setup-node-env');

const Mustache = require('mustache');
const { readFileSync, writeFileSync, mkdirSync } = require('fs');
const { join } = require('path');
const globby = require('globby');

const version = process.env.KBN_VERSION;
const goArch = process.env.KBN_GO_ARCH;

if (!version || !goArch) {
  console.error('KBN_VERSION and KBN_GO_ARCH must be set');
  process.exit(1);
}

const scriptsSrc = 'src/dev/build/tasks/bin/scripts';
const scriptsDest = join(
  'build/default',
  `kibana-${version}-SNAPSHOT-linux-${goArch}`,
  'bin'
);

mkdirSync(scriptsDest, { recursive: true });

globby.sync(['*'], { ignore: ['*.bat'], cwd: scriptsSrc }).forEach((script) => {
  const template = readFileSync(join(scriptsSrc, script), 'utf8');
  const output = Mustache.render(template, {
    darwin: false,
    linux: true,
    serverless: false,
    forcePointerCompression: false,
  });
  writeFileSync(join(scriptsDest, script), output, { mode: 0o755 });
});
