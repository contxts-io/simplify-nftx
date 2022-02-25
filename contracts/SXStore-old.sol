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

    struct FeeParams {
        uint256 ethBase;
        uint256 ethStep;
    }

    struct BountyParams {
        uint256 ethMax;
        uint256 length;
    }

    struct Vault {
        address xTokenAddress;
        address nftAddress;
        address manager;
        IXToken xToken;
        IERC721 nft;
        EnumerableSet.UintSet holdings;
        mapping(uint256 => address) requester;
        mapping(uint256 => bool) isEligible;
        FeeParams mintFees;
        FeeParams burnFees;
        uint256 ethBalance;
        uint256 tokenBalance;
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

    function mintFees(uint256 vaultId) public view returns (uint256, uint256) {
        Vault storage vault = _getVault(vaultId);
        return (vault.mintFees.ethBase, vault.mintFees.ethStep);
    }

    function burnFees(uint256 vaultId) public view returns (uint256, uint256) {
        Vault storage vault = _getVault(vaultId);
        return (vault.burnFees.ethBase, vault.burnFees.ethStep);
    }

    function ethBalance(uint256 vaultId) public view returns (uint256) {
        Vault storage vault = _getVault(vaultId);
        return vault.ethBalance;
    }

    function tokenBalance(uint256 vaultId) public view returns (uint256) {
        Vault storage vault = _getVault(vaultId);
        return vault.tokenBalance;
    }

    // 이 위는 다 public view 함수라 그냥 정보 조회고, 여기서부터 set이다.
    function setXTokenAddress(uint256 vaultId, address _xTokenAddress)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.xTokenAddress = _xTokenAddress;
        emit XTokenAddressSet(vaultId, _xTokenAddress);
    }

    function setNftAddress(uint256 vaultId, address _nft) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.nftAddress = _nft;
        emit NftAddressSet(vaultId, _nft);
    }

    function setManager(uint256 vaultId, address _manager) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.manager = _manager;
        emit ManagerSet(vaultId, _manager);
    }

    function setXToken(uint256 vaultId) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        // 이렇게 컨트랙트 객체를 불러옴
        vault.xToken = IXToken(vault.xTokenAddress);
        emit XTokenSet(vaultId);
    }

    function setNft(uint256 vaultId) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.nft = IERC721(vault.nftAddress);
        emit NftSet(vaultId);
    }

    function holdingsAdd(uint256 vaultId, uint256 elem) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.holdings.add(elem);
        emit HoldingsAdded(vaultId, elem);
    }

    function holdingsRemove(uint256 vaultId, uint256 elem) public onlyOwner {
        Vault storage vault = _getVault(vaultId);
        vault.holdings.remove(elem);
        emit HoldingsRemoved(vaultId, elem);
    }

    function setRequester(uint256 vaultId, uint256 id, address _requester)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.requester[id] = _requester;
        emit RequesterSet(vaultId, id, _requester);
    }

    function setIsEligible(uint256 vaultId, uint256 id, bool _bool)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.isEligible[id] = _bool;
        emit IsEligibleSet(vaultId, id, _bool);
    }

    function setMintFees(uint256 vaultId, uint256 ethBase, uint256 ethStep)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.mintFees = FeeParams(ethBase, ethStep);
        emit MintFeesSet(vaultId, ethBase, ethStep);
    }

    function setBurnFees(uint256 vaultId, uint256 ethBase, uint256 ethStep)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.burnFees = FeeParams(ethBase, ethStep);
        emit BurnFeesSet(vaultId, ethBase, ethStep);
    }

    function setEthBalance(uint256 vaultId, uint256 _ethBalance)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.ethBalance = _ethBalance;
        emit EthBalanceSet(vaultId, _ethBalance);
    }

    function setTokenBalance(uint256 vaultId, uint256 _tokenBalance)
        public
        onlyOwner
    {
        Vault storage vault = _getVault(vaultId);
        vault.tokenBalance = _tokenBalance;
        emit TokenBalanceSet(vaultId, _tokenBalance);
    }

    function addNewVault() public onlyOwner returns (uint256) {
        Vault memory newVault;
        vaults.push(newVault);
        uint256 vaultId = vaults.length.sub(1);
        emit NewVaultAdded(vaultId);
        return vaultId;
    }

    function setRandNonce(uint256 _randNonce) public onlyOwner {
        randNonce = _randNonce;
        emit RandNonceSet(_randNonce);
    }
}
