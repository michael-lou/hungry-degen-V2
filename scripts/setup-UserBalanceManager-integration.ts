import { ethers, network } from 'hardhat';
import { ContractAddressManager } from './utils/ContractAddressManager';

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`配置 UserBalanceManager 集成到 ${networkName} 网络...`);

  // 获取部署者钱包
  const [deployer] = await ethers.getSigners();
  console.log(`操作者地址: ${deployer.address}`);

  try {
    // 从 ContractAddressManager 加载合约地址
    console.log('\n📋 加载已部署的合约地址...');
    const contracts = addressManager.getAllContractAddresses(networkName) || {};
    
    const userBalanceManagerAddress = contracts['UserBalanceManager'];
    const packMarketplaceAddress = contracts['PackMarketplace'];
    const foodMarketplaceAddress = contracts['FoodMarketplace'];

    console.log(`UserBalanceManager: ${userBalanceManagerAddress || '未部署'}`);
    console.log(`PackMarketplace: ${packMarketplaceAddress || '未部署'}`);
    console.log(`FoodMarketplace: ${foodMarketplaceAddress || '未部署'}`);

    // 检查必需的合约地址
    if (!userBalanceManagerAddress) {
      throw new Error('UserBalanceManager 地址未找到，请先部署 UserBalanceManager 合约');
    }

    // 连接到合约
    const UserBalanceManager = await ethers.getContractFactory('UserBalanceManager');
    const userBalanceManager = UserBalanceManager.attach(userBalanceManagerAddress) as any;

    let configuredCount = 0;

    // 配置 PackMarketplace
    if (packMarketplaceAddress) {
      console.log('\n🔧 配置 PackMarketplace 集成...');
      
      const PackMarketplace = await ethers.getContractFactory('PackMarketplace');
      const packMarketplace = PackMarketplace.attach(packMarketplaceAddress) as any;

      // 1. 在 PackMarketplace 中设置 UserBalanceManager 地址
      try {
        const currentBalanceManager = await packMarketplace.balanceManager();
        if (currentBalanceManager.toLowerCase() !== userBalanceManagerAddress.toLowerCase()) {
          console.log('  - 设置 PackMarketplace 的 BalanceManager...');
          const tx1 = await packMarketplace.setBalanceManager(userBalanceManagerAddress);
          await tx1.wait();
          console.log('  ✅ PackMarketplace BalanceManager 已设置');
        } else {
          console.log('  ✅ PackMarketplace BalanceManager 已经正确设置');
        }
      } catch (error) {
        console.log('  ❌ 设置 PackMarketplace BalanceManager 失败，可能是旧版本合约');
      }

      // 2. 在 UserBalanceManager 中授权 PackMarketplace
      const isPackAuthorized = await userBalanceManager.authorizedContracts(packMarketplaceAddress);
      if (!isPackAuthorized) {
        console.log('  - 授权 PackMarketplace 访问 UserBalanceManager...');
        const tx2 = await userBalanceManager.setAuthorizedContract(packMarketplaceAddress, true);
        await tx2.wait();
        console.log('  ✅ PackMarketplace 已被授权');
      } else {
        console.log('  ✅ PackMarketplace 已经被授权');
      }

      configuredCount++;
    } else {
      console.log('\n⚠️  PackMarketplace 未部署，跳过配置');
    }

    // 配置 FoodMarketplace
    if (foodMarketplaceAddress) {
      console.log('\n🔧 配置 FoodMarketplace 集成...');
      
      const FoodMarketplace = await ethers.getContractFactory('FoodMarketplace');
      const foodMarketplace = FoodMarketplace.attach(foodMarketplaceAddress) as any;

      // 1. 在 FoodMarketplace 中设置 UserBalanceManager 地址
      try {
        const currentBalanceManager = await foodMarketplace.balanceManager();
        if (currentBalanceManager.toLowerCase() !== userBalanceManagerAddress.toLowerCase()) {
          console.log('  - 设置 FoodMarketplace 的 BalanceManager...');
          const tx1 = await foodMarketplace.setBalanceManager(userBalanceManagerAddress);
          await tx1.wait();
          console.log('  ✅ FoodMarketplace BalanceManager 已设置');
        } else {
          console.log('  ✅ FoodMarketplace BalanceManager 已经正确设置');
        }
      } catch (error) {
        console.log('  ❌ 设置 FoodMarketplace BalanceManager 失败，可能是旧版本合约');
      }

      // 2. 在 UserBalanceManager 中授权 FoodMarketplace
      const isFoodAuthorized = await userBalanceManager.authorizedContracts(foodMarketplaceAddress);
      if (!isFoodAuthorized) {
        console.log('  - 授权 FoodMarketplace 访问 UserBalanceManager...');
        const tx2 = await userBalanceManager.setAuthorizedContract(foodMarketplaceAddress, true);
        await tx2.wait();
        console.log('  ✅ FoodMarketplace 已被授权');
      } else {
        console.log('  ✅ FoodMarketplace 已经被授权');
      }

      configuredCount++;
    } else {
      console.log('\n⚠️  FoodMarketplace 未部署，跳过配置');
    }

    // 验证配置
    console.log('\n🔍 验证配置...');
    const authorizedContracts = [];
    
    if (packMarketplaceAddress) {
      const isAuthorized = await userBalanceManager.authorizedContracts(packMarketplaceAddress);
      authorizedContracts.push(`PackMarketplace: ${isAuthorized ? '✅' : '❌'}`);
    }
    
    if (foodMarketplaceAddress) {
      const isAuthorized = await userBalanceManager.authorizedContracts(foodMarketplaceAddress);
      authorizedContracts.push(`FoodMarketplace: ${isAuthorized ? '✅' : '❌'}`);
    }

    console.log('授权状态:');
    authorizedContracts.forEach(status => console.log(`  ${status}`));

    console.log('\n✅ UserBalanceManager 集成配置完成!');
    console.log(`已配置 ${configuredCount} 个合约的集成`);

    // 使用指南
    console.log('\n📝 部署新合约时的配置指南:');
    console.log('1. PackMarketplace 初始化参数应包含 UserBalanceManager 地址');
    console.log('2. FoodMarketplace 初始化参数应包含 UserBalanceManager 地址');
    console.log('3. 新部署的合约需要在 UserBalanceManager 中获得授权');
    console.log('\n📊 数据迁移提醒:');
    console.log('- 如果需要从旧合约迁移用户余额数据，请使用 UserBalanceManager 的紧急迁移功能');
    console.log('- 迁移完成后，旧合约的余额数据可以被清理');

  } catch (error) {
    console.error('❌ 配置过程中发生错误:', error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('UserBalanceManager 集成配置失败:', error);
    process.exit(1);
  });