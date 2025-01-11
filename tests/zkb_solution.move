module challenge::exploit {

    use zkb::verify;
    use std::bcs;
    use aptos_std::from_bcs;
    use std::debug;

    #[test(account = @1338, challenger = @challenger, aptos_framework = @0x1)]
    public entry fun solve(account: &signer, challenger: &signer) {
        verify::initialize(challenger);

        for (i in 0..3) {
            verify::set_knowledge(challenger, 10);
            let knowledge = verify::get_knowledge();
            let secret = from_bcs::to_u64(bcs::to_bytes(&knowledge));
            verify::prove(&mut knowledge, secret, account);
            debug::print(&secret);
        };
        verify::is_proved(account);
    }
}
