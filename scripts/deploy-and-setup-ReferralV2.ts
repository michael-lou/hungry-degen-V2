import { ethers, network, upgrades } from 'hardhat';
import { ContractAddressManager } from './utils/ContractAddressManager';

// 添加延迟函数，在测试网部署时避免交易冲突
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`部署并配置 ReferralV2 系统到 ${networkName} 网络...`);

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

    console.log('\n📋 检查依赖合约:');
    console.log(`DUSTToken: ${dustTokenAddress || '未部署'}`);

    if (!dustTokenAddress) {
      throw new Error('DUSTToken 地址未找到，请先部署 DUSTToken');
    }

    // 检查现有合约
    const existingGoldDXPToken = contracts['GoldDXPToken'];
    const existingSilverDXPToken = contracts['SilverDXPToken'];
    const existingReferralV2 = contracts['ReferralV2'];

    let goldDXPTokenAddress = existingGoldDXPToken;
    let silverDXPTokenAddress = existingSilverDXPToken;

    // 1. 部署 GoldDXPToken (可升级)
    if (!goldDXPTokenAddress) {
      console.log('\n🚀 部署 GoldDXPToken...');
      const GoldDXPTokenFactory = await ethers.getContractFactory('GoldDXPToken');
      const goldDXPToken = await upgrades.deployProxy(GoldDXPTokenFactory, [], {
        initializer: 'initialize',
        kind: 'uups',
      });
      await goldDXPToken.waitForDeployment();
      
      goldDXPTokenAddress = await goldDXPToken.getAddress();
      console.log(`✅ GoldDXPToken 已部署 (可升级): ${goldDXPTokenAddress}`);

      // 获取代币信息
      const name = await goldDXPToken.name();
      const symbol = await goldDXPToken.symbol();
      const decimals = await goldDXPToken.decimals();

      // 保存地址
      addressManager.saveContractAddress(networkName, 'GoldDXPToken', goldDXPTokenAddress, {
        deployer: deployer.address,
        deploymentMode: 'upgradeable',
        proxyType: 'UUPS',
        initParams: [],
        metadata: {
          description: 'GoldDXPToken - Gold experience points token for referral rewards',
          name: name,
          symbol: symbol,
          decimals: Number(decimals),
        },
        deployedAt: new Date().toISOString(),
      });

      await delay(2000);
    } else {
      console.log(`\n✅ GoldDXPToken 已存在: ${goldDXPTokenAddress}`);
    }

    // 2. 部署 SilverDXPToken (可升级)
    if (!silverDXPTokenAddress) {
      console.log('\n🚀 部署 SilverDXPToken...');
      const SilverDXPTokenFactory = await ethers.getContractFactory('SilverDXPToken');
      const silverDXPToken = await upgrades.deployProxy(SilverDXPTokenFactory, [], {
        initializer: 'initialize',
        kind: 'uups',
      });
      await silverDXPToken.waitForDeployment();
      
      silverDXPTokenAddress = await silverDXPToken.getAddress();
      console.log(`✅ SilverDXPToken 已部署 (可升级): ${silverDXPTokenAddress}`);

      // 获取代币信息
      const name = await silverDXPToken.name();
      const symbol = await silverDXPToken.symbol();
      const decimals = await silverDXPToken.decimals();

      // 保存地址
      addressManager.saveContractAddress(networkName, 'SilverDXPToken', silverDXPTokenAddress, {
        deployer: deployer.address,
        deploymentMode: 'upgradeable',
        proxyType: 'UUPS',
        initParams: [],
        metadata: {
          description: 'SilverDXPToken - Silver experience points token for referral rewards',
          name: name,
          symbol: symbol,
          decimals: Number(decimals),
        },
        deployedAt: new Date().toISOString(),
      });

      await delay(2000);
    } else {
      console.log(`\n✅ SilverDXPToken 已存在: ${silverDXPTokenAddress}`);
    }

    // 3. 部署 ReferralV2 (可升级)
    if (!existingReferralV2) {
      console.log('\n🚀 部署 ReferralV2...');
      
      // ReferralV2 配置参数
      const referralConfig = {
        admin: deployer.address,
        dustToken: dustTokenAddress,
        goldDXPToken: goldDXPTokenAddress,
        silverDXPToken: silverDXPTokenAddress,
        vrfSystem: ethers.ZeroAddress, // 暂时不使用 VRF 系统
        treasury: treasury,
      };

      console.log('\n📋 ReferralV2 配置:');
      console.log(`管理员: ${referralConfig.admin}`);
      console.log(`DUSTToken: ${referralConfig.dustToken}`);
      console.log(`GoldDXPToken: ${referralConfig.goldDXPToken}`);
      console.log(`SilverDXPToken: ${referralConfig.silverDXPToken}`);
      console.log(`VRF 系统: ${referralConfig.vrfSystem === ethers.ZeroAddress ? '未配置' : referralConfig.vrfSystem}`);
      console.log(`财政金库: ${referralConfig.treasury}`);

      const ReferralV2Factory = await ethers.getContractFactory('ReferralV2');
      const referralV2 = await upgrades.deployProxy(
        ReferralV2Factory,
        [
          referralConfig.admin,
          referralConfig.dustToken,
          referralConfig.goldDXPToken,
          referralConfig.silverDXPToken,
          referralConfig.vrfSystem,
          referralConfig.treasury,
        ],
        {
          initializer: 'initialize',
          kind: 'uups',
        }
      );

      await referralV2.waitForDeployment();
      const referralV2Address = await referralV2.getAddress();
      console.log(`✅ ReferralV2 已部署 (可升级): ${referralV2Address}`);

      await delay(2000);

      // 4. 配置权限和设置
      console.log('\n🔧 配置权限和推荐参数...');
      
      try {
        // 设置 DXP Token 权限
        const GoldDXPToken = await ethers.getContractFactory('GoldDXPToken');
        const goldDXPToken = GoldDXPToken.attach(goldDXPTokenAddress) as any;
        
        console.log('   设置 ReferralV2 为 GoldDXPToken 铸造者...');
        const goldMinterTx = await goldDXPToken.setMinterAuthorization(referralV2Address, true);
        await goldMinterTx.wait();
        console.log('✅ ReferralV2 已获得 GoldDXPToken 铸造权限');
        await delay(1000);

        const SilverDXPToken = await ethers.getContractFactory('SilverDXPToken');
        const silverDXPToken = SilverDXPToken.attach(silverDXPTokenAddress) as any;
        
        console.log('   设置 ReferralV2 为 SilverDXPToken 铸造者...');
        const silverMinterTx = await silverDXPToken.setMinterAuthorization(referralV2Address, true);
        await silverMinterTx.wait();
        console.log('✅ ReferralV2 已获得 SilverDXPToken 铸造权限');
        await delay(1000);

        // 配置推荐奖励参数
        console.log('   配置推荐奖励参数...');
        
        // 设置各产品类型的佣金率 (使用 ProductType 枚举)
        const productCommissions = [
          { type: 0, rate: 25, name: 'FOOD_PACK (0.25%)' },      // 0.25%
          { type: 1, rate: 500, name: 'CORE_PACK (5%)' },        // 5%
          { type: 2, rate: 500, name: 'FLEX_PACK (5%)' },        // 5%
          { type: 3, rate: 500, name: 'FLEX_PACK_DUST (5%)' },   // 5%
          { type: 4, rate: 1200, name: 'CHARACTER_NFT (12%)' },  // 12%
          { type: 5, rate: 1200, name: 'BLACKGHOST_NFT (12%)' }, // 12%
        ];

        for (const product of productCommissions) {
          try {
            console.log(`   设置 ${product.name} 佣金率`);
            const setCommissionTx = await referralV2.setCommissionRate(product.type, product.rate);
            await setCommissionTx.wait();
            await delay(1000);
          } catch (error) {
            console.error(`   ❌ 设置佣金率失败:`, error);
          }
        }

        // 设置 DXP 奖励率
        const dxpRewardRates = [
          { type: 4, rate: 1000, name: 'CHARACTER_NFT Gold DXP' },  // Character NFT 给 Gold DXP
          { type: 5, rate: 1000, name: 'BLACKGHOST_NFT Silver DXP' }, // BlackGhost NFT 给 Silver DXP
        ];

        for (const reward of dxpRewardRates) {
          try {
            console.log(`   设置 ${reward.name} 奖励率`);
            const setDXPRateTx = await referralV2.setDXPRewardRate(reward.type, reward.rate);
            await setDXPRateTx.wait();
            await delay(1000);
          } catch (error) {
            console.error(`   ❌ 设置 DXP 奖励率失败:`, error);
          }
        }

        // 启用系统
        console.log('   启用推荐系统...');
        const enableSystemTx = await referralV2.setSystemEnabled(true);
        await enableSystemTx.wait();
        await delay(1000);

        console.log('✅ ReferralV2 配置完成');
      } catch (error) {
        console.error('❌ 配置 ReferralV2 时出错:', error);
      }

      // 验证配置
      console.log('\n🔍 验证推荐系统配置...');
      try {
        const owner = await referralV2.owner();
        const dustToken = await referralV2.dustToken();
        const goldDXPToken = await referralV2.goldDXPToken();
        const silverDXPToken = await referralV2.silverDXPToken();
        const treasury = await referralV2.treasury();
        const systemEnabled = await referralV2.systemEnabled();
        
        console.log(`合约所有者: ${owner}`);
        console.log(`DUST Token: ${dustToken}`);
        console.log(`Gold DXP Token: ${goldDXPToken}`);
        console.log(`Silver DXP Token: ${silverDXPToken}`);
        console.log(`财政金库: ${treasury}`);
        console.log(`系统状态: ${systemEnabled ? '启用' : '禁用'}`);
        
        // 检查一些佣金率
        const foodPackRate = await referralV2.commissionRates(0); // FOOD_PACK
        const characterNFTRate = await referralV2.commissionRates(4); // CHARACTER_NFT
        console.log(`Food Pack 佣金率: ${Number(foodPackRate) / 100}%`);
        console.log(`Character NFT 佣金率: ${Number(characterNFTRate) / 100}%`);
      } catch (error) {
        console.error('验证配置时出错:', error);
      }

      // 保存 ReferralV2 地址
      addressManager.saveContractAddress(networkName, 'ReferralV2', referralV2Address, {
        deployer: deployer.address,
        deploymentMode: 'upgradeable',
        proxyType: 'UUPS',
        admin: referralConfig.admin,
        dustToken: referralConfig.dustToken,
        goldDXPToken: referralConfig.goldDXPToken,
        silverDXPToken: referralConfig.silverDXPToken,
        vrfSystem: referralConfig.vrfSystem,
        treasury: referralConfig.treasury,
        initParams: [
          referralConfig.admin,
          referralConfig.dustToken,
          referralConfig.goldDXPToken,
          referralConfig.silverDXPToken,
          referralConfig.vrfSystem,
          referralConfig.treasury,
        ],
        metadata: {
          description: 'ReferralV2 - Multi-level referral system with DXP token rewards',
          productTypes: 6,
          systemEnabled: true,
          supportedTokens: ['ETH', 'DUST', 'GoldDXP', 'SilverDXP'],
        },
        deployedAt: new Date().toISOString(),
      });

      console.log('\n✅ ReferralV2 系统部署和配置完成!');

      // 打印完整部署摘要
      console.log('\n📋 完整部署摘要:');
      console.log(`网络: ${networkName}`);
      console.log(`部署者: ${deployer.address}`);
      console.log(`GoldDXPToken: ${goldDXPTokenAddress}`);
      console.log(`SilverDXPToken: ${silverDXPTokenAddress}`);
      console.log(`ReferralV2: ${referralV2Address}`);
      console.log(`关联 DUSTToken: ${dustTokenAddress}`);
      console.log(`财政金库: ${treasury}`);
      console.log(`推荐系统已配置 6 种产品类型的佣金结构`);
    } else {
      console.log(`\n⚠️  ReferralV2 已存在: ${existingReferralV2}`);
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