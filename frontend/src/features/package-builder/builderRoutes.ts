/**
 * What the builder opens, and the URL for each case. The URL is the single
 * source of truth so a reload always shows the same thing:
 *
 *   /                 latest  - the most recently saved package (core requirement 9)
 *   /?new=1           new     - an empty draft ("Create New Package")
 *   /?package=<id>    package - edit a specific saved package
 *
 * `saved=created|updated` may accompany `package` to confirm a save that
 * just happened before the page was (re)mounted.
 */
import type { SavedAction } from "@/features/packages/savedNotice";

export type BuilderSource = { kind: "latest" } | { kind: "new" } | { kind: "package"; id: string };

export const builderUrl = {
  latest: "/",
  newPackage: "/?new=1",
  package: (id: string, saved?: SavedAction) =>
    `/?package=${encodeURIComponent(id)}${saved ? `&saved=${saved}` : ""}`,
};

export function parseBuilderSource(params: URLSearchParams): BuilderSource {
  const id = params.get("package");
  if (id) return { kind: "package", id };
  if (params.has("new")) return { kind: "new" };
  return { kind: "latest" };
}

/** `saved=created|updated` on a builder URL, if present. */
export function parseJustSaved(params: URLSearchParams): SavedAction | null {
  const saved = params.get("saved");
  return saved === "created" || saved === "updated" ? saved : null;
}

/** Stable identity for a source: remount the builder only when this changes. */
export const sourceKey = (source: BuilderSource) =>
  source.kind === "package" ? `package:${source.id}` : source.kind;
