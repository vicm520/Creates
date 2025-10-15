// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/EipTokenCloneable.sol";
import "../src/MemeFactory.sol";

contract QuickTestScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Quick Meme Test ===");
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署EipTokenCloneable模板
        console.log("\n1. Deploying EipTokenCloneable template...");
        EipTokenCloneable tokenTemplate = new EipTokenCloneable();
        console.log("Template deployed at:", address(tokenTemplate));
        
        // 2. 部署MemeFactory
        console.log("\n2. Deploying MemeFactory...");
        MemeFactory factory = new MemeFactory(address(tokenTemplate), deployer);
        console.log("Factory deployed at:", address(factory));
        
        // 3. 部署Meme代币
        console.log("\n3. Deploying Meme token...");
        address memeToken = factory.deployMeme("PEPE", 1000000, 1000, 0.001 ether);
        console.log("Meme token deployed at:", memeToken);
        
        // 4. 获取创建者信息
        (, address creator, , , , , , ) = factory.memeInfos(memeToken);
        console.log("Creator:", creator);
        
        // 5. 记录铸造前的状态
        console.log("\n4. Before minting:");
        console.log("User token balance:", EipTokenCloneable(memeToken).balanceOf(deployer));
        console.log("Creator ETH balance:", creator.balance);
        console.log("Platform ETH balance:", factory.platformFeeReceiver().balance);
        
        // 6. 铸造代币
        console.log("\n5. Minting tokens...");
        factory.mintMeme{value: 0.001 ether}(memeToken);
        
        // 7. 记录铸造后的状态
        console.log("\n6. After minting:");
        console.log("User token balance:", EipTokenCloneable(memeToken).balanceOf(deployer));
        console.log("Creator ETH balance:", creator.balance);
        console.log("Platform ETH balance:", factory.platformFeeReceiver().balance);
        
        // 8. 验证费用分配
        uint256 expectedPlatformFee = (0.001 ether * 100) / 10000; // 1%
        uint256 expectedCreatorFee = 0.001 ether - expectedPlatformFee; // 99%
        
        console.log("\n7. Fee verification:");
        console.log("Expected platform fee (1%):", expectedPlatformFee);
        console.log("Expected creator fee (99%):", expectedCreatorFee);
        console.log("Actual platform fee:", factory.platformFeeReceiver().balance);
        console.log("Actual creator fee:", creator.balance);
        
        // 9. 验证结果
        bool platformFeeCorrect = factory.platformFeeReceiver().balance == expectedPlatformFee;
        bool creatorFeeCorrect = creator.balance >= expectedCreatorFee;
        
        console.log("\n8. Test Results:");
        console.log("Platform fee correct:", platformFeeCorrect);
        console.log("Creator fee correct:", creatorFeeCorrect);
        console.log("Test PASSED:", platformFeeCorrect && creatorFeeCorrect);
        
        vm.stopBroadcast();
        
        console.log("\n=== Test Complete ===");
        console.log("EipTokenCloneable:", address(tokenTemplate));
        console.log("MemeFactory:", address(factory));
        console.log("Meme Token:", memeToken);
    }
}