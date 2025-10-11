"use client";

import { useStacks } from "@/hooks/use-stacks";
import { redirect } from "next/navigation";

export default function Home() {
  const { userData } = useStacks();

  if (!userData) {
    return (
      <main className="flex min-h-screen flex-col items-center gap-8 p-24">
        <span>Connect your wallet or search for an address</span>
      </main>
    );
  }

  // If user's wallet is connected, just redirect to the /SP... page
  // to show their profile
  redirect(`/${userData.profile.stxAddress.mainnet}`);
}