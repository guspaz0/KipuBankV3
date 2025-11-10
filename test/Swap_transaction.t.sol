// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import { console } from "forge-std/Test.sol";

import {KipuBankV3BaseTest} from "./helpers/KipuBankV3BaseTest.sol";
import {KipuBankV3} from "src/contracts/KipuBankV3.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockUniswapV2Router02} from "./mocks/MockUniswapV2Router02.sol";

contract TokenTransactionTest is KipuBankV3BaseTest {

    uint256 s_minOut = 1;
    uint256 s_deadline = block.timestamp + 1 hours;

// -------- Constructor / estado inicial --------
    function testInitialState() public {
        assertEq(address(bank.i_router()), address(router));
        assertEq(address(bank.s_usdc()), address(s_usdc));
        assertEq(bank.bankCap(),BANK_CAP);
        assertTrue(bank.WETH() == address(s_weth));
    }

    // -------- hasDirects_usdcPair / helpers --------
    function testHasDirects_usdcPair() public {
        assertTrue(bank.hasDirects_usdcPair(address(s_dai)));
        assertTrue(bank.hasDirects_usdcPair(address(s_wbtc)));
        assertFalse(bank.hasDirects_usdcPair(address(0xDEAD))); // sin par
    }

    function testRemainingCapacity() public {
        assertEq(bank.remainingCapacity(),BANK_CAP);
        vm.prank(user1);
        bank.deposit(address(s_usdc), 1_000e6, s_minOut, s_deadline);
        assertEq(bank.remainingCapacity(),BANK_CAP - 1_000e6);
    }

    // -------- Depósito s_usdc --------
    function testDeposits_usdc_Success_Emits() public {
        uint256 amt = 1_234e6;
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit KipuBankV3.DepositUsdc(user1, amt);
        bank.deposit(address(s_usdc), amt, s_minOut, s_deadline);

        assertEq(bank.balanceOfUsdc(user1), amt);
        assertEq(bank.totalUsdc(), amt);
        assertEq(s_usdc.balanceOf(address(bank)), amt);
    }

    function testDeposits_usdc_Revert_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(KipuBankV3.ZeroAmount.selector);
        bank.deposit(address(s_usdc),0,s_minOut, s_deadline);
    }

    function testDeposit_usdc_Revert_CapExceeded() public {
        vm.prank(user1);
        bank.deposit(address(s_usdc), BANK_CAP - 100e6, s_minOut, s_deadline);
        vm.prank(user1);
        vm.expectRevert(KipuBankV3.BankCapLimitExceeded.selector);
        bank.deposit(address(s_usdc),200e6,s_minOut, s_deadline);
    }

    // -------- Depósito ETH --------
    function testDepositEth_Success_Emits() public {
        uint256 ethIn = 2 ether; // 2 ETH * 3000 = 6000 s_usdc
        uint256 minOut = 5_500e6;

        uint256 s_usdcBefore = s_usdc.balanceOf(address(bank));
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        // user, tokenIn(0), amountIn, s_usdcReceived (match on topics/data)
        emit KipuBankV3.DepositSwapped(user1, address(0), ethIn, 0);
        bank.deposit{value: ethIn}(address(0), ethIn, minOut, block.timestamp + 1 hours);

        uint256 received = s_usdc.balanceOf(address(bank)) - s_usdcBefore;
        assertEq(received, 6_000e6);
        assertEq(bank.balanceOfUsdc(user1), received);
        assertEq(bank.totalUsdc(), received);
    }

    function testDepositEth_Revert_Slippage() public {
        uint256 ethIn = 1 ether; // 3000 s_usdc
        uint256 minOut = 3_500e6; // mayor a lo que da el rate
        vm.prank(user1);
        vm.expectRevert(bytes("slip"));
        bank.deposit{value: ethIn}(address(0), ethIn, minOut, block.timestamp + 1 hours);
    }

    function testDepositEth_Revert_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(KipuBankV3.ZeroAmount.selector);
        bank.deposit{value: 0}(address(0), 0, s_minOut, s_deadline);
    }

    function testDepositEth_Revert_CapExceeded_ByPrecheckOrFinal() public {
        // Llenamos casi todo el BANK_CAP
        vm.prank(user1);
        bank.deposit(address(0), BANK_CAP - 1000, s_minOut, s_deadline);
        // minOut ya superaría el BANK_CAP
        vm.prank(user1);
        vm.expectRevert(KipuBankV3.BankCapLimitExceeded.selector);
        bank.deposit{value: 1 ether}(address(0), 2000, s_minOut, s_deadline);
    }

    // -------- Depósito Token --------
    function testDepositToken_Success_s_dai_1to1() public {
        uint256 s_daiIn = 2_000e18;
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit KipuBankV3.DepositSwapped(user1, address(s_dai), s_daiIn, 0);
        bank.deposit(
            address(s_dai),
            s_daiIn,
            1_900e6,
            block.timestamp + 1 hours
        );

        assertEq(bank.balanceOfUsdc(user1), 2_000e6);
        assertEq(bank.totalUsdc(), 2_000e6);
        assertEq(s_usdc.balanceOf(address(bank)), 2_000e6);
    }

    function testDepositToken_Success_s_wbtc_HighValue() public {
        uint256 s_wbtcIn = 1e8; // 1 s_wbtc
        vm.prank(user1);
        bank.deposit(
            address(s_wbtc),
            s_wbtcIn,
            60_000e6,
            block.timestamp + 1 hours
        );

        assertEq(bank.balanceOfUsdc(user1), 70_000e6);
        assertEq(bank.totalUsdc(), 70_000e6);
    }

    function testDepositToken_Revert_Unsupported_NoPair() public {
        address XYZ = address(0xBEEF);
        // no pair configurado
        vm.prank(user1);
        vm.expectRevert(KipuBankV3.UnsupportedToken.selector);
        bank.deposit(XYZ, 100, 1, block.timestamp + 1 hours);
    }

    function testDepositToken_Revert_Unsupported_Ifs_usdc() public {
        vm.prank(user1);
        vm.expectRevert(KipuBankV3.UnsupportedToken.selector);
        bank.deposit(
            address(s_usdc),
            100e6,
            100e6,
            block.timestamp + 1 hours
        );
    }

    function testDepositToken_Revert_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(KipuBankV3.ZeroAmount.selector);
        bank.deposit(address(s_dai), 0, 0, block.timestamp + 1 hours);
    }

    function testDepositToken_Revert_Slippage() public {
        vm.prank(user1);
        vm.expectRevert(bytes("slip"));
        bank.deposit(
            address(s_dai),
            100e18,
            200e6,
            block.timestamp + 1 hours
        );
    }

    function testDepositToken_Revert_CapExceeded_Precheck() public {
        vm.prank(user1);
        bank.deposit(address(0), BANK_CAP - 1_000e6, s_minOut, s_deadline);
        vm.prank(user1);
        vm.expectRevert(KipuBankV3.BankCapLimitExceeded.selector);
        bank.deposit(
            address(s_dai),
            1_000e18,
            1_000e6,
            block.timestamp + 1 hours
        );
    }

    // -------- Withdraw --------
    function testWithdraws_usdc_Success_Emits() public {
        vm.prank(user1);
        bank.deposit(address(s_usdc),2_000e6, s_minOut, s_deadline);

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit KipuBankV3.WithdrawUsdc(user1, 500e6, 2_000e6-500e6);
        bank.withdraw(500e6);

        assertEq(bank.balanceOfUsdc(user1), 1_500e6);
        assertEq(bank.totalUsdc(), 1_500e6);
        assertEq(s_usdc.balanceOf(user2), 500e6);
    }

    function testWithdraws_usdc_Revert_ZeroAddress() public {
        vm.prank(user1);
        bank.deposit(address(s_usdc), 1_000e6, s_minOut, s_deadline);
        vm.prank(user1);
        vm.expectRevert(KipuBankV3.ZeroAddress.selector);
        bank.withdraw(100e6);
    }

    function testWithdraws_usdc_Revert_ZeroAmount() public {
        vm.prank(user1);
        bank.deposit(address(s_usdc), 1, s_minOut, s_deadline);
        vm.prank(user1);
        vm.expectRevert(KipuBankV3.ZeroAmount.selector);
        bank.withdraw(0);
    }

    function testWithdraws_usdc_Revert_InsufficientBalance() public {
        vm.prank(user1);
        bank.deposit(address(s_usdc), 100e6, s_minOut, s_deadline);
        vm.prank(user1);
        vm.expectRevert(KipuBankV3.InsufficientUserBalance.selector);
        bank.withdraw(200e6);
    }

    function testSetters_OnlyOwner_AndEvents() public {
        // sets_usdc
        MockERC20 NEW_usdc = new MockERC20("ns_usdc", "ns_usdc", 6);
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit KipuBankV3.UsdcUpdated(address(s_usdc), address(NEW_usdc));
        bank.setUsdc(address(NEW_usdc));
        assertEq(address(bank.s_usdc()), address(NEW_usdc));

        // setRouter (cambia factory/WETH indirectamente en prod; aquí solo evento)
        MockUniswapV2Router02 newRouter = new MockUniswapV2Router02(
            address(s_weth)
        );
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit KipuBankV3.RouterUpdated(address(router), address(newRouter));
        bank.setRouter(address(newRouter));
        assertEq(address(bank.i_router()), address(newRouter));

    }

    // -------- Receive() bloqueo --------
    function testReceive_Revert_UseDepositEth() public {
        vm.deal(user2, 1 ether);
        vm.prank(user2);
        (bool ok, ) = address(bank).call{value: 1 ether}("");
        assertFalse(ok, "should revert");
    }
}