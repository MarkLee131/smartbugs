// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


uint256 constant EQUIPPED_WEARABLE_SLOTS = 16;
uint256 constant NUMERIC_TRAITS_NUM = 6;
uint256 constant TRAIT_BONUSES_NUM = 5;
uint256 constant PORTAL_AAVEGOTCHIS_NUM = 10;

// Immutable values are prefixed with im_ to easily identify them in code
// these are constant not immutable because this upgradeable contract doesn't have a constructor
// (immutable variables must be declared in the constructor -- i like the im prefix though)
address constant im_diamondAddress = 0x86935F11C86623deC8a25696E1C19a8659CbF95d;
address constant im_ghstAddress = 0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7;
//address internal constant im_vGHSTAddress;
address constant im_realmAddress = 0x1D0360BaC7299C86Ec8E99d0c1C9A95FEfaF2a11;
address constant im_raffleAddress = 0x6c723cac1E35FE29a175b287AE242d424c52c1CE;
address constant im_stakingAddress = 0xA02d547512Bb90002807499F05495Fe9C4C3943f;

bytes4 constant ERC1155_ACCEPTED = 0xf23a6e61; // Return value from `onERC1155Received` call if a contract accepts receipt (i.e `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`).
uint256 constant MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;


//  switch (traitType) {
//         case 0:
//             return energy(value);
//         case 1:
//             return aggressiveness(value);
//         case 2:
//             return spookiness(value);
//         case 3:
//             return brain(value);
//         case 4:
//             return eyeShape(value);
//         case 5:
//             return eyeColor(value);

struct Aavegotchi {
    uint16[EQUIPPED_WEARABLE_SLOTS] equippedWearables; //The currently equipped wearables of the Aavegotchi
    // [Experience, Rarity Score, Kinship, Eye Color, Eye Shape, Brain Size, Spookiness, Aggressiveness, Energy]
    int8[NUMERIC_TRAITS_NUM] temporaryTraitBoosts;
    int16[NUMERIC_TRAITS_NUM] numericTraits; // Sixteen 16 bit ints.  [Eye Color, Eye Shape, Brain Size, Spookiness, Aggressiveness, Energy]
    string name;
    uint256 randomNumber;
    uint256 experience; //How much XP this Aavegotchi has accrued. Begins at 0.
    uint256 minimumStake; //The minimum amount of collateral that must be staked. Set upon creation.
    uint256 usedSkillPoints; //The number of skill points this aavegotchi has already used
    uint256 interactionCount; //How many times the owner of this Aavegotchi has interacted with it.
    address collateralType;
    uint40 claimTime; //The block timestamp when this Aavegotchi was claimed
    uint40 lastTemporaryBoost;
    uint16 hauntId;
    address owner;
    uint8 status; // 0 == portal, 1 == VRF_PENDING, 2 == open portal, 3 == Aavegotchi
    uint40 lastInteracted; //The last time this Aavegotchi was interacted with
    bool locked;
    address escrow; //The escrow address this Aavegotchi manages.
}

struct Dimensions {
    uint8 x;
    uint8 y;
    uint8 width;
    uint8 height;
}

struct ItemType {
    string name; //The name of the item
    string description;
    string author;
    // treated as int8s array
    // [Experience, Rarity Score, Kinship, Eye Color, Eye Shape, Brain Size, Spookiness, Aggressiveness, Energy]
    int8[NUMERIC_TRAITS_NUM] traitModifiers; //[WEARABLE ONLY] How much the wearable modifies each trait. Should not be more than +-5 total
    //[WEARABLE ONLY] The slots that this wearable can be added to.
    bool[EQUIPPED_WEARABLE_SLOTS] slotPositions;
    // this is an array of uint indexes into the collateralTypes array
    uint8[] allowedCollaterals; //[WEARABLE ONLY] The collaterals this wearable can be equipped to. An empty array is "any"
    // SVG x,y,width,height
    Dimensions dimensions;
    uint256 ghstPrice; //How much GHST this item costs
    uint256 maxQuantity; //Total number that can be minted of this item.
    uint256 totalQuantity; //The total quantity of this item minted so far
    uint32 svgId; //The svgId of the item
    uint8 rarityScoreModifier; //Number from 1-50.
    // Each bit is a slot position. 1 is true, 0 is false
    bool canPurchaseWithGhst;
    uint16 minLevel; //The minimum Aavegotchi level required to use this item. Default is 1.
    bool canBeTransferred;
    uint8 category; // 0 is wearable, 1 is badge, 2 is consumable
    int16 kinshipBonus; //[CONSUMABLE ONLY] How much this consumable boosts (or reduces) kinship score
    uint32 experienceBonus; //[CONSUMABLE ONLY]
}

struct ItemIdIO {
        uint256 itemId;
        uint256 balance;
    }

struct WearableSet {
    string name;
    uint8[] allowedCollaterals;
    uint16[] wearableIds; // The tokenIdS of each piece of the set
    int8[TRAIT_BONUSES_NUM] traitsBonuses;
}

struct Haunt {
    uint256 hauntMaxSize; //The max size of the Haunt
    uint256 portalPrice;
    bytes3 bodyColor;
    uint24 totalCount;
}

