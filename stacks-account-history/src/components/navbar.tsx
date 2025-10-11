"use client";
import { useStacks } from "@/hooks/use-stacks";
import { abbreviateAddress } from "@/lib/stx-utils";
import { createAddress } from "@stacks/transactions";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";

export function Navbar() {
  // next.js router to handle redirecting to different pages
  const router = useRouter();

  // state variable for storing the address input in the search bar
  const [searchAddress, setSearchAddress] = useState("");

  // our useStacks hook
  const { userData, connectWallet, disconnectWallet } = useStacks();

  // function that validates the user inputted address
  // If it is valid, we will redirect the user to the txn history page
  function handleSearch() {
    if (!searchAddress.startsWith("SP")) {
      return alert("Please enter a mainnet Stacks address");
    }

    try {
      // createAddress comes from @stacks/transactions
      // and throws an error if the given user input is not a valid Stacks address
      createAddress(searchAddress);
    } catch (error) {
      return alert(`Invalid Stacks address entered ${error}`);
    }

    // redirect to /SP... which will show the txn history for this address
    router.push(`/${searchAddress}`);
  }

  return (
    <nav className="flex w-full items-center justify-between gap-4 p-4 h-16 border-b border-gray-500">
      <Link href="/" className="text-2xl font-bold">
        Stacks Account History
      </Link>

      <input
        type="text"
        placeholder="SP..."
        className="w-96 rounded-lg bg-gray-700  px-4 py-2 text-sm"
        onChange={(e) => setSearchAddress(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter") {
            // enter = search
            handleSearch();
          }
        }}
      />

      <div className="flex items-center gap-2">
        {/* If userData exists, show the disconnect wallet button, else show the connect wallet button */}
        {userData ? (
          <div className="flex items-center gap-2">
            {/* button for quickly viewing the user's own transaction history */}
            <button
              type="button"
              onClick={() =>
                router.push(`/${userData.profile.stxAddress.mainnet}`)
              }
              className="rounded-lg bg-blue-500 px-4 py-2 text-sm font-medium text-white hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
            >
              View {abbreviateAddress(userData.profile.stxAddress.mainnet)}
            </button>
            <button
              type="button"
              onClick={disconnectWallet}
              className="rounded-lg bg-red-500 px-4 py-2 text-sm font-medium text-white hover:bg-red-600 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2"
            >
              Disconnect
            </button>
          </div>
        ) : (
          <button
            type="button"
            onClick={connectWallet}
            className="rounded-lg bg-blue-500 px-4 py-2 text-sm font-medium text-white hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
          >
            Connect Wallet
          </button>
        )}
      </div>
    </nav>
  );
}