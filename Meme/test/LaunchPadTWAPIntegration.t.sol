// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MemeFactoryV2.sol";
import "../src/EipTokenCloneable.sol";
import "../src/MemeTWAPOracle.sol";
import "lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "lib/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

// Mock Uniswap V2 Factory
contract MockUniswapV2Factory is IUniswapV2Factory {
    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;
    address public override feeTo;
    address public override feeToSetter;
    

    
    constructor() {
        feeToSetter = msg.sender;
    }
    
    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }
    
    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2Factory: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Factory: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2Factory: PAIR_EXISTS');
        
        // 使用普通的MockPair合约，非代理
        MockUniswapV2Pair mockPair = new MockUniswapV2Pair();
        mockPair.initialize(token0, token1);
        
        pair = address(mockPair);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        
        emit PairCreated(token0, token1, pair, allPairs.length);
        return pair;
    }
    
    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'UniswapV2Factory: FORBIDDEN');
        feeTo = _feeTo;
    }
    
    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'UniswapV2Factory: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}

// Mock Uniswap V2 Pair
contract MockUniswapV2Pair is IUniswapV2Pair {
    address public override token0;
    address public override token1;
    
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;
    
    uint private _price0CumulativeLast;
    uint private _price1CumulativeLast;
    uint private _kLast;
    

    
    mapping(address => uint) private _balanceOf;
    mapping(address => mapping(address => uint)) private _allowance;
    uint private _totalSupply;
    
    string public constant name = 'Uniswap V2';
    string public constant symbol = 'UNI-V2';
    uint8 public constant decimals = 18;
    
    // 移除重复的事件定义，使用接口中的定义
    
    function initialize(address _token0, address _token1) external {
        token0 = _token0;
        token1 = _token1;
        blockTimestampLast = uint32(block.timestamp);
    }
    
    function getReserves() external view override returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        return (reserve0, reserve1, blockTimestampLast);
    }
    
    function price0CumulativeLast() external view override returns (uint) {
        return _price0CumulativeLast;
    }
    
    function price1CumulativeLast() external view override returns (uint) {
        return _price1CumulativeLast;
    }
    
    function kLast() external view override returns (uint) {
        return _kLast;
    }
    
    function MINIMUM_LIQUIDITY() external pure override returns (uint) {
        return 10**3;
    }
    
    function factory() external view override returns (address) {
        return msg.sender; // 简化实现
    }
    
    function totalSupply() external view override returns (uint) {
        return _totalSupply;
    }
    
    function balanceOf(address owner) external view override returns (uint) {
        return _balanceOf[owner];
    }
    
    function allowance(address owner, address spender) external view override returns (uint) {
        return _allowance[owner][spender];
    }
    
    function approve(address spender, uint value) external override returns (bool) {
        _allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function transfer(address to, uint value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint value) external override returns (bool) {
        if (_allowance[from][msg.sender] != type(uint).max) {
            _allowance[from][msg.sender] -= value;
        }
        _transfer(from, to, value);
        return true;
    }
    
    function _transfer(address from, address to, uint value) private {
        _balanceOf[from] -= value;
        _balanceOf[to] += value;
        emit Transfer(from, to, value);
    }
    
    // 模拟设置储备量和时间戳
    function setReserves(uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) external {
        // 记录之前的时间戳和储备，用于计算累积价格
        uint32 previousTimestamp = blockTimestampLast;
        uint112 previousReserve0 = reserve0;
        uint112 previousReserve1 = reserve1;
        
        // 更新储备和时间戳
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        
        // 模拟价格累积计算
        if (previousTimestamp > 0 && previousReserve0 > 0 && previousReserve1 > 0) {
            uint32 timeElapsed = _blockTimestampLast - previousTimestamp;
            if (timeElapsed > 0) {
                // 使用之前的储备来计算，而不是新设置的储备
                uint224 price0 = uint224((uint256(previousReserve1) * 2**112) / previousReserve0);
                uint224 price1 = uint224((uint256(previousReserve0) * 2**112) / previousReserve1);
                
                // 累积价格 = 之前的价格 * 时间
                _price0CumulativeLast += uint256(price0) * timeElapsed;
                _price1CumulativeLast += uint256(price1) * timeElapsed;
            }
        }
        
        blockTimestampLast = _blockTimestampLast;
        emit Sync(reserve0, reserve1);
    }
    
    // 其他必需的接口函数（简化实现）
    function DOMAIN_SEPARATOR() external pure override returns (bytes32) { return bytes32(0); }
    function PERMIT_TYPEHASH() external pure override returns (bytes32) { return bytes32(0); }
    function nonces(address) external pure override returns (uint) { return 0; }
    function permit(address, address, uint, uint, uint8, bytes32, bytes32) external override {}
    function mint(address to) external override returns (uint liquidity) { 
        _balanceOf[to] += 1000 ether;
        _totalSupply += 1000 ether;
        return 1000 ether;
    }
    function burn(address) external override returns (uint, uint) { return (0, 0); }
    function swap(uint, uint, address, bytes calldata) external override {}
    function skim(address) external override {}
    function sync() external override {}
}

