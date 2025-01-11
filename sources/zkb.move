module zkb::verify {

    //
    // [*] Dependencies
    //

    use std::signer;

    //
    // [*] Constants
    //
    const ERR_NOT_ADMIN: u64 = 0x4000;
    const ERR_NOT_INITIALIZED: u64 = 0x4001;
    const ERR_NOT_PROVED: u64 = 0x4002;

    //
    // [*] Structures
    //
    struct ProofStatus has key, store {
        proofs: u64
    }

    struct Knowledge has key, drop, copy {
        value: u64
    }

    //
    // [*] Module Initialization
    //
    public entry fun initialize(account: &signer) {
        assert!(signer::address_of(account) == @challenger, ERR_NOT_ADMIN);
        move_to(account, ProofStatus { proofs: 0 });
        move_to(account, Knowledge { value: 0 });
    }

    //
    // [*] Public functions
    //
    public fun prove(
        knowledge: &mut Knowledge, secret_number: u64, _account: &signer
    ) acquires ProofStatus {
        if (knowledge.value != 0) {
            if (knowledge.value == secret_number) {
                if (exists<ProofStatus>(@challenger)) {
                    let challenge_status = borrow_global_mut<ProofStatus>(@challenger);
                    challenge_status.proofs = challenge_status.proofs + 1;
                    knowledge.value = 0;
                };
            };
        };
    }

    public entry fun set_knowledge(account: &signer, value: u64) acquires Knowledge {
        assert!(signer::address_of(account) == @challenger, ERR_NOT_ADMIN);
        assert!(exists<Knowledge>(@challenger), ERR_NOT_INITIALIZED);
        let knowledge = borrow_global_mut<Knowledge>(@challenger);
        knowledge.value = value;
    }

    public entry fun is_proved(_account: &signer) acquires ProofStatus {
        assert!(exists<ProofStatus>(@challenger), ERR_NOT_INITIALIZED);
        let challenge_status = borrow_global_mut<ProofStatus>(@challenger);
        assert!(challenge_status.proofs >= 3, ERR_NOT_PROVED);
    }

    #[view]
    public fun get_knowledge(): Knowledge acquires Knowledge {
        assert!(exists<Knowledge>(@challenger), ERR_NOT_INITIALIZED);
        *borrow_global<Knowledge>(@challenger)
    }

    use std::debug;
    use std::bcs;
    use aptos_std::from_bcs;

    // solution
    #[test(account = @1338, challenger = @challenger, aptos_framework = @0x1)]
    public entry fun solve(account: &signer, challenger: &signer) acquires Knowledge, ProofStatus {
        initialize(challenger);

        for (i in 0..3) {
            set_knowledge(challenger, 10);
            let knowledge = get_knowledge();
            let secret = from_bcs::to_u64(bcs::to_bytes(&knowledge));
            prove(&mut knowledge, secret, account);
            debug::print(&secret);
        };
        is_proved(account);
    }
}
