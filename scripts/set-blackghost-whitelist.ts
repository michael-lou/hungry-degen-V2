import { ethers, network } from 'hardhat';
import { ContractAddressManager } from './utils/ContractAddressManager';

/**
 * 批量设置 BlackGhostSale 白名单的示例脚本
 *
 * 使用方法：
 * 1. 修改下面的 WHITELIST_CONFIG 数组，添加需要设置白名单的地址和折扣
 * 2. 运行: npx hardhat run scripts/set_blackghost_whitelist.ts --network [网络名]
 */

// 白名单配置
const WHITELIST_CONFIG = [
  // 示例配置，请根据实际需求修改
  { address: '0x1234567890123456789012345678901234567890', discount: 1000 }, // 1折 (10%)
  { address: '0x2345678901234567890123456789012345678901', discount: 8000 }, // 8折 (80%)
  // 添加更多地址...
];

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`批量设置 BlackGhostSale 白名单 - ${networkName} 网络...`);

  // 获取部署者钱包
  const [deployer] = await ethers.getSigners();
  console.log(`操作者地址: ${deployer.address}`);

  try {
    // 从 ContractAddressManager 加载合约地址
    const contracts = addressManager.getAllContractAddresses(networkName) || {};
    const blackGhostSaleAddress = contracts['BlackGhostSale'];

    if (!blackGhostSaleAddress) {
      throw new Error('BlackGhostSale 地址未找到，请先部署 BlackGhostSale 合约');
    }

    // 连接到 BlackGhostSale 合约
    const BlackGhostSale = await ethers.getContractFactory('BlackGhostSale');
    const blackGhostSale = BlackGhostSale.attach(blackGhostSaleAddress) as any;
    console.log(`✅ 已连接到 BlackGhostSale: ${blackGhostSaleAddress}`);

    if (WHITELIST_CONFIG.length === 0) {
      console.log('⚠️ 没有配置白名单地址，请修改脚本中的 WHITELIST_CONFIG');
      return;
    }

    // 验证所有地址格式
    for (const config of WHITELIST_CONFIG) {
      if (!ethers.isAddress(config.address)) {
        throw new Error(`无效的地址格式: ${config.address}`);
      }
      if (config.discount < 0 || config.discount > 10000) {
        throw new Error(`无效的折扣值: ${config.discount}，应该在0-10000之间`);
      }
    }

    console.log(`\n📋 准备设置 ${WHITELIST_CONFIG.length} 个白名单地址:`);
    WHITELIST_CONFIG.forEach((config, index) => {
      console.log(
        `${index + 1}. ${config.address} - ${config.discount / 100}% (${config.discount === 1000 ? '1折' : config.discount === 8000 ? '8折' : `${config.discount / 100}%`})`
      );
    });

    // 批量设置白名单
    console.log('\n🔧 批量设置白名单...');
    const addresses = WHITELIST_CONFIG.map((config) => config.address);
    const discounts = WHITELIST_CONFIG.map((config) => config.discount);

    const tx = await blackGhostSale.setWhitelist(addresses, discounts);
    await tx.wait();

    console.log(`✅ 成功设置 ${addresses.length} 个白名单地址`);

    // 验证设置结果
    console.log('\n🔍 验证设置结果:');
    for (let i = 0; i < addresses.length; i++) {
      const actualDiscount = await blackGhostSale.whitelistDiscounts(addresses[i]);
      const expectedDiscount = discounts[i];

      if (Number(actualDiscount) === expectedDiscount) {
        console.log(`✅ ${addresses[i]}: ${Number(actualDiscount) / 100}% 折扣`);
      } else {
        console.log(`❌ ${addresses[i]}: 预期 ${expectedDiscount / 100}%，实际 ${Number(actualDiscount) / 100}%`);
      }
    }

    console.log('\n✅ 白名单设置完成!');

    // 提供移除白名单的示例
    console.log('\n📝 如需移除白名单，可以使用以下方法:');
    console.log('// 移除单个地址');
    console.log('// await blackGhostSale.removeFromWhitelist("0x地址");');
    console.log('// 或设置折扣为0');
    console.log('// await blackGhostSale.setWhitelist(["0x地址"], [0]);');
  } catch (error) {
    console.error('❌ 设置白名单过程中发生错误:', error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('白名单设置脚本执行失败:', error);
    process.exit(1);
  });
