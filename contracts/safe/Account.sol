//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Account {

    event LogChangeOwner(address indexed safe, address indexed owner, address indexed newOwner);
    event LogDisown(address indexed safe, address indexed owner);

    address public owner;
    uint public id;

    function init(address _owner, uint _id) public {
        require(id == 0, "safe/Account::already-init");
        changeOwner(_owner);
        id = _id;
    }

    function changeOwner(address newOwner) public {
        require(owner == address(0) || msg.sender == owner, "safe/Account::not-authorized");
        require(newOwner != address(0), "safe/Account::invalid-new-owner");

        emit LogChangeOwner(address(this), owner, newOwner);

        owner = newOwner;
    }

    function disown() public {
        require(msg.sender == owner, "safe/Account::not-authorized");

        emit LogDisown(address(this), owner);

        owner = address(0);
    }

    function spell(address target, bytes memory data) internal {
        require(target != address(0), "safe/Account::target-invalid");

        assembly {
            let succeeded := delegatecall(gas(), target, add(data, 0x20), mload(data), 0, 0)

            switch iszero(succeeded)
                case 1 {
                    let size := returndatasize()
                    returndatacopy(0x00, 0x00, size)
                    revert(0x00, size)
                }
        }
    }

    function execute(address[] calldata targets, bytes[] calldata datas) external payable {
        require(msg.sender == owner, "safe/Account::not-authorized");
        require(targets.length == datas.length, "safe/Account::array-length-mismatch");

        for (uint i = 0; i < targets.length; i++) {
            spell(targets[i], datas[i]);
        }
    }
}
