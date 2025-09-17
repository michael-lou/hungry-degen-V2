import { Contract } from 'ethers';
import * as hre from 'hardhat';
import { ethers, network } from 'hardhat';
import fetch from 'node-fetch';
import { getMetadataFilesStats, metadataFiles } from './metadata/packMetadata';
import { ContractAddressManager } from './utils/ContractAddressManager';

const TYPE_CORE = 0;
const TYPE_FLEX = 1;

const BASE_URI_CORE = 'https://storage.googleapis.com/hungrydegens/itemsMetadata/core/';
const BASE_URI_FLEX = 'https://storage.googleapis.com/hungrydegens/itemsMetadata/flex/';

const characterNameToId: Record<string, number> = {
  'Airdrop Andy': 1,
  'Scammed Steve': 2,
  'Dustbag Danny': 3,
  'Leverage Larry': 4,
  'Trenches Ghost': 5,
};

const rarityNameToId: Record<string, number> = {
  C: 1,
  N: 2,
  R: 3,
  RR: 4,
  SR: 5,
  SSR: 6,
};

const partNameToId: Record<string, number> = {
  Clothes: 1,
  Headwears: 2,
  Accessories: 3,
  Opticals: 4,
  Weapons: 5,
};

const setNameToId: Record<string, number> = {
  Default: 0,
  'WAGMI War Set': 1,
  'Locked Liquidity Set': 2,
  'Mint Day Set': 3,
  'Joker Set': 4,
  'Down Bad Set': 5,
  'Muay Thai Set': 6,
  'WAGMI Blaster Set': 7,
  'Pre-Chain Set': 8,
  'Raijin Set': 9,
  'FOMO Set': 10,
  'Rug Sniffer Set': 11,
  'Wontonald Set': 12,
  'Poultry Ponzi Set': 13,
};

function chunkArray<T>(array: T[], chunkSize: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < array.length; i += chunkSize) {
    chunks.push(array.slice(i, i + chunkSize));
  }
  return chunks;
}

async function fetchMetadata(baseUri: string, filename: string) {
  try {
    const response = await fetch(`${baseUri}${filename}`);
    if (!response.ok) {
      throw new Error(`Failed to fetch metadata: ${response.status} ${response.statusText}`);
    }
    return await response.json();
  } catch (error) {
    console.error(`Error fetching metadata for ${filename}:`, error);
    throw error;
  }
}

