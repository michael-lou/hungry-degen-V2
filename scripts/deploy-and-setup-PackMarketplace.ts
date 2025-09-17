import { ethers, network, upgrades } from 'hardhat';
import { ContractAddressManager } from './utils/ContractAddressManager';

// 添加延迟函数，在测试网部署时避免交易冲突
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`部署并配置 PackMarketplace 生态系统到 ${networkName} 网络...`);

  // 获取部署者钱包
  const [deployer] = await ethers.getSigners();
  console.log(`部署者地址: ${deployer.address}`);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(`部署者余额: ${ethers.formatEther(balance)} ETH`);

  const treasury = '0x888Ce07575185Fe5b148b368634b12B0813e92e7'; // 统一财政金库地址
  console.log(`财政金库地址: ${treasury}`);

  try {
    // 检查依赖合约
    const contracts = addressManager.getAllContractAddresses(networkName) || {};
    const dustTokenAddress = contracts['DUSTToken'];
    const referralV2Address = contracts['ReferralV2'];
    const userBalanceManagerAddress = contracts['UserBalanceManager'];

    console.log('\n📋 检查依赖合约:');
    console.log(`DUSTToken: ${dustTokenAddress || '未部署'}`);
    console.log(`ReferralV2: ${referralV2Address || '未部署'}`);
    console.log(`UserBalanceManager: ${userBalanceManagerAddress || '未部署'}`);

    if (!dustTokenAddress) {
      console.log('⚠️  DUSTToken 未部署，将使用零地址（可能影响功能）');
    }

    if (!userBalanceManagerAddress) {
      throw new Error('UserBalanceManager 未部署，请先运行: npx hardhat run scripts/deploy-UserBalanceManager.ts');
    }

    // 检查现有合约并声明变量
    const existingCoreNFT = contracts['CoreNFT'];
    const existingFlexNFT = contracts['FlexNFT'];
    const existingPackMetadataStorage = contracts['PackMetadataStorage'];
    const existingRarityManager = contracts['RarityManager'];
    const existingPackMarketplace = contracts['PackMarketplace'];

    let coreNFTAddress: string;
    let flexNFTAddress: string;
    let packMetadataStorageAddress: string;
    let rarityManagerAddress: string;

    // 1. 检查并部署 RarityManager (标准合约)
    if (!existingRarityManager) {
      console.log('\n🚀 部署 RarityManager...');
      const RarityManagerFactory = await ethers.getContractFactory('RarityManager');
      const rarityManager = await RarityManagerFactory.deploy();
      await rarityManager.waitForDeployment();
      
      rarityManagerAddress = await rarityManager.getAddress();
      console.log(`✅ RarityManager 已部署: ${rarityManagerAddress}`);

      // 保存地址
      addressManager.saveContractAddress(networkName, 'RarityManager', rarityManagerAddress, {
        deployer: deployer.address,
        deploymentMode: 'standard',
        initParams: [],
        metadata: {
          description: 'RarityManager - Manages rarity configurations for NFTs',
        },
        deployedAt: new Date().toISOString(),
      });

      await delay(2000);
    } else {
      console.log(`\n✅ RarityManager 已存在: ${existingRarityManager}`);
      rarityManagerAddress = existingRarityManager;
    }

    // 2. 检查并部署 PackMetadataStorage (可升级)
    if (!existingPackMetadataStorage) {
      console.log('\n🚀 部署 PackMetadataStorage...');
      const PackMetadataStorageFactory = await ethers.getContractFactory('PackMetadataStorage');
      const packMetadataStorage = await upgrades.deployProxy(PackMetadataStorageFactory, [], {
        initializer: 'initialize',
        kind: 'uups',
      });
      await packMetadataStorage.waitForDeployment();
      
      packMetadataStorageAddress = await packMetadataStorage.getAddress();
      console.log(`✅ PackMetadataStorage 已部署 (可升级): ${packMetadataStorageAddress}`);

      // 保存地址
      addressManager.saveContractAddress(networkName, 'PackMetadataStorage', packMetadataStorageAddress, {
        deployer: deployer.address,
        deploymentMode: 'upgradeable',
        proxyType: 'UUPS',
        initParams: [],
        metadata: {
          description: 'PackMetadataStorage - Metadata storage for pack NFTs',
        },
        deployedAt: new Date().toISOString(),
      });

      await delay(2000);
    } else {
      console.log(`\n✅ PackMetadataStorage 已存在: ${existingPackMetadataStorage}`);
      packMetadataStorageAddress = existingPackMetadataStorage;
    }

    // 3. 检查并部署 CoreNFT (可升级)
    if (!existingCoreNFT) {
      console.log('\n🚀 部署 CoreNFT...');
      const CoreNFTFactory = await ethers.getContractFactory('CoreNFT');
      const coreNFT = await upgrades.deployProxy(CoreNFTFactory, [], {
        initializer: 'initialize',
        kind: 'uups',
      });
      await coreNFT.waitForDeployment();
      
      coreNFTAddress = await coreNFT.getAddress();
      console.log(`✅ CoreNFT 已部署 (可升级): ${coreNFTAddress}`);

      // 保存地址
      addressManager.saveContractAddress(networkName, 'CoreNFT', coreNFTAddress, {
        deployer: deployer.address,
        deploymentMode: 'upgradeable',
        proxyType: 'UUPS',
        initParams: [],
        metadata: {
          description: 'CoreNFT - Core equipment NFTs for HungryDegen game',
        },
        deployedAt: new Date().toISOString(),
      });

      await delay(2000);
    } else {
      console.log(`\n✅ CoreNFT 已存在: ${existingCoreNFT}`);
      coreNFTAddress = existingCoreNFT;
    }

    // 4. 检查并部署 FlexNFT (可升级)
    if (!existingFlexNFT) {
      console.log('\n🚀 部署 FlexNFT...');
      const FlexNFTFactory = await ethers.getContractFactory('FlexNFT');
      const flexNFT = await upgrades.deployProxy(FlexNFTFactory, [], {
        initializer: 'initialize',
        kind: 'uups',
      });
      await flexNFT.waitForDeployment();
      
      flexNFTAddress = await flexNFT.getAddress();
      console.log(`✅ FlexNFT 已部署 (可升级): ${flexNFTAddress}`);

      // 保存地址
      addressManager.saveContractAddress(networkName, 'FlexNFT', flexNFTAddress, {
        deployer: deployer.address,
        deploymentMode: 'upgradeable',
        proxyType: 'UUPS',
        initParams: [],
        metadata: {
          description: 'FlexNFT - Flexible equipment NFTs for HungryDegen game',
        },
        deployedAt: new Date().toISOString(),
      });

      await delay(2000);
    } else {
      console.log(`\n✅ FlexNFT 已存在: ${existingFlexNFT}`);
      flexNFTAddress = existingFlexNFT;
    }

    // 5. 部署 PackMarketplace (可升级)
    if (!existingPackMarketplace) {
      console.log('\n🚀 部署 PackMarketplace...');

      const marketplaceConfig = {
        coreNFT: coreNFTAddress,
        flexNFT: flexNFTAddress,
        rarityManager: rarityManagerAddress,
        referralV2: referralV2Address || ethers.ZeroAddress,
        balanceManager: userBalanceManagerAddress,
        treasury: treasury,
        packMetadataStorage: packMetadataStorageAddress,
      };

      console.log('\n📋 Marketplace 配置:');
      console.log(`CoreNFT: ${marketplaceConfig.coreNFT}`);
      console.log(`FlexNFT: ${marketplaceConfig.flexNFT}`);
      console.log(`RarityManager: ${marketplaceConfig.rarityManager}`);
      console.log(`ReferralV2: ${marketplaceConfig.referralV2}`);
      console.log(`UserBalanceManager: ${marketplaceConfig.balanceManager}`);
      console.log(`Treasury: ${marketplaceConfig.treasury}`);
      console.log(`PackMetadataStorage: ${marketplaceConfig.packMetadataStorage}`);

      const PackMarketplaceFactory = await ethers.getContractFactory('PackMarketplace');
      const packMarketplace = await upgrades.deployProxy(
        PackMarketplaceFactory,
        [
          marketplaceConfig.coreNFT,
          marketplaceConfig.flexNFT,
          marketplaceConfig.rarityManager,
          marketplaceConfig.referralV2,
          marketplaceConfig.balanceManager,
          marketplaceConfig.treasury,
        ],
        {
          initializer: 'initialize',
          kind: 'uups',
        }
      );

      await packMarketplace.waitForDeployment();
      const packMarketplaceAddress = await packMarketplace.getAddress();
      console.log(`✅ PackMarketplace 已部署 (可升级): ${packMarketplaceAddress}`);

      await delay(2000);

      // 6. 配置 DUST 代币
      console.log('\n🔧 配置 DUST 代币...');
      if (dustTokenAddress) {
        try {
          // 设置基础 DUST 代币 (用于 Flex Pack)
          console.log('   设置基础 DUST 代币地址...');
          const setDustTokenTx = await (packMarketplace as any).setDustToken(dustTokenAddress);
          await setDustTokenTx.wait();
          console.log('✅ 基础 DUST 代币已设置');

          // 设置 Gold DUST 代币 (用于 Gold Pack)
          console.log('   设置 Gold DUST 代币地址...');
          const setGoldDustTokenTx = await (packMarketplace as any).setGoldDustToken(dustTokenAddress);
          await setGoldDustTokenTx.wait();
          console.log('✅ Gold DUST 代币已设置');
        } catch (error) {
          console.error('❌ 设置 DUST 代币时出错:', error);
        }
      } else {
        console.log('⚠️  跳过 DUST 代币配置（DUST 代币未部署）');
        console.log('   请在 DUST 代币部署后手动调用:');
        console.log(`   - packMarketplace.setDustToken(dustTokenAddress)`);
        console.log(`   - packMarketplace.setGoldDustToken(dustTokenAddress)`);
      }

      await delay(1000);

      // 7. 配置权限和设置
      console.log('\n🔧 配置权限和关联...');
      
      try {
        // 设置 CoreNFT 权限
        const CoreNFT = await ethers.getContractFactory('CoreNFT');
        const coreNFT = CoreNFT.attach(coreNFTAddress) as any;
        
        const isCoreAuthorized = await coreNFT.authorizedCallers(packMarketplaceAddress);
        if (!isCoreAuthorized) {
          console.log('   设置 PackMarketplace 为 CoreNFT 授权调用者...');
          const authTx = await coreNFT.setAuthorizedCaller(packMarketplaceAddress, true);
          await authTx.wait();
          console.log('✅ PackMarketplace 已获得 CoreNFT 权限');
        } else {
          console.log('✅ PackMarketplace 已经有 CoreNFT 权限');
        }

        await delay(1000);

        // 设置 FlexNFT 权限
        const FlexNFT = await ethers.getContractFactory('FlexNFT');
        const flexNFT = FlexNFT.attach(flexNFTAddress) as any;
        
        const isFlexAuthorized = await flexNFT.authorizedCallers(packMarketplaceAddress);
        if (!isFlexAuthorized) {
          console.log('   设置 PackMarketplace 为 FlexNFT 授权调用者...');
          const authTx = await flexNFT.setAuthorizedCaller(packMarketplaceAddress, true);
          await authTx.wait();
          console.log('✅ PackMarketplace 已获得 FlexNFT 权限');
        } else {
          console.log('✅ PackMarketplace 已经有 FlexNFT 权限');
        }

        await delay(1000);

        // 设置 PackMetadataStorage
        try {
          const PackMetadataStorage = await ethers.getContractFactory('PackMetadataStorage');
          const packMetadataStorage = PackMetadataStorage.attach(packMetadataStorageAddress) as any;
          
          const setPackMetadataTx = await (packMarketplace as any).setPackMetadataStorage(packMetadataStorageAddress);
          await setPackMetadataTx.wait();
          console.log('✅ PackMetadataStorage 已关联');
        } catch (error) {
          console.log('⚠️  PackMetadataStorage 关联可能失败，请手动设置');
        }

      } catch (error) {
        console.error('权限配置过程中出错:', error);
      }

      // 8. 验证配置
      console.log('\n🔍 验证配置...');
      try {
        const coreNFTAddr = await packMarketplace.coreNFT();
        const flexNFTAddr = await packMarketplace.flexNFT();
        const dustTokenAddr = await packMarketplace.dustToken();
        const goldDustTokenAddr = await packMarketplace.goldDustToken();
        const treasuryAddr = await packMarketplace.treasury();
        
        console.log(`CoreNFT 地址: ${coreNFTAddr}`);
        console.log(`FlexNFT 地址: ${flexNFTAddr}`);
        console.log(`DUSTToken 地址: ${dustTokenAddr}`);
        console.log(`GoldDUSTToken 地址: ${goldDustTokenAddr}`);
        console.log(`Treasury 地址: ${treasuryAddr}`);
        console.log(`📝 注意: Core 和 Flex Pack 的价格配置将使用合约默认值，管理员可后续调整`);
      } catch (error) {
        console.error('验证配置时出错:', error);
      }

      // 保存 PackMarketplace 地址
      addressManager.saveContractAddress(networkName, 'PackMarketplace', packMarketplaceAddress, {
        deployer: deployer.address,
        deploymentMode: 'upgradeable',
        proxyType: 'UUPS',
        initParams: [
          marketplaceConfig.coreNFT,
          marketplaceConfig.flexNFT,
          marketplaceConfig.rarityManager,
          marketplaceConfig.referralV2,
          marketplaceConfig.balanceManager,
          marketplaceConfig.treasury,
        ],
        metadata: {
          description: 'PackMarketplace - Marketplace for pack NFTs with CoreNFT and FlexNFT support and UserBalanceManager integration',
          usesDefaultPricing: true,
          usesUserBalanceManager: true,
        },
        deployedAt: new Date().toISOString(),
      });

      console.log('\n✅ PackMarketplace 生态系统部署和配置完成!');

      // 打印完整部署摘要
      console.log('\n📋 完整部署摘要:');
      console.log(`网络: ${networkName}`);
      console.log(`部署者: ${deployer.address}`);
      console.log(`RarityManager: ${rarityManagerAddress}`);
      console.log(`PackMetadataStorage: ${packMetadataStorageAddress}`);
      console.log(`CoreNFT: ${coreNFTAddress}`);
      console.log(`FlexNFT: ${flexNFTAddress}`);
      console.log(`PackMarketplace: ${packMarketplaceAddress}`);
      console.log(`财政金库: ${treasury}`);

      // 后续配置建议
      console.log('\n📝 后续配置建议:');
      if (!dustTokenAddress) {
        console.log('🔴 重要: DUST 代币配置');
        console.log('   在 DUST 代币部署后，请手动配置:');
        console.log(`   - packMarketplace.setDustToken(dustTokenAddress)`);
        console.log(`   - packMarketplace.setGoldDustToken(dustTokenAddress)`);
      }
      console.log('1. 运行 setup-UserBalanceManager-integration.ts 完成用户余额管理集成');
      console.log('2. 根据需要调整包裹价格: updatePackPrice()');
      console.log('3. 根据需要调整 DUST 价格: updateFlexPackDustPrice() / updateGoldPackPrice()');
      console.log('4. 设置包裹元数据: setPackMetadataStorage()');
      console.log('5. 配置稀有度权重: 在 RarityManager 中设置稀有度概率');
    } else {
      console.log(`\n⚠️  PackMarketplace 已存在: ${existingPackMarketplace}`);
      console.log('如需重新部署，请先删除地址管理器中的记录');
    }

  } catch (error) {
    console.error('\n❌ 部署过程中发生错误:', error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('部署脚本执行失败:', error);
    process.exit(1);
  });