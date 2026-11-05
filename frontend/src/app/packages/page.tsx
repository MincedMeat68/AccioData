import { Suspense } from "react";
import { PackageList } from "@/features/packages/PackageList";

export const metadata = { title: "Saved Packages · Screening Package Builder" };

export default function PackagesPage() {
  return (
    <Suspense>
      <PackageList />
    </Suspense>
  );
}