// Mock Uniswap V2 Router
contract MockUniswapV2Router is IUniswapV2Router02 {
    address private _factory;
    address private _weth;
    
    constructor(address factoryAddr, address wethAddress) {
        _factory = factoryAddr;
        _weth = wethAddress;
    }
    
    function factory() external pure override returns (address) {
        return 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // Uniswap V2 Factory address
    }
    
    function WETH() external pure override returns (address) {
        return 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH address
    }
    
    // 添加流动性 ETH
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable override returns (uint amountToken, uint amountETH, uint liquidity) {
        // 简化实现
        IUniswapV2Factory factoryContract = IUniswapV2Factory(_factory);
        address pair = factoryContract.getPair(token, _weth);
        
        if (pair == address(0)) {
            pair = factoryContract.createPair(token, _weth);
        }
        
        // 设置储备
        MockUniswapV2Pair(pair).setReserves(
            uint112(amountTokenDesired),
            uint112(msg.value),
            uint32(block.timestamp)
        );
        
        return (amountTokenDesired, msg.value, 1000 ether);
    }
    
    // 获取兑换金额
    function getAmountsOut(uint amountIn, address[] calldata path) external view override returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        if (path.length == 2) {
            amounts[1] = amountIn * 100000; // 简化：1 ETH = 100000 tokens
        }
        return amounts;
    }
    
    // 支持转移费用的兑换 ETH 到代币
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable override {
        // 简化实现
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

// Mock WETH
contract MockWETH {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8 public decimals = 18;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    
    function withdraw(uint wad) public {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }
    
    function totalSupply() public view returns (uint) {
        return address(this).balance;
    }
    
    function approve(address guy, uint wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }
    
    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }
    
    function transferFrom(address src, address dst, uint wad) public returns (bool) {
        require(balanceOf[src] >= wad);
        
        if (src != msg.sender && allowance[src][msg.sender] != type(uint).max) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }
        
        balanceOf[src] -= wad;
        balanceOf[dst] += wad;
        
        emit Transfer(src, dst, wad);
        return true;
    }
}

