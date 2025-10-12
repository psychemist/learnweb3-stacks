import { getAllPools } from "@/lib/amm";
import { PoolsList } from "@/components/pools";
import { CreatePool } from "@/components/create-pool";
import { AddLiquidity } from "@/components/add-liquidity";
import { RemoveLiquidity } from "@/components/remove-liquidity";

export default async function Pools() {
  const allPools = await getAllPools();

  return (
    <main className="flex min-h-screen flex-col gap-8 p-24">
      <h1 className="text-3xl font-bold">Pools</h1>
      <PoolsList pools={allPools} />
      <hr />
      <div className="flex justify-center gap-8">
        <CreatePool />
        {allPools.length > 0 ? (
          <>
            <AddLiquidity pools={allPools} />
            <RemoveLiquidity pools={allPools} />
          </>
        ) : null}
      </div>
    </main>
  );
}