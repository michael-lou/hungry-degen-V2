import { ethers, network, upgrades } from 'hardhat';
import { ContractAddressManager } from './utils/ContractAddressManager';

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`部署 UserBalanceManager 合约到 ${networkName} 网络...`);

  // 获取部署者钱包
  const [deployer] = await ethers.getSigners();
  console.log(`部署者地址: ${deployer.address}`);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(`部署者余额: ${ethers.formatEther(balance)} ETH`);

  try {
    // 检查是否已经部署过 UserBalanceManager
    const contracts = addressManager.getAllContractAddresses(networkName) || {};
    const existingUserBalanceManager = contracts['UserBalanceManager'];

    if (existingUserBalanceManager) {
      console.log(`⚠️  UserBalanceManager 已在此网络部署: ${existingUserBalanceManager}`);
      console.log('如需重新部署，请先删除地址管理器中的记录');
      return;
    }

    // 部署 UserBalanceManager (可升级)
    console.log('\n🚀 部署 UserBalanceManager...');
    const UserBalanceManagerFactory = await ethers.getContractFactory('UserBalanceManager');
    const userBalanceManager = await upgrades.deployProxy(
      UserBalanceManagerFactory,
      [], // 初始化函数无参数
      {
        initializer: 'initialize',
        kind: 'uups',
      }
    );

    await userBalanceManager.waitForDeployment();
    const userBalanceManagerAddress = await userBalanceManager.getAddress();
    console.log(`✅ UserBalanceManager 已部署 (可升级): ${userBalanceManagerAddress}`);

    // 保存合约地址
    addressManager.saveContractAddress(networkName, 'UserBalanceManager', userBalanceManagerAddress, {
      deployer: deployer.address,
      deploymentMode: 'upgradeable',
      proxyType: 'UUPS',
      initParams: [],
      description: 'Unified user balance manager for PackMarketplace and FoodMarketplace',
      features: [
        'Food box balance management',
        'Gold pack balance management (3D mapping)',
        'Box balance management (3D mapping)',
        'Authorization system',
        'Emergency migration functions',
        'Batch operations'
      ],
      deployedAt: new Date().toISOString(),
    });

    console.log('\n✅ UserBalanceManager 部署完成!');

    // 打印部署摘要
    console.log('\n📋 部署摘要:');
    console.log(`网络: ${networkName}`);
    console.log(`部署者: ${deployer.address}`);
    console.log(`UserBalanceManager: ${userBalanceManagerAddress}`);

    console.log('\n📝 后续配置步骤:');
    console.log('1. 在 PackMarketplace 中设置 UserBalanceManager 地址:');
    console.log(`   packMarketplace.setBalanceManager("${userBalanceManagerAddress}")`);
    console.log('2. 在 FoodMarketplace 中设置 UserBalanceManager 地址:');
    console.log(`   foodMarketplace.setBalanceManager("${userBalanceManagerAddress}")`);
    console.log('3. 在 UserBalanceManager 中授权 PackMarketplace:');
    console.log(`   userBalanceManager.setAuthorizedContract(packMarketplaceAddress, true)`);
    console.log('4. 在 UserBalanceManager 中授权 FoodMarketplace:');
    console.log(`   userBalanceManager.setAuthorizedContract(foodMarketplaceAddress, true)`);
    console.log('\n⚠️  重要提醒:');
    console.log('- 部署新版本的 PackMarketplace 和 FoodMarketplace 时，请确保在初始化函数中传入 UserBalanceManager 地址');
    console.log('- 如果需要迁移现有用户数据，请使用 UserBalanceManager 的紧急迁移功能');

  } catch (error) {
    console.error('❌ 部署过程中发生错误:', error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('UserBalanceManager 部署脚本执行失败:', error);
    process.exit(1);
  });