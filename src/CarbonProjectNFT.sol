// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CarbonProjectNFT is ERC721URIStorage, Ownable, ReentrancyGuard {

    struct ProjectData {
        string parcelId;
        uint256 carbonAmount;
        string projectType;
        string methodology;
        string vintage;
        uint256 mintedAt;
    }

    uint256 public nextId = 1;
    mapping(uint256 => ProjectData) public projectData;

    // Deduplication: parcel_id string → list of project NFT IDs minted for that parcel
    mapping(string => uint256[]) public projectsByParcelId;

    event CarbonProjectMinted(
        uint256 indexed projectId,
        address indexed owner,
        string parcelId,
        uint256 carbonAmount,
        string projectType,
        string methodology,
        string vintage
    );

    constructor() ERC721("Carbon Project", "CARBON-PROJECT") {}

    function mintCarbonProject(
        address to,
        string calldata parcelId,
        uint256 carbonAmount,
        string calldata projectType,
        string calldata methodology,
        string calldata vintage,
        string calldata uri
    ) external onlyOwner nonReentrant returns (uint256 projectId) {
        require(to != address(0), "Cannot mint to zero address");
        require(bytes(parcelId).length > 0, "Parcel ID required");
        require(carbonAmount > 0, "Carbon amount must be greater than 0");
        require(bytes(projectType).length > 0, "Project type required");
        require(bytes(methodology).length > 0, "Methodology required");
        require(bytes(vintage).length > 0, "Vintage required");

        projectId = nextId++;

        _mint(to, projectId);
        _setTokenURI(projectId, uri);

        projectData[projectId] = ProjectData({
            parcelId: parcelId,
            carbonAmount: carbonAmount,
            projectType: projectType,
            methodology: methodology,
            vintage: vintage,
            mintedAt: block.timestamp
        });

        projectsByParcelId[parcelId].push(projectId);

        emit CarbonProjectMinted(
            projectId,
            to,
            parcelId,
            carbonAmount,
            projectType,
            methodology,
            vintage
        );
    }

    function getProjectData(uint256 projectId) external view returns (
        string memory parcelId,
        uint256 carbonAmount,
        string memory projectType,
        string memory methodology,
        string memory vintage,
        uint256 mintedAt
    ) {
        require(_exists(projectId), "Project does not exist");
        ProjectData memory p = projectData[projectId];
        return (p.parcelId, p.carbonAmount, p.projectType, p.methodology, p.vintage, p.mintedAt);
    }

    function getProjectsByParcelId(string calldata parcelId) external view returns (uint256[] memory) {
        return projectsByParcelId[parcelId];
    }

    function setTokenURI(uint256 tokenId, string calldata uri) external onlyOwner {
        require(_exists(tokenId), "Project does not exist");
        _setTokenURI(tokenId, uri);
    }
}
