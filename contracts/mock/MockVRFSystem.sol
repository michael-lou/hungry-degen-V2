// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IVRFSystem.sol";
import "../interfaces/IVRFSystemCallback.sol";

contract MockVRFSystem is IVRFSystem {
    uint256 private nextRequestId = 1;

    // 记录请求信息
    mapping(uint256 => address) public requestIdToSender;
    mapping(uint256 => uint256) public requestIdToTraceId;

    event RandomNumberRequested(uint256 indexed requestId, address indexed requester, uint256 traceId);
    event RandomNumberFulfilled(uint256 indexed requestId, uint256 randomNumber);

    /**
     * @dev 请求随机数，仅记录请求，不执行回调
     * @param traceId 业务跟踪ID
     * @return requestId 随机数请求ID
     */
    function requestRandomNumberWithTraceId(uint256 traceId) external override returns (uint256) {
        uint256 requestId = nextRequestId++;

        // 记录请求信息
        requestIdToSender[requestId] = msg.sender;
        requestIdToTraceId[requestId] = traceId;

        emit RandomNumberRequested(requestId, msg.sender, traceId);

        return requestId;
    }

    /**
     * @dev 由链下系统/测试脚本调用，完成随机数生成
     * @param requestId 请求ID
     * @param randomNumber 生成的随机数
     */
    function fulfillRandomness(uint256 requestId, uint256 randomNumber) external {
        address callbackAddress = requestIdToSender[nextRequestId - 1];
        require(callbackAddress != address(0), "MockVRFSystem: Request ID not found");

        // 调用请求者的回调函数
        IVRFSystemCallback(callbackAddress).randomNumberCallback(nextRequestId - 1, randomNumber);

        emit RandomNumberFulfilled(nextRequestId - 1, randomNumber);
    }

    /**
     * @dev 获取请求关联的业务追踪ID
     * @param requestId 请求ID
     * @return traceId 业务追踪ID
     */
    function getTraceIdForRequest(uint256 requestId) external view returns (uint256) {
        return requestIdToTraceId[requestId];
    }

    /**
     * @dev 检查请求是否存在
     * @param requestId 请求ID
     * @return 请求是否存在
     */
    function requestExists(uint256 requestId) external view returns (bool) {
        return requestIdToSender[requestId] != address(0);
    }
}
