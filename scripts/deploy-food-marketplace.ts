import { ethers, network, upgrades } from 'hardhat';
import { ContractAddressManager } from './utils/ContractAddressManager';

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`部署 FoodMarketplace 系统到 ${networkName} 网络...`);

  // 获取部署者钱包
  const [deployer] = await ethers.getSigners();
  console.log(`部署者地址: ${deployer.address}`);

  const treasury = deployer.address;
  console.log(`财政金库地址: ${treasury}`);

  try {
    // 第一步：部署 FoodNFT
    console.log('\n🚀 步骤1: 部署 FoodNFT...');
    const FoodNFTFactory = await ethers.getContractFactory('FoodNFT');
    const foodNFT = await upgrades.deployProxy(FoodNFTFactory, [], {
      initializer: 'initialize',
      kind: 'uups',
    });
    await foodNFT.waitForDeployment();
    const foodNFTAddress = await foodNFT.getAddress();
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
    console.log(`   ⏸️ 暂停1秒以避免网络拥堵...`);
    await new Promise((resolve) => setTimeout(resolve, 1000));

    // 第二步：部署 FoodMarketplace
    console.log('\n🚀 步骤2: 部署 FoodMarketplace...');

    // FoodMarketplace 配置参数
    const marketplaceConfig = {
      foodNFTAddress: foodNFTAddress,
      treasuryAddress: treasury,
      initialFoodPrice: ethers.parseEther('0.0005'), // 初始食物价格 0.0005 ETH
    };

    console.log('\n📋 Marketplace 配置:');
    console.log(`FoodNFT 地址: ${marketplaceConfig.foodNFTAddress}`);
    console.log(`Treasury 地址: ${marketplaceConfig.treasuryAddress}`);
    console.log(`初始食物价格: ${ethers.formatEther(marketplaceConfig.initialFoodPrice)} ETH`);

    const FoodMarketplaceFactory = await ethers.getContractFactory('FoodMarketplace');
    const foodMarketplace = await upgrades.deployProxy(
      FoodMarketplaceFactory,
      [marketplaceConfig.foodNFTAddress, marketplaceConfig.treasuryAddress],
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

    // 第三步：配置 FoodNFT 权限
    console.log('\n🔧 步骤3: 配置 FoodNFT 授权...');

    const isAuthorized = await (foodNFT as any).authorizedCallers(foodMarketplaceAddress);

    if (!isAuthorized) {
      const tx = await (foodNFT as any).setAuthorizedCaller(foodMarketplaceAddress, true);
      await tx.wait();
      console.log('✅ FoodMarketplace 已获得 FoodNFT 铸造权限');
    } else {
      console.log('✅ FoodMarketplace 已经有 FoodNFT 铸造权限');
    }
    console.log(`   ⏸️ 暂停1秒以避免网络拥堵...`);
    await new Promise((resolve) => setTimeout(resolve, 1000));

    // 第四步：设置 FoodMarketplace 初始配置
    console.log('\n🔧 步骤4: 配置 FoodMarketplace 初始参数...');

    // 设置食物价格
    const priceTx = await (foodMarketplace as any).updatePrice(marketplaceConfig.initialFoodPrice);
    await priceTx.wait();
    console.log(`✅ 食物价格已设置: ${ethers.formatEther(marketplaceConfig.initialFoodPrice)} ETH`);

    // 保存 FoodMarketplace 合约地址
    addressManager.saveContractAddress(networkName, 'FoodMarketplace', foodMarketplaceAddress, {
      deployer: deployer.address,
      deploymentMode: 'upgradeable',
      proxyType: 'UUPS',
      initParams: [marketplaceConfig.foodNFTAddress, marketplaceConfig.treasuryAddress],
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
    console.log(`Treasury: ${treasury}`);
    console.log(`初始食物价格: ${ethers.formatEther(marketplaceConfig.initialFoodPrice)} ETH`);

    // 使用指南
    console.log('\n📝 后续配置建议:');
    console.log('1. 设置推荐系统合约地址: foodMarketplace.setReferralV2(referralAddress)');
    console.log('2. 设置Relayer地址(如需要): foodMarketplace.setRelayerAddress(relayerAddress)');
    console.log('3. 向合约充值ETH作为回收资金池: foodMarketplace.depositETH({value: amount})');
    console.log('4. 根据需要调整token序列: foodMarketplace.setTokenSequence([...])');
    console.log('5. 在FoodNFT中初始化食物配置');
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
