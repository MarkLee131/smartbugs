//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ItemType, ItemIdIO, ERC721Listing, ERC1155Listing, GotchiLending } from  "../libraries/LibAppStorage.sol";


interface IAavegotchi{

        function getItemType(uint256 _itemId) external view returns (ItemType memory itemType_);

        function itemBalances(address _account) external view returns (ItemIdIO[] memory bals_);

        function executeERC721Listing(uint256 _listingId) external;

        function getERC721ListingFromToken(
                address _erc721TokenAddress,
                uint256 _erc721TokenId,
                address _owner
        ) external view returns (ERC721Listing memory listing_);

        function getERC1155ListingFromToken(
                address _erc1155TokenAddress,
                uint256 _erc1155TypeId,
                address _owner
        ) external view returns (ERC1155Listing memory listing_);

        function executeERC1155Listing(
                uint256 _listingId,
                uint256 _quantity,
                uint256 _priceInWei
        ) external;

        function escrowBalance(uint256 _tokenId, address _erc20Contract) external view returns (uint256);

        function transferEscrow(
        uint256 _tokenId,
        address _erc20Contract,
        address _recipient,
        uint256 _transferAmount
        ) external;

        function gotchiEscrow(uint256 _tokenId) external view returns (address);

        function interact(uint256[] calldata _tokenIds) external;

        function spendSkillPoints(uint256 _tokenId, int16[4] calldata _values) external;

        function setERC1155Listing(
        address _erc1155TokenAddress,
        uint256 _erc1155TypeId,
        uint256 _quantity,
        uint256 _priceInWei
        ) external;

        function cancelERC1155Listing(uint256 _listingId) external;

        function addERC721Listing(
        address _erc721TokenAddress,
        uint256 _erc721TokenId,
        uint256 _priceInWei
        ) external;

        function cancelERC721ListingByToken(address _erc721TokenAddress, uint256 _erc721TokenId) external;

        function cancelERC721Listing(uint256 _listingId) external;

        function updateERC721Listing(
        address _erc721TokenAddress,
        uint256 _erc721TokenId,
        address _owner
        ) external;

        function setApprovalForAll(address _operator, bool _approved) external;

        function setPetOperatorForAll(address _operator, bool _approved) external;

        function ownerOf(uint256 _tokenId) external view returns (address owner_);

        function tokenIdsOfOwner(address _owner) external view returns (uint32[] memory tokenIds_);

        function addGotchiLending(
        uint32 _erc721TokenId,
        uint96 _initialCost,
        uint32 _period,
        uint8[3] calldata _revenueSplit,
        address _originalOwner,
        address _thirdParty,
        uint32 _whitelistId,
        address[] calldata _revenueTokens
        ) external;

        function cancelGotchiLendingByToken(uint32 _erc721TokenId) external;

        function cancelGotchiLending(uint32 _listingId) external;

        function claimGotchiLending(uint32 _tokenId) external;

        function isAavegotchiLent(uint32 _erc721TokenId) external view returns (bool);

        function claimAndEndGotchiLending(uint32 _tokenId) external;

        function getGotchiLendingIdByToken(uint32 _erc721TokenId) external view returns (uint32);

        function getGotchiLendingFromToken(uint32 _erc721TokenId) external view returns (GotchiLending memory listing_);

        function getOwnerGotchiLendings(
                address _lender,
                bytes32 _status,
                uint256 _length
        ) external view returns (GotchiLending[] memory listings_);

        function createWhitelist(string calldata _name, address[] calldata _whitelistAddresses) external;

        function updateWhitelist(uint32 _whitelistId, address[] calldata _whitelistAddresses) external;

        function removeAddressesFromWhitelist(uint32 _whitelistId, address[] calldata _whitelistAddresses) external;

        function isWhitelisted(uint32 _whitelistId, address _whitelistAddress) external view returns (uint256);

        function getWhitelistsLength() external view returns (uint256);

        function setBorrowLimit(uint32 _whitelistId, uint256 _borrowlimit) external;
}