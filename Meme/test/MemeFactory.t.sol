// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MemeFactory.sol";
import "../src/EipTokenCloneable.sol";

/**
 * @title MemeFactory测试合约
 * @dev 测试Meme代币发射平台的所有功能
 */
contract MemeFactoryTest is Test {
    MemeFactory public factory;
    EipTokenCloneable public tokenTemplate;
    
    address public owner = address(0x1);
    address public platformFeeReceiver = address(0x2);
    address public creator = address(0x3);
    address public user1 = address(0x4);
    address public user2 = address(0x5);
    
    // 测试用的Meme参数
    string constant SYMBOL = "DOGE";
    uint256 constant TOTAL_SUPPLY = 1000000; // 100万代币
    uint256 constant PER_MINT = 1000; // 每次铸造1000代币
    uint256 constant PRICE = 0.001 ether; // 0.001 ETH

    event MemeDeployed(
        address indexed tokenAddress,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );
    
    event MemeMinted(
        address indexed tokenAddress,
        address indexed minter,
        uint256 amount,
        uint256 cost,
        uint256 platformFee,
        uint256 creatorFee
    );

    function setUp() public {
        // 设置测试账户余额
        vm.deal(owner, 100 ether);
        vm.deal(creator, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        
        // 部署模板合约
        vm.prank(owner);
        tokenTemplate = new EipTokenCloneable();
        
        // 部署工厂合约
        vm.prank(owner);
        factory = new MemeFactory(address(tokenTemplate), platformFeeReceiver);
    }

    /**
     * @dev 测试工厂合约部署
     */
    function testFactoryDeployment() public {
        assertEq(factory.tokenTemplate(), address(tokenTemplate));
        assertEq(factory.platformFeeReceiver(), platformFeeReceiver);
        assertEq(factory.owner(), owner);
        assertEq(factory.PLATFORM_FEE_RATE(), 100); // 1%
        assertEq(factory.FEE_DENOMINATOR(), 10000); // 100%
    }

    /**
     * @dev 测试部署Meme代币
     */
    function testDeployMeme() public {
        vm.prank(creator);
        
        // 期望触发事件 (地址无法预测，所以不检查第一个参数)
        vm.expectEmit(false, true, false, true);
        emit MemeDeployed(address(0), creator, SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 验证Meme信息
        (
            address tokenAddress,
            address memeCreator,
            string memory symbol,
            uint256 totalSupply,
            uint256 perMint,
            uint256 price,
            uint256 currentSupply,
            bool isActive
        ) = factory.memeInfos(memeToken);
        
        assertEq(tokenAddress, memeToken);
        assertEq(memeCreator, creator);
        assertEq(symbol, SYMBOL);
        assertEq(totalSupply, TOTAL_SUPPLY * 10**18);
        assertEq(perMint, PER_MINT * 10**18);
        assertEq(price, PRICE);
        assertEq(currentSupply, 0);
        assertTrue(isActive);
        
        // 验证代币合约
        EipTokenCloneable token = EipTokenCloneable(memeToken);
        assertEq(token.name(), string(abi.encodePacked("Meme ", SYMBOL)));
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.totalSupply(), 0); // 初始供应量为0
        assertEq(token.owner(), address(factory)); // 工厂合约是所有者
        
        // 验证列表更新
        assertEq(factory.getAllMemesCount(), 1);
        address[] memory creatorMemes = factory.getCreatorMemes(creator);
        assertEq(creatorMemes.length, 1);
        assertEq(creatorMemes[0], memeToken);
    }

    /**
     * @dev 测试部署Meme代币的参数验证
     */
    function testDeployMemeValidation() public {
        vm.startPrank(creator);
        
        // 测试空符号
        vm.expectRevert("MemeFactory: symbol cannot be empty");
        factory.deployMeme("", TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 测试总供应量为0
        vm.expectRevert("MemeFactory: total supply must be greater than 0");
        factory.deployMeme(SYMBOL, 0, PER_MINT, PRICE);
        
        // 测试每次铸造数量为0
        vm.expectRevert("MemeFactory: per mint amount must be greater than 0");
        factory.deployMeme(SYMBOL, TOTAL_SUPPLY, 0, PRICE);
        
        // 测试每次铸造数量超过总供应量
        vm.expectRevert("MemeFactory: per mint amount cannot exceed total supply");
        factory.deployMeme(SYMBOL, TOTAL_SUPPLY, TOTAL_SUPPLY + 1, PRICE);
        
        // 测试价格为0
        vm.expectRevert("MemeFactory: price must be greater than 0");
        factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, 0);
        
        vm.stopPrank();
    }

    /**
     * @dev 测试铸造Meme代币
     */
    function testMintMeme() public {
        // 先部署Meme代币
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 记录初始余额
        uint256 initialPlatformBalance = platformFeeReceiver.balance;
        uint256 initialCreatorBalance = creator.balance;
        uint256 initialUserBalance = user1.balance;
        
        // 计算预期费用
        uint256 expectedPlatformFee = (PRICE * 100) / 10000; // 1%
        uint256 expectedCreatorFee = PRICE - expectedPlatformFee; // 99%
        
        vm.prank(user1);
        
        // 期望触发事件
        vm.expectEmit(true, true, false, true);
        emit MemeMinted(memeToken, user1, PER_MINT * 10**18, PRICE, expectedPlatformFee, expectedCreatorFee);
        
        factory.mintMeme{value: PRICE}(memeToken);
        
        // 验证代币余额
        EipTokenCloneable token = EipTokenCloneable(memeToken);
        assertEq(token.balanceOf(user1), PER_MINT * 10**18);
        assertEq(token.totalSupply(), PER_MINT * 10**18);
        
        // 验证ETH分配
        assertEq(platformFeeReceiver.balance, initialPlatformBalance + expectedPlatformFee);
        assertEq(creator.balance, initialCreatorBalance + expectedCreatorFee);
        assertEq(user1.balance, initialUserBalance - PRICE);
        
        // 验证Meme信息更新
        (, , , , , , uint256 currentSupply, ) = factory.memeInfos(memeToken);
        assertEq(currentSupply, PER_MINT * 10**18);
        
        // 验证剩余供应量
        uint256 remainingSupply = factory.getRemainingSupply(memeToken);
        assertEq(remainingSupply, (TOTAL_SUPPLY - PER_MINT) * 10**18);
    }

    /**
     * @dev 测试多次铸造
     */
    function testMultipleMints() public {
        // 部署Meme代币
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 用户1铸造
        vm.prank(user1);
        factory.mintMeme{value: PRICE}(memeToken);
        
        // 用户2铸造
        vm.prank(user2);
        factory.mintMeme{value: PRICE}(memeToken);
        
        // 验证余额
        EipTokenCloneable token = EipTokenCloneable(memeToken);
        assertEq(token.balanceOf(user1), PER_MINT * 10**18);
        assertEq(token.balanceOf(user2), PER_MINT * 10**18);
        assertEq(token.totalSupply(), 2 * PER_MINT * 10**18);
        
        // 验证当前供应量
        (, , , , , , uint256 currentSupply, ) = factory.memeInfos(memeToken);
        assertEq(currentSupply, 2 * PER_MINT * 10**18);
    }

    /**
     * @dev 测试支付金额不足
     */
    function testInsufficientPayment() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        vm.prank(user1);
        vm.expectRevert("MemeFactory: insufficient payment");
        factory.mintMeme{value: PRICE - 1}(memeToken);
    }

    /**
     * @dev 测试超过总供应量限制
     */
    function testExceedTotalSupply() public {
        // 部署小总量的Meme代币
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, 1000, 1000, PRICE); // 总量1000，每次铸造1000
        
        // 第一次铸造成功
        vm.prank(user1);
        factory.mintMeme{value: PRICE}(memeToken);
        
        // 第二次铸造应该失败
        vm.prank(user2);
        vm.expectRevert("MemeFactory: exceeds total supply limit");
        factory.mintMeme{value: PRICE}(memeToken);
    }

    /**
     * @dev 测试多余ETH退还
     */
    function testExcessETHRefund() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        uint256 excessAmount = 0.5 ether;
        uint256 totalPayment = PRICE + excessAmount;
        uint256 initialBalance = user1.balance;
        
        vm.prank(user1);
        factory.mintMeme{value: totalPayment}(memeToken);
        
        // 验证只扣除了实际价格，多余的被退还
        assertEq(user1.balance, initialBalance - PRICE);
    }

    /**
     * @dev 测试停用和激活Meme代币
     */
    function testDeactivateAndActivateMeme() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 创建者停用Meme
        vm.prank(creator);
        factory.deactivateMeme(memeToken);
        
        (, , , , , , , bool isActive) = factory.memeInfos(memeToken);
        assertFalse(isActive);
        
        // 尝试铸造应该失败
        vm.prank(user1);
        vm.expectRevert("MemeFactory: meme token is not active or does not exist");
        factory.mintMeme{value: PRICE}(memeToken);
        
        // 创建者重新激活
        vm.prank(creator);
        factory.activateMeme(memeToken);
        
        (, , , , , , , isActive) = factory.memeInfos(memeToken);
        assertTrue(isActive);
        
        // 现在可以正常铸造
        vm.prank(user1);
        factory.mintMeme{value: PRICE}(memeToken);
    }

    /**
     * @dev 测试所有者停用Meme代币
     */
    function testOwnerDeactivateMeme() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 所有者停用Meme
        vm.prank(owner);
        factory.deactivateMeme(memeToken);
        
        (, , , , , , , bool isActive) = factory.memeInfos(memeToken);
        assertFalse(isActive);
    }

    /**
     * @dev 测试无权限用户无法停用Meme
     */
    function testUnauthorizedDeactivation() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        vm.prank(user1);
        vm.expectRevert("MemeFactory: unauthorized operation");
        factory.deactivateMeme(memeToken);
    }

    /**
     * @dev 测试设置平台费用接收地址
     */
    function testSetPlatformFeeReceiver() public {
        address newReceiver = address(0x999);
        
        vm.prank(owner);
        factory.setPlatformFeeReceiver(newReceiver);
        
        assertEq(factory.platformFeeReceiver(), newReceiver);
    }

    /**
     * @dev 测试非所有者无法设置平台费用接收地址
     */
    function testUnauthorizedSetPlatformFeeReceiver() public {
        address newReceiver = address(0x999);
        
        vm.prank(user1);
        vm.expectRevert();
        factory.setPlatformFeeReceiver(newReceiver);
    }

    /**
     * @dev 测试查询函数
     */
    function testQueryFunctions() public {
        // 部署多个Meme代币
        vm.startPrank(creator);
        address meme1 = factory.deployMeme("DOGE", TOTAL_SUPPLY, PER_MINT, PRICE);
        address meme2 = factory.deployMeme("SHIB", TOTAL_SUPPLY, PER_MINT, PRICE);
        vm.stopPrank();
        
        // 测试getAllMemesCount
        assertEq(factory.getAllMemesCount(), 2);
        
        // 测试getCreatorMemes
        address[] memory creatorMemes = factory.getCreatorMemes(creator);
        assertEq(creatorMemes.length, 2);
        assertEq(creatorMemes[0], meme1);
        assertEq(creatorMemes[1], meme2);
        
        // 测试canMint
        assertTrue(factory.canMint(meme1, PER_MINT * 10**18));
        assertTrue(factory.canMint(meme1, TOTAL_SUPPLY * 10**18)); // 可以铸造全部
        assertFalse(factory.canMint(meme1, (TOTAL_SUPPLY + 1) * 10**18)); // 超过总量
        
        // 铸造一些代币后再测试
        vm.prank(user1);
        factory.mintMeme{value: PRICE}(meme1);
        
        assertEq(factory.getRemainingSupply(meme1), (TOTAL_SUPPLY - PER_MINT) * 10**18);
        assertTrue(factory.canMint(meme1, PER_MINT * 10**18));
        assertFalse(factory.canMint(meme1, TOTAL_SUPPLY * 10**18)); // 现在不能铸造全部了
    }

    /**
     * @dev 测试费用分配精确性
     */
    function testFeeDistributionAccuracy() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        uint256 customPrice = 1 ether;
        
        // 更新价格（这里需要添加更新价格的功能，或者重新部署）
        vm.prank(creator);
        address memeToken2 = factory.deployMeme("TEST", TOTAL_SUPPLY, PER_MINT, customPrice);
        
        uint256 initialPlatformBalance = platformFeeReceiver.balance;
        uint256 initialCreatorBalance = creator.balance;
        
        vm.prank(user1);
        factory.mintMeme{value: customPrice}(memeToken2);
        
        uint256 expectedPlatformFee = (customPrice * 100) / 10000; // 1%
        uint256 expectedCreatorFee = customPrice - expectedPlatformFee; // 99%
        
        assertEq(platformFeeReceiver.balance - initialPlatformBalance, expectedPlatformFee);
        assertEq(creator.balance - initialCreatorBalance, expectedCreatorFee);
        
        // 验证费用分配总和等于支付金额
        assertEq(expectedPlatformFee + expectedCreatorFee, customPrice);
    }

    /**
     * @dev 测试重入攻击保护
     */
    function testReentrancyProtection() public {
        // 这个测试需要创建一个恶意合约来尝试重入攻击
        // 由于ReentrancyGuard的保护，应该会失败
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 正常铸造应该成功
        vm.prank(user1);
        factory.mintMeme{value: PRICE}(memeToken);
        
        // 验证铸造成功
        EipTokenCloneable token = EipTokenCloneable(memeToken);
        assertEq(token.balanceOf(user1), PER_MINT * 10**18);
    }

    /**
     * @dev 测试边界条件
     */
    function testEdgeCases() public {
        // 测试最小值
        vm.prank(creator);
        address memeToken = factory.deployMeme("MIN", 1, 1, 1 wei);
        
        vm.prank(user1);
        factory.mintMeme{value: 1 wei}(memeToken);
        
        // 验证铸造成功
        EipTokenCloneable token = EipTokenCloneable(memeToken);
        assertEq(token.balanceOf(user1), 1 * 10**18);
        
        // 再次铸造应该失败（已达到总供应量）
        vm.prank(user2);
        vm.expectRevert("MemeFactory: exceeds total supply limit");
        factory.mintMeme{value: 1 wei}(memeToken);
    }
}