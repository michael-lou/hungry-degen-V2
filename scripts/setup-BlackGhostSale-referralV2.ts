import { ethers, network } from 'hardhat';
import { ContractAddressManager } from './utils/ContractAddressManager';

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`设置 BlackGhostSale 的 ReferralV2 系统到 ${networkName} 网络...`);

  // 获取部署者钱包
  const [deployer] = await ethers.getSigners();
  console.log(`操作者地址: ${deployer.address}`);

  try {
    // 第一步：获取合约地址
    console.log('\n🔍 步骤1: 获取合约地址...');
    
    const blackGhostSaleAddress = addressManager.getContractAddress(networkName, 'BlackGhostSale');
    const referralV2Address = addressManager.getContractAddress(networkName, 'ReferralV2');

    console.log(`BlackGhostSale: ${blackGhostSaleAddress || '未部署'}`);
    console.log(`ReferralV2: ${referralV2Address || '未部署'}`);

    // 验证合约地址
    if (!blackGhostSaleAddress) {
      throw new Error('BlackGhostSale 合约尚未部署。请先运行 BlackGhostSale 部署脚本。');
    }

    if (!referralV2Address) {
      throw new Error('ReferralV2 合约尚未部署。请先运行 deploy-and-setup-ReferralV2.ts。');
    }

    // 第二步：连接到合约
    console.log('\n🔗 步骤2: 连接到合约...');
    
    const BlackGhostSaleFactory = await ethers.getContractFactory('BlackGhostSale');
    const blackGhostSale = BlackGhostSaleFactory.attach(blackGhostSaleAddress.address) as any;

    const ReferralV2Factory = await ethers.getContractFactory('ReferralV2');
    const referralV2 = ReferralV2Factory.attach(referralV2Address.address) as any;

    console.log('✅ 合约连接成功');

    // 第三步：检查当前配置
    console.log('\n🔍 步骤3: 检查当前配置...');
    
    let currentReferralV2Address;
    try {
      currentReferralV2Address = await blackGhostSale.referralV2();
      console.log(`当前 ReferralV2 地址: ${currentReferralV2Address}`);
    } catch (error) {
      console.log('无法读取当前 ReferralV2 地址（可能为零地址）');
      currentReferralV2Address = ethers.ZeroAddress;
    }

    // 第四步：设置 ReferralV2
    console.log('\n🔧 步骤4: 设置 ReferralV2...');
    
    if (currentReferralV2Address.toLowerCase() === referralV2Address.address.toLowerCase()) {
      console.log('✅ ReferralV2 地址已正确设置，无需更改');
    } else {
      console.log('   正在设置 ReferralV2 地址...');
      
      const setReferralTx = await blackGhostSale.setReferralV2(referralV2Address.address);
      console.log(`   交易哈希: ${setReferralTx.hash}`);
      
      await setReferralTx.wait();
      console.log('✅ ReferralV2 地址设置成功');
      
      // 验证设置
      const newReferralV2Address = await blackGhostSale.referralV2();
      console.log(`   新的 ReferralV2 地址: ${newReferralV2Address}`);
      
      if (newReferralV2Address.toLowerCase() !== referralV2Address.address.toLowerCase()) {
        throw new Error('ReferralV2 地址设置验证失败');
      }
    }

    // 第五步：验证 ReferralV2 配置
    console.log('\n🔍 步骤5: 验证 ReferralV2 配置...');
    
    try {
      // 检查 ReferralV2 是否支持 BLACKGHOST_NFT 产品类型
      const isProductSupported = await referralV2.isProductTypeSupported(4); // BLACKGHOST_NFT = 4
      console.log(`BLACKGHOST_NFT 产品类型支持状态: ${isProductSupported ? '✅ 支持' : '❌ 不支持'}`);
      
      if (!isProductSupported) {
        console.log('⚠️  警告: ReferralV2 可能尚未配置 BLACKGHOST_NFT 产品类型');
        console.log('   请确保在 ReferralV2 中配置了正确的产品类型和奖励设置');
      }
      
      // 检查银币 DXP 代币配置
      const silverDXPToken = await referralV2.silverDXPToken();
      console.log(`Silver DXP Token 地址: ${silverDXPToken}`);
      
      if (silverDXPToken === ethers.ZeroAddress) {
        console.log('⚠️  警告: Silver DXP Token 尚未设置');
      }
      
    } catch (error) {
      console.log('⚠️  无法完全验证 ReferralV2 配置:', error);
    }

    // 第六步：测试基础功能
    console.log('\n🧪 步骤6: 测试基础功能...');
    
    try {
      // 测试获取推荐人（应该返回零地址，因为测试地址没有推荐关系）
      const testReferrer = await referralV2.getReferrer(deployer.address);
      console.log(`测试获取推荐人: ${testReferrer === ethers.ZeroAddress ? '✅ 正常' : '⚠️  异常'}`);
      
    } catch (error) {
      console.log('⚠️  基础功能测试失败:', error);
    }

    // 第七步：保存配置信息
    console.log('\n📝 步骤7: 保存配置信息...');
    
    // 更新 BlackGhostSale 的配置信息
    try {
      const existingInfo = addressManager.getContractAddress(networkName, 'BlackGhostSale');
      if (existingInfo) {
        // 保存更新的配置信息
        addressManager.saveContractAddress(networkName, 'BlackGhostSale', blackGhostSaleAddress.address, {
          deployer: deployer.address,
          deploymentMode: 'upgradeable',
          proxyType: 'UUPS',
          config: {
            referralV2Address: referralV2Address.address,
            referralV2ConfiguredAt: new Date().toISOString(),
          },
          description: 'BlackGhostSale contract with ReferralV2 integration configured',
        });
        console.log('✅ 配置信息已保存');
      }
    } catch (error) {
      console.log('⚠️  保存配置信息时出错:', error);
    }

    console.log('\n✅ BlackGhostSale ReferralV2 设置完成!');

    // 打印最终配置摘要
    console.log('\n📋 最终配置摘要:');
    console.log(`网络: ${networkName}`);
    console.log(`操作者: ${deployer.address}`);
    console.log(`BlackGhostSale: ${blackGhostSaleAddress.address}`);
    console.log(`ReferralV2: ${referralV2Address.address}`);

    // 使用指南
    console.log('\n📝 使用说明:');
    console.log('1. BlackGhostSale 现在已连接到 ReferralV2 系统');
    console.log('2. 用户购买时可以指定推荐人地址获得推荐奖励');
    console.log('3. 推荐奖励以 Silver DXP 代币形式发放');
    console.log('4. 确保 ReferralV2 已正确配置 BLACKGHOST_NFT 产品类型');
    console.log('5. 确保 Silver DXP Token 已部署并在 ReferralV2 中配置');

    console.log('\n📝 相关管理命令:');
    console.log('- 查看销售统计: blackGhostSale.getSaleStats()');
    console.log('- 查看用户推荐人: referralV2.getReferrer(userAddress)');
    console.log('- 查看推荐奖励: referralV2.getUserStats(userAddress)');

  } catch (error) {
    console.error('\n❌ 设置过程中发生错误:', error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('BlackGhostSale ReferralV2 设置脚本执行失败:', error);
    process.exit(1);
  });