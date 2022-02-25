// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Ownable.sol";
import "./IXToken.sol";
import "./IERC721.sol";
import "./ERC721Holder.sol";
import "./IXStore.sol";
import "./Initializable.sol";
import "./SafeERC20.sol";

contract SNFTX is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IXStore public store;

    function initialize(address storeAddress) public initializer {
        initOwnable();
        store = IXStore(storeAddress);
    }

    // modifier가 아니라 그냥 함수로 구현함
    function onlyPrivileged(uint256 vaultId) internal view {
        require(msg.sender == store.manager(vaultId),
            "Not manager");
    }

    function _getPseudoRand(uint256 modulus)
        internal
        returns (uint256)
    {
        store.setRandNonce(store.randNonce().add(1));
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        now, msg.sender, store.randNonce()))
            ) %
            modulus;
    }

    function _receiveEthToVault(
        uint256 vaultId,
        uint256 amountRequested,
        uint256 amountSent
    ) internal {
        require(amountSent >= amountRequested, "Value too low");
        store.setEthBalance(
            vaultId,
            store.ethBalance(vaultId).add(amountRequested)
        );
        // 잔돈 거슬러줌.
        if (amountSent > amountRequested) {
            msg.sender.transfer(amountSent.sub(amountRequested));
        }
    }

    function _calcFee(
        uint256 amount,
        uint256 fee
    ) internal pure returns (uint256) {
        if (amount == 0) {
            return 0;
        } else {
            return amount.mul(fee);
        }
    }

    function setIsEligible(
        uint256 vaultId,
        uint256[] memory nftIds,
        bool _boolean
    ) public {
        onlyPrivileged(vaultId);
        for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
            store.setIsEligible(vaultId, nftIds[i], _boolean);
        }
    }

    function isEligible(uint256 vaultId, uint256 nftId)
        public
        view
        returns (bool)
    {
        return store.isEligible(vaultId, nftId);
    }

    function setEnableAllNfts(uint256 vaultId, bool _bool)
        public
    {
        onlyPrivileged(vaultId);
        store.setEnableAllNfts(vaultId, _bool);
    }

    function createVault(
        address _xTokenAddress,
        address _assetAddress,
        bool enableAllNfts,
        uint256[] memory eligibleNftIds,
    ) public returns (uint256) {
        IXToken xToken = IXToken(_xTokenAddress);
        require(xToken.owner() == address(this), "Wrong owner");
        uint256 vaultId = store.addNewVault();

        store.setXTokenAddress(vaultId, _xTokenAddress);
        store.setXToken(vaultId);
        store.setNftAddress(vaultId, _assetAddress);
        store.setNft(vaultId);
        store.setManager(vaultId, msg.sender);

        if (enableAllNfts) {
            setEnableAllNfts(vaultId, true);
        } else {
            setEnableAllNfts(vaultId, false);
            setIsEligible(vaultId, eligibleNftIds, true);
        }

        return vaultId;
    }

    function _mint(uint256 vaultId, uint256[] memory nftIds)
        internal
    {
        for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
            uint256 nftId = nftIds[i];
            if (!store.enableAllNfts(vaultId){
                (isEligible(vaultId, nftId), "Not eligible");
            })
            require(
                store.nft(vaultId).ownerOf(nftId)
                    != address(this),
                "Already owner"
            );
            // 1)NFT를 vault에 옮기고
            store.nft(vaultId).safeTransferFrom(
                msg.sender,
                address(this),
                nftId
            );
            require(
                store.nft(vaultId).ownerOf(nftId)
                    == address(this),
                "Not received"
            );
            store.holdingsAdd(vaultId, nftId);
        }
        uint256 amount = nftIds.length.mul(10**18);
        // 2)vault token 찍어준다.
        store.xToken(vaultId).mint(msg.sender, amount);
    }

    function mint(uint256 vaultId, uint256[] memory nftIds)
        public payable
    {
        uint256 amount = nftIds.length;
        uint256 fee = store.mintFee(vaultId);
        uint256 ethFee = _calcFee(amount,fee);
        _receiveEthToVault(vaultId, ethFee, msg.value);
        _mint(vaultId, nftIds, false);
    }

    function _redeem(uint256 vaultId, uint256 numNFTs) internal {
        // 새 array를 만들어줌
        uint256[] memory nftIds = new uint256[](numNFTs);
        for (uint256 i = 0; i < numNFTs; i = i.add(1)) {
            uint256 rand = _getPseudoRand(
                store.holdingsLength(vaultId));
            nftIds[i] = store.holdingsAt(vaultId, rand);
        }
        _redeemHelper(vaultId, nftIds);
    }

    function _redeemHelper(
        uint256 vaultId,
        uint256[] memory nftIds
    ) internal {
        store.xToken(vaultId).burnFrom(
            msg.sender,
            nftIds.length.mul(10**18)
        );
        for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
            uint256 nftId = nftIds[i];
            require(
                store.holdingsContains(vaultId, nftId) ||
                    store.reservesContains(vaultId, nftId),
                "NFT not in vault"
            );
            store.holdingsRemove(vaultId, nftId);
            store.nft(vaultId).safeTransferFrom(
                address(this),
                msg.sender,
                nftId
            );
        }
    }

    function redeem(uint256 vaultId, uint256 amount)
        public payable
    {
        uint256 fee = store.burnFee(vaultId);
        uint256 ethFee = _calcFee(amount,fee);
        _receiveEthToVault(vaultId, ethFee, msg.value);
        _redeem(vaultId, amount, false);
    }

    function setManager(uint256 vaultId, address newManager)
        public virtual {
        onlyPrivileged(vaultId);
        store.setManager(vaultId, newManager);
    }

    function setMintFee(
        uint256 vaultId,
        uint256 fee
    )
        public
        virtual
    {
        onlyPrivileged(vaultId);
        store.setMintFee(vaultId, fee);
    }

    function setBurn(
        uint256 vaultId,
        uint256 fee
    )
        public
        virtual
    {
        onlyPrivileged(vaultId);
        store.setBurnFee(vaultId, fee);
    }
}
