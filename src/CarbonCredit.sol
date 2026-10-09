// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CarbonCredit is ERC20, Ownable {

    address public minter;

    // Cumulative amount ever minted to an address. Unlike balanceOf it does not
    // drop when credits are moved or burned, so the tokenizer can tell whether a
    // batch's token-bound account has already been funded.
    mapping(address => uint256) public mintedTo;

    event MinterUpdated(address indexed oldMinter, address indexed newMinter);

    modifier onlyMinter() {
        require(msg.sender == minter, "CarbonCredit: caller is not minter");
        _;
    }

    constructor(address _minter) ERC20("Carbon Credit", "CC") {
        require(_minter != address(0), "CarbonCredit: zero minter");
        minter = _minter;
        emit MinterUpdated(address(0), _minter);
    }

    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "CarbonCredit: zero address");
        emit MinterUpdated(minter, _minter);
        minter = _minter;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        require(to != address(0), "CarbonCredit: zero address");
        mintedTo[to] += amount;
        _mint(to, amount);
    }

    // Requires the token holder to have approved the minter via ERC-20 approve().
    // This prevents the minter from confiscating tokens without the holder's consent.
    function burn(address from, uint256 amount) external onlyMinter {
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
    }
}
