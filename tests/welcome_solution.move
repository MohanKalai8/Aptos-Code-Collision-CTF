module challenge::solution {
    use challenge::welcome;

    #[test(account = @1338, challenger = @challenger, aptos_framework = @0x1)]
    public entry fun solve(account: &signer, challenger: &signer) {
        welcome::initialize(challenger);
        welcome::solve(account);
        welcome::is_solved(account);
    }
}