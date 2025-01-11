module 0x1337::solution1 {
    use 0x1337::source;
    use std::debug;

    #[test]
    public entry fun solve() {
        debug::print(&source::get_flag());
    }
}