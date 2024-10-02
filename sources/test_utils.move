#[test_only]
module dllm_addr::test_utils {
  use aptos_framework::aptos_coin::{Self, AptosCoin};
  use aptos_framework::coin::{Self, Coin};
  use aptos_framework::account;
  use aptos_framework::timestamp;
  use aptos_framework::signer;
  use aptos_std::ed25519;

  public inline fun setup(
        aptos_framework: &signer,
        client: &signer,
        server_a: &signer,
        server_b: &signer,
    ): (address, address, address, ed25519::SecretKey, ed25519::UnvalidatedPublicKey) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);

        let client_addr = signer::address_of(client);
        account::create_account_for_test(client_addr);
        coin::register<AptosCoin>(client);

        let server_a_addr = signer::address_of(server_a);
        account::create_account_for_test(server_a_addr);
        coin::register<AptosCoin>(server_a);

        let server_b_addr = signer::address_of(server_b);
        account::create_account_for_test(server_b_addr);
        coin::register<AptosCoin>(server_b);

        let coins = coin::mint(10000, &mint_cap);
        coin::deposit(server_a_addr, coins);
        let coins = coin::mint(10000, &mint_cap);
        coin::deposit(server_b_addr, coins);
        let coins = coin::mint(10000, &mint_cap);
        coin::deposit(client_addr, coins);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        let (sk, vpk) = ed25519::generate_keys();
        let pk = ed25519::public_key_into_unvalidated(vpk);

        (client_addr, server_a_addr, server_b_addr, sk, pk)
    }
}