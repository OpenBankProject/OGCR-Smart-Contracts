// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ActivityNFT is ERC721, Ownable {

    struct ActivityData {
        string activity_id;
        string operator_id;
        string name;
        string activity_type;   // 'type' is reserved in Solidity
        string start_date;
        string end_date;
        string activity_url;
        string activity_hash;
    }

    uint256 public nextId = 1;
    address public minter;

    mapping(uint256 => ActivityData) public activities;
    mapping(string => uint256) public tokenIdByActivityId;

    event ActivityMinted(
        uint256 indexed tokenId,
        address indexed to,
        string activity_id,
        string operator_id
    );

    event MinterUpdated(address indexed oldMinter, address indexed newMinter);

    modifier onlyMinter() {
        require(msg.sender == minter, "ActivityNFT: caller is not minter");
        _;
    }

    constructor(address _minter) ERC721("OGCR Activity", "ACT") {
        require(_minter != address(0), "ActivityNFT: zero minter");
        minter = _minter;
        emit MinterUpdated(address(0), _minter);
    }

    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "ActivityNFT: zero address");
        emit MinterUpdated(minter, _minter);
        minter = _minter;
    }

    function mint(
        address to,
        string calldata activity_id,
        string calldata operator_id,
        string calldata name,
        string calldata activity_type,
        string calldata start_date,
        string calldata end_date,
        string calldata activity_url,
        string calldata activity_hash
    ) external onlyMinter returns (uint256 tokenId) {
        require(to != address(0), "ActivityNFT: zero address");
        require(bytes(activity_id).length > 0, "ActivityNFT: activity_id required");
        require(tokenIdByActivityId[activity_id] == 0, "ActivityNFT: already minted");

        tokenId = nextId++;

        _mint(to, tokenId);

        activities[tokenId] = ActivityData({
            activity_id: activity_id,
            operator_id: operator_id,
            name: name,
            activity_type: activity_type,
            start_date: start_date,
            end_date: end_date,
            activity_url: activity_url,
            activity_hash: activity_hash
        });

        tokenIdByActivityId[activity_id] = tokenId;

        emit ActivityMinted(tokenId, to, activity_id, operator_id);
    }

    function getActivity(uint256 tokenId) external view returns (ActivityData memory) {
        require(_exists(tokenId), "ActivityNFT: token does not exist");
        return activities[tokenId];
    }
}
