// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title CarbonProjectNFT
 * @dev Represents carbon projects developed on geographic parcels
 * 
 * This NFT represents a specific carbon project (methodology, carbon amount, etc.)
 * that is tied to a geographic parcel. Multiple projects can exist on the same parcel.
 */
contract CarbonProjectNFT is ERC721URIStorage, Ownable, ReentrancyGuard {
    
    struct ProjectData {
        address geographicParcelNft;    // Address of the geographic parcel NFT contract
        uint256 geographicParcelId;     // ID of the geographic parcel this project is on
        address erc20Token;             // ERC20 token to mint when redeemed
        uint256 carbonAmount;           // Amount of carbon credits this project represents
        address tokenRecipient;         // Who receives the ERC20 tokens when redeemed
        string projectType;             // e.g., "Reforestation", "Renewable Energy", "Soil Carbon"
        string methodology;             // Carbon methodology used (e.g., "VCS", "Gold Standard")
        string vintage;                 // Year/period the carbon was captured/avoided
        uint256 developmentDate;        // When this project was developed
        bool redeemed;                  // Whether this project has been redeemed for tokens
        bool verified;                  // Whether this project has been verified
    }

    uint256 public nextId = 1;
    mapping(uint256 => ProjectData) public projectData;
    
    // Authorized contracts that can mark projects as redeemed
    mapping(address => bool) public authorizedRedeemers;
    
    // Track projects per geographic parcel
    mapping(address => mapping(uint256 => uint256[])) public projectsOnParcel;

    event CarbonProjectMinted(
        uint256 indexed projectId,
        address indexed owner,
        address indexed geographicParcelNft,
        uint256 geographicParcelId,
        uint256 carbonAmount,
        string projectType,
        string methodology,
        string vintage
    );
    
    event ProjectRedeemed(uint256 indexed projectId, address indexed redeemedBy);
    event ProjectVerified(uint256 indexed projectId, bool verified);
    event RedeemerAuthorized(address indexed redeemer, bool authorized);

    constructor() ERC721("Carbon Project", "CARBON-PROJECT") {}

    /**
     * @dev Mint a new carbon project NFT
     * @param to Address to receive the project NFT
     * @param geographicParcelNft Address of the geographic parcel NFT contract
     * @param geographicParcelId ID of the geographic parcel
     * @param erc20Token ERC20 token contract to mint when redeemed
     * @param carbonAmount Amount of carbon credits this project represents
     * @param tokenRecipient Who receives tokens when project is redeemed
     * @param projectType Type of carbon project
     * @param methodology Carbon methodology used
     * @param vintage Year/period of carbon capture/avoidance
     * @param uri Metadata URI for the project
     */
    function mintCarbonProject(
        address to,
        address geographicParcelNft,
        uint256 geographicParcelId,
        address erc20Token,
        uint256 carbonAmount,
        address tokenRecipient,
        string calldata projectType,
        string calldata methodology,
        string calldata vintage,
        string calldata uri
    ) external onlyOwner nonReentrant returns (uint256 projectId) {
        require(to != address(0), "Cannot mint to zero address");
        require(geographicParcelNft != address(0), "Invalid parcel NFT contract");
        require(erc20Token != address(0), "Invalid ERC20 token contract");
        require(tokenRecipient != address(0), "Invalid token recipient");
        require(carbonAmount > 0, "Carbon amount must be greater than 0");
        require(bytes(projectType).length > 0, "Project type required");
        require(bytes(methodology).length > 0, "Methodology required");
        require(bytes(vintage).length > 0, "Vintage required");
        
        // Verify the geographic parcel exists (basic check)
        // In a full implementation, you might want to verify parcel ownership/approval
        
        projectId = nextId++;
        
        // Mint the NFT
        _mint(to, projectId);
        _setTokenURI(projectId, uri);
        
        // Store project data
        projectData[projectId] = ProjectData({
            geographicParcelNft: geographicParcelNft,
            geographicParcelId: geographicParcelId,
            erc20Token: erc20Token,
            carbonAmount: carbonAmount,
            tokenRecipient: tokenRecipient,
            projectType: projectType,
            methodology: methodology,
            vintage: vintage,
            developmentDate: block.timestamp,
            redeemed: false,
            verified: true  // Auto-verify projects upon creation
        });
        
        // Track project on the geographic parcel
        projectsOnParcel[geographicParcelNft][geographicParcelId].push(projectId);
        
        emit CarbonProjectMinted(
            projectId,
            to,
            geographicParcelNft,
            geographicParcelId,
            carbonAmount,
            projectType,
            methodology,
            vintage
        );
    }

    /**
     * @dev Mark a project as redeemed - can be called by authorized contracts
     * @param projectId The project to mark as redeemed
     */
    function markRedeemed(uint256 projectId) external {
        require(
            authorizedRedeemers[msg.sender] || msg.sender == owner(),
            "Not authorized to mark as redeemed"
        );
        
        ProjectData storage project = projectData[projectId];
        require(!project.redeemed, "Project already redeemed");
        require(_exists(projectId), "Project does not exist");
        
        project.redeemed = true;
        emit ProjectRedeemed(projectId, msg.sender);
    }

    /**
     * @dev Set verification status of a project
     * @param projectId The project to verify/unverify
     * @param verified Whether the project is verified
     */
    function setProjectVerified(uint256 projectId, bool verified) external onlyOwner {
        require(_exists(projectId), "Project does not exist");
        projectData[projectId].verified = verified;
        emit ProjectVerified(projectId, verified);
    }

    /**
     * @dev Authorize/deauthorize a contract to mark projects as redeemed
     * @param redeemer The address to authorize/deauthorize
     * @param authorized Whether to authorize or deauthorize
     */
    function setAuthorizedRedeemer(address redeemer, bool authorized) external onlyOwner {
        authorizedRedeemers[redeemer] = authorized;
        emit RedeemerAuthorized(redeemer, authorized);
    }

    /**
     * @dev Get complete project data
     * @param projectId The project to query
     */
    function getProjectData(uint256 projectId) external view returns (
        address geographicParcelNft,
        uint256 geographicParcelId,
        address erc20Token,
        uint256 carbonAmount,
        address tokenRecipient,
        string memory projectType,
        string memory methodology,
        string memory vintage,
        uint256 developmentDate,
        bool redeemed,
        bool verified
    ) {
        require(_exists(projectId), "Project does not exist");
        ProjectData memory project = projectData[projectId];
        
        return (
            project.geographicParcelNft,
            project.geographicParcelId,
            project.erc20Token,
            project.carbonAmount,
            project.tokenRecipient,
            project.projectType,
            project.methodology,
            project.vintage,
            project.developmentDate,
            project.redeemed,
            project.verified
        );
    }

    /**
     * @dev Get all projects on a specific geographic parcel
     * @param geographicParcelNft The geographic parcel NFT contract
     * @param geographicParcelId The geographic parcel ID
     */
    function getProjectsOnParcel(address geographicParcelNft, uint256 geographicParcelId) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return projectsOnParcel[geographicParcelNft][geographicParcelId];
    }

    /**
     * @dev Check if a project is verified and not yet redeemed
     * @param projectId The project to check
     */
    function isProjectRedeemable(uint256 projectId) external view returns (bool) {
        require(_exists(projectId), "Project does not exist");
        ProjectData memory project = projectData[projectId];
        return project.verified && !project.redeemed;
    }
}