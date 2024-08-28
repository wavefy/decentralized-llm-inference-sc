module dllm_addr::dllm {
  use std::bcs;
  use std::signer;
  use std::vector;
  use std::string::String;
  use aptos_framework::event;
  use aptos_std::string_utils;
  use aptos_framework::object;
  use aptos_std::smart_table::{Self, SmartTable};


  // =============================== Events ===============================
  #[event]
  struct SessionCreated has drop, store {
    session_id: u64,
    owner: address,
    uid: String,
    session_expiration: u64,
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
    token_count: u64,
  }

  // =============================== Constants ===============================

  const SET_PRICE_PER_TOKEN: u64 = 1;
  const E_SESSION_NOT_FOUND: u64 = 1;
  const E_INSUFFICIENT_TOKENS: u64 = 2;
  const E_CANNOT_CLAIM_OWN_TOKENS: u64 = 3;
  const E_SESSION_EXPIRED: u64 = 4;
  const E_INVALID_CLAIM: u64 = 5;

  // =============================== Storage ===============================
  struct BalanceStorage has key {
    balance: u64,
  }

  struct SessionCounter has key {
    counter: u64,
  }

  struct Session has key {
    session_id: u64,
    owner: address,
    addresses: SmartTable<address, bool>,
    session_expiration: u64,
    price_per_token: u64,
    max_tokens: u64,
    token_count: u64,
  }

  struct SessionView has drop {
    session_id: u64,
    owner: address,
    addresses: vector<address>,
    session_expiration: u64,
    price_per_token: u64,
    max_tokens: u64,
    token_count: u64,
  }


  public entry fun create_session(account: &signer, uid: String, session_expiration: u64, max_tokens: u64, addresses: vector<address>) acquires SessionCounter {
    let signer_address = signer::address_of(account);

    let counter = if (exists<SessionCounter>(signer_address)) {
      let session_counter = borrow_global_mut<SessionCounter>(signer_address);
      session_counter.counter
    } else {
      let new_counter = SessionCounter { counter: 0 };
      move_to(account, new_counter);
      0
    };

    let object_holds_session_construct_ref = object::create_named_object(account, generate_session_id(counter));
    let obj_signer = object::generate_signer(&object_holds_session_construct_ref); 

    let address_table = smart_table::new<address, bool>();

    vector::for_each_ref(&addresses, |address| {
      smart_table::add(&mut address_table, *address, true);
    });

    let session = Session {
      session_id: counter,
      owner: signer_address,
      addresses: address_table,
      session_expiration,
      price_per_token: SET_PRICE_PER_TOKEN,
      max_tokens,
      token_count: 0,
    };

    move_to(&obj_signer, session);


    event::emit(SessionCreated {
      session_id: counter,
      owner: signer_address,
      uid,
      session_expiration,
      price_per_token: SET_PRICE_PER_TOKEN,
      max_tokens,
    });

    // Increment the counter
    let counter_mut = borrow_global_mut<SessionCounter>(signer_address);
    counter_mut.counter = counter_mut.counter + 1;
  }

  public entry fun update_session_addresses(account: &signer, session_id: u64, addresses: vector<address>) acquires Session {
    let signer_address = signer::address_of(account);
    let session_obj_addr = object::create_object_address(&signer_address, generate_session_id(session_id));
    assert_address_has_session(session_obj_addr);

    let session = borrow_global_mut<Session>(session_obj_addr);
    smart_table::clear(&mut session.addresses);
    vector::for_each_ref(&addresses, |address| {
      smart_table::add(&mut session.addresses, *address, true);
    });

    event::emit(SessionUpdated {
      session_id,
      owner: signer_address,
      addresses: addresses,
      token_count: session.token_count,
    });

  }

  public entry fun update_token_count(account: &signer, session_id: u64, token_count: u64) acquires Session {
    let signer_address = signer::address_of(account);
    let session_obj_addr = object::create_object_address(&signer_address, generate_session_id(session_id));
    assert_address_has_session(session_obj_addr);
    let session = borrow_global_mut<Session>(session_obj_addr);
    session.token_count = token_count;

    event::emit(SessionUpdated {
      session_id,
      owner: signer_address,
      addresses: vector::empty(),
      token_count,
    });
  }

  public entry fun claim_tokens(account: &signer, owner_address: address, session_id: u64, token_count: u64) acquires Session {
    let signer_address = signer::address_of(account);

    let session_obj_addr = object::create_object_address(&owner_address, generate_session_id(session_id));
    assert_address_has_session(session_obj_addr);
    let session = borrow_global_mut<Session>(session_obj_addr);
    assert!(session.owner != signer_address, E_CANNOT_CLAIM_OWN_TOKENS);
    assert!(smart_table::contains(&session.addresses, signer_address), E_INVALID_CLAIM);
    assert!(session.token_count >= token_count, E_INSUFFICIENT_TOKENS);

    session.token_count = session.token_count - token_count;

    event::emit(TokenClaimed {
      session_id,
      owner: owner_address,
      claimer: signer_address,
      token_count,
    });
  }

  // =============================== View functions ===============================

  #[view]
  public fun get_session_counter(signer_address: address): u64 acquires SessionCounter {
    if (exists<SessionCounter>(signer_address)) {
      let session_counter = borrow_global<SessionCounter>(signer_address);
      session_counter.counter
    } else {
      0
    }
  }

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
    let session_view = SessionView {
      session_id,
      owner: session.owner,
      addresses: smart_table::keys(&session.addresses),
      session_expiration: session.session_expiration,
      price_per_token: session.price_per_token,
      max_tokens: session.max_tokens,
      token_count: session.token_count,
    };
    session_view
  }

  #[view]
  public fun address_claimable(owner_address: address, session_id: u64, claimer_address: address): bool acquires Session {
    let session_obj_addr = object::create_object_address(&owner_address, generate_session_id(session_id));
    assert_address_has_session(session_obj_addr);
    let session = borrow_global<Session>(session_obj_addr);
    smart_table::contains(&session.addresses, claimer_address)
  }




  // =============================== Helper functions ===============================

  fun generate_session_id(counter: u64): vector<u8> {
    bcs::to_bytes(&string_utils::format2(&b"dllm_session_{}_{}", @dllm_addr, counter))
  }

  fun assert_address_has_session(addr: address) {
    assert!(exists<Session>(addr), E_SESSION_NOT_FOUND)
  }


  // =============================== Tests ===============================
  #[test_only]
  use std::string;
  #[test_only]
  use aptos_framework::account;

  #[test(admin = @0x100, server_a = @0xcafea, server_b = @0xdeadbeef)]
  public entry fun test_end_to_end(admin: &signer, server_a: &signer, server_b: &signer) acquires SessionCounter, Session {
    let admin_address = signer::address_of(admin);
    let session_idx = get_session_counter(admin_address);

    assert!(session_idx == 0, 1);
    account::create_account_for_test(admin_address);

    assert!(!has_session(admin_address, session_idx), 2);

    let addresses = vector::empty();
    vector::push_back(&mut addresses, signer::address_of(server_a));
    vector::push_back(&mut addresses, signer::address_of(server_b));

    create_session(admin, string::utf8(b"test_session"), 100, 100, addresses);

    assert!(has_session(admin_address, session_idx), 3);

    let session = get_session(admin_address, session_idx);
    assert!(session.owner == admin_address, 4);
    assert!(session.session_expiration == 100, 5);
    assert!(session.price_per_token == 1, 6);
    assert!(session.max_tokens == 100, 7);
    assert!(address_claimable(admin_address, session_idx, signer::address_of(server_a)), 8);
    assert!(address_claimable(admin_address, session_idx, signer::address_of(server_b)), 9);
    

    // Update the addresses
    let new_addresses = vector::empty();
    vector::push_back(&mut new_addresses, signer::address_of(server_a));
    update_session_addresses(admin, session_idx, new_addresses);

    // Check if the addresses are updated
    assert!(address_claimable(admin_address, session_idx, signer::address_of(server_a)), 10);
    assert!(!address_claimable(admin_address, session_idx, signer::address_of(server_b)), 11);

    // Update the token count
    update_token_count(admin, session_idx, 50);
    let updated_session = get_session(admin_address, session_idx);
    assert!(updated_session.token_count == 50, 12);

    // Claim tokens
    claim_tokens(server_a, admin_address, session_idx, 10);
    let updated_session = get_session(admin_address, session_idx);
    assert!(updated_session.token_count == 40, 13);
  }

}