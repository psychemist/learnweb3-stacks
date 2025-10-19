import {
  addLiquidity,
  createPool,
  Pool,
  removeLiquidity,
  swap,
} from "@/lib/amm";
import {
  AppConfig,
  connect,
  disconnect,
  isConnected,
  getLocalStorage,
  openContractCall,
  type UserData,
  UserSession,
} from "@stacks/connect";
import { PostConditionMode } from "@stacks/transactions";
import { useEffect, useState } from "react";

const appDetails = {
  name: "Full Range AMM",
  icon: "https://cryptologos.cc/logos/stacks-stx-logo.png",
};

const appConfig = new AppConfig(["store_write", "publish_data"]);
const userSession = new UserSession({ appConfig });

export function useStacks() {
  const [userData, setUserData] = useState<UserData | null>(null);
  const [userAddress, setUserAddress] = useState<string | null>(null);

  async function connectWallet() {
    try {
      console.log("=== Connecting Wallet ===");
      await connect();
      console.log("Wallet connected successfully");
      
      // Get user address after connection
      let address = null;
      if (isConnected()) {
        const data = getLocalStorage();
        if (data?.addresses?.stx && data.addresses.stx.length > 0) {
          address = data.addresses.stx[0].address;
          setUserAddress(address);
        }
      } else if (userSession.isUserSignedIn()) {
        const userData = userSession.loadUserData();
        address = userData.profile.stxAddress.testnet;
        setUserAddress(address);
        setUserData(userData);
      }
      
      // Reload to update state
      window.location.reload();
    } catch (error) {
      console.error("Connection failed:", error);
      window.alert("Failed to connect wallet. Please try again.");
    }
  }

  function disconnectWallet() {
    disconnect();
    userSession.signUserOut("/");
    setUserData(null);
    setUserAddress(null);
  }

  async function handleCreatePool(token0: string, token1: string, fee: number) {
    try {
      if (!userData && !userAddress) throw new Error("User not connected");
      const options = await createPool(token0, token1, fee);
      await openContractCall({
        ...options,
        appDetails,
        onFinish: (data) => {
          window.alert("Sent create pool transaction");
          console.log(data);
        },
        postConditionMode: PostConditionMode.Allow,
      });
    } catch (_err) {
      const err = _err as Error;
      console.log(err);
      window.alert(err.message);
      return;
    }
  }

  async function handleSwap(pool: Pool, amount: number, zeroForOne: boolean) {
    try {
      if (!userData && !userAddress) throw new Error("User not connected");
      const options = await swap(pool, amount, zeroForOne);
      await openContractCall({
        ...options,
        appDetails,
        onFinish: (data) => {
          window.alert("Sent swap transaction");
          console.log(data);
        },
        postConditionMode: PostConditionMode.Allow,
      });
    } catch (_err) {
      const err = _err as Error;
      console.log(err);
      window.alert(err.message);
      return;
    }
  }

  async function handleAddLiquidity(
    pool: Pool,
    amount0: number,
    amount1: number
  ) {
    try {
      if (!userData && !userAddress) throw new Error("User not connected");
      const options = await addLiquidity(pool, amount0, amount1);
      await openContractCall({
        ...options,
        appDetails,
        onFinish: (data) => {
          window.alert("Sent add liquidity transaction");
          console.log({ data });
        },
        postConditionMode: PostConditionMode.Allow,
      });
    } catch (_err) {
      const err = _err as Error;
      console.log(err);
      window.alert(err.message);
      return;
    }
  }

  async function handleRemoveLiquidity(pool: Pool, liquidity: number) {
    try {
      if (!userData && !userAddress) throw new Error("User not connected");
      const options = await removeLiquidity(pool, liquidity);
      await openContractCall({
        ...options,
        appDetails,
        onFinish: (data) => {
          window.alert("Sent remove liquidity transaction");
          console.log(data);
        },
        postConditionMode: PostConditionMode.Allow,
      });
    } catch (_err) {
      const err = _err as Error;
      console.log(err);
      window.alert(err.message);
      return;
    }
  }

  useEffect(() => {
    // Check if user is connected via new connect method
    if (isConnected()) {
      const data = getLocalStorage();
      if (data?.addresses?.stx && data.addresses.stx.length > 0) {
        const address = data.addresses.stx[0].address;
        setUserAddress(address);
        // Create minimal userData for compatibility
        setUserData({
          profile: {
            stxAddress: {
              testnet: address,
              mainnet: address,
            },
          },
        } as UserData);
      }
    } else if (userSession.isSignInPending()) {
      userSession.handlePendingSignIn().then((userData) => {
        setUserData(userData);
        setUserAddress(userData.profile.stxAddress.testnet);
      });
    } else if (userSession.isUserSignedIn()) {
      const userData = userSession.loadUserData();
      setUserData(userData);
      setUserAddress(userData.profile.stxAddress.testnet);
    }
  }, []);

  return {
    userData,
    userAddress,
    handleCreatePool,
    handleSwap,
    handleAddLiquidity,
    handleRemoveLiquidity,
    connectWallet,
    disconnectWallet,
    isConnected: isConnected() || userSession.isUserSignedIn(),
  };
}