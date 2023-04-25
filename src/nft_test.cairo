use array::ArrayTrait;
use option::OptionTrait;
use starknet::contract_address;
use starknet::ContractAddress;
use traits::Into;
use traits::TryInto;
use zeroable::Zeroable;

use cairo_nft::nft::NFT;

const ERC165_INTERFACE: u32 = 0x01ffc9a7_u32;
const ERC721_INTERFACE: u32 = 0x80ac58cd_u32;
const ERC721_METADATA_INTERFACE: u32 = 0x5b5e139f_u32;


//
// ERC165 tests
//

#[test]
fn test_supports_interface() {
    assert(NFT::supports_interface(ERC165_INTERFACE), 'ERC165 interface');
    assert(NFT::supports_interface(ERC721_INTERFACE), 'ERC165 interface');
    assert(NFT::supports_interface(ERC721_METADATA_INTERFACE), 'ERC165 interface');
    assert(NFT::supports_interface(0x1_u32) == false, 'invalid interface');
}

//
// view tests
//

#[test]
#[available_gas(10000000)]
fn test_balance_of_basic() {
    let addr: ContractAddress = 0xc0ffee.try_into().unwrap();
    assert(NFT::balance_of(addr) == 0.into(), 'starter balance not zero');
}

#[test]
#[should_panic(expected: ('invalid address', ))]
fn test_balance_of_raise_when_zero_address() {
    NFT::balance_of(Zeroable::zero());
}

#[test]
#[available_gas(10000000)]
fn test_token_uri() {
    let owner: ContractAddress = 0x33.try_into().unwrap();
    NFT::mint(owner);

    let uri: Array<felt252> = NFT::token_uri(u256 { low: 1_u128, high: 0_u128 });
    assert(uri.len() == 2, 'invalid uri len');
    assert(*uri.at(0) == 'https://www.starknet.io/assets/', 'invalid uri 0');
    assert(*uri.at(1) == 'cairo_logo_banner.png', 'invalid uri 1');
}

#[test]
#[available_gas(10000000)]
fn test_token_mint() {
    let owner: ContractAddress = 0x33.try_into().unwrap();
    NFT::mint(owner);
    assert(NFT::owner_of(1.into()) == owner, 'wrong mint');
}

//
// ERC / auth tests
//

#[test]
#[available_gas(10000000)]
#[should_panic(expected: ('invalid address', ))]
fn test_owner_of_raise_when_no_owner() {
    let orphan_token = u256 { low: 1_u128, high: 0_u128 };
    NFT::owner_of(orphan_token);
}

#[test]
#[available_gas(10000000)]
#[should_panic(expected: ('invalid token ID', ))]
fn test_get_approved_raise_when_invalid_token_id() {
    let orphan_token = u256 { low: 1_u128, high: 0_u128 };
    NFT::get_approved(orphan_token);
}

#[test]
#[available_gas(10000000)]
fn test_is_approved_for_all_basic() {
    let owner: ContractAddress = 0xf00.try_into().unwrap();
    let operator: ContractAddress = 0xbaba.try_into().unwrap();
    assert(NFT::is_approved_for_all(owner, operator) == false, 'failed approved for all');
}
