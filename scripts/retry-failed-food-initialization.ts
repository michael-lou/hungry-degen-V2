import { ethers, network } from 'hardhat';
import { foodMetadata } from './metadata/foodMetadata';
import { ContractAddressManager } from './utils/ContractAddressManager';

/**
 * 重新初始化失败的FoodNFT token
 */

// 稀有度映射
const RARITY_MAP: { [key: string]: number } = {
  'F': 1,
  'N': 2,    // Normal (普通)
  'C': 3,    // Common (常见)
  'R': 4,    // Rare (稀有)
  'RR': 5,   // Very Rare (非常稀有)
  'SR': 6,   // Super Rare (超稀有)
  'SSR': 7,  // Super Super Rare (超超稀有)
};

// 失败的token ID列表 - 根据实际失败情况更新
const FAILED_TOKEN_IDS = [13, 19, 28, 43, 53, 55];

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`重新初始化失败的 FoodNFT tokens - ${networkName} 网络...`);

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

    console.log(`\n📋 准备重新初始化 ${FAILED_TOKEN_IDS.length} 个失败的食物NFT:`);
    console.log(`失败的Token IDs: [${FAILED_TOKEN_IDS.join(', ')}]`);

    let successCount = 0;
    let stillFailedCount = 0;
    let alreadyInitializedCount = 0;

    // 重新初始化失败的食物NFT
    for (const tokenId of FAILED_TOKEN_IDS) {
      const food = foodMetadata.find(f => parseInt(f.TokenId) === tokenId);
      
      if (!food) {
        console.log(`❌ 未找到 Token ${tokenId} 的元数据`);
        stillFailedCount++;
        continue;
      }

      const rarity = RARITY_MAP[food.Rarity];
      const name = food.Name;
      const value = ethers.parseEther(food.Value);
      const exp = ethers.parseEther(food.Exp);

      if (!rarity) {
        console.log(`❌ 未知稀有度: ${food.Rarity} (Token ID: ${tokenId})`);
        stillFailedCount++;
        continue;
      }

      try {
        // 检查是否已经初始化
        try {
          const existingName = await foodNFT.getName(tokenId);
          if (existingName && existingName !== "") {
            console.log(`✅ Token ${tokenId} (${name}) 已初始化，无需重试`);
            alreadyInitializedCount++;
            continue;
          }
        } catch (error) {
          // Token 不存在，需要初始化
        }

        console.log(`🔄 重试初始化 Token ${tokenId}: ${name}`);
        console.log(`   稀有度: ${food.Rarity} (${rarity}), 价值: ${food.Value} ETH, 经验: ${food.Exp}`);

        // 使用更高的 gas price 来避免 "replacement transaction underpriced" 错误
        const gasPrice = await ethers.provider.getFeeData();
        const increasedGasPrice = gasPrice.gasPrice ? gasPrice.gasPrice * 120n / 100n : undefined;

        const tx = await foodNFT.initializeCollection(
          tokenId,
          rarity,
          name,
          value,
          exp,
          {
            gasPrice: increasedGasPrice,
            gasLimit: 300000 // 设置足够的 gas limit
          }
        );
        
        console.log(`   ⏳ 交易已发送，等待确认... (hash: ${tx.hash})`);
        await tx.wait();

        console.log(`✅ Token ${tokenId} 重新初始化成功`);
        successCount++;

        // 验证初始化结果
        try {
          const verifyName = await foodNFT.getName(tokenId);
          const verifyRarity = await foodNFT.getRarity(tokenId);
          console.log(`   🔍 验证成功: ${verifyName}, 稀有度: ${verifyRarity}`);
        } catch (verifyError) {
          console.log(`   ⚠️ 验证失败，但交易已确认`);
        }

      } catch (error) {
        console.log(`❌ Token ${tokenId} 重新初始化仍然失败:`, error);
        stillFailedCount++;
      }

      // 在每个token之间添加延迟，避免nonce冲突
      console.log(`   ⏸️ 等待3秒以避免nonce冲突...\n`);
      await new Promise(resolve => setTimeout(resolve, 3000));
    }

    console.log('\n✅ 失败token重新初始化完成!');
    console.log(`\n📊 重试统计:`);
    console.log(`新成功: ${successCount}`);
    console.log(`已初始化: ${alreadyInitializedCount}`);
    console.log(`仍然失败: ${stillFailedCount}`);
    console.log(`总计重试: ${FAILED_TOKEN_IDS.length}`);

    if (stillFailedCount > 0) {
      console.log(`\n⚠️ 仍然失败的token需要手动检查或再次重试`);
    }

    // 最终验证所有原本失败的token
    console.log('\n🔍 最终验证所有原本失败的token:');
    for (const tokenId of FAILED_TOKEN_IDS) {
      try {
        const name = await foodNFT.getName(tokenId);
        const rarity = await foodNFT.getRarity(tokenId);
        const value = await foodNFT.getValue(tokenId);
        const exp = await foodNFT.getExp(tokenId);
        
        console.log(`✅ Token ${tokenId}: ${name}, 稀有度: ${rarity}, 价值: ${ethers.formatEther(value)} ETH, 经验: ${ethers.formatEther(exp)}`);
      } catch (error) {
        console.log(`❌ Token ${tokenId} 验证失败 - 仍未初始化`);
      }
    }

  } catch (error) {
    console.error('❌ 重试过程中发生错误:', error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('失败token重新初始化脚本执行失败:', error);
    process.exit(1);
  });
