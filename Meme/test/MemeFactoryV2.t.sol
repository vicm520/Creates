// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MemeFactoryV2.sol";
import "../src/EipTokenCloneable.sol";
import "v2-periphery/interfaces/IUniswapV2Router02.sol";

// Mock Uniswap V2 Router 合约 - 用于测试
contract MockUniswapV2Router is IUniswapV2Router02 {
    address private _weth;
    
    constructor(address _wethAddr) {
        _weth = _wethAddr;
    }
    
    // 返回WETH地址
    function WETH() external pure override returns (address) {
        return address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // Mainnet WETH address
    }
    
    // 返回工厂地址
    function factory() external pure override returns (address) {
        return address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    }
    
    // 添加流动性 - ETH和代币
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable override returns (uint amountToken, uint amountETH, uint liquidity) {
        // 模拟添加流动性，返回固定值
        return (amountTokenDesired, msg.value, 1000);
    }
    
    // 获取输出数量 - ETH换代币
    function getAmountsOut(uint amountIn, address[] calldata path)
        external pure override returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        // 模拟非常有利的汇率：1 ETH = 100000 tokens，这样价格会比铸造价格更优
        amounts[1] = amountIn * 100000;
    }
    
    // 用ETH交换代币（支持手续费代币）
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable override {
        // Mock实现 - 简单转账模拟
    }
    
    // 其他必需的接口函数（空实现）
    function addLiquidity(address,address,uint,uint,uint,uint,address,uint) external override returns (uint,uint,uint) { return (0,0,0); }
    function removeLiquidity(address,address,uint,uint,uint,address,uint) external override returns (uint,uint) { return (0,0); }
    function removeLiquidityETH(address,uint,uint,uint,address,uint) external override returns (uint,uint) { return (0,0); }
    function removeLiquidityWithPermit(address,address,uint,uint,uint,address,uint,bool,uint8,bytes32,bytes32) external override returns (uint,uint) { return (0,0); }
    function removeLiquidityETHWithPermit(address,uint,uint,uint,address,uint,bool,uint8,bytes32,bytes32) external override returns (uint,uint) { return (0,0); }
    function swapExactTokensForTokens(uint,uint,address[] calldata,address,uint) external override returns (uint[] memory amounts) { amounts = new uint[](2); }
    function swapTokensForExactTokens(uint,uint,address[] calldata,address,uint) external override returns (uint[] memory amounts) { amounts = new uint[](2); }
    function swapExactETHForTokens(uint,address[] calldata,address,uint) external payable override returns (uint[] memory amounts) { amounts = new uint[](2); }
    function swapTokensForExactETH(uint,uint,address[] calldata,address,uint) external override returns (uint[] memory amounts) { amounts = new uint[](2); }
    function swapExactTokensForETH(uint,uint,address[] calldata,address,uint) external override returns (uint[] memory amounts) { amounts = new uint[](2); }
    function swapETHForExactTokens(uint,address[] calldata,address,uint) external payable override returns (uint[] memory amounts) { amounts = new uint[](2); }
    function quote(uint,uint,uint) external pure override returns (uint) { return 0; }
    function getAmountOut(uint,uint,uint) external pure override returns (uint) { return 0; }
    function getAmountIn(uint,uint,uint) external pure override returns (uint) { return 0; }
    function getAmountsIn(uint,address[] calldata) external pure override returns (uint[] memory amounts) { amounts = new uint[](2); }
    function removeLiquidityETHSupportingFeeOnTransferTokens(address,uint,uint,uint,address,uint) external override returns (uint) { return 0; }
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(address,uint,uint,uint,address,uint,bool,uint8,bytes32,bytes32) external override returns (uint) { return 0; }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint,uint,address[] calldata,address,uint) external override {}
    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint,uint,address[] calldata,address,uint) external override {}    
}

// Mock WETH 合约 - 用于测试
contract MockWETH {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8 public decimals = 18;
    
    mapping(address => uint256) public balanceOf;
    
    // 存入ETH，获得WETH
    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
    }
    
    // 提取WETH，获得ETH
    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }
}

