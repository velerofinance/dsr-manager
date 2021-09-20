pragma solidity >=0.5.12;

import "dss-deploy/DssDeploy.t.base.sol";

import "./DsrManager.sol";

contract DsrManagerTest is DssDeployTestBase {
    DsrManager manager;

    function setUp() public {
        super.setUp();
        deploy();
        manager = new DsrManager(address(pot), address(usdvJoin));

        wvlx.mint(1 ether);
        wvlx.approve(address(vlxJoin), uint(-1));
        vlxJoin.join(address(this), 1 ether);
        vat.frob("VLX", address(this), address(this), address(this), 1 ether, 50 ether);
        vat.hope(address(usdvJoin));
        usdvJoin.exit(address(this), 50 ether);
        usdv.approve(address(manager), 50 ether);
    }

    function test_initial_balances() public {
        assertEq(usdv.balanceOf(address(this)), 50 ether);
        assertEq(pot.pie(address(manager)), 0 ether);
        assertEq(manager.pieOf(address(manager)), 0 ether);
    }


    function test_pot() public {
      assertEq(address(manager.pot()), address(pot));
    }

    function test_usdvJoin() public {
      assertEq(address(manager.usdvJoin()), address(usdvJoin));
    }

    function test_usdv() public {
      assertEq(address(manager.usdv()), address(usdv));
    }

    function testSimpleCase() public {
        this.file(address(pot), "dsr", uint(1.05 * 10 ** 27)); // 5% per second
        uint initialTime = 0; // Initial time set to 0 to avoid any intial rounding
        hevm.warp(initialTime);
        manager.join(address(this), 50 ether);
        assertEq(usdv.balanceOf(address(this)), 0 ether);
        assertEq(pot.pie(address(manager)) * pot.chi(), 50 ether * RAY);
        assertEq(manager.pieOf(address(this)) * pot.chi(), 50 ether * RAY);
        hevm.warp(initialTime + 1); // Moved 1 second
        pot.drip();
        assertEq(pot.pie(address(manager)) * pot.chi(), 52.5 ether * RAY); // Now the equivalent USDV amount is 2.5 USDV extra
        assertEq(manager.pieOf(address(this)) * pot.chi(), 52.5 ether * RAY);
        manager.exit(address(this), 52.5 ether);
        assertEq(usdv.balanceOf(address(this)), 52.5 ether);
        assertEq(pot.pie(address(manager)), 0);
        assertEq(manager.pieOf(address(this)), 0);
    }

    function testJoinOtherUser() public {
        this.file(address(pot), "dsr", uint(1.05 * 10 ** 27)); // 5% per second
        uint initialTime = 0;
        hevm.warp(initialTime);
        manager.join(address(0x1), 50 ether);
        assertEq(usdv.balanceOf(address(this)), 0 ether);
        assertEq(pot.pie(address(manager)) * pot.chi(), 50 ether * RAY);
        assertEq(manager.pieOf(address(0x1)) * pot.chi(), 50 ether * RAY);
    }

    function testExitOtherUser() public {
        this.file(address(pot), "dsr", uint(1.05 * 10 ** 27)); // 5% per second
        uint initialTime = 0;
        hevm.warp(initialTime);
        manager.join(address(this), 50 ether);
        hevm.warp(initialTime + 1);
        pot.drip();
        manager.exit(address(0x1), 52.5 ether);
        assertEq(usdv.balanceOf(address(0x1)), 52.5 ether);
        assertEq(pot.pie(address(manager)), 0);
        assertEq(manager.pieOf(address(this)), 0);
    }

    function testRounding() public {
        this.file(address(pot), "dsr", uint(1.05 * 10 ** 27));
        uint initialTime = 1; // Initial time set to 1 this way some the pie will not be the same than the initial USDV wad amount
        hevm.warp(initialTime);
        manager.join(address(this), 50 ether);
        assertEq(usdv.balanceOf(address(this)), 0 ether);
        // Due rounding the USDV equivalent is not the same than initial wad amount
        assertEq(pot.pie(address(manager)) * pot.chi(), 49999999999999999999350000000000000000000000000);
        assertEq(manager.pieOf(address(this)) * pot.chi(), 49999999999999999999350000000000000000000000000);
        hevm.warp(initialTime + 1);
        pot.drip(); // Just necessary to check in this test the updated value of chi
        assertEq(pot.pie(address(manager)) * pot.chi(), 52499999999999999999317500000000000000000000000);
        assertEq(manager.pieOf(address(this)) * pot.chi(), 52499999999999999999317500000000000000000000000);
        manager.exit(address(this), 52.499999999999999999 ether);
        assertEq(usdv.balanceOf(address(this)), 52.499999999999999999 ether);
        assertEq(pot.pie(address(manager)), 0);
        assertEq(manager.pieOf(address(this)), 0);
    }

    function testRounding2() public {
        this.file(address(pot), "dsr", uint(1.03434234324 * 10 ** 27));
        uint initialTime = 1;
        hevm.warp(initialTime);
        manager.join(address(this), 50 ether);
        assertEq(pot.pie(address(manager)) * pot.chi(), 49999999999999999999993075745400000000000000000);
        assertEq(manager.pieOf(address(this)) * pot.chi(), 49999999999999999999993075745400000000000000000);
        assertEq(vat.usdv(address(manager)), 50 ether * RAY - 49999999999999999999993075745400000000000000000);
        manager.exit(address(this), 49.999999999999999999 ether);
        assertEq(usdv.balanceOf(address(this)), 49.999999999999999999 ether);
    }

    function testExitAll() public {
        this.file(address(pot), "dsr", uint(1.03434234324 * 10 ** 27));
        uint initialTime = 1;
        hevm.warp(initialTime);
        manager.join(address(this), 50 ether);
        manager.exitAll(address(this));
        assertEq(usdv.balanceOf(address(this)), 49.999999999999999999 ether);
    }

    function testExitAllOtherUser() public {
        this.file(address(pot), "dsr", uint(1.03434234324 * 10 ** 27));
        uint initialTime = 1;
        hevm.warp(initialTime);
        manager.join(address(this), 50 ether);
        manager.exitAll(address(0x1));
        assertEq(usdv.balanceOf(address(0x1)), 49.999999999999999999 ether);
    }
}
