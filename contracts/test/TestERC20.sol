// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "hardhat/console.sol";

/**
    @notice Token behaviours can be set by calling configure()
    name                                    params
    balance-of/consume-all-gas                                          Consume all gas on balanceOf
    balance-of/max-value                                                Return max uint on balanceOf
    balance-of/revert                                                   Revert on balanceOf
    balance-of/panic                                                    Panic on balanceOf
    approve/return-void                                                 Return nothing instead of bool
    transfer/return-void                                                Return nothing instead of bool
    transfer-from/return-void                                           Return nothing instead of bool
    transfer/deflationary                   uint deflate                Make the transfer and transferFrom decrease recipient amount by deflate
    transfer/inflationary                   uint inflate                Make the transfer and transferFrom increase recipient amount by inflate
*/

contract TestERC20 {
    address owner;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    bool secureMode;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowance;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor(string memory name_, string memory symbol_, uint8 decimals_, bool secureMode_) {
        owner = msg.sender;
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        secureMode = secureMode_;
    }

    function balanceOf(address account) public view returns (uint) {
        (bool isSet,) = behaviour("balance-of/consume-all-gas");
        if(isSet) consumeAllGas();

        (isSet,) = behaviour("balance-of/revert");
        if(isSet) revert("revert behaviour");

        (isSet,) = behaviour("balance-of/panic");
        if(isSet) assert(false);

        (isSet,) = behaviour("balance-of/zero");
        if(isSet) return 0;

        (isSet,) = behaviour("balance-of/max-value"); 
        return isSet ? type(uint).max : balances[account];
    }

    function approve(address spender, uint256 amount) external {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);

        (bool isSet,) = behaviour("approve/return-void");
        doReturn(isSet);
    }

    function transfer(address recipient, uint256 amount) external {
        transferFrom(msg.sender, recipient, amount);

        (bool isSet,) = behaviour("transfer/return-void");
        doReturn(isSet);
    }

    function transferFrom(address from, address recipient, uint256 amount) public {
        require(balances[from] >= amount, "ERC20: transfer amount exceeds balance");
        if (from != msg.sender && allowance[from][msg.sender] != type(uint256).max) {
            require(allowance[from][msg.sender] >= amount, "ERC20: transfer amount exceeds allowance");
            allowance[from][msg.sender] -= amount;
        }

        (bool isSet, bytes memory data) = behaviour("transfer/deflationary");
        uint deflate = isSet ? abi.decode(data, (uint)) : 0;

        (isSet, data) = behaviour("transfer/inflationary");
        uint inflate = isSet ? abi.decode(data, (uint)) : 0;

        balances[from] -= amount;
        balances[recipient] += amount - deflate + inflate;
        emit Transfer(from, recipient, amount);

        if(msg.sig == this.transferFrom.selector) {
            (isSet,) = behaviour("transfer-from/return-void");
            doReturn(isSet);
        }
    }

    // Custom testing method

    modifier secured() {
        require(!secureMode || msg.sender == owner, "TestERC20: secure mode enabled");
        _;
    }

    struct Config {
        string name;
        bytes data;
    }

    Config[] config;

    function configure(string calldata name_, bytes calldata data_) external secured {
        config.push(Config(name_, data_));
    }

    function behaviour(string memory name_) public view returns(bool, bytes memory) {
        for (uint i = 0; i < config.length; i++) {
            if (keccak256(abi.encode(config[i].name)) == keccak256(abi.encode(name_))) {
                return (true, config[i].data);
            }
        }
        return (false, "");
    }


    function changeOwner(address newOwner) external secured {
        owner = newOwner;
    }

    function mint(address who, uint amount) external secured {
        balances[who] += amount;
        emit Transfer(address(0), who, amount);
    }

    function setBalance(address who, uint newBalance) external secured {
        balances[who] = newBalance;
    }

    function changeDecimals(uint8 decimals_) external secured {
        decimals = decimals_;
    }

    function callSelfDestruct() external secured {
        selfdestruct(payable(address(0)));
    }

    function consumeAllGas() internal pure {
        for (; true;) {}
    }

    function doReturn(bool returnVoid) internal pure {
        if (returnVoid) return;

        assembly {
            mstore(mload(0x40), 1) // NOTE default true
            return(mload(0x40), 0x20)
        }
    }
}
