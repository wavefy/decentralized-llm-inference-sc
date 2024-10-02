module dllm_addr::dllm {
  use std::bcs;
  use std::signer;
  use std::vector;
  use aptos_framework::event;
  use aptos_std::string_utils;
  use aptos_framework::object;
  use aptos_framework::coin::{Self, Coin};
  use aptos_framework::aptos_coin::AptosCoin; 
  use aptos_std::ed25519;


  // =============================== Events ===============================
  #[event]
  struct SessionCreated has drop, store {
    session_id: u64,
    owner: address,
    price_per_token: u64,
    max_tokens: u64,
  }

  #[event]
  struct TokenClaimed has drop, store {
    session_id: u64,
    owner: address,
    claimer: address,
    token_count: u64,
  }

  #[event]
  struct SessionUpdated has drop, store {
    session_id: u64,
    owner: address,
    addresses: vector<address>,
  }

  #[event]
  struct PoolDeposit has drop, store {
    owner: address,
    amount: u64,
  }

  // =============================== Constants ===============================

  const SET_PRICE_PER_TOKEN: u64 = 1;

  const E_SESSION_NOT_FOUND: u64 = 1;
  const E_INSUFFICIENT_TOKENS: u64 = 2;
  const E_CANNOT_CLAIM_OWN_TOKENS: u64 = 3;
  const E_INVALID_CLAIM: u64 = 4;
  const E_BALANCE_INSUFFICIENT: u64 = 5;

  // =============================== Storage ===============================
  struct RewardPool has key {
    coins: Coin<AptosCoin>
  }

  struct Session has key {
    session_id: u64,
    owner: address,
    addresses: vector<address>,
    layers: vector<u64>,
    price_per_token: u64,
    max_tokens: u64,
    claimed: vector<address>,
    pk: ed25519::UnvalidatedPublicKey,
  }

  struct SessionView has drop {
    session_id: u64,
    owner: address,
    addresses: vector<address>,
    layers: vector<u64>,
    price_per_token: u64,
    max_tokens: u64,
    claimed: vector<address>,
  }

  public entry fun deposit(account: &signer, amount: u64) acquires RewardPool {
    let signer_address = signer::address_of(account);

    if (!exists<RewardPool>(signer_address)) {
      let pool = RewardPool { coins: coin::zero<AptosCoin>() };
      move_to(account, pool);
    };

    let pool = borrow_global_mut<RewardPool>(signer_address);
    let coins = coin::withdraw<AptosCoin>(account, amount);
    coin::merge(&mut pool.coins, coins);

    event::emit(PoolDeposit {
      owner: signer_address,
      amount,
    });
  }


  public entry fun create_session(account: &signer, session_id: u64, max_tokens: u64, addresses: vector<address>, layers: vector<u64>, client_pk: vector<u8>) acquires RewardPool {
    let signer_address = signer::address_of(account);

    let num_layers = vector::fold(layers, 0, |acc, x| acc + x);
    let min_balance = num_layers * SET_PRICE_PER_TOKEN * max_tokens; 

    let pool = borrow_global<RewardPool>(signer_address);
    assert!(coin::value(&pool.coins) >= min_balance, E_BALANCE_INSUFFICIENT);

    let object_holds_session_construct_ref = object::create_named_object(account, generate_session_id(session_id));
    let obj_signer = object::generate_signer(&object_holds_session_construct_ref); 

    let pub_key = ed25519::new_unvalidated_public_key_from_bytes(client_pk);

    let session = Session {
      session_id,
      owner: signer_address,
      addresses,
      layers,
      price_per_token: SET_PRICE_PER_TOKEN,
      max_tokens,
      claimed: vector::empty(),
      pk: pub_key,
    };

    move_to(&obj_signer, session);

    event::emit(SessionCreated {
      session_id,
      owner: signer_address,
      price_per_token: SET_PRICE_PER_TOKEN,
      max_tokens,
    });
  }

  public entry fun claim_tokens(account: &signer, owner_address: address, session_id: u64, token_count: u64, signature: vector<u8>) acquires Session, RewardPool {
    let signer_address = signer::address_of(account);
    let session_obj_addr = object::create_object_address(&owner_address, generate_session_id(session_id));

    assert_address_has_session(session_obj_addr);
    let session = borrow_global_mut<Session>(session_obj_addr);
    assert!(session.max_tokens >= token_count, E_INVALID_CLAIM);

    let signature = ed25519::new_signature_from_bytes(signature);
    let count_bytes = bcs::to_bytes(&token_count);
    let is_valid = ed25519::signature_verify_strict(&signature, &session.pk, count_bytes);

    assert!(is_valid, E_INVALID_CLAIM);
    assert!(session.owner != signer_address, E_CANNOT_CLAIM_OWN_TOKENS);
    assert!(!vector::contains(&session.claimed, &signer_address), E_INVALID_CLAIM);

    let (_, address_idx) = vector::index_of(&session.addresses, &signer_address);
    let layers = *vector::borrow(&session.layers, address_idx);

    let reward_pool = borrow_global_mut<RewardPool>(owner_address);
    let total_reward = token_count * layers * session.price_per_token;
    let coins = coin::extract(&mut reward_pool.coins, total_reward);
    coin::deposit<AptosCoin>(signer_address, coins);

    vector::push_back(&mut session.claimed, signer_address);

    event::emit(TokenClaimed {
      session_id,
      owner: owner_address,
      claimer: signer_address,
      token_count,
    });
  }

  // =============================== View functions ===============================

  #[view]
  public fun has_session(signer_address: address, session_id: u64): bool {
    let session_obj_addr = object::create_object_address(&signer_address, generate_session_id(session_id));
    exists<Session>(session_obj_addr)
  }

  #[view]
  public fun get_session(signer_address: address, session_id: u64): SessionView acquires Session {
    let session_obj_addr = object::create_object_address(&signer_address, generate_session_id(session_id));
    assert_address_has_session(session_obj_addr);

    let session = borrow_global<Session>(session_obj_addr);
    SessionView {
      session_id: session.session_id,
      owner: session.owner,
      addresses: session.addresses,
      price_per_token: session.price_per_token,
      max_tokens: session.max_tokens,
      layers: session.layers,
      claimed: session.claimed,
    }
  }

  #[view]
  public fun get_balance(signer_address: address): u64 acquires RewardPool {
    let pool = borrow_global<RewardPool>(signer_address);
    coin::value(&pool.coins)
  }


  // =============================== Helper functions ===============================

  fun generate_session_id(session_id: u64): vector<u8> {
    bcs::to_bytes(&string_utils::format2(&b"dllm_session_{}_{}", @dllm_addr, session_id))
  }

  fun assert_address_has_session(addr: address) {
    assert!(exists<Session>(addr), E_SESSION_NOT_FOUND)
  }


  // =============================== Tests ===============================
  #[test_only]
  use std::string;
  #[test_only]
  use aptos_framework::account;
  #[test_only]
  use dllm_addr::test_utils::{setup};
  #[test_only]
  use aptos_std::debug;

  #[test(aptos_framework = @0x1, admin = @0x1000, server_a = @0x1111, server_b = @0x2222)]
  public entry fun should_success_create_session(aptos_framework: &signer, admin: &signer, server_a: &signer, server_b: &signer) acquires Session, RewardPool {
    let admin_address = signer::address_of(admin);
    let (client_addr, server_a_addr, server_b_addr, sk, pk) = setup(aptos_framework, admin, server_a, server_b);


    // deposit to the reward pool
    deposit(admin, 1000);
    assert!(coin::value(&borrow_global<RewardPool>(admin_address).coins) == 1000, 1);

    let session_id: u64 = 1;
    create_session(admin, session_id, 10, vector[server_a_addr, server_b_addr], vector[10, 10], ed25519::unvalidated_public_key_to_bytes(&pk));

    // Should have session
    assert!(has_session(admin_address, session_id), 1);

    // Check the session
    let session_obj_addr = object::create_object_address(&admin_address, generate_session_id(session_id));
    let session = borrow_global<Session>(session_obj_addr);

    assert!(session.session_id == session_id, 1);
    assert!(session.owner == admin_address, 1);
    assert!(session.addresses == vector[server_a_addr, server_b_addr], 1);
    assert!(session.layers == vector[10, 10], 1);
    assert!(session.price_per_token == SET_PRICE_PER_TOKEN, 1);
    assert!(session.max_tokens == 10, 1);
  }

  #[test(aptos_framework = @0x1, admin = @0x1001, server_a = @0x1111, server_b = @0x2222)]
  public entry fun should_success_claim_tokens(aptos_framework: &signer, admin: &signer, server_a: &signer, server_b: &signer) acquires Session, RewardPool {
    let admin_address = signer::address_of(admin);
    let (client_addr, server_a_addr, server_b_addr, sk, pk) = setup(aptos_framework, admin, server_a, server_b);

    // deposit to the reward pool
    deposit(admin, 1000);
    assert!(coin::value(&borrow_global<RewardPool>(admin_address).coins) == 1000, 1);

    let session_id = 1;
    create_session(admin, session_id, 10, vector[server_a_addr, server_b_addr], vector[10, 10], ed25519::unvalidated_public_key_to_bytes(&pk));

    // Should have session
    assert!(has_session(admin_address, session_id), 2);

    let count: u64 = 1;
    let count_bytes: vector<u8> = bcs::to_bytes(&count);
    let signature = ed25519::signature_to_bytes(&ed25519::sign_arbitrary_bytes(&sk, count_bytes));

    // Claim tokens
    claim_tokens(server_a, admin_address, session_id, 1, signature);

    // Check the session
    let session_obj_addr = object::create_object_address(&admin_address, generate_session_id(session_id));
    let session = borrow_global<Session>(session_obj_addr);

    assert!(vector::contains(&session.claimed, &server_a_addr), 3);

    // Check balance
    assert!(coin::balance<AptosCoin>(server_a_addr) == 10010, 4);
    assert!(coin::value<AptosCoin>(&borrow_global<RewardPool>(admin_address).coins) == 990, 5);
  }

  #[test(aptos_framework = @0x1, admin = @0x1000, server_a = @0x1111, server_b = @0x2222)]
  #[expected_failure(abort_code = 4, location = Self)]
  public entry fun should_fail_reclaim_tokens(aptos_framework: &signer, admin: &signer, server_a: &signer, server_b: &signer) acquires Session, RewardPool {
    let admin_address = signer::address_of(admin);
    let (client_addr, server_a_addr, server_b_addr, sk, pk) = setup(aptos_framework, admin, server_a, server_b);

    // deposit to the reward pool
    deposit(admin, 1000);
    assert!(coin::value(&borrow_global<RewardPool>(admin_address).coins) == 1000, 1);

    let session_id = 1;
    create_session(admin, session_id, 10, vector[server_a_addr, server_b_addr], vector[10, 10], ed25519::unvalidated_public_key_to_bytes(&pk));

    // Should have session
    assert!(has_session(admin_address, session_id), 1);

    let count: u64 = 1;
    let count_bytes: vector<u8> = bcs::to_bytes(&count);
    let signature = ed25519::signature_to_bytes(&ed25519::sign_arbitrary_bytes(&sk, count_bytes));    // Claim tokens
    claim_tokens(server_a, admin_address, session_id, 1, signature);
    claim_tokens(server_a, admin_address, session_id, 1, signature);
  }

  #[test(aptos_framework = @0x1, admin = @0x1000, server_a = @0x1111, server_b = @0x2222)]
  #[expected_failure(abort_code = 3, location = Self)]
  public entry fun should_fail_claim_own_tokens(aptos_framework: &signer, admin: &signer, server_a: &signer, server_b: &signer) acquires Session, RewardPool {
    let admin_address = signer::address_of(admin);
    let (client_addr, server_a_addr, server_b_addr, sk, pk) = setup(aptos_framework, admin, server_a, server_b);

    // deposit to the reward pool
    deposit(admin, 1000);
    assert!(coin::value(&borrow_global<RewardPool>(admin_address).coins) == 1000, 1);

    let session_id = 1;
    create_session(admin, session_id, 10, vector[server_a_addr, server_b_addr], vector[10, 10], ed25519::unvalidated_public_key_to_bytes(&pk));

    // Should have session
    assert!(has_session(admin_address, session_id), 1);

    let count: u64 = 1;
    let count_bytes: vector<u8> = bcs::to_bytes(&count);
    let signature = ed25519::signature_to_bytes(&ed25519::sign_arbitrary_bytes(&sk, count_bytes));
    // Claim tokens
    claim_tokens(admin, admin_address, session_id, 1, signature);
  }


  #[test(aptos_framework = @0x1, admin = @0x1000, server_a = @0x1111, server_b = @0x2222)]
  #[expected_failure(abort_code = 5, location = Self)]
  public entry fun should_fail_create_session_with_insufficient_balance(aptos_framework: &signer, admin: &signer, server_a: &signer, server_b: &signer) acquires RewardPool {
    let admin_address = signer::address_of(admin);
    let (client_addr, server_a_addr, server_b_addr, sk, pk) = setup(aptos_framework, admin, server_a, server_b);

    // deposit to the reward pool
    deposit(admin, 1000);
    assert!(coin::value(&borrow_global<RewardPool>(admin_address).coins) == 1000, 1);

    let session_id = 1;
    // Create session with 100 max tokens, with 20 layers coins
    // So, the minimum balance should be 1 * 100 * 20 = 2000
    create_session(admin, session_id, 100, vector[server_a_addr, server_b_addr], vector[10, 10], ed25519::unvalidated_public_key_to_bytes(&pk));
  }
}