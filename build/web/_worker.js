export default {
	async fetch(request, env) {
		const url = new URL(request.url);

		// Decompress the gzipped wasm and serve raw bytes
		if (url.pathname === "/index.wasm") {
			try {
				const assetResponse = await env.ASSETS.fetch(request);
				const gzippedBuffer = await assetResponse.arrayBuffer();

				const ds = new DecompressionStream("gzip");
				const writer = ds.writable.getWriter();
				writer.write(new Uint8Array(gzippedBuffer));
				writer.close();

				const decompressed = await new Response(ds.readable).arrayBuffer();

				return new Response(decompressed, {
					headers: {
						"Content-Type": "application/wasm",
						"Cross-Origin-Opener-Policy": "same-origin",
						"Cross-Origin-Embedder-Policy": "require-corp",
						"Cache-Control": "public, max-age=31536000, immutable",
					},
				});
			} catch (e) {
				return new Response("Decompression error: " + e.message, { status: 500 });
			}
		}

		const response = await env.ASSETS.fetch(request);
		const headers = new Headers(response.headers);
		headers.set("Cross-Origin-Opener-Policy", "same-origin");
		headers.set("Cross-Origin-Embedder-Policy", "require-corp");

		return new Response(response.body, {
			status: response.status,
			headers,
		});
	},
};
