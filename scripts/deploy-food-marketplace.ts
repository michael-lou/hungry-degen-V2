import { ethers, network, upgrades } from 'hardhat';
import { ContractAddressManager } from './utils/ContractAddressManager';

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`部署 FoodMarketplace 系统到 ${networkName} 网络...`);

  // 获取部署者钱包
  const [deployer] = await ethers.getSigners();
  console.log(`部署者地址: ${deployer.address}`);

  const treasury = '0x888Ce07575185Fe5b148b368634b12B0813e92e7';//deployer.address;
  console.log(`财政金库地址: ${treasury}`);

  try {
    // 第一步：检查并部署 FoodNFT
    console.log('\n🔍 步骤1: 检查 FoodNFT 部署状态...');
    
    let foodNFTAddress: string;
    const existingFoodNFT = addressManager.getContractAddress(networkName, 'FoodNFT');
    
    if (existingFoodNFT) {
      console.log(`✅ FoodNFT 已存在: ${existingFoodNFT.address}`);
      foodNFTAddress = existingFoodNFT.address;
    } else {
      console.log('\n🚀 部署 FoodNFT...');
      const FoodNFTFactory = await ethers.getContractFactory('FoodNFT');
      const foodNFT = await upgrades.deployProxy(FoodNFTFactory, [], {
        initializer: 'initialize',
        kind: 'uups',
      });
      await foodNFT.waitForDeployment();
      foodNFTAddress = await foodNFT.getAddress();
      console.log(`✅ FoodNFT 已部署 (可升级): ${foodNFTAddress}`);

      // 保存 FoodNFT 合约地址
      addressManager.saveContractAddress(networkName, 'FoodNFT', foodNFTAddress, {
        deployer: deployer.address,
        deploymentMode: 'upgradeable',
        proxyType: 'UUPS',
        initParams: [],
        description: 'Food NFT contract for the marketplace',
      });

      console.log('\n✅ FoodNFT 部署完成!');
      console.log(`   ⏸️ 暂停3秒以避免网络拥堵...`);
      await new Promise((resolve) => setTimeout(resolve, 3000));
    }

    // 第二步：检查 UserBalanceManager 依赖
    console.log('\n🔍 步骤2: 检查 UserBalanceManager 依赖...');
    const balanceManagerInfo = addressManager.getContractAddress(networkName, 'UserBalanceManager');
    if (!balanceManagerInfo) {
      throw new Error('UserBalanceManager 尚未部署。请先运行 deploy-UserBalanceManager.ts');
    }
    const balanceManagerAddress = balanceManagerInfo.address;
    console.log(`✅ UserBalanceManager 已部署: ${balanceManagerAddress}`);

    // 第三步：部署 FoodMarketplace
    console.log('\n🚀 步骤3: 部署 FoodMarketplace...');

    // FoodMarketplace 配置参数
    const marketplaceConfig = {
      foodNFTAddress: foodNFTAddress,
      treasuryAddress: treasury,
      balanceManagerAddress: balanceManagerAddress,
      initialFoodPrice: ethers.parseEther('0.0005'), // 初始食物价格 0.0005 ETH
    };

    console.log('\n📋 Marketplace 配置:');
    console.log(`FoodNFT 地址: ${marketplaceConfig.foodNFTAddress}`);
    console.log(`Treasury 地址: ${marketplaceConfig.treasuryAddress}`);
    console.log(`BalanceManager 地址: ${marketplaceConfig.balanceManagerAddress}`);
    console.log(`初始食物价格: ${ethers.formatEther(marketplaceConfig.initialFoodPrice)} ETH`);

    const FoodMarketplaceFactory = await ethers.getContractFactory('FoodMarketplace');
    const foodMarketplace = await upgrades.deployProxy(
      FoodMarketplaceFactory,
      [
        marketplaceConfig.foodNFTAddress, 
        marketplaceConfig.treasuryAddress,
        marketplaceConfig.balanceManagerAddress
      ],
      {
        initializer: 'initialize',
        kind: 'uups',
      }
    );

    await foodMarketplace.waitForDeployment();
    const foodMarketplaceAddress = await foodMarketplace.getAddress();
    console.log(`✅ FoodMarketplace 已部署 (可升级): ${foodMarketplaceAddress}`);
    console.log(`   ⏸️ 暂停1秒以避免网络拥堵...`);
    await new Promise((resolve) => setTimeout(resolve, 1000));

    // 第四步：配置 FoodNFT 权限
    console.log('\n🔧 步骤4: 配置 FoodNFT 授权...');

    // 连接到 FoodNFT 合约
    const FoodNFTFactory = await ethers.getContractFactory('FoodNFT');
    const foodNFT = FoodNFTFactory.attach(foodNFTAddress) as any;

    try {
      const isAuthorized = await foodNFT.authorizedCallers(foodMarketplaceAddress);
      
      if (!isAuthorized) {
        console.log('   设置 FoodMarketplace 为 FoodNFT 授权调用者...');
        const tx = await foodNFT.setAuthorizedCaller(foodMarketplaceAddress, true);
        await tx.wait();
        console.log('✅ FoodMarketplace 已获得 FoodNFT 铸造权限');
      } else {
        console.log('✅ FoodMarketplace 已经有 FoodNFT 铸造权限');
      }
    } catch (error) {
      console.log('⚠️  无法检查授权状态，直接设置权限...');
      try {
        const tx = await foodNFT.setAuthorizedCaller(foodMarketplaceAddress, true);
        await tx.wait();
        console.log('✅ FoodMarketplace 已获得 FoodNFT 铸造权限');
      } catch (authError) {
        console.log('❌ 设置权限失败，请手动配置:', authError);
      }
    }
    console.log(`   ⏸️ 暂停1秒以避免网络拥堵...`);
    await new Promise((resolve) => setTimeout(resolve, 1000));

    // 第五步：设置 FoodMarketplace 初始配置
    console.log('\n🔧 步骤5: 配置 FoodMarketplace 初始参数...');

    // 设置食物价格
    const priceTx = await (foodMarketplace as any).updatePrice(marketplaceConfig.initialFoodPrice);
    await priceTx.wait();
    console.log(`✅ 食物价格已设置: ${ethers.formatEther(marketplaceConfig.initialFoodPrice)} ETH`);

    // 保存 FoodMarketplace 合约地址
    addressManager.saveContractAddress(networkName, 'FoodMarketplace', foodMarketplaceAddress, {
      deployer: deployer.address,
      deploymentMode: 'upgradeable',
      proxyType: 'UUPS',
      initParams: [
        marketplaceConfig.foodNFTAddress, 
        marketplaceConfig.treasuryAddress,
        marketplaceConfig.balanceManagerAddress
      ],
      config: {
        initialFoodPrice: marketplaceConfig.initialFoodPrice.toString(),
      },
      description: 'Food Marketplace contract with NFT integration',
    });

    console.log('\n✅ FoodMarketplace 部署和配置完成!');

    // 打印最终部署摘要
    console.log('\n📋 最终部署摘要:');
    console.log(`网络: ${networkName}`);
    console.log(`部署者: ${deployer.address}`);
    console.log(`FoodNFT: ${foodNFTAddress}`);
    console.log(`FoodMarketplace: ${foodMarketplaceAddress}`);
    console.log(`UserBalanceManager: ${balanceManagerAddress}`);
    console.log(`Treasury: ${treasury}`);
    console.log(`初始食物价格: ${ethers.formatEther(marketplaceConfig.initialFoodPrice)} ETH`);

    // 使用指南
    console.log('\n📝 后续配置建议:');
    console.log('1. 运行 setup-UserBalanceManager-integration.ts 完成集成配置');
    console.log('2. 设置推荐系统合约地址: foodMarketplace.setReferralV2(referralAddress)');
    console.log('3. 设置Relayer地址(如需要): foodMarketplace.setRelayerAddress(relayerAddress)');
    console.log('4. 向合约充值ETH作为回收资金池: foodMarketplace.depositETH({value: amount})');
    console.log('5. 根据需要调整token序列: foodMarketplace.setTokenSequence([...])');
    console.log('6. 在FoodNFT中初始化食物配置');
  } catch (error) {
    console.error('❌ 部署过程中发生错误:', error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('FoodMarketplace 部署脚本执行失败:', error);
    process.exit(1);
  });