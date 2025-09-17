import { ethers, network, upgrades } from 'hardhat';
import { ContractAddressManager } from './utils/ContractAddressManager';

// 添加延迟函数，在测试网部署时避免交易冲突
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`部署并配置 ConfigCenter 合约到 ${networkName} 网络...`);

  // 获取部署者钱包
  const [deployer] = await ethers.getSigners();
  console.log(`部署者地址: ${deployer.address}`);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(`部署者余额: ${ethers.formatEther(balance)} ETH`);

  try {
    // 检查是否已经部署过 ConfigCenter
    const contracts = addressManager.getAllContractAddresses(networkName) || {};
    const existingConfigCenter = contracts['ConfigCenter'];

    if (existingConfigCenter) {
      console.log(`⚠️  ConfigCenter 已在此网络部署: ${existingConfigCenter}`);
      console.log('如需重新部署，请先删除地址管理器中的记录');
      return;
    }

    // 部署 ConfigCenter (可升级)
    console.log('\n🚀 部署 ConfigCenter...');
    const ConfigCenterFactory = await ethers.getContractFactory('ConfigCenter');
    const configCenter = await upgrades.deployProxy(ConfigCenterFactory, [], {
      initializer: 'initialize',
      kind: 'uups',
    });
    await configCenter.waitForDeployment();
    
    const configCenterAddress = await configCenter.getAddress();
    console.log(`✅ ConfigCenter 已部署 (可升级): ${configCenterAddress}`);

    // 等待一段时间确保合约部署完成
    console.log('⏳ 等待合约稳定...');
    await delay(3000);

    // 验证合约部署
    console.log('\n🔍 验证合约部署...');
    const deployedConfigCenter = await ethers.getContractAt('ConfigCenter', configCenterAddress);
    const owner = await deployedConfigCenter.owner();
    console.log(`合约所有者: ${owner}`);
    console.log(`所有者验证: ${owner === deployer.address ? '✅ 正确' : '❌ 错误'}`);

    // 配置 ConfigCenter 参数
    console.log('\n🔧 配置 ConfigCenter 参数...');
    
    try {
      // 设置授权调用者（如果需要的话）
      console.log('   设置部署者为授权调用者...');
      const setAuthTx = await deployedConfigCenter.setAuthorizedCaller(deployer.address, true);
      await setAuthTx.wait();
      await delay(1000);
      
      // 设置奖励发放者地址
      console.log('   设置奖励发放者地址...');
      const setRewarderTx = await deployedConfigCenter.setRewarder(deployer.address);
      await setRewarderTx.wait();
      await delay(1000);
      
      // 设置总奖励每区块数量 (如果需要修改默认值)
      const newTotalRewardPerBlock = ethers.parseEther('1000'); // 1000 DUST per block
      console.log(`   设置每区块总奖励: ${ethers.formatEther(newTotalRewardPerBlock)} DUST`);
      const setTotalRewardTx = await deployedConfigCenter.updateTotalRewardPerBlock(newTotalRewardPerBlock);
      await setTotalRewardTx.wait();
      await delay(1000);
      
      // 设置基础损耗参数
      console.log('   设置损耗参数...');
      const setWearTx = await deployedConfigCenter.updateWearParameters(5, 1, 1); // baseWear=5, rarityReduction=1, levelReduction=1
      await setWearTx.wait();
      await delay(1000);
      
      // 设置修复模式 (false = 使用DUST, true = 使用ETH)
      console.log('   设置修复模式为DUST...');
      const setRepairModeTx = await deployedConfigCenter.setRepairByEth(false);
      await setRepairModeTx.wait();
      await delay(1000);
      
      console.log('✅ 基础参数配置完成');
      
    } catch (error) {
      console.error('❌ 配置参数时出错:', error);
    }

    // 验证配置
    console.log('\n🔍 验证配置...');
    try {
      const totalRewardPerBlock = await deployedConfigCenter.TOTAL_REWARD_PER_BLOCK();
      const rewarder = await deployedConfigCenter.getRewarder();
      const repairByEth = await deployedConfigCenter.repairByEth();
      
      console.log(`每区块总奖励: ${ethers.formatEther(totalRewardPerBlock)} DUST`);
      console.log(`奖励发放者: ${rewarder}`);
      console.log(`修复模式: ${repairByEth ? 'ETH' : 'DUST'}`);
    } catch (error) {
      console.error('验证配置时出错:', error);
    }

    // 保存合约地址和元数据
    addressManager.saveContractAddress(networkName, 'ConfigCenter', configCenterAddress, {
      deployer: deployer.address,
      deploymentMode: 'upgradeable',
      proxyType: 'UUPS',
      initParams: [],
      metadata: {
        description: 'ConfigCenter - Centralized configuration management for HungryDegen ecosystem',
        baseParamsConfigured: true,
        totalRewardPerBlock: '1000 DUST',
        repairMode: 'DUST',
      },
      deployedAt: new Date().toISOString(),
    });

    console.log('\n✅ ConfigCenter 部署和配置完成!');

    // 打印部署摘要
    console.log('\n📋 部署摘要:');
    console.log(`网络: ${networkName}`);
    console.log(`部署者: ${deployer.address}`);
    console.log(`ConfigCenter: ${configCenterAddress}`);
    console.log(`已配置基础参数和权限设置`);

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