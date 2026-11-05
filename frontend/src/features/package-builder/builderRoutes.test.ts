import { describe, expect, it } from "vitest";
import { builderUrl, parseBuilderSource, parseJustSaved, sourceKey } from "./builderRoutes";

const parse = (url: string) => parseBuilderSource(new URL(url, "http://localhost").searchParams);

describe("builder routes", () => {
  it("opens the latest package at /", () => {
    expect(parse(builderUrl.latest)).toEqual({ kind: "latest" });
  });

  it("opens an empty draft for Create New Package", () => {
    expect(parse(builderUrl.newPackage)).toEqual({ kind: "new" });
  });

  it("opens a specific package, which wins over ?new", () => {
    expect(parse(builderUrl.package("abc-123"))).toEqual({ kind: "package", id: "abc-123" });
    expect(parse("/?new=1&package=abc")).toEqual({ kind: "package", id: "abc" });
  });

  it("reads the just-saved flag and ignores anything else", () => {
    const params = (url: string) => new URL(url, "http://localhost").searchParams;
    expect(parseJustSaved(params(builderUrl.package("abc", "created")))).toBe("created");
    expect(parseJustSaved(params(builderUrl.package("abc")))).toBeNull();
    expect(parseJustSaved(params("/?package=abc&saved=bogus"))).toBeNull();
  });

  it("keeps the source key stable when only the saved flag changes", () => {
    const withFlag = parse(builderUrl.package("abc", "created"));
    expect(sourceKey(withFlag)).toBe(sourceKey(parse(builderUrl.package("abc"))));
    expect(sourceKey(parse(builderUrl.newPackage))).not.toBe(sourceKey(parse(builderUrl.latest)));
  });
});
