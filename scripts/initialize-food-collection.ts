import { ethers, network } from 'hardhat';
import { foodMetadata } from './metadata/foodMetadata';
import { ContractAddressManager } from './utils/ContractAddressManager';

/**
 * 根据foodMetadata.ts的数据初始化FoodNFT集合
 */

// 稀有度映射
const RARITY_MAP: { [key: string]: number } = {
  F: 1,
  N: 2, // Normal (普通)
  C: 3, // Common (常见)
  R: 4, // Rare (稀有)
  RR: 5, // Very Rare (非常稀有)
  SR: 6, // Super Rare (超稀有)
  SSR: 7, // Super Super Rare (超超稀有)
};

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`初始化 FoodNFT 集合 - ${networkName} 网络...`);

  const [deployer] = await ethers.getSigners();
  console.log(`操作者地址: ${deployer.address}`);

  try {
    // 从 ContractAddressManager 加载合约地址
    const contracts = addressManager.getAllContractAddresses(networkName) || {};
    const foodNFTAddress = contracts['FoodNFT'];

    if (!foodNFTAddress) {
      throw new Error('FoodNFT 地址未找到，请先部署 FoodNFT 合约');
    }

    console.log(`FoodNFT 地址: ${foodNFTAddress}`);

    // 连接到 FoodNFT 合约
    const FoodNFT = await ethers.getContractFactory('FoodNFT');
    const foodNFT = FoodNFT.attach(foodNFTAddress) as any;

    console.log(`\n📋 准备初始化 ${foodMetadata.length} 个食物NFT:`);

    let successCount = 0;
    let skipCount = 0;
    let errorCount = 0;

    // 批量初始化食物NFT
    for (let i = 0; i < foodMetadata.length; i++) {
      const food = foodMetadata[i];
      const tokenId = parseInt(food.TokenId);
      const rarity = RARITY_MAP[food.Rarity];
      const name = food.Name;
      const value = ethers.parseEther(food.Value);
      const exp = ethers.parseEther(food.Exp);

      if (!rarity) {
        console.log(`❌ 未知稀有度: ${food.Rarity} (Token ID: ${tokenId})`);
        errorCount++;
        continue;
      }

      try {
        // 检查是否已经初始化
        try {
          const existingName = await foodNFT.getName(tokenId);
          if (existingName && existingName !== '') {
            console.log(`⏭️ Token ${tokenId} (${name}) 已初始化，跳过`);
            skipCount++;
            continue;
          }
        } catch (error) {
          // Token 不存在，需要初始化
        }

        console.log(`🍽️ 初始化 Token ${tokenId}: ${name}`);
        console.log(`   稀有度: ${food.Rarity} (${rarity}), 价值: ${food.Value} ETH, 经验: ${food.Exp}`);

        const tx = await foodNFT.initializeCollection(tokenId, rarity, name, value, exp);
        await tx.wait();

        console.log(`✅ Token ${tokenId} 初始化成功`);
        successCount++;
      } catch (error) {
        console.log(`❌ Token ${tokenId} 初始化失败:`, error);
        errorCount++;
      }

      console.log(`\n--- 已处理 ${i + 1}/${foodMetadata.length} 个食物 ---\n`);
      await new Promise((resolve) => setTimeout(resolve, 3000));
    }

    console.log('\n✅ 食物NFT集合初始化完成!');
    console.log(`\n📊 初始化统计:`);
    console.log(`成功: ${successCount}`);
    console.log(`跳过: ${skipCount}`);
    console.log(`失败: ${errorCount}`);
    console.log(`总计: ${foodMetadata.length}`);

    // 验证几个示例食物
    console.log('\n🔍 验证示例食物:');
    const sampleIds = [1, 15, 42, 58]; // 随机选择几个ID验证

    for (const tokenId of sampleIds) {
      try {
        const name = await foodNFT.getName(tokenId);
        const rarity = await foodNFT.getRarity(tokenId);
        const value = await foodNFT.getValue(tokenId);
        const exp = await foodNFT.getExp(tokenId);

        console.log(
          `✅ Token ${tokenId}: ${name}, 稀有度: ${rarity}, 价值: ${ethers.formatEther(value)} ETH, 经验: ${ethers.formatEther(exp)}`
        );
      } catch (error) {
        console.log(`❌ Token ${tokenId} 验证失败`);
      }
    }

    // 设置FoodNFT的URI
    await new Promise((resolve) => setTimeout(resolve, 3000));

    console.log('\n🔧 设置FoodNFT URI...');
    const newURI = 'https://storage.googleapis.com/hungrydegens/foodsMetadata/{id}.json';

    try {
      // 检查当前URI
      try {
        const currentURI = await foodNFT.uri(1); // 用任意ID测试当前URI
        console.log(`📋 当前URI: ${currentURI}`);
      } catch (error) {
        console.log('📋 无法获取当前URI');
      }

      console.log(`🔧 设置新的URI: ${newURI}`);

      // 设置新URI
      const uriTx = await foodNFT.setURI(newURI);
      console.log(`URI设置交易已发送: ${uriTx.hash}`);

      await uriTx.wait();
      console.log(`✅ URI设置完成`);

    } catch (uriError) {
      console.error('❌ URI设置失败:', uriError);
      // URI设置失败不影响整体初始化
    }
  } catch (error) {
    console.error('❌ 初始化过程中发生错误:', error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('FoodNFT集合初始化脚本执行失败:', error);
    process.exit(1);
  });
