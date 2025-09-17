import { ethers, network, upgrades } from 'hardhat';
import { ContractAddressManager } from './utils/ContractAddressManager';

// 添加延迟函数，在测试网部署时避免交易冲突
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`部署 CharacterUpgrade 角色升级系统到 ${networkName} 网络...`);

  // 获取部署者钱包
  const [deployer] = await ethers.getSigners();
  console.log(`部署者地址: ${deployer.address}`);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(`部署者余额: ${ethers.formatEther(balance)} ETH`);

  try {
    // 检查依赖合约
    const contracts = addressManager.getAllContractAddresses(networkName) || {};
    const goldDXPTokenAddress = contracts['GoldDXPToken'];
    const silverDXPTokenAddress = contracts['SilverDXPToken'];
    const characterNFTAddress = contracts['CharacterNFT'];
    const blackGhostNFTAddress = contracts['BlackGhostNFT'];

    console.log('\n📋 检查依赖合约:');
    console.log(`GoldDXPToken: ${goldDXPTokenAddress || '未部署'}`);
    console.log(`SilverDXPToken: ${silverDXPTokenAddress || '未部署'}`);
    console.log(`CharacterNFT: ${characterNFTAddress || '未部署'}`);
    console.log(`BlackGhostNFT: ${blackGhostNFTAddress || '未部署'}`);

    // 验证所有依赖合约都已部署
    const missingContracts = [];
    if (!goldDXPTokenAddress) missingContracts.push('GoldDXPToken');
    if (!silverDXPTokenAddress) missingContracts.push('SilverDXPToken');
    if (!characterNFTAddress) missingContracts.push('CharacterNFT');
    if (!blackGhostNFTAddress) missingContracts.push('BlackGhostNFT');

    if (missingContracts.length > 0) {
      throw new Error(`缺少必需的依赖合约: ${missingContracts.join(', ')}\n请先部署这些合约后再运行此脚本`);
    }

    // 检查是否已经部署过 CharacterUpgrade
    const existingCharacterUpgrade = contracts['CharacterUpgrade'];
    
    if (existingCharacterUpgrade) {
      console.log(`\n⚠️  CharacterUpgrade 已在此网络部署: ${existingCharacterUpgrade}`);
      console.log('如需重新部署，请先删除地址管理器中的记录');
      return;
    }

    // 部署 CharacterUpgrade (可升级)
    console.log('\n🚀 部署 CharacterUpgrade...');
    
    const CharacterUpgradeFactory = await ethers.getContractFactory('CharacterUpgrade');
    const characterUpgrade = await upgrades.deployProxy(
      CharacterUpgradeFactory,
      [
        goldDXPTokenAddress,
        silverDXPTokenAddress,
        characterNFTAddress,
        blackGhostNFTAddress,
      ],
      {
        initializer: 'initialize',
        kind: 'uups',
      }
    );

    await characterUpgrade.waitForDeployment();
    const characterUpgradeAddress = await characterUpgrade.getAddress();
    console.log(`✅ CharacterUpgrade 已部署 (可升级): ${characterUpgradeAddress}`);

    await delay(2000);

    // 配置 DXP Token 权限
    console.log('\n🔧 配置 CharacterUpgrade 权限...');
    
    try {
      // 设置 CharacterUpgrade 为 GoldDXPToken 消费者
      const GoldDXPToken = await ethers.getContractFactory('GoldDXPToken');
      const goldDXPToken = GoldDXPToken.attach(goldDXPTokenAddress) as any;
      
      console.log('   设置 CharacterUpgrade 为 GoldDXPToken 消费者...');
      const goldUpgradeTx = await goldDXPToken.setBurnerAuthorization(characterUpgradeAddress, true);
      await goldUpgradeTx.wait();
      console.log('✅ CharacterUpgrade 已获得 GoldDXPToken 销毁权限');
      await delay(1000);

      // 设置 CharacterUpgrade 为 SilverDXPToken 消费者
      const SilverDXPToken = await ethers.getContractFactory('SilverDXPToken');
      const silverDXPToken = SilverDXPToken.attach(silverDXPTokenAddress) as any;
      
      console.log('   设置 CharacterUpgrade 为 SilverDXPToken 消费者...');
      const silverUpgradeTx = await silverDXPToken.setBurnerAuthorization(characterUpgradeAddress, true);
      await silverUpgradeTx.wait();
      console.log('✅ CharacterUpgrade 已获得 SilverDXPToken 销毁权限');
      await delay(1000);

      console.log('✅ CharacterUpgrade 权限配置完成');
    } catch (error) {
      console.error('❌ 配置 CharacterUpgrade 权限时出错:', error);
    }

    // 验证配置
    console.log('\n🔍 验证 CharacterUpgrade 配置...');
    try {
      const owner = await characterUpgrade.owner();
      const goldDXPToken = await characterUpgrade.goldDXPToken();
      const silverDXPToken = await characterUpgrade.silverDXPToken();
      const characterNFT = await characterUpgrade.characterNFT();
      const blackGhostNFT = await characterUpgrade.blackGhostNFT();
      
      console.log(`合约所有者: ${owner}`);
      console.log(`Gold DXP Token: ${goldDXPToken}`);
      console.log(`Silver DXP Token: ${silverDXPToken}`);
      console.log(`Character NFT: ${characterNFT}`);
      console.log(`BlackGhost NFT: ${blackGhostNFT}`);
      
      // 检查升级配置
      const upgradeConfig = await characterUpgrade.upgradeConfig();
      console.log(`Gold DXP 升级消耗: ${ethers.formatEther(upgradeConfig.goldDXPCost)} DXP`);
      console.log(`Silver DXP 升级消耗: ${ethers.formatEther(upgradeConfig.silverDXPCost)} DXP`);
      console.log(`最大升级等级: ${upgradeConfig.maxLevel}`);
    } catch (error) {
      console.error('验证配置时出错:', error);
    }

    // 保存 CharacterUpgrade 地址
    addressManager.saveContractAddress(networkName, 'CharacterUpgrade', characterUpgradeAddress, {
      deployer: deployer.address,
      deploymentMode: 'upgradeable',
      proxyType: 'UUPS',
      goldDXPToken: goldDXPTokenAddress,
      silverDXPToken: silverDXPTokenAddress,
      characterNFT: characterNFTAddress,
      blackGhostNFT: blackGhostNFTAddress,
      initParams: [
        goldDXPTokenAddress,
        silverDXPTokenAddress,
        characterNFTAddress,
        blackGhostNFTAddress,
      ],
      metadata: {
        description: 'CharacterUpgrade - Character upgrade system using Gold and Silver DXP tokens',
        goldDXPCost: '100 DXP per level',
        silverDXPCost: '50 DXP per level',
        maxLevel: 10,
        features: [
          'Gold DXP: 批量升级 CharacterNFT',
          'Silver DXP: 单个升级任意角色',
          '支持 CharacterNFT 和 BlackGhostNFT',
        ],
      },
      deployedAt: new Date().toISOString(),
    });

    console.log('\n✅ CharacterUpgrade 角色升级系统部署完成!');

    // 打印完整部署摘要
    console.log('\n📋 完整部署摘要:');
    console.log(`网络: ${networkName}`);
    console.log(`部署者: ${deployer.address}`);
    console.log(`CharacterUpgrade: ${characterUpgradeAddress}`);
    console.log(`关联 GoldDXPToken: ${goldDXPTokenAddress}`);
    console.log(`关联 SilverDXPToken: ${silverDXPTokenAddress}`);
    console.log(`关联 CharacterNFT: ${characterNFTAddress}`);
    console.log(`关联 BlackGhostNFT: ${blackGhostNFTAddress}`);
    console.log(`角色升级系统已配置 DXP 权限`);

    // 使用指南
    console.log('\n📝 使用指南:');
    console.log('1. Gold DXP 升级: 支持批量升级 CharacterNFT');
    console.log('2. Silver DXP 升级: 支持单个升级任意角色 (CharacterNFT 或 BlackGhostNFT)');
    console.log('3. 升级消耗: 每级 100 Gold DXP 或 50 Silver DXP');
    console.log('4. 最大等级: 10');
    console.log('5. 权限管理: 已配置 DXP 代币销毁权限');

  } catch (error) {
    console.error('\n❌ 部署过程中发生错误:', error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('CharacterUpgrade 部署脚本执行失败:', error);
    process.exit(1);
  });