import type { Catalog, Evaluation, PackageInput, SavedPackage, ServiceCode, Violation } from "./types";

/** Error returned by the API's `{ error: { code, message, violations } }` envelope. */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly violations: Violation[] = [],
  ) {
    super(message);
    this.name = "ApiError";
  }
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  let response: Response;
  try {
    response = await fetch(path, {
      ...init,
      headers: { "Content-Type": "application/json", ...init.headers },
      cache: "no-store",
    });
  } catch (cause) {
    if ((cause as Error).name === "AbortError") throw cause;
    throw new ApiError(0, "network_error", "Could not reach the server. Is the backend running?");
  }

  if (response.status === 204) return null as T;

  const body = await response.json().catch(() => null);
  if (!response.ok) {
    const error = body?.error;
    // A proxy failure (backend down) comes back as a non-JSON 500 from Next.
    throw new ApiError(
      response.status,
      error?.code ?? "http_error",
      error?.message ?? `The server responded with ${response.status}. Is the backend running?`,
      error?.violations ?? [],
    );
  }
  return body as T;
}

const json = (data: unknown) => JSON.stringify(data);

export const api = {
  catalog: () => request<Catalog>("/api/catalog"),

  evaluate: (serviceCodes: ServiceCode[], signal?: AbortSignal) =>
    request<Evaluation>("/api/packages/evaluate", {
      method: "POST",
      body: json({ service_codes: serviceCodes }),
      signal,
    }),

  listPackages: () => request<SavedPackage[]>("/api/packages"),
  latestPackage: () => request<SavedPackage | null>("/api/packages/latest"),
  getPackage: (id: string) => request<SavedPackage>(`/api/packages/${encodeURIComponent(id)}`),

  createPackage: (input: PackageInput) =>
    request<SavedPackage>("/api/packages", { method: "POST", body: json(input) }),

  updatePackage: (id: string, input: PackageInput) =>
    request<SavedPackage>(`/api/packages/${encodeURIComponent(id)}`, { method: "PUT", body: json(input) }),

  deletePackage: (id: string) =>
    request<null>(`/api/packages/${encodeURIComponent(id)}`, { method: "DELETE" }),

  duplicatePackage: (id: string) =>
    request<SavedPackage>(`/api/packages/${encodeURIComponent(id)}/duplicate`, { method: "POST", body: "{}" }),
};
