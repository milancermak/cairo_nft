#[contract]
mod NFT {
    use array::ArrayTrait;
    use option::OptionTrait;
    use traits::Into;
    use traits::TryInto;
    use starknet::contract_address;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;

    type addr = ContractAddress;

    // ERC 165 interface codes
    const INTERFACE_ERC165: u32 = 0x01ffc9a7_u32;
    const INTERFACE_ERC721: u32 = 0x80ac58cd_u32;
    const INTERFACE_ERC721_METADATA: u32 = 0x5b5e139f_u32;
    const INTERFACE_ERC721_RECEIVER: u32 = 0x150b7a02_u32;

    #[abi]
    trait IERC721TokenReceiver {
        fn on_erc721_received(operator: addr, from: addr, token_id: u256, data: Array<u8>) -> u32;
    }

    #[abi]
    trait IERC165 {
        fn supports_interface(interface_id: u32) -> bool;
    }

    #[event]
    fn Transfer(from: addr, to: addr, token_id: u256) {}

    #[event]
    fn Approval(owner: addr, approved: addr, token_id: u256) {}

    #[event]
    fn ApprovalForAll(owner: addr, operator: addr, approved: bool) {}

    struct Storage {
        admin: addr,
        token_id_count: u256,
        balances: LegacyMap<addr, u256>,
        owners: LegacyMap<u256, addr>,
        token_approvals: LegacyMap<u256, addr>,
        operator_approvals: LegacyMap<(addr, addr), bool>,
    }

    #[constructor]
    fn constructor() {
        admin::write(get_caller_address())
    }

    //
    // External
    //

    fn mint(to: addr) {
        assert_admin();
        assert(to.is_non_zero(), 'minting to zero');

        let one = u256 { low: 1, high: 0 };
        let token_id = token_id_count::read() + one;

        token_id_count::write(token_id);
        balances::write(to, balances::read(to) + one);
        owners::write(token_id, to);

        Transfer(Zeroable::zero(), to, token_id);
    }

    //
    // ERC721Metadata
    //

    #[view]
    fn name() -> felt252 {
        'Starknet'
    }

    #[view]
    fn symbol() -> felt252 {
        'Starknet'
    }

    #[view]
    fn token_uri(token_id: u256) -> Array<felt252> {
        assert_valid_token(token_id);
        let mut uri = ArrayTrait::new();
        uri.append('https://www.starknet.io/assets/');
        uri.append('cairo_logo_banner.png');
        uri
    }   

    //
    // ERC721
    //

    #[view]
    fn balance_of(owner: addr) -> u256 {
        assert_valid_address(owner);
        balances::read(owner)
    }

    #[view]
    fn owner_of(token_id: u256) -> addr {
        let owner = owners::read(token_id);
        assert_valid_address(owner);
        owner
    }

    #[view]
    fn get_approved(token_id: u256) -> addr {
        assert_valid_token(token_id);
        token_approvals::read(token_id)
    }

    #[view]
    fn is_approved_for_all(owner: addr, operator: addr) -> bool {
        operator_approvals::read((owner, operator))
    }

    #[external]
    fn safe_transfer_from(from: addr, to: addr, token_id: u256, data: Array<u8>) {
        let can_receive_token = IERC165Dispatcher { contract_address: to }.supports_interface(INTERFACE_ERC721_RECEIVER);
        assert(can_receive_token, 'not supported by receiver');

        transfer(from, to, token_id);

        let confirmation = IERC721TokenReceiverDispatcher { contract_address: to }.on_erc721_received(from, to, token_id, data);
        assert(confirmation == INTERFACE_ERC721_RECEIVER, 'incompatible receiver');
    }

    #[external]
    fn transfer_from(from: addr, to: addr, token_id: u256) {
        transfer(from, to, token_id);
    }

    #[external]
    fn approve(approved: addr, token_id: u256) {
        let owner = owners::read(token_id);
        assert(owner != approved, 'approval to owner');

        let caller = get_caller_address();
        assert(
            caller == owner | operator_approvals::read((owner, caller)), 
            'not approved'
        );

        token_approvals::write(token_id, approved);
        Approval(owner, approved, token_id);
    }

    #[external]
    fn set_approval_for_all(operator: addr, approval: bool) {
        let owner = get_caller_address();
        assert(owner != operator, 'approval to self');
        operator_approvals::write((owner, operator), approval);
        ApprovalForAll(owner, operator, approval);
    }

    //
    // ERC165
    //

    #[view]
    fn supports_interface(interface_id: u32) -> bool {
        interface_id == INTERFACE_ERC165 |
        interface_id == INTERFACE_ERC721 |
        interface_id == INTERFACE_ERC721_METADATA
    }

    //
    // Internal
    //

    fn assert_admin() {
        assert(get_caller_address() == admin::read(), 'caller not admin')
    }

    fn assert_approved_or_owner(operator: addr, token_id: u256) {
        let owner = owners::read(token_id);
        let approved = get_approved(token_id);
        assert(
            operator == owner | operator == approved | is_approved_for_all(owner, operator),
            'operation not allowed'
        );
    }

    fn assert_valid_address(address: addr) {
        assert(address.is_non_zero(), 'invalid address');
    }

    fn assert_valid_token(token_id: u256) {
        assert(owners::read(token_id).is_non_zero(), 'invalid token ID')
    }

    fn transfer(from: addr, to: addr, token_id: u256) {
        assert_approved_or_owner(get_caller_address(), token_id);
        assert(owners::read(token_id) == from, 'source not owner');
        assert(to.is_non_zero(), 'transferring to zero');
        assert_valid_token(token_id);

        // reset approvals
        token_approvals::write(token_id, Zeroable::zero());

        // update balances
        let one = u256 { low: 1, high: 0 };
        let owner_balance = balances::read(from);
        balances::write(from, owner_balance - one);
        let receiver_balance = balances::read(to);
        balances::write(to, receiver_balance + one);

        // update ownership
        owners::write(token_id, to);
        Transfer(from, to, token_id);
    }
}
