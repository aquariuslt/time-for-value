// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { SharesFactoryV1 } from "contracts/core/SharesFactoryV1.sol";
import { BaseTest } from "../BaseTest.t.sol";

contract YieldAggregatorTests is BaseTest {
    uint8 public curveType = 0;
    address public addrAlice = address(1);
    address public addrBob = address(2);
    address public referralReceiver = address(3);
    uint256 public defaultYieldBuffer = 1e12;

    function setUp() public {
        createFactory();
    }

    function test_migrateNewYieldAggregator() public {
        vm.prank(owner);
        vm.expectRevert(bytes("Invalid yieldAggregator"));
        sharesFactory.migrate(address(0));

        vm.prank(owner);
        sharesFactory.migrate(address(aaveYieldAggregator));
    }

    function test_setYieldBuffer() public {
        // TODO: fix below
        _testBuyShares();

        vm.warp(YIELD_CLAIM_TIME);
        uint256 depositedETHAmount = sharesFactory.depositedETHAmount();
        uint256 maxYield = aaveYieldAggregator.yieldMaxClaimable(depositedETHAmount);
        assertEq(depositedETHAmount, 10000227777777775);

        uint256 withdrawableETHAmount = aWETH.balanceOf(address(sharesFactory));
        uint256 yieldBuffer = withdrawableETHAmount - depositedETHAmount - maxYield;
        assertEq(yieldBuffer, defaultYieldBuffer);

        vm.prank(owner);
        aaveYieldAggregator.setYieldBuffer(1e11);
        uint256 maxYieldAfter = aaveYieldAggregator.yieldMaxClaimable(depositedETHAmount);
        assertEq(maxYieldAfter - maxYield, 1e12 - 1e11);
    }

    function _testBuyShares() public {
        uint256 aliceBalBefore = addrAlice.balance;
        uint256 bobBalBefore = addrBob.balance;
        uint256 referrerBalBefore = referralReceiver.balance;
        // uint256 factoryBalBefore = aWETH.balanceOf(address(sharesFactory));
        uint256 depositedETHAmountBefore = sharesFactory.depositedETHAmount();

        vm.deal(addrBob, 10 ether);
        _buyShare(addrBob, 0, 2, referralReceiver);

        uint256 aliceBalAfter = addrAlice.balance;
        uint256 bobBalAfter = addrBob.balance;
        uint256 referrerBalAfter = referralReceiver.balance;
        // uint256 factoryBalAfter = aWETH.balanceOf(address(sharesFactory));
        uint256 depositedETHAmountAfter = sharesFactory.depositedETHAmount();

        assertEq(bobBalBefore - bobBalAfter, 5500450999999993); // Bob buy 1 share
        assertEq(aliceBalAfter - aliceBalBefore, 250020499999999); // Alice receive creator fee
        assertEq(referrerBalAfter - referrerBalBefore, 250020499999999); // referral receive fee
        // assertEq(factoryBalAfter - factoryBalBefore, 5000409999999995); // Factory aWETH balance with rounding error
        assertEq(depositedETHAmountAfter - depositedETHAmountBefore, 5000409999999995); // Factory records ETH Amount

        uint256 bobShareBal = sharesNFT.balanceOf(addrBob, 0);
        assertEq(bobShareBal, 2);
    }

    function _buyShare(address sender, uint256 shareId, uint32 quantity, address referral) internal {
        (uint256 buyPriceAfterFee,,,) = sharesFactory.getBuyPriceAfterFee(shareId, quantity, referral);
        vm.prank(address(sender));
        sharesFactory.buyShare{ value: buyPriceAfterFee }(shareId, quantity, referral);
    }
}
