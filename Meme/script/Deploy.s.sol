// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/EipTokenCloneable.sol";
import "../src/MemeFactory.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署EipTokenCloneable模板合约
        console.log("Deploying EipTokenCloneable template...");
        EipTokenCloneable tokenTemplate = new EipTokenCloneable();
        console.log("EipTokenCloneable deployed at:", address(tokenTemplate));
        
        // 2. 部署MemeFactory合约
        console.log("Deploying MemeFactory...");
        address platformFeeReceiver = deployer; // 使用部署者作为平台费用接收者
        MemeFactory factory = new MemeFactory(address(tokenTemplate), platformFeeReceiver);
        console.log("MemeFactory deployed at:", address(factory));
        console.log("Platform fee receiver:", platformFeeReceiver);
        
        vm.stopBroadcast();
        
        // 保存部署信息到文件
        string memory deploymentInfo = string(abi.encodePacked(
            "=== Deployment Information ===\n",
            "Deployer: ", vm.toString(deployer), "\n",
            "EipTokenCloneable: ", vm.toString(address(tokenTemplate)), "\n",
            "MemeFactory: ", vm.toString(address(factory)), "\n",
            "Platform Fee Receiver: ", vm.toString(platformFeeReceiver), "\n",
            "Chain ID: 31337\n",
            "RPC URL: http://localhost:8545\n"
        ));
        
        vm.writeFile("deployment_addresses.txt", deploymentInfo);
        console.log("Deployment addresses saved to deployment_addresses.txt");
    }
}