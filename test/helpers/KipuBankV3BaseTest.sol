///SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console } from "forge-std/Test.sol";

import { KipuBankV3 } from "src/contracts/KipuBankV3.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockV3Aggregator} from "@chainlink-local/src/data-feeds/MockV3Aggregator.sol"; // Chainlink
import {MockUniswapV2Router02} from "../mocks/MockUniswapV2Router02.sol";
import {MockUniswapV2Factory} from "../mocks/MockUniswapV2Factory.sol";

abstract contract KipuBankV3BaseTest is Test {
///@notice instancia del contrato KipuBankV3
    KipuBankV3 public bank;

    MockUniswapV2Router02 public router;
    MockUniswapV2Factory public factory;

    ///@notice Instancia de Mock para token ETC20
    MockERC20 public s_usdc;
    MockERC20 public s_weth;
    MockERC20 public s_dai;
    MockERC20 public s_wbtc;

    ///@notice Instancia de Mock de CL Feeds
    MockV3Aggregator public s_clFeed;

    //Variables ~ Users
    address owner = address(77);
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    //Variables ~ Utils
    //@notice Parametros de CL Feeds
    uint8 constant DECIMALS = 6;
    int256 constant INITIAL_ANSWER = 2500 * 10 ** 8;
    // ------ conversion --------
    // dado que 1 USDC = 250,000,000,000 wei
    // y dado que 1 ETH = 1,000,000,000,000,000,000 wei
    // entonces 1 USDC = 0.00025 ETH 
    uint256 constant ONE_ETHER_TO_USD = 4000;
    uint256 constant ONE_USD_TO_WEI = 0.00025 ether;

    uint256 constant BANK_CAP = 10000; // Banco Capacidad en USD 4000 o 1 ETH

    uint256 constant ETHER_INITIAL_BALANCE = 2 ether; // 40 million USD
    address constant ETH_ADDRESS = address(0);

    uint256 constant USDC_INITIAL_BALANCE = 10_000 * 10 ** 6;

    /*////////////////////////////////////
            * ENVIRONMENT SETUP * 
    ////////////////////////////////////*/

    function setUp() public {
        s_usdc = new MockERC20("USDC Coin", "USDC", 6);
        s_weth = new MockERC20("Wrapped Ether", "WETH", 18);
        s_dai = new MockERC20("Dai", "DAI", 18);
        s_wbtc = new MockERC20("Wrapped BTC", "WBTC", 8);

        // Router + Factory
        router = new MockUniswapV2Router02(address(s_weth));
        factory = new MockUniswapV2Factory();
        router.setFactory(address(factory));
        router.setUSDC(address(s_usdc));

        // Rates
        router.setTokenRate(address(s_dai), 1e18); // 1 DAI -> 1 USDC
        router.setTokenRate(address(s_wbtc), 70_000e18); // 1 WBTC -> 70k USDC
        router.setEthRate(4_000e18); // 1 ETH  -> 3000 USDC

        // Pairs directos a USDC
        factory.setPair(address(s_dai), address(s_usdc), address(0x111));
        factory.setPair(address(s_wbtc), address(s_usdc), address(0x222));

        // WETH-USDC par para depositEth (no lo usa hasDirectUsdcPair, pero es realista)
        factory.setPair(address(s_weth), address(s_usdc), address(0x333));

        s_clFeed = new MockV3Aggregator(8, INITIAL_ANSWER);

        vm.startPrank(owner);
        bank = new KipuBankV3(
            BANK_CAP, 
            address(router),
            address(s_usdc)
            );

        // Fondos
        s_usdc.mint(user1, USDC_INITIAL_BALANCE); //  USDC.mint(user1, 10_000 * 10 ** 6);
        s_dai.mint(user1, 10_000e18);
        s_wbtc.mint(user1, 2e8);

        s_usdc.mint(user2, USDC_INITIAL_BALANCE);

        // Approvals
        vm.startPrank(user1);
        s_usdc.approve(address(bank), type(uint256).max);
        s_dai.approve(address(bank), type(uint256).max);
        s_wbtc.approve(address(bank), type(uint256).max);
        vm.stopPrank();

        ///@notice Distribuir ether
        vm.deal(user1, ETHER_INITIAL_BALANCE);
        vm.deal(user2, ETHER_INITIAL_BALANCE);


    }
}