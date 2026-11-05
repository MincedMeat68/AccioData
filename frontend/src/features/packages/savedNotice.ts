/**
 * The builder hands off to the package list through the URL
 * (/packages?saved=<id>&action=updated), so the list can confirm the save
 * and highlight the package even though it loads its own data.
 */
export type SavedAction = "created" | "updated";

export const savedPackagesUrl = (id: string, action: SavedAction) =>
  `/packages?saved=${encodeURIComponent(id)}&action=${action}`;

export function readSavedNotice(params: URLSearchParams): { id: string; action: SavedAction } | null {
  const id = params.get("saved");
  if (!id) return null;
  return { id, action: params.get("action") === "created" ? "created" : "updated" };
}
