import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure can create trend",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("trend-weave", "create-trend", [
        types.utf8("Test Trend"),
        types.utf8("Test Description"),
        types.list([types.utf8("tag1"), types.utf8("tag2")])
      ], wallet_1.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 2);
    
    const result = chain.callReadOnlyFn("trend-weave", "get-trend", [types.uint(0)], wallet_1.address);
    assertEquals(result.result.expectOk().expectSome().data["title"].value, types.utf8("Test Trend"));
  },
});

Clarinet.test({
  name: "Ensure can vote on trend",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    const wallet_2 = accounts.get("wallet_2")!;
    
    chain.mineBlock([
      Tx.contractCall("trend-weave", "create-trend", [
        types.utf8("Test Trend"),
        types.utf8("Test Description"),
        types.list([types.utf8("tag1")])
      ], wallet_1.address)
    ]);

    let block = chain.mineBlock([
      Tx.contractCall("trend-weave", "vote", [types.uint(0), types.bool(true)], wallet_2.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 3);
    
    const result = chain.callReadOnlyFn("trend-weave", "get-trend", [types.uint(0)], wallet_1.address);
    assertEquals(result.result.expectOk().expectSome().data["upvotes"].value, types.uint(1));
  },
});
