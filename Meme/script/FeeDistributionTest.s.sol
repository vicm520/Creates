// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/EipTokenCloneable.sol";
import "../src/MemeFactory.sol";

contract FeeDistributionTestScript is Script {
    // Anvil预设账号
    address constant PLATFORM_RECEIVER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // 账号0 - 平台费用接收者
    address constant MEME_CREATOR = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;      // 账号1 - Meme创建者
    address constant TOKEN_BUYER = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;       // 账号2 - 代币购买者
    
    // 对应的私钥
    uint256 constant PLATFORM_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 constant CREATOR_PRIVATE_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 constant BUYER_PRIVATE_KEY = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    
    function run() external {
        // 使用已部署的合约地址
        address factoryAddress = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
        MemeFactory factory = MemeFactory(factoryAddress);
        
        console.log("=== Multi-Account Fee Distribution Test ===");
        console.log("Factory Address:", factoryAddress);
        console.log("Platform Receiver:", PLATFORM_RECEIVER);
        console.log("Meme Creator:", MEME_CREATOR);
        console.log("Token Buyer:", TOKEN_BUYER);
        
        // 记录初始余额
        uint256 platformInitialBalance = PLATFORM_RECEIVER.balance;
        uint256 creatorInitialBalance = MEME_CREATOR.balance;
        uint256 buyerInitialBalance = TOKEN_BUYER.balance;
        
        console.log("\n=== Initial Balances ===");
        console.log("Platform balance:", platformInitialBalance);
        console.log("Creator balance:", creatorInitialBalance);
        console.log("Buyer balance:", buyerInitialBalance);
        
        // 步骤1: 创建者部署Meme代币
        console.log("\n=== Step 1: Creator deploys Meme token ===");
        vm.startBroadcast(CREATOR_PRIVATE_KEY);
        
        address memeToken = factory.deployMeme("DOGE", 1000000, 1000, 0.001 ether);
        console.log("Meme token deployed at:", memeToken);
        
        vm.stopBroadcast();
        
        // 验证创建者
        (, address creator, , , , , , ) = factory.memeInfos(memeToken);
        console.log("Verified creator:", creator);
        require(creator == MEME_CREATOR, "Creator mismatch");
        
        // 步骤2: 购买者铸造代币
        console.log("\n=== Step 2: Buyer mints tokens ===");
        vm.startBroadcast(BUYER_PRIVATE_KEY);
        
        console.log("Buyer balance before mint:", TOKEN_BUYER.balance);
        console.log("Buyer token balance before:", EipTokenCloneable(memeToken).balanceOf(TOKEN_BUYER));
        
        factory.mintMeme{value: 0.001 ether}(memeToken);
        
        console.log("Buyer balance after mint:", TOKEN_BUYER.balance);
        console.log("Buyer token balance after:", EipTokenCloneable(memeToken).balanceOf(TOKEN_BUYER));
        
        vm.stopBroadcast();
        
        // 记录最终余额
        uint256 platformFinalBalance = PLATFORM_RECEIVER.balance;
        uint256 creatorFinalBalance = MEME_CREATOR.balance;
        uint256 buyerFinalBalance = TOKEN_BUYER.balance;
        
        console.log("\n=== Final Balances ===");
        console.log("Platform balance:", platformFinalBalance);
        console.log("Creator balance:", creatorFinalBalance);
        console.log("Buyer balance:", buyerFinalBalance);
        
        // 计算余额变化
        uint256 platformGain = platformFinalBalance - platformInitialBalance;
        uint256 creatorGain = creatorFinalBalance - creatorInitialBalance;
        uint256 buyerLoss = buyerInitialBalance - buyerFinalBalance;
        
        console.log("\n=== Balance Changes ===");
        console.log("Platform gained:", platformGain);
        console.log("Creator gained:", creatorGain);
        console.log("Buyer paid:", buyerLoss);
        
        // 验证费用分配
        uint256 totalPaid = 0.001 ether;
        uint256 expectedPlatformFee = (totalPaid * 100) / 10000; // 1%
        uint256 expectedCreatorFee = totalPaid - expectedPlatformFee; // 99%
        
        console.log("\n=== Fee Distribution Verification ===");
        console.log("Total paid:", totalPaid);
        console.log("Expected platform fee (1%):", expectedPlatformFee);
        console.log("Expected creator fee (99%):", expectedCreatorFee);
        console.log("Actual platform fee:", platformGain);
        console.log("Actual creator fee:", creatorGain);
        
        // 验证结果
        bool platformFeeCorrect = platformGain == expectedPlatformFee;
        bool creatorFeeCorrect = creatorGain == expectedCreatorFee;
        bool totalCorrect = (platformGain + creatorGain) == totalPaid;
        
        console.log("\n=== Test Results ===");
        console.log("Platform fee correct:", platformFeeCorrect);
        console.log("Creator fee correct:", creatorFeeCorrect);
        console.log("Total distribution correct:", totalCorrect);
        console.log("Fee distribution test PASSED:", platformFeeCorrect && creatorFeeCorrect && totalCorrect);
        
        // 计算百分比
        if (totalPaid > 0) {
            uint256 platformPercentage = (platformGain * 10000) / totalPaid;
            uint256 creatorPercentage = (creatorGain * 10000) / totalPaid;
            
            console.log("\n=== Actual Percentages ===");
            console.log("Platform percentage (basis points):", platformPercentage);
            console.log("Creator percentage (basis points):", creatorPercentage);
            console.log("Platform percentage (%):", platformPercentage / 100);
            console.log("Creator percentage (%):", creatorPercentage / 100);
        }
        
        console.log("\n=== Test Complete ===");
    }
}