# cairo_nft

A basic ERC721 contract in Cairo 1. Intended primarily for education or as a starting point for futher development or customizations.

Features:
  
* no external dependencies - full ERC721 compatibility in a single file
* non-upgradable
* deployer is admin, only admin can mint
* uses `Array<felt252>` as return value of `token_uri`
* uses `Array<u8>` for `bytes` in `on_erc721_received`
  