// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IERC1155.sol";
import "./interfaces/StakingContract.sol";
import "./interfaces/Raffle.sol";
import "./interfaces/IAavegotchi.sol";
import "./interfaces/wapGHST.sol";
import "./interfaces/IUniswap.sol";
import "./interfaces/GLTR.sol";
import "hardhat/console.sol";



//the multi-sig owners define these parameters, but allow a single wallet to execute minting, 
//to minimize the number of multi-sig txs required
struct MintingSettings{
    //Unix time -- how frequently frens can be minted
    uint256 allowedFrequency;
    //the Unix time of the last minting of tickets
    uint256 lastExecuted;
    //the number of frens the vault had the last time tickets were minted -- used to see
    //how many new frens have accrued
    uint256 lastFrens; 
    //an array storing how many frens it costs for each ticket
    uint256[] frensCost;
    //what percentage of new frens should go towards each type of raffle ticket.  This is a number from 0-100
    uint256[] mintPercentages;
    //the approved prices that tickets may be sold for -- each array entry corresponds to a type of ticket
    uint256[] salesPrices;
}


// this contract draws from QiDao's camToken
// https://github.com/0xlaozi/qidao/blob/main/contracts/camToken.sol
// stake GHST to earn more vGHST (from farming and using frens rewards)
contract vGHST is Initializable, ERC20Upgradeable, PausableUpgradeable {
    using SafeMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    
    address public constant ghstAddress=0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7;
    address public constant stakingAddress=0xA02d547512Bb90002807499F05495Fe9C4C3943f;
    address public constant raffleAddress=0x6c723cac1E35FE29a175b287AE242d424c52c1CE;
    address public constant diamondAddress=0x86935F11C86623deC8a25696E1C19a8659CbF95d;
    address public constant realmAddress=0x1D0360BaC7299C86Ec8E99d0c1C9A95FEfaF2a11;
    address public gotchiVaultAddress;

    uint256 constant MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    address public owner;
    address public contractCreator;

    uint16 public withdrawalFeeBP;

    uint256 public totalFeesCollected;

    MintingSettings mintingSettings;

    mapping(address => bool) approvedUsers;

    //THESE ARE LEGACY VARIABLES AND ARE NOT USED IN THE CONTRACT
    uint256 allowedFrequency;
    //the Unix time of the last minting of tickets
    uint256 lastExecuted;
    //the number of frens the vault had the last time tickets were minted -- used to see
    //how many new frens have accrued
    uint256 lastFrens; 
    //what percentage of new frens should go towards each type of raffle ticket
    uint256[] mintPercentages;
    //the approved prices that tickets may be sold for -- each array entry corresponds to a type of ticket
    uint256[] salesPrices;
    //THIS ENDS THE LEGACY VARIABLES 

    address public signer;

    //vars to be used once amGHST goes live
    address public wapGHST;

    //GLTR farming addresses
    address public farmAddress ;
    address public gltrAddress ;
    address[] public alchemicaAddresses;
    address public quickswapAddress ;

    //events to emit
    event vGHSTEntered(address indexed _user, uint256 _GHSTAmount, uint256 _vGHSTAmount);
    event vGHSTLeft(address indexed _user, uint256 _vGHSTAmount, uint256 _GHSTAmount);

    // Define the token contract
//    function initialize(
//        address _owner,
//        string memory name,
//        string memory symbol
//        ) public initializer{
//
//        __ERC20_init(name, symbol);
//
//        withdrawalFeeBP = 0;
//        owner = _owner;
//        contractCreator = msg.sender;
//
//    }

    modifier onlyOwner() {
        require(msg.sender ==  owner, "onlyOwner: not allowed");
        _;
    }

    modifier onlyApproved() {
        require(msg.sender ==  owner || approvedUsers[msg.sender], "onlyApproved: not allowed");
        _;
    }

    function setApproved(address _user, bool _approval) public onlyOwner{
        approvedUsers[_user] = _approval;
    }

    function isApproved(address _user) public view returns(bool){
        return approvedUsers[_user];
    }

    function pause(bool _setPause) public onlyOwner{
        if(_setPause){_pause();}
        else _unpause();
    }

    function updateOwner(address _owner) public onlyOwner {
        owner = _owner;
    }

    function updateCreator(address _creator) public {
        require(msg.sender == contractCreator,"Can only be called by creator");
        contractCreator = _creator;
    }

    function updateGotchiVault(address _vault) public onlyOwner {
        gotchiVaultAddress = _vault;
    }

  
    //this function is to future-proof the possibility that Aavegotchi creates
    //new ERC721 or ERC1155 items with a new address.  Will want to be able to list these at the baazaar
    //both ERC721 and ERC1155 use the same "setApprovalForAll" function, so can use the IERC1155 interface for either
    function setNewDiamondApprovalERC1155(address _tokenAddress) public onlyOwner{
        IERC1155(_tokenAddress).setApprovalForAll(diamondAddress, true);
    }

//    function setApprovals() public onlyOwner{
//
//        //diamond address needs to take GHST for baazaar fees
//        IERC20Upgradeable(ghstAddress).approve(diamondAddress, MAX_INT);
//
//        //staking address needs to take GHST for staking GHST
//        IERC20Upgradeable(ghstAddress).approve(stakingAddress, MAX_INT);
//
//        //raffle address needs to take raffle tickets
//        IERC1155(stakingAddress).setApprovalForAll(raffleAddress, true);
//
//        //diamond address needs to take raffle tickets
//        IERC1155(stakingAddress).setApprovalForAll(diamondAddress, true);
//
//        //diamond needs to take gotchis and wearables for baazaar sales
//        IERC1155(diamondAddress).setApprovalForAll(diamondAddress, true);
//
//        //diamond needs to take realm for baazaar sales
//        IERC721(realmAddress).setApprovalForAll(diamondAddress, true);
//    }

    function updateWithdrawalFee(uint16 _withdrawalFee) public onlyOwner{
        withdrawalFeeBP=_withdrawalFee;
    }

    function getFee() public view returns(uint256){
        return withdrawalFeeBP;
    }

    function getTotalFees() public view returns(uint256){
        return totalFeesCollected;
    }

    function setMintingSettings(uint256 _frequency, uint256[] calldata _percentages, 
        uint256[] calldata _prices, uint256[] calldata _costs) public onlyOwner{

        mintingSettings.allowedFrequency = _frequency;       
        mintingSettings.mintPercentages = _percentages;
        mintingSettings.salesPrices = _prices;
        mintingSettings.frensCost = _costs;

    }

    function getMintingSettings() public view returns(MintingSettings memory){
        return mintingSettings;
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //In this section, we pull from Qidao's camToken implementation to allow users to own
    //a fraction of the deposited pot, which can be compounded.  Have added view functions to 
    //see how much total GHST is held by the contract, and to convert vGHST to corresponding GHST

    // Locks ghst and mints our vGHST (shares) -- this function is largely from QiDao code

    //note: will need to upgrade this code once Aave rewards go live, to go into amGHST
    function enter(uint256 _amount) public whenNotPaused returns(uint256)  {
        
        //the total "pool" of GHST held is a combination of the GHST directly held, and the GHST staked
        uint256 totalTokenLocked = totalGHST(address(this));

        uint256 totalShares = totalSupply(); // Gets the amount of vGHST in existence

        // Lock the GHST in the contract
        IERC20Upgradeable(ghstAddress).transferFrom(msg.sender, address(this), _amount);

        // Deposit the GHST for wapGHST at Aavegotchi.com
        uint256 wapGHSTreceived = IwapGHST(wapGHST).enterWithUnderlying(_amount);

        // Deposit the wapGHST for GLTR
        farm(farmAddress).deposit(0,wapGHSTreceived);

        if (totalShares == 0 || totalTokenLocked == 0) { // If no vGHST exists, mint it 1:1 to the amount put in
                _mint(msg.sender, _amount);
                return _amount;
                emit vGHSTEntered(msg.sender,_amount,_amount);

        } else {
            uint256 vGHSTAmount = _amount.mul(totalShares).div(totalTokenLocked);
            _mint(msg.sender, vGHSTAmount);
            return vGHSTAmount;
            emit vGHSTEntered(msg.sender,_amount,vGHSTAmount);
        }
    }

    //this function allows the owner to manually unstake staked wapGHST tokens from the GLTR farming pool
    function farmWithdraw(uint256 _amount) public onlyOwner{
        // unstake the wapGHST
        farm(farmAddress).withdraw(0,_amount);

        //now withdraw corresponding GHST from Aavegotchi.com
        IwapGHST(wapGHST).leaveToUnderlying(_amount);
    }

    // claim ghst by burning vGHST -- this function is largely from QiDao code
    // we charge a 0.5% fee on withdrawal
    function leave(uint256 _share) public whenNotPaused {
        if(_share>0){

            uint256 ghstAmount = convertVGHST(_share);

            //if balanceof(this) < ghst Amount (because GHST is staked for frens), unstake ghstAmount
            if(ghstAmount > IERC20Upgradeable(ghstAddress).balanceOf(address(this))){

                //find how much wapGHST we need to withdraw
                uint256 wapGHSTamount = IwapGHST(wapGHST).convertToShares(ghstAmount);
                // unstake the wapGHST
                farm(farmAddress).withdraw(0,wapGHSTamount);

                //now withdraw corresponding GHST from Aavegotchi.com
                IwapGHST(wapGHST).leaveToUnderlying(wapGHSTamount);
            }
            _burn(msg.sender, _share);
            
            // Now we withdraw the GHST from the vGHST Pool (this contract) and send to user as GHST.
            //IERC20(usdc).safeApprove(address(this), amTokenAmount);
            //we take a designated fee from the withdrawal
            //solidity doesn't allow floating point math, so we have to multiply up to take percentages
            //here, e.g., a fee of 50 basis points would be a 0.5% fee
            //half the fee goes to the protocol, 25% goes to the contract owner, 25% goes to the contract creator 
            //we send 25% each to the owner and creator, and the remaining 50% just stays in the contract
            uint256 feeAmount = ghstAmount.mul(withdrawalFeeBP).div(10000);

            totalFeesCollected += feeAmount;

            IERC20Upgradeable(ghstAddress).transfer(owner, feeAmount.mul(100).div(400));
            IERC20Upgradeable(ghstAddress).transfer(contractCreator, feeAmount.mul(100).div(400));

            //if the sender is trying to cash out all the remaining vGHST, then half the fee goes to him
            if(totalSupply() == 0){IERC20Upgradeable(ghstAddress).transfer(msg.sender, feeAmount.mul(200).div(400));}
            
            //we send the escrow - fee to the owner
            IERC20Upgradeable(ghstAddress).transfer(msg.sender, ghstAmount.sub(feeAmount));

            emit vGHSTLeft(msg.sender, _share, ghstAmount);
        }
    }

    //a function to get the total GHST held by an address between the wallet AND staked
    function totalGHST(address _user) public view returns(uint256 _totalGHST){
        //get the total amount of GHST held directly in the wallet
        uint256 totalGHSTHeld = IERC20Upgradeable(ghstAddress).balanceOf(_user);
        //find the total amount of GHST and wapGHST this contract has staked
        uint256 totalGHSTStaked;
        uint256 totalwapGHSTStaked;

        PoolStakedOutput[] memory poolsStaked = StakingContract(stakingAddress).stakedInCurrentEpoch(_user);
        for(uint256 i = 0; i < poolsStaked.length; i++){
            if(poolsStaked[i].poolAddress == ghstAddress){
                totalGHSTStaked += poolsStaked[i].amount;
            }
            else if(poolsStaked[i].poolAddress == wapGHST){
                totalwapGHSTStaked += poolsStaked[i].amount;
            }
        }

        //how much wapGHST is staked in the GLTR contract
        totalwapGHSTStaked += farm(farmAddress).deposited(0,address(this));

        //we convert the amount of wapGHST we have staked into GHST
        uint256 wapGHSTtoGHST = IwapGHST(wapGHST).convertToAssets(totalwapGHSTStaked);

        _totalGHST = totalGHSTHeld + totalGHSTStaked + wapGHSTtoGHST;
    }

    function convertVGHST(uint256 _share) public view returns(uint256 _ghst){
        if(_share > 0){
            uint256 totalShares = totalSupply(); // Gets the amount of vGHST in existence

            //get the total amount of GHST held by the contract
            uint256 totalTokenLocked = totalGHST(address(this));

            //calculate how much of our total pool this share owns
            _ghst = _share.mul(totalTokenLocked).div(totalShares);
        }
        else return 0;
            
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //In this section, we have wrapper functions that can be called by the owner, to stake and 
    //unstake GHST, claim raffle tickets, enter raffle tickets into raffles, sell ERC1155 items on baazaar
    //this is the core of the "compounding" part of this contract, and can only be called by the owner

    //This first function is the key for automating minting and ticket sales.  An approved wallet
    //(a bot) can call the function at approved intervals.  Only the owner of the contract can adjust the 
    //parameters
    function mintAndSell() public onlyApproved{
        //must wait the required interval since the last minting
        require(block.timestamp - mintingSettings.lastExecuted >= mintingSettings.allowedFrequency,"Need to wait to mint more");
        
        //we check how many new frens we've accrued since last minting -- we want the differential since the last claiming
        uint256 newFrens = frens() - mintingSettings.lastFrens;

        //we might need to pull some GHST out of the staking pool to pay the baazaar fees
        if(IERC20Upgradeable(ghstAddress).balanceOf(address(this)) < 1e18){
            StakingContract(stakingAddress).withdrawFromPool(ghstAddress, 5e18);
        }

        //note: this will end up with leftover frens since the numbers won't always line up.  we can just leave them
        //sitting (what i've done here) or go back in at the end and mint the remainder in the smallest denominator
        //there are 7 ticket types: common, uncommon, rare, legendary, mythical, godlike, drop
        for(uint i = 0; i < 7; i++){
            
            //we may not want to mint all the ticket types -- check if the percentage >0
            if(mintingSettings.mintPercentages[i] > 0){

                //first, we find the number of frens to spend on each raffle item
                uint256 frensToSpend = (mintingSettings.mintPercentages[i] * newFrens) / 100;

                //next, we figure out how many raffle tickets that number of frens corresponds to.
                //solidity division rounds down, so we get the max number of tickets of each type for that amount of frens
                uint256 ticketsToBuy = frensToSpend / mintingSettings.frensCost[i];

                //now we claim that number of tickets
                uint256[] memory ticketIds = new uint256[](1); 
                uint256[] memory ticketQuants = new uint256[](1);
                ticketIds[0] = i;
                ticketQuants[0] = ticketsToBuy;

                if(ticketsToBuy > 0){
                    StakingContract(stakingAddress).claimTickets(ticketIds, ticketQuants);

                    //if we already have a listing with this type of ticket, Aavegotchi won't let us list a new one
                    //so we have to cancel and then combine the tickets

                    //get the preexisting listing, and number of tickets -- numTickets defaults to 0 if there's no listing
                    ERC1155Listing memory currentListing = IAavegotchi(diamondAddress).getERC1155ListingFromToken(stakingAddress, i, address(this));
                    uint256 numTickets = currentListing.quantity;

                    //now we cancel the prior listing
                    IAavegotchi(diamondAddress).cancelERC1155Listing(currentListing.listingId);
                    
                    //and finally, we list the tickets on the baazaar
                    IAavegotchi(diamondAddress).setERC1155Listing(stakingAddress, i, ticketsToBuy + numTickets, mintingSettings.salesPrices[i]);
                }
                
            }
        }

        //and we record the ending information to refer to in the future
        mintingSettings.lastExecuted = block.timestamp;
        mintingSettings.lastFrens = frens();
    }

    
    /////////////////////////////////////////////////////////////////////////////////////
    //Wrapper functions for the staking diamond contract
    function frens() public view returns (uint256 frens_) {
        frens_ = StakingContract(stakingAddress).frens(address(this));
    }

    function stakeIntoPool(address _poolContractAddress, uint256 _amount) public onlyOwner{
        StakingContract(stakingAddress).stakeIntoPool(_poolContractAddress, _amount);
    }

    function stakeAllGHST() public onlyApproved{
        // Deposit the GHST for wapGHST at Aavegotchi.com
        uint256 wapGHSTreceived = IwapGHST(wapGHST).enterWithUnderlying(IERC20Upgradeable(ghstAddress).balanceOf(address(this)));

        // Deposit the wapGHST for GLTR
        farm(farmAddress).deposit(0,wapGHSTreceived);
    }

    function withdrawFromPool(address _poolContractAddress, uint256 _amount) public onlyOwner{
        StakingContract(stakingAddress).withdrawFromPool(_poolContractAddress, _amount);
    }

    function claimTickets(uint256[] calldata _ids, uint256[] calldata _values) public onlyOwner{
        StakingContract(stakingAddress).claimTickets(_ids, _values);
        mintingSettings.lastFrens = frens();
    }

    function convertTickets(uint256[] calldata _ids, uint256[] calldata _values) public onlyOwner{
        StakingContract(stakingAddress).convertTickets(_ids, _values);
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //Wrapper functions for the raffle contract
//    function enterTickets(uint256 _raffleId, TicketItemIO[] calldata _ticketItems) public onlyOwner{
//        RaffleContract(raffleAddress).enterTickets(_raffleId, _ticketItems);
//    }
//
//    function claimPrize(
//        uint256 _raffleId,
//        address _entrant,
//        ticketWinIO[] calldata _wins
//    ) public onlyOwner{
//        RaffleContract(raffleAddress).claimPrize(_raffleId, _entrant, _wins);
//    }

    //we need this function because the Aavegotchi contracts change their function calls for converting raffle
    //winning vouchers into ERC721 tokens (ERC1155 tokens are sent directly to the winner using claimPrize), so we need 
    //an upgradable contract or EOA to be the one actually claiming the ERC721 token from the ERC1155 vouchers
    function withdrawERC1155(address _erc1155Address, uint256[] calldata _ids, uint256[] calldata _values) public whenNotPaused {
        require(msg.sender == owner || msg.sender == gotchiVaultAddress, "withdrawVouchers: can only be called by contract owner or the gotchiVault");
        require(_ids.length == _values.length, "ids and values must be same length");

        IERC1155(_erc1155Address).safeBatchTransferFrom(address(this), msg.sender, _ids, _values, "");

    }

    //function to withdraw alchemica or other ERC20 tokens from the contract
    function withdrawERC20(address[] calldata _token, uint256[] calldata _amount) public onlyOwner{
        require(_token.length == _amount.length,"withdrawERC20: tokens and amounts must be same length");
        for(uint256 i = 0; i < _token.length;){
            IERC20Upgradeable(_token[i]).transfer(owner,_amount[i]);
            unchecked{
                i++;
             }
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //Wrapper functions for the baazaar
    //We allow the owner to list items (e.g., raffle tickets and raffle winnings)
    function setERC1155Listing(address _erc1155TokenAddress, uint256 _erc1155TypeId, uint256 _quantity, uint256 _priceInWei) public onlyOwner{
        //we need at least 0.1 GHST (1e17) in the wallet to pay the listing fee
        //if we don't have that much, pull 5 GHST from staking pool
        if(IERC20Upgradeable(ghstAddress).balanceOf(address(this)) < 1e18){
            StakingContract(stakingAddress).withdrawFromPool(ghstAddress, 5e18);
        }
        IAavegotchi(diamondAddress).setERC1155Listing(_erc1155TokenAddress, _erc1155TypeId, _quantity, _priceInWei);
    }

    function batchSetERC1155Listing(address _erc1155TokenAddress, uint256[] calldata _erc1155TypeIds, uint256[] calldata _quantities, 
        uint256[] calldata _pricesInWei) public onlyOwner{
        
        require(_erc1155TypeIds.length == _quantities.length && _quantities.length == _pricesInWei.length, "inputs must be same length");
        //we need at least 0.1 GHST (1e17) per listing in the wallet to pay the listing fee
        //if we don't have that much, pull the required amount from staking pool
        if(IERC20Upgradeable(ghstAddress).balanceOf(address(this)) < _erc1155TypeIds.length*1e17){
            StakingContract(stakingAddress).withdrawFromPool(ghstAddress, _erc1155TypeIds.length*1e17);
        }

        for(uint256 i = 0; i < _erc1155TypeIds.length; i++){
            IAavegotchi(diamondAddress).setERC1155Listing(_erc1155TokenAddress, _erc1155TypeIds[i], _quantities[i], _pricesInWei[i]);
        }
    }
    
    function cancelERC1155Listing(uint256 _listingId) public onlyOwner{
        IAavegotchi(diamondAddress).cancelERC1155Listing(_listingId);
    }

    function addERC721Listing(address _erc721TokenAddress,uint256 _erc721TokenId,uint256 _priceInWei) public onlyOwner{
        IAavegotchi(diamondAddress).addERC721Listing(_erc721TokenAddress, _erc721TokenId, _priceInWei);
    }

    function cancelERC721ListingByToken(address _erc721TokenAddress, uint256 _erc721TokenId) public onlyOwner{
        IAavegotchi(diamondAddress).cancelERC721ListingByToken(_erc721TokenAddress, _erc721TokenId);
    }

    function updateERC721Listing(address _erc721TokenAddress,uint256 _erc721TokenId,address _owner) public onlyOwner{
        IAavegotchi(diamondAddress).updateERC721Listing(_erc721TokenAddress, _erc721TokenId, _owner);
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //      GLTR farming code                                                          //
    /////////////////////////////////////////////////////////////////////////////////////
    function setGLTRApproval() public onlyApproved{
        IERC20Upgradeable(wapGHST).approve(farmAddress, MAX_INT);
    }

    //this function was called when first upgraded
//    function setGLTRvars() public onlyApproved{
//
//        farmAddress = 0x1fE64677Ab1397e20A1211AFae2758570fEa1B8c;
//        gltrAddress = 0x3801C3B3B5c98F88a9c9005966AA96aa440B9Afc;
//
//        //note: these must be pushed in this exact order as they reflect the order of farming pools
//        alchemicaAddresses.push(0x403E967b044d4Be25170310157cB1A4Bf10bdD0f); //FUD
//        alchemicaAddresses.push(0x44A6e0BE76e1D9620A7F76588e4509fE4fa8E8C8); //FOMO
//        alchemicaAddresses.push(0x6a3E7C3c6EF65Ee26975b12293cA1AAD7e1dAeD2); //ALPHA
//        alchemicaAddresses.push(0x42E5E06EF5b90Fe15F853F59299Fc96259209c5C); //KEK
//
//        quickswapAddress = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
//
//        wapGHST = 0x73958d46B7aA2bc94926d8a215Fa560A5CdCA3eA;
//
//        IERC20Upgradeable(ghstAddress).approve(wapGHST, MAX_INT);
//        IERC20Upgradeable(wapGHST).approve(stakingAddress, MAX_INT);
//
//        IERC20Upgradeable(gltrAddress).approve(quickswapAddress,MAX_INT);
//        IERC20Upgradeable(ghstAddress).approve(quickswapAddress,MAX_INT);
//        IERC20Upgradeable(alchemicaAddresses[0]).approve(quickswapAddress,MAX_INT);
//        IERC20Upgradeable(alchemicaAddresses[1]).approve(quickswapAddress,MAX_INT);
//        IERC20Upgradeable(alchemicaAddresses[2]).approve(quickswapAddress,MAX_INT);
//        IERC20Upgradeable(alchemicaAddresses[3]).approve(quickswapAddress,MAX_INT);
//
//        IERC20Upgradeable(0xfEC232CC6F0F3aEb2f81B2787A9bc9F6fc72EA5C).approve(farmAddress,MAX_INT); //FUD LP
//        IERC20Upgradeable(0x641CA8d96b01Db1E14a5fBa16bc1e5e508A45f2B).approve(farmAddress,MAX_INT); //FOMO LP
//        IERC20Upgradeable(0xC765ECA0Ad3fd27779d36d18E32552Bd7e26Fd7b).approve(farmAddress,MAX_INT); //ALPHA LP
//        IERC20Upgradeable(0xBFad162775EBfB9988db3F24ef28CA6Bc2fB92f0).approve(farmAddress,MAX_INT); //KEK LP
//
//    }

    function stakeAlchemica() public onlyApproved{

        for(uint256 i = 0; i < alchemicaAddresses.length; ){
            //get the current balance of alchemica
            uint256 tokenBalance = IERC20Upgradeable(alchemicaAddresses[i]).balanceOf(address(this));

            address[] memory path = new address[](2);
                path[0] = alchemicaAddresses[i];
                path[1] = ghstAddress;

            //sell 50% of the alchemica for GHST
            Uni(quickswapAddress).swapExactTokensForTokens(tokenBalance/2,0,path,address(this),2626531562);

            //get new balances
            uint256 ghstBalance = IERC20Upgradeable(ghstAddress).balanceOf(address(this));
            uint256 alchemicaBalance = IERC20Upgradeable(alchemicaAddresses[i]).balanceOf(address(this));

            //pool liquidity
            uint256 poolTokens;
            (, , poolTokens) = IUniswapRouterV2(quickswapAddress).addLiquidity(alchemicaAddresses[i],ghstAddress,alchemicaBalance,ghstBalance,0,0,address(this),2626531562);

            //stake -- pool 0 is the wapGHST pool, so skip 0
            farm(farmAddress).deposit(i+1,poolTokens);

            unchecked{
                i++;
            }
        }
    }

    function sellGLTR() public onlyApproved{
        //claim all GLTR from pools 0-4
        uint256[] memory pools = new uint256[](5);
        pools[0] = 0;
        pools[1] = 1;
        pools[2] = 2;
        pools[3] = 3;
        pools[4] = 4;
        farm(farmAddress).batchHarvest(pools);

        //sell for GHST
        uint256 GLTRbalance = IERC20Upgradeable(gltrAddress).balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = gltrAddress;
        path[1] = ghstAddress;

        Uni(quickswapAddress).swapExactTokensForTokens(GLTRbalance,0,path,address(this),2626531562);

        stakeAllGHST();
    }


    function migrateStkGHST() public onlyOwner{

        //the total GHST we have staked in the GHST frens pool
        uint256 totalGHSTStaked;

        //this returns all the pools of assets we have staked on Aavegotchi.com
        PoolStakedOutput[] memory poolsStaked = StakingContract(stakingAddress).stakedInCurrentEpoch(address(this));

        //go through each pool and find the GHST pool
        for(uint256 i = 0; i < poolsStaked.length; i++){

            if(poolsStaked[i].poolAddress == ghstAddress){
                //track how much GHST is in the GHST pool
                totalGHSTStaked = poolsStaked[i].amount;
            }
        }

        //withdraw staked GHST from Aavegotchi.com -- get GHST
        StakingContract(stakingAddress).withdrawFromPool(ghstAddress, totalGHSTStaked);

        //deposit GHST to wapGHST
        uint256 newBalance = IwapGHST(wapGHST).enterWithUnderlying(totalGHSTStaked);

        //stake wapGHST on Aavegotchi.com using wapGHST
        farm(farmAddress).deposit(0,newBalance);
    }

    /////////////////////////////////////////////////////////
    //EIP-1271-compliant functions to allow Snapshot voting
    function getSigner() public view returns(address){
        return signer;
    }

    function setSigner(address _signer) public onlyOwner{
        signer = _signer;
    }

    /**
   * @notice Verifies that the signer is the owner of the signing contract.
   */
    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view returns (bytes4) {
        // Validate signatures
        if (recoverSigner(_hash, _signature) == signer) {
        return 0x1626ba7e;
        } else {
        return 0xffffffff;
        }
    }

    /**
      * @notice Recover the signer of hash, assuming it's an EOA account
   * @dev Only for EthSign signatures
   * @param _ethSignedMessageHash       Hash of message that was signed
   * @param _signature  Signature encoded as (bytes32 r, bytes32 s, uint8 v)
   */
    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature)
    public
    pure
    returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
    public
    pure
    returns (
        bytes32 r,
        bytes32 s,
        uint8 v
    )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
        /*
        First 32 bytes stores the length of the signature
        add(sig, 32) = pointer of sig + 32
        effectively, skips first 32 bytes of signature
        mload(p) loads next 32 bytes starting at the memory address p into memory
        */

        // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
        // second 32 bytes
            s := mload(add(sig, 64))
        // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
    }


    /////////////////////////////////////////////////////////////////////////////////////
    // We need to handle the receipt of ERC1155 and ERC721 tokens, as those will be the winnings
    // of the Aavegotchi raffles
     /**
        @notice Handle the receipt of a single ERC1155 token type.
        @dev An ERC1155-compliant smart contract MUST call this function on the token recipient contract, at the end of a `safeTransferFrom` after the balance has been updated.        
        This function MUST return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` (i.e. 0xf23a6e61) if it accepts the transfer.
        This function MUST revert if it rejects the transfer.
        Return of any other value than the prescribed keccak256 generated value MUST result in the transaction being reverted by the caller.
        @param _operator  The address which initiated the transfer (i.e. msg.sender)
        @param _from      The address which previously owned the token
        @param _id        The ID of the token being transferred
        @param _value     The amount of tokens being transferred
        @param _data      Additional data with no specified format
        @return           `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
    */
    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external pure returns (bytes4) {
        _operator; // silence not used warning
        _from; // silence not used warning
        _id; // silence not used warning
        _value; // silence not used warning
        _data;
        return 0xf23a6e61;
    }

    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external pure returns (bytes4){
        _operator;
        _from;
        _ids;
        _values;
        _data;
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }


    function onERC721Received(
        address, /* _operator */
        address, /*  _from */
        uint256, /*  _tokenId */
        bytes calldata /* _data */
    ) external pure returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    /////////////////////////////////////////////////////////////////////////////////////
}
