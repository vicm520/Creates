// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @dev ERC20接收器接口
 */
interface IERC20Receiver {
    function onERC20Received(address operator, uint256 amount, bytes calldata data) external returns (bytes4);
}

/**
 * @title EipTokenCloneable
 * @dev 可克隆的ERC20代币模板合约，用于最小代理模式
 * 避免使用构造函数，改用initialize函数进行初始化
 */
contract EipTokenCloneable is ERC20, Ownable, Initializable {
    
    // 存储代币名称和符号，因为ERC20的_name和_symbol是私有的
    string private _tokenName;
    string private _tokenSymbol;
    
    /**
     * @dev 构造函数 - 仅用于模板合约部署
     * 模板合约不需要初始化，克隆合约通过initialize函数初始化
     */
    constructor() ERC20("", "") Ownable(msg.sender) {
        // 禁用模板合约的初始化，防止被误用
        _disableInitializers();
    }

    /**
     * @dev 初始化函数，替代构造函数用于克隆合约
     * @param name_ 代币名称
     * @param symbol_ 代币符号
     * @param initialSupply_ 初始供应量
     * @param owner_ 合约所有者
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_,
        address owner_
    ) external initializer {
        require(owner_ != address(0), "EipTokenCloneable: owner cannot be zero address");
        
        // 存储代币名称和符号
        _tokenName = name_;
        _tokenSymbol = symbol_;
        
        // 初始化Ownable
        _transferOwnership(owner_);
        
        // 如果有初始供应量，铸造给所有者
        if (initialSupply_ > 0) {
            _mint(owner_, initialSupply_);
        }
    }

    /**
     * @dev 重写name函数返回正确的代币名称
     */
    function name() public view override returns (string memory) {
        return _tokenName;
    }

    /**
     * @dev 重写symbol函数返回正确的代币符号
     */
    function symbol() public view override returns (string memory) {
        return _tokenSymbol;
    }

    /**
     * @dev 铸造代币 (仅所有者)
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev 销毁代币 (仅所有者)
     * @param from 销毁地址
     * @param amount 销毁数量
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    /**
     * @dev 带回调的转账函数
     * @param to 接收地址
     * @param amount 转账数量
     * @param data 回调数据
     */
    function transferWithCallback(address to, uint256 amount, bytes calldata data) external returns (bool) {
        bool success = transfer(to, amount);
        
        // 如果接收地址是合约，尝试调用回调函数
        if (to.code.length > 0) {
            try IERC20Receiver(to).onERC20Received(msg.sender, amount, data) returns (bytes4 retval) {
                require(retval == IERC20Receiver.onERC20Received.selector, "EipTokenCloneable: transfer to non ERC20Receiver implementer");
            } catch {
                // 忽略回调失败，保持转账成功
            }
        }
        
        return success;
    }
}