struct SvgLayer {
    address svgLayersContract;
    uint16 offset;
    uint16 size;
}

struct AavegotchiCollateralTypeInfo {
    // treated as an arary of int8
    int16[NUMERIC_TRAITS_NUM] modifiers; //Trait modifiers for each collateral. Can be 2, 1, -1, or -2
    bytes3 primaryColor;
    bytes3 secondaryColor;
    bytes3 cheekColor;
    uint8 svgId;
    uint8 eyeShapeSvgId;
    uint16 conversionRate; //Current conversionRate for the price of this collateral in relation to 1 USD. Can be updated by the DAO
    bool delisted;
}

struct ERC1155Listing {
    uint256 listingId;
    address seller;
    address erc1155TokenAddress;
    uint256 erc1155TypeId;
    uint256 category; // 0 is wearable, 1 is badge, 2 is consumable, 3 is tickets
    uint256 quantity;
    uint256 priceInWei;
    uint256 timeCreated;
    uint256 timeLastPurchased;
    uint256 sourceListingId;
    bool sold;
    bool cancelled;
}

struct ERC721Listing {
    uint256 listingId;
    address seller;
    address erc721TokenAddress;
    uint256 erc721TokenId;
    uint256 category; // 0 is closed portal, 1 is vrf pending, 2 is open portal, 3 is Aavegotchi
    uint256 priceInWei;
    uint256 timeCreated;
    uint256 timePurchased;
    bool cancelled;
}

struct ListingListItem {
    uint256 parentListingId;
    uint256 listingId;
    uint256 childListingId;
}

struct GameManager {
    uint256 limit;
    uint256 balance;
    uint256 refreshTime;
}

struct GotchiLending {
    // storage slot 1
    address lender;
    uint96 initialCost; // GHST in wei, can be zero
    // storage slot 2
    address borrower;
    uint32 listingId;
    uint32 erc721TokenId;
    uint32 whitelistId; // can be zero
    // storage slot 3
    address originalOwner; // if original owner is lender, same as lender
    uint40 timeCreated;
    uint40 timeAgreed;
    bool canceled;
    bool completed;
    // storage slot 4
    address thirdParty; // can be address(0)
    uint8[3] revenueSplit; // lender/original owner, borrower, thirdParty
    uint40 lastClaimed; //timestamp
    uint32 period; //in seconds
    // storage slot 5
    address[] includeList;
}

// All state variables are accessed through this struct
// To avoid name clashes and make clear a variable is a state variable
// state variable access starts with "s." which accesses variables in this struct
struct AppStorage {
    // IERC165
    mapping(bytes4 => bool) supportedInterfaces;
    address contractOwner;
    address contractCreator;
    address vGHSTAddress;

    //every ERC721 token is mapped to a depositor address
    //the default (i.e., the token hasn't been deposited) maps to the 0 address
    mapping(address => mapping(uint256 => address)) deposits;
    //every depositor is mapped to an array of their tokens
    mapping(address=>mapping(address=>uint256[])) tokenIdsByOwner;
    //each token index is mapped to ensure constant tokenId look-ups and avoid iteration
    //this is a lot (triple mapping) but it ends up being ownerTokenIndexByTokenId[_tokenAddress][_user][tokenId]
    mapping(address=>mapping(address => mapping(uint256 => uint256))) ownerTokenIndexByTokenId;

    mapping(uint256 => Gotchi) gotchiMapping;

    //the fee we're going to charge on all GHST deposits/withdrawals
    uint256 feeBP;
    //the fee we're going to charge on all erc721 deposits/withdrawals
    uint256 fee721;

    uint256 totalFeesCollected;

    mapping(address => bool) approvedUsers;

    //legacy variable
    uint8 alchemicaFee;

    //the Vault's default settings for rentals
    RentalSettings defaultSettings;

    //a mapping keeping track of all the guilds
    mapping(uint256 => Guild) guilds;

    uint256 customSettingsFee;

}

struct Gotchi {

    address DepositorAddress;
    uint256 tokenId;

    uint256 timeCheckedOut;

    bool locked;    //whether this gotchi is locked for a guild
    uint256 lastLocked; //the block it was last locked
    uint256 lockPeriod;

    uint256 assignedGuild;
    bool pauseLending;  //whether the user wants to pause the lending of his gotchi
    RentalSettings preferredSettings;   //the user's preferred rental settings

}

//this allows us to store info on guilds
struct Guild {
    string name;
    address approved;   //an address authorized to modify the guild's information
    RentalSettings rentalSettings;  //the guild's preferred rental settings
}

struct RentalSettings{
    bool initialized; //putting this here so that we can use default settings if individual gotchi settings aren't initialized
    uint96 initialCost;
    uint32 period;
    uint8[3] revenueSplit;
    address thirdParty;
    uint32 whitelistId;
    address[] revenueTokens;
}

contract Modifiers {
    AppStorage internal s;

    modifier onlyApproved{
        require(msg.sender ==  s.contractOwner || s.approvedUsers[msg.sender], "onlyApproved");
        _;
    }

    modifier onlyOwner{
        require(msg.sender == s.contractOwner);
        _;
    }


}