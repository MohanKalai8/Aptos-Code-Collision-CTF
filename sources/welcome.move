module challenge::welcome {
    use aptos_framework::signer;

    struct ChallengeStatus has key {
        is_solved: bool,
    }

    public entry fun initialize(account: &signer) {
        let account_address = signer::address_of(account);
        assert!(account_address == @challenger, 0);
        move_to(account, ChallengeStatus { is_solved: false })
    }

    public entry fun solve(account: &signer) acquires ChallengeStatus {
        let challenge_status = borrow_global_mut<ChallengeStatus>(@challenger);
        challenge_status.is_solved = true;
    }

    public entry fun is_solved(_account: &signer) acquires ChallengeStatus {
        let challenge_status = borrow_global_mut<ChallengeStatus>(@challenger);
        assert!(challenge_status.is_solved, 2);
    }

    // solution
    #[test(account = @1338, challenger = @challenger, aptos_framework = @0x1)]
    public entry fun solve_challenge(account: &signer, challenger: &signer) acquires ChallengeStatus {
        initialize(challenger);
        solve(account);
        is_solved(account);
    }
}

