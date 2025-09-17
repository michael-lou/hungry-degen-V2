import { ethers, network, upgrades } from 'hardhat';
import { ContractAddressManager } from './utils/ContractAddressManager';

// 添加延迟函数，在测试网部署时避免交易冲突
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`部署并配置 CharacterNFT 和 CharacterNFTSale 合约到 ${networkName} 网络...`);

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

    console.log('\n📋 检查依赖合约:');
    console.log(`DUSTToken: ${dustTokenAddress || '未部署'}`);
    console.log(`ReferralV2: ${referralV2Address || '未部署'}`);

    if (!dustTokenAddress) {
      console.log('⚠️  DUSTToken 未部署，将使用零地址（可能影响功能）');
    }
    if (!referralV2Address) {
      console.log('⚠️  ReferralV2 未部署，将使用零地址（可能影响推荐功能）');
    }

    // 检查是否已经部署过
    const existingCharacterNFT = contracts['CharacterNFT'];
    const existingCharacterNFTSale = contracts['CharacterNFTSale'];

    if (existingCharacterNFT && existingCharacterNFTSale) {
      console.log(`⚠️  CharacterNFT 和 CharacterNFTSale 已在此网络部署:`);
      console.log(`CharacterNFT: ${existingCharacterNFT}`);
      console.log(`CharacterNFTSale: ${existingCharacterNFTSale}`);
      console.log('如需重新部署，请先删除地址管理器中的记录');
      return;
    }

    let characterNFTAddress = existingCharacterNFT;

    // 1. 检查并部署 CharacterNFT (如果尚未部署)
    if (!characterNFTAddress) {
      console.log('\n🚀 部署 CharacterNFT...');
      const CharacterNFTFactory = await ethers.getContractFactory('CharacterNFT');
      const characterNFT = await upgrades.deployProxy(CharacterNFTFactory, [], {
        initializer: 'initialize',
        kind: 'uups',
      });
      await characterNFT.waitForDeployment();
      
      characterNFTAddress = await characterNFT.getAddress();
      console.log(`✅ CharacterNFT 已部署 (可升级): ${characterNFTAddress}`);

      // 保存 CharacterNFT 地址
      addressManager.saveContractAddress(networkName, 'CharacterNFT', characterNFTAddress, {
        deployer: deployer.address,
        deploymentMode: 'upgradeable',
        proxyType: 'UUPS',
        initParams: [],
        metadata: {
          description: 'CharacterNFT - Character collection for HungryDegen game',
        },
        deployedAt: new Date().toISOString(),
      });

      await delay(2000);
    } else {
      console.log(`\n✅ CharacterNFT 已存在: ${characterNFTAddress}`);
    }

    // 2. 部署 CharacterNFTSale
    if (!existingCharacterNFTSale) {
      console.log('\n🚀 部署 CharacterNFTSale...');
      
      // CharacterNFTSale 配置参数
      const saleConfig = {
        characterNFT: characterNFTAddress,
        price: ethers.parseEther('0.01'), // 0.01 ETH per NFT
        treasury: treasury,
        referralV2: referralV2Address || ethers.ZeroAddress,
      };

      console.log('\n📋 CharacterNFTSale 配置:');
      console.log(`CharacterNFT 地址: ${saleConfig.characterNFT}`);
      console.log(`销售价格: ${ethers.formatEther(saleConfig.price)} ETH`);
      console.log(`财政金库: ${saleConfig.treasury}`);
      console.log(`推荐系统: ${saleConfig.referralV2 === ethers.ZeroAddress ? '未配置' : saleConfig.referralV2}`);

      const CharacterNFTSaleFactory = await ethers.getContractFactory('CharacterNFTSale');
      const characterNFTSale = await upgrades.deployProxy(
        CharacterNFTSaleFactory,
        [
          saleConfig.characterNFT,
          saleConfig.price,
          saleConfig.treasury,
          saleConfig.referralV2,
        ],
        {
          initializer: 'initialize',
          kind: 'uups',
        }
      );

      await characterNFTSale.waitForDeployment();
      const characterNFTSaleAddress = await characterNFTSale.getAddress();
      console.log(`✅ CharacterNFTSale 已部署 (可升级): ${characterNFTSaleAddress}`);

      await delay(2000);

      // 3. 配置权限和设置
      console.log('\n🔧 配置 CharacterNFT 权限...');
      
      const CharacterNFT = await ethers.getContractFactory('CharacterNFT');
      const characterNFT = CharacterNFT.attach(characterNFTAddress) as any;

      // 检查并设置授权
      try {
        const isAuthorized = await characterNFT.authorizedCallers(characterNFTSaleAddress);
        
        if (!isAuthorized) {
          console.log('   设置 CharacterNFTSale 为授权铸造者...');
          const authTx = await characterNFT.setAuthorizedCaller(characterNFTSaleAddress, true);
          await authTx.wait();
          console.log('✅ CharacterNFTSale 已获得 CharacterNFT 铸造权限');
          await delay(1000);
        } else {
          console.log('✅ CharacterNFTSale 已经有 CharacterNFT 铸造权限');
        }
      } catch (error) {
        console.error('❌ 设置权限时出错:', error);
      }

      // 验证配置
      console.log('\n🔍 验证配置...');
      try {
        const price = await characterNFTSale.price();
        const treasury = await characterNFTSale.treasury();
        
        console.log(`销售价格: ${ethers.formatEther(price)} ETH`);
        console.log(`财政金库: ${treasury}`);
        console.log(`📝 注意: NFT 的铸造和销售队列配置需要管理员手动操作`);
      } catch (error) {
        console.error('验证配置时出错:', error);
      }

      // 保存 CharacterNFTSale 地址
      addressManager.saveContractAddress(networkName, 'CharacterNFTSale', characterNFTSaleAddress, {
        deployer: deployer.address,
        deploymentMode: 'upgradeable',
        proxyType: 'UUPS',
        characterNFT: characterNFTAddress,
        price: saleConfig.price.toString(),
        treasury: saleConfig.treasury,
        referralV2: saleConfig.referralV2,
        initParams: [
          characterNFTAddress,
          saleConfig.price.toString(),
          saleConfig.treasury,
          saleConfig.referralV2,
        ],
        metadata: {
          description: 'CharacterNFTSale - Character NFT sales contract',
          initialTokensForSale: 10,
          saleActive: true,
        },
        deployedAt: new Date().toISOString(),
      });

      console.log('\n✅ CharacterNFTSale 部署和配置完成!');

      // 打印部署摘要
      console.log('\n📋 部署摘要:');
      console.log(`网络: ${networkName}`);
      console.log(`部署者: ${deployer.address}`);
      console.log(`CharacterNFT: ${characterNFTAddress}`);
      console.log(`CharacterNFTSale: ${characterNFTSaleAddress}`);
      console.log(`销售价格: ${ethers.formatEther(saleConfig.price)} ETH`);
      console.log(`财政金库: ${saleConfig.treasury}`);
    } else {
      console.log(`\n⚠️  CharacterNFTSale 已存在: ${existingCharacterNFTSale}`);
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