// Wallpaper search (owner, 2026-10-16): Wallhaven in a Vicinae grid, replacing the dmenu script.
// Typing searches half a second after the last key; the dropdown picks the order. An empty search
// bar shows recent searches (Enter runs one; Ctrl+B: Remove from history, Clear all) above this
// month's toplist. Enter on a wallpaper downloads it to ~/Pictures/Wallpapers and runs
// wallpaper-apply, which sets it and recolours the desktop; Ctrl+B also has Download only, Open on
// Wallhaven and Copy link. A search joins Recent searches once a wallpaper from it is set or
// downloaded, so half-typed words never do.
import { Action, ActionPanel, Grid, Icon, Keyboard, LocalStorage, showHUD, showToast, Toast } from "@vicinae/api";
import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import { useEffect, useRef, useState } from "react";
import { effectiveSort, fetchWallpaper, pruneCache, search, type Sort, type Wallpaper } from "./wallhaven";

const sorts: { value: Sort; title: string }[] = [
  { value: "relevance", title: "Relevance" },
  { value: "toplist", title: "Toplist this month" },
  { value: "date_added", title: "Latest" },
  { value: "random", title: "Random" },
];
const recentKey = "recent-searches"; // LocalStorage: a JSON list, newest first
const recentSize = 8;

const message = (err: unknown) => (err instanceof Error ? err.message : String(err));

