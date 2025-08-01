// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.6;

import "forge-std/Test.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";
import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract SafeTestHelper is Test {
    GnosisSafe public safeSingleton;
    GnosisSafeProxyFactory public factory;
    
    // Constants for mainnet addresses (can be overridden)
    address public constant SAFE_FACTORY = 0xBba817F97F133b87b9b7F1FC0f2c56E9F68D2EdF;
    address payable public constant SAFE_SINGLETON = payable(0xDd4BDA7BcdA544d6da2aEa8AB8B0e63D2f6Dc737);
    
    // Events for debugging
    event SafeCreated(address indexed safe, address[] owners, uint256 threshold);
    event TransactionExecuted(address indexed safe, bool success);

    function setUpSafeHelpers() internal {
        // Try to use existing contracts first, then deploy if needed
        if (Address.isContract(SAFE_FACTORY)) {
            factory = GnosisSafeProxyFactory(SAFE_FACTORY);
        } else {
            factory = new GnosisSafeProxyFactory();
        }
        
        if (Address.isContract(SAFE_SINGLETON)) {
            safeSingleton = GnosisSafe(payable(SAFE_SINGLETON));
        } else {
            safeSingleton = new GnosisSafe();
        }
    }

    function createSafeFallbackHandler(
        address[] memory owners,
        uint256 threshold,
        address payable fallbackHandler
    ) internal returns (GnosisSafe safe) {
        bytes memory initializer = abi.encodeWithSelector(
            GnosisSafe.setup.selector,
            owners,
            threshold,
            address(0), // to
            "", // data
            fallbackHandler, // fallbackHandler
            address(0), // paymentToken
            0, // payment
            payable(0) // paymentReceiver
        );

        GnosisSafeProxy proxy = factory.createProxy(address(safeSingleton), initializer);
        safe = GnosisSafe(payable(proxy));
        
        emit SafeCreated(address(safe), owners, threshold);
    }

    function createSafe(
        address[] memory owners,
        uint256 threshold
    ) internal returns (GnosisSafe safe) {
        return createSafeFallbackHandler(owners, threshold, payable(address(0)));
    }


    function createSafeWithOwners(
        address[] memory owners
    ) internal returns (GnosisSafe safe) {
        return createSafe(owners, owners.length);
    }

    function createSafeWithSingleOwner(
        address owner
    ) internal returns (GnosisSafe safe) {
        address[] memory owners = new address[](1);
        owners[0] = owner;
        return createSafe(owners, 1);
    }

    function executeSafeTransaction(
        GnosisSafe safe,
        address target,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) internal returns (bool success) {
        bytes memory encodedTx = abi.encodeWithSelector(
            GnosisSafe.execTransaction.selector,
            target,
            value,
            data,
            operation,
            safeTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver,
            signatures
        );

        (success, ) = address(safe).call(encodedTx);
        emit TransactionExecuted(address(safe), success);
    }

    function executeSafeTransaction(
        GnosisSafe safe,
        address target,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) internal returns (bool success) {
        return executeSafeTransaction(
            safe,
            target,
            value,
            data,
            operation,
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            payable(0), // refundReceiver
            "" // signatures
        );
    }

    function executeSafeTransaction(
        GnosisSafe safe,
        address target,
        bytes memory data
    ) internal returns (bool success) {
        return executeSafeTransaction(
            safe,
            target,
            0, // value
            data,
            Enum.Operation.Call
        );
    }

    function signSafeTransaction(
        GnosisSafe safe,
        address target,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        uint256 nonce,
        uint256 privateKey
    ) internal returns (bytes memory signature) {
        bytes32 txHash = safe.getTransactionHash(
            target,
            value,
            data,
            operation,
            safeTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver,
            nonce
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, txHash);
        signature = abi.encodePacked(r, s, v);
    }

    function signSafeTransaction(
        GnosisSafe safe,
        address target,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 nonce,
        uint256 privateKey
    ) internal returns (bytes memory signature) {
        return signSafeTransaction(
            safe,
            target,
            value,
            data,
            operation,
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            payable(0), // refundReceiver
            nonce,
            privateKey
        );
    }

    function signSafeTransaction(
        GnosisSafe safe,
        address target,
        bytes memory data,
        uint256 nonce,
        uint256 privateKey
    ) internal returns (bytes memory signature) {
        return signSafeTransaction(
            safe,
            target,
            0, // value
            data,
            Enum.Operation.Call,
            nonce,
            privateKey
        );
    }

    function combineSignatures(
        bytes memory signature1,
        bytes memory signature2
    ) internal pure returns (bytes memory combined) {
        combined = abi.encodePacked(signature1, signature2);
    }

    function combineSignatures(
        bytes memory signature1,
        bytes memory signature2,
        bytes memory signature3
    ) internal pure returns (bytes memory combined) {
        combined = abi.encodePacked(signature1, signature2, signature3);
    }



    // Enhanced helper function similar to SafeSetup.sol
    function safeHelper(
        GnosisSafe safe,
        uint256 privateKey,
        address target,
        bytes memory data
    ) internal {
        safeHelper(safe, privateKey, target, data, 0);
    }

    function safeHelper(
        GnosisSafe safe,
        uint256 privateKey,
        address target,
        bytes memory data,
        uint256 value
    ) internal {
        bytes memory signature = signSafeTransaction(
            safe,
            target,
            data,
            safe.nonce(),
            privateKey
        );
        
        bool success = executeSafeTransaction(
            safe,
            target,
            value,
            data,
            Enum.Operation.Call,
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            payable(0), // refundReceiver
            signature
        );
        
        require(success, "Safe transaction failed");
    }

    // Helper to get transaction hash (similar to SafeSetup.sol)
    function getTransactionHash(
        GnosisSafe safe,
        address target,
        bytes memory data
    ) internal view returns (bytes32) {
        return safe.getTransactionHash(
            target,
            0, // value
            data,
            Enum.Operation.Call,
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            payable(0), // refundReceiver
            safe.nonce()
        );
    }

    // Helper to create Safe with specific nonce (like SafeSetup.sol)
    function createSafeWithNonce(
        address[] memory owners,
        uint256 threshold,
        uint256 nonce
    ) internal returns (GnosisSafe safe) {
        bytes memory initializer = abi.encodeWithSelector(
            GnosisSafe.setup.selector,
            owners,
            threshold,
            address(0), // to
            "", // data
            address(0), // fallbackHandler
            address(0), // paymentToken
            0, // payment
            payable(0) // paymentReceiver
        );

        GnosisSafeProxy proxy = factory.createProxyWithNonce(address(safeSingleton), initializer, nonce);
        safe = GnosisSafe(payable(proxy));
        
        emit SafeCreated(address(safe), owners, threshold);
    }
} 