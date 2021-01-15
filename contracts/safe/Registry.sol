//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface SafeLike {
    function changeOwner(address) external;
    function execute(address[] calldata, bytes[] calldata) external payable;
}

contract SafeFactory {

    event LogNewSafe(address indexed owner, address indexed safe);

    mapping (uint => address) public registry;
    address private safeLogic;

    function createClone(address target) internal returns (address result) {
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create(0, clone, 0x37)
        }
    }

    function createSafe() public returns (address safe) {
        safe = createClone(safeLogic);
        SafeLike(safe).changeOwner(msg.sender);

        emit LogNewSafe(msg.sender, safe);
    }

    function createAndExecute(
        address[] calldata targets,
        bytes[] calldata datas
    ) external payable returns (address safe) {
        require(targets.length > 0, "safe/Registry::noting-to-execute");

        safe = createSafe();

        SafeLike(safe).cast(targets, datas);
    }

    function setLogic(address logic) public {
        require(safeLogic == address(0), "safe/Registry::already-set");

        safeLogic = logic;
    }
}
