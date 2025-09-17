import { ethers, network, upgrades } from 'hardhat';
import { ContractAddressManager } from './utils/ContractAddressManager';

// 添加延迟函数，在测试网部署时避免交易冲突
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`部署并配置 CharacterNFTStaking 合约到 ${networkName} 网络...`);

  // 获取部署者钱包
  const [deployer] = await ethers.getSigners();
  console.log(`部署者地址: ${deployer.address}`);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(`部署者余额: ${ethers.formatEther(balance)} ETH`);

  try {
    // 检查依赖合约
    const contracts = addressManager.getAllContractAddresses(networkName) || {};
    const characterNFTAddress = contracts['CharacterNFT'];
    const blackGhostNFTAddress = contracts['BlackGhostNFT'];
    const configCenterAddress = contracts['ConfigCenter'];

    console.log('\n📋 检查依赖合约:');
    console.log(`CharacterNFT: ${characterNFTAddress || '未部署'}`);
    console.log(`BlackGhostNFT: ${blackGhostNFTAddress || '未部署'}`);
    console.log(`ConfigCenter: ${configCenterAddress || '未部署'}`);

    // 检查必需的合约地址
    if (!characterNFTAddress) {
      throw new Error('CharacterNFT 地址未找到，请先部署 CharacterNFT');
    }
    if (!blackGhostNFTAddress) {
      throw new Error('BlackGhostNFT 地址未找到，请先部署 BlackGhostNFT');
    }
    if (!configCenterAddress) {
      throw new Error('ConfigCenter 地址未找到，请先部署 ConfigCenter');
    }

    // 检查是否已经部署过
    const existingCharacterNFTStaking = contracts['CharacterNFTStaking'];

    if (existingCharacterNFTStaking) {
      console.log(`⚠️  CharacterNFTStaking 已在此网络部署: ${existingCharacterNFTStaking}`);
      console.log('如需重新部署，请先删除地址管理器中的记录');
      return;
    }

    // CharacterNFTStaking 配置参数
    const stakingConfig = {
      characterNFT: characterNFTAddress,
      blackGhostNFT: blackGhostNFTAddress,
      configCenter: configCenterAddress,
      expPerBlock: ethers.parseEther('10'), // 每区块10 EXP (以 wei 为单位)
      endBlock: (await ethers.provider.getBlockNumber()) + (30 * 24 * 60 * 60 / 2), // 30天后结束 (假设2秒一个区块)
    };

    console.log('\n📋 CharacterNFTStaking 配置:');
    console.log(`CharacterNFT: ${stakingConfig.characterNFT}`);
    console.log(`BlackGhostNFT: ${stakingConfig.blackGhostNFT}`);
    console.log(`ConfigCenter: ${stakingConfig.configCenter}`);
    console.log(`每区块经验奖励: ${ethers.formatEther(stakingConfig.expPerBlock)} EXP`);
    console.log(`结束区块: ${stakingConfig.endBlock}`);

    // 部署 CharacterNFTStaking
    console.log('\n🚀 部署 CharacterNFTStaking...');
    const CharacterNFTStakingFactory = await ethers.getContractFactory('CharacterNFTStaking');
    const characterNFTStaking = await upgrades.deployProxy(
      CharacterNFTStakingFactory,
      [
        stakingConfig.characterNFT,
        stakingConfig.blackGhostNFT,
        stakingConfig.configCenter,
        stakingConfig.expPerBlock,
        stakingConfig.endBlock,
      ],
      {
        initializer: 'initialize',
        kind: 'uups',
      }
    );

    await characterNFTStaking.waitForDeployment();
    const characterNFTStakingAddress = await characterNFTStaking.getAddress();
    console.log(`✅ CharacterNFTStaking 已部署 (可升级): ${characterNFTStakingAddress}`);

    await delay(2000);

    // 配置权限
    console.log('\n🔧 配置权限和设置...');
    
    try {
      // 检查 CharacterNFT 是否需要授权质押合约
      const CharacterNFT = await ethers.getContractFactory('CharacterNFT');
      const characterNFT = CharacterNFT.attach(characterNFTAddress) as any;
      
      const isAuthorized = await characterNFT.authorizedCallers(characterNFTStakingAddress);
      
      if (!isAuthorized) {
        console.log('   设置 CharacterNFTStaking 为 CharacterNFT 授权调用者...');
        const authTx = await characterNFT.setAuthorizedCaller(characterNFTStakingAddress, true);
        await authTx.wait();
        console.log('✅ CharacterNFTStaking 已获得 CharacterNFT 权限');
        await delay(1000);
      } else {
        console.log('✅ CharacterNFTStaking 已经有 CharacterNFT 权限');
      }

      // 检查 BlackGhostNFT 是否需要授权质押合约
      const BlackGhostNFT = await ethers.getContractFactory('BlackGhostNFT');
      const blackGhostNFT = BlackGhostNFT.attach(blackGhostNFTAddress) as any;
      
      const isBlackGhostAuthorized = await blackGhostNFT.authorizedCallers(characterNFTStakingAddress);
      
      if (!isBlackGhostAuthorized) {
        console.log('   设置 CharacterNFTStaking 为 BlackGhostNFT 授权调用者...');
        const authTx = await blackGhostNFT.setAuthorizedCaller(characterNFTStakingAddress, true);
        await authTx.wait();
        console.log('✅ CharacterNFTStaking 已获得 BlackGhostNFT 权限');
        await delay(1000);
      } else {
        console.log('✅ CharacterNFTStaking 已经有 BlackGhostNFT 权限');
      }

    } catch (error) {
      console.error('❌ 设置权限时出错:', error);
    }

    // 验证配置
    console.log('\n🔍 验证质押配置...');
    try {
      const stakingConfigData = await characterNFTStaking.stakingConfig();
      const totalStakedTokens = await characterNFTStaking.totalStakedTokens();
      const totalExpRewarded = await characterNFTStaking.totalExpRewarded();
      
      console.log(`每区块经验奖励: ${ethers.formatEther(stakingConfigData[0])} EXP`);
      console.log(`结束区块: ${stakingConfigData[1].toString()}`);
      console.log(`池子状态: ${stakingConfigData[2] ? '激活' : '未激活'}`);
      console.log(`总质押代币数: ${totalStakedTokens.toString()}`);
      console.log(`总奖励经验: ${ethers.formatEther(totalExpRewarded)} EXP`);
    } catch (error) {
      console.error('验证配置时出错:', error);
    }

    // 保存合约地址
    addressManager.saveContractAddress(networkName, 'CharacterNFTStaking', characterNFTStakingAddress, {
      deployer: deployer.address,
      deploymentMode: 'upgradeable',
      proxyType: 'UUPS',
      characterNFT: stakingConfig.characterNFT,
      blackGhostNFT: stakingConfig.blackGhostNFT,
      configCenter: stakingConfig.configCenter,
      expPerBlock: stakingConfig.expPerBlock.toString(),
      endBlock: stakingConfig.endBlock.toString(),
      initParams: [
        stakingConfig.characterNFT,
        stakingConfig.blackGhostNFT,
        stakingConfig.configCenter,
        stakingConfig.expPerBlock.toString(),
        stakingConfig.endBlock.toString(),
      ],
      metadata: {
        description: 'CharacterNFTStaking - Staking contract for Character and BlackGhost NFTs',
        stakingDuration: '30 days',
        expPerBlock: ethers.formatEther(stakingConfig.expPerBlock) + ' EXP',
      },
      deployedAt: new Date().toISOString(),
    });

    console.log('\n✅ CharacterNFTStaking 部署和配置完成!');

    // 打印部署摘要
    console.log('\n📋 部署摘要:');
    console.log(`网络: ${networkName}`);
    console.log(`部署者: ${deployer.address}`);
    console.log(`CharacterNFTStaking: ${characterNFTStakingAddress}`);
    console.log(`关联 CharacterNFT: ${stakingConfig.characterNFT}`);
    console.log(`关联 BlackGhostNFT: ${stakingConfig.blackGhostNFT}`);
    console.log(`关联 ConfigCenter: ${stakingConfig.configCenter}`);
    console.log(`每区块奖励: ${ethers.formatEther(stakingConfig.expPerBlock)} EXP`);

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