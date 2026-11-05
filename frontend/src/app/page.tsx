import { Suspense } from "react";
import { BuilderPage } from "@/features/package-builder/components/BuilderPage";

export default function Home() {
  return (
    <Suspense>
      <BuilderPage />
    </Suspense>
  );
}
