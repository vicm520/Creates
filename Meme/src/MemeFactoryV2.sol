// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// 引入 Uniswap 接口
import "v2-periphery/interfaces/IUniswapV2Router02.sol";
// import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./EipTokenCloneable.sol";

/**
 * @title MemeFactoryV2
 * @dev Meme代币发射平台工厂合约，使用最小代理模式部署Meme代币
 */
contract MemeFactoryV2 is Ownable, ReentrancyGuard {
    using Clones for address;

    // Uniswap Router 地址
    IUniswapV2Router02 public immutable uniswapRouter;

    // 模板合约地址
    address public immutable tokenTemplate;
    
    // 平台费用收取地址
    address public platformFeeReceiver;
    
    // 平台费用比例 (1% = 100)
    uint256 public constant PLATFORM_FEE_RATE = 500; // 5%
    uint256 public constant FEE_DENOMINATOR = 10000; // 100%

    // Meme代币信息结构体
    struct MemeInfo {
        address tokenAddress;    // 代币合约地址
        address creator;         // 创建者地址
        string symbol;           // 代币符号
        uint256 totalSupply;     // 总供应量
        uint256 perMint;         // 每次铸造数量
        uint256 price;           // 铸造价格 (wei)
        uint256 currentSupply;   // 当前已铸造数量
        bool isActive;           // 是否激活
        bool liquidityAdded;     // 是否已添加初始流动性
    }

    // 存储所有Meme代币信息
    mapping(address => MemeInfo) public memeInfos;
    
    // 创建者的Meme代币列表
    mapping(address => address[]) public creatorMemes;
    
    // 所有Meme代币地址数组
    address[] public allMemes;

    // 事件定义
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
    

    event InitialLiquidityAdded(address indexed tokenAddress, uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);
    event PlatformFeeReceiverUpdated(address indexed oldReceiver, address indexed newReceiver);

    /**
     * @dev 构造函数
     * @param _tokenTemplate EipTokenCloneable模板合约地址
     * @param _platformFeeReceiver 平台费用接收地址
     */
    constructor(address _tokenTemplate, address _platformFeeReceiver,address _uniswapRouter) Ownable(msg.sender) {
        require(_tokenTemplate != address(0), "MemeFactory: template address cannot be zero");
        require(_platformFeeReceiver != address(0), "MemeFactory: platform fee receiver cannot be zero");
        
        tokenTemplate = _tokenTemplate;
        platformFeeReceiver = _platformFeeReceiver;
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    }

    /**
     * @dev 部署新的Meme代币
     * @param symbol 代币符号
     * @param totalSupply 总供应量 (不包含小数位)
     * @param perMint 每次铸造数量 (不包含小数位)
     * @param price 铸造价格 (wei)
     */
    function deployMeme(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        require(bytes(symbol).length > 0, "MemeFactory: symbol cannot be empty");
        require(totalSupply > 0, "MemeFactory: total supply must be greater than 0");
        require(perMint > 0, "MemeFactory: per mint amount must be greater than 0");
        require(perMint <= totalSupply, "MemeFactory: per mint amount cannot exceed total supply");
        require(price > 0, "MemeFactory: price must be greater than 0");

        // 构造代币名称
        string memory name = string(abi.encodePacked("Meme ", symbol));
        
        // 使用最小代理模式克隆模板合约
        address tokenAddress = Clones.clone(tokenTemplate);
        
        // 初始化克隆合约 (总供应量设为0，通过mint函数铸造)
        EipTokenCloneable(tokenAddress).initialize(name, symbol, 0, address(this));
        
        // 存储Meme信息
        memeInfos[tokenAddress] = MemeInfo({
            tokenAddress: tokenAddress,
            creator: msg.sender,
            symbol: symbol,
            totalSupply: totalSupply * 1e18,
            perMint: perMint * 1e18,
            price: price,
            currentSupply: 0,
            isActive: true,
            liquidityAdded: false
        });
        
        // 添加到创建者列表和全局列表
        creatorMemes[msg.sender].push(tokenAddress);
        allMemes.push(tokenAddress);
        
        emit MemeDeployed(tokenAddress, msg.sender, symbol, totalSupply, perMint, price);
        
        return tokenAddress;
    }

    /**
     * @dev 铸造Meme代币 - 修改版本
     * @param tokenAddr 代币合约地址
     */
    function mintMeme(address tokenAddr) external payable nonReentrant {
        MemeInfo storage meme = memeInfos[tokenAddr];
        require(meme.isActive, "MemeFactory: meme token is not active or does not exist");
        require(msg.value >= meme.price, "MemeFactory: insufficient payment");
        require(meme.currentSupply + meme.perMint <= meme.totalSupply, "MemeFactory: exceeds total supply limit");

        // 计算费用分配 (基于实际价格，不是支付金额)
        uint256 platformFee = (meme.price * PLATFORM_FEE_RATE) / FEE_DENOMINATOR; // 5%给平台
        uint256 creatorFee = meme.price - platformFee; // 95%给创建者

        // 更新当前供应量
        meme.currentSupply += meme.perMint;

        // 铸造代币给购买者
        EipTokenCloneable(tokenAddr).mint(msg.sender, meme.perMint);

        // 退还多余的ETH (先退还，避免余额不足)
        if (msg.value > meme.price) {
            payable(msg.sender).transfer(msg.value - meme.price);
        }

        // 首次添加流动性逻辑
        if (!meme.liquidityAdded) {
            // 使用平台的 platformFee (ETH) 作为向池中注入的 ETH 部分
            uint256 ethForLiquidity = platformFee;
            
            uint256 tokenAmount = (ethForLiquidity * 1e18) / meme.price;

            // mint token 到工厂地址 
            EipTokenCloneable(tokenAddr).mint(address(this), tokenAmount);

            // approve token 给 router
            IERC20(tokenAddr).approve(address(uniswapRouter), tokenAmount);

            // 添加流动性到Uniswap V2池
            (, , uint256 liquidity) = uniswapRouter.addLiquidityETH{value: ethForLiquidity}(
                tokenAddr,
                tokenAmount,
                0,
                0,
                platformFeeReceiver, // 接收流动性的地址
                block.timestamp + 300
            );


            // 标记为已添加流动性
            meme.liquidityAdded = true;

            emit InitialLiquidityAdded(tokenAddr, tokenAmount, ethForLiquidity, liquidity);
        }else{
            // 如果已添加过流动性，则将 platformFee 直接转给平台接收地址
            if (platformFee > 0) {
                payable(platformFeeReceiver).transfer(platformFee);
            }
        }

        // 将创作者收益转给 meme.creator
        if (creatorFee > 0) {
            payable(meme.creator).transfer(creatorFee);
        }

        emit MemeMinted(tokenAddr, msg.sender, meme.perMint, meme.price, platformFee, creatorFee);
    }

    // 以便在 Unswap 的价格优于设定的起始价格时，用户可调用该函数来购买 
    function buyMeme(address tokenAddr, uint256 minTokensOut) external payable nonReentrant {
        require(msg.value > 0, "MemeFactory: send ETH to buy");
        MemeInfo storage meme = memeInfos[tokenAddr];
        require(meme.liquidityAdded, "MemeFactory: liquidity not added yet");

        // 构造路径 WETH -> tokenAddr
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = tokenAddr;

        // 1) 通过 Uniswap 估算 expectedTokens
        uint256[] memory amountsOut = uniswapRouter.getAmountsOut(msg.value, path);
        uint256 expectedTokens = amountsOut[1];

        // 2) 计算在初始价格下 msg.value 能买到的 token 数量
        uint256 tokensAtInitialPrice =  (msg.value * 1e18) / meme.price;


        // 3) 只有当 Uniswap 能买到更多 token 时才允许
        require(expectedTokens > tokensAtInitialPrice, "MemeFactory: Uniswap price not favorable");

        // 4) 执行 Swap，把 token 发送到 buyer
        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            minTokensOut, // slippage 由调用者指定
            path,
            msg.sender,
            block.timestamp + 300
        );
    }

    /**
     * @dev 设置平台费用接收地址 (仅所有者)
     * @param _newReceiver 新的平台费用接收地址
     */
    function setPlatformFeeReceiver(address _newReceiver) external onlyOwner {
        require(_newReceiver != address(0), "MemeFactory: new address cannot be zero");
        address oldReceiver = platformFeeReceiver;
        platformFeeReceiver = _newReceiver;
        emit PlatformFeeReceiverUpdated(oldReceiver, _newReceiver);
    }

    /**
     * @dev 停用Meme代币 (仅创建者或所有者)
     * @param tokenAddr 代币合约地址
     */
    function deactivateMeme(address tokenAddr) external {
        MemeInfo storage meme = memeInfos[tokenAddr];
        require(meme.tokenAddress != address(0), "MemeFactory: meme token does not exist");
        require(msg.sender == meme.creator || msg.sender == owner(), "MemeFactory: unauthorized operation");
        
        meme.isActive = false;
    }

    /**
     * @dev 激活Meme代币 (仅创建者或所有者)
     * @param tokenAddr 代币合约地址
     */
    function activateMeme(address tokenAddr) external {
        MemeInfo storage meme = memeInfos[tokenAddr];
        require(meme.tokenAddress != address(0), "MemeFactory: meme token does not exist");
        require(msg.sender == meme.creator || msg.sender == owner(), "MemeFactory: unauthorized operation");
        
        meme.isActive = true;
    }

    // 查询函数

    /**
     * @dev 获取创建者的所有Meme代币
     * @param creator 创建者地址
     */
    function getCreatorMemes(address creator) external view returns (address[] memory) {
        return creatorMemes[creator];
    }

    /**
     * @dev 获取所有Meme代币数量
     */
    function getAllMemesCount() external view returns (uint256) {
        return allMemes.length;
    }

    /**
     * @dev 获取Meme代币的剩余可铸造数量
     * @param tokenAddr 代币合约地址
     */
    function getRemainingSupply(address tokenAddr) external view returns (uint256) {
        MemeInfo memory meme = memeInfos[tokenAddr];
        if (meme.currentSupply >= meme.totalSupply) {
            return 0;
        }
        return meme.totalSupply - meme.currentSupply;
    }

    /**
     * @dev 检查是否可以铸造指定数量
     * @param tokenAddr 代币合约地址
     * @param amount 铸造数量
     */
    function canMint(address tokenAddr, uint256 amount) external view returns (bool) {
        MemeInfo memory meme = memeInfos[tokenAddr];
        return meme.isActive && (meme.currentSupply + amount <= meme.totalSupply);
    }
}