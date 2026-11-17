// Build-only stand-in for the compression-rspack-plugin npm package, a native
// addon that publishes no linux-arm64-musl binding and so cannot run in the
// arm64 package build. Emits the same [path][base].gz/.br assets through node's
// zlib, keeping the packaged frontend identical to upstream's.
import zlib from "zlib";
import { promisify } from "util";

const ALGORITHMS = {
  gzip: promisify(zlib.gzip),
  brotliCompress: promisify(zlib.brotliCompress),
};

const MIN_RATIO = 0.8;

class CompressionRspackPlugin {
  constructor(options) {
    this.options = options;
  }

  apply(compiler) {
    const { test, algorithm, filename, compressionOptions } = this.options;
    const compress = ALGORITHMS[algorithm];
    const { Compilation, sources } = compiler.webpack;

    compiler.hooks.thisCompilation.tap("CompressionRspackPlugin", (compilation) => {
      compilation.hooks.processAssets.tapPromise(
        {
          name: "CompressionRspackPlugin",
          stage: Compilation.PROCESS_ASSETS_STAGE_OPTIMIZE_TRANSFER,
          additionalAssets: true,
        },
        async (assets) => {
          await Promise.all(
            Object.keys(assets)
              .filter((name) => test.test(name))
              .map(async (name) => {
                const source = assets[name].source();
                const buffer = Buffer.isBuffer(source)
                  ? source
                  : Buffer.from(source);
                const compressed = await compress(buffer, compressionOptions);

                if (compressed.length / buffer.length >= MIN_RATIO) {
                  return;
                }

                const compressedName = filename.replace("[path][base]", name);
                compilation.emitAsset(
                  compressedName,
                  new sources.RawSource(compressed),
                  { compressed: true },
                );
                compilation.updateAsset(name, (source) => source, (info) => ({
                  ...info,
                  related: { ...info.related, [algorithm]: compressedName },
                }));
              }),
          );
        },
      );
    });
  }
}

export { CompressionRspackPlugin };
