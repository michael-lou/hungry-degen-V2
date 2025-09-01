import { ethers, network } from 'hardhat';
import { foodSequence } from './metadata/foodSequence';
import { ContractAddressManager } from './utils/ContractAddressManager';

/**
 * 根据foodSequence.ts的数据分批设置FoodMarketplace的token序列
 * 优化版本：使用较小的批次大小和更好的错误处理
 */

const BATCH_SIZE = 25; // 每批处理25个token，降低gas使用

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`分批设置 FoodMarketplace Token序列 - ${networkName} 网络...`);

  const [deployer] = await ethers.getSigners();
  console.log(`操作者地址: ${deployer.address}`);

  try {
    // 从 ContractAddressManager 加载合约地址
    const contracts = addressManager.getAllContractAddresses(networkName) || {};
    const foodMarketplaceAddress = contracts['FoodMarketplace'];

    if (!foodMarketplaceAddress) {
      throw new Error('FoodMarketplace 地址未找到，请先部署 FoodMarketplace 合约');
    }

    console.log(`FoodMarketplace 地址: ${foodMarketplaceAddress}`);

    // 连接到 FoodMarketplace 合约
    const FoodMarketplace = await ethers.getContractFactory('FoodMarketplace');
    const foodMarketplace = FoodMarketplace.attach(foodMarketplaceAddress) as any;

    // 转换序列数据
    console.log('\n🔄 处理序列数据...');
    const tokenSequenceArray = foodSequence.map(item => parseInt(item.TokenId));
    
    console.log(`📋 序列统计信息:`);
    console.log(`总长度: ${tokenSequenceArray.length}`);
    console.log(`批次大小: ${BATCH_SIZE}`);
    console.log(`预计批次数: ${Math.ceil(tokenSequenceArray.length / BATCH_SIZE)}`);
    
    // 统计每个TokenId出现的次数
    const tokenCounts: { [key: number]: number } = {};
    tokenSequenceArray.forEach(tokenId => {
      tokenCounts[tokenId] = (tokenCounts[tokenId] || 0) + 1;
    });
    
    const uniqueTokens = Object.keys(tokenCounts).map(Number).sort((a, b) => a - b);
    console.log(`唯一Token数量: ${uniqueTokens.length}`);
    console.log(`Token ID范围: ${Math.min(...uniqueTokens)} - ${Math.max(...uniqueTokens)}`);

    // 检查数据有效性
    const invalidTokens = tokenSequenceArray.filter(id => isNaN(id) || id <= 0);
    if (invalidTokens.length > 0) {
      throw new Error(`发现无效Token ID: [${invalidTokens.slice(0, 10).join(', ')}${invalidTokens.length > 10 ? '...' : ''}]`);
    }

    // 检查当前序列
    try {
      const currentSequence = await foodMarketplace.getTokenSequence();
      const currentProgress = await foodMarketplace.getSequenceProgress();
      
      if (currentSequence.length > 0) {
        console.log(`\n⚠️ 发现现有序列长度: ${currentSequence.length}`);
        console.log(`当前进度: ${currentProgress}`);
        console.log('将清空并重新设置序列...');
      }
    } catch (error) {
      console.log('\n📝 当前没有设置序列');
    }

    // 步骤1: 初始化序列
    console.log('\n🚀 步骤1: 初始化Token序列...');
    const initTx = await foodMarketplace.initializeTokenSequence(tokenSequenceArray.length, {
      gasLimit: 500000
    });
    await initTx.wait();
    console.log(`✅ 序列初始化完成，预期长度: ${tokenSequenceArray.length}`);

    // 步骤2: 分批追加序列
    console.log('\n📦 步骤2: 分批追加Token序列...');
    
    const totalBatches = Math.ceil(tokenSequenceArray.length / BATCH_SIZE);
    let successfulBatches = 0;
    
    for (let i = 0; i < tokenSequenceArray.length; i += BATCH_SIZE) {
      const batch = tokenSequenceArray.slice(i, i + BATCH_SIZE);
      const batchNumber = Math.floor(i / BATCH_SIZE) + 1;
      
      console.log(`\n📦 处理批次 ${batchNumber}/${totalBatches}:`);
      console.log(`   范围: ${i} - ${Math.min(i + BATCH_SIZE - 1, tokenSequenceArray.length - 1)}`);
      console.log(`   批次大小: ${batch.length}`);
      console.log(`   样本: [${batch.slice(0, 5).join(', ')}${batch.length > 5 ? '...' : ''}]`);

      try {
        // 先估算gas
        let gasEstimate;
        try {
          gasEstimate = await foodMarketplace.appendTokenSequence.estimateGas(batch);
          console.log(`   预估Gas: ${gasEstimate}`);
        } catch (gasError) {
          console.log(`   ⚠️ Gas估算失败，使用默认值`);
          gasEstimate = 1200000n;
        }

        // 执行交易，使用估算gas的1.2倍作为安全边际
        const gasLimit = Math.floor(Number(gasEstimate) * 120 / 100);
        const appendTx = await foodMarketplace.appendTokenSequence(batch, {
          gasLimit: Math.min(gasLimit, 1500000) // 最大不超过1.5M gas
        });
        
        console.log(`   交易哈希: ${appendTx.hash}`);
        await appendTx.wait();
        
        // 验证进度
        const currentProgress = await foodMarketplace.getSequenceProgress();
        console.log(`   ✅ 批次 ${batchNumber} 成功，当前总长度: ${currentProgress}`);
        
        successfulBatches++;
        
        // 每次合约调用后都添加延迟，避免nonce冲突
        console.log(`   ⏸️ 等待3秒以避免nonce冲突...`);
        await new Promise(resolve => setTimeout(resolve, 3000));
        
      } catch (error) {
        console.log(`   ❌ 批次 ${batchNumber} 失败:`, error);
        
        // 尝试更小的批次
        console.log(`   🔧 尝试拆分为更小的批次...`);
        const smallBatchSize = Math.max(Math.floor(batch.length / 2), 5);
        
        for (let j = 0; j < batch.length; j += smallBatchSize) {
          const smallBatch = batch.slice(j, j + smallBatchSize);
          const smallBatchNumber = Math.floor(j / smallBatchSize) + 1;
          const totalSmallBatches = Math.ceil(batch.length / smallBatchSize);
          
          console.log(`   📦 小批次 ${smallBatchNumber}/${totalSmallBatches}: ${smallBatch.length}个token`);
          
          try {
            const smallTx = await foodMarketplace.appendTokenSequence(smallBatch, {
              gasLimit: 800000
            });
            await smallTx.wait();
            console.log(`   ✅ 小批次 ${smallBatchNumber} 成功`);
            
            // 在小批次之间增加延迟避免nonce冲突
            await new Promise(resolve => setTimeout(resolve, 2000));
          } catch (smallError) {
            console.log(`   ❌ 小批次 ${smallBatchNumber} 也失败:`, smallError);
            throw new Error(`批次 ${batchNumber} 完全失败，无法继续`);
          }
        }
        
        successfulBatches++;
      }
    }

    console.log(`\n✅ 所有批次处理完成！成功: ${successfulBatches}/${totalBatches}`);

    // 步骤3: 完成设置
    console.log('\n🏁 步骤3: 完成序列设置...');
    // 等待一下确保nonce是最新的
    console.log('   ⏸️ 等待3秒确保nonce同步...');
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    const finalizeTx = await foodMarketplace.finalizeTokenSequence();
    await finalizeTx.wait();
    console.log(`✅ 序列设置已完成并重置索引`);

    // 最终验证
    console.log('\n🔍 最终验证...');
    const finalSequence = await foodMarketplace.getTokenSequence();
    const currentIndex = await foodMarketplace.getCurrentSequenceIndex();

    console.log(`✅ 最终序列设置成功！`);
    console.log(`序列长度: ${finalSequence.length}`);
    console.log(`当前索引: ${currentIndex}`);
    console.log(`序列前10个: [${finalSequence.slice(0, 10).map((n: any) => n.toString()).join(', ')}...]`);
    console.log(`序列后10个: [...${finalSequence.slice(-10).map((n: any) => n.toString()).join(', ')}]`);

    // 验证长度匹配
    if (finalSequence.length === tokenSequenceArray.length) {
      console.log(`✅ 序列长度验证通过: ${finalSequence.length}`);
    } else {
      console.log(`❌ 序列长度不匹配: 期望 ${tokenSequenceArray.length}, 实际 ${finalSequence.length}`);
    }

    // 抽样验证几个位置的值
    console.log('\n🎯 抽样验证序列内容:');
    const sampleIndices = [0, 100, 500, 1000, Math.min(1500, tokenSequenceArray.length - 1), tokenSequenceArray.length - 1];
    
    for (const index of sampleIndices) {
      if (index < tokenSequenceArray.length && index < finalSequence.length) {
        const expected = tokenSequenceArray[index];
        const actual = Number(finalSequence[index]);
        if (expected === actual) {
          console.log(`✅ 位置 ${index}: ${actual} (正确)`);
        } else {
          console.log(`❌ 位置 ${index}: 期望 ${expected}, 实际 ${actual}`);
        }
      }
    }

    console.log('\n✅ FoodMarketplace Token序列分批设置完成!');
    console.log('\n📊 设置统计:');
    console.log(`总Token数量: ${tokenSequenceArray.length}`);
    console.log(`成功批次: ${successfulBatches}/${totalBatches}`);
    console.log(`批次大小: ${BATCH_SIZE}`);
    console.log(`唯一Token: ${uniqueTokens.length}`);

    console.log('\n📝 后续操作:');
    console.log('1. 确保FoodNFT中的所有Token都已初始化');
    console.log('2. 设置合适的食物价格: foodMarketplace.updatePrice(price)');
    console.log('3. 用户现在可以购买和开启食物盒子了');

  } catch (error) {
    console.error('❌ 设置过程中发生错误:', error);
    
    // 如果出错，显示当前进度
    try {
      const contracts = addressManager.getAllContractAddresses(networkName) || {};
      const foodMarketplaceAddress = contracts['FoodMarketplace'];
      if (foodMarketplaceAddress) {
        const FoodMarketplace = await ethers.getContractFactory('FoodMarketplace');
        const foodMarketplace = FoodMarketplace.attach(foodMarketplaceAddress) as any;
        const currentProgress = await foodMarketplace.getSequenceProgress();
        console.log(`当前设置进度: ${currentProgress} tokens`);
        console.log('可以重新运行脚本从中断处继续...');
      }
    } catch (progressError) {
      console.log('无法获取当前进度');
    }
    
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('FoodMarketplace序列分批设置脚本执行失败:', error);
    process.exit(1);
  });
