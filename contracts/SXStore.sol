// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./EnumerableSet.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./IXToken.sol";
import "./IERC721.sol";
import "./SafeERC20.sol";

contract SXStore is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    struct Vault {
        address xTokenAddress;
        address nftAddress;
        address manager;
        IXToken xToken;
        IERC721 nft;
        EnumerableSet.UintSet holdings;
        mapping(uint256 => address) requester;
        mapping(uint256 => bool) isEligible;
        uint256 mintFee;
        uint256 burnFee;
        uint256 ethBalance;
        uint256 tokenBalance;
        bool enableAllNfts;
    }

    Vault[] internal vaults;

    mapping(address => bool) public isExtension;
    uint256 public randNonce;

    constructor() public {
        initOwnable();
    }

    function _getVault(uint256 vaultId) internal view returns (Vault storage) {
        require(vaultId < vaults.length, "Invalid vaultId");
        return vaults[vaultId];
    }

    function vaultsLength() public view returns (uint256) {
        return vaults.length;
    }

    function xTokenAddress(uint256 vaultId) public view returns (address) {
        Vault storage vault = _getVault(vaultId);
        return vault.xTokenAddress;
    }

    function nftAddress(uint256 vaultId) public view returns (address) {
        Vault storage vault = _getVault(vaultId);
        return vault.nftAddress;
    }

    function manager(uint256 vaultId) public view returns (address) {
        Vault storage vault = _getVault(vaultId);
        return vault.manager;
    }

    function xToken(uint256 vaultId) public view returns (IXToken) {
        Vault storage vault = _getVault(vaultId);
        return vault.xToken;
    }

    function nft(uint256 vaultId) public view returns (IERC721) {
        Vault storage vault = _getVault(vaultId);
        return vault.nft;
    }

    function holdingsLength(uint256 vaultId) public view returns (uint256) {
        Vault storage vault = _getVault(vaultId);
        return vault.holdings.length();
    }

    function holdingsContains(uint256 vaultId, uint256 elem)
        public
        view
        returns (bool)
    {
        Vault storage vault = _getVault(vaultId);
        return vault.holdings.contains(elem);
    }

    function holdingsAt(uint256 vaultId, uint256 index)
        public
        view
        returns (uint256)
    {
        Vault storage vault = _getVault(vaultId);
        return vault.holdings.at(index);
    }

    function requester(uint256 vaultId, uint256 id)
        public
        view
        returns (address)
    {
        Vault storage vault = _getVault(vaultId);
        return vault.requester[id];
    }

    function isEligible(uint256 vaultId, uint256 id)
        public
        view
        returns (bool)
    {
        Vault storage vault = _getVault(vaultId);
        return vault.isEligible[id];
    }

    function mintFee(uint256 vaultId) public view returns (uint256, uint256) {
        Vault storage vault = _getVault(vaultId);
        return vault.mintFee;
    }

    function burnFee(uint256 vaultId) public view returns (uint256, uint256) {
        Vault storage vault = _getVault(vaultId);
        return vault.burnFee;
    }

    function ethBalance(uint256 vaultId) public view returns (uint256) {
        Vault storage vault = _getVault(vaultId);
        return vault.ethBalance;
    }

    function tokenBalance(uint256 vaultId) public view returns (uint256) {
        Vault storage vault = _getVault(vaultId);
        return vault.tokenBalance;
    }

    function enableAllNfts(uint256 vaultId) public view returns (uint256) {
        Vault storage vault = _getVault(vaultId);
        return vault.enableAllNfts;
    }

    function setEnableAllNfts(uint256 vaultId, bool _bool) public onlyOwner{
        Vault storage vault = _getVault(vaultId);
        vault.enableAllNfts = _bool;
    }

    // ??? ?????? ??? public view ????????? ?????? ?????? ?????????, ??????????????? set??????.
    function setXTokenAddress(uint256 vaultId, address _xTokenAddress)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.xTokenAddress = _xTokenAddress;
    }

    function setNftAddress(uint256 vaultId, address _nft) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.nftAddress = _nft;
    }

    function setManager(uint256 vaultId, address _manager) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.manager = _manager;
    }

    function setXToken(uint256 vaultId) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        // ????????? ???????????? ????????? ?????????
        vault.xToken = IXToken(vault.xTokenAddress);
    }

    function setNft(uint256 vaultId) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.nft = IERC721(vault.nftAddress);
    }

    function holdingsAdd(uint256 vaultId, uint256 elem) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.holdings.add(elem);
    }

    function holdingsRemove(uint256 vaultId, uint256 elem) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.holdings.remove(elem);
    }

    function setRequester(uint256 vaultId, uint256 id, address _requester)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.requester[id] = _requester;
    }

    function setIsEligible(uint256 vaultId, uint256 id, bool _bool)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.isEligible[id] = _bool;
    }

    function setMintFee(uint256 vaultId, uint256 fee)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.mintFee = fee;
    }

    function setBurnFee(uint256 vaultId, uint256 fee)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.burnFee = fee;
    }

    function setEthBalance(uint256 vaultId, uint256 _ethBalance)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.ethBalance = _ethBalance;
    }

    function setTokenBalance(uint256 vaultId, uint256 _tokenBalance)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.tokenBalance = _tokenBalance;
    }

    function addNewVault() public onlyOwner returns (uint256) {
        Vault memory newVault;
        vaults.push(newVault);
        uint256 vaultId = vaults.length.sub(1);
        return vaultId;
    }

    function setRandNonce(uint256 _randNonce) public onlyOwner {
        randNonce = _randNonce;
    }
}
