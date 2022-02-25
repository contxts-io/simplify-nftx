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

    function _payEthFromVault(
        uint256 vaultId,
        uint256 amount,
        address payable to
    ) internal virtual {
        uint256 ethBalance = store.ethBalance(vaultId);
        uint256 amountToSend = ethBalance < amount ? ethBalance : amount;
        if (amountToSend > 0) {
            store.setEthBalance(vaultId, ethBalance.sub(amountToSend));
            to.transfer(amountToSend);
        }
    }

    function _calcFee(
        uint256 amount,
        uint256 ethBase,
        uint256 ethStep
    ) internal pure returns (uint256) {
        if (amount == 0) {
            return 0;
        } else {
            uint256 n = amount;
            uint256 nSub1 = amount >= 1 ? n.sub(1) : 0;
            return ethBase.add(ethStep.mul(nSub1));
        }
    }

    function createVault(
        address _xTokenAddress,
        address _assetAddress
    ) public returns (uint256) {
        IXToken xToken = IXToken(_xTokenAddress);
        require(xToken.owner() == address(this), "Wrong owner");
        uint256 vaultId = store.addNewVault();

        store.setXTokenAddress(vaultId, _xTokenAddress);
        store.setXToken(vaultId);
        store.setNftAddress(vaultId, _assetAddress);
        store.setNft(vaultId);
        store.setManager(vaultId, msg.sender);

        return vaultId;
    }

    function requestMint(uint256 vaultId, uint256[] memory nftIds)
        public
        payable
    {
        uint256 amount = nftIds.length;
        (uint256 ethBase, uint256 ethStep)
            = store.mintFees(vaultId);
        uint256 ethFee = _calcFee(
            amount,
            ethBase,
            ethStep
        );
        _receiveEthToVault(vaultId, ethFee, msg.value);
        for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
            require(
                store.nft(vaultId).ownerOf(nftIds[i])
                    != address(this),
                "Already owner"
            );
            // store.nft(vaultId)는 ERC721 contract 객체다.
            store.nft(vaultId).safeTransferFrom(
                msg.sender,
                address(this),
                nftIds[i]
            );
            require(
                store.nft(vaultId).ownerOf(nftIds[i])
                    == address(this),
                "Not received"
            );
            store.setRequester(vaultId, nftIds[i], msg.sender);
        }
    }

    // 위에 거 반대로 해서 취소하는 기능
    function revokeMintRequests(
        uint256 vaultId,
        uint256[] memory nftIds)
        public
    {
        uint256 amount = nftIds.length;
        (uint256 ethBase, uint256 ethStep)
            = store.mintFees(vaultId);
        uint256 ethFee = _calcFee(
            amount,
            ethBase,
            ethStep
        );
        _payEthFromVault(vaultId, ethFee, msg.sender);
        for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
            require(
                store.requester(vaultId, nftIds[i])
                    == msg.sender,
                "Not requester"
            );
            store.setRequester(vaultId, nftIds[i], address(0));
            store.nft(vaultId).safeTransferFrom(
                address(this),
                msg.sender,
                nftIds[i]
            );
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

    function approveMintRequest(
        uint256 vaultId,
        uint256[] memory nftIds
    ) public {
        // modifier 대신 이렇게 함수 호출로 쓸 수도 있음.
        onlyPrivileged(vaultId);
        for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
            address requester = store.requester(
                vaultId, nftIds[i]);
            require(requester != address(0), "No request");
            require(
                store.nft(vaultId).ownerOf(nftIds[i])
                    == address(this),
                "Not owner"
            );
            store.setRequester(vaultId, nftIds[i], address(0));
            store.setIsEligible(vaultId, nftIds[i], true);
            store.holdingsAdd(vaultId, nftIds[i]);
            // wei 단위 때문에 이렇게 10**18을 곱해줘야 한다.
            // 일단 이렇게 찍어만 놓고, requester에게 나중에 준다.
            store.xToken(vaultId).mint(requester, 10**18);
        }
    }

    function _mint(uint256 vaultId, uint256[] memory nftIds)
        internal
    {
        for (uint256 i = 0; i < nftIds.length; i = i.add(1)) {
            uint256 nftId = nftIds[i];
            require(isEligible(vaultId, nftId), "Not eligible");
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
        (uint256 ethBase, uint256 ethStep)
            = store.mintFees(vaultId);
        uint256 ethFee = _calcFee(
            amount,
            ethBase,
            ethStep
        );
        _receiveEthToVault(vaultId, ethFee, msg.value);
        _mint(vaultId, nftIds, false);
    }

    function _redeem(uint256 vaultId, uint256 numNFTs) internal {
        for (uint256 i = 0; i < numNFTs; i = i.add(1)) {
            // 새 array를 만들어줌
            uint256[] memory nftIds = new uint256[](1);
            uint256 rand = _getPseudoRand(
                store.holdingsLength(vaultId));
            nftIds[0] = store.holdingsAt(vaultId, rand);
            _redeemHelper(vaultId, nftIds);
        }
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
        (uint256 ethBase, uint256 ethStep)
            = store.burnFees(vaultId);
        uint256 ethFee = _calcFee(
            amount,
            ethBase,
            ethStep
        );
        _receiveEthToVault(vaultId, ethFee, msg.value);
        _redeem(vaultId, amount, false);
    }

    function setManager(uint256 vaultId, address newManager)
        public virtual {
        onlyPrivileged(vaultId);
        store.setManager(vaultId, newManager);
    }

    function setMintFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep
    )
        public
        virtual
    {
        onlyPrivileged(vaultId);
        store.setMintFees(vaultId, _ethBase, _ethStep);
    }

    function setBurnFees(
        uint256 vaultId,
        uint256 _ethBase,
        uint256 _ethStep
    )
        public
        virtual
    {
        onlyPrivileged(vaultId);
        store.setBurnFees(vaultId, _ethBase, _ethStep);
    }
}