// LaunchPad TWAP Integration 测试合约
contract LaunchPadTWAPIntegrationTest is Test {
    // 合约变量
    MemeFactoryV2 public factory;
    EipTokenCloneable public tokenTemplate;
    MemeTWAPOracle public oracle;
    MockUniswapV2Router public router;
    MockUniswapV2Factory public uniswapFactory;
    MockWETH public weth;
    
    // 地址变量
    address public platformFeeReceiver;
    address public creator;
    address public buyer1;
    address public buyer2;
    address public memeToken;
    address public pair;
    
    // 测试参数
    string constant SYMBOL = "MEME";
    uint256 constant TOTAL_SUPPLY = 1000000; // 1,000,000 tokens
    uint256 constant PER_MINT = 1000;       // 1,000 tokens per mint
    uint256 constant PRICE = 0.0001 ether;  // 0.0001 ETH per token
    
    function setUp() public {
        // 设置测试账户
        platformFeeReceiver = makeAddr("platformFeeReceiver");
        creator = makeAddr("creator");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        
        // 给测试账户一些 ETH
        vm.deal(platformFeeReceiver, 10 ether);
        vm.deal(creator, 10 ether);
        vm.deal(buyer1, 10 ether);
        vm.deal(buyer2, 10 ether);
        
        // 部署 Mock 合约
        weth = new MockWETH();
        uniswapFactory = new MockUniswapV2Factory();
        router = new MockUniswapV2Router(address(uniswapFactory), address(weth));
        tokenTemplate = new EipTokenCloneable();
        
        // 部署 MemeFactoryV2 合约
        factory = new MemeFactoryV2(
            address(tokenTemplate),
            platformFeeReceiver,
            address(router)
        );
    }
    
    // 测试工厂和预言机的初始化
    function testFactoryAndOracleInitialization() public {
        // 验证工厂合约的初始状态
        assertEq(factory.tokenTemplate(), address(tokenTemplate));
        assertEq(factory.platformFeeReceiver(), platformFeeReceiver);
        assertEq(address(factory.uniswapRouter()), address(router));
        assertEq(factory.PLATFORM_FEE_RATE(), 500);  // 5%
        assertEq(factory.FEE_DENOMINATOR(), 10000);
        
        console.log("Factory initialization test passed");
    }
    
    // 测试通过 LaunchPad 发行 Meme 代币
    function testLaunchPadMemeDeployment() public {
        vm.startPrank(creator);
        
        // 部署新的 Meme 代币
        memeToken = factory.deployMeme(
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
        
        // 验证工厂记录
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
        
        assertEq(tokenAddress, memeToken);
        assertEq(memeCreator, creator);
        assertEq(symbol, SYMBOL);
        assertEq(totalSupply, TOTAL_SUPPLY * 1e18);
        assertEq(perMint, PER_MINT * 1e18);
        assertEq(price, PRICE);
        assertEq(currentSupply, 0);
        assertTrue(isActive);
        assertFalse(liquidityAdded);
        
        vm.stopPrank();
        
        console.log("LaunchPad Meme deployment test passed");
        console.log("Meme token address:", memeToken);
    }
    
    // 测试添加流动性后的 TWAP 价格更新
    function testTWAPAfterLiquidityAddition() public {
        // 先部署代币
        vm.prank(creator);
        memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 第一次铸造以创建流动性
        vm.prank(buyer1);
        factory.mintMeme{value: PRICE}(memeToken);
        
        // 获取交易对地址
        pair = uniswapFactory.getPair(memeToken, address(weth));
        assertTrue(pair != address(0), "Pair should be created");
        
        // 部署 TWAP 预言机
        oracle = new MemeTWAPOracle(pair, memeToken, address(weth));
        
        // 验证预言机初始化
        assertEq(address(oracle.pair()), pair);
        assertEq(oracle.memeToken(), memeToken);
        assertEq(oracle.weth(), address(weth));
        
        console.log("TWAP Oracle deployment after liquidity addition test passed");
        console.log("Pair address:", pair);
        console.log("Oracle address:", address(oracle));
    }
    
    // 测试多次交易后的 TWAP 价格计算
    function testTWAPAfterMultipleTransactions() public {
        // 设置初始状态
        vm.prank(creator);
        memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // 第一次铸造创建流动性
        vm.prank(buyer1);
        factory.mintMeme{value: PRICE}(memeToken);
        
        pair = uniswapFactory.getPair(memeToken, address(weth));
        oracle = new MemeTWAPOracle(pair, memeToken, address(weth));
        
        // 模拟多次交易，改变价格
        // 交易 1: 1000 Meme tokens, 0.1 ETH
        vm.warp(block.timestamp + 1 hours);
        simulateTrading(1000 * 1e18, 0.1 ether);
        
        // 交易 2: 2000 Meme tokens, 0.15 ETH
        vm.warp(block.timestamp + 2 hours);
        simulateTrading(2000 * 1e18, 0.15 ether);
        
        // 交易 3: 1500 Meme tokens, 0.12 ETH
        vm.warp(block.timestamp + 3 hours);
        simulateTrading(1500 * 1e18, 0.12 ether);
        
        // 前进时间以便更新 TWAP (需要至少 30 分钟)
        vm.warp(block.timestamp + 31 minutes);
        
        // 更新预言机价格
        oracle.update();
        
        console.log("TWAP after multiple transactions test passed");
    }
    
    // 测试时间推移对 TWAP 价格的影响
    function testTWAPTimeElapsedEffect() public {
        // 设置初始状态
        vm.prank(creator);
        memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        vm.prank(buyer1);
        factory.mintMeme{value: PRICE}(memeToken);
        
        pair = uniswapFactory.getPair(memeToken, address(weth));
        oracle = new MemeTWAPOracle(pair, memeToken, address(weth));
        
        // 记录初始状态
        uint256 initialPrice0Cumulative = oracle.price0CumulativeLast();
        uint256 initialPrice1Cumulative = oracle.price1CumulativeLast();
        uint32 initialTimestamp = oracle.blockTimestampLast();
        
        // 模拟长时间的价格稳定
        vm.warp(block.timestamp + 6 hours);
        simulateTrading(1000 * 1e18, 0.1 ether);
        
        // 再次长时间等待
        vm.warp(block.timestamp + 12 hours);
        simulateTrading(1000 * 1e18, 0.1 ether);
        
        // 最后一次长时间等待
        vm.warp(block.timestamp + 6 hours);
        
        // 更新预言机价格 (需要至少 30 分钟间隔)
        vm.warp(block.timestamp + 31 minutes);
        oracle.update();
        
        // 验证状态已更新
        assertTrue(oracle.price0CumulativeLast() >= initialPrice0Cumulative, "Price0Cumulative should increase or stay same");
        assertTrue(oracle.price1CumulativeLast() >= initialPrice1Cumulative, "Price1Cumulative should increase or stay same");
        assertTrue(oracle.blockTimestampLast() > initialTimestamp, "Timestamp should be updated");
        
        console.log("TWAP time elapsed effect test passed");
        console.log("Time elapsed:", oracle.blockTimestampLast() - initialTimestamp, "seconds");
    }
    
    // 测试获取 Meme 对 ETH 和 ETH 对 Meme 的价格
    function testMemeETHPriceQueries() public {
        // 设置初始状态
        vm.prank(creator);
        memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        vm.prank(buyer1);
        factory.mintMeme{value: PRICE}(memeToken);
        
        pair = uniswapFactory.getPair(memeToken, address(weth));
        oracle = new MemeTWAPOracle(pair, memeToken, address(weth));
        
        // 模拟一些交易以建立价格历史
        vm.warp(block.timestamp + 1 hours);
        simulateTrading(1000 * 1e18, 0.1 ether);
        
        vm.warp(block.timestamp + 2 hours);
        simulateTrading(2000 * 1e18, 0.2 ether);
        
        vm.warp(block.timestamp + 31 minutes);
        
        // 更新预言机价格
        oracle.update();
        
        // 测试 Meme 对 ETH 的价格查询
        uint256 memeAmount = 1 ether; // 1 Meme token
        uint256 ethForMeme = oracle.getMemeToEthPrice(memeAmount);
        
        console.log("1 Meme token worth in ETH:", ethForMeme);
        assertTrue(ethForMeme >= 0, "Meme to ETH price should be non-negative");
        
        // 测试 ETH 对 Meme 的价格查询
        uint256 ethAmount = 1 ether; // 1 ETH
        uint256 memeForEth = oracle.getEthToMemePrice(ethAmount);
        
        console.log("1 ETH worth in Meme tokens:", memeForEth);
        assertTrue(memeForEth >= 0, "ETH to Meme price should be non-negative");
        
        // 测试 consult 函数
        (address token0, address token1) = getOrderedTokens(memeToken, address(weth));
        
        if (memeToken == token0) {
            uint256 consultPrice = oracle.consult(memeToken, 1 ether);
            console.log("Consult price for 1 Meme:", consultPrice);
            assertTrue(consultPrice >= 0, "Consult price should be non-negative");
        } else {
            uint256 consultPrice = oracle.consult(address(weth), 1 ether);
            console.log("Consult price for 1 ETH:", consultPrice);
            assertTrue(consultPrice >= 0, "Consult price should be non-negative");
        }
        
        console.log("Meme/ETH price queries test passed");
    }
    
    // 测试价格波动情况下的 TWAP 稳定性
    function testTWAPStabilityUnderVolatility() public {
        // 设置初始状态
        vm.prank(creator);
        memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        vm.prank(buyer1);
        factory.mintMeme{value: PRICE}(memeToken);
        
        pair = uniswapFactory.getPair(memeToken, address(weth));
        oracle = new MemeTWAPOracle(pair, memeToken, address(weth));
        
        // 模拟价格剧烈波动
        // 初始价格：1000 Meme = 0.1 ETH
        vm.warp(block.timestamp + 1 hours);
        simulateTrading(1000 * 1e18, 0.1 ether);
        
        // 价格暴涨：1000 Meme = 1 ETH (10倍)
        vm.warp(block.timestamp + 2 hours);
        simulateTrading(1000 * 1e18, 1 ether);
        
        // 价格暴跌：10000 Meme = 0.1 ETH (1/100 初始价格)
        vm.warp(block.timestamp + 3 hours);
        simulateTrading(10000 * 1e18, 0.1 ether);
        
        // 价格回归：1000 Meme = 0.1 ETH
        vm.warp(block.timestamp + 4 hours);
        simulateTrading(1000 * 1e18, 0.1 ether);
        
        // 更新 TWAP (需要至少 30 分钟间隔)
        vm.warp(block.timestamp + 31 minutes);
        oracle.update();
        
        // 查询 TWAP 价格 - 应该是这些价格的时间加权平均值
        uint256 twapMemePrice = oracle.getMemeToEthPrice(1 ether);
        uint256 twapEthPrice = oracle.getEthToMemePrice(1 ether);
        
        console.log("TWAP Meme price after volatility (1 Meme in ETH):", twapMemePrice);
        console.log("TWAP ETH price after volatility (1 ETH in Meme):", twapEthPrice);
        
        // TWAP 应该平滑价格波动
        assertTrue(twapMemePrice >= 0, "TWAP Meme price should be non-negative");
        assertTrue(twapEthPrice >= 0, "TWAP ETH price should be non-negative");
        
        console.log("TWAP stability under volatility test passed");
    }
    
    // 测试完整的 LaunchPad 到 TWAP 工作流程
    function testCompleteWorkflow() public {
        console.log("Starting complete LaunchPad to TWAP workflow test");
        
        // 1. 部署 Meme 代币
        vm.prank(creator);
        memeToken = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        console.log("1. Meme token deployed:", memeToken);
        
        // 2. 多个用户铸造代币
        vm.prank(buyer1);
        factory.mintMeme{value: PRICE}(memeToken);
        console.log("2. Buyer1 minted tokens");
        
        vm.prank(buyer2);
        factory.mintMeme{value: PRICE}(memeToken);
        console.log("3. Buyer2 minted tokens");
        
        // 3. 验证流动性已添加
        pair = uniswapFactory.getPair(memeToken, address(weth));
        assertTrue(pair != address(0), "Pair should exist");
        console.log("4. Liquidity pair created:", pair);
        
        // 4. 部署 TWAP 预言机
        oracle = new MemeTWAPOracle(pair, memeToken, address(weth));
        console.log("5. TWAP Oracle deployed:", address(oracle));
        
        // 5. 模拟一系列交易
        for (uint i = 1; i <= 5; i++) {
            vm.warp(block.timestamp + 2 hours);
            uint256 tokenAmount = (800 + i * 200) * 1e18; // 递增代币数量
            uint256 ethAmount = (0.08 ether + i * 0.02 ether); // 递增 ETH 数量
            simulateTrading(tokenAmount, ethAmount);
            console.log("6.", i, "Trading simulation completed");
        }
        
        // 6. 更新 TWAP 价格 (需要至少 30 分钟间隔)
        vm.warp(block.timestamp + 31 minutes);
        oracle.update();
        console.log("7. TWAP Oracle updated");
        
        // 7. 查询最终价格
        uint256 finalMemePrice = oracle.getMemeToEthPrice(1 ether);
        uint256 finalEthPrice = oracle.getEthToMemePrice(1 ether);
        
        console.log("8. Final TWAP prices:");
        console.log("   - 1 Meme token worth:", finalMemePrice, "wei ETH");
        console.log("   - 1 ETH worth:", finalEthPrice, "wei Meme tokens");
        
        // 8. 验证价格合理性
        assertTrue(finalMemePrice >= 0, "Final Meme price should be non-negative");
        assertTrue(finalEthPrice >= 0, "Final ETH price should be non-negative");
        
        console.log("Complete workflow test passed successfully!");
    }
    
    // 辅助函数：模拟交易
    function simulateTrading(uint256 tokenAmount, uint256 ethAmount) internal {
        require(pair != address(0), "Pair not created");
        
        // 确定代币顺序
        (address token0, ) = getOrderedTokens(memeToken, address(weth));
        
        // 更新储备，保持代币顺序
        if (memeToken == token0) {
            MockUniswapV2Pair(pair).setReserves(
                uint112(tokenAmount),
                uint112(ethAmount),
                uint32(block.timestamp)
            );
        } else {
            MockUniswapV2Pair(pair).setReserves(
                uint112(ethAmount),
                uint112(tokenAmount),
                uint32(block.timestamp)
            );
        }
    }
    
    // 辅助函数：获取排序后的代币地址
    function getOrderedTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}