import { ethers, network, upgrades } from 'hardhat';
import { ContractAddressManager } from '../utils/ContractAddressManager';

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`部署 BlackGhostSale 合约到 ${networkName} 网络...`);

  // 获取部署者钱包
  const [deployer] = await ethers.getSigners();
  console.log(`部署者地址: ${deployer.address}`);

  const treasury = '0x888Ce07575185Fe5b148b368634b12B0813e92e7';
  console.log(`财政金库地址: ${treasury}`);

  try {
    // 从 AddressManager 读取 BlackGhostNFT 地址
    console.log('\n📋 加载已部署的合约地址...');
    const contracts = addressManager.getAllContractAddresses(networkName) || {};
    const blackGhostNFTAddress = contracts['BlackGhostNFT'];

    if (!blackGhostNFTAddress) {
      throw new Error(`BlackGhostNFT 合约未在 ${networkName} 网络中找到，请先部署 BlackGhostNFT`);
    }

    console.log(`✅ 已加载 BlackGhostNFT: ${blackGhostNFTAddress}`);

    // BlackGhostSale 配置参数
    const saleConfig = {
      metadataUri: 'https://storage.googleapis.com/hungrydegens/metadata/basic_ghost_1.json',
      price: ethers.parseEther('0.003'), // 正价 0.003 ETH
      maxSupply: ethers.MaxUint256, // 最大供应量设置为uint256最大值
      treasuryAddress: treasury, // 资金接收地址
      phase2StartTime: Math.floor(new Date('2025-12-31').getTime() / 1000), // 2025-12-31
    };

    console.log('\n📋 销售配置:');
    console.log(`BlackGhostNFT 地址: ${blackGhostNFTAddress}`);
    console.log(`正价: ${ethers.formatEther(saleConfig.price)} ETH`);
    console.log(`最大供应量: ${saleConfig.maxSupply.toString()}`);
    console.log(`Treasury: ${saleConfig.treasuryAddress}`);
    console.log(`第二阶段开始时间: ${new Date(saleConfig.phase2StartTime * 1000).toISOString()}`);

    // 部署 BlackGhostSale
    console.log('\n🚀 部署 BlackGhostSale...');

    const BlackGhostSaleFactory = await ethers.getContractFactory('BlackGhostSale');
    const blackGhostSale = await upgrades.deployProxy(
      BlackGhostSaleFactory,
      [
        blackGhostNFTAddress,
        saleConfig.metadataUri,
        saleConfig.price,
        saleConfig.maxSupply,
        saleConfig.treasuryAddress,
        saleConfig.phase2StartTime,
      ],
      {
        initializer: 'initialize',
        kind: 'uups',
      }
    );
    await blackGhostSale.waitForDeployment();
    const blackGhostSaleAddress = await blackGhostSale.getAddress();
    console.log(`✅ BlackGhostSale 已部署 (可升级): ${blackGhostSaleAddress}`);

    console.log('\n🔧 配置 BlackGhostNFT 权限...');

    const BlackGhostNFT = await ethers.getContractFactory('BlackGhostNFT');

    const blackGhostNFT = BlackGhostNFT.attach(blackGhostNFTAddress) as any;

    const isAuthorized = await blackGhostNFT.authorizedCallers(blackGhostSaleAddress);

    if (!isAuthorized) {
      const tx = await blackGhostNFT.setAuthorizedCaller(blackGhostSaleAddress, true);
      await tx.wait();
      console.log('✅ BlackGhostSale 已获得 BlackGhostNFT 铸造权限');
    } else {
      console.log('✅ BlackGhostSale 已经有 BlackGhostNFT 铸造权限');
    }

    // 启动早鸟阶段并设置折扣配置
    console.log(`   ⏸️ 暂停3秒以避免网络拥堵...`);
    await new Promise((resolve) => setTimeout(resolve, 3000));
    const characterHolderDiscount = 10000; // 角色持有者折扣 0% (以基点为单位，10000 = 100%)
    const generalEarlyDiscount = 10000; // 一般早期折扣 0% (以基点为单位，10000 = 100%)

    console.log(`设置折扣配置:`);
    console.log(`- 角色持有者折扣: ${characterHolderDiscount / 100}%`);
    console.log(`- 一般早期折扣: ${generalEarlyDiscount / 100}%`);

    const BlackGhostSale = await ethers.getContractFactory('BlackGhostSale');
    const blackGhostSaleContract = BlackGhostSale.attach(blackGhostSaleAddress) as any;

    // 使用updateDiscountConfig方法设置折扣
    const updateDiscountTx = await blackGhostSaleContract.updateDiscountConfig(
      characterHolderDiscount,
      generalEarlyDiscount
    );
    await updateDiscountTx.wait();
    console.log(`✅ 折扣配置已更新`);

    // 保存合约地址
    addressManager.saveContractAddress(networkName, 'BlackGhostSale', blackGhostSaleAddress, {
      deployer: deployer.address,
      deploymentMode: 'upgradeable',
      proxyType: 'UUPS',
      initParams: [
        blackGhostNFTAddress,
        saleConfig.metadataUri,
        saleConfig.price.toString(),
        saleConfig.maxSupply.toString(), // 将BigInt转换为字符串
        saleConfig.treasuryAddress,
        saleConfig.phase2StartTime,
      ],
      metadata: {
        linkedContracts: {
          BlackGhostNFT: blackGhostNFTAddress,
        },
        salePhase: 'EARLY_BIRD',
        characterHolderDiscount: characterHolderDiscount,
        generalEarlyDiscount: generalEarlyDiscount,
        phase2StartTime: saleConfig.phase2StartTime,
      },
      deployedAt: new Date().toISOString(),
    });

    console.log('\n✅ BlackGhostSale 部署完成!');
  } catch (error) {
    console.error('❌ 部署过程中发生错误:', error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('BlackGhostSale 部署脚本执行失败:', error);
    process.exit(1);
  });