// 设置预设分发序列
async function setupDistributionSequences(packMetadataStorage: Contract) {
  console.log('设置基础分发序列...');
  
  // 为所有角色和稀有度组合设置简单的顺序分发序列
  // 这确保了每个模板都有机会被选中
  
  const nftTypes = [TYPE_CORE, TYPE_FLEX]; // 0=Core, 1=Flex
  const characters = [1, 2, 3, 4, 5]; // Airdrop Andy, Scammed Steve, Dustbag Danny, Leverage Larry, Trenches Ghost
  const rarities = [1, 2, 3, 4, 5, 6]; // C, N, R, RR, SR, SSR
  
  let totalSequencesSet = 0;
  
  for (const nftType of nftTypes) {
    const nftTypeName = nftType === TYPE_CORE ? 'Core' : 'Flex';
    
    for (const character of characters) {
      for (const rarity of rarities) {
        try {
          // 获取此组合的模板数量
          const templateCount = await packMetadataStorage.getTemplateCount(nftType, character, rarity);
          
          if (templateCount > 0) {
            // 创建一个乱序序列 [0, 1, 2, ...] 然后打乱
            const sequence = Array.from({ length: Number(templateCount) }, (_, i) => i);
            
            // 使用算法打乱序列
            for (let i = sequence.length - 1; i > 0; i--) {
              const j = Math.floor(Math.random() * (i + 1));
              [sequence[i], sequence[j]] = [sequence[j], sequence[i]];
            }
            
            // 设置分发序列
            await packMetadataStorage.setDistributionSequence(nftType, character, rarity, sequence);
            
            console.log(`✅ ${nftTypeName} 角色${character} 稀有度${rarity}: 设置了${templateCount}个模板的序列`);
            totalSequencesSet++;
            
            // 添加小延迟以避免nonce冲突
            await new Promise(resolve => setTimeout(resolve, 100));
          }
        } catch (error: any) {
          console.warn(`⚠️  ${nftTypeName} 角色${character} 稀有度${rarity}: ${error.message || error}`);
        }
      }
    }
  }
  
  console.log(`🎉 总共设置了 ${totalSequencesSet} 个分发序列`);
}

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`开始为 PackMetadataStorage 添加元数据模板 (${networkName} 网络)...`);

  try {
    const [signer] = await ethers.getSigners();
    console.log(`使用地址: ${signer.address}`);

    const packMetadataStorageInfo = addressManager.getContractAddress(networkName, 'PackMetadataStorage');
    const coreNFTInfo = addressManager.getContractAddress(networkName, 'CoreNFT');
    const flexNFTInfo = addressManager.getContractAddress(networkName, 'FlexNFT');

    if (!packMetadataStorageInfo || !coreNFTInfo || !flexNFTInfo) {
      console.error('❌ 无法找到必要的合约地址，请先运行部署脚本');
      process.exit(1);
    }

    const packMetadataStorageArtifact = await hre.artifacts.readArtifact('PackMetadataStorage');
    const packMetadataStorage = new ethers.Contract(
      packMetadataStorageInfo.address,
      packMetadataStorageArtifact.abi,
      signer
    );
    console.log('已连接到 PackMetadataStorage:', packMetadataStorageInfo.address);

    const coreNFTArtifact = await hre.artifacts.readArtifact('CoreNFT');
    const coreNFT = new ethers.Contract(coreNFTInfo.address, coreNFTArtifact.abi, signer);
    console.log('已连接到 CoreNFT:', coreNFTInfo.address);

    const flexNFTArtifact = await hre.artifacts.readArtifact('FlexNFT');
    const flexNFT = new ethers.Contract(flexNFTInfo.address, flexNFTArtifact.abi, signer);
    console.log('已连接到 FlexNFT:', flexNFTInfo.address);

    console.log('设置 CoreNFT 的基础 URI...');
    const maxRetries = 3;
    let retries = 0;
    let success = false;

    while (retries < maxRetries && !success) {
      try {
        const tx1 = await coreNFT.setBaseURI(BASE_URI_CORE);
        console.log(`交易已提交，等待确认... 交易哈希: ${tx1.hash}`);
        await tx1.wait();
        console.log(`✅ 已设置 CoreNFT 的基础 URI: ${BASE_URI_CORE}`);
        success = true;
      } catch (error: any) {
        retries++;
        console.warn(`尝试 ${retries}/${maxRetries} 失败: ${error.message || error}`);

        if (retries >= maxRetries) {
          throw new Error(`无法设置 CoreNFT 基础 URI，达到最大重试次数`);
        }

        console.log(`等待 3 秒后重试...`);
        await new Promise((resolve) => setTimeout(resolve, 3000));
      }
    }

    console.log('设置 FlexNFT 的基础 URI...');
    retries = 0;
    success = false;

    while (retries < maxRetries && !success) {
      try {
        const tx2 = await flexNFT.setBaseURI(BASE_URI_FLEX);
        console.log(`交易已提交，等待确认... 交易哈希: ${tx2.hash}`);
        await tx2.wait();
        console.log(`✅ 已设置 FlexNFT 的基础 URI: ${BASE_URI_FLEX}`);
        success = true;
      } catch (error: any) {
        retries++;
        console.warn(`尝试 ${retries}/${maxRetries} 失败: ${error.message || error}`);

        if (retries >= maxRetries) {
          throw new Error(`无法设置 FlexNFT 基础 URI，达到最大重试次数`);
        }

        console.log(`等待 3 秒后重试...`);
        await new Promise((resolve) => setTimeout(resolve, 3000));
      }
    }

    console.log('\n开始处理元数据文件...');

    const stats = getMetadataFilesStats();
    console.log(`找到 ${stats.coreFilesCount} 个 CORE NFT 元数据文件`);
    console.log(`找到 ${stats.flexFilesCount} 个 FLEX NFT 元数据文件`);
    console.log(`总共 ${stats.totalFilesCount} 个元数据文件`);

    await processFiles(metadataFiles.core, TYPE_CORE, BASE_URI_CORE, packMetadataStorage);

    await processFiles(metadataFiles.flex, TYPE_FLEX, BASE_URI_FLEX, packMetadataStorage);

    console.log('\n🎯 开始设置预设分发序列...');
    await setupDistributionSequences(packMetadataStorage);

    console.log('\n元数据添加脚本执行完成!');

    addressManager.saveContractAddress(networkName, 'PackMetadataSetup', packMetadataStorageInfo.address, {
      coreBaseURI: BASE_URI_CORE,
      flexBaseURI: BASE_URI_FLEX,
      totalCoreTemplates: metadataFiles.core.length,
      totalFlexTemplates: metadataFiles.flex.length,
      updatedAt: new Date().toISOString(),
    });
  } catch (error) {
    console.error('❌ 添加元数据过程中发生错误:', error);
    throw error;
  }
}

