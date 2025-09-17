import { ethers, network } from 'hardhat';
import type { BlackGhostSale } from '../../typechain-types';
import { ContractAddressManager } from '../utils/ContractAddressManager';

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`暂停 BlackGhostSale 合约在 ${networkName} 网络...`);

  // 获取部署者钱包
  const [deployer] = await ethers.getSigners();
  console.log(`部署者地址: ${deployer.address}`);

  try {
    // 从 AddressManager 读取 BlackGhostSale 地址
    console.log('\n📋 加载已部署的合约地址...');
    const contracts = addressManager.getAllContractAddresses(networkName) || {};
    const blackGhostSaleAddress = contracts['BlackGhostSale'];

    if (!blackGhostSaleAddress) {
      throw new Error(`BlackGhostSale 合约未在 ${networkName} 网络中找到，请先部署 BlackGhostSale`);
    }

    console.log(`✅ 已找到 BlackGhostSale: ${blackGhostSaleAddress}`);

    // 连接到 BlackGhostSale 合约
    const BlackGhostSale = await ethers.getContractFactory('BlackGhostSale');
    const blackGhostSale = BlackGhostSale.attach(blackGhostSaleAddress) as BlackGhostSale;

    // 检查当前暂停状态
    console.log('\n🔍 检查当前合约状态...');
    const isPaused = await blackGhostSale.paused();
    console.log(`当前暂停状态: ${isPaused ? '已暂停' : '运行中'}`);

    if (isPaused) {
      console.log('⚠️  合约已经处于暂停状态');
      return;
    }

    // 获取合约所有者
    const owner = await blackGhostSale.owner();
    console.log(`合约所有者: ${owner}`);

    if (deployer.address.toLowerCase() !== owner.toLowerCase()) {
      throw new Error(`权限不足: 当前地址 ${deployer.address} 不是合约所有者 ${owner}`);
    }

    // 获取合约销售状态信息
    const currentSupply = await blackGhostSale.currentSupply();
    const maxSupply = await blackGhostSale.maxSupply();
    const price = await blackGhostSale.price();
    const currentPhase = await blackGhostSale.currentPhase();
    const isActive = await blackGhostSale.isSaleActive();

    console.log('\n📊 合约当前状态:');
    console.log(`当前供应量: ${currentSupply.toString()}`);
    console.log(`最大供应量: ${maxSupply.toString()}`);
    console.log(`价格: ${ethers.formatEther(price)} ETH`);
    console.log(`当前阶段: ${currentPhase === 0n ? 'Early Bird (早鸟阶段)' : 'Public Sale (公开销售)'}`);
    console.log(`销售状态: ${isActive ? '激活' : '未激活'}`);

    // 暂停合约
    console.log('\n⏸️  暂停 BlackGhostSale 合约...');
    const pauseTx = await blackGhostSale.pause();
    console.log(`暂停交易哈希: ${pauseTx.hash}`);

    console.log('⏳ 等待交易确认...');
    await pauseTx.wait();

    // 验证暂停状态
    const isPausedAfter = await blackGhostSale.paused();
    const isActiveAfter = await blackGhostSale.isSaleActive();

    console.log('\n✅ 暂停操作完成！');
    console.log(`暂停状态: ${isPausedAfter ? '已暂停' : '运行中'}`);
    console.log(`销售状态: ${isActiveAfter ? '激活' : '未激活'}`);

    if (isPausedAfter) {
      console.log('\n🎉 BlackGhostSale 合约已成功暂停');
      console.log('💡 提示: 用户将无法购买 NFT，直到合约被重新启用');
      console.log('💡 要恢复合约，请使用 unpause 功能');
    } else {
      console.log('\n❌ 暂停操作失败，请检查交易状态');
    }
  } catch (error) {
    console.error('\n❌ 暂停操作失败:');
    if (error instanceof Error) {
      console.error(error.message);
    } else {
      console.error('未知错误:', error);
    }
    process.exit(1);
  }
}

// 执行脚本
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
