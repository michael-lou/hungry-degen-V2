import { ethers, network } from 'hardhat';
import { ContractAddressManager } from './utils/ContractAddressManager';

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`设置 FoodMarketplace 的 ReferralV2 到 ${networkName} 网络...`);

  const [deployer] = await ethers.getSigners();
  console.log(`操作者地址: ${deployer.address}`);

  try {
    // 1) 读取地址
    console.log('\n🔍 步骤1: 获取合约地址...');
    const foodMarketplaceInfo = addressManager.getContractAddress(networkName, 'FoodMarketplace');
    const referralV2Info = addressManager.getContractAddress(networkName, 'ReferralV2');

    console.log(`FoodMarketplace: ${foodMarketplaceInfo ? foodMarketplaceInfo.address : '未部署'}`);
    console.log(`ReferralV2: ${referralV2Info ? referralV2Info.address : '未部署'}`);

    if (!foodMarketplaceInfo?.address) throw new Error('FoodMarketplace 合约尚未部署');
    if (!referralV2Info?.address) throw new Error('ReferralV2 合约尚未部署');

    // 2) 连接合约
    console.log('\n🔗 步骤2: 连接到合约...');
    const FoodMarketplaceFactory = await ethers.getContractFactory('FoodMarketplace');
    const foodMarketplace = FoodMarketplaceFactory.attach(foodMarketplaceInfo.address) as any;
    const ReferralV2Factory = await ethers.getContractFactory('ReferralV2');
    const referralV2 = ReferralV2Factory.attach(referralV2Info.address) as any;
    console.log('✅ 合约连接成功');

    // 3) 检查当前 referralV2
    console.log('\n🔍 步骤3: 检查当前 ReferralV2 配置...');
    let currentRef: string;
    try {
      currentRef = await foodMarketplace.referralV2();
      console.log(`当前 FoodMarketplace.referralV2: ${currentRef}`);
    } catch (err) {
      console.log('读取 FoodMarketplace.referralV2 失败，按未设置处理');
      currentRef = ethers.ZeroAddress;
    }

    // 4) 必要时设置 referralV2
    console.log('\n🔧 步骤4: 设置 ReferralV2 地址...');
    if (currentRef.toLowerCase() === referralV2Info.address.toLowerCase()) {
      console.log('✅ ReferralV2 地址已正确设置，无需更改');
    } else {
      console.log('   正在调用 setReferralV2...');
      const tx = await foodMarketplace.setReferralV2(referralV2Info.address);
      console.log(`   交易哈希: ${tx.hash}`);
      await tx.wait();
      const newRef = await foodMarketplace.referralV2();
      console.log(`✅ 设置完成，新地址: ${newRef}`);
      if (newRef.toLowerCase() !== referralV2Info.address.toLowerCase()) {
        throw new Error('设置 ReferralV2 地址后验证失败');
      }
    }

    // 5) 确保在 ReferralV2 中授权该 marketplace（如果有权限方法则尝试）
    console.log('\n🛡️  步骤5: 确认在 ReferralV2 中已授权该 Marketplace...');
    try {
      const isAuthorized = await referralV2.authorizedMarketplaces(foodMarketplaceInfo.address);
      if (!isAuthorized) {
        console.log('   未授权，正在授权...');
        const authTx = await referralV2.setMarketplaceAuthorization(foodMarketplaceInfo.address, true);
        console.log(`   授权交易哈希: ${authTx.hash}`);
        await authTx.wait();
        const after = await referralV2.authorizedMarketplaces(foodMarketplaceInfo.address);
        console.log(after ? '✅ 已授权' : '❌ 授权失败');
      } else {
        console.log('✅ 已在 ReferralV2 中授权');
      }
    } catch (e) {
      console.log('⚠️  无法确认/设置 ReferralV2 授权（可能ABI/权限不支持），跳过该步骤');
    }

    // 6) 持久化保存更新信息
    console.log('\n📝 步骤6: 保存配置信息...');
    try {
      addressManager.saveContractAddress(networkName, 'FoodMarketplace', foodMarketplaceInfo.address, {
        ...(foodMarketplaceInfo.metadata ? { metadata: foodMarketplaceInfo.metadata } : {}),
        deployer: deployer.address,
        deploymentMode: 'upgradeable',
        proxyType: 'UUPS',
        config: {
          ...(foodMarketplaceInfo.config || {}),
          referralV2: referralV2Info.address,
          referralV2ConfiguredAt: new Date().toISOString(),
        },
        description: 'Food Marketplace contract with ReferralV2 configured',
      });
      console.log('✅ 配置信息已保存');
    } catch (e) {
      console.log('⚠️  保存配置信息时出错: ', e);
    }

    console.log('\n✅ FoodMarketplace ReferralV2 设置完成!');
    console.log('\n📋 摘要:');
    console.log(`网络: ${networkName}`);
    console.log(`操作者: ${deployer.address}`);
    console.log(`FoodMarketplace: ${foodMarketplaceInfo.address}`);
    console.log(`ReferralV2: ${referralV2Info.address}`);
  } catch (error) {
    console.error('\n❌ 脚本执行失败:', error);
    process.exit(1);
  }
}

main();