async function processFiles(files: string[], nftType: number, baseUri: string, packMetadataStorage: Contract) {
  const nftTypeName = nftType === TYPE_CORE ? 'CORE' : 'FLEX';
  console.log(`\n开始处理 ${nftTypeName} NFT 元数据...`);

  const metadataByCharacterRarity: Record<string, any[]> = {};

  const concurrencyLimit = 5;
  const chunks = chunkArray(files, concurrencyLimit);

  for (const chunk of chunks) {
    const promises = chunk.map(async (filename) => {
      try {
        console.log(`获取元数据: ${baseUri}${filename}`);
        const metadata = await fetchMetadata(baseUri, filename);

        const characterAttr = metadata.attributes.find((attr: any) => attr.trait_type === 'Character');
        const rarityAttr = metadata.attributes.find((attr: any) => attr.trait_type === 'Rarity');
        const partAttr = metadata.attributes.find((attr: any) => attr.trait_type === 'Part');
        const setAttr = metadata.attributes.find((attr: any) => attr.trait_type === 'Set');

        if (!characterAttr || !rarityAttr || !partAttr) {
          throw new Error(`元数据 ${filename} 缺少必要的属性`);
        }

        const characterId = characterNameToId[characterAttr.value];
        const rarityId = rarityNameToId[rarityAttr.value];
        const partId = partNameToId[partAttr.value];
        const setId = setAttr ? setNameToId[setAttr.value] || 0 : 0;

        if (!characterId || !rarityId || !partId) {
          console.warn(
            `警告: ${filename} 的某些属性无法映射到ID. Character: ${characterAttr.value} -> ${characterId}, Rarity: ${rarityAttr.value} -> ${rarityId}, Part: ${partAttr.value} -> ${partId}`
          );
        }

        const key = `${characterId}_${rarityId}`;
        if (!metadataByCharacterRarity[key]) {
          metadataByCharacterRarity[key] = [];
        }

        const attributesBytes = ethers.toUtf8Bytes(JSON.stringify(metadata));

        metadataByCharacterRarity[key].push({
          uri: filename,
          attributes: attributesBytes,
          part: partId,
          set: setId,
        });
      } catch (error) {
        console.error(`处理元数据 ${filename} 失败:`, error);
      }
    });

    await Promise.all(promises);
  }

  console.log(`\n按角色和稀有度分组添加 ${nftTypeName} 元数据...`);

  const BATCH_SIZE = 10; 
  let totalAdded = 0;

  for (const [key, items] of Object.entries(metadataByCharacterRarity)) {
    const [characterId, rarityId] = key.split('_').map(Number);

    const characterName =
      Object.keys(characterNameToId).find((name) => characterNameToId[name] === characterId) || `ID: ${characterId}`;
    const rarityName =
      Object.keys(rarityNameToId).find((name) => rarityNameToId[name] === rarityId) || `ID: ${rarityId}`;

    console.log(`处理 ${characterName} 的 ${rarityName} 稀有度元数据 (${items.length} 项)...`);

    const batches = chunkArray(items, BATCH_SIZE);

    for (let i = 0; i < batches.length; i++) {
      const batch = batches[i];
      const uris = batch.map((item) => item.uri);
      const attributesArray = batch.map((item) => item.attributes);
      const partArray = batch.map((item) => item.part);
      const setArray = batch.map((item) => item.set);

      console.log(`添加批次 ${i + 1}/${batches.length} (${batch.length} 个模板)...`);

      const maxRetries = 3;
      let retries = 0;
      let success = false;

      while (retries < maxRetries && !success) {
        try {
          const tx = await packMetadataStorage.addTemplates(
            nftType,
            characterId,
            rarityId,
            uris,
            attributesArray,
            partArray,
            setArray
          );

          console.log(`批次 ${i + 1} 交易已提交，等待确认... 交易哈希: ${tx.hash}`);
          await tx.wait();

          totalAdded += batch.length;
          console.log(`✅ 批次 ${i + 1} 添加成功! 已添加: ${totalAdded}/${items.length}`);
          success = true;
        } catch (error: any) {
          retries++;
          console.warn(`批次 ${i + 1} 尝试 ${retries}/${maxRetries} 失败: ${error.message || error}`);

          if (retries >= maxRetries) {
            console.error(`❌ 批次 ${i + 1} 添加失败，达到最大重试次数`);
            break;
          }

          console.log(`等待 5 秒后重试批次 ${i + 1}...`);
          await new Promise((resolve) => setTimeout(resolve, 5000));
        }
      }
    }
  }

  console.log(`✅ ${nftTypeName} 元数据添加完成! 总共添加了 ${totalAdded} 个模板。`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('添加元数据脚本执行失败:', error);
    process.exit(1);
  });
