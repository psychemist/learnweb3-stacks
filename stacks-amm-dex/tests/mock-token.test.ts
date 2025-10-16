
import { Cl } from "@stacks/transactions";
import { beforeEach, describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const alice = accounts.get("wallet_1")!;
const bob = accounts.get("wallet_2")!;
const charlie = accounts.get("wallet_3")!;

describe("Mock Token Tests", () => {
  beforeEach(() => {
    // Reset state before each test
  });

  describe("SIP-010 Token Metadata", () => {
    it("returns correct token name", () => {
      const { result } = simnet.callReadOnlyFn(
        "mock-token",
        "get-name",
        [],
        alice
      );
      expect(result).toBeOk(Cl.stringAscii("Mock Token"));
    });

    it("returns correct token symbol", () => {
      const { result } = simnet.callReadOnlyFn(
        "mock-token",
        "get-symbol",
        [],
        alice
      );
      expect(result).toBeOk(Cl.stringAscii("MTK"));
    });

    it("returns correct decimals", () => {
      const { result } = simnet.callReadOnlyFn(
        "mock-token",
        "get-decimals",
        [],
        alice
      );
      expect(result).toBeOk(Cl.uint(6));
    });

    it("returns none for token URI", () => {
      const { result } = simnet.callReadOnlyFn(
        "mock-token",
        "get-token-uri",
        [],
        alice
      );
      expect(result).toBeOk(Cl.none());
    });
  });

  describe("Minting", () => {
    it("allows minting tokens to a recipient", () => {
      const mintAmount = 1_000_000;
      const { result, events } = simnet.callPublicFn(
        "mock-token",
        "mint",
        [Cl.uint(mintAmount), Cl.principal(alice)],
        alice
      );

      expect(result).toBeOk(Cl.bool(true));
      expect(events.length).toBeGreaterThan(0);
      expect(events[0].event).toBe("ft_mint_event");
      expect(events[0].data.amount).toBe(mintAmount.toString());
      expect(events[0].data.recipient).toBe(alice);
    });

    it("updates balance after minting", () => {
      const mintAmount = 5_000_000;
      simnet.callPublicFn(
        "mock-token",
        "mint",
        [Cl.uint(mintAmount), Cl.principal(bob)],
        bob
      );

      const { result } = simnet.callReadOnlyFn(
        "mock-token",
        "get-balance",
        [Cl.principal(bob)],
        bob
      );

      expect(result).toBeOk(Cl.uint(mintAmount));
    });

    it("updates total supply after minting", () => {
      const mintAmount1 = 1_000_000;
      const mintAmount2 = 2_000_000;

      simnet.callPublicFn(
        "mock-token",
        "mint",
        [Cl.uint(mintAmount1), Cl.principal(alice)],
        alice
      );

      simnet.callPublicFn(
        "mock-token",
        "mint",
        [Cl.uint(mintAmount2), Cl.principal(bob)],
        bob
      );

      const { result } = simnet.callReadOnlyFn(
        "mock-token",
        "get-total-supply",
        [],
        alice
      );

      expect(result).toBeOk(Cl.uint(mintAmount1 + mintAmount2));
    });

    it("allows multiple mints to same recipient", () => {
      const mintAmount1 = 1_000_000;
      const mintAmount2 = 500_000;

      simnet.callPublicFn(
        "mock-token",
        "mint",
        [Cl.uint(mintAmount1), Cl.principal(alice)],
        alice
      );

      simnet.callPublicFn(
        "mock-token",
        "mint",
        [Cl.uint(mintAmount2), Cl.principal(alice)],
        alice
      );

      const { result } = simnet.callReadOnlyFn(
        "mock-token",
        "get-balance",
        [Cl.principal(alice)],
        alice
      );

      expect(result).toBeOk(Cl.uint(mintAmount1 + mintAmount2));
    });
  });

  describe("Transfers", () => {
    beforeEach(() => {
      // Mint tokens to alice for transfer tests
      simnet.callPublicFn(
        "mock-token",
        "mint",
        [Cl.uint(10_000_000), Cl.principal(alice)],
        alice
      );
    });

    it("allows token transfer from sender to recipient", () => {
      const transferAmount = 1_000_000;
      const { result, events } = simnet.callPublicFn(
        "mock-token",
        "transfer",
        [
          Cl.uint(transferAmount),
          Cl.principal(alice),
          Cl.principal(bob),
          Cl.none(),
        ],
        alice
      );

      expect(result).toBeOk(Cl.bool(true));
      expect(events.length).toBeGreaterThan(0);
      expect(events[0].event).toBe("ft_transfer_event");
      expect(events[0].data.amount).toBe(transferAmount.toString());
      expect(events[0].data.sender).toBe(alice);
      expect(events[0].data.recipient).toBe(bob);
    });

    it("updates balances after transfer", () => {
      const transferAmount = 2_000_000;
      const initialAliceBalance = 10_000_000;

      simnet.callPublicFn(
        "mock-token",
        "transfer",
        [
          Cl.uint(transferAmount),
          Cl.principal(alice),
          Cl.principal(bob),
          Cl.none(),
        ],
        alice
      );

      const aliceBalance = simnet.callReadOnlyFn(
        "mock-token",
        "get-balance",
        [Cl.principal(alice)],
        alice
      );
      expect(aliceBalance.result).toBeOk(
        Cl.uint(initialAliceBalance - transferAmount)
      );

      const bobBalance = simnet.callReadOnlyFn(
        "mock-token",
        "get-balance",
        [Cl.principal(bob)],
        bob
      );
      expect(bobBalance.result).toBeOk(Cl.uint(transferAmount));
    });

    it("fails when non-owner tries to transfer", () => {
      const transferAmount = 1_000_000;
      const { result } = simnet.callPublicFn(
        "mock-token",
        "transfer",
        [
          Cl.uint(transferAmount),
          Cl.principal(alice),
          Cl.principal(charlie),
          Cl.none(),
        ],
        bob // bob trying to transfer alice's tokens
      );

      expect(result).toBeErr(Cl.uint(101)); // err-not-token-owner
    });

    it("allows transfer with memo", () => {
      const transferAmount = 500_000;
      const memo = Cl.bufferFromUtf8("test memo");

      const { result, events } = simnet.callPublicFn(
        "mock-token",
        "transfer",
        [
          Cl.uint(transferAmount),
          Cl.principal(alice),
          Cl.principal(bob),
          Cl.some(memo),
        ],
        alice
      );

      expect(result).toBeOk(Cl.bool(true));
      expect(events.length).toBeGreaterThan(0);
    });

    it("fails when transferring more than balance", () => {
      const { result } = simnet.callPublicFn(
        "mock-token",
        "transfer",
        [
          Cl.uint(20_000_000), // more than alice has
          Cl.principal(alice),
          Cl.principal(bob),
          Cl.none(),
        ],
        alice
      );

      expect(result).toBeErr(Cl.uint(1)); // insufficient balance error
    });
  });

  describe("Balance Queries", () => {
    it("returns zero balance for account with no tokens", () => {
      const { result } = simnet.callReadOnlyFn(
        "mock-token",
        "get-balance",
        [Cl.principal(charlie)],
        charlie
      );

      expect(result).toBeOk(Cl.uint(0));
    });

    it("returns correct balance after multiple operations", () => {
      const mintAmount = 5_000_000;
      const transferAmount = 1_000_000;

      simnet.callPublicFn(
        "mock-token",
        "mint",
        [Cl.uint(mintAmount), Cl.principal(alice)],
        alice
      );

      simnet.callPublicFn(
        "mock-token",
        "transfer",
        [
          Cl.uint(transferAmount),
          Cl.principal(alice),
          Cl.principal(bob),
          Cl.none(),
        ],
        alice
      );

      const { result } = simnet.callReadOnlyFn(
        "mock-token",
        "get-balance",
        [Cl.principal(alice)],
        alice
      );

      expect(result).toBeOk(Cl.uint(mintAmount - transferAmount));
    });
  });

  describe("Total Supply", () => {
    it("returns zero when no tokens minted", () => {
      const { result } = simnet.callReadOnlyFn(
        "mock-token",
        "get-total-supply",
        [],
        alice
      );

      expect(result).toBeOk(Cl.uint(0));
    });

    it("total supply is not affected by transfers", () => {
      const mintAmount = 10_000_000;
      const transferAmount = 3_000_000;

      simnet.callPublicFn(
        "mock-token",
        "mint",
        [Cl.uint(mintAmount), Cl.principal(alice)],
        alice
      );

      const beforeTransfer = simnet.callReadOnlyFn(
        "mock-token",
        "get-total-supply",
        [],
        alice
      );

      simnet.callPublicFn(
        "mock-token",
        "transfer",
        [
          Cl.uint(transferAmount),
          Cl.principal(alice),
          Cl.principal(bob),
          Cl.none(),
        ],
        alice
      );

      const afterTransfer = simnet.callReadOnlyFn(
        "mock-token",
        "get-total-supply",
        [],
        alice
      );

      expect(beforeTransfer.result).toEqual(afterTransfer.result);
      expect(afterTransfer.result).toBeOk(Cl.uint(mintAmount));
    });
  });
});
