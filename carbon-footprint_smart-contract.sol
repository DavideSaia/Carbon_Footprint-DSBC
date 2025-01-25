// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract CarbonFootprintNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // Struttura per i progetti di compensazione
    struct CarbonProject {
        uint256 id;
        string name;
        string description;
        uint256 totalTokenRequired;
        uint256 carbonOffset;
        uint256 currentFunding;
        address projectOwner;
        bool isActive;
    }

    // Struttura per il token di carbonio
    struct CarbonToken {
        uint256 tokenId;
        uint256 carbonFootprint;
        uint256 tokenValue;
        uint256 creationDate;
        string countryOrigin;
    }

    // Mapping per gestire i dati
    mapping(uint256 => CarbonToken) public carbonTokens;
    mapping(uint256 => CarbonProject) public carbonProjects;
    mapping(address => uint256[]) public userTokens;

    // Prezzi e parametri
    uint256 public constant BASE_TOKEN_PRICE = 10 ether;
    uint256 public constant MAX_CARBON_PROJECTS = 10;

    // Interfaccia per ottenere prezzi in tempo reale
    AggregatorV3Interface internal priceFeed;

    // Eventi
    event CarbonTokenMinted(
        address indexed owner, 
        uint256 tokenId, 
        uint256 carbonFootprint
    );
    event ProjectCreated(
        uint256 indexed projectId, 
        string name, 
        uint256 carbonOffset
    );
    event TokenRedeemed(
        address indexed user, 
        uint256 tokenId, 
        uint256 projectId
    );

    constructor() ERC721("CarbonFootprintToken", "CFT") {
        // Inizializzazione con feed prezzo Chainlink (esempio per ETH/USD)
        priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    }

    // Funzione per ottenere il prezzo attuale del token basato su vari fattori
    function calculateTokenPrice(
        uint256 carbonFootprint, 
        string memory country
    ) public view returns (uint256) {
        // Logica di pricing basata su footprint e paese
        uint256 basePrice = BASE_TOKEN_PRICE;
        
        // Moltiplicatore basato sul footprint
        uint256 footprintMultiplier = carbonFootprint > 1000 ? 2 : 1;
        
        // Adattamento del prezzo per paese
        uint256 countryMultiplier = _getCountryMultiplier(country);
        
        return basePrice * footprintMultiplier * countryMultiplier;
    }

    // Funzione interna per ottenere il moltiplicatore del paese
    function _getCountryMultiplier(
        string memory country
    ) internal pure returns (uint256) {
        // Logica semplificata per moltiplicatori paese
        bytes32 countryHash = keccak256(abi.encodePacked(country));
        
        if (countryHash == keccak256(abi.encodePacked("IT"))) return 1;
        if (countryHash == keccak256(abi.encodePacked("DE"))) return 1.2;
        if (countryHash == keccak256(abi.encodePacked("US"))) return 1.5;
        
        return 1;
    }

    // Mintare un nuovo token di carbonio
    function mintCarbonToken(
        uint256 carbonFootprint, 
        string memory country
    ) public payable {
        uint256 tokenPrice = calculateTokenPrice(carbonFootprint, country);
        require(msg.value >= tokenPrice, "Insufficient payment");

        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint del token NFT
        _safeMint(msg.sender, tokenId);

        // Salvataggio dei metadati del token
        carbonTokens[tokenId] = CarbonToken({
            tokenId: tokenId,
            carbonFootprint: carbonFootprint,
            tokenValue: tokenPrice,
            creationDate: block.timestamp,
            countryOrigin: country
        });

        userTokens[msg.sender].push(tokenId);

        emit CarbonTokenMinted(msg.sender, tokenId, carbonFootprint);
    }

    // Creare un nuovo progetto di compensazione
    function createCarbonProject(
        string memory name,
        string memory description,
        uint256 carbonOffset,
        uint256 tokensRequired
    ) public {
        require(MAX_CARBON_PROJECTS > 0, "Max projects reached");

        uint256 projectId = uint256(keccak256(abi.encodePacked(name, block.timestamp)));
        
        carbonProjects[projectId] = CarbonProject({
            id: projectId,
            name: name,
            description: description,
            totalTokenRequired: tokensRequired,
            carbonOffset: carbonOffset,
            currentFunding: 0,
            projectOwner: msg.sender,
            isActive: true
        });

        emit ProjectCreated(projectId, name, carbonOffset);
    }

    // Riscattare token per un progetto
    function redeemTokenForProject(
        uint256 tokenId, 
        uint256 projectId
    ) public {
        require(_exists(tokenId), "Token non esistente");
        require(ownerOf(tokenId) == msg.sender, "Non sei proprietario");
        
        CarbonProject storage project = carbonProjects[projectId];
        require(project.isActive, "Progetto non attivo");

        // Logica di riscatto e aggiornamento progetto
        project.currentFunding += carbonTokens[tokenId].tokenValue;
        
        // Brucia il token dopo il riscatto
        _burn(tokenId);

        emit TokenRedeemed(msg.sender, tokenId, projectId);
    }

    // Funzioni di utilità aggiuntive...
    function getUserTokens(address user) public view returns (uint256[] memory) {
        return userTokens[user];
    }
}