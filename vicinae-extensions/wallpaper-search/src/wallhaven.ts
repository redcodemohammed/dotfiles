// Wallhaven's API and files, past the local network's DNS block (owner, 2026-10-16).
// The network answers DNS queries for wallhaven.cc with nothing (even ones sent to 1.1.1.1), so
// every request here looks Wallhaven's hostnames up over Cloudflare's DNS-over-HTTPS instead,
// through the `lookup` option of node:https. TLS still checks the certificate against the name.
// Nothing else on the system changes.
import { createWriteStream } from "node:fs";
import { mkdir, readdir, rename, rm, stat } from "node:fs/promises";
import type { IncomingMessage } from "node:http";
import https from "node:https";
import type { LookupFunction } from "node:net";
import { homedir } from "node:os";
import { basename, dirname, join } from "node:path";
import { pipeline } from "node:stream/promises";

const cacheDir = join(homedir(), ".cache", "wallpaper-search"); // thumbnails
const wallpaperDir = join(homedir(), "Pictures", "Wallpapers");

export type Sort = "relevance" | "toplist" | "date_added" | "random";

export type Wallpaper = {
  id: string;
  page: string; // https://wallhaven.cc/w/<id>
  image: string; // the full-size file on w.wallhaven.cc
  resolution: string; // "3840x2160"
  thumbnail: string; // local copy of the large thumbnail
};

export type Page = { wallpapers: Wallpaper[]; lastPage: number; seed?: string };

type ApiPage = {
  data: { id: string; url: string; path: string; resolution: string; thumbs: { large: string } }[];
  meta: { last_page: number; seed: string | null };
};

/** One page (24) of safe-for-work wallpapers, at least 2560x1440, with thumbnails downloaded. */
export async function search(query: string, sort: Sort, page: number, seed?: string): Promise<Page> {
  // purity=100 is safe for work only, all that a search without an account can get anyway.
  const params = new URLSearchParams({ categories: "111", purity: "100", atleast: "2560x1440" });
  if (query) params.set("q", query);
  const sorting = effectiveSort(query, sort);
  params.set("sorting", sorting);
  if (sorting === "toplist") params.set("topRange", "1M");
  if (seed) params.set("seed", seed); // random: page 2 continues the same shuffle
  params.set("page", String(page));
  const json = await getJson<ApiPage>(`https://wallhaven.cc/api/v1/search?${params}`);
  const wallpapers = await mapLimit(json.data, 8, async (w): Promise<Wallpaper | null> => {
    const thumb = join(cacheDir, basename(new URL(w.thumbs.large).pathname));
    try {
      await download(w.thumbs.large, thumb);
    } catch {
      return null; // a missing thumbnail drops that one wallpaper, not the page
    }
    return { id: w.id, page: w.url, image: w.path, resolution: w.resolution, thumbnail: thumb };
  });
  return {
    wallpapers: wallpapers.filter((w): w is Wallpaper => w !== null),
    lastPage: json.meta.last_page,
    seed: json.meta.seed ?? undefined,
  };
}

/** Relevance needs words to be relevant to: an empty search shows this month's toplist. */
export function effectiveSort(query: string, sort: Sort): Sort {
  return sort === "relevance" && !query ? "toplist" : sort;
}

/** The full-size wallpaper in ~/Pictures/Wallpapers (downloaded once, then reused). */
export function fetchWallpaper(w: Wallpaper): Promise<string> {
  return download(w.image, join(wallpaperDir, basename(new URL(w.image).pathname)));
}

/** Thumbnails older than a day go; searches download what they show. */
export async function pruneCache(): Promise<void> {
  const now = Date.now();
  for (const name of await readdir(cacheDir).catch(() => [] as string[])) {
    const file = join(cacheDir, name);
    const info = await stat(file).catch(() => null);
    if (info && now - info.mtimeMs > 24 * 3600 * 1000) await rm(file, { recursive: true, force: true });
  }
}

const addresses = new Map<string, Promise<string>>(); // hostname → IPv4 address, per session

async function dnsOverHttps(host: string): Promise<string> {
  const res = await fetch(`https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(host)}&type=A`, {
    headers: { accept: "application/dns-json" },
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) throw new Error(`Cloudflare DNS answered ${res.status}`);
  const json = (await res.json()) as { Answer?: { type: number; data: string }[] };
  const ip = json.Answer?.find((a) => a.type === 1)?.data; // type 1 = an IPv4 address
  if (!ip) throw new Error(`no address for ${host}`);
  return ip;
}

// Node 24 asks with `all: true` (it races every address, "happy eyeballs"); other callers want one.
const lookup: LookupFunction = (hostname, options, callback) => {
  let ip = addresses.get(hostname);
  if (!ip) {
    ip = dnsOverHttps(hostname);
    addresses.set(hostname, ip);
    ip.catch(() => addresses.delete(hostname)); // a failed lookup is tried again next time
  }
  ip.then(
    (address) => (options.all ? callback(null, [{ address, family: 4 }]) : callback(null, address, 4)),
    (err: Error) => callback(new Error(`Couldn't look up ${hostname} (no internet?): ${err.message}`), ""),
  );
};

function open(url: string): Promise<IncomingMessage> {
  return new Promise((resolve, reject) => {
    const req = https.get(url, { lookup, timeout: 30_000 }, (res) => {
      if (res.statusCode === 200) {
        resolve(res);
        return;
      }
      res.resume();
      // The API allows 45 requests a minute without an account.
      reject(new Error(res.statusCode === 429 ? "Too many requests, wait a minute" : `Wallhaven answered ${res.statusCode}`));
    });
    req.on("timeout", () => req.destroy(new Error("Wallhaven didn't answer in time")));
    req.on("error", reject);
  });
}

async function getJson<T>(url: string): Promise<T> {
  const chunks: Buffer[] = [];
  for await (const chunk of await open(url)) chunks.push(chunk as Buffer);
  return JSON.parse(Buffer.concat(chunks).toString("utf8")) as T;
}

/** url → file, through file.part so a broken download never looks finished. Existing files are kept. */
async function download(url: string, file: string): Promise<string> {
  const info = await stat(file).catch(() => null);
  if (info && info.size > 0) return file;
  await mkdir(dirname(file), { recursive: true });
  const part = `${file}.part`;
  try {
    await pipeline(await open(url), createWriteStream(part));
    await rename(part, file);
  } catch (err) {
    await rm(part, { force: true });
    throw err;
  }
  return file;
}

/** Like items.map(fn), with at most `limit` calls running at once. */
async function mapLimit<T, R>(items: T[], limit: number, fn: (item: T) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let next = 0;
  const worker = async () => {
    while (next < items.length) {
      const i = next++;
      out[i] = await fn(items[i]);
    }
  };
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return out;
}
