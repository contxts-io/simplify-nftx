// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Context.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./Address.sol";

contract SERC20 is Context, IERC20 {
    using SafeMath for uint256;
    using Address for address;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(string memory name, string memory symbol) public {
        _name = name;
        _symbol = symbol;
        _decimals = 18;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    function totalSupply()
        public view returns (uint256) { return _totalSupply; }
    function balanceOf(address account)
        public view returns (uint256) { return _balances[account];}
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount)
        internal {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function allowance(address owner, address spender)
        public view returns (uint256){
        return _allowances[owner][spender];
    }
    function transferFrom(address sender, address recipient, uint256 amount)
        public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    function _changeName(string memory name_) internal {
        _name = name_;
    }

    function _changeSymbol(string memory symbol_) internal {
        _symbol = symbol_;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        virtual
    {}
}