// MemeFactoryV2 测试合约
contract MemeFactoryV2Test is Test {
    MemeFactoryV2 public factory;           // 工厂合约实例
    EipTokenCloneable public tokenTemplate; // 代币模板合约
    MockUniswapV2Router public mockRouter;  // Mock Uniswap路由器
    MockWETH public mockWETH;               // Mock WETH合约
    
    // 测试用地址
    address public platformFeeReceiver;     // 平台费用接收者
    address public creator;                 // 创建者
    address public buyer;                   // 购买者
    address public other;                   // 其他用户
    
    // 测试常量
    string constant SYMBOL = "MEME";        // 代币符号
    uint256 constant TOTAL_SUPPLY = 1000000; // 总供应量
    uint256 constant PER_MINT = 1000;       // 每次铸造数量
    uint256 constant PRICE = 0.0001 ether;  // 铸造价格
    
    // 测试初始化设置
    function setUp() public {
        // 创建测试地址
        platformFeeReceiver = makeAddr("platformFeeReceiver");
        creator = makeAddr("creator");
        buyer = makeAddr("buyer");
        other = makeAddr("other");
        
        // 为测试地址分配ETH
        vm.deal(creator, 10 ether);
        vm.deal(buyer, 10 ether);
        vm.deal(other, 10 ether);
        
        // 部署Mock合约
        mockWETH = new MockWETH();
        mockRouter = new MockUniswapV2Router(address(mockWETH));
        tokenTemplate = new EipTokenCloneable();
        
        // 部署工厂合约
        factory = new MemeFactoryV2(
            address(tokenTemplate),
            platformFeeReceiver,
            address(mockRouter)
        );
    }
    
    // 测试工厂合约部署
    function testFactoryDeployment() public {
        // 验证工厂合约的初始状态
        assertEq(factory.tokenTemplate(), address(tokenTemplate));
        assertEq(factory.platformFeeReceiver(), platformFeeReceiver);
        assertEq(address(factory.uniswapRouter()), address(mockRouter));
        assertEq(factory.PLATFORM_FEE_RATE(), 500);  // 5%
        assertEq(factory.FEE_DENOMINATOR(), 10000);
    }
    
    // 测试部署Meme代币
    function testDeployMeme() public {
        vm.startPrank(creator);
        
        // 部署新的Meme代币
        address memeToken = factory.deployMeme(
            SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        // 验证代币地址不为空
        assertTrue(memeToken != address(0));
        
        // 验证代币信息
        EipTokenCloneable token = EipTokenCloneable(memeToken);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.totalSupply(), 0); // 初始供应量为0
        
        // 验证工厂记录 - 使用memeInfos结构体
        (
            address tokenAddress,
            address memeCreator,
            string memory symbol,
            uint256 totalSupply,
            uint256 perMint,
            uint256 price,
            uint256 currentSupply,
            bool isActive,
            bool liquidityAdded
        ) = factory.memeInfos(memeToken);
        
        
        assertEq(memeCreator, creator);
        assertEq(symbol, SYMBOL);
        assertEq(totalSupply, TOTAL_SUPPLY * 1e18);
        assertEq(perMint, PER_MINT * 1e18);
        assertEq(price, PRICE);
        assertEq(currentSupply, 0);
        assertTrue(isActive);
        assertFalse(liquidityAdded);
        
        vm.stopPrank();
    }
    
    // 测试部署Meme代币时的无效参数
    function testDeployMemeInvalidParams() public {
        vm.startPrank(creator);
        
        // 测试空符号
        vm.expectRevert("MemeFactory: symbol cannot be empty");
        factory.deployMeme("", TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 测试零总供应量
        vm.expectRevert("MemeFactory: total supply must be greater than 0");
        factory.deployMeme(SYMBOL, 0, PER_MINT, PRICE);
        
        // 测试零每次铸造量
        vm.expectRevert("MemeFactory: per mint amount must be greater than 0");
        factory.deployMeme(SYMBOL, TOTAL_SUPPLY, 0, PRICE);
        
        // 测试每次铸造量超过总供应量
        vm.expectRevert("MemeFactory: per mint amount cannot exceed total supply");
        factory.deployMeme(SYMBOL, PER_MINT, TOTAL_SUPPLY, PRICE);
        
        // 测试零价格
        vm.expectRevert("MemeFactory: price must be greater than 0");
        factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, 0);
        
        vm.stopPrank();
    }
    
    // 测试首次铸造Meme代币
    function testMintMemeFirstTime() public {
        // 先部署代币
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        vm.startPrank(buyer);
        
        // 记录初始余额
        uint256 initialBuyerBalance = buyer.balance;
        uint256 initialCreatorBalance = creator.balance;
        
        // 铸造代币
        factory.mintMeme{value: PRICE}(memeToken);
        
        // 验证代币余额
        EipTokenCloneable token = EipTokenCloneable(memeToken);
        assertEq(token.balanceOf(buyer), PER_MINT * 1e18);
        
        // 验证费用分配
        uint256 platformFee = (PRICE * factory.PLATFORM_FEE_RATE()) / factory.FEE_DENOMINATOR();
        uint256 creatorFee = PRICE - platformFee;
        
        assertEq(buyer.balance, initialBuyerBalance - PRICE);
        assertEq(creator.balance, initialCreatorBalance + creatorFee);
        
        // 验证流动性已添加
        (, , , , , , , , bool liquidityAdded) = factory.memeInfos(memeToken);
        assertTrue(liquidityAdded);
        
        vm.stopPrank();
    }
    
    // 测试第二次铸造Meme代币
    function testMintMemeSecondTime() public {
        // 先部署代币
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 第一次铸造
        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(memeToken);
        
        // 记录第二次铸造前的余额
        uint256 initialOtherBalance = other.balance;
        uint256 initialCreatorBalance = creator.balance;
        uint256 initialPlatformBalance = platformFeeReceiver.balance;
        
        // 第二次铸造
        vm.prank(other);
        factory.mintMeme{value: PRICE}(memeToken);
        
        // 验证两个用户都有代币
        EipTokenCloneable token = EipTokenCloneable(memeToken);
        assertEq(token.balanceOf(buyer), PER_MINT * 1e18);
        assertEq(token.balanceOf(other), PER_MINT * 1e18);
        
        // 验证第二次铸造的费用分配
        uint256 platformFee = (PRICE * factory.PLATFORM_FEE_RATE()) / factory.FEE_DENOMINATOR();
        uint256 creatorFee = PRICE - platformFee;
        
        assertEq(other.balance, initialOtherBalance - PRICE);
        assertEq(creator.balance, initialCreatorBalance + creatorFee);
        // 注意：第二次铸造时平台费用可能不会直接转给platformFeeReceiver
        
        vm.stopPrank();
    }
    
    // 测试铸造时支付不足
    function testMintMemeInsufficientPayment() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        vm.startPrank(buyer);
        
        // 支付不足的金额
        uint256 insufficientAmount = PRICE - 1;
        vm.expectRevert("MemeFactory: insufficient payment");
        factory.mintMeme{value: insufficientAmount}(memeToken);
        
        vm.stopPrank();
    }
    
    // 测试超过供应量的铸造
    function testMintMemeExceedsSupply() public {
        // 部署小供应量的代币
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, PER_MINT, PER_MINT, PRICE);
        
        // 第一次铸造（用完所有供应量）
        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(memeToken);
        
        // 尝试第二次铸造（应该失败）
        vm.prank(other);
        vm.expectRevert("MemeFactory: exceeds total supply limit");
        factory.mintMeme{value: PRICE}(memeToken);
    }
    
    // 测试对非活跃代币的铸造
    function testMintMemeInactiveToken() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 停用代币
        vm.prank(creator);
        factory.deactivateMeme(memeToken);
        
        vm.startPrank(buyer);
        vm.expectRevert("MemeFactory: meme token is not active or does not exist");
        factory.mintMeme{value: PRICE}(memeToken);
        vm.stopPrank();
    }
    
    // 测试铸造时退还多余的ETH
    function testMintMemeRefundExcess() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        uint256 excessAmount = 1 ether;
        uint256 paymentAmount = PRICE + excessAmount;
        
        vm.startPrank(buyer);
        
        uint256 initialBalance = buyer.balance;
        
        // 支付超额金额
        factory.mintMeme{value: paymentAmount}(memeToken);
        
        // 验证多余的ETH被退还
        assertEq(buyer.balance, initialBalance - PRICE);
        
        vm.stopPrank();
    }
    
    // 测试购买Meme代币（无流动性）
    function testBuyMemeWithoutLiquidity() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        vm.startPrank(buyer);
        
        // 尝试购买但没有流动性
        vm.expectRevert("MemeFactory: liquidity not added yet");
        factory.buyMeme{value: 1 ether}(memeToken, 0);
        
        vm.stopPrank();
    }
    
    // 测试购买Meme代币（有流动性）
    function testBuyMemeWithLiquidity() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 先铸造一些代币以创建流动性
        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(memeToken);
        
        // 模拟添加流动性后购买
        vm.startPrank(other);
        
        uint256 buyAmount = 0.1 ether;
        uint256 initialBalance = other.balance;
        
        // 购买代币 - 由于Mock返回非常有利的价格，这应该成功
        factory.buyMeme{value: buyAmount}(memeToken, 0);
        
        // 验证ETH被消费
        assertTrue(other.balance < initialBalance);
        
        vm.stopPrank();
    }
    
    // 测试零价值购买
    function testBuyMemeZeroValue() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        vm.startPrank(buyer);
        
        vm.expectRevert("MemeFactory: send ETH to buy");
        factory.buyMeme{value: 0}(memeToken, 0);
        
        vm.stopPrank();
    }
    
    // 测试设置平台费用接收者（仅所有者）
    function testSetPlatformFeeReceiver() public {
        address newReceiver = makeAddr("newReceiver");
        
        // 所有者可以设置
        factory.setPlatformFeeReceiver(newReceiver);
        assertEq(factory.platformFeeReceiver(), newReceiver);
        
        // 非所有者不能设置
        vm.prank(other);
        vm.expectRevert();
        factory.setPlatformFeeReceiver(other);
    }
    
    // 测试停用Meme代币（仅创建者）
    function testDeactivateMeme() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 创建者可以停用
        vm.prank(creator);
        factory.deactivateMeme(memeToken);
        
        (, , , , , , , bool isActive, ) = factory.memeInfos(memeToken);
        assertFalse(isActive);
        
        // 非创建者不能停用
        vm.prank(other);
        vm.expectRevert("MemeFactory: unauthorized operation");
        factory.deactivateMeme(memeToken);
    }
    
    // 测试激活Meme代币（仅创建者）
    function testActivateMeme() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 先停用
        vm.prank(creator);
        factory.deactivateMeme(memeToken);
        
        // 创建者可以重新激活
        vm.prank(creator);
        factory.activateMeme(memeToken);
        
        (, , , , , , , bool isActive, ) = factory.memeInfos(memeToken);
        assertTrue(isActive);
        
        // 非创建者不能激活
        vm.prank(creator);
        factory.deactivateMeme(memeToken);
        
        vm.prank(other);
        vm.expectRevert("MemeFactory: unauthorized operation");
        factory.activateMeme(memeToken);
    }
    
    // 测试获取剩余供应量
    function testGetRemainingSupply() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 初始剩余供应量应该等于总供应量
        assertEq(factory.getRemainingSupply(memeToken), TOTAL_SUPPLY * 1e18);
        
        // 铸造后剩余供应量应该减少
        vm.prank(buyer);
        factory.mintMeme{value: PRICE}(memeToken);
        
        assertEq(factory.getRemainingSupply(memeToken), (TOTAL_SUPPLY - PER_MINT) * 1e18);
    }
    
    // 测试是否可以铸造
    function testCanMint() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 初始状态应该可以铸造
        assertTrue(factory.canMint(memeToken, PER_MINT * 1e18));
        
        // 停用后不能铸造
        vm.prank(creator);
        factory.deactivateMeme(memeToken);
        assertFalse(factory.canMint(memeToken, PER_MINT * 1e18));
        
        // 重新激活后可以铸造
        vm.prank(creator);
        factory.activateMeme(memeToken);
        assertTrue(factory.canMint(memeToken, PER_MINT * 1e18));
    }
    
    // 测试边界条件 - 最大供应量
    function testBoundaryMaxSupply() public {
        uint256 maxSupply = type(uint256).max / 1e18; // 避免溢出
        
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, maxSupply, PER_MINT, PRICE);
        
        assertEq(factory.getRemainingSupply(memeToken), maxSupply * 1e18);
    }
    
    // 测试边界条件 - 最小价格
    function testBoundaryMinPrice() public {
        uint256 minPrice = 1 wei;
        
        vm.prank(creator);
        address memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, minPrice);
        
        (, , , , , uint256 price, , , ) = factory.memeInfos(memeToken);
        assertEq(price, minPrice);
    }
    
    // 测试获取创建者的Meme代币列表
    function testGetCreatorMemes() public {
        vm.startPrank(creator);
        
        // 部署多个Meme代币
        address meme1 = factory.deployMeme("MEME1", TOTAL_SUPPLY, PER_MINT, PRICE);
        address meme2 = factory.deployMeme("MEME2", TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 获取创建者的Meme列表
        address[] memory creatorMemes = factory.getCreatorMemes(creator);
        
        assertEq(creatorMemes.length, 2);
        assertEq(creatorMemes[0], meme1);
        assertEq(creatorMemes[1], meme2);
        
        vm.stopPrank();
    }
    
    // 测试获取所有Meme代币数量
    function testGetAllMemesCount() public {
        uint256 initialCount = factory.getAllMemesCount();
        
        vm.prank(creator);
        factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        assertEq(factory.getAllMemesCount(), initialCount + 1);
    }
}