export default function WallpaperSearch() {
  const [text, setText] = useState("");
  const [query, setQuery] = useState(""); // the text, once typing pauses
  const [sort, setSort] = useState<Sort>("relevance");
  const [recent, setRecent] = useState<string[]>([]);
  const [wallpapers, setWallpapers] = useState<Wallpaper[]>([]);
  const [page, setPage] = useState<{ number: number; last: number; seed?: string }>({ number: 0, last: 0 });
  const [loading, setLoading] = useState(true);
  const generation = useRef(0); // which search is current: answers to older ones are dropped
  const busy = useRef(false); // a page is on its way

  useEffect(() => {
    pruneCache().catch(() => {});
    LocalStorage.getItem<string>(recentKey).then((saved) => setRecent(saved ? JSON.parse(saved) : []));
  }, []);

  useEffect(() => {
    const timer = setTimeout(() => setQuery(text.trim()), 500);
    return () => clearTimeout(timer);
  }, [text]);

  async function load(number: number, seed?: string) {
    const current = generation.current;
    busy.current = true;
    setLoading(true);
    try {
      const result = await search(query, sort, number, seed);
      if (current !== generation.current) return;
      setWallpapers((old) =>
        number === 1 ? result.wallpapers : [...old, ...result.wallpapers.filter((w) => !old.some((o) => o.id === w.id))],
      );
      setPage({ number, last: result.lastPage, seed: result.seed ?? seed });
    } catch (err) {
      if (current === generation.current) {
        showToast({ style: Toast.Style.Failure, title: "Wallhaven search failed", message: message(err) });
      }
    } finally {
      if (current === generation.current) {
        busy.current = false;
        setLoading(false);
      }
    }
  }

  // A new search: the old results stay on screen until the new ones arrive.
  useEffect(() => {
    generation.current++;
    load(1);
  }, [query, sort]);

  async function saveRecent(next: string[]) {
    setRecent(next);
    if (next.length) await LocalStorage.setItem(recentKey, JSON.stringify(next));
    else await LocalStorage.removeItem(recentKey);
  }

  function runRecent(search: string) {
    setText(search);
    setQuery(search); // straight away, without the typing pause
  }

  async function use(w: Wallpaper, apply: boolean) {
    const toast = await showToast({ style: Toast.Style.Animated, title: "Downloading", message: `wallhaven-${w.id}` });
    let file: string;
    try {
      file = await fetchWallpaper(w);
    } catch (err) {
      toast.message = message(err); // first: only the style and title setters redraw the toast
      toast.style = Toast.Style.Failure;
      toast.title = "The download failed";
      return;
    }
    if (query) await saveRecent([query, ...recent.filter((r) => r !== query)].slice(0, recentSize));
    if (!apply) {
      toast.message = `~/Pictures/Wallpapers/${basename(file)}`;
      toast.style = Toast.Style.Success;
      toast.title = "Saved";
      return;
    }
    const child = spawn(join(homedir(), ".local", "bin", "wallpaper-apply"), [file], { detached: true, stdio: "ignore" });
    child.on("error", (err) => showToast({ style: Toast.Style.Failure, title: "wallpaper-apply failed", message: err.message }));
    child.unref();
    await showHUD("Setting the wallpaper");
  }

  const order = sorts.find((s) => s.value === effectiveSort(query, sort))?.title;
  return (
    <Grid
      columns={4}
      aspectRatio="16/9"
      fit={Grid.Fit.Fill}
      filtering={false}
      isLoading={loading}
      searchText={text}
      onSearchTextChange={setText}
      searchBarPlaceholder="Search Wallhaven"
      navigationTitle="Wallpaper search"
      searchBarAccessory={
        <Grid.Dropdown tooltip="Order" value={sort} onChange={(value) => setSort(value as Sort)}>
          {sorts.map((s) => (
            <Grid.Dropdown.Item key={s.value} value={s.value} title={s.title} />
          ))}
        </Grid.Dropdown>
      }
      pagination={{
        hasMore: page.number > 0 && page.number < page.last,
        onLoadMore: () => {
          if (!busy.current) load(page.number + 1, page.seed);
        },
      }}
    >
      {!query && recent.length > 0 && (
        <Grid.Section title="Recent searches" columns={8} aspectRatio="1" fit={Grid.Fit.Contain} inset={Grid.Inset.Large}>
          {recent.map((r) => (
            <Grid.Item
              key={`recent-${r}`}
              id={`recent-${r}`}
              content={Icon.MagnifyingGlass}
              title={r}
              actions={
                <ActionPanel>
                  <Action title="Search" icon={Icon.MagnifyingGlass} onAction={() => runRecent(r)} />
                  <Action
                    title="Remove from history"
                    icon={Icon.Trash}
                    shortcut={Keyboard.Shortcut.Common.Remove}
                    onAction={() => saveRecent(recent.filter((other) => other !== r))}
                  />
                  <Action
                    title="Clear all"
                    icon={Icon.Trash}
                    style="destructive"
                    shortcut={Keyboard.Shortcut.Common.RemoveAll}
                    onAction={() => saveRecent([])}
                  />
                </ActionPanel>
              }
            />
          ))}
        </Grid.Section>
      )}
      <Grid.Section title={query ? `Results for "${query}"` : order} subtitle={wallpapers.length ? String(wallpapers.length) : undefined}>
        {wallpapers.map((w) => (
          <Grid.Item
            key={w.id}
            id={w.id}
            content={w.thumbnail}
            title={w.resolution.replace("x", " × ")}
            actions={
              <ActionPanel>
                <Action title="Set as wallpaper" icon={Icon.Image} onAction={() => use(w, true)} />
                <Action
                  title="Download only"
                  icon={Icon.Download}
                  shortcut={Keyboard.Shortcut.Common.Save}
                  onAction={() => use(w, false)}
                />
                <Action.OpenInBrowser title="Open on Wallhaven" url={w.page} shortcut={Keyboard.Shortcut.Common.Open} />
                <Action.CopyToClipboard title="Copy link" content={w.page} shortcut={Keyboard.Shortcut.Common.Copy} />
              </ActionPanel>
            }
          />
        ))}
      </Grid.Section>
      {!loading && wallpapers.length === 0 && (
        <Grid.EmptyView title={query ? `Nothing found for "${query}"` : "Nothing to show"} icon={Icon.Image} />
      )}
    </Grid>
  );
}
