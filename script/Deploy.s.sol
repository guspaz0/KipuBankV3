// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/contracts/KipuBankV3.sol";

contract DeployKipuBankV3 is Script {
    function run() external {
        // --- Configurar los parámetros ---
        uint256 bankCap = vm.envUint("BANK_CAP_USDC");                      // Limite de depositos en USDC
        address router = vm.envAddress("ROUTER_ADDRESS");                   // UniswapV2Router02 en Sepolia
        address ethUsdPriceFeed = vm.envAddress("PRICE_FEEDS_ADDRESS");     // Feed precios USDC en Sepolia
        address usdc = vm.envAddress("USDC_ADDRESS");                       // USDC en Sepolia
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");             // Tu dirección

        vm.startBroadcast();

        KipuBankV3 bank = new KipuBankV3(bankCap, ethUsdPriceFeed, router, usdc);

        console.log("==================================");
        console.log("Deploying KipuBankV3...");
        console.log("==================================");
        console.log("ETH/USD Price Feed:", ethUsdPriceFeed);
        console.log("UniswapV2 Router:", router);
        console.log("Bank Cap (USDC):", bankCap);
        console.log("==================================");

        vm.stopBroadcast();

        console.log("==================================");
        console.log("Deployment Successful!");
        console.log("==================================");
        console.log("KipuBankV3 deployed at:", address(bank));
        console.log("==================================");
        console.log("\nNext Steps:");
        console.log("1. Wait for block confirmations");
        console.log("2. Verify contract with:");
        console.log("   forge verify-contract", address(bank), "src/contracts/KipuBankV3.sol:KipuBankV3 --chain sepolia --watch");
        console.log("\nView on Sepolia Etherscan:");
        console.log("https://sepolia.etherscan.io/address/%s", address(bank));
        console.log("==================================");

    }
}