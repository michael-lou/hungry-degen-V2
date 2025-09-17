import { ethers, network } from 'hardhat';
import { ContractAddressManager } from './utils/ContractAddressManager';

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`部署 DUST Token 合约到 ${networkName} 网络...`);

  // 获取部署者钱包
  const [deployer] = await ethers.getSigners();
  console.log(`部署者地址: ${deployer.address}`);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(`部署者余额: ${ethers.formatEther(balance)} ETH`);

  try {
    // 检查是否已经部署过 DUSTToken
    const contracts = addressManager.getAllContractAddresses(networkName) || {};
    const existingDUSTToken = contracts['DUSTToken'];

    if (existingDUSTToken) {
      console.log(`⚠️  DUSTToken 已在此网络部署: ${existingDUSTToken}`);
      console.log('如需重新部署，请先删除地址管理器中的记录');
      return;
    }

    // 部署 DUSTToken
    console.log('\n🚀 部署 DUSTToken...');
    const DUSTTokenFactory = await ethers.getContractFactory('DUSTToken');
    
    // DUSTToken 构造函数参数：initialOwner
    const dustToken = await DUSTTokenFactory.deploy(deployer.address);
    await dustToken.waitForDeployment();
    
    const dustTokenAddress = await dustToken.getAddress();
    console.log(`✅ DUSTToken 已部署: ${dustTokenAddress}`);

    // 获取代币信息
    const name = await dustToken.name();
    const symbol = await dustToken.symbol();
    const decimals = await dustToken.decimals();
    const totalSupply = await dustToken.totalSupply();
    const deployerBalance = await dustToken.balanceOf(deployer.address);

    console.log('\n📋 DUST Token 信息:');
    console.log(`名称: ${name}`);
    console.log(`符号: ${symbol}`);
    console.log(`精度: ${decimals}`);
    console.log(`总供应量: ${ethers.formatEther(totalSupply)} ${symbol}`);
    console.log(`部署者余额: ${ethers.formatEther(deployerBalance)} ${symbol}`);

    // 保存合约地址和元数据
    addressManager.saveContractAddress(networkName, 'DUSTToken', dustTokenAddress, {
      deployer: deployer.address,
      deploymentMode: 'standard',
      contractType: 'ERC20',
      genesisHolder: deployer.address,
      initParams: [deployer.address],
      metadata: {
        name: name,
        symbol: symbol,
        decimals: Number(decimals),
        totalSupply: totalSupply.toString(),
        description: 'DUST Token - The primary utility token for HungryDegen ecosystem',
      },
      deployedAt: new Date().toISOString(),
    });

    console.log('\n✅ DUSTToken 部署完成!');

    // 打印部署摘要
    console.log('\n📋 部署摘要:');
    console.log(`网络: ${networkName}`);
    console.log(`部署者: ${deployer.address}`);
    console.log(`DUSTToken: ${dustTokenAddress}`);
    console.log(`代币名称: ${name} (${symbol})`);
    console.log(`初始供应量: ${ethers.formatEther(totalSupply)} ${symbol}`);

    // 验证部署
    console.log('\n🔍 验证部署...');
    const deployedToken = await ethers.getContractAt('DUSTToken', dustTokenAddress);
    const verifyBalance = await deployedToken.balanceOf(deployer.address);
    const verifyTotalSupply = await deployedToken.totalSupply();
    
    console.log(`总供应量验证: ${ethers.formatEther(verifyTotalSupply)} ${symbol}`);
    console.log(`部署者代币余额: ${ethers.formatEther(verifyBalance)} ${symbol}`);
    console.log(`余额是否等于总供应量: ${verifyBalance === verifyTotalSupply ? '✅ 正确' : '❌ 错误'}`);

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