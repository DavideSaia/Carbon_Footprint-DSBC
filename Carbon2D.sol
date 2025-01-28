// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Carbon2D is ERC20, Ownable {
    // Struttura per i progetti di compensazione
    struct CompensationProject {
        string name;
        uint256 requiredTokens;
        uint256 co2Reduction;
        uint256 price;
        bool active;
        uint256 totalContributed;
        address projectOwner; // Proprietario del progetto
    }
    
    // Struttura per i dati dell'impronta di carbonio
    struct CarbonData {
        uint256 electricityConsumption;
        uint256 carKilometers;
        uint256 flights;
        uint256 meatConsumption;
        uint256 totalEmissions;
        uint256 timestamp;
        uint256 tokenPrice;
    }
    
    // Prezzo fisso per i token
    uint256 public constant TOKEN_PRICE = 12500000000000000; // 0.0125 ETH
    
    // Mapping per memorizzare i dati
    mapping(address => CarbonData) public userCarbonData;
    mapping(uint256 => CompensationProject) public projects;
    mapping(uint256 => mapping(address => uint256)) public userContributions; // Contributi degli utenti per progetto
    uint256 public projectCounter;
    uint256 public totalMintedTokens; // Totale dei token mintati
    
    // Eventi per tracciare le azioni
    event TokensMinted(address indexed recipient, uint256 amount, uint256 emissions);
    event ProjectCreated(uint256 projectId, string name, uint256 price);
    event ProjectCompensated(uint256 projectId, address indexed user, uint256 tokens);
    event ProjectCompleted(uint256 projectId, address indexed projectOwner, uint256 tokens);

    constructor() ERC20("Carbon2D", "C2D") Ownable(msg.sender) {
        projectCounter = 0;
        totalMintedTokens = 0;
        // Inizializza i progetti predefiniti
        _createProject("Riforestazione Amazzonica", 5, 500, 62500000000000000); // 0.0625 ETH
        _createProject("Energia Solare in Africa", 3, 300, 37500000000000000); // 0.0375 ETH
        _createProject("Turbine Eoliche", 8, 800, 100000000000000000); // 0.1 ETH
    }

    function _createProject(
        string memory name,
        uint256 requiredTokens,
        uint256 co2Reduction,
        uint256 price
    ) internal {
        projectCounter++;
        projects[projectCounter] = CompensationProject(
            name,
            requiredTokens,
            co2Reduction,
            price,
            true,
            0,
            msg.sender // Il creatore del progetto è il proprietario
        );
        emit ProjectCreated(projectCounter, name, price);
    }

    // Funzione per creare un nuovo progetto (pubblica)
    function createProject(
        string memory name,
        uint256 requiredTokens,
        uint256 co2Reduction,
        uint256 price
    ) public {
        _createProject(name, requiredTokens, co2Reduction, price);
    }

    // Funzione per acquistare token
    function buyTokens(uint256 tokenAmount) public payable {
        require(msg.value >= TOKEN_PRICE * tokenAmount, "Insufficient payment");
        _mint(msg.sender, tokenAmount);
        totalMintedTokens += tokenAmount; // Aggiorna il totale dei token mintati
        emit TokensMinted(msg.sender, tokenAmount, 0);
    }

    // Funzione per registrare le emissioni
    function recordEmissions(
        uint256 electricityConsumption,
        uint256 carKilometers,
        uint256 flights,
        uint256 meatConsumption
    ) public {
        uint256 totalEmissions = calculateEmissions(
            electricityConsumption,
            carKilometers,
            flights,
            meatConsumption
        );
        
        userCarbonData[msg.sender] = CarbonData(
            electricityConsumption,
            carKilometers,
            flights,
            meatConsumption,
            totalEmissions,
            block.timestamp,
            TOKEN_PRICE
        );
    }

    function calculateEmissions(
        uint256 electricityConsumption,
        uint256 carKilometers,
        uint256 flights,
        uint256 meatConsumption
    ) public pure returns (uint256) {
        uint256 electricityFactor = 0.4 ether; // kWh to kg CO2
        uint256 carFactor = 0.2 ether; // km to kg CO2
        uint256 flightFactor = 200 ether; // flights to kg CO2
        uint256 meatFactor = 50 ether; // kg meat to kg CO2
        
        return (electricityConsumption * electricityFactor + 
                carKilometers * carFactor + 
                flights * flightFactor + 
                meatConsumption * meatFactor) / 1 ether;
    }

    // Funzione per compensare un progetto
    function compensateProject(uint256 projectId, uint256 tokenAmount) public {
        require(projects[projectId].active, "Project not active");
        require(balanceOf(msg.sender) >= tokenAmount, "Insufficient tokens");

        // Calcola il massimo di token che l'utente può contribuire
        uint256 remainingTokens = projects[projectId].requiredTokens - projects[projectId].totalContributed;
        require(tokenAmount <= remainingTokens, "Exceeds remaining tokens for the project");

        // Trasferisci i token dal contributore al contratto
        _transfer(msg.sender, address(this), tokenAmount);
        projects[projectId].totalContributed += tokenAmount;
        userContributions[projectId][msg.sender] += tokenAmount;
        emit ProjectCompensated(projectId, msg.sender, tokenAmount);

        // Se l'obiettivo è raggiunto, disattiva il progetto e trasferisci i token al proprietario
        if (projects[projectId].totalContributed >= projects[projectId].requiredTokens) {
            projects[projectId].active = false;
            _transfer(address(this), projects[projectId].projectOwner, projects[projectId].totalContributed);
            emit ProjectCompleted(projectId, projects[projectId].projectOwner, projects[projectId].totalContributed);
        }
    }

    // Funzione per ottenere lo stato di avanzamento del progetto
    function getProjectProgress(uint256 projectId) public view returns (uint256) {
        CompensationProject memory project = projects[projectId];
        if (project.requiredTokens == 0) return 0;
        return (project.totalContributed * 100) / project.requiredTokens;
    }

    // Funzione per prelevare i fondi dal contratto (solo owner)
    